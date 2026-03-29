#!/usr/bin/env python3
"""Generate an HTML comparison page: our constellation stick figures vs In-The-Sky.org reference.

Reads CONSTELLATIONS.aplf and star positions via gritt, renders our stick figures
as inline SVGs, and shows In-The-Sky.org charts side by side."""

import math
import os
import re
import subprocess
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
OUTPUT_FILE = os.path.join(SCRIPT_DIR, 'constellations_compare.html')

# In-The-Sky.org chart URL pattern (Dominic Ford, non-commercial use with credit)
CHART_URL = 'https://in-the-sky.org/data/charts/{CODE}_1.png'

# Map our abbreviations to In-The-Sky.org codes
ABBR_TO_CODE = {
    'And': 'AND', 'Aql': 'AQL', 'Aqr': 'AQR', 'Ara': 'ARA', 'Ari': 'ARI',
    'Aur': 'AUR', 'Boo': 'BOO', 'CMa': 'CMA', 'CMi': 'CMI', 'Cap': 'CAP',
    'Car': 'CAR', 'Cas': 'CAS', 'Cen': 'CEN', 'Cep': 'CEP', 'Cet': 'CET',
    'Cnc': 'CNC', 'Col': 'COL', 'Cru': 'CRU', 'Crv': 'CRV', 'Cyg': 'CYG',
    'Del': 'DEL', 'Dor': 'DOR', 'Dra': 'DRA', 'Eri': 'ERI', 'Gem': 'GEM',
    'Gru': 'GRU', 'Her': 'HER', 'Hya': 'HYA', 'Hyi': 'HYI', 'Leo': 'LEO',
    'Lep': 'LEP', 'Lib': 'LIB', 'Lup': 'LUP', 'Lyr': 'LYR', 'Oph': 'OPH',
    'Ori': 'ORI', 'Peg': 'PEG', 'Per': 'PER', 'Phe': 'PHE', 'Pup': 'PUP',
    'Sco': 'SCO', 'Ser': 'SER1', 'Sgr': 'SGR', 'Tau': 'TAU', 'TrA': 'TRA',
    'Tri': 'TRI', 'UMa': 'UMA', 'UMi': 'UMI', 'Vel': 'VEL', 'Vir': 'VIR',
}

FULL_NAMES = {
    'And': 'Andromeda', 'Aql': 'Aquila', 'Aqr': 'Aquarius', 'Ara': 'Ara',
    'Ari': 'Aries', 'Aur': 'Auriga', 'Boo': 'Bootes', 'CMa': 'Canis Major',
    'CMi': 'Canis Minor', 'Cap': 'Capricornus', 'Car': 'Carina', 'Cas': 'Cassiopeia',
    'Cen': 'Centaurus', 'Cep': 'Cepheus', 'Cet': 'Cetus', 'Cnc': 'Cancer',
    'Col': 'Columba', 'Cru': 'Crux', 'Crv': 'Corvus', 'Cyg': 'Cygnus',
    'Del': 'Delphinus', 'Dor': 'Dorado', 'Dra': 'Draco', 'Eri': 'Eridanus',
    'Gem': 'Gemini', 'Gru': 'Grus', 'Her': 'Hercules', 'Hya': 'Hydra',
    'Hyi': 'Hydrus', 'Leo': 'Leo', 'Lep': 'Lepus', 'Lib': 'Libra',
    'Lup': 'Lupus', 'Lyr': 'Lyra', 'Oph': 'Ophiuchus', 'Ori': 'Orion',
    'Peg': 'Pegasus', 'Per': 'Perseus', 'Phe': 'Phoenix', 'Pup': 'Puppis',
    'Sco': 'Scorpius', 'Ser': 'Serpens', 'Sgr': 'Sagittarius', 'Tau': 'Taurus',
    'TrA': 'Triangulum Australe', 'Tri': 'Triangulum', 'UMa': 'Ursa Major',
    'UMi': 'Ursa Minor', 'Vel': 'Vela', 'Vir': 'Virgo',
}


def load_data():
    """Load star positions, names, and constellation data from APL."""
    result = subprocess.run(
        ['gritt', '-l',
         '-link', f'sm:{PROJECT_DIR}/APLSource',
         '-e', "{⎕←(⍕⍵),' ',(⍵⊃sm.STARNAMES),' ',(⍕sm.STARS[⍵;])}¨⍳332"],
        capture_output=True, text=True, timeout=60
    )
    stars = {}
    for line in result.stdout.strip().split('\n'):
        line = line.strip()
        if not line or line.startswith('Linked'):
            continue
        parts = line.split()
        if len(parts) < 4:
            continue
        idx = int(parts[0])
        dec = float(parts[-1].replace('¯', '-'))
        ra = float(parts[-2].replace('¯', '-'))
        name = ' '.join(parts[1:-2])
        stars[idx] = (name, ra, dec)

    # Parse CONSTELLATIONS.aplf
    constellations = {}
    with open(os.path.join(PROJECT_DIR, 'APLSource', 'CONSTELLATIONS.aplf')) as f:
        for line in f:
            m = re.search(r"'(\w+)'\((\d+) 2⍴([\d ]+)\)", line)
            if m:
                abbr = m.group(1)
                n = int(m.group(2))
                nums = list(map(int, m.group(3).split()))
                pairs = [(nums[i], nums[i + 1]) for i in range(0, len(nums), 2)]
                constellations[abbr] = pairs

    return stars, constellations


def render_constellation_svg(abbr, pairs, stars, size=300):
    """Render a single constellation as an SVG string."""
    # Collect all stars in this constellation
    all_indices = set()
    for a, b in pairs:
        all_indices.add(a)
        all_indices.add(b)

    if not all_indices:
        return ''

    # Get RA/Dec for all stars
    positions = {idx: (stars[idx][1], stars[idx][2]) for idx in all_indices if idx in stars}
    if not positions:
        return ''

    ras = [ra for ra, dec in positions.values()]
    decs = [dec for ra, dec in positions.values()]

    # Handle RA wrapping (if constellation spans 0h)
    ra_range = max(ras) - min(ras)
    if ra_range > 12:
        ras_shifted = [(ra - 24 if ra > 12 else ra) for ra in ras]
        positions = {idx: ((ra - 24 if ra > 12 else ra), dec)
                     for idx, (ra, dec) in positions.items()}
        ras = ras_shifted

    margin = 0.15
    ra_min, ra_max = min(ras), max(ras)
    dec_min, dec_max = min(decs), max(decs)
    ra_span = max(ra_max - ra_min, 0.5)
    dec_span = max(dec_max - dec_min, 2.0)

    ra_min -= ra_span * margin
    ra_max += ra_span * margin
    dec_min -= dec_span * margin
    dec_max += dec_span * margin
    ra_span = ra_max - ra_min
    dec_span = dec_max - dec_min

    def to_xy(ra, dec):
        # RA increases right-to-left (east on left), so invert x
        x = (1 - (ra - ra_min) / ra_span) * size
        y = (1 - (dec - dec_min) / dec_span) * size
        return x, y

    svg = f'<svg width="{size}" height="{size}" xmlns="http://www.w3.org/2000/svg">'
    svg += f'<rect width="{size}" height="{size}" fill="#0a0a2e"/>'

    # Draw lines
    for a, b in pairs:
        if a in positions and b in positions:
            x1, y1 = to_xy(*positions[a])
            x2, y2 = to_xy(*positions[b])
            svg += f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="#5577aa" stroke-width="1.5"/>'

    # Draw stars
    for idx in sorted(all_indices):
        if idx not in positions:
            continue
        x, y = to_xy(*positions[idx])
        name = stars[idx][0]
        is_bright = name[0].isupper() and not name.startswith('pp') and not name.startswith('nu')
        r = 4 if is_bright else 2.5
        fill = '#ffcc00' if is_bright else '#aabbcc'
        svg += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r}" fill="{fill}"/>'
        svg += f'<text x="{x + 6:.1f}" y="{y + 3:.1f}" fill="#99aabb" font-size="9" font-family="monospace">{name}</text>'

    svg += '</svg>'
    return svg


def main():
    print("Loading constellation data...")
    stars, constellations = load_data()
    print(f"  {len(stars)} stars, {len(constellations)} constellations")

    html = '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Constellation stick figure comparison</title>
<style>
body { background: #1a1a2e; color: #ccc; font-family: system-ui, sans-serif; margin: 20px; }
h1 { color: #88aadd; text-align: center; }
h2 { color: #88aadd; margin: 0 0 4px 0; font-size: 16px; }
.note { text-align: center; color: #667; font-size: 13px; margin-bottom: 30px; }
.grid { display: flex; flex-direction: column; gap: 20px; max-width: 900px; margin: 0 auto; }
.card { background: #12122a; border: 1px solid #334; border-radius: 8px; padding: 16px; }
.pair { display: flex; gap: 16px; align-items: flex-start; }
.ours { flex: 0 0 300px; }
.ref { flex: 0 0 500px; }
.ref img { width: 100%; border-radius: 4px; }
.label { color: #667; font-size: 11px; margin-bottom: 4px; }
.coverage { color: #556; font-size: 11px; }
@media print {
  body { background: white; color: #222; }
  .card { border-color: #ccc; background: white; page-break-inside: avoid; }
  .ref img { max-height: 300px; width: auto; }
  h1, h2 { color: #335; }
}
</style>
</head>
<body>
<h1>Constellation stick figure comparison</h1>
<p class="note">Left: our rendering (Stellarium modern_iau data, matched to 332-star catalog)<br>
Right: In-The-Sky.org reference charts (Dominic Ford, used for comparison only)</p>
<div class="grid">
'''

    # Load Stellarium segment counts for coverage stats
    import json
    with open(os.path.join(SCRIPT_DIR, 'stellarium_modern_iau.json')) as f:
        stel = json.load(f)
    stel_counts = {}
    for entry in stel['constellations']:
        a = entry['id'].split()[-1]
        stel_counts[a] = sum(len(chain) - 1 for chain in entry['lines'])

    for abbr in sorted(constellations.keys()):
        pairs = constellations[abbr]
        code = ABBR_TO_CODE.get(abbr, abbr.upper())
        full = FULL_NAMES.get(abbr, abbr)
        svg = render_constellation_svg(abbr, pairs, stars)
        chart_url = CHART_URL.format(CODE=code)
        stel_n = stel_counts.get(abbr, 0)
        pct = int(len(pairs) / stel_n * 100) if stel_n > 0 else 100

        html += f'''<div class="card">
<h2>{abbr} — {full} <span class="coverage">({len(pairs)}/{stel_n} segments, {pct}% coverage)</span></h2>
<div class="pair">
<div class="ours">
<div class="label">Ours</div>
{svg}
</div>
<div class="ref">
<div class="label">In-The-Sky.org reference</div>
<img src="{chart_url}" alt="{full} reference chart" loading="lazy">
</div>
</div>
</div>
'''

    html += '''</div>
<p class="note" style="margin-top:30px">Reference charts copyright Dominic Ford / In-The-Sky.org. Used here for visual comparison only.</p>
</body>
</html>
'''

    with open(OUTPUT_FILE, 'w') as f:
        f.write(html)
    print(f"Written to {OUTPUT_FILE}")
    print(f"Open: file://{OUTPUT_FILE}")


if __name__ == '__main__':
    main()
