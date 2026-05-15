STARMAP
=======

## An aside regarding this repository

This is based on [Stephen Taylor's scan of the STARMAP book](https://github.com/5jt/STARMAP).
I intend to create a PR there, once I have updated this documentation and checked
for any stray files that might have found their way committed to GitHub.

Work done:

* Make it work with Dyalog APL
* Add tests based on JPL data
* Fix some issues such as transcription ones
* Create a simple web UI - hosted at https://starmap.kirsopp.me
  - [Sample .svg created](animated.svg) (very small - download and open in a browser)
  - [Sample .mp4 of the web UI](starmap-animation-demo.mp4) (large - but should work everywhere)

## Back to the original README...

![Sample output of program to plot heliocentric coordinates](book/extracted-figures/figure-05.png)

This is a project to recreate STARMAP, a classic example of Expository Programming:

> the art of writing a program that is both executable by machine, and makes clear to a human reader what it does and how it works.
> 
> […]
> 
> The idea was to explain the movement of the stars and planets across the sky and to do it by writing programs that clearly stated the simple formulas that described their motion.
> 
> — from Paul Berry, "[Expository Programming](vector/expository-programming.md)" in *Vector*, Vol.22, No.3


Background
----------

(Courtesy of ChatGPT 5.2)

STARMAP is a well-known example of *expository programming* from IBM’s APL culture in the 1970s–1980s, though—like many such artefacts—it existed more as a *tradition* than as a single, canonically frozen program.

What follows is what can be said with reasonable confidence, and where the historical record becomes thinner.

---

### 1. What STARMAP was

**STARMAP** was an APL program that generated a textual (and sometimes character-graphic) map of the night sky: stars plotted by right ascension and declination, typically for a given observer latitude and date/time. Its output was usually a printed page or terminal display rather than a graphical plot in the modern sense.

Its purpose was not primarily astronomical utility, but **demonstration**:

* demonstration of APL’s expressive power,
* demonstration of array thinking applied to a real-world domain,
* demonstration of how a non-trivial problem could be presented *readably* in APL.

It therefore sat alongside other “showpiece” programs such as **LIFE**, **GAME**, **MANDEL**, **TICTACTOE**, and various calendar and ephemeris examples.

---

### 2. Expository programming context

The term *expository programming* was actively used in IBM APL circles, particularly influenced by:

* Ken Iverson’s belief that programs should *explain* ideas,
* the pedagogical style of *APL Quote Quad*,
* IBM’s internal and customer-facing APL training materials.

STARMAP exemplified several expository ideals:

* **Dense but meaningful expressions**: compact lines whose structure mirrors the mathematics.
* **Minimal control flow**: emphasis on whole-array transformations rather than loops.
* **Narrative layout**: variables named for concepts (RA, DEC, LAT), functions ordered to tell a story.
* **Mathematics close to notation**: spherical trigonometry expressed almost verbatim in APL glyphs.

A knowledgeable reader was expected to *read* the program as much as *run* it.

---

### 3. Typical technical characteristics

While versions varied, most STARMAP programs shared these features:

#### Astronomical model

* Star catalogue: usually a small built-in table of bright stars (often ~50–100), with:

  * right ascension,
  * declination,
  * magnitude.
* Simplified astronomy:

  * sidereal time computed from date/time,
  * conversion from equatorial to horizontal coordinates,
  * neglect of precession, nutation, refraction (or very rough approximations).

Accuracy was “educationally respectable” rather than observatory-grade.

#### Coordinate transforms

These were a major didactic focus:

* vectorised spherical trigonometry,
* use of APL’s inner/outer products to express rotations,
* masking of stars below the horizon using Boolean arrays.

This made STARMAP a favourite example for showing how APL eliminates explicit iteration.

#### Output

* Fixed-width character grid (often 60×60 or similar).
* Zenith at centre, horizon as a circle.
* Stars plotted as `*`, `+`, or magnitude-dependent symbols.
* Cardinal directions labelled (N, S, E, W).

On line printers, the result was striking and memorable.

---

### 4. Distribution and provenance

There was **no single official IBM-blessed STARMAP source** in the way there was, say, an official APL interpreter.

Instead, STARMAP circulated through:

* IBM internal libraries,
* SHARE and GUIDE APL user groups,
* APL Quote Quad listings,
* training courses and conference handouts,
* informal copy-and-modify sharing between sites.

As a result:

* multiple dialects existed (APL\360, APLSV, VS APL, later APL2),
* variable names, formatting, and even algorithms differ between versions,
* comments were sometimes extensive, sometimes sparse.

Many people remember *having seen* STARMAP rather than *which* STARMAP they saw.

---

### 5. Why it became iconic

STARMAP achieved minor legendary status because it hit several sweet spots simultaneously:

* **Non-toy problem**: real astronomy, not contrived arithmetic.
* **Visually rewarding output** from a line printer or glass TTY.
* **Mathematical elegance** well matched to APL’s strengths.
* **Cultural resonance**: mapping the heavens felt suitably grand for a language evangelised as “notation as a tool of thought”.

For many programmers, STARMAP was the first time APL *felt inevitable* rather than merely clever.


Project goals
-------------

1.  **Republish STARMAP on the Web**

	The source is a printed copy of <cite>STARMAP</cite> by Paul C. Berry & John R. Thorstensen published in 1978 by APL Press in San Francisco, first published in 1973 by IBM Corp. as Technical Report No. 02.665.

2.  **Recreate the code in Dyalog APL**

	The core logic of STARMAP is printed in the book.
	Most of the input and output functions are not.

	This phase will reproduce the core logic as closely as possible.
	Visual fidelity cannot be exact: modern APL does not use the overstruck alphabetic characters in use in 1973.

	Some unpublished input functions need to be recreated from their descriptions.

	The unpublished output functions that drove IBM plotters will be ignored.

	Testing the code results used by the output functions is a challenge:
	the book includes no examples.

3.  **Refactor the code in Dyalog APL**

	APL has advanced considerably since 1973.

	A modern version of the core logic should be both
	more readable and more functional.

4.  **Deploy STARMAP as an API**

5.  **Develop an HTML front end**