---
name: cik-typeset
description: >-
  Convert a Communications in Kinesiology (CiK) author submission folder (a Word
  manuscript plus figure files) into a DRAFT Quarto article in the CiK template.
  Use when asked to typeset, convert, or draft a CiK submission, a CiK Word
  manuscript, or a STORK/Communications in Kinesiology article into the cik-pdf /
  cik-html Quarto format. Produces a reviewable draft .qmd, a verified .bib built
  from DOI lookups, and a references-review.md report — it does NOT finalize the
  article.
---

# CiK manuscript → Quarto draft

This skill turns an author submission (Word `.docx` + figures + a formatted reference
list) into a **draft** Quarto article using the Communications in Kinesiology (CiK)
template. The output is a clean starting point for a human typesetter — **not** a
finished article. You do not sign off on equations, finalize formatting, or resolve
flagged citations. Those stay with the typesetter (see [Handoff boundary](#handoff-boundary)).

Prefer the deterministic scripts in `scripts/` for conversion and verification. Reserve
your own judgment for the two things scripts cannot do well: parsing messy author
reference formatting, and body cleanup.

## Prerequisites

| Tool | Pinned / tested version | Notes |
|------|------------------------|-------|
| Quarto | **1.6.x** (≥ 1.6 required) | The template's `before-body.tex` defines `\pandocbounded` for Pandoc ≥ 3.4 / Quarto ≥ 1.6. Older Quarto will fail to render. |
| Pandoc | **3.4+** | Bundled with Quarto 1.6. Used directly for the `.docx` → `.qmd` body conversion. |
| R | **4.5.x** (4.5.3 confirmed on this machine at `C:\Program Files\R\R-4.5.3\bin\Rscript.exe`) | Runs the citation verifier and the schema check. |
| R package `rcrossref` | latest | DOI content negotiation (`cr_cn`) and title search (`cr_works`). |
| R packages `jsonlite`, `yaml` | latest | JSON/YAML parsing in the scripts. |

If `quarto`, `pandoc`, or `Rscript` is not on `PATH`, locate the executable first (on
this machine R lives under `C:\Program Files\R\R-4.5.3\bin\`) and call it by full path.
The Pandoc wrapper will fall back to `quarto pandoc` (Quarto's bundled Pandoc) when no
standalone `pandoc` is found.

## Inputs you expect in a submission folder

- One Word manuscript (`.docx`). DOC (legacy) should be re-saved as `.docx` first.
- Figures: per the house decision, figures arrive **either embedded in the Word doc or
  as separate `.png` files**. If you find neither — or find an unexpected format (TIFF,
  EPS, raw data, a PowerPoint of figures) — **stop and ask the user** rather than
  guessing.
- A formatted reference list (usually the last section of the `.docx`, sometimes a
  separate file).
- A metadata sheet or the standardized author block (authors, affiliations, ORCID,
  funding, COI). If absent, the corresponding front-matter fields become author queries.

## Output filename and layout

Write the assembled article as **`<lastname>-<descriptive-word>.qmd`** in the submission
folder — first author's surname plus one short descriptive word from the title, all
lowercase, hyphen-separated (e.g. `smith-altitude.qmd`, `nakamura-hrv.qmd`). Ask the user
if the right descriptive word is ambiguous.

Keep **mechanical conversion output separate from manual polish** so re-runs stay
idempotent (see [Idempotency](#idempotency)):

```
<submission folder>/
  manuscript.docx                 # author input (untouched)
  <lastname>-<word>.qmd           # ASSEMBLED article — front matter + curated body; hand-polished
  _body.generated.qmd             # MECHANICAL pandoc output — regenerated every run, never hand-edit
  references-asgiven.json         # your structured parse of the author reference list
  references.bib                  # verified bibliography (built from DOI lookups)
  references-review.md            # citation review report for the typesetter
  media/                          # images extracted from the .docx by pandoc
  figures/                        # final figure files wired into the article (.png / .pdf)
```

> The CiK extension itself (`_extensions/cik/`, `apa7.csl`, `cik.cls`) must be installed
> in or alongside the submission folder for the article to render. If the folder is not
> already a CiK Quarto project, run `quarto install extension arcaldwell49/cik-quarto`
> in it, or copy the repo's `_extensions/cik/` tree in. The bibliography path in the
> front matter should point at the `references.bib` this skill produces.

## Conversion procedure

Work top to bottom. Do not skip the review block at the end.

### 1. Body — mechanical conversion

Run the pinned Pandoc wrapper. It extracts embedded media and writes a *mechanical* body
file that you never hand-edit:

```powershell
# PowerShell (Windows)
.\scripts\convert-body.ps1 -Input "manuscript.docx" -OutDir "."
```
```bash
# bash / macOS / Linux
scripts/convert-body.sh manuscript.docx .
```

This produces `_body.generated.qmd` and a `media/` folder of any embedded images. The
wrapper uses fixed flags (see [Pinned Pandoc flags](#pinned-pandoc-flags)). Pandoc's
docx reader converts OMML equations to LaTeX `$…$` / `$$…$$` automatically.

### 2. Figures

- **Embedded in the doc:** they land in `media/`. Move/rename the ones that are real
  figures into `figures/` preserving the **author's figure numbering** (`fig_1`, `fig_2`,
  …). Discard logos/equation-rasters that pandoc extracted by mistake.
- **Separate `.png` files:** copy them into `figures/` with the same `fig_N` naming.
- Wire each figure into the template's figure syntax with a caption and a cross-reference
  label:

  ```markdown
  ![**Figure 1:** <caption text, math allowed e.g. $\beta$>](figures/fig_1.png){#fig-1 fig-align="center" width=100%}
  ```

  Cross-reference in text as `[Figure 1](#fig-1)` (the template's convention) or `@fig-1`.
- **Print quality:** the template ideally wants a vector `.pdf` *and* a `.png` sharing a
  basename (then you reference `figures/fig_1` with no extension and each format picks its
  file). Authors usually supply only `.png`. PNG renders in both HTML and PDF (xelatex),
  so reference the `.png` explicitly and **flag in the review block** that a vector/300+
  dpi version is preferred for print. Do not fabricate a PDF figure.
- Preserve author figure numbering exactly. If figures are out of order or a number is
  missing, flag it — do not renumber silently.

### 3. Front matter

Map the standardized author metadata into the template YAML using the
[front-matter schema](#front-matter-schema) below. Then validate:

```powershell
& "C:\Program Files\R\R-4.5.3\bin\Rscript.exe" .\scripts\check-frontmatter.R "<lastname>-<word>.qmd"
```

Every **missing or empty required field becomes an author query in the review block.**
Never fabricate metadata (no invented affiliations, ORCIDs, DOIs, funding numbers).

### 4. Cleanup (your judgment)

On the assembled article, working from the mechanical body:

- Normalize heading levels so the section hierarchy matches house style
  ([section ordering](#section-ordering)). Top-level sections are `#`.
- Fix figure/table cross-references and caption placement; ensure every `{#fig-…}` /
  `{#tbl-…}` label is referenced and every reference resolves.
- Fix list nesting that Pandoc flattened or over-indented.
- **Equations:** keep Pandoc's OMML→LaTeX output only where it is clearly sound. For any
  equation you are not confident about (multi-line alignment, matrices, unusual symbols,
  anything that looks mangled), **leave it but flag it** in the review block with its
  location — never silently ship a guessed equation.
- Remove conversion noise (empty styled spans, stray raw HTML, page-break artifacts) but
  do not drop author content.

### 5. Citations

Run the [citation sub-procedure](#citations-convert-and-verify-never-fabricate). This is
the most important correctness step.

### 6. Review block

Put a TODO block at the very top of the assembled `.qmd`, immediately after the YAML
front matter, listing everything ambiguous, missing, or flagged. See
[Review block](#review-block-format).

## Front-matter schema

Derived from `template.qmd` and `_extensions/cik/partials/before-body.tex` /
`title.tex`. **Required** fields must be present and non-empty or they become author
queries.

```yaml
---
title: <string>                         # REQUIRED
subtitle: <string>                      # optional
author:                                 # REQUIRED, >= 1
  - name: <Given Family>                # REQUIRED per author
    orcid: 0000-0000-0000-0000          # recommended; query if missing
    affiliations:                       # REQUIRED for >= 1 author
      - id: <slug>                      # first occurrence defines the affiliation
        name: <institution>
      - ref: <slug>                     # later authors reference an existing id
    email: name@inst.edu                # REQUIRED on the corresponding author (marks them with *)
doi: "10.51224/XXXXXXXXX"               # REQUIRED; CiK DOI. Placeholder allowed only if not yet assigned — flag it.
journal-editor: "<name>"                # REQUIRED
article_type: Research                  # REQUIRED (e.g. Research, Review, Commentary, RISE)
notetf: false                           # optional; true to show an editor's note
printnote: "<editor note>"              # used only when notetf: true
sci-subject: [<subject>, ...]           # REQUIRED (>=1)
keywords: [<kw>, ...]                   # REQUIRED (>=1)
abstract: "<abstract text>"             # REQUIRED
format:                                 # REQUIRED — must include both CiK formats
  cik-html: default
  cik-pdf:
    fig-format: pdf
bibliography: references.bib            # REQUIRED — point at the verified bib this skill emits
csl: apa7.csl                           # optional override; the extension already defaults to apa7.csl
editor: source                          # optional (RStudio source mode)
date: "`r Sys.Date()`"                  # optional
---
```

Do not invent values. A placeholder DOI (`10.51224/XXXX…`) is acceptable only when the
journal has not yet assigned one — note it in the review block.

## House style

### Section ordering

CiK articles follow this top-level (`#`) order. Map author headings onto it; flag any the
author omitted.

1. Introduction
2. Methods
3. Results
4. Discussion (may contain a `## Conclusion` subsection)
5. **Additional Information** — contains these `##` subsections:
   - Data Accessibility — *required*
   - Author Contributions — *required* (the CRediT-style bullet list)
   - Conflict of Interest — *required*
   - Funding — *required*
   - Acknowledgments — optional
   - Preprint — optional (SportRxiv DOI)
6. References (`# References`; bibliography is auto-generated by citeproc)

`\newpage` between major sections is acceptable and present in the template.

### Citation style

APA 7th edition via `apa7.csl` (already the extension default). Citations use citeproc
(`cite-method: citeproc`). In-text citations are `[@citekey]` / `@citekey`.

## Citations: convert and verify, never fabricate

**The bibliography must never contain fields invented by you. Every DOI-bearing entry is
built from the DOI lookup, not from the parse.**

1. **Parse (your judgment).** Read the author's formatted reference list and parse each
   reference into structured fields. Assign each a stable citekey (e.g. `surname2020`,
   disambiguate with `a`/`b`). Write them to `references-asgiven.json` (schema below).
   **Use these same citekeys for the in-text `[@…]` citations in the body** — keep them
   consistent so the bibliography resolves.

   ```json
   [
     {
       "key": "smith2020",
       "authors": ["Smith, J. A.", "Doe, R."],
       "year": 2020,
       "title": "Effects of altitude on cycling performance",
       "doi": "10.1234/abc.2020.001",
       "raw": "Smith, J. A., & Doe, R. (2020). Effects of altitude... Journal, 1(2), 10-20."
     }
   ]
   ```
   Set `"doi": null` when the author gave no DOI. Keep `raw` verbatim — it is the
   "as-given" record the verifier compares against and prints in the report.

2. **Verify (deterministic).** Run the verifier:

   ```powershell
   & "C:\Program Files\R\R-4.5.3\bin\Rscript.exe" .\scripts\verify-citations.R `
       --input references-asgiven.json `
       --bib references.bib `
       --report references-review.md `
       --tolerance 0.85
   ```

   For each reference the script:
   - **DOI present:** fetches the canonical record via `rcrossref::cr_cn()` through
     doi.org (resolves both Crossref and DataCite) — `citeproc-json` for structured
     comparison and `bibtex` for the entry. The `.bib` entry is built from the **fetched**
     record (citekey rewritten to your assigned key), never from the parse.
   - **Match check:** compares fetched vs as-given on first-author surname, year, and
     normalized title (lowercase, strip punctuation, normalize accents and `&`/`and`, then
     **token-overlap**, not exact equality). Divergence beyond the tolerance
     (**default 0.85**, moderate) is flagged — this catches a DOI that points to the wrong
     paper.
   - **No DOI:** never invents one. Builds a clearly-marked **unverified** entry from the
     as-given fields and flags it; optionally runs `rcrossref::cr_works()` to *suggest* a
     candidate DOI, labelled unverified for the typesetter to confirm.
   - **Not found / lookup error:** flagged under "not found".

3. **Outputs:** `references.bib` (verified entries + clearly-marked unverified ones) and
   `references-review.md` grouped as **no DOI**, **DOI mismatch**, and **not found**, each
   item showing as-given beside what was fetched.

The tolerance is adjustable via `--tolerance`; 0.85 is the house default chosen for this
skill.

## Pinned Pandoc flags

The wrapper (`scripts/convert-body.{ps1,sh}`) pins:

```
--from=docx
--to=markdown+tex_math_dollars-simple_tables-multiline_tables-grid_tables+pipe_tables
--wrap=none
--markdown-headings=atx
--extract-media=media
--output=_body.generated.qmd
```

Rationale: `--wrap=none` keeps each paragraph on one line for clean git diffs across
re-runs; `pipe_tables` (and disabling the others) gives readable, diff-stable tables;
`atx` headings produce `#`-style headings; `tex_math_dollars` preserves equation
delimiters; `--extract-media` pulls embedded figures out of the `.docx`.

## Known Pandoc gotchas

- **Equations:** OMML → LaTeX is usually right for inline and simple display math, but
  multi-line/aligned equations, matrices, and uncommon symbols can mangle. Inspect and
  flag (procedure step 4).
- **Tables:** complex Word tables (merged cells, nested headers) fall back to raw HTML or
  lose structure. The template uses `flextable` for rich tables — flag complex tables for
  the typesetter to rebuild rather than shipping broken markdown.
- **Styled spans:** custom Word styles can surface as empty `[]{custom-style="…"}` spans
  (we omit `+styles`, but residue happens). Strip them.
- **Footnotes/endnotes** convert to `[^n]` markdown footnotes — check they survived.
- **Images** extracted to `media/` keep opaque hashed names; rename to `fig_N` and move to
  `figures/`. Some "images" are rasterized equations or logos — discard those.
- **Smart quotes / dashes** usually convert fine; watch for literal Unicode that should be
  LaTeX-safe in PDF.
- **Cross-references:** Word's auto "Figure 1" / "Table 1" text becomes literal text, not
  a live reference. Re-wire to `@fig-1` / `[Figure 1](#fig-1)`.

## Idempotency

Re-running on a revised `.docx` must produce a **reviewable git diff, not a clobber** of
manual edits:

- `_body.generated.qmd` is **mechanical** and regenerated every run — never hand-edit it.
  Commit it so the next run's diff shows exactly what changed in the manuscript.
- The assembled `<lastname>-<word>.qmd` holds the **curated** content and is where manual
  polish lives. When the manuscript is revised, re-run the wrapper, diff the new
  `_body.generated.qmd` against the prior one, and port the real changes into the
  assembled file — do not overwrite it wholesale.
- `references-asgiven.json` is hand-curated (your parse); `references.bib` and
  `references-review.md` are regenerated by the verifier and safe to overwrite.

## Review block format

At the top of the assembled `.qmd`, right after the front matter:

```markdown
<!--
TYPESETTER REVIEW — generated draft, NOT final. Resolve before publishing.

MISSING FRONT MATTER (author queries):
- [ ] ORCID missing for J. Doe
- [ ] DOI is a placeholder (not yet assigned)

FIGURES:
- [ ] fig_2 supplied as PNG only — request vector/300dpi for print
- [ ] Author references "Figure 4" in text but no Figure 4 was supplied

EQUATIONS (verify — OMML conversion uncertain):
- [ ] Eq. in Methods §2.1 — multi-line alignment may be wrong

TABLES:
- [ ] Table 2 has merged cells — rebuild with flextable

CITATIONS: see references-review.md
- 2 no-DOI, 1 DOI mismatch, 0 not found

OTHER:
- [ ] Heading "Background" remapped to Introduction — confirm
-->
```

## Handoff boundary

This skill produces **a draft and a review report**. It does not sign off on equations,
finalize formatting, or resolve flagged citations. Those decisions stay with the human
typesetter.

## When done

Summarize what was created and where, confirm the example renders (or note the missing
tool if it cannot be rendered here), and list everything still needed from the user.

## Reference material

- `reference/example-article.qmd` — a finished CiK article in the exact target format
  (the canonical `template.qmd`). Read it to see the front matter, figure syntax, table
  approach, and section ordering you are converting toward.
- `reference/template-notes.md` — where the CiK extension lives, the field schema, and
  rendering commands.
