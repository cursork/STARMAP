# Book modernisation plan

Re-render the 1978 STARMAP book as A5 PDF using Typst. First reproduce the existing content faithfully, then update code to Dyalog v20.

## Principles

1. **Original first.** Convert `book/markdown/starmap.md` as-is to Typst and get a faithful A5 rendering before changing anything.
2. **Same book, new code.** Only update code listings and prose that the code changes invalidate. Everything else stays.
3. **No fanciness.** Match the original style. No modern design, no added commentary.

## Phase 1: Typst rendering of existing content

**Status**: In progress — first working render complete, refinements remaining.

Convert `book/markdown/starmap.md` as it stands into Typst. Render as A5 PDF matching the original book's style.

### Layout targets

| Element | Style | Status |
|---------|-------|--------|
| Page size | A5 (148 × 210 mm) | Done |
| Body font | Courier 7.5pt | Done |
| Code font | APL385 Unicode 7pt | Done |
| Headings | Underlined, not bold | Done |
| Paragraphs | First line indented, justified | Done |
| Page numbers | Centred at bottom | Done |
| Figure captions | Sans-serif, centred, italic | Done |
| Code blocks | Indented via `#apl-block` wrapper | Done |
| Data tables | Courier 5pt via `#data-table` wrapper | Done |
| Star table | All 332 rows, Courier 4.5pt | Done |
| Margins | 15mm L/R, 18mm top, 20mm bottom | Done |

### Files
- `book/typst/template.typ` — page layout, fonts, helper functions
- `book/typst/starmap.typ` — full document content
- `book/typst/star-table.txt` — 332-row star catalog (extracted from markdown)
- `book/typst/output/starmap-original.pdf` — rendered PDF

### Build command
```
cd book/typst && typst compile --root ../.. starmap.typ output/starmap-original.pdf
```

### Remaining work
- Table 1 (function call hierarchy diagram) — not yet included
- Figure numbering: rotation matrices figure is out of order (shows as Fig. 10, should be Fig. 6) because the sections follow markdown order, not original book page order
- Page break tuning to better match original page boundaries
- Compare rendered output against original page scans for layout fidelity

### Fonts
- Body: Courier (system)
- Code: APL385 Unicode (Dyalog)
- Captions: Helvetica (system)

## Phase 2: Code audit

Diff every code listing in the rendered document against `APLSource/*.aplf`. Classify each difference as transcription fix, bug fix, or Dyalog adaptation. Check original page scans to confirm what the book actually printed.

### Deliverable
- Table of every code listing, whether it changes, why, and whether surrounding prose needs adjustment

## Phase 3: Apply updates

Replace code listings with working Dyalog v20 code. Update prose only where invalidated by code changes. Do not add or remove prose beyond what's necessary.

### Rules
- Variable name changes (e.g. `STARS` → `STARDATA`): update prose references
- Operator changes (e.g. `IF` with `/` → `⌿`): update prose that describes the operator
- Do not explain why something changed — the book should read as though the code was always this way

## Phase 4: Validate

- Side-by-side: phase 1 PDF vs phase 3 PDF — only deliberate changes
- Code: verify every listing matches working `APLSource/` code
- Tests: full suite passes via gritt

## Open questions

1. Cover page: reproduce the original design or just title page?
2. Star table: the markdown already has the BSC5-derived table — use that in both phases?
3. Figures: use existing extractions from `book/extracted-figures/` or re-extract?
4. Addendum for new work: separate document, or reserved section at the end?
