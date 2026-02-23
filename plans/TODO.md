# TODO

## Active tasks

None currently.

## Up next

- Continue proofreading transcribed book text
- Address other transcription errors (code blocks, special characters)

## Blocked

None currently.

## Completed

- **Star table reconstruction** (issue #1, PR #2 merged)
  - Re-derived 332 rows from Yale BSC5 catalog
  - Documented in `docs/star-table-reconstruction.md`
- Initial transcription of book to Markdown
- Extraction of figures from page images
- Inclusion of "Expository Programming" article
- Manual proofread of expository programming article

---

## Session log

### 2026-02-23
- Fixed moon duplication bug in CALCULATEPLANETS: book's `1 0⌽PLANETS` was misread `1 0↓PLANETS` (drop moon row before SKYPOS, since moon already handled with parallax)
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
