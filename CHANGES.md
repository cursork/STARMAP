# STARMAP Modernization: Changes and Recommendations

This document covers all changes made to bring STARMAP to working order in modern Dyalog APL, along with suggestions for future improvements.

## Overview

STARMAP is a 1973 APL program for generating star maps. The code was transcribed from the book "STARMAP" by Paul C. Berry & John R. Thorstensen (APL Press, 1978). During modernization, several issues were discovered:

1. **Transcription errors** - typos or OCR errors from the original printed source
2. **APL dialect differences** - syntax that worked in 1970s IBM APL but not in modern Dyalog
3. **Shape/rank issues** - functions that assumed specific array shapes
4. **Logic errors** - incorrect formulas or algorithms

---

## Fixes Applied

### 1. EARTH.aplf (Line 3)

**Problem:** Function returned a vector instead of a 1×11 matrix.

**Original (incorrect):**
```apl
Z←(planets)[3;]
```

**Fixed:**
```apl
Z←planets[,3;]
```

**Explanation:** The orbital element accessor functions (SEMIMAJOR, PERIOD, etc.) use `ORB[;N]` indexing which requires ORB to be a matrix. When EARTH returned a vector, downstream functions like EPOCHADJUST failed with RANK ERROR.

The `,3` in `planets[,3;]` ravels the index, preserving the row dimension and returning a 1×11 matrix.

---

### 2. ORBROTATE.aplf (Line 12)

**Problem:** Incorrect reshape produced wrong output shape.

**Original (incorrect):**
```apl
H←((1↓⍴H),×/1↑⍴H)⍴H
```

**Fixed:**
```apl
H←(¯1↓⍴H)⍴H
```

**Explanation:** After matrix multiplications, H has shape N×3×1 (planets × coordinates × 1). The goal is to produce N×3.

The original formula `((1↓⍴H),×/1↑⍴H)` with H of shape 9 3 1 gives:
- `1↓⍴H` = 3 1
- `×/1↑⍴H` = 9
- Reshape to (3 1),9 = 3 1 9 ← **wrong!**

The fix `(¯1↓⍴H)` simply drops the trailing dimension, giving 9 3 ← **correct**.

**Note:** The original book shows `H←((1+ρH),×/1+ρH)ρH` which appears to be a transcription/OCR error. The `1+` doesn't make mathematical sense.

---

### 3. EARTHVIEW.aplf (Line 3)

**Problem:** Function failed when passed a vector (e.g., sun position `0 0 0`).

**Original:**
```apl
GC←H-(⍴H)⍴DATE PLANETPOS EARTH
```

**Fixed (added line before):**
```apl
H←(1,⍴H)⍴⍣(1=≢⍴H)⊢H ⍝ Ensure matrix
GC←H-(⍴H)⍴DATE PLANETPOS EARTH
```

**Explanation:** EARTHVIEW is called with `DATE EARTHVIEW 0 0 0` for the sun's position. The vector `0 0 0` has rank 1, but downstream RADECDIST uses `GQ[;1]` indexing which requires rank 2.

The fix conditionally reshapes vectors to 1-row matrices using the power operator `⍣`.

---

### 4. AREADERIV.aplf (Line 3)

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

**Note:** The book shows `(X×2)÷8×PERIDIST` - this may be another OCR error where `*` was read as `×`.

---

### 5. SKYPOS.aplf (Multiple fixes)

#### 5a. Line 10 - Syntax error and unclear logic

**Original (broken):**
```apl
GQ←GQ÷(⊖(⌽⍴GQ)⍴NORM GQ←CARTRIPLET GQ
```

**Fixed (split into two lines):**
```apl
GQ←CARTRIPLET GQ
GQ←GQ÷(NORM GQ)∘.×3⍴1
```

**Explanation:** The original line had an unpaired parenthesis and confusing operator sequence. The intent is:
1. Convert RA/Dec to Cartesian coordinates
2. Normalize each row to unit length

The fix uses outer product `∘.×` to broadcast the N-element norm vector to N×3 for element-wise division.

#### 5b. Line 16 - Azimuth calculation shape mismatch

**Original (incorrect):**
```apl
AZ←(360×S≥0)+NEG×DEGREES ARCCOS GQ[;1 3]÷NORM GQ[;1 3]
```

**Fixed:**
```apl
AZ←(360×S≥0)+NEG×DEGREES ARCCOS GQ[;1]÷NORM GQ[;1 3]
```

**Explanation:** `GQ[;1 3]` returns an N×2 matrix (X and Z columns). ARCCOS should only be applied to the normalized X component (a scalar per row), not to both columns.

The division `GQ[;1 3]÷NORM GQ[;1 3]` also had shape issues: N×2 ÷ N doesn't broadcast correctly.

The fix applies ARCCOS only to column 1 (X), properly normalized by the XZ-plane norm.

---

### 6. CALCULATEPLANETS.aplf (Lines 12-13)

**Problem:** Passed 3-column matrices to SKYPOS which expects 2 columns.

**Original (incorrect):**
```apl
MN←MN[;3]PARALLAXADJUST(LAT,DATE,TIME)SKYPOS MN
AA←MN,[1](LAT,DATE,TIME)SKYPOS 1 0⌽PLANETS
```

**Fixed:**
```apl
MN←MN[;3]PARALLAXADJUST(LAT,DATE,TIME)SKYPOS MN[;1 2]
AA←MN,[1](LAT,DATE,TIME)SKYPOS PLANETS[;1 2]
```

**Explanation:** EARTHVIEW returns N×3 matrices (RA, Dec, Distance). SKYPOS expects N×2 (RA, Dec only). CARTRIPLET inside SKYPOS uses `RADEC[;1]` and `RADEC[;2]` indexing.

The original `1 0⌽PLANETS` makes no sense - rotate doesn't help here. The book shows `1 0+PLANETS` which is also unclear. The fix explicitly selects columns 1 and 2.

---

### 7. CALCULATESTARS.aplf (Lines 4-7)

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
VE←STARCOORD←AAE←⍬
...
VE←VISIBLE STARDATA
BRIGHTVIS←BRIGHT∧VE
AAE←BRIGHTVIS⌿STARDATA
```

**Explanation:** In the original 1973 workspace, BRIGHT was likely a global variable. In our implementation, BRIGHT is a niladic function that returns the brightness vector. APL doesn't allow assigning to function names.

The fix:
1. Removes BRIGHT from initialization chain
2. Uses local variable BRIGHTVIS for the "bright AND visible" mask
3. Calls BRIGHT (the function) to get the data

Also fixed logic: original `BRIGHT/⍨VE` compresses BRIGHT by VE, giving fewer elements. We need `BRIGHT∧VE` to get a same-length boolean mask.

---

## Current Status

### Working:
- **PLANETPOS** - Calculates heliocentric positions for all 9 planets
- **EARTHVIEW** - Converts to geocentric equatorial coordinates
- **MOONPOS** - Moon position relative to Earth
- **COMETPOS** - Comet Kohoutek position (within ±100 days of perihelion)
- **SKYPOS** - Converts to altitude/azimuth for observer location
- **PRECESS** - Adjusts star positions for precession
- **CALCULATEPLANETS** - Full planet calculation pipeline
- **CALCULATESTARS** - Full star calculation pipeline
- **WORK** - Main calculation orchestration

### Partially Working:
- **CAPTION** - Works but shows latitude in radians (should be degrees)
- **REPORTPLANETS** - Works but formatting could be improved

### Not Tested:
- **DISPLAY** - Requires interactive input via ⎕
- **PLOTSTARS** - Requires FPLOT (external plotting function)
- **REPORTSTARS** - Depends on PLOTSTARS output
- **PRINTED** - Output formatting

---

## Suggestions for Improvements

### 1. Modernize Array Handling

Replace manual shape manipulations with rank operator (`⍤`):

```apl
⍝ Old: normalize each row
GQ←GQ÷(NORM GQ)∘.×3⍴1

⍝ Modern: using rank operator
GQ←GQ÷⍤1⊢NORM GQ
```

### 2. Replace Control Flow with Guards

The iterative functions use old-style branching:

```apl
⍝ Old style (KEPLINVERSE)
TEST:→END IF∧/,TOL>|ERROR←TIME-E KEPLERFN PSI
PSI←PSI+ERROR÷E KEPDERIV PSI
→TEST
END:

⍝ Modern style with guards and recursion or power operator
KEPLINVERSE←{
    TOL←1E¯10
    step←{PSI←⍵ ⋄ ERR←TIME-E KEPLERFN PSI ⋄ PSI+ERR÷E KEPDERIV PSI}
    conv←{TOL>|TIME-E KEPLERFN ⍵}
    step⍣conv⊢⍺
}
```

### 3. Use Dfns for Simple Functions

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

### 4. Improve SKYPOS Robustness

Handle edge cases:
- Observer at poles (latitude ±90)
- Objects at zenith (altitude = 90)
- Objects on horizon (altitude = 0)

### 5. Add Input Validation

The GET* functions should validate input:
- Date ranges (Julian day calculation limits)
- Latitude bounds (-90 to 90)
- Longitude bounds (-180 to 180)
- Time bounds (0 to 24)

### 6. Separate Data from Code

Move orbital elements to data files:
```
data/
  planets.json      # Orbital elements
  stars.json        # Star catalog
  bright.json       # Brightness flags
```

Load at startup rather than embedding in functions.

### 7. Add Modern Visualization

Replace FPLOT (1970s plotter) with:
- SharpPlot for static images
- HTML/SVG output for web display
- Integration with ⎕WC for GUI

### 8. Extend Functionality

- **More celestial objects**: asteroids, satellites, deep sky objects
- **Updated orbital elements**: current ephemeris data
- **Rise/set times**: when objects cross horizon
- **Twilight calculation**: astronomical, nautical, civil
- **Eclipse prediction**: solar and lunar

### 9. Add Unit Tests

Create test cases for each function:
```apl
∇ TestPLANETPOS
  ⍝ Earth at J2000 epoch should be at known position
  DATE←2451545  ⍝ J2000.0
  POS←DATE PLANETPOS EARTH
  assert (|POS-KNOWN_J2000_EARTH)<1E¯6
∇
```

### 10. Documentation

- Add docstrings to all functions explaining inputs/outputs
- Create worked examples for each major calculation
- Document coordinate systems and conventions used

---

## Testing Commands

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
DATE EARTHVIEW 0 0 0         ⍝ Sun's geocentric position
MOONPOS DATE                 ⍝ Moon position
DATE COMETPOS kohoutek       ⍝ Kohoutek position

⍝ Full calculation
CALCULATEPLANETS
CALCULATESTARS
⍴PLANETS                     ⍝ Should be 12 3
⍴STARCOORD                   ⍝ Should be ~18 2 (varies with inputs)
```

---

## Files Modified

| File | Lines Changed | Issue Type |
|------|---------------|------------|
| EARTH.aplf | 1 | Shape (vector→matrix) |
| ORBROTATE.aplf | 1 | Reshape formula |
| EARTHVIEW.aplf | 1 added | Shape enforcement |
| AREADERIV.aplf | 1 | Wrong coefficient |
| SKYPOS.aplf | 3 | Syntax + shapes |
| CALCULATEPLANETS.aplf | 2 | Column selection |
| CALCULATESTARS.aplf | 4 | Function/variable conflict |

**Total: 7 files, 13 line changes**

---

## Acknowledgments

Original STARMAP by Paul C. Berry and John R. Thorstensen, IBM Corporation, 1973.

Modernization work performed January 2026.
