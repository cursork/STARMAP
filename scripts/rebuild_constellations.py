#!/usr/bin/env python3
"""Rebuild CONSTELLATIONS.aplf from Stellarium modern_iau constellation data.

Source: Stellarium skycultures/modern_iau (CC BY-SA 4.0)
        github.com/Stellarium/stellarium

Matching strategy:
  1. Extract HR (Yale BSC) numbers from our star table (book appendix)
  2. Cross-reference HR -> HIP via VizieR (IV/27A catalog)
  3. Build deterministic HIP -> our_index map
  4. Map Stellarium HIP chains to our 332-star catalog

Cross-constellation links (e.g. Auriga using beta Tau, Argo Navis remnants
sharing boundary stars) are preserved -- they are standard in all major
stick figure references."""

import json
import math
import os
import re
import subprocess
import sys
import urllib.request

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
STELLARIUM_FILE = os.path.join(SCRIPT_DIR, 'stellarium_modern_iau.json')
STAR_TABLE_FILE = os.path.join(PROJECT_DIR, 'book', 'markdown', 'starmap.md')
OUTPUT_FILE = os.path.join(PROJECT_DIR, 'APLSource', 'CONSTELLATIONS.aplf')

# All constellation abbreviations used in the book's star table
VALID_CONSTS = {
    'AND', 'AQL', 'AQR', 'ARA', 'ARI', 'AUR', 'BOO', 'CAP', 'CAR', 'CAS',
    'CEN', 'CEP', 'CET', 'CMA', 'CMI', 'CNC', 'COL', 'CRB', 'CRU', 'CRV',
    'CYG', 'DEL', 'DOR', 'DRA', 'ERI', 'GEM', 'GRU', 'HER', 'HYA', 'HYI',
    'IND', 'LEO', 'LEP', 'LIB', 'LUP', 'LYR', 'MUS', 'OPH', 'ORI', 'PAV',
    'PEG', 'PER', 'PHE', 'PLE', 'PSA', 'PSC', 'PUP', 'SCO', 'SER', 'SGR',
    'TAU', 'TRA', 'TRI', 'TUC', 'UMA', 'UMI', 'VEL', 'VIR',
}


def parse_star_table(filename):
    """Extract (index, HR_number) pairs from the book's star table.

    Uses token-based parsing: finds the known constellation abbreviation in each
    line, then extracts the star index (last integer before it) and HR number
    (first integer after it)."""
    stars = {}  # index -> HR number
    with open(filename) as f:
        content = f.read()

    # Find the star table section (between the header and closing ```)
    in_table = False
    for line in content.split('\n'):
        if 'Popular Name' in line and 'Bayer' in line and 'Yale' in line:
            in_table = True
            continue
        if not in_table:
            continue
        if line.strip() == '```':
            break
        if line.strip().startswith('Hr Min') or line.strip().startswith('No.'):
            continue

        tokens = line.split()
        if not tokens:
            continue

        # Find the constellation code among the tokens
        const_pos = None
        for i, tok in enumerate(tokens):
            if tok in VALID_CONSTS:
                const_pos = i
                break
        if const_pos is None:
            continue

        # Star index: last integer token (1-332) before the constellation
        star_idx = None
        for i in range(const_pos - 1, -1, -1):
            try:
                n = int(tokens[i])
                if 1 <= n <= 332:
                    star_idx = n
                    break
            except ValueError:
                continue

        # HR number: first integer token after the constellation
        hr = None
        for i in range(const_pos + 1, len(tokens)):
            try:
                n = int(tokens[i])
                hr = n
                break
            except ValueError:
                continue

        if star_idx is not None and hr is not None:
            stars[star_idx] = hr

    return stars


def load_star_catalog():
    """Load our 332-star catalog via gritt to get RA/Dec and names."""
    result = subprocess.run(
        ['gritt', '-l',
         '-link', f'sm:{PROJECT_DIR}/APLSource',
         '-e', "{⎕←(⍕⍵),' ',(⍵⊃sm.STARNAMES),' ',(⍕sm.STARS[⍵;]),' ',(⍵⊃sm.STARCONSTELLATION)}¨⍳332"],
        capture_output=True, text=True, timeout=60
    )
    stars = {}  # index -> (name, ra_hours, dec_deg, const)
    for line in result.stdout.strip().split('\n'):
        line = line.strip()
        if not line or line.startswith('Linked'):
            continue
        parts = line.split()
        if len(parts) < 5:
            continue
        idx = int(parts[0])
        const = parts[-1]
        dec = float(parts[-2].replace('¯', '-'))
        ra = float(parts[-3].replace('¯', '-'))
        name = ' '.join(parts[1:-3])
        stars[idx] = (name, ra, dec, const)
    return stars


def fetch_hr_to_hip(hr_numbers):
    """Cross-reference HR -> HIP using VizieR IV/27A catalog."""
    # Known HR->HIP mappings not present in IV/27A cross-reference.
    # HR 4210 (eta Car, mag 6.21) has no Hipparcos entry.
    KNOWN_HR_HIP = {
        2890: 36850,   # Castor (alpha Gem) — IV/27A has HR 2891 not 2890
        5506: 72105,   # epsilon Boo (Izar)
        5909: 77055,   # zeta UMi
    }
    hr_to_hip = {}
    # Apply known overrides first
    for hr, hip in KNOWN_HR_HIP.items():
        if hr in hr_numbers:
            hr_to_hip[hr] = hip
    batch_size = 50
    hr_list = sorted(hr_numbers - set(hr_to_hip.keys()))

    for i in range(0, len(hr_list), batch_size):
        batch = hr_list[i:i + batch_size]
        hr_str = ','.join(str(h) for h in batch)
        url = (f'https://vizier.cds.unistra.fr/viz-bin/asu-tsv?-source=IV/27A'
               f'&HR={hr_str}&-out=HR,HIP&-out.max=100')
        try:
            with urllib.request.urlopen(url, timeout=15) as resp:
                data = resp.read().decode('utf-8')
                for line in data.strip().split('\n'):
                    if line.startswith('#') or line.startswith('-') or not line.strip():
                        continue
                    parts = line.split('\t')
                    if len(parts) >= 2:
                        try:
                            hr = int(parts[0].strip())
                            hip = int(parts[1].strip())
                            hr_to_hip[hr] = hip
                        except (ValueError, IndexError):
                            pass
        except Exception as e:
            print(f"  VizieR batch error at offset {i}: {e}", file=sys.stderr)
            for hr in batch:
                try:
                    url2 = (f'https://vizier.cds.unistra.fr/viz-bin/asu-tsv?-source=IV/27A'
                            f'&HR={hr}&-out=HR,HIP&-out.max=1')
                    with urllib.request.urlopen(url2, timeout=10) as resp:
                        data = resp.read().decode('utf-8')
                        for line in data.strip().split('\n'):
                            if line.startswith('#') or line.startswith('-') or not line.strip():
                                continue
                            parts = line.split('\t')
                            if len(parts) >= 2:
                                try:
                                    hr_to_hip[int(parts[0].strip())] = int(parts[1].strip())
                                except (ValueError, IndexError):
                                    pass
                except Exception:
                    pass

    return hr_to_hip


def fetch_hip_coords(hip_ids):
    """Get RA/Dec for HIP stars from VizieR Hipparcos catalog."""
    coords = {}
    batch_size = 50
    hip_list = sorted(hip_ids)

    for i in range(0, len(hip_list), batch_size):
        batch = hip_list[i:i + batch_size]
        id_list = ','.join(str(h) for h in batch)
        url = (f'https://vizier.cds.unistra.fr/viz-bin/asu-tsv?-source=I/239/hip_main'
               f'&HIP={id_list}&-out=HIP,RAICRS,DEICRS&-out.max=100')
        try:
            with urllib.request.urlopen(url, timeout=15) as resp:
                data = resp.read().decode('utf-8')
                for line in data.strip().split('\n'):
                    if line.startswith('#') or line.startswith('-') or not line.strip():
                        continue
                    parts = line.split('\t')
                    if len(parts) >= 3:
                        try:
                            hip = int(parts[0].strip())
                            ra = float(parts[1].strip()) / 15.0  # deg -> hours
                            dec = float(parts[2].strip())
                            coords[hip] = (ra, dec)
                        except (ValueError, IndexError):
                            pass
        except Exception as e:
            print(f"  VizieR coords batch error at offset {i}: {e}", file=sys.stderr)

    return coords


def angular_distance(ra1, dec1, ra2, dec2):
    """Angular distance in degrees (RA in hours, Dec in degrees)."""
    ra1_r = math.radians(ra1 * 15)
    ra2_r = math.radians(ra2 * 15)
    d1 = math.radians(dec1)
    d2 = math.radians(dec2)
    cos_d = math.sin(d1) * math.sin(d2) + math.cos(d1) * math.cos(d2) * math.cos(ra1_r - ra2_r)
    return math.degrees(math.acos(max(-1, min(1, cos_d))))


def main():
    # --- 1. Parse Stellarium data ---
    print("Loading Stellarium modern_iau data...")
    with open(STELLARIUM_FILE) as f:
        stellarium = json.load(f)

    constellations_raw = {}  # abbr -> list of chains (each chain is list of HIP ints)
    all_hip_ids = set()
    for entry in stellarium['constellations']:
        abbr = entry['id'].split()[-1]
        chains = entry['lines']
        constellations_raw[abbr] = chains
        for chain in chains:
            all_hip_ids.update(chain)

    print(f"  {len(constellations_raw)} constellations, {len(all_hip_ids)} unique HIP IDs")

    # --- 2. Load our star catalog ---
    print("Loading our 332-star catalog...")
    our_stars = load_star_catalog()
    print(f"  {len(our_stars)} stars loaded")

    # --- 3. Parse HR numbers from the book ---
    print("Parsing HR numbers from star table...")
    idx_to_hr = parse_star_table(STAR_TABLE_FILE)
    print(f"  {len(idx_to_hr)} HR numbers extracted")
    if len(idx_to_hr) < 330:
        print(f"  WARNING: expected ~332, got {len(idx_to_hr)}", file=sys.stderr)
        # Show which indices are missing
        missing = [i for i in range(1, 333) if i not in idx_to_hr]
        if missing:
            print(f"  Missing indices: {missing[:20]}{'...' if len(missing) > 20 else ''}")

    # Build HR -> our_index map
    hr_to_idx = {hr: idx for idx, hr in idx_to_hr.items()}

    # --- 4. Get HR -> HIP cross-reference ---
    print("Fetching HR -> HIP cross-reference from VizieR...")
    hr_numbers = set(idx_to_hr.values())
    hr_to_hip = fetch_hr_to_hip(hr_numbers)
    print(f"  {len(hr_to_hip)}/{len(hr_numbers)} HR numbers resolved to HIP")

    # Show missing HR->HIP
    missing_hr = hr_numbers - set(hr_to_hip.keys())
    if missing_hr:
        print(f"  HR numbers without HIP match: {sorted(missing_hr)}")

    # Build HIP -> our_index via HR
    hip_to_idx = {}
    for idx, hr in idx_to_hr.items():
        if hr in hr_to_hip:
            hip = hr_to_hip[hr]
            hip_to_idx[hip] = idx

    print(f"  {len(hip_to_idx)} HIP -> our_index mappings via HR cross-reference")

    # --- 5. Fallback: angular distance matching for unmapped HIP IDs ---
    unmapped_hips = all_hip_ids - set(hip_to_idx.keys())
    if unmapped_hips:
        print(f"\n  {len(unmapped_hips)} Stellarium HIP IDs not in our catalog via HR")
        print("  Fetching coordinates for fallback matching...")
        hip_coords = fetch_hip_coords(unmapped_hips)
        matched = 0
        unmatched = []
        for hip in sorted(unmapped_hips):
            if hip not in hip_coords:
                continue
            ra, dec = hip_coords[hip]
            best_idx = None
            best_dist = 999
            for idx, (name, sra, sdec, const) in our_stars.items():
                d = angular_distance(ra, dec, sra, sdec)
                if d < best_dist:
                    best_dist = d
                    best_idx = idx
            if best_dist < 0.5:  # tighter threshold: 0.5 degrees
                hip_to_idx[hip] = best_idx
                matched += 1
            else:
                unmatched.append((hip, ra, dec, best_dist, best_idx))
        print(f"  Coordinate fallback: {matched} matched, {len(unmatched)} not in our catalog")
        if unmatched and len(unmatched) <= 20:
            for hip, ra, dec, d, best in unmatched:
                best_name = our_stars[best][0] if best else '?'
                print(f"    HIP {hip}: RA={ra:.3f}h Dec={dec:.1f} (nearest: {best_name} at {d:.1f})")

    total_mapped = len(set(hip_to_idx.keys()) & all_hip_ids)
    print(f"\nTotal: {total_mapped}/{len(all_hip_ids)} Stellarium HIP IDs mapped to our catalog")

    # --- 6. Build constellation line pairs ---
    our_constellations = {}  # abbr -> list of (idx1, idx2) pairs

    for abbr in sorted(constellations_raw.keys()):
        chains = constellations_raw[abbr]
        pairs = []
        for chain in chains:
            idx_chain = []
            for hip in chain:
                if hip in hip_to_idx:
                    idx = hip_to_idx[hip]
                    if 1 <= idx <= 332:
                        idx_chain.append(idx)
            for i in range(len(idx_chain) - 1):
                if idx_chain[i] != idx_chain[i + 1]:
                    pair = (idx_chain[i], idx_chain[i + 1])
                    if pair not in pairs and (pair[1], pair[0]) not in pairs:
                        pairs.append(pair)
        if pairs:
            our_constellations[abbr] = pairs

    # --- 7. Report cross-boundary links ---
    print(f"\n{'=' * 60}")
    print("Cross-constellation links:")
    print(f"{'=' * 60}")
    cross_count = 0
    seen_cross = set()
    for abbr, pairs in sorted(our_constellations.items()):
        for a, b in pairs:
            for idx in (a, b):
                star_const = our_stars[idx][3]
                key = (abbr, idx)
                if star_const != abbr and key not in seen_cross:
                    seen_cross.add(key)
                    star_name = our_stars[idx][0]
                    cross_count += 1
                    print(f"  {abbr} uses star {idx} ({star_name}) from {star_const}")
    print(f"\n{cross_count} cross-boundary star references")

    # --- 8. Report constellation summary ---
    total_lines = sum(len(p) for p in our_constellations.values())
    print(f"\n{len(our_constellations)} constellations, {total_lines} line segments")
    for abbr in sorted(our_constellations.keys()):
        pairs = our_constellations[abbr]
        star_indices = set()
        for a, b in pairs:
            star_indices.add(a)
            star_indices.add(b)
        stars_str = ', '.join(f"{our_stars[i][0]}({i})" for i in sorted(star_indices))
        print(f"  {abbr}: {len(pairs)} lines, {len(star_indices)} stars: {stars_str}")

    # --- 9. Generate APL code ---
    print(f"\n{'=' * 60}")
    print("Generating APL code...")

    apl_lines = []
    apl_lines.append(' Z←CONSTELLATIONS')
    apl_lines.append('⍝ Constellation stick figure connectivity data')
    apl_lines.append('⍝ Source: Stellarium skycultures/modern_iau (CC BY-SA 4.0)')
    apl_lines.append('⍝ github.com/Stellarium/stellarium')
    apl_lines.append('⍝ Returns nested vector: each element is (name lines)')
    apl_lines.append('⍝   name:  IAU abbreviation (character vector)')
    apl_lines.append('⍝   lines: N×2 matrix of 1-based star indices into STARS/STARNAMES')
    apl_lines.append('⍝')
    apl_lines.append('⍝ Some constellations share boundary stars (Argo Navis remnants:')
    apl_lines.append('⍝ Car/Vel/Pup; traditional: Aur/Tau). These are standard in all')
    apl_lines.append('⍝ major stick figure references.')
    apl_lines.append(' Z←⍬')

    for abbr in sorted(our_constellations.keys()):
        pairs = our_constellations[abbr]
        n = len(pairs)
        flat = []
        for a, b in pairs:
            flat.extend([a, b])
        flat_str = ' '.join(str(x) for x in flat)
        apl_lines.append(f" Z,←⊂('{abbr}'({n} 2⍴{flat_str}))")

    apl_code = '\n'.join(apl_lines) + '\n'

    with open(OUTPUT_FILE, 'w') as f:
        f.write(apl_code)
    print(f"\nWritten to {OUTPUT_FILE}")


if __name__ == '__main__':
    main()
