# TODO

## Active tasks

- Continue proofreading transcribed book text
- Clean up debug scripts (`debug_skypos*.py`, `debug_final.py`) from sky position investigation

## Up next

- Update ENTRY documentation to clarify UTC input convention
- Tighten SUN_TOL in TEST_POSITIONS (currently 3 deg, actual error 0.006 deg; comment about LST error is misleading for geocentric RA/Dec)

## Blocked

None currently.

## Completed (this session)

- **Restore book-faithful APL architecture** (branch `restore-book-architecture`)
  - 11 selector functions: removed `:If`/`:Else` rank guards, restored `Z←ORB[;N]` one-liners
  - EARTHVIEW: removed `⍣` power-operator rank guard, callers now pass matrices
  - SKYPOS: restored book's `⍉(⌽⍴GQ)⍴NORM` normalization idiom (replaces `∘.×` outer product)
  - CALCULATESTARS: restored `10` placeholders, `STARDATA` local (Dyalog scoping prevents shadowing `STARS` niladic function)
  - CALCULATEPLANETS: restored `(3≠⍳9)⌿planets` boolean mask, `10` placeholders, `1 3⍴0 0 0` matrix for sun, kept `PLANETAA`
  - Dyalog constraints: `⌿` instead of `IF` for matrix compression (book's `/` via `IF` doesn't work on N×2 matrices in Dyalog); `STARDATA`/`MN`/`SN`/`KO` variable names (can't shadow niladic functions)
  - Fixed COMETPOS: ensure always-matrix output for EARTHVIEW (prevented RANK ERROR for live comet dates Oct 1973–Apr 1974)
  - Fixed PLANETSPOS: `planets[,P;]` ensures matrix ORB for scalar planet index
  - New TEST_SKYPOS: 9 bright stars + Sun alt/az, visibility count (0.005 deg max error)
  - New TEST_PIPELINE: CALCULATESTARS + CALCULATEPLANETS end-to-end shapes and values
  - All 7 tests pass, visual render matches EXAMPLE_RENDER.png reference

## Previously completed

- **Planet epoch fix** (branch `fix-sky-coordinates`)
  - Fixed ANOMALYDATE inconsistency in `planets.aplf`: column 10 changed from JD 2443600.5 to JD 2441720.5
  - After fix: planet RA/Dec matches JPL Horizons to 1–7 minutes
  - Documented as bug #12 in `docs/calculation-fixes.md`

- **Sky position fix** (branch `fix-sky-coordinates`)
  - Root-caused the "all objects in top-right quadrant" bug to two transcription errors
  - JNU.aplf: `B←2-A+⌊A÷4` → `B←(2-A)+⌊A÷4` (APL precedence)
  - SKYPOS.aplf: `S←×GQ[;3]` → `S←-×GQ[;3]` (azimuth sign)
  - Added TEST_JNU with 5 reference Julian day numbers
  - Created `docs/calculation-fixes.md`

- **Terminal rendering** (branch `terminal-rendering`)
  - New utilities: JNUINV, DAYNAME with tests
  - 5 output functions: CAPTION, REPORTPLANETS, PLOTSTARS, REPORTSTARS, PRINTED
  - Full pipeline end-to-end at ⎕PW=80 and ⎕PW=120

- **Star table reconstruction** (issue #1, PR #2 merged)
  - Re-derived 332 rows from Yale BSC5 catalog
  - Documented in `docs/star-table-reconstruction.md`

- Initial transcription of book to Markdown
- Extraction of figures from page images
- Inclusion of "Expository Programming" article
- Manual proofread of expository programming article

---

## Session log

### 2026-02-26 (restore book architecture)
- Created branch `restore-book-architecture` from `fix-sky-coordinates`
- Removed `:If`/`:Else` rank guards from 11 selector functions (ANOMALY, ANOMALYDATE, ASCENDING, ECCENTRICITY, EPOCHDATE, INCLINATION, PERIANGLE, PERIDIST, PERIOD, SECULAR, SEMIMAJOR)
- Removed `⍣` rank guard from EARTHVIEW, updated callers to pass matrices
- Restored book's `⍉(⌽⍴GQ)⍴NORM` normalization idiom in SKYPOS
- Restructured CALCULATESTARS and CALCULATEPLANETS: `10` placeholders, `(3≠⍳9)⌿planets`, restored globals comments
- Fixed COMETPOS to always return matrix (prevented latent RANK ERROR for comet-active dates)
- Fixed PLANETSPOS `planets[,P;]` for scalar planet index
- Updated TEST_POSITIONS to pass `1 3⍴0 0 0` to EARTHVIEW
- New TEST_SKYPOS: alt/az validation for 9 bright stars + Sun
- New TEST_PIPELINE: end-to-end CALCULATESTARS + CALCULATEPLANETS validation
- Thorough review: verified TEST_POSITIONS JPL reference data is correct (date, precession, angular error formula, frame consistency, reference generation script)
- All 7 tests pass, visual render matches EXAMPLE_RENDER.png
- Files changed: 16 modified, 2 new tests
- Branch: `restore-book-architecture`

### 2026-02-25 (planet epoch fix)
- Fixed ANOMALYDATE inconsistency: planets.aplf column 10 changed from JD 2443600.5 to JD 2441720.5
- ANOMALY values were for ~1973 epoch, DATE_ASC claimed 1978 — all planet positions wrong by large amounts
- Added bug #12 to docs/calculation-fixes.md with impact analysis and JPL Horizons validation
- Updated Anaheim validation section to reference planet RA/Dec comparison
- Branch: `fix-sky-coordinates`

### 2026-02-25 (sky position fix)
- Root-caused the "all objects in top-right quadrant" bug using Python numerical verification against JPL Horizons
- Identified two transcription errors: JNU Gregorian correction (APL precedence) and SKYPOS azimuth sign
- Fixed JNU.aplf, SKYPOS.aplf, simplified JNUINV.aplf
- Added TEST_JNU.aplf (5 reference Julian day numbers)
- Created `docs/calculation-fixes.md` — comprehensive calculation bug report (11 bugs total)
- Updated CHANGES.md, TODO.md
- Branch: `fix-sky-coordinates` from `terminal-rendering`

### 2026-02-23 (session 2 — terminal rendering)
- Created branch `terminal-rendering` from `hacks`
- Wrote and tested JNUINV and DAYNAME utility functions
- Rewrote all 5 output functions (CAPTION, REPORTPLANETS, PLOTSTARS, REPORTSTARS, PRINTED) to match EXAMPLE_RENDER.png layout
- Added `PLANETAA←AA` to CALCULATEPLANETS (one line, preserves uncompressed alt/az)
- Fixed STARNAMES `⊂` bug, PLANETNAMES length mismatch, various APL precedence issues
- Full pipeline works at ⎕PW=80 and ⎕PW=120
- Identified critical bug: all sky objects cluster in top-right quadrant (upstream of rendering)
- Files changed: CALCULATEPLANETS, CAPTION, DAYNAME (new), JNUINV (new), PLOTSTARS, PRINTED, REPORTPLANETS, REPORTSTARS, STARNAMES, TEST_DAYNAME (new), TEST_JNUINV (new)

### 2026-02-23 (session 1)
- Fixed moon duplication bug in CALCULATEPLANETS: book's `1 0⌽PLANETS` was misread `1 0↓PLANETS`
- Fixed off-by-one planet labelling (consequence of moon duplication)
- Removed spurious Earth from planet computation (row 3 of `planets` excluded from `PLANETPOS` call)
- Replaced ASCII planet symbols with Unicode astronomical symbols (☾☉☿♀♂♃♄⛢♆♇☄)
- Updated PLANETNAMES to remove Earth
- Updated CHANGES.md section 6

### 2026-02-05
- Completed star table reconstruction from BSC5 catalog
- Created extraction script `yale-catalog/extract_stars.py`
- Compared BSC5 values against test rows from printed book
- Decision: use BSC5 values (current authoritative source)
- Discrepancies documented in `docs/star-table-reconstruction.md`
- Replaced table in `book/markdown/starmap.md` (332 rows)
- Fixed Pleiades row formatting, parallax column alignment
- Created PR #2, merged to main
- Issue #1 closed

### 2026-02-04
- Read project files and CLAUDE.md standing instructions
- Discussed star table reconstruction approach
- Decision: derive from Yale BSC5 catalog (original source)
- Key decisions documented:
  - Use J2000 epoch
  - Preserve original 332-star selection
  - Use APL high minus (¯) notation
- Created `plans/` folder with PLAN.md and TODO.md
- Created GitHub issue #1 for star table work
- Downloaded BSC5 catalog from Harvard/CfA
