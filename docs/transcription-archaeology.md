# Recovering STARMAP: a transcription archaeology

In January 2026, the STARMAP program — a set of APL functions written by
Paul C. Berry and John R. Thorstensen for a 1973 IBM astronomy exhibit —
was transcribed from the printed pages of their 1978 book into modern Dyalog
APL source files. The program computes star, planet, Moon, and Sun positions
for any date and location, projects them onto a sky dome, and draws a map.

The transcription produced 84 source files. None of them worked. What
followed was a month-long excavation through nested rotation matrices,
Julian day arithmetic, and Keplerian orbital mechanics, uncovering roughly
twenty transcription errors — not bugs in the original algorithm, but
mistakes introduced when reading printed APL characters off a page. This
document describes those errors, the patterns behind them, and how they
were found.


## The medium is the problem

APL was designed to be written by hand on a specialised keyboard and read
on a screen or lineprinter. The 1978 book reproduces the program listings
photographically from typewriter output. Several APL glyphs differ by a
single stroke or by the direction of an arrow:

| Glyph | Name | What it does |
|-------|------|-------------|
| `⊖` | reverse-first | Flips rows (vertical flip) |
| `⌽` | reverse-last | Flips columns (horizontal flip) |
| `⍉` | transpose | Swaps axes |
| `-` | minus (function) | Negates its right argument |
| `¯` | high-minus (constant) | Negative sign in a number literal |

In the book's typeface, `⊖` and `⌽` are nearly identical — both are
circles bisected by a line, differing only in whether the line is vertical
or horizontal. A negation sign before a variable can be missed entirely in
a dense formula. These ambiguities account for the majority of bugs.


## The errors, by family

### Family 1: the `⊖`/`⌽` confusion

Three functions had `⊖` (reverse-first, a vertical flip) where `⌽`
(reverse-last, a horizontal flip) was intended, or vice versa. In a 3×3
matrix context, this swaps completely different pairs of basis vectors,
producing rotations around the wrong axis.

**MAPCARTESIAN** converts projected polar coordinates to Cartesian for
plotting. The book says (p. 545) that it must swap the column order because
"altitude and azimuth are conventionally grouped in the opposite order from
right ascension and declination." The correct operation is `⌽CARTESIAN⌽X`
(swap columns before and after). The transcription had `⊖CARTESIAN⊖X`
(swap rows), which feeds radius as angle and azimuth as magnitude. Every
plotted point ended up at the wrong position.

**PRECESS** applies precession of the equinoxes to star positions. The
rotation matrix ROT is built by composing three matrices (de-tilt ecliptic,
rotate in ecliptic, re-tilt). The final line multiplies the star positions
by ROT. The transcription had `X+.×⊖ROT` — a row-reversal of the 3×3
matrix that swaps the first and third basis vectors. This is not transpose,
not inverse, and not any geometrically meaningful operation. It shifted
every star's right ascension by about ten hours. The correct line is simply
`X+.×ROT`.

**LATROTATE** generates a rotation matrix for the observer's latitude.
It is defined in terms of INCLROTATE (the inclination rotation) with an
axis swap. The correct form is `⌽⊖INCLROTATE LAT` (one column-flip and
one row-flip, which together transpose and negate certain elements to
convert between inclination and latitude conventions). The transcription
had `⊖⊖INCLROTATE LAT` — two row-flips, which cancel out to the
identity, leaving LATROTATE as simply INCLROTATE. The result: the
observer's latitude had no effect on the sky projection.


### Family 2: missing negation signs

Four functions were missing a `-` (negate) before a term. In printed APL,
a function-minus before a variable name is a small mark easily overlooked,
especially when the variable name itself begins with a tall character.

**PRECESS** (line 6): the precession angle was positive where it should
be negative. The line builds a longitude rotation matrix:

```apl
PRECESSION←LONGROTATE INTERVAL×2×PI÷25800×YRLENGTH    ⍝ wrong
PRECESSION←LONGROTATE-INTERVAL×2×PI÷25800×YRLENGTH    ⍝ correct
```

The reason the sign matters is subtle. STARMAP uses row-vector
multiplication: `X +.× M` rather than `M +.× X`. In this convention the
effective rotation is M-transposed, which reverses the rotation direction.
To compensate, the angle must be negated. With the wrong sign, precession
ran backwards — for stars at J2000 precessed to 1974, the error doubled
rather than correcting, producing about 0.7° of displacement.

This bug was invisible until a Skyfield/JPL reference dataset was built
for all 332 stars. With only the `⊖` fix applied, the remaining star
error looked plausible ("maybe the linear precession model is just
approximate"). Only when the Skyfield reference was switched from ICRS to
equinox-of-date coordinates did the systematic directional bias become
obvious.

**MOONPOS** (line 4): ecliptic-to-equatorial coordinate conversion used
positive obliquity instead of negative:

```apl
GQ←3 RADECDIST GC+.×INCLROTATE RADIAN AXITILT     ⍝ wrong
GQ←3 RADECDIST GC+.×INCLROTATE-RADIAN AXITILT     ⍝ correct
```

EARTHVIEW performs the identical conversion for planets and uses the
negative sign. The missing negation swung the Moon's declination by
roughly 47° (twice the obliquity).

**SKYPOS** (line 14): the azimuth sign extraction `S←×GQ[;3]` should be
`S←-×GQ[;3]`. After the equatorial-to-horizontal rotation, the
z-component has the opposite sign from what the azimuth formula expects.
Without the negation, all objects are reflected East-West.


### Family 3: APL right-to-left evaluation

APL has no operator precedence. All expressions evaluate strictly
right-to-left. A formula that looks correct to a mathematician can
silently compute the wrong thing.

**JNU** (line 9): the Gregorian calendar correction from Meeus is
`B = 2 − A + ⌊A/4⌋`. The transcription wrote:

```apl
B←2-A+⌊A÷4     ⍝ APL reads this as: 2 - (A + ⌊A÷4⌋)
```

For 1974 with A=19, this gives B = −21 instead of the correct B = −13.
The fix:

```apl
B←(2-A)+⌊A÷4   ⍝ parentheses force the correct grouping
```

The 8-day Julian day number error cascaded through the entire pipeline:
sidereal time was off by about 5°, and planetary ephemerides shifted by
eight days' worth of orbital motion.


### Family 4: decimal point displacement

**moon.aplf** (line 5): the Moon's secular drift rates — the daily change
in the ascending node longitude and the argument of periapse — were exactly
ten times too small:

```
SECULAR_ASC:  ¯0.0052953922  (transcribed)  →  ¯0.052953922  (correct)
SECULAR_PERI:  0.01114040803 (transcribed)  →   0.1114040803 (correct)
```

Over the 74 years between the elements' 1900 epoch and the 1974 test
date, the ascending node error accumulated to about 1300° (3.6 complete
revolutions). The Moon's ecliptic longitude was wrong by roughly 200°,
placing it on the opposite side of the sky. This bug survived until all
other Moon-related fixes were in place, because the MOONPOS sign error
(family 2) already made the output nonsensical — one garbage result
masked another.


### Family 5: wrong epochs and constants

Three errors involved numerical constants that were simply wrong — either
misread from the book or taken from the wrong table.

**planets.aplf**, column 10 (DATE_ASC): all nine rows had JD 2443600.5
(2 April 1978) as the anomaly reference epoch. But the anomaly values in
column 7 correspond to the American Ephemeris for 1973, epoch JD 2441720.5
(January 1973). The 1880-day discrepancy shifted every planet by hundreds
of degrees — the Sun was off by 3.4 hours in right ascension, Mars by
over nine.

**EQUINOX.apla**: 2441761.5 instead of the correct 2441762.5. An off-by-one
in the Julian day number of the 1973 vernal equinox. This shifted sidereal
time by about 1° for all observations.

**CALCULATESTARS**: passed the absolute Julian day number (~2,442,000) as
the precession interval to PRECESS, instead of the difference from the
catalogue epoch. A J2000 catalogue precessed by 2.4 million days
(~6600 years) produces about 93° of spurious rotation. The fix introduced
a `CATEPOCH` constant (JD 2451545, J2000.0) and changed the call to
`(DATE-CATEPOCH)PRECESS STARS`.


### Family 6: shape and rank mismatches

The original program ran in a 1973 APL workspace where data shapes were
established interactively. Modern Dyalog APL, loading functions from
individual source files, is stricter about rank. Several functions received
vectors where they expected matrices or vice versa.

**EARTH.aplf**: `(planets)[3;]` returns a rank-1 vector in Dyalog, but
downstream functions index with `ORB[;7]` (matrix column selection). Fix:
`planets[,3;]` (comma-indexing preserves the matrix rank).

**ORBROTATE.aplf**: a reshape operation `((1↓⍴H),×/1↑⍴H)⍴H` produced
shape 3 1 9 instead of the intended 9 3. The dimension formula assumed a
different axis convention.

**SKYPOS**: an unpaired parenthesis in the original CARTRIPLET/NORM line
caused a syntax error, and a later line passed an N×2 matrix to ARCCOS
where only one column was intended.


## How the errors were found

The bugs were not found in book order. They were found in the order that
allowed something to run.

**Phase 1 — make it not crash** (24 January). The shape and rank errors
(family 6) and the AREADERIV coefficient error (a comet-orbit function
with `1÷8` instead of `3÷4` in its derivative) prevented the program from
producing any output. These were fixed first because they caused `DOMAIN
ERROR` or `RANK ERROR` before anything could be computed.

**Phase 2 — make it draw** (22 February). With the program running but
producing a blank map, MAPCARTESIAN's `⊖`/`⌽` error was the blocker. After
fixing it, a star map appeared for the first time — but with all the stars
in the wrong positions.

**Phase 3 — make the sky right** (24–25 February). LATROTATE and SKYPOS
fixes corrected the altitude-azimuth projection so that the horizon and
cardinal directions were correct. JNU's precedence error was found by
comparing Julian day numbers against Meeus's published tables. The planet
epoch error was found by comparing Sun RA against JPL Horizons.

**Phase 4 — precision** (25 February). With the broad structure correct,
a Skyfield/JPL reference dataset was generated for all 332 stars, the Moon,
and the Sun, at the program's example date (16 May 1974, Anaheim CA). This
revealed the two PRECESS bugs (the residual `⊖` and the sign error) and
all three Moon bugs (MOONPOS sign, secular rate decimal points). The star
catalogue was also expanded from 50 to 332 entries to match the book's
full appendix.


## Validation

The final program matches external references within the expected accuracy
of its simplified models:

| Object class | Max error | Reference source | Limiting factor |
|-------------|-----------|-----------------|----------------|
| 332 stars | 0.010° | Skyfield (IAU 2006 precession) | Linear precession model; no nutation or aberration |
| Sun | 0.006° | JPL DE421 ephemeris | Keplerian orbit (no perturbations) |
| Moon | 2.5° | JPL DE421 ephemeris | Keplerian orbit (no lunar perturbation terms) |

The Moon's 2.5° error is an inherent limitation: the Moon's orbit is
subject to large perturbations (evection, variation, annual equation) that
a simple Keplerian model cannot capture. The 1973 program was designed for
a wall display at the IBM Exhibit Center, where this level of accuracy was
more than adequate.


## Lessons

Transcribing APL from a printed book is error-prone in ways that are
specific to APL. The glyph confusion (`⊖` vs `⌽`) has no analogue in
languages with keyword-based syntax. The precedence trap (right-to-left
evaluation) catches anyone who thinks in standard mathematical notation.
The negation sign, a single character that reverses a rotation, is
physically tiny on a printed page.

The bugs also had a tendency to mask each other. The Moon had three
independent errors (tilt sign, node drift rate, periapse drift rate) that
each individually produced hundreds of degrees of displacement; fixing any
one or two still left the output obviously wrong. Systematic reference
testing — comparing every output against an independent source — was the
only reliable way to confirm that all errors had been found.

The original algorithms, once freed from transcription errors, are
remarkably good. A program written in 1973 for a typewriter terminal,
using only Keplerian orbits and linear precession, places 332 stars
within 0.01° of their true positions and the Sun within 0.006°. The code
itself — a few dozen short APL functions, none longer than twenty lines —
remains a model of expository programming.
