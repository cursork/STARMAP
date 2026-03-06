#!/usr/bin/env python3
"""Generate APL star catalog files from book/markdown/starmap.md table.

Parses the 332-star table (lines 721-1052) and writes:
  - APLSource/stars.aplf     (N×2 matrix of RA, Dec)
  - APLSource/STARNAMES.aplf (nested vector of names)
  - APLSource/BRIGHT.aplf    (boolean vector, 1 if mag ≤ 1.5)
"""

import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
PROJECT_DIR = SCRIPT_DIR.parent
STARMAP_PATH = PROJECT_DIR / 'book' / 'markdown' / 'starmap.md'
APL_DIR = PROJECT_DIR / 'APLSource'

TABLE_START = 721  # 1-indexed line number of first star (Alpheratz)
TABLE_END = 1052   # 1-indexed line number of last star (ζ Vir)

GREEK_MAP = {
    'α': 'a',  'β': 'b',  'γ': 'g',  'δ': 'd',  'ε': 'e',
    'ζ': 'z',  'η': 'et', 'θ': 'th', 'ι': 'i',  'κ': 'k',
    'λ': 'l',  'μ': 'mu', 'µ': 'mu',  # U+03BC and U+00B5 (micro sign)
    'ν': 'nu', 'ξ': 'xi', 'ο': 'o',  'π': 'pi', 'ρ': 'r',
    'σ': 'si', 'τ': 't',  'υ': 'u',  'φ': 'ph', 'χ': 'x',
    'ψ': 'ps', 'ω': 'w',
}

GREEK_LETTERS = set(GREEK_MAP.keys())

# Two-word constellation abbreviations needing non-trivial mixed case
MULTIWORD_CONSTS = {
    'CMA': 'CMa', 'CMI': 'CMi', 'CRB': 'CrB', 'CVN': 'CVn',
    'PSA': 'PsA', 'TRA': 'TrA', 'UMA': 'UMa', 'UMI': 'UMi',
}


def const_mixed(abbr):
    """AND→And, CMA→CMa, UMA→UMa, etc."""
    if abbr in MULTIWORD_CONSTS:
        return MULTIWORD_CONSTS[abbr]
    return abbr[0] + abbr[1:].lower()


def parse_apl_num(s):
    """Convert APL numeric literal (¯ for minus) to float."""
    return float(s.replace('¯', '-'))


def parse_line(line):
    """Parse one row of the star table. Returns a dict or None."""
    tokens = line.split()
    if len(tokens) < 10:
        return None

    # Last 8 tokens: BSC RAH RAM RAS DECD DECM MAG PAR
    par_s, mag_s, decm_s, decd_s = tokens[-1], tokens[-2], tokens[-3], tokens[-4]
    ras_s, ram_s, rah_s, bsc_s = tokens[-5], tokens[-6], tokens[-7], tokens[-8]
    constellation = tokens[-9]
    remaining = tokens[:-9]

    # Row number is the first all-digit token in remaining
    row_idx = None
    for i, t in enumerate(remaining):
        if t.isdigit():
            row_idx = i
            break
    if row_idx is None:
        raise ValueError(f'No row number found: {line!r}')

    popular_name = ' '.join(remaining[:row_idx])
    row = int(remaining[row_idx])

    greek = None
    if row_idx + 1 < len(remaining) and remaining[row_idx + 1] in GREEK_LETTERS:
        greek = remaining[row_idx + 1]

    # RA = hours + minutes/60 + seconds/3600
    ra = int(rah_s) + int(ram_s) / 60 + int(ras_s) / 3600

    # Dec: sign from ¯ prefix on degrees (handles ¯0 correctly)
    neg = decd_s.startswith('¯')
    d = abs(int(decd_s.replace('¯', '-')))
    m = abs(int(decm_s.replace('¯', '-')))
    dec = d + m / 60
    if neg:
        dec = -dec

    mag = parse_apl_num(mag_s)

    return {
        'row': row,
        'popular_name': popular_name,
        'greek': greek,
        'constellation': constellation,
        'ra': ra,
        'dec': dec,
        'magnitude': mag,
        'bright': 1 if mag <= 1.5 else 0,
    }


def make_name(star, ple_counter):
    """Generate display name for a star."""
    pop = star['popular_name']
    if pop:
        if '(' in pop:
            pop = pop[:pop.index('(')].strip()
        return pop.title()

    const = star['constellation']
    if const == 'PLE':
        return f'Ple{ple_counter}'

    mixed = const_mixed(const)
    greek = star['greek']
    if greek:
        return GREEK_MAP[greek] + mixed

    return 'pp' + mixed


def read_star_table():
    """Parse all 332 stars from starmap.md."""
    with open(STARMAP_PATH, encoding='utf-8') as f:
        lines = f.readlines()

    stars = []
    ple_count = 0
    for i in range(TABLE_START - 1, TABLE_END):
        star = parse_line(lines[i])
        if star is None:
            raise ValueError(f'Failed to parse line {i + 1}: {lines[i]!r}')
        if star['constellation'] == 'PLE':
            ple_count += 1
        star['_ple'] = ple_count
        stars.append(star)

    return stars


def write_stars(stars):
    """Write stars.aplf: N×2 matrix of RA, Dec."""
    n = len(stars)
    vals = []
    for s in stars:
        vals.append(f'{s["ra"]:.6f}')
        vals.append(f'{s["dec"]:.6f}')
    vals = [v.replace('-', '¯') for v in vals]

    path = APL_DIR / 'stars.aplf'
    with open(path, 'w', encoding='utf-8') as f:
        f.write(' Z←STARS\n')
        f.write('⍝ Star catalog: Right Ascension (hours), Declination (degrees)\n')
        f.write('⍝ Epoch J2000. 332 stars from Yale BSC5 (book appendix pp.693+)\n')
        f.write(f' Z←{n} 2⍴{" ".join(vals)}\n')
    print(f'Wrote {path} ({n} stars)')


def write_starnames(stars):
    """Write STARNAMES.aplf: nested vector grouped by constellation."""
    names = [make_name(s, s['_ple']) for s in stars]

    # Group consecutive stars by constellation
    groups = []
    cur_const = None
    cur_names = []
    for s, name in zip(stars, names):
        c = s['constellation']
        if c != cur_const:
            if cur_names:
                groups.append(cur_names)
            cur_names = [name]
            cur_const = c
        else:
            cur_names.append(name)
    if cur_names:
        groups.append(cur_names)

    path = APL_DIR / 'STARNAMES.aplf'
    with open(path, 'w', encoding='utf-8') as f:
        f.write(' Z←STARNAMES\n')
        f.write(f'⍝ Names for the {len(names)} stars in STARS catalog\n')
        f.write('⍝ Popular names where available, Bayer designations otherwise\n')
        for i, grp in enumerate(groups):
            quoted = ' '.join(f"'{n}'" for n in grp)
            if i == 0:
                if len(grp) == 1:
                    f.write(f' Z←,⊂{quoted}\n')
                else:
                    f.write(f' Z←{quoted}\n')
            else:
                if len(grp) == 1:
                    f.write(f' Z,←,⊂{quoted}\n')
                else:
                    f.write(f' Z,←{quoted}\n')
    print(f'Wrote {path} ({len(names)} names, {len(groups)} constellation groups)')


def write_bright(stars):
    """Write BRIGHT.aplf: boolean vector."""
    n = len(stars)
    vals = ' '.join(str(s['bright']) for s in stars)

    path = APL_DIR / 'BRIGHT.aplf'
    with open(path, 'w', encoding='utf-8') as f:
        f.write(' Z←BRIGHT\n')
        f.write('⍝ Logical vector: 1 for stars of magnitude 1.5 or brighter\n')
        f.write('⍝ Corresponds to entries in STARS matrix\n')
        f.write(f' Z←{n}⍴{vals}\n')
    print(f'Wrote {path} ({n} values, {sum(s["bright"] for s in stars)} bright)')


def main():
    stars = read_star_table()
    if len(stars) != 332:
        print(f'ERROR: expected 332 stars, got {len(stars)}', file=sys.stderr)
        sys.exit(1)

    bright = sum(s['bright'] for s in stars)
    print(f'Parsed {len(stars)} stars ({bright} bright)')

    # Sanity checks
    for s in stars:
        if not (0 <= s['ra'] <= 24):
            print(f'WARNING: row {s["row"]} RA={s["ra"]:.6f} out of range')
        if not (-90 <= s['dec'] <= 90):
            print(f'WARNING: row {s["row"]} Dec={s["dec"]:.6f} out of range')

    write_stars(stars)
    write_starnames(stars)
    write_bright(stars)


if __name__ == '__main__':
    main()
