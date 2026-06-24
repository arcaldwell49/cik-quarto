# CLAUDE.md

Orientation for working in this repo. The conversion how-to is **not** here — it lives in
the `cik-typeset` skill (`.claude/skills/cik-typeset/`). This file says where things are
and what not to do.

## What this repo is

The Quarto **typesetting template** for *Communications in Kinesiology* (CiK), the STORK
journal. It produces final PDF and HTML versions of accepted articles.

**Lifecycle:** the repo is a template, copied per article — one article per copy, with its
own branch. You start a new article from it via `quarto use template arcaldwell49/cik-quarto`
(or by branching this repo), then drop the author's submission in and convert it.

## Layout

- `_extensions/cik/` — the CiK Quarto format (`cik-pdf`, `cik-html`), the LaTeX class
  (`cik.cls`), the citation style (`apa7.csl`), Lua filters, and template partials. This is
  the engine; don't edit it for a single article.
- `template.qmd` — the example/starter article showing the target front matter, figure
  syntax, tables (flextable), and section ordering.
- Root support files: `apa7.csl`, `cik.cls`, `reflist.json`, `fig_1.*`, `tables.xlsx`.
- `style-guide/` — house style notes (excluded from template distribution).
- `.claude/skills/cik-typeset/` — the skill that converts an author submission to a draft.

**Per article**, the converted draft lands as `<lastname>-<word>.qmd` in the article
folder, with `references.bib` and the `references-review.md` report alongside it.

## Render

Requires **Quarto 1.6+** (bundles Pandoc 3.4+).

```bash
quarto render <article>.qmd --to cik-pdf    # PDF
quarto render <article>.qmd --to cik-html   # HTML
quarto render <article>.qmd                 # both, per the format: block
```

## Workflow

1. **Convert** the author submission to a draft — use the `cik-typeset` skill on the
   article folder.
2. **Human proof** the draft and resolve everything the skill flagged.
3. A **typesetter finishes** the article (formatting, equations, citations) and renders the
   final PDF/HTML.

The skill produces a *draft and a review report*, not a finished article.

## Always-on guardrails

These apply to every session in this repo, not only when the skill runs:

- **Do not finalize formatting.** Output is a draft for a human typesetter.
- **Do not resolve flagged citations or equations.** Leave them flagged for the typesetter.
- **Never write bibliographic fields from memory.** Every entry comes from a DOI lookup (or
  is kept as-given and clearly marked unverified). No invented authors, years, titles,
  DOIs, affiliations, ORCIDs, or funding details.

## Convert an author submission

To convert an author submission, use the `cik-typeset` skill on the article folder.
