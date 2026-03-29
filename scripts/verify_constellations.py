#!/usr/bin/env python3
"""Plot each constellation's stick figure to visually verify correctness.
Uses RA/Dec from the STARS catalog and connectivity from CONSTELLATIONS."""

import subprocess
import json
import re

# Get star data from APL
result = subprocess.run(
    ['gritt', '-l',
     '-link', 'sm:/Users/nk/dev/STARMAP/APLSource',
     '-e', "{⎕←(⍕⍵),' ',(⍵⊃sm.STARNAMES),' ',(⍕sm.STARS[⍵;]),' ',(⍵⊃sm.STARCONSTELLATION)}¨⍳332"],
    capture_output=True, text=True, timeout=30
)

stars = {}  # index -> (name, ra, dec, const)
for line in result.stdout.strip().split('\n'):
    line = line.strip()
    if not line or line.startswith('Linked'):
        continue
    # Last field is constellation (3 chars), before that dec and ra (floats)
    # First field is index, middle is name (may contain spaces)
    parts = line.split()
    if len(parts) < 5:
        continue
    idx = int(parts[0])
    const = parts[-1]
    dec = float(parts[-2].replace('¯', '-'))
    ra = float(parts[-3].replace('¯', '-'))
    name = ' '.join(parts[1:-3])
    stars[idx] = (name, ra, dec, const)

# Get constellation data from APL
result2 = subprocess.run(
    ['gritt', '-l',
     '-link', 'sm:/Users/nk/dev/STARMAP/APLSource',
     '-e', "⎕PW←1000",
     '-e', "{C←⍵⊃sm.CONSTELLATIONS ⋄ N←1⊃C ⋄ P←2⊃C ⋄ ⎕←N,' ',⍕,P}¨⍳≢sm.CONSTELLATIONS"],
    capture_output=True, text=True, timeout=30
)

constellations = {}  # name -> list of (idx1, idx2) pairs
for line in result2.stdout.strip().split('\n'):
    line = line.strip()
    if not line or line.startswith('Linked'):
        continue
    parts = line.split()
    if len(parts) < 3:
        continue
    name = parts[0]
    nums = [int(x) for x in parts[1:]]
    pairs = [(nums[i], nums[i+1]) for i in range(0, len(nums), 2)]
    constellations[name] = pairs

# Generate SVG for each constellation
svg_parts = []
cols = 4
row_h = 500
col_w = 500
per_page = 16  # 4x4 per page
sorted_const = sorted(constellations.items())
total = len(sorted_const)
pages = (total + per_page - 1) // per_page

for page in range(pages):
    svg_parts = []
    page_items = sorted_const[page*per_page:(page+1)*per_page]
    page_rows = (len(page_items) + cols - 1) // cols
    svg_parts.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{cols*col_w}" height="{page_rows*row_h}">')
    svg_parts.append('<rect width="100%" height="100%" fill="#0a0a2a"/>')
    svg_parts.append('<style>text{font-family:monospace;fill:#ccc;font-size:13px} .title{font-size:20px;fill:#fff;text-anchor:middle}</style>')

    for ci, (cname, pairs) in enumerate(page_items):
        row = ci // cols
        col = ci % cols
        ox = col * col_w + 20
        oy = row * row_h + 20
        pw = col_w - 40
        ph = row_h - 60

        # Collect all star indices for this constellation
        all_idx = set()
        for a, b in pairs:
            all_idx.add(a)
            all_idx.add(b)

        if not all_idx:
            continue

        # Get RA/Dec for these stars
        ras = [stars[i][1] for i in all_idx]
        decs = [stars[i][2] for i in all_idx]

        # Scale to fit box (RA inverted to match sky view)
        ra_min, ra_max = min(ras), max(ras)
        dec_min, dec_max = min(decs), max(decs)

        # Handle RA wrapping (if range > 12h, stars cross 0h)
        ra_range = ra_max - ra_min
        if ra_range > 12:
            ras_shifted = [(r + 24) % 24 if r < 12 else r for r in ras]
            ra_min, ra_max = min(ras_shifted), max(ras_shifted)
            ra_range = ra_max - ra_min
            ra_map = {i: (stars[i][1] + 24) % 24 if stars[i][1] < 12 else stars[i][1] for i in all_idx}
        else:
            ra_map = {i: stars[i][1] for i in all_idx}

        dec_range = dec_max - dec_min
        if ra_range == 0: ra_range = 1
        if dec_range == 0: dec_range = 1

        ra_pad = ra_range * 0.15
        dec_pad = dec_range * 0.15

        def to_xy(idx, ox=ox, oy=oy, pw=pw, ph=ph, ra_min=ra_min, ra_range=ra_range, ra_pad=ra_pad, dec_min=dec_min, dec_range=dec_range, dec_pad=dec_pad, ra_map=ra_map):
            ra = ra_map[idx]
            dec = stars[idx][2]
            x = ox + pw - (ra - (ra_min - ra_pad)) / (ra_range + 2*ra_pad) * pw
            y = oy + ph - (dec - (dec_min - dec_pad)) / (dec_range + 2*dec_pad) * ph
            return x, y

        svg_parts.append(f'<text class="title" x="{ox + pw/2}" y="{oy - 5}">{cname}</text>')

        for a, b in pairs:
            x1, y1 = to_xy(a)
            x2, y2 = to_xy(b)
            svg_parts.append(f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="#446" stroke-width="1.5"/>')

        for idx in all_idx:
            x, y = to_xy(idx)
            name = stars[idx][0]
            bright = len(name) > 2 and name[0].isupper() and name[1].islower()
            r = 5 if bright else 3
            fill = "#ffd700" if bright else "#aaa"
            svg_parts.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r}" fill="{fill}"/>')
            svg_parts.append(f'<text x="{x+8:.1f}" y="{y+4:.1f}">{name}</text>')

    svg_parts.append('</svg>')

    outpath = f'/Users/nk/dev/STARMAP/scripts/constellations_page{page+1}.svg'
    with open(outpath, 'w') as f:
        f.write('\n'.join(svg_parts))
    print(f"Written page {page+1}: {len(page_items)} constellations -> {outpath}")

print(f"\n{total} constellations across {pages} pages")
