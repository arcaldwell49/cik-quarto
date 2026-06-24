#!/usr/bin/env Rscript

# check-frontmatter.R — validate a CiK draft .qmd against the required-fields
# schema and the house-style section ordering. Reports missing/empty fields as
# author queries. It NEVER fills anything in.
#
# Usage:
#   Rscript check-frontmatter.R <article.qmd>
#
# Exit code 0 if all required fields present, 1 if any are missing (so it can
# gate a pipeline). The human-readable report is printed to stdout.

suppressWarnings(suppressMessages({
  ok <- requireNamespace("yaml", quietly = TRUE)
}))
if (!ok) stop("Missing R package 'yaml'. Install with: install.packages('yaml')", call. = FALSE)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) stop("Usage: check-frontmatter.R <article.qmd>", call. = FALSE)
path <- args[[1]]
if (!file.exists(path)) stop(sprintf("File not found: %s", path), call. = FALSE)

lines <- readLines(path, warn = FALSE, encoding = "UTF-8")

# ---- extract YAML front matter (first --- ... --- block) --------------------
fences <- which(grepl("^---\\s*$", lines))
if (length(fences) < 2) stop("No YAML front matter delimited by '---' found.", call. = FALSE)
yaml_text <- paste(lines[(fences[1] + 1):(fences[2] - 1)], collapse = "\n")
# Quarto allows `r ...` inline expressions in YAML values; quote bare backticks so
# the YAML parser doesn't choke. (Only affects parsing here, not the file.)
fm <- tryCatch(yaml::yaml.load(yaml_text),
               error = function(e) stop(sprintf("Front matter is not valid YAML: %s", conditionMessage(e)), call. = FALSE))

body <- paste(lines[(fences[2] + 1):length(lines)], collapse = "\n")

queries <- character(0)
note <- function(...) queries <<- c(queries, sprintf(...))

nonempty <- function(x) !is.null(x) && length(x) > 0 && any(nzchar(as.character(unlist(x))))

# ---- required scalar fields -------------------------------------------------
req_scalars <- c("title", "doi", "journal-editor", "article_type", "abstract")
for (f in req_scalars) {
  if (!nonempty(fm[[f]])) note("Missing/empty required field: `%s`", f)
}

# ---- required list fields ---------------------------------------------------
for (f in c("sci-subject", "keywords")) {
  if (!nonempty(fm[[f]])) note("Missing/empty required list field: `%s`", f)
}

# ---- DOI sanity -------------------------------------------------------------
if (nonempty(fm$doi)) {
  d <- as.character(fm$doi)
  if (grepl("X{3,}", d, ignore.case = TRUE)) {
    note("`doi` looks like a placeholder (%s) — confirm the assigned DOI.", d)
  } else if (!grepl("^10\\.", d)) {
    note("`doi` does not start with '10.' (%s) — check it.", d)
  }
}

# ---- authors / affiliations -------------------------------------------------
authors <- fm$author
if (is.null(authors)) {
  note("Missing required field: `author`")
} else {
  if (!is.null(authors$name) || !is.null(authors$affiliations)) authors <- list(authors)  # single-author shorthand
  has_affil <- FALSE
  has_corr  <- FALSE
  for (i in seq_along(authors)) {
    a <- authors[[i]]
    nm <- if (!is.null(a$name)) a$name else sprintf("author #%d", i)
    if (!nonempty(a$name)) note("Author #%d has no `name`.", i)
    if (nonempty(a$affiliations)) has_affil <- TRUE
    if (nonempty(a$email)) has_corr <- TRUE
    if (!nonempty(a$orcid)) note("ORCID missing for %s (recommended).", nm)
  }
  if (!has_affil) note("No author has an `affiliations` block — at least one is required.")
  if (!has_corr)  note("No author has an `email` — the corresponding author needs one (rendered with *).")
}

# ---- format block -----------------------------------------------------------
fmt <- fm$format
fmt_names <- if (is.null(fmt)) character(0) else names(fmt)
if (!("cik-html" %in% fmt_names)) note("`format` is missing `cik-html`.")
if (!("cik-pdf"  %in% fmt_names)) note("`format` is missing `cik-pdf`.")

# ---- bibliography -----------------------------------------------------------
if (!nonempty(fm$bibliography)) {
  note("Missing `bibliography` — point it at the verified references.bib.")
}

# ---- required body sections (house style) -----------------------------------
required_sections <- c("Introduction", "Methods", "Results", "Discussion",
                       "Data Accessibility", "Author Contributions",
                       "Conflict of Interest", "Funding", "References")
for (s in required_sections) {
  # Section names are plain words/spaces — no regex escaping needed.
  pat <- sprintf("(?m)^#{1,3}[ \\t]+%s\\b", s)
  if (!any(grepl(pat, body, perl = TRUE, ignore.case = TRUE))) {
    note("Required section heading not found in body: `%s`", s)
  }
}

# ---- report -----------------------------------------------------------------
cat("CiK front-matter & structure check\n")
cat(sprintf("File: %s\n\n", path))
if (length(queries) == 0) {
  cat("PASS — all required front-matter fields and sections present.\n")
  quit(status = 0)
} else {
  cat(sprintf("%d item(s) need attention (author queries — do NOT fabricate):\n\n", length(queries)))
  for (q in queries) cat(sprintf("  - [ ] %s\n", q))
  cat("\nAdd these to the review block at the top of the .qmd.\n")
  quit(status = 1)
}
