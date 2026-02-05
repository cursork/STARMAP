# STARMAP Test Plan

This document outlines a comprehensive testing strategy for the STARMAP APL codebase.

## Test Categories

### 1. Unit Tests - Pure Mathematical Functions

**Priority: High | Difficulty: Easy**

These functions have no side effects and deterministic outputs.

| Function | Test Cases | Expected |
|----------|------------|----------|
| `PI` | Constant | 3.141592654 |
| `RADIAN` | 0, 90, 180, 360 | 0, π/2, π, 2π |
| `DEGREES` | 0, π/2, π, 2π | 0, 90, 180, 360 |
| `SIN` | 0, π/2, π | 0, 1, 0 |
| `COS` | 0, π/2, π | 1, 0, -1 |
| `TAN` | 0, π/4 | 0, 1 |
| `ARCSIN` | 0, 1 | 0, π/2 |
| `ARCCOS` | 1, 0 | 0, π/2 |
| `NORM` | (3 4), (1 0 0) | 5, 1 |
| `SQRT` | 4, 9, 2 | 2, 3, 1.414... |

**Round-trip tests:**
- `DEGREES RADIAN X` = X for all X
- `RADIAN DEGREES X` = X for all X
- `ARCSIN SIN X` = X for X ∈ [-π/2, π/2]
- `ARCCOS COS X` = X for X ∈ [0, π]

### 2. Date/Time Functions

**Priority: High | Difficulty: Medium**

| Function | Input | Expected | Notes |
|----------|-------|----------|-------|
| `JNU` | 1 1 2000 | 2451536.5 | Near J2000 epoch |
| `JNU` | 1 14 1974 | 2442053.5 | Test date from book |
| `JNU` | 7 4 1776 | 2369916.5 | Historical validation |
| `JNU` | 12 31 1999 | 2451535.5 | Year boundary |

**Edge cases:**
- Leap years: Feb 29
- Century boundaries
- Negative years (BCE dates)

### 3. Data Structure Validation

**Priority: High | Difficulty: Easy**

| Data | Shape | Content Check |
|------|-------|---------------|
| `planets` | 9×11 | 9 planets, 11 orbital elements |
| `EARTH` | 1×11 | Earth's elements as matrix |
| `moon` | 1×11 | Moon's orbital elements |
| `kohoutek` | 1×11 | Comet Kohoutek elements |
| `STARS` | 50×2 | 50 stars × (RA, Dec) |
| `BRIGHT` | 50 | Boolean vector, +/BRIGHT = 23 |

### 4. Rotation Matrix Tests

**Priority: Medium | Difficulty: Medium**

For `INCLROTATE`, `LONGROTATE`, `LATROTATE`:

**Orthogonality test:**
```apl
M ← INCLROTATE θ
⌈/,|(M +.× ⍉M) - I    ⍝ Should be ~0 (within floating point)
```

**Determinant test:**
```apl
⌈/|1 - DET M          ⍝ Determinant should be 1
```

**Known rotations:**
- θ = 0: Identity matrix
- θ = π/2: 90° rotation (permutes axes)
- θ = π: 180° rotation

**Composition:**
```apl
(INCLROTATE A) +.× (INCLROTATE B) ≡ INCLROTATE A+B
```

### 5. Coordinate Transformation Tests

**Priority: High | Difficulty: Medium**

**CARTRIPLET / RADECDIST round-trip:**
```apl
dist RADECDIST CARTRIPLET ra_dec    ⍝ Should return ra_dec
```

Test cases:
- RA = 0, 6, 12, 18 hours
- Dec = -90, 0, 45, 90 degrees
- Distance = 1, 10, 100 AU

**PROJECTION / MAPCARTESIAN:**
- Zenith (Alt=90) maps to origin
- Horizon (Alt=0) maps to edge of circle
- Cardinal directions preserved

### 6. Orbital Mechanics Solvers

**Priority: Critical | Difficulty: Hard**

#### KEPLINVERSE (Kepler's Equation)

For eccentricity E and mean anomaly M, find eccentric anomaly ψ such that:
```
M = ψ - E·sin(ψ)
```

**Test procedure:**
```apl
E ← 0.5
M ← 1
PSI ← E KEPLINVERSE M
|M - E KEPLERFN PSI| < 1E¯10    ⍝ Must be true
```

**Test cases:**
| E | M | Expected PSI |
|---|---|--------------|
| 0 | 1 | 1 (no correction for circular orbit) |
| 0.5 | 1 | ~1.499 |
| 0.9 | 1 | ~1.862 (high eccentricity) |

**Convergence tests:**
- All E ∈ [0, 0.99]
- All M ∈ [0, 2π]
- Should converge in < 20 iterations

#### COMETSOLVE (Parabolic Orbits)

Similar structure - verify `AREA` function at solution equals input time.

### 7. Position Calculation Tests

**Priority: Critical | Difficulty: Hard**

#### PLANETPOS
Computes heliocentric Cartesian coordinates.

**Test approach:** Compare with JPL Horizons or Stellarium for known dates.

Test cases with date JNU 1 14 1974:
```apl
DATE PLANETPOS EARTH     ⍝ Earth's heliocentric position
DATE PLANETPOS planets   ⍝ All 9 planets
```

**Validation:**
- Distance from sun: compare with known orbital radii
- Position angle: compare with ephemeris data

#### MOONPOS
```apl
MOONPOS DATE             ⍝ Returns RA, Dec, Distance
```

**Validation:** Compare with lunar ephemeris.

#### EARTHVIEW
Converts heliocentric to geocentric equatorial.

```apl
DATE EARTHVIEW 0 0 0     ⍝ Sun's position from Earth
```

### 8. Pipeline Integration Tests

**Priority: Critical | Difficulty: Medium**

#### CALCULATEPLANETS

**Setup:**
```apl
DATE ← JNU 1 14 1974
LAT ← 40
LONG ← ¯75
TIME ← 21
STATEDDAYNO ← DATE
STATEDTIME ← TIME
```

**Assertions:**
```apl
CALCULATEPLANETS
⍴PLANETS ≡ 12 3          ⍝ 12 objects × 3 values (RA, Dec, Dist)
⍴VP ≡ 12                 ⍝ Visibility vector
⍴AAE ≡ (+/VP) 3          ⍝ Alt/Az for visible only
```

#### CALCULATESTARS

**Assertions:**
```apl
CALCULATESTARS
2 = ≢⍴STARCOORD          ⍝ Must be matrix
(⊃⌽⍴STARCOORD) = 2       ⍝ 2 columns (X, Y coordinates)
```

#### WORK (Full Pipeline)

```apl
WORK                      ⍝ Should complete without error
```

### 9. Edge Case Tests

**Priority: Medium | Difficulty: Hard**

| Scenario | Parameters | Risk |
|----------|------------|------|
| North Pole | LAT = 90 | Division by zero in azimuth |
| South Pole | LAT = -90 | Same |
| Dateline East | LONG = 180 | Wrap-around |
| Dateline West | LONG = -180 | Same |
| Midnight | TIME = 0 | Day boundary |
| Noon | TIME = 12 | Sun at meridian |
| Zenith object | Alt = 90 | Azimuth undefined |
| Horizon object | Alt = 0 | Refraction effects |

### 10. Regression Tests

**Priority: Critical | Difficulty: Easy**

Tests for bugs fixed in CHANGES.md:

| Bug | Test |
|-----|------|
| EARTH returns vector | `1 = ≢⍴EARTH` must be false; `2 = ≢⍴EARTH` must be true |
| ORBROTATE wrong shape | `⍴DATE PLANETPOS planets` = 9 3 |
| EARTHVIEW fails on vector | `DATE EARTHVIEW 0 0 0` must not error |
| AREADERIV wrong coefficient | `DATE COMETPOS kohoutek` must complete |
| CALCULATEPLANETS column mismatch | `CALCULATEPLANETS` must not error |
| CALCULATESTARS name conflict | `CALCULATESTARS` must not error |

---

## Test Infrastructure

### Using gritt for Batch Testing

```bash
# Start Dyalog
RIDE_INIT=SERVE:127.0.0.1:14502 dyalog +s -q &

# Clear and link
gritt -addr localhost:14502 -e ")clear"
gritt -addr localhost:14502 -e "⎕SE.Link.Create '#' '/path/to/APLSource'"

# Run test
gritt -addr localhost:14502 -e "PI"
```

### Proposed APL Test Harness

```apl
∇ Z←ASSERT COND;MSG
  :If ~COND
    MSG←'ASSERTION FAILED'
    ⎕←MSG
    Z←0
  :Else
    Z←1
  :EndIf
∇

∇ Z←ASSERT_EQ(A B);MSG
  :If A≢B
    MSG←'Expected ',⍕B,' got ',⍕A
    ⎕←MSG
    Z←0
  :Else
    Z←1
  :EndIf
∇

∇ Z←ASSERT_NEAR(A B TOL)
  Z←TOL>|A-B
∇
```

### Test File Structure

```
test/
├── test_trig.apl           # Trigonometry and conversions
├── test_julian.apl         # JNU date function
├── test_data.apl           # Data shape validation
├── test_rotation.apl       # Rotation matrices
├── test_coordinates.apl    # Coordinate transformations
├── test_kepler.apl         # Orbital solvers
├── test_positions.apl      # PLANETPOS, MOONPOS, etc.
├── test_pipeline.apl       # CALCULATEPLANETS, CALCULATESTARS
├── test_edge_cases.apl     # Boundary conditions
├── test_regression.apl     # Bug regression tests
├── run_all.apl             # Test runner
└── test_display.sh         # Interactive flow test (existing)
```

---

## Validation Data Sources

For verifying astronomical calculations:

1. **JPL Horizons** (https://ssd.jpl.nasa.gov/horizons/)
   - Ephemeris data for any date
   - Planet/moon positions

2. **Stellarium** (https://stellarium.org/)
   - Cross-reference visual positions
   - Altitude/azimuth verification

3. **USNO Astronomical Almanac**
   - Official reference data
   - Solar/lunar positions

4. **Original STARMAP Book**
   - Example outputs in appendices
   - Test cases from 1974

---

## Implementation Priority

1. **Immediate** (catch obvious bugs)
   - Regression tests for fixed bugs
   - Data shape validation
   - Pipeline completion tests

2. **Short-term** (verify correctness)
   - Trig function round-trips
   - Rotation matrix properties
   - Kepler solver verification

3. **Medium-term** (validate accuracy)
   - Position calculations vs. ephemeris
   - Edge case handling

4. **Long-term** (comprehensive)
   - Full coordinate transform testing
   - Historical date validation
   - Performance benchmarks
