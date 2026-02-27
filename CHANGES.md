# STARMAP modernization: changes and recommendations

This document covers all changes made to bring STARMAP to working order in modern Dyalog APL, along with suggestions for future improvements.

## Overview

STARMAP is a 1973 APL program for generating star maps. The code was transcribed from the book "STARMAP" by Paul C. Berry & John R. Thorstensen (APL Press, 1978). During modernization, several issues were discovered:

1. **Transcription errors** - typos or OCR errors from the original printed source
2. **APL dialect differences** - syntax that worked in 1970s IBM APL but not in modern Dyalog
3. **Shape/rank issues** - functions that assumed specific array shapes
4. **Logic errors** - incorrect formulas or algorithms
5. **Data errors** - wrong constants or decimal places in orbital element tables

---

## Fixes applied

### 1. EARTH.aplf (line 3)

**Problem:** Function returned a vector instead of a 1x11 matrix.

**Original (incorrect):**
```apl
Z←(planets)[3;]
```

**Fixed:**
```apl
Z←planets[,3;]
```

**Explanation:** The orbital element accessor functions (SEMIMAJOR, PERIOD, etc.) use `ORB[;N]` indexing which requires ORB to be a matrix. When EARTH returned a vector, downstream functions like EPOCHADJUST failed with RANK ERROR.

The `,3` in `planets[,3;]` ravels the index, preserving the row dimension and returning a 1x11 matrix.

---

### 2. ORBROTATE.aplf (line 12)

**Problem:** Incorrect reshape produced wrong output shape.

**Original (incorrect):**
```apl
H←((1↓⍴H),×/1↑⍴H)⍴H
```

**Fixed:**
```apl
H←(¯1↓⍴H)⍴H
```

**Explanation:** After matrix multiplications, H has shape NxCx1 (planets x coordinates x 1). The goal is to produce Nx3.

The original formula `((1↓⍴H),×/1↑⍴H)` with H of shape 9 3 1 gives:
- `1↓⍴H` = 3 1
- `×/1↑⍴H` = 9
- Reshape to (3 1),9 = 3 1 9 — wrong

The fix `(¯1↓⍴H)` simply drops the trailing dimension, giving 9 3.

**Note:** The original book shows `H←((1+ρH),×/1+ρH)ρH` which appears to be a transcription/OCR error. The `1+` doesn't make mathematical sense.

---

### 3. EARTHVIEW.aplf — callers must pass matrices

**Problem:** EARTHVIEW failed when passed a vector (e.g., sun position `0 0 0`).

**Original call pattern:**
```apl
SN←DATE EARTHVIEW 0 0 0
```

**Fixed call pattern (in CALCULATEPLANETS):**
```apl
SN←DATE EARTHVIEW 1 3⍴0 0 0
```

**Explanation:** EARTHVIEW uses `(⍴H)⍴` and downstream RADECDIST uses `[;N]` indexing, both requiring rank-2 input. Rather than adding a rank guard inside EARTHVIEW (which would diverge from the book's code), all callers now ensure they pass matrices. COMETPOS was also fixed to always return a matrix (see fix 14).

---

### 4. AREADERIV.aplf (line 3)

**Problem:** Incorrect derivative formula caused Newton's method to diverge.

**Original (incorrect):**
```apl
Z←(PERIDIST÷2)+(X*2)÷8×PERIDIST
```

**Fixed:**
```apl
Z←(PERIDIST÷2)+(3×X*2)÷4×PERIDIST
```

**Explanation:** AREA computes `(PERIDIST×X÷2) + (X*3)÷(4×PERIDIST)`.

The derivative with respect to X is:
- d/dX of `PERIDIST×X÷2` = `PERIDIST÷2`
- d/dX of `(X*3)÷(4×PERIDIST)` = `(3×X*2)÷(4×PERIDIST)`

The original had coefficient 1/8 instead of 3/4, causing COMETSOLVE's Newton iteration to oscillate wildly instead of converging. This made any calculation involving Kohoutek hang indefinitely.

**Note:** The book shows `(X×2)÷8×PERIDIST` — this may be another OCR error where `*` was read as `×`.

---

### 5. SKYPOS.aplf (multiple fixes)

#### 5a. Line 10 — normalization syntax error

**Original (broken):**
```apl
GQ←GQ÷(⊖(⌽⍴GQ)⍴NORM GQ←CARTRIPLET GQ
```

**Fixed:**
```apl
GQ←GQ÷⍉(⌽⍴GQ)⍴NORM GQ←CARTRIPLET GQ
```

**Explanation:** The original line had an unpaired parenthesis and used `⊖` (reverse rows) where `⍉` (transpose) was needed. The intent is to convert RA/Dec to Cartesian and normalize each row to unit length. The idiom `⍉(⌽⍴GQ)⍴NORM GQ` broadcasts the N-element norm vector to Nx3 for element-wise division.

#### 5b. Line 11 — rotation matrix order and LATROTATE fix

**Original (on main, after earlier intermediate fix):**
```apl
GQ←GQ+.×⊖(LATROTATE LAT)+.×LONGROTATE-ROT
```

**Fixed:**
```apl
GQ←GQ+.×(LONGROTATE ROT)+.×LATROTATE LAT
```

**Explanation:** The book's rotation is longitude first, then latitude — matching the standard equatorial-to-horizontal transform. The intermediate fix had reversed the order and compensated with `⊖` and a negated ROT. After fixing LATROTATE (see fix 10), the book's original rotation order works correctly without the `⊖` wrapper.

#### 5c. Line 13 — azimuth quadrant sign negated

**Original (incorrect):**
```apl
S←×GQ[;3]
```

**Fixed:**
```apl
S←-×GQ[;3]
```

**Explanation:** After the equatorial-to-horizontal rotation, the z-component has the opposite sign from what the azimuth extraction formula expects. Without this fix, all azimuths are reflected East/West. Full derivation in `docs/calculation-fixes.md`, section 2.

#### 5d. Line 14 — azimuth calculation reworked

**Original (incorrect):**
```apl
NEG←-S×GQ[;3]
AZ←(360×S≥0)+NEG×DEGREES ARCCOS GQ[;1 3]÷NORM GQ[;1 3]
```

**Fixed:**
```apl
AZ←(360×S≤0)+S×DEGREES ARCCOS(-GQ[;1])÷NORM GQ[;1 3]
```

**Explanation:** Three problems in the original:
1. `GQ[;1 3]` passes an Nx2 matrix to ARCCOS — should be the normalized X component only
2. The `NEG` intermediate variable is eliminated; `S` (the sign of the z-component) directly scales the angle
3. `(-GQ[;1])` negates X before ARCCOS and `S≤0` replaces `S≥0`, together producing the correct North=0, East=90 azimuth convention

---

### 6. CALCULATEPLANETS.aplf (multiple fixes)

**Problem A:** Moon passed twice to SKYPOS; Earth included in planet computation.

**Original:**
```apl
PLANETS←DATE EARTHVIEW DATE PLANETPOS planets
SN←DATE EARTHVIEW 0 0 0
...
AA←MN,[1](LAT,DATE,TIME)SKYPOS 1 0⌽PLANETS
```

**Fixed:**
```apl
PLANETS←DATE EARTHVIEW DATE PLANETPOS(3≠⍳9)⌿planets
SN←DATE EARTHVIEW 1 3⍴0 0 0
...
MN←MN[;3]PARALLAXADJUST(LAT,DATE,TIME)SKYPOS MN[;1 2]
AA←MN,[1](LAT,DATE,TIME)SKYPOS 1 0↓PLANETS
PLANETAA←AA
```

**Explanation:**
- `(3≠⍳9)⌿planets` excludes Earth (row 3) from the planet computation. Computing Earth's position from Earth yields a zero vector mapped to zenith, producing a spurious marker.
- `1 3⍴0 0 0` ensures the sun's zero vector is a matrix for EARTHVIEW (see fix 3).
- `1 0⌽PLANETS` (rotate) was a misreading of `1 0↓PLANETS` (drop). The drop removes the moon row from PLANETS before SKYPOS, since the moon is already handled separately with parallax correction. Without this, the moon appeared twice and all planet symbols shifted by one.
- `PLANETAA←AA` preserves uncompressed alt/az for REPORTPLANETS.

---

### 7. CALCULATESTARS.aplf (lines 4-7)

**Problem:** Attempted to assign to BRIGHT which is defined as a function.

**Original (broken):**
```apl
VE←BRIGHT←STARCOORD←AAE←⍬
...
BRIGHT←BRIGHT/⍨VE←VISIBLE STARDATA
AAE←(BRIGHT∧VE)⌿STARDATA
```

**Fixed:**
```apl
VE←BRIGHTVIS←STARCOORD←AAE←10
...
VE←VISIBLE STARDATA
BRIGHTVIS←BRIGHT∧VE
AAE←BRIGHTVIS⌿STARDATA
```

**Explanation:** In the original 1973 workspace, BRIGHT was likely a global variable. In our implementation, BRIGHT is a niladic function that returns the brightness vector. APL doesn't allow assigning to function names. The fix uses `BRIGHTVIS` as a local variable for the "bright AND visible" mask, and initialises with `10` (the book's convention for uninitialised placeholders).

Also: `STARDATA←(LAT,DATE,TIME)SKYPOS(DATE-CATEPOCH)PRECESS STARS` — uses CATEPOCH for the precession interval rather than raw DATE, matching the catalog epoch convention.

---

### 8. MAPCARTESIAN.aplf (line 4)

**Problem:** `⊖` (reverse first axis) used where `⌽` (reverse last axis) was needed, likely a transcription error from the 1978 printed book where the two glyphs are easily confused.

**Original (incorrect):**
```apl
Z←⊖CARTESIAN⊖X
```

**Fixed:**
```apl
Z←⌽CARTESIAN⌽X
```

**Explanation:** PROJECTION outputs an Nx2 matrix of `[radius, azimuth]`. CARTESIAN expects `[theta, rho]` — columns swapped. The book itself says (p.545): *"MAPCARTESIAN makes allowance for the fact that altitude and azimuth are conventionally grouped in the opposite order from right ascension and declination"* — i.e., a column swap.

`⊖` reverses rows (first axis), so `⊖CARTESIAN⊖X` reverses rows, applies CARTESIAN, reverses rows back — the two operations cancel. `⌽` reverses columns (last axis), so `⌽CARTESIAN⌽X` swaps columns, applies CARTESIAN correctly, then swaps back.

---

### 9. JNU.aplf (line 9) — Gregorian correction

**Problem:** APL right-to-left precedence gave wrong result for the Meeus Gregorian correction formula.

**Original (incorrect):**
```apl
B←2-A+⌊A÷4
```

**Fixed:**
```apl
B←(2-A)+⌊A÷4
```

**Explanation:** The Meeus formula is B = 2 - A + floor(A/4). In APL, `2-A+⌊A÷4` evaluates right-to-left as `2-(A+⌊A÷4⌋)`, giving B = -21 for year 1974 instead of the correct B = -13. This made every Julian day number 8 less than correct.

The EQUINOX constant (2441761.5) and planetary epoch dates in the `planets` table are correct Julian day numbers from external references. Since DATE was computed by the buggy JNU, `DATE-EQUINOX` was systematically 8 days too small, causing ~2.6 deg sidereal time error and 8-day planetary ephemeris shift.

**Collateral fix:** JNUINV simplified from a two-pass algorithm (compensating for JNU's bug) to the standard Meeus inverse plus round-trip safety check.

Full derivation in `docs/calculation-fixes.md`, section 1.

---

### 10. LATROTATE.aplf (line 4) — transcription error

**Original (incorrect):**
```apl
Z←⊖⊖INCLROTATE LAT
```

**Fixed:**
```apl
Z←⌽⊖INCLROTATE LAT
```

**Explanation:** Same class of error as MAPCARTESIAN: `⊖` (reverse rows) was transcribed where `⌽` (reverse columns) was needed. `⊖⊖` cancels to identity, making LATROTATE equivalent to INCLROTATE — wrong. `⌽⊖` swaps axes correctly, producing a latitude rotation in the horizontal plane. This fix also allowed removing the `⊖` wrapper from the SKYPOS rotation line (fix 5b).

---

### 11. PRECESS.aplf (lines 6, 8) — sign and transpose errors

**Original (incorrect):**
```apl
PRECESSION←LONGROTATE INTERVAL×2×PI÷25800×YRLENGTH
...
Z←2 RADECDIST X+.×⊖ROT
```

**Fixed:**
```apl
PRECESSION←LONGROTATE-INTERVAL×2×PI÷25800×YRLENGTH
...
Z←2 RADECDIST X+.×ROT
```

**Explanation:** Two errors:
1. Missing negation: precession is a westward drift of the equinox, requiring a negative rotation angle. Without the minus sign, star positions precess in the wrong direction.
2. `⊖ROT` reverses the rotation matrix rows. The correct matrix is `ROT` without reversal (the negative angle handles the direction).

---

### 12. MOONPOS.aplf (line 4) — missing negation

**Original (incorrect):**
```apl
GQ←3 RADECDIST GC+.×INCLROTATE RADIAN AXITILT
```

**Fixed:**
```apl
GQ←3 RADECDIST GC+.×INCLROTATE-RADIAN AXITILT
```

**Explanation:** The ecliptic-to-equatorial rotation requires negating the axial tilt angle (rotating *from* ecliptic *to* equatorial), matching the same pattern in EARTHVIEW. Without the negation, the moon's declination is tilted the wrong way.

---

### 13. planets.aplf — epoch date inconsistency

**Problem:** Column 10 (DATE_ASC) used JD 2443600.5 (1978 epoch) for all planets, but the ANOMALY values in column 7 correspond to ~1973 epoch.

**Original (incorrect):**
```
DATE_ASC = 2443600.5  (for all 9 planets)
```

**Fixed:**
```
DATE_ASC = 2441720.5  (for all 9 planets)
```

**Explanation:** The anomaly values are mean anomalies at a 1973-era epoch (JD 2441720.5). Using the 1978 date caused EPOCHADJUST to miscalculate the time interval, shifting all planet longitudes by several degrees. After the fix, planet RA/Dec matches JPL Horizons to 1-7 arcminutes.

Documented as bug #12 in `docs/calculation-fixes.md`.

---

### 14. moon.aplf — decimal place errors in secular rates

**Original (incorrect):**
```apl
... ¯0.0052953922 0.01114040803 ...
```

**Fixed:**
```apl
... ¯0.052953922 0.1114040803 ...
```

**Explanation:** The secular rates for the moon's ascending node and periangle were a factor of 10 too small (extra leading zero after the decimal point). This is a transcription error — the moon's node regresses ~19 deg/year, which requires these larger secular rate values.

---

### 15. COMETPOS.aplf (line 7) — ensure matrix output

**Original:**
```apl
H←ORBROTATE(PARABOLA X),-X
```

**Fixed:**
```apl
H←((1⌈⍴,DATE),3)⍴ORBROTATE(PARABOLA X),-X
```

**Explanation:** When DATE is scalar, ORBROTATE returns a vector. EARTHVIEW requires a matrix (see fix 3). The reshape `((1⌈⍴,DATE),3)⍴` ensures the result is always Nx3, preventing RANK ERROR for single-date comet calculations.

---

### 16. PLANETSPOS.aplf (line 5) — scalar index fix

**Original (incorrect):**
```apl
PL←(planets)[P;]
```

**Fixed:**
```apl
PL←planets[,P;]
```

**Explanation:** Same pattern as EARTH (fix 1): when P is a scalar, `planets[P;]` returns a vector instead of a 1x11 matrix. The `,P` ravels the index, preserving the row dimension.

---

### 17. 11 selector functions — rank guard removal

**Functions:** ANOMALY, ANOMALYDATE, ASCENDING, ECCENTRICITY, EPOCHDATE, INCLINATION, PERIANGLE, PERIDIST, PERIOD, SECULAR, SEMIMAJOR

**Original (added during early modernization):**
```apl
:If 2=≢⍴ORB ⋄ Z←ORB[;7] ⋄ :Else ⋄ Z←ORB[7] ⋄ :EndIf
```

**Restored to book form:**
```apl
Z←ORB[;7]
```

**Explanation:** The `:If`/`:Else` rank guards were added as a workaround when callers sometimes passed vectors instead of matrices. After fixing EARTH (fix 1), PLANETSPOS (fix 16), and COMETPOS (fix 15) to always produce matrices, the guards became unnecessary. Removing them restores the book's one-liner form.

---

### 18. DISPLAY.aplf (lines 5-6) — plotter prompt removed

**Original:**
```apl
ENTRY
⎕←'Insert fine plotting element and press ENTER'
⍞
WORK
```

**Fixed:**
```apl
ENTRY
WORK
```

**Explanation:** The "fine plotting element" was a physical pen tip inserted into an IBM pen plotter (IBM program 5798-AGL). The `⍞` paused execution until the operator confirmed the plotter was ready. Since there is no plotter, this prompt is removed. The `⍞` also caused NONCE ERROR when executing via RIDE sockets.

---

### 19. PLOTSTARS.aplf (complete rewrite)

**Problem:** Original PLOTSTARS called FPLOT, an external IBM fine-plotting function not included in the book.

**Fix:** Replaced with terminal renderer producing an adaptive character grid:
- Size adapts to `⎕PW` (works at both 80 and 120 columns)
- Horizon circle drawn with `·`, crosshairs with box-drawing characters
- Cardinal directions (N/S/E/W) — East on left, West on right (standard sky chart: looking up)
- Zenith marked with `┼` at center
- Stars: `.` for faint, `*` for bright (magnitude ≤ 1.5)
- Planets: Unicode astronomical symbols (☾☉☿♀♂♃♄⛢♆♇☄) with name labels
- Legend printed below map

Uses existing globals STARCOORD, PLANETCOORD, VE, VP, BRIGHT, PHASE set by CALCULATEPLANETS and CALCULATESTARS.

---

## Files modified

| File | Lines changed | Issue type |
|------|---------------|------------|
| EARTH.aplf | 1 | Shape (vector to matrix) |
| ORBROTATE.aplf | 1 | Reshape formula |
| AREADERIV.aplf | 1 | Wrong coefficient |
| SKYPOS.aplf | 5 | Syntax, shape, signs, azimuth |
| CALCULATEPLANETS.aplf | 5 | Earth exclusion, moon duplication, matrix args |
| CALCULATESTARS.aplf | 4 | Function/variable conflict, epoch |
| MAPCARTESIAN.aplf | 1 | Transcription error (⊖ vs ⌽) |
| JNU.aplf | 1 | APL precedence error |
| JNUINV.aplf | simplified | Removed two-pass JNU compensation |
| LATROTATE.aplf | 1 | Transcription error (⊖ vs ⌽) |
| PRECESS.aplf | 2 | Missing negation, spurious reverse |
| MOONPOS.aplf | 1 | Missing negation |
| planets.aplf | 1 | Epoch date column (2443600.5 to 2441720.5) |
| moon.aplf | 1 | Decimal place errors in secular rates |
| COMETPOS.aplf | 1 | Matrix reshape for EARTHVIEW |
| PLANETSPOS.aplf | 1 | Scalar index (same as EARTH) |
| ANOMALY.aplf | 1 | Rank guard removed |
| ANOMALYDATE.aplf | 1 | Rank guard removed |
| ASCENDING.aplf | 1 | Rank guard removed |
| ECCENTRICITY.aplf | 1 | Rank guard removed |
| EPOCHDATE.aplf | 1 | Rank guard removed |
| INCLINATION.aplf | 1 | Rank guard removed |
| PERIANGLE.aplf | 1 | Rank guard removed |
| PERIDIST.aplf | 1 | Rank guard removed |
| PERIOD.aplf | 1 | Rank guard removed |
| SECULAR.aplf | 1 | Rank guard removed |
| SEMIMAJOR.aplf | 1 | Rank guard removed |
| DISPLAY.aplf | 2 removed | Plotter prompt removed |
| PLOTSTARS.aplf | full rewrite | Terminal renderer replaces FPLOT stub |
| BRIGHT.aplf | 1 | Updated for 332-star catalog |
| EARTHVIEW.aplf | 1 removed | Rank guard removed (callers pass matrices) |
| CAPTION.aplf | rewrite | Formatted header matching book layout |
| REPORTPLANETS.aplf | rewrite | Two-column planet table with Unicode symbols |
| REPORTSTARS.aplf | rewrite | Formatted star report |
| PRINTED.aplf | rewrite | Formatted footer with timestamp |
| WORK.aplf | updated | Calls rewritten output functions |

## Files added

| File | Purpose |
|------|---------|
| PLANETNAMES.aplf | 11-element nested vector of planet/object names matching CALCULATEPLANETS order |
| STARNAMES.aplf | 332-element nested vector of star names from book appendix (p.693+) |
| STARS.aplf | 332x2 star catalog (RA hours, Dec degrees) derived from Yale BSC5 |
| JNUINV.aplf | Standard Meeus inverse: Julian day number to M D Y |
| DAYNAME.aplf | Day-of-week name from Julian day number (Sakamoto's algorithm) |
| EXAMPLE_RENDER.aplf | Reference rendering: Anaheim, May 15 1974, 10 PM PDT |
| reference_positions.aplf | 334x2 reference RA/Dec matrix generated by `scripts/generate_reference.py` |
| TEST_JNU.aplf | 5 reference Julian day numbers |
| TEST_JNUINV.aplf | Round-trip JNU/JNUINV validation |
| TEST_DAYNAME.aplf | Day-of-week validation |
| TEST_STARCATALOG.aplf | Star catalog format and content checks |
| TEST_POSITIONS.aplf | Planet RA/Dec against JPL Horizons reference |
| TEST_SKYPOS.aplf | Alt/az for 9 bright stars + Sun (0.005 deg max error) |
| TEST_PIPELINE.aplf | End-to-end CALCULATESTARS + CALCULATEPLANETS validation |

---

## Current status

### Working:
- **Full pipeline** — DISPLAY drives ENTRY, WORK, and all sub-stages
- **PLANETPOS** — Heliocentric positions for all 9 planets
- **EARTHVIEW** — Geocentric equatorial coordinates
- **MOONPOS** — Moon position relative to Earth
- **COMETPOS** — Comet Kohoutek (within +/-100 days of perihelion)
- **SKYPOS** — Altitude/azimuth for any observer location
- **PRECESS** — Star position precession
- **CALCULATEPLANETS** — Full planet pipeline (Moon, Sun, 8 planets, Kohoutek)
- **CALCULATESTARS** — Full star pipeline (332-star catalog)
- **PLOTSTARS** — Terminal star map with horizon circle, cardinal directions, symbols
- **MAPCARTESIAN** — Stereographic projection to Cartesian
- **CAPTION** — Formatted header with location, date, time
- **REPORTPLANETS** — Two-column planet position table
- **PRINTED** — Footer with generation timestamp
- **All 7 tests pass**

### Partially working:
- **REPORTSTARS** — Works but formatting could be improved

---

## Suggestions for improvements

### 1. Modernize array handling

Replace manual shape manipulations with rank operator (`⍤`):

```apl
⍝ Old: normalize each row
GQ←GQ÷⍉(⌽⍴GQ)⍴NORM GQ

⍝ Modern: using rank operator
GQ←GQ÷⍤1⊢NORM GQ
```

### 2. Replace control flow with guards

The iterative functions use old-style branching:

```apl
⍝ Old style (KEPLINVERSE)
TEST:→END IF∧/,TOL>|ERROR←TIME-E KEPLERFN PSI
PSI←PSI+ERROR÷E KEPDERIV PSI
→TEST
END:

⍝ Modern style with power operator
KEPLINVERSE←{
    TOL←1E¯10
    step←{PSI←⍵ ⋄ ERR←TIME-E KEPLERFN PSI ⋄ PSI+ERR÷E KEPDERIV PSI}
    conv←{TOL>|TIME-E KEPLERFN ⍵}
    step⍣conv⊢⍺
}
```

### 3. Use dfns for simple functions

Many utility functions could be dfns:

```apl
⍝ Old
∇ Z←PI
  Z←○1
∇

⍝ Modern
PI←{○1}
⍝ Or simply use ○1 directly
```

### 4. Improve SKYPOS robustness

Handle edge cases:
- Observer at poles (latitude +/-90)
- Objects at zenith (altitude = 90)
- Objects on horizon (altitude = 0)

### 5. Add input validation

The GET* functions should validate input:
- Date ranges (Julian day calculation limits)
- Latitude bounds (-90 to 90)
- Longitude bounds (-180 to 180)
- Time bounds (0 to 24)

### 6. Separate data from code

Move orbital elements to data files:
```
data/
  planets.json      # Orbital elements
  stars.json        # Star catalog
  bright.json       # Brightness flags
```

Load at startup rather than embedding in functions.

### 7. Add modern visualization

Replace FPLOT (1970s plotter) with:
- SharpPlot for static images
- HTML/SVG output for web display
- Integration with `⎕WC` for GUI

### 8. Extend functionality

- **More celestial objects**: asteroids, satellites, deep sky objects
- **Updated orbital elements**: current ephemeris data
- **Rise/set times**: when objects cross horizon
- **Twilight calculation**: astronomical, nautical, civil
- **Eclipse prediction**: solar and lunar

### 9. Documentation

- Add docstrings to all functions explaining inputs/outputs
- Create worked examples for each major calculation
- Document coordinate systems and conventions used

---

## Testing commands

After loading with Link:

```apl
)clear
⎕SE.Link.Create '#' '/Users/nk/dev/STARMAP/APLSource'

⍝ Set test parameters (Philadelphia, Jan 14 1974, 9pm)
DATE←JNU 1 14 1974
LAT←40
LONG←¯75
TIME←21
STATEDDAYNO←DATE
STATEDTIME←TIME

⍝ Test individual functions
PI                           ⍝ Should be 3.14159...
RADIAN 180                   ⍝ Should be π
⍴planets                     ⍝ Should be 9 11
⍴EARTH                       ⍝ Should be 1 11
DATE PLANETPOS EARTH         ⍝ Earth's heliocentric position
DATE EARTHVIEW 1 3⍴0 0 0    ⍝ Sun's geocentric position
MOONPOS DATE                 ⍝ Moon position
DATE COMETPOS kohoutek       ⍝ Kohoutek position

⍝ Full calculation
CALCULATEPLANETS
CALCULATESTARS
⍴PLANETS                     ⍝ Should be 11 3 (no Earth)
⍴STARCOORD                   ⍝ Should be ~N 2 (varies with inputs)
```

---

## Acknowledgments

Original STARMAP by Paul C. Berry and John R. Thorstensen, IBM Corporation, 1973.

Modernization work performed January-February 2026.
