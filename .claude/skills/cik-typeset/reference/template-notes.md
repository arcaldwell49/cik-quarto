# CiK template — reference notes

Supporting reference for the `cik-typeset` skill. The authoritative template lives in the
`arcaldwell49/cik-quarto` repository; this folder carries the bits the skill needs to
convert *toward* the right target.

## Files here

- **`example-article.qmd`** — the canonical finished CiK article (a copy of the repo's
  `template.qmd`). This is your worked example: read it to see the exact front matter,
  figure syntax, table approach (flextable), section ordering, and math handling that a
  converted article must match.
- **`example-reflist.json`** — example CSL-JSON bibliography entry, showing the structured
  shape Crossref/`cr_cn` returns and that the CiK extension consumes.

## Where the template machinery lives

The CiK Quarto **extension** (the format definitions, LaTeX class, CSL, partials) is **not**
duplicated here. It is installed per-project under `_extensions/cik/`:

```
_extensions/cik/
  _extension.yml         # defines the cik-pdf / cik-html / jats formats
  cik.cls                # LaTeX document class (title page, two-column front matter)
  apa7.csl               # APA 7th edition citation style (the journal default)
  *.lua, partials/*.tex  # filters and template partials
```

To make a submission folder renderable:

```bash
# in the submission folder
quarto install extension arcaldwell49/cik-quarto
```

or copy the repo's `_extensions/cik/` directory in.

## Format facts the converter relies on

- Output formats are named **`cik-pdf`** and **`cik-html`** (not plain `pdf`/`html`).
- PDF engine is **xelatex**; `documentclass: cik`.
- Citations use **citeproc** with **`apa7.csl`** (author–date, APA 7). The extension sets
  this by default — a per-document `csl:` is only needed to override.
- Default bibliography in the template is `reflist.json` (CSL-JSON); this skill instead
  emits and points at a verified **`references.bib`**. Either format works with citeproc.
- Figures: reference `figures/fig_N` **without extension** when both `.pdf` and `.png`
  exist (each format auto-selects), or `figures/fig_N.png` explicitly when only PNG is
  supplied. Label `{#fig-N}`, cross-ref `@fig-N` or `[Figure N](#fig-N)`.

## Render commands

```bash
quarto render <lastname>-<word>.qmd --to cik-pdf
quarto render <lastname>-<word>.qmd --to cik-html
quarto render <lastname>-<word>.qmd            # both, per the format: block
```

Requires Quarto **1.6+** (Pandoc **3.4+**). The template's `before-body.tex` defines
`\pandocbounded`, which older toolchains lack.
