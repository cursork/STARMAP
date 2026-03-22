// STARMAP book template
// Faithful reproduction of the 1978 book style, rendered at A5

// ── Page setup ──────────────────────────────────────────────
#let starmap-book(body) = {
  set page(
    paper: "a5",
    margin: (
      top: 18mm,
      bottom: 20mm,
      left: 15mm,
      right: 15mm,
    ),
    header: none,
    footer: context {
      align(center)[
        #text(size: 7pt)[#counter(page).display()]
      ]
    },
  )

  // ── Body text ───────────────────────────────────────────
  set text(
    font: "Courier",
    size: 7.5pt,
    lang: "en",
    region: "us",
  )

  set par(
    justify: true,
    leading: 0.55em,
    first-line-indent: 2em,
  )

  // ── Headings: underlined, not bold ──────────────────────
  show heading.where(level: 1): it => {
    v(1.2em)
    set text(size: 7.5pt, weight: "regular")
    block[
      #underline(offset: 2pt)[#it.body]
    ]
    v(0.6em)
  }

  show heading.where(level: 2): it => {
    v(0.8em)
    set text(size: 7.5pt, weight: "regular")
    block[
      #underline(offset: 2pt)[#it.body]
    ]
    v(0.4em)
  }

  // ── Code blocks ─────────────────────────────────────────
  // Layout only — no font override. Font comes from surrounding context.
  // APL code blocks use #apl-block wrapper which sets APL385.
  // Data tables use #data-table wrapper which sets Courier at small size.
  show raw.where(block: true): it => {
    set par(justify: false, first-line-indent: 0em)
    block(
      inset: (left: 2em, top: 0.3em, bottom: 0.3em),
    )[#it]
  }

  // ── Inline code ─────────────────────────────────────────
  show raw.where(block: false): it => {
    text(font: "APL385 Unicode", size: 7pt)[#it]
  }

  // ── Figures ─────────────────────────────────────────────
  show figure.caption: it => {
    set text(font: "Helvetica", size: 6.5pt, style: "italic")
    it
  }

  set figure(
    placement: none,
    gap: 0.8em,
  )

  body
}

// ── Helper functions ────────────────────────────────────────

// Indented paragraph (first line indent is automatic via par settings,
// but this wrapper ensures the paragraph break)
#let indent(body) = {
  par[#body]
}

// Inline APL code
#let apl(body) = {
  text(font: "APL385 Unicode", size: 7pt)[#body]
}

// APL code block (wrapper to ensure proper styling)
#let apl-block(body) = [
  #set text(font: "APL385 Unicode", size: 7pt)
  #body
]

// Fixed-width data table (Courier, small, no wrapping)
#let data-table(body) = [
  #set text(font: "Courier", size: 5pt)
  #body
]

// Parameter definition (name + description on same line, hanging indent)
#let param(name, desc) = {
  set par(first-line-indent: 0em)
  block(inset: (left: 4em))[
    #h(-4em)#name#h(1em)#desc
  ]
}
