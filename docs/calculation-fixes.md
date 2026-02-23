# Calculation fixes

This document records every calculation bug found in the STARMAP program, the mathematical analysis that identified each bug, the fix applied, and how the fix was validated.

The original program was transcribed from *STARMAP* by Paul C. Berry and John R. Thorstensen (APL Press, 1978). The bugs documented here are transcription errors — typos, OCR misreads, or APL dialect confusions — not errors in the original algorithm design.

---

## Coordinate computation pipeline

For context, the pipeline that transforms celestial coordinates to plotted positions is:

```
Star catalog (RA, Dec)     Orbital elements       Moon elements
        |                          |                     |
        v                          v                     v
    PRECESS                   PLANETPOS → EARTHVIEW  PLANETPOS → MOONPOS
        |                          |                     |
        v                          v                     v
      (RA, Dec at current epoch)  (RA, Dec geocentric)  (RA, Dec geocentric)
                    \               |                   /
                     v              v                  v
                          SKYPOS (Alt, Az)
                                |
                                v
                          PROJECTION (stereographic)
                                |
                                v
                          MAPCARTESIAN (x, y for plot)
                                |
                                v
                            PLOTSTARS (ASCII grid)
```

Every function in this chain has been checked. Bugs were found at six stages: JNU (date input), PRECESS (precession), MOONPOS (Moon coordinates), SKYPOS (horizon transformation), MAPCARTESIAN (projection), and the `planets`/`moon` data tables. There are also shape/rank bugs and derivative errors in auxiliary functions.

---

## Bug index

| # | File | Line | Type | Severity | Section |
|---|------|------|------|----------|---------|
| 1 | JNU.aplf | 9 | APL precedence | Critical | [JNU](#1-jnu-gregorian-correction) |
| 2 | SKYPOS.aplf | 14 | Sign error | Critical | [SKYPOS azimuth](#2-skypos-azimuth-quadrant-sign) |
| 3 | SKYPOS.aplf | 10–11 | Syntax/shape | Blocking | [SKYPOS normalisation](#3-skypos-normalisation) |
| 4 | SKYPOS.aplf | 15 | Shape mismatch | Major | [SKYPOS arccos argument](#4-skypos-arccos-argument) |
| 5 | MAPCARTESIAN.aplf | 4 | ⊖ vs ⌽ | Critical | [MAPCARTESIAN](#5-mapcartesian-axis-swap) |
| 6 | EARTH.aplf | 3 | Shape | Blocking | [EARTH shape](#6-earth-shape) |
| 7 | ORBROTATE.aplf | 12 | Reshape | Blocking | [ORBROTATE reshape](#7-orbrotate-reshape) |
| 8 | EARTHVIEW.aplf | 3 | Shape | Blocking | [EARTHVIEW shape](#8-earthview-shape) |
| 9 | AREADERIV.aplf | 3 | Wrong coefficient | Blocking | [AREADERIV](#9-areaderiv-coefficient) |
| 10 | CALCULATEPLANETS.aplf | 5,12–13 | Logic | Major | [CALCULATEPLANETS](#10-calculateplanets) |
| 11 | CALCULATESTARS.aplf | 4–7 | Name conflict | Blocking | [CALCULATESTARS](#11-calculatestars) |
| 12 | planets.aplf | 5 | Wrong epoch | Critical | [Planet epoch](#12-planet-epoch-inconsistency) |
| 13 | PRECESS.aplf | 8 | ⊖ vs identity | Critical | [PRECESS row-reversal](#13-precess-row-reversal) |
| 14 | CALCULATESTARS.aplf | 5 | Wrong interval | Critical | [CALCULATESTARS precession interval](#14-calculatestars-precession-interval) |
| 15 | PRECESS.aplf | 6 | Sign error | Critical | [PRECESS sign](#15-precess-precession-direction) |
| 16 | MOONPOS.aplf | 4 | Sign error | Critical | [MOONPOS tilt sign](#16-moonpos-ecliptic-tilt-sign) |
| 17 | moon.aplf | 5 | Decimal point | Critical | [Moon secular rates](#17-moon-secular-drift-rates) |

Severity levels:
- **Critical**: produces systematically wrong sky positions
- **Major**: wrong output but doesn't prevent execution
- **Blocking**: causes a runtime error (RANK, LENGTH, DOMAIN, etc.)

---

## 1. JNU: Gregorian correction

**File:** `JNU.aplf` line 9
**Type:** APL right-to-left precedence error
**Severity:** Critical — all Julian day numbers off by −8, causing ~5° sidereal time error and 8-day planetary ephemeris shift

### The bug

The Meeus formula for the Gregorian correction in the Julian day number is:

    B = 2 − A + ⌊A/4⌋

where A = ⌊Y/100⌋. In standard mathematical notation this is unambiguous. In APL, the expression:

```apl
B←2-A+⌊A÷4
```

evaluates right-to-left as `2 − (A + ⌊A÷4⌋)`, giving the wrong result:

| | Standard | APL (buggy) |
|---|---------|-------------|
| Formula | 2 − A + ⌊A/4⌋ | 2 − (A + ⌊A/4⌋) |
| For Y=1974, A=19 | 2 − 19 + 4 = **−13** | 2 − (19 + 4) = **−21** |
| Difference | | **−8** |

Every Julian day number computed by JNU was 8 less than the correct value.

### Impact

The constant `EQUINOX` (2441762.5, the JD of the 1973 vernal equinox) and the planetary epoch dates in the `planets` table are external reference values — they use correct Julian day numbers. Since `DATE` was computed by the buggy JNU, `DATE − EQUINOX` was systematically 8 days too small, causing:

1. **Sidereal time error**: SUN is wrong by 8 × 24/365.24 ≈ 0.53 hours ≈ 7.9°
2. **Planetary positions**: computed for 8 days earlier than intended. For Saturn (period 29.5 yr) the error is ~0.07° (negligible); for Mercury (period 0.24 yr) it is ~3.3° (noticeable)

### Fix

```apl
⍝ Before (buggy):
B←2-A+⌊A÷4

⍝ After (correct):
B←(2-A)+⌊A÷4
```

### Collateral: JNUINV

The inverse function JNUINV contained a two-pass algorithm to compensate for JNU's bug (offset `OFF←2×⌊A÷4`). After fixing JNU, JNUINV is simplified to the standard Meeus inverse plus a round-trip safety check.

### Validation

After the fix, JNU gives the correct Julian day number for all test dates:

| Date | JNU (original) | JNU (paren fix only) | JNU (final) | Correct JD |
|------|----------------|---------------------|-------------|------------|
| 1 Jan 2000 | 2451536.5 | 2451544.5 | 2451544.5 | 2451544.5 |
| 16 May 1974 | 2442175.5 | 2442183.5 | 2442183.5 | 2442183.5 |
| 4 Jul 1776 | 2369907.5 | 2369915.5 | 2369915.5 | 2369915.5 |
| 1 Jan 1900 | 2415012.5 | 2415020.5 | 2415020.5 | 2415020.5 |
| 21 Mar 1973 | 2441754.5 | 2441762.5 | 2441762.5 | 2441762.5 |

---

## 2. SKYPOS: azimuth quadrant sign

**File:** `SKYPOS.aplf` line 14
**Type:** Negated sign in azimuth quadrant determination
**Severity:** Critical — all azimuths reflected East ↔ West, causing objects to cluster on one side of the sky

### The bug

After the equatorial-to-horizontal coordinate rotation, the transformed vector (x, y, z) has:
- y = sin(altitude)
- x, z = horizontal plane components

The azimuth is extracted from x and z. In the program's coordinate system, after `(LONGROTATE ROT)+.×LATROTATE LAT`:
- −x direction = North (azimuth 0°)
- +z direction should be East (azimuth 90°)

But the z-component is **negated** relative to the standard astronomical convention. The code uses `S←×GQ[;3]` (sign of z) to determine the East/West hemisphere, which assigns the wrong quadrant.

### Mathematical proof

The rotation matrix product `(LONGROTATE ω) +.× (LATROTATE L)` where L = colatitude gives, for input vector v = (cos δ cos α, sin δ, −cos δ sin α):

    result[1] = cos δ cos(lat) cos(α − ω) + sin δ sin(lat)

This matches the standard altitude formula when ω = π × LST / 12 (see section on SKYPOS validation below). For the z-component:

    result[2] = −cos δ sin(α − ω) cos(lat) − ... (details in working notes)

The z-component has the opposite sign from what the azimuth extraction formula expects. Negating S corrects this.

### Fix

```apl
⍝ Before (buggy):
S←×GQ[;3]

⍝ After (correct):
S←-×GQ[;3]
```

### What is NOT broken: line 12

The rotation matrix on line 12:

```apl
GQ←GQ+.×(LONGROTATE ROT)+.×LATROTATE LAT
```

is **correct as-is**. The TODO file speculated the original book had `⊖` (row-reversal) here, but analysis proves the current matrix product is mathematically right — it produces correct altitudes and correct x-components. Only the z-sign needs correction (bug #2 above).

### Validation

See the combined validation section below.

---

## 3. SKYPOS: normalisation (previously fixed)

**File:** `SKYPOS.aplf` lines 10–11
**Severity:** Blocking (syntax error)

### The bug

The book's line was:

```apl
GQ←GQ÷(⊖(⌽⍴GQ)⍴NORM GQ←CARTRIPLET GQ
```

Unpaired parenthesis, unclear intent.

### Fix (applied in earlier session)

Split into two clear lines:

```apl
GQ←CARTRIPLET GQ
GQ←GQ÷(NORM GQ)∘.×3⍴1
```

---

## 4. SKYPOS: arccos argument (previously fixed)

**File:** `SKYPOS.aplf` line 15
**Severity:** Major (shape mismatch in azimuth)

### The bug

The original `ARCCOS GQ[;1 3]÷NORM GQ[;1 3]` passed an N×2 matrix to ARCCOS. Only column 1 (the x-component) should be used.

### Fix (applied in earlier session)

```apl
⍝ Before:
AZ←(360×S≥0)+NEG×DEGREES ARCCOS GQ[;1 3]÷NORM GQ[;1 3]

⍝ After:
AZ←(360×S≤0)+S×DEGREES ARCCOS(-GQ[;1])÷NORM GQ[;1 3]
```

Note: the `S≥0` → `S≤0` change was part of this fix. With bug #2 now also fixed (`S←-×GQ[;3]`), the overall azimuth formula is correct.

---

## 5. MAPCARTESIAN: axis swap (previously fixed)

**File:** `MAPCARTESIAN.aplf` line 4
**Severity:** Critical (coordinates outside unit circle)

### The bug

`⊖` (reverse rows) was used where `⌽` (reverse columns) was needed. In the original printed book the glyphs ⊖ and ⌽ are easily confused.

### Fix (applied in earlier session)

```apl
⍝ Before:
Z←⊖CARTESIAN⊖X

⍝ After:
Z←⌽CARTESIAN⌽X
```

---

## 6–11. Previously fixed bugs (summary)

These bugs were fixed in earlier sessions and are documented in `CHANGES.md`:

| # | File | Issue | Fix |
|---|------|-------|-----|
| 6 | EARTH.aplf | Returned vector not matrix | `Z←planets[,3;]` |
| 7 | ORBROTATE.aplf | Wrong reshape formula | `H←(¯1↓⍴H)⍴H` |
| 8 | EARTHVIEW.aplf | Failed on vector input (sun=0 0 0) | Added `H←(1,⍴H)⍴⍣(1=≢⍴H)⊢H` |
| 9 | AREADERIV.aplf | Wrong derivative coefficient (1/8 vs 3/4) | `Z←(PERIDIST÷2)+(3×X*2)÷4×PERIDIST` |
| 10 | CALCULATEPLANETS.aplf | Moon duplication, Earth in planet list | `1 0↓PLANETS`, excluded row 3 |
| 11 | CALCULATESTARS.aplf | Assigned to function name BRIGHT | Used local BRIGHTVIS variable |

Full details for each are in `CHANGES.md`.

---

## 12. Planet epoch inconsistency

**File:** `planets.aplf` line 5, column 10 (DATE_ASC)
**Type:** Epoch mismatch between ANOMALY values and their stated epoch date
**Severity:** Critical — all planet RA/Dec wrong by large amounts (Sun off by 3.4h, Mars by 9.5h)

### The bug

The `planets` table stores orbital elements in an 9x11 matrix. Column 7 (ANOMALY) holds mean anomaly values, and column 10 (DATE_ASC) stores the epoch at which those anomaly values are valid. Both columns originally contained JD 2443600.5 (2 April 1978).

However, the ANOMALY values are actually from the *American Ephemeris and Nautical Almanac for 1973* — they correspond to an epoch of approximately JD 2441720.5 (January 1973). The book (published 1978) appears to have propagated some orbital elements forward to JD 2443600.5 (ASCENDING via SECULAR_ASC, and PERIANGLE via SECULAR_PERI) but did not propagate the ANOMALY values to match.

The result: `PLANETPOS` computes mean anomaly as `ANOMALY + (DATE - ANOMALYDATE) * 360/PERIOD`, where `ANOMALYDATE` is column 10. With the wrong epoch, the elapsed time is ~1880 days too small, shifting every planet's position by hundreds of degrees.

### Impact

Using the Anaheim test case (16 May 1974, 05:00 UTC), the epoch error produces:

| Planet | Computed RA (broken) | JPL reference RA | Error |
|--------|---------------------|-----------------|-------|
| Sun | 0h 09m | 3h 31m | 3.4h |
| Mars | 16h 36m | 7h 09m | 9.5h |
| Jupiter | 12h 07m | 23h 03m | 10.9h |

### Fix

Change column 10 (DATE_ASC) from `2443600.5` to `2441720.5` for all 9 rows. Column 11 (DATE_PERI, used for PERIANGLE secular drift) remains at `2443600.5` since the PERIANGLE values appear to have been propagated to that epoch.

### Validation

After the fix, computed planet positions match JPL Horizons to within 1–7 minutes of RA:

| Planet | Computed RA/Dec | JPL RA/Dec | RA error |
|--------|----------------|------------|----------|
| Sun | 3h 30m, +19° | 3h 31m, +19° | 1m |
| Mercury | 4h 25m, +23° | 4h 26m, +23° | 1m |
| Mars | 7h 08m, +24° | 7h 09m, +24° | 1m |
| Jupiter | 23h 02m, -7° | 23h 03m, -7° | 1m |
| Saturn | 6h 20m, +23° | 6h 13m, +23° | 7m |

The remaining 7-minute Saturn error is consistent with the simplified Keplerian model (no perturbation corrections).

---

## 13. PRECESS: row-reversal

**File:** `PRECESS.aplf` line 8
**Type:** Transcription error (⊖ instead of identity)
**Severity:** Critical — precessed star positions are garbage (RA shifted by ~10 hours)

### The bug

The final line of PRECESS applies the combined precession rotation matrix to the star position vector:

```apl
Z←2 RADECDIST X+.×⊖ROT
```

The `⊖` (row-reversal) operator swaps the first and third rows of the 3x3 rotation matrix. This exchanges the first and third basis vectors, producing a completely wrong transformation. It is not transpose (`⍉`), not inverse, and not any meaningful operation on a rotation matrix.

Evidence from the Anaheim test case (Arcturus, J2000 RA=14.26h):
- `X +.× ROT` (⊖ removed): RA = 14.28h (correct ~0.02h precession shift)
- `X +.× ⊖ROT` (buggy): RA = 3.76h (10h shift — garbage)

The `⊖` is likely a misread of `⍉` (transpose) from the printed book, as these glyphs are easily confused. However, analysis shows `ROT` without any transformation is correct: the rotation matrices produced by `LONGROTATE`/`INCLROTATE` are already in the convention suitable for right-multiplication via `X +.× M`.

### Fix

```apl
⍝ Before (buggy):
Z←2 RADECDIST X+.×⊖ROT

⍝ After (correct):
Z←2 RADECDIST X+.×ROT
```

### Validation

With the fix, `EARTH SKYPOS DATE PRECESS ARC` gives Arcturus alt = +66.6° (matches the no-precession case and JPL reference). Before the fix, it gave -44.0° (below horizon — completely wrong).

---

## 14. CALCULATESTARS: precession interval

**File:** `CALCULATESTARS.aplf` line 5
**Type:** Wrong argument to PRECESS (absolute JD instead of interval)
**Severity:** Critical — 93° of spurious precession even with bug #13 fixed

### The bug

`CALCULATESTARS` passes the absolute Julian day number (`DATE`, ~2.4 million) as the precession interval:

```apl
STARDATA←(LAT,DATE,TIME)SKYPOS DATE PRECESS STARS
```

`PRECESS` interprets its left argument as the number of days to precess. The star catalog uses J2000 epoch (JD 2451545), so the correct interval is `DATE - 2451545` (typically a few thousand days for 1970s observations). Passing the raw JD causes ~93° of spurious precession.

### Fix

A new constant `CATEPOCH` (value 2451545, the J2000.0 epoch JD) is defined in `CATEPOCH.apla`. The fix passes the interval from the catalog epoch:

```apl
⍝ Before (buggy):
STARDATA←(LAT,DATE,TIME)SKYPOS DATE PRECESS STARS

⍝ After (correct):
STARDATA←(LAT,DATE,TIME)SKYPOS(DATE-CATEPOCH)PRECESS STARS
```

For the Anaheim test case (16 May 1974), `DATE` ≈ 2442183.5, so the interval is 2442183.5 - 2451545 = -9361.5 days ≈ -25.6 years. The precession over this interval is ~0.36°, which is the correct order of magnitude.

---

## 15. PRECESS: precession direction

**File:** `PRECESS.aplf` line 6
**Type:** Sign error in precession angle
**Severity:** Critical — stars precessed in the wrong direction (~0.7° total error for 26-year interval)

### The bug

The precession rotation angle was not negated to account for the row-vector multiplication convention `X +.× M`. In APL, `X +.× M` applies the transformation as `M^T · X^T` in column-vector notation, which reverses the effective rotation direction. The precession angle needs to be negated to compensate.

With the wrong sign, stars were precessed forward when they should have been precessed backward (for dates before J2000), doubling the error.

### Fix

```apl
⍝ Before:
PRECESSION←LONGROTATE INTERVAL×2×PI÷25800×YRLENGTH

⍝ After:
PRECESSION←LONGROTATE-INTERVAL×2×PI÷25800×YRLENGTH
```

### Validation

After the fix, all 332 stars match Skyfield/JPL reference positions (equinox of date) to within 0.01° (max error 0.0097°), compared to 0.72° before the fix.

---

## 16. MOONPOS: ecliptic tilt sign

**File:** `MOONPOS.aplf` line 4
**Type:** Wrong sign for ecliptic-to-equatorial rotation
**Severity:** Critical — Moon declination wrong by ~24° (full obliquity swing)

### The bug

`MOONPOS` uses `INCLROTATE RADIAN AXITILT` (positive rotation) but `EARTHVIEW` uses `INCLROTATE-RADIAN AXITILT` (negative rotation). Both convert ecliptic coordinates to equatorial coordinates. Since `EARTHVIEW` is validated correct for all planet positions, the negative sign is the correct convention.

### Fix

```apl
⍝ Before:
GQ←3 RADECDIST GC+.×INCLROTATE RADIAN AXITILT

⍝ After:
GQ←3 RADECDIST GC+.×INCLROTATE-RADIAN AXITILT
```

---

## 17. Moon secular drift rates

**File:** `moon.aplf` line 5, columns 8–9
**Type:** Decimal point transcription error (rates 10× too small)
**Severity:** Critical — Moon position off by ~160° due to accumulated node/periapse error

### The bug

The Moon's secular drift rates for the ascending node and argument of periapse were exactly 10× too small — a decimal point transcription error from the printed book:

| Parameter | Book value | Correct value | Known rate |
|-----------|-----------|---------------|------------|
| SECULAR_ASC (deg/day) | −0.0052953922 | −0.052953922 | −0.05300 (18.6-yr period) |
| SECULAR_PERI (deg/day) | 0.01114040803 | 0.1114040803 | 0.11134 (8.85-yr period) |

Over the 74-year interval from the 1900 epoch to 1974, the accumulated error in the ascending node was 1296° (3.6 full rotations), making the Moon's ecliptic longitude wrong by ~200°.

### Fix

```apl
⍝ Before:
Z←1 11⍴1 0.07544 0.05490 5.14342 260.38369 331.80423 0 ¯0.0052953922 0.01114040803 2414997.831 2414997.831

⍝ After:
Z←1 11⍴1 0.07544 0.05490 5.14342 260.38369 331.80423 0 ¯0.052953922 0.1114040803 2414997.831 2414997.831
```

### Validation

After all three Moon fixes (#15, #16, #17), the computed Moon position for the Anaheim test case matches JPL Horizons to 2.5°:

| | Computed | JPL reference | Error |
|---|---------|--------------|-------|
| RA | 23h 07m | 22h 58m | 2.3h (in RA), 2.5° angular |
| Dec | 0° | −1° | 1° |

The 2.5° residual is consistent with the simplified Keplerian model (no solar perturbations, no evection, no variation). The Moon phase also corrected from "0.51 WAXING" to "0.3 WANING" (actual: 25% waning crescent).

---

## Combined validation

### Method

The fixes were validated by comparing computed star and planet positions against reference data from NASA/JPL Horizons for 5 geographically diverse test cases:

| Location | Date/time (UTC) | Latitude | Longitude |
|----------|-----------------|----------|-----------|
| Anaheim, CA | 16 May 1974 05:00 | 33.767°N | 117.833°W |
| Philadelphia, PA | 15 Jan 1974 02:00 | 40.0°N | 75.0°W |
| London, UK | 21 Jun 1974 22:00 | 51.5°N | 0.0° |
| Sydney, AU | 25 Dec 1974 12:00 | 33.87°S | 151.21°E |
| Tokyo, JP | 20 Mar 1975 18:00 | 35.68°N | 139.69°E |

Reference stars: Polaris, Arcturus, Sirius, Vega, Antares, Canopus. For Anaheim, planet RA/Dec validated against JPL Horizons (see [bug #12](#12-planet-epoch-inconsistency)).

### Results (fixed JNU + fixed azimuth sign)

| Location | LST error | Star position RMS |
|----------|-----------|-------------------|
| Anaheim | 0.175h (2.6°) | 1.78° |
| Philadelphia | 0.175h (2.6°) | 3.09° |
| London | 0.175h (2.6°) | 1.87° |
| Sydney | 0.175h (2.6°) | 1.76° |
| Tokyo | 0.175h (2.6°) | 2.14° |

The constant 2.6° LST error is inherent to the program's simple sidereal time formula (`SUN + TIME − 12`, where SUN approximates the mean sun's right ascension). This is typical accuracy for a simplified formula that ignores the equation of time, nutation, and other corrections. The 1973 program was designed for educational/illustrative use, not navigation.

### Anaheim detail (primary test case, vs JPL Horizons)

| Object | Computed Alt | Ref Alt | Computed Az | Ref Az | Error |
|--------|-------------|---------|-------------|--------|-------|
| Arcturus | +66.6° | +65.0° | 123.3° | 119.6° | 4.0° |
| Regulus | +46.4° | +48.5° | 250.3° | 248.0° | 3.1° |
| Spica | +44.6° | +44.2° | 169.4° | 165.9° | 3.6° |
| Vega | +23.4° | +21.5° | 57.9° | 56.9° | 2.1° |
| Polaris | +33.0° | +33.0° | 359.7° | 359.6° | 0.1° |
Objects are correctly distributed across the full sky (N, NE, E, SE, S, W, WNW) rather than clustering in one quadrant.

Note: planet Alt/Az values were validated before the epoch fix (bug #12). With the epoch fix, planet RA/Dec values match JPL Horizons to within 1–7 minutes — see the [bug #12 validation table](#12-planet-epoch-inconsistency) for details.

### Before fixes (for comparison)

With the buggy code, the same Anaheim test case gives RMS error of **70.6°** with all objects clustered in the west-northwest quadrant (azimuth 228–313°).

### Updated results (after all 17 bugs fixed)

With all bugs fixed, the full pipeline was validated against Skyfield/JPL DE421 reference positions for the Anaheim test case using `TEST_POSITIONS`:

| Category | Objects | Max error | Tolerance | Method |
|----------|---------|-----------|-----------|--------|
| Stars | 332 | 0.010° | 0.15° | Skyfield apparent RA/Dec (equinox of date) |
| Moon | 1 | 2.5° | 10° | JPL DE421 ephemeris |
| Sun | 1 | 0.006° | 3° | JPL DE421 ephemeris |

The star precession error (0.01°) is dominated by the difference between the program's simplified linear precession model and the full IAU 2006 model, plus the absence of nutation and aberration corrections. The Moon error (2.5°) reflects the limitations of the simplified Keplerian orbit model (no solar perturbations, evection, or variation terms). Both are consistent with design limitations, not residual bugs.

---

## Input convention

The program expects the user to enter **UTC (Greenwich civil time)**, not local clock time. The `ENTRY` function adjusts:

- `TIME ← STATEDTIME + LONG/15` converts UTC to local solar time for the hour-angle calculation in SKYPOS
- `DATE ← STATEDDAYNO + TIME/24 − LONG/360` computes the Julian date (the longitude terms cancel, giving `STATEDDAYNO + STATEDTIME/24`)

For the EXAMPLE_RENDER test case (Anaheim, 10 PM PDT, 15 May 1974):
- PDT = UTC − 7, so 10 PM PDT = 05:00 UTC on 16 May
- Enter: date = 5 16 1974, time = 5

---

## Remaining approximations

These are design limitations of the original 1973 program, not bugs:

1. **Sidereal time**: `SUN + TIME − 12` approximates LST to ~2.6° (0.175h). A more accurate formula would use the IAU GMST equation, but this would change the program's character
2. **Precession**: uses a simple linear rate (25,800-year period). Modern IAU precession has additional terms. Nutation and aberration are not modelled
3. **Planetary positions**: Keplerian two-body with secular drift. No perturbation corrections
4. **Moon position**: Keplerian orbit with secular drift of node and periapse. No solar perturbations (evection, variation, annual equation). Residual error ~2.5° against JPL
5. **Star catalog**: epoch J2000 positions precessed to observation date. Proper motion is ignored
6. **Refraction**: not modelled. Objects near the horizon appear ~0.5° higher than computed
