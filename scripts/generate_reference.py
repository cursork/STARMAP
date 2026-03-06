#!/usr/bin/env python3
"""Generate reference RA/Dec positions using Skyfield and JPL ephemeris.

Produces APLSource/reference_positions.aplf — a 334x2 matrix of apparent
RA (hours) and Dec (degrees) for the Anaheim test case:
  - Rows 1–332: stars (precessed from J2000 to observation epoch)
  - Row 333: Moon (geocentric apparent)
  - Row 334: Sun (geocentric apparent)

Observation: 1974-05-16 05:00 UTC (Anaheim, CA)

Requires: pip install skyfield
"""

import re
import sys
from pathlib import Path

from skyfield.api import Star, load
from skyfield.positionlib import Apparent

SCRIPT_DIR = Path(__file__).parent
PROJECT_DIR = SCRIPT_DIR.parent
APL_DIR = PROJECT_DIR / 'APLSource'
STARS_PATH = APL_DIR / 'STARS.aplf'
OUTPUT_PATH = APL_DIR / 'reference_positions.aplf'

# Observation parameters (Anaheim test case)
OBS_YEAR = 1974
OBS_MONTH = 5
OBS_DAY = 16
OBS_HOUR = 5
OBS_MINUTE = 0
OBS_SECOND = 0


def parse_stars(path):
    """Parse STARS.aplf and return list of (ra_hours, dec_degrees) tuples."""
    text = path.read_text()
    # Replace APL high minus with regular minus
    text = text.replace('¯', '-')
    # Extract the numeric values after the reshape: 332 2⍴...
    match = re.search(r'332\s+2⍴(.+)', text, re.DOTALL)
    if not match:
        raise ValueError('Could not find 332 2⍴ in STARS.aplf')
    nums_text = match.group(1).strip()
    nums = [float(x) for x in nums_text.split()]
    if len(nums) != 664:
        raise ValueError(f'Expected 664 values, got {len(nums)}')
    stars = []
    for i in range(0, 664, 2):
        stars.append((nums[i], nums[i + 1]))
    return stars


def format_apl_float(value):
    """Format a float for APL (use ¯ for negative)."""
    s = f'{value:.6f}'
    if s.startswith('-'):
        s = '¯' + s[1:]
    return s


def main():
    print('Loading Skyfield timescale and ephemeris...')
    ts = load.timescale()
    eph = load('de421.bsp')
    earth = eph['earth']
    t = ts.utc(OBS_YEAR, OBS_MONTH, OBS_DAY, OBS_HOUR, OBS_MINUTE, OBS_SECOND)

    print(f'Observation time: {t.utc_iso()}')

    # --- Stars ---
    print('Parsing STARS.aplf...')
    star_data = parse_stars(STARS_PATH)
    print(f'  {len(star_data)} stars loaded')

    print('Computing apparent star positions (equinox of date)...')
    star_results = []
    for i, (ra_h, dec_d) in enumerate(star_data):
        star = Star(ra_hours=ra_h, dec_degrees=dec_d)
        astrometric = earth.at(t).observe(star)
        apparent = astrometric.apparent()
        ra, dec, _ = apparent.radec(epoch='date')
        star_results.append((ra.hours, dec.degrees))

    # --- Moon ---
    print('Computing Moon position (equinox of date)...')
    moon = eph['moon']
    astrometric = earth.at(t).observe(moon)
    apparent = astrometric.apparent()
    moon_ra, moon_dec, _ = apparent.radec(epoch='date')
    moon_result = (moon_ra.hours, moon_dec.degrees)
    print(f'  Moon: RA {moon_ra.hours:.4f}h, Dec {moon_dec.degrees:.4f}°')

    # --- Sun ---
    print('Computing Sun position (equinox of date)...')
    sun = eph['sun']
    astrometric = earth.at(t).observe(sun)
    apparent = astrometric.apparent()
    sun_ra, sun_dec, _ = apparent.radec(epoch='date')
    sun_result = (sun_ra.hours, sun_dec.degrees)
    print(f'  Sun:  RA {sun_ra.hours:.4f}h, Dec {sun_dec.degrees:.4f}°')

    # --- Write APL function file ---
    print(f'Writing {OUTPUT_PATH}...')
    all_results = star_results + [moon_result, sun_result]
    n = len(all_results)
    assert n == 334, f'Expected 334 rows, got {n}'

    lines = []
    lines.append(' Z←reference_positions')
    lines.append(f'⍝ Reference positions: Skyfield/JPL DE421, {OBS_YEAR}-{OBS_MONTH:02d}-{OBS_DAY:02d} {OBS_HOUR:02d}:{OBS_MINUTE:02d} UTC')
    lines.append('⍝ Rows 1-332: stars (apparent RA hours, Dec degrees)')
    lines.append('⍝ Row 333: Moon, Row 334: Sun')

    # Build flat vector, then reshape at end
    all_values = []
    for ra, dec in all_results:
        all_values.append(format_apl_float(ra))
        all_values.append(format_apl_float(dec))

    # First chunk starts the vector
    chunk_size = 20  # 10 pairs per line
    lines.append(' Z←' + ' '.join(all_values[:chunk_size]))

    # Remaining chunks catenated
    for i in range(chunk_size, len(all_values), chunk_size):
        chunk = all_values[i:i + chunk_size]
        lines.append(' Z←Z,' + ' '.join(chunk))

    # Reshape to matrix
    lines.append(f' Z←{n} 2⍴Z')

    OUTPUT_PATH.write_text('\n'.join(lines) + '\n')
    print(f'Done. {n} positions written ({n - 2} stars + Moon + Sun)')

    # --- Summary stats ---
    # Compare J2000 vs apparent for a few notable stars
    notable = [
        (0, 'Alpheratz'),
        (26, 'Arcturus'),
        (176, 'Sirius (aCMa)'),
    ]
    print('\nSample precession shifts (J2000 → apparent):')
    for idx, name in notable:
        j2000_ra, j2000_dec = star_data[idx]
        app_ra, app_dec = star_results[idx]
        dra = (app_ra - j2000_ra) * 15  # degrees
        ddec = app_dec - j2000_dec
        print(f'  {name}: dRA={dra:+.4f}°, dDec={ddec:+.4f}°')


if __name__ == '__main__':
    main()
