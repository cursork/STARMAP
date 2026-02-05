# STARMAP: Differences from Original (Dyalog APL Adaptation)

This document summarizes all changes made to adapt the 1973 STARMAP program for modern Dyalog APL, with working examples demonstrating correct operation.

## Overview

The original STARMAP was written for IBM APL on mainframes circa 1973. Adapting it to Dyalog APL required fixing:

1. **Transcription/OCR errors** from the printed book
2. **APL dialect differences** (IBM APL vs Dyalog)
3. **Shape/rank handling** differences
4. **Mathematical errors** in formulas

**Total: 7 files modified, 13 line changes**

---

## Summary of All Changes

| File | Lines | Issue Type | Symptom |
|------|-------|------------|---------|
| EARTH.aplf | 1 | Shape | RANK ERROR in EPOCHADJUST |
| ORBROTATE.aplf | 1 | Reshape formula | Wrong output dimensions |
| EARTHVIEW.aplf | 1 added | Shape enforcement | RANK ERROR on sun position |
| AREADERIV.aplf | 1 | Wrong coefficient | Newton iteration diverges |
| SKYPOS.aplf | 3 | Syntax + shapes | Multiple errors |
| CALCULATEPLANETS.aplf | 2 | Column selection | RANK ERROR in SKYPOS |
| CALCULATESTARS.aplf | 4 | Name conflict | Can't assign to function |

---

## Detailed Changes

### 1. EARTH.aplf

**Problem:** Returned vector instead of 1×11 matrix.

```apl
⍝ Original (broken)
Z←(planets)[3;]

⍝ Fixed
Z←planets[,3;]
```

**Explanation:** The `,3` syntax in `planets[,3;]` preserves the row dimension, returning a 1×11 matrix instead of an 11-element vector.

**Test:**
```
      ⍴EARTH
1 11
```

### 2. ORBROTATE.aplf

**Problem:** Incorrect reshape produced wrong output shape.

```apl
⍝ Original (broken) - from book shows "1+ρH" which is OCR error
H←((1↓⍴H),×/1↑⍴H)⍴H

⍝ Fixed
H←(¯1↓⍴H)⍴H
```

**Explanation:** After matrix multiplications, H has shape N×3×1. The goal is N×3. The fix simply drops the trailing dimension.

**Test:**
```
      DATE←JNU 1 14 1974
      ⍴DATE PLANETPOS planets
9 3
```

### 3. EARTHVIEW.aplf

**Problem:** Failed when passed a vector (sun position `0 0 0`).

```apl
⍝ Added this line before existing code:
H←(1,⍴H)⍴⍣(1=≢⍴H)⊢H
```

**Explanation:** Conditionally reshapes vectors to 1-row matrices using the power operator `⍣`.

**Test:**
```
      DATE EARTHVIEW 0 0 0
15.22180114 ¯17.94701314 0.9894741581
```

### 4. AREADERIV.aplf

**Problem:** Wrong derivative coefficient caused Newton's method to diverge.

```apl
⍝ Original (broken) - coefficient 1/8 instead of 3/4
Z←(PERIDIST÷2)+(X*2)÷8×PERIDIST

⍝ Fixed
Z←(PERIDIST÷2)+(3×X*2)÷4×PERIDIST
```

**Explanation:** The AREA function is `(PERIDIST×X÷2) + (X*3)÷(4×PERIDIST)`. The derivative of `X*3` is `3×X*2`, not `X*2`. The book shows `X×2` which may be OCR misreading `*` as `×`.

**Test:**
```
      DATE COMETPOS kohoutek
0.2129173036 0.05097014753 ¯0.03775422479
```

(Without this fix, COMETPOS would hang indefinitely.)

### 5. SKYPOS.aplf (Multiple Fixes)

#### 5a. Line 10 - Syntax error

```apl
⍝ Original (broken) - unpaired parenthesis
GQ←GQ÷(⊖(⌽⍴GQ)⍴NORM GQ←CARTRIPLET GQ

⍝ Fixed (split into two lines)
GQ←CARTRIPLET GQ
GQ←GQ÷(NORM GQ)∘.×3⍴1
```

#### 5b. Line 16 - Shape mismatch

```apl
⍝ Original (broken)
AZ←(360×S≥0)+NEG×DEGREES ARCCOS GQ[;1 3]÷NORM GQ[;1 3]

⍝ Fixed
AZ←(360×S≥0)+NEG×DEGREES ARCCOS GQ[;1]÷NORM GQ[;1 3]
```

**Explanation:** ARCCOS expects a scalar per row, not a 2-column matrix.

### 6. CALCULATEPLANETS.aplf

**Problem:** Passed 3-column matrices to SKYPOS which expects 2 columns.

```apl
⍝ Original (broken)
MN←MN[;3]PARALLAXADJUST(LAT,DATE,TIME)SKYPOS MN
AA←MN,[1](LAT,DATE,TIME)SKYPOS 1 0⌽PLANETS

⍝ Fixed
MN←MN[;3]PARALLAXADJUST(LAT,DATE,TIME)SKYPOS MN[;1 2]
AA←MN,[1](LAT,DATE,TIME)SKYPOS PLANETS[;1 2]
```

**Test:**
```
      DATE←JNU 1 14 1974 ⋄ LAT←40 ⋄ LONG←¯75 ⋄ TIME←21
      STATEDDAYNO←DATE ⋄ STATEDTIME←TIME
      CALCULATEPLANETS
      ⍴PLANETS
12 3
```

### 7. CALCULATESTARS.aplf

**Problem:** Attempted to assign to BRIGHT which is a function.

```apl
⍝ Original (broken)
VE←BRIGHT←STARCOORD←AAE←⍬
...
BRIGHT←BRIGHT/⍨VE←VISIBLE STARDATA

⍝ Fixed
VE←STARCOORD←AAE←⍬
...
VE←VISIBLE STARDATA
BRIGHTVIS←BRIGHT∧VE
AAE←BRIGHTVIS⌿STARDATA
```

**Test:**
```
      CALCULATESTARS
      ⍴STARCOORD
21 2
```

---

## Working Examples

All examples tested with Dyalog APL 20.0 via gritt.

### Basic Functions

```
      PI
3.141592654

      RADIAN 180
3.141592654

      DEGREES PI
180

      SIN RADIAN 90
1

      COS RADIAN 0
1

      NORM 3 4
5
```

### Date Conversion

```
      JNU 1 1 2000
2451536.5

      JNU 1 14 1974
2442053.5
```

### Data Structures

```
      ⍴planets
9 11

      ⍴EARTH
1 11

      ⍴STARS
50 2

      +/BRIGHT
23
```

### Rotation Matrix Properties

```
      ⍝ Shape check
      ⍴INCLROTATE RADIAN 45
3 3

      ⍝ Orthogonality: M × M' = I
      M←INCLROTATE RADIAN 45
      I←3 3⍴1 0 0 0 1 0 0 0 1
      ⌈/,|(M+.×⍉M)-I
0
```

### Kepler Equation Solver

```
      ⍝ Find eccentric anomaly for E=0.5, M=1
      E←0.5
      PSI←E KEPLINVERSE 1
      PSI
1.498701134

      ⍝ Verify solution satisfies Kepler's equation
      E KEPLERFN PSI
1
```

### Coordinate Transformations

```
      ⍝ Round-trip: RA/Dec → Cartesian → RA/Dec
      1 RADECDIST CARTRIPLET 1 2⍴6 45
6 45
```

### Orbital Positions

```
      DATE←JNU 1 14 1974

      ⍝ Earth's heliocentric position
      DATE PLANETPOS EARTH
0.6258686202 0 ¯0.7663860514

      ⍝ Sun's geocentric position (RA hours, Dec degrees, distance AU)
      DATE EARTHVIEW 0 0 0
15.22180114 ¯17.94701314 0.9894741581

      ⍝ Moon position
      MOONPOS DATE
15.85242585 24.52499304 0.9528298472

      ⍝ Comet Kohoutek position
      DATE COMETPOS kohoutek
0.2129173036 0.05097014753 ¯0.03775422479
```

### Full Pipeline

```
      DATE←JNU 1 14 1974
      LAT←40
      LONG←¯75
      TIME←21
      STATEDDAYNO←DATE
      STATEDTIME←TIME

      CALCULATEPLANETS
      ⍴PLANETS
12 3

      +/VP
1

      CALCULATESTARS
      ⍴STARCOORD
21 2

      +/VE
21
```

---

## Dialect Differences: IBM APL vs Dyalog

### Syntax Changes

| Feature | IBM APL (1973) | Dyalog APL |
|---------|----------------|------------|
| Branch | `→LABEL` | Same, but dfns preferred |
| Quad input | `⎕` | Same |
| Quote-quad | `⍞` | Same (but RIDE issues) |
| System commands | `)SAVE` etc. | Same |
| Workspace | Monolithic | Link-based source files |

### Semantic Differences

1. **Indexing:** IBM APL was typically index-origin 1; Dyalog defaults to 0 but we use `⎕IO←1`

2. **Function/Variable namespaces:** In IBM APL workspaces, functions and variables could share names (BRIGHT was both). In Dyalog Link, each `.aplf` file is a function - no variable of that name can exist.

3. **Shape handling:** Modern Dyalog is stricter about rank mismatches in operations.

### External Dependencies

| Original | Status | Notes |
|----------|--------|-------|
| FPLOT (fine plotting) | Not available | Need replacement (ASCII, SVG, etc.) |
| IBM plotter hardware | Not available | Was element 114 on line printers |

---

## Current Working Status

### Fully Working
- All trigonometric functions
- All coordinate transformations
- PLANETPOS, MOONPOS, COMETPOS, EARTHVIEW
- SKYPOS, PRECESS
- CALCULATEPLANETS, CALCULATESTARS
- WORK (main calculation pipeline)

### Partially Working
- CAPTION (latitude shows in radians, day-of-week as number)
- REPORTPLANETS (formatting could improve)

### Not Working
- PLOTSTARS (requires FPLOT replacement)
- REPORTSTARS (depends on PLOTSTARS)
- Interactive DISPLAY via socket (NONCE ERROR on ⍞)

---

## Verification Commands

To verify the codebase is working:

```bash
# Start Dyalog
pkill -f dyalog
RIDE_INIT=SERVE:127.0.0.1:14502 dyalog +s -q &
sleep 2

# Clear and link
gritt -addr localhost:14502 -e ")clear"
gritt -addr localhost:14502 -e "⎕SE.Link.Create '#' '/Users/nk/dev/STARMAP/APLSource'"

# Set globals
gritt -addr localhost:14502 -e "DATE←JNU 1 14 1974 ⋄ LAT←40 ⋄ LONG←¯75 ⋄ TIME←21 ⋄ STATEDDAYNO←DATE ⋄ STATEDTIME←TIME"

# Run full pipeline
gritt -addr localhost:14502 -e "CALCULATEPLANETS ⋄ CALCULATESTARS ⋄ (⍴PLANETS)(⍴STARCOORD)"
# Expected: 12 3  21 2  (or similar)
```

---

## References

- Original: "STARMAP" by Paul C. Berry & John R. Thorstensen (APL Press, 1978)
- Book scan: `book/STARMAP.pdf`
- Transcription: `book/starmap.md`
- Bug fixes: `CHANGES.md`
