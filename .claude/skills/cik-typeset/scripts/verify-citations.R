#!/usr/bin/env Rscript

# verify-citations.R — CiK typesetting citation verifier.
#
# Builds a verified bibliography from DOI lookups (NEVER from invented fields) and
# a review report. Reads a structured "as-given" parse of the author reference list
# (produced by the model from the messy formatted list) and, for each reference:
#
#   * DOI present  -> fetch canonical record via rcrossref::cr_cn() through doi.org
#                     (resolves Crossref AND DataCite). citeproc-json for the match
#                     check, bibtex for the entry. The .bib entry is built from the
#                     FETCHED record; the citekey is rewritten to the assigned key.
#                     The fetched title/first-author surname/year are compared with
#                     the as-given values (normalized token-overlap on title); a
#                     divergence beyond --tolerance is flagged (catches a DOI that
#                     points to the wrong paper).
#   * No DOI       -> never invents one. Emits a CLEARLY-MARKED unverified entry from
#                     the as-given fields and flags it. Optionally suggests a candidate
#                     DOI via cr_works() title search, labelled unverified.
#   * Not found    -> flagged.
#
# Outputs: a .bib and a references-review.md grouped as no-DOI / DOI-mismatch / not-found.
#
# Usage:
#   Rscript verify-citations.R --input references-asgiven.json \
#       --bib references.bib --report references-review.md --tolerance 0.85
#
# Input JSON schema (array): see SKILL.md.
#   { "key": "smith2020", "authors": ["Smith, J. A."], "year": 2020,
#     "title": "...", "doi": "10.xxx/..." | null, "raw": "<verbatim>" }

suppressWarnings(suppressMessages({
  ok <- requireNamespace("jsonlite", quietly = TRUE) &&
        requireNamespace("rcrossref", quietly = TRUE)
}))
if (!ok) {
  stop("Missing R packages. Install with: install.packages(c('jsonlite','rcrossref'))",
       call. = FALSE)
}

# ---- arg parsing ------------------------------------------------------------
parse_args <- function(args) {
  out <- list(input = NULL, bib = "references.bib",
              report = "references-review.md", tolerance = 0.85,
              suggest = TRUE)
  i <- 1
  while (i <= length(args)) {
    a <- args[[i]]
    switch(a,
      "--input"     = { out$input  <- args[[i + 1]]; i <- i + 2 },
      "--bib"       = { out$bib    <- args[[i + 1]]; i <- i + 2 },
      "--report"    = { out$report <- args[[i + 1]]; i <- i + 2 },
      "--tolerance" = { out$tolerance <- as.numeric(args[[i + 1]]); i <- i + 2 },
      "--no-suggest"= { out$suggest <- FALSE; i <- i + 1 },
      { stop(sprintf("Unknown argument: %s", a), call. = FALSE) }
    )
  }
  if (is.null(out$input)) stop("--input <references-asgiven.json> is required", call. = FALSE)
  out
}
opt <- parse_args(commandArgs(trailingOnly = TRUE))

# ---- normalization & matching ----------------------------------------------
normalize_title <- function(x) {
  if (is.null(x) || is.na(x) || !nzchar(x)) return("")
  x <- tolower(x)
  x <- iconv(x, to = "ASCII//TRANSLIT", sub = "")   # strip accents
  x <- gsub("&", " and ", x, fixed = TRUE)
  x <- gsub("[^a-z0-9 ]+", " ", x)                  # drop punctuation
  x <- gsub("\\s+", " ", x)
  trimws(x)
}

tokens <- function(x) {
  t <- strsplit(normalize_title(x), " ", fixed = TRUE)[[1]]
  t[nzchar(t)]
}

# Overlap coefficient: |A ∩ B| / min(|A|,|B|). Robust to one title being longer
# (e.g. subtitle present in one record but not the other).
title_overlap <- function(a, b) {
  ta <- unique(tokens(a)); tb <- unique(tokens(b))
  if (length(ta) == 0 || length(tb) == 0) return(0)
  length(intersect(ta, tb)) / min(length(ta), length(tb))
}

surname_of <- function(author_string) {
  # "Smith, J. A." -> "smith"; "John Smith" -> "smith"
  if (is.null(author_string) || !nzchar(author_string)) return("")
  s <- author_string
  if (grepl(",", s, fixed = TRUE)) {
    fam <- trimws(strsplit(s, ",", fixed = TRUE)[[1]][1])
  } else {
    parts <- strsplit(trimws(s), "\\s+")[[1]]
    fam <- parts[length(parts)]
  }
  normalize_title(fam)
}

# ---- crossref helpers (network, may fail) -----------------------------------
fetch_citeproc <- function(doi) {
  tryCatch(
    rcrossref::cr_cn(dois = doi, format = "citeproc-json"),
    error = function(e) NULL
  )
}
fetch_bibtex <- function(doi) {
  tryCatch(
    rcrossref::cr_cn(dois = doi, format = "bibtex"),
    error = function(e) NULL
  )
}
suggest_doi <- function(title, author) {
  if (!opt$suggest || is.null(title) || !nzchar(title)) return(NULL)
  q <- title
  res <- tryCatch(
    rcrossref::cr_works(query = q, limit = 3),
    error = function(e) NULL
  )
  if (is.null(res) || is.null(res$data) || nrow(res$data) == 0) return(NULL)
  d <- res$data
  cand_title <- if ("title" %in% names(d)) d$title[[1]] else NA_character_
  cand_doi   <- if ("doi"   %in% names(d)) d$doi[[1]]   else NA_character_
  if (is.na(cand_doi)) return(NULL)
  list(doi = cand_doi, title = cand_title,
       overlap = title_overlap(title, cand_title))
}

# Rewrite the @type{OLDKEY, ...} in a bibtex string to the assigned citekey.
rekey_bibtex <- function(bib, key) {
  sub("(@[A-Za-z]+\\{)[^,]*,", paste0("\\1", key, ","), bib)
}

# extract first-author family / year / title from a citeproc-json record.
# cr_cn() parses with jsonlite (simplifyVector=TRUE), so `author` may be a
# data.frame and `issued$date-parts` a matrix — handle both those and the
# list-of-lists shape.
record_fields <- function(cj) {
  fam <- ""; yr <- NA_integer_; ttl <- ""
  au <- cj$author
  if (!is.null(au)) {
    if (is.data.frame(au)) {
      if ("family" %in% names(au) && nrow(au) >= 1) fam <- normalize_title(au$family[1])
    } else if (is.list(au) && length(au) >= 1) {
      a1 <- au[[1]]
      if (is.list(a1) && !is.null(a1$family)) fam <- normalize_title(a1$family)
    }
  }
  iss <- cj$issued
  if (!is.null(iss) && !is.null(iss[["date-parts"]])) {
    dp <- iss[["date-parts"]]
    yv <- tryCatch({
      if (is.matrix(dp)) as.integer(dp[1, 1])
      else if (is.list(dp)) as.integer(dp[[1]][[1]])
      else as.integer(dp[1])
    }, error = function(e) NA_integer_)
    if (length(yv)) yr <- yv[[1]]
  }
  if (!is.null(cj$title)) ttl <- if (is.list(cj$title)) cj$title[[1]] else cj$title[1]
  list(family = fam, year = yr, title = ttl)
}

# ---- main loop --------------------------------------------------------------
refs <- jsonlite::fromJSON(opt$input, simplifyVector = FALSE)
if (length(refs) == 0) stop("No references in input.", call. = FALSE)

bib_entries  <- character(0)
grp_nodoi    <- list()
grp_mismatch <- list()
grp_notfound <- list()
n_ok <- 0L

for (r in refs) {
  key   <- if (!is.null(r$key)) r$key else "MISSING_KEY"
  doi   <- if (!is.null(r$doi)) r$doi else NA_character_
  asg_t <- if (!is.null(r$title)) r$title else ""
  asg_y <- if (!is.null(r$year)) suppressWarnings(as.integer(r$year)) else NA_integer_
  asg_a <- if (!is.null(r$authors) && length(r$authors) >= 1) r$authors[[1]] else ""
  raw   <- if (!is.null(r$raw)) r$raw else ""

  if (is.null(doi) || is.na(doi) || !nzchar(doi)) {
    # ---- NO DOI: emit clearly-marked unverified entry from as-given ---------
    cand <- suggest_doi(asg_t, asg_a)
    note <- "% UNVERIFIED — no DOI supplied; fields are AS-GIVEN by the author, not fetched."
    sug_line <- ""
    if (!is.null(cand)) {
      sug_line <- sprintf("%% SUGGESTED DOI (UNVERIFIED, confirm before use): %s  [title overlap %.2f]\n",
                          cand$doi, cand$overlap)
    }
    yr <- if (!is.na(asg_y)) asg_y else ""
    entry <- sprintf("%s\n%s@misc{%s,\n  title = {%s},\n  author = {%s},\n  year = {%s},\n  note = {AS-GIVEN, no DOI — verify manually}\n}\n",
                     note, sug_line, key, asg_t, paste(unlist(r$authors), collapse = " and "), yr)
    bib_entries <- c(bib_entries, entry)
    grp_nodoi[[length(grp_nodoi) + 1]] <- list(key = key, raw = raw, suggest = cand)
    next
  }

  # ---- DOI present: fetch canonical record --------------------------------
  cj <- fetch_citeproc(doi)
  bt <- fetch_bibtex(doi)
  if (is.null(cj) || is.null(bt)) {
    grp_notfound[[length(grp_notfound) + 1]] <-
      list(key = key, doi = doi, raw = raw,
           reason = "DOI did not resolve via doi.org content negotiation")
    next
  }

  fields <- record_fields(cj)
  ov   <- title_overlap(asg_t, fields$title)
  fam_match  <- (surname_of(asg_a) == fields$family) || surname_of(asg_a) == "" || fields$family == ""
  year_match <- is.na(asg_y) || is.na(fields$year) || (asg_y == fields$year)
  title_match <- ov >= opt$tolerance

  bib_entries <- c(bib_entries, paste0(rekey_bibtex(bt, key), "\n"))

  if (title_match && fam_match && year_match) {
    n_ok <- n_ok + 1L
  } else {
    grp_mismatch[[length(grp_mismatch) + 1]] <- list(
      key = key, doi = doi, raw = raw,
      asg = list(author = asg_a, year = asg_y, title = asg_t),
      got = list(author = fields$family, year = fields$year, title = fields$title),
      overlap = ov, title_ok = title_match, fam_ok = fam_match, year_ok = year_match
    )
  }
}

# ---- write .bib -------------------------------------------------------------
writeLines(paste(bib_entries, collapse = "\n"), opt$bib, useBytes = TRUE)

# ---- write report -----------------------------------------------------------
md <- c()
add <- function(...) md <<- c(md, sprintf(...))

add("# Citation review — CiK typesetting\n")
add("Generated by `verify-citations.R`. Title-match tolerance: **%.2f** (overlap coefficient).\n", opt$tolerance)
add("- References processed: **%d**", length(refs))
add("- Verified clean (DOI resolved, matched): **%d**", n_ok)
add("- No DOI: **%d**  |  DOI mismatch: **%d**  |  Not found: **%d**\n",
    length(grp_nodoi), length(grp_mismatch), length(grp_notfound))
add("> The `.bib` contains canonical entries built from DOI lookups. No-DOI entries are")
add("> marked `UNVERIFIED` and carry only author-supplied fields. Resolve every item below.\n")

add("## No DOI (%d)\n", length(grp_nodoi))
if (length(grp_nodoi) == 0) add("_None._\n") else for (x in grp_nodoi) {
  add("- **`@%s`**", x$key)
  add("  - as-given: %s", x$raw)
  if (!is.null(x$suggest)) {
    add("  - suggested DOI (UNVERIFIED, confirm): `%s` — %s  _[title overlap %.2f]_",
        x$suggest$doi, x$suggest$title, x$suggest$overlap)
  } else {
    add("  - no candidate DOI found via title search")
  }
  add("")
}

add("## DOI mismatch (%d)\n", length(grp_mismatch))
if (length(grp_mismatch) == 0) add("_None._\n") else for (x in grp_mismatch) {
  flags <- c(if (!x$title_ok) "title", if (!x$fam_ok) "author", if (!x$year_ok) "year")
  add("- **`@%s`** — DOI `%s` — diverges on: **%s** _(title overlap %.2f)_",
      x$key, x$doi, paste(flags, collapse = ", "), x$overlap)
  add("  - as-given: %s (%s) — %s", x$asg$author, ifelse(is.na(x$asg$year), "?", x$asg$year), x$asg$title)
  add("  - fetched : %s (%s) — %s", x$got$author, ifelse(is.na(x$got$year), "?", x$got$year), x$got$title)
  add("  - raw: %s", x$raw)
  add("")
}

add("## Not found (%d)\n", length(grp_notfound))
if (length(grp_notfound) == 0) add("_None._\n") else for (x in grp_notfound) {
  add("- **`@%s`** — DOI `%s` — %s", x$key, x$doi, x$reason)
  add("  - as-given: %s", x$raw)
  add("")
}

writeLines(md, opt$report, useBytes = TRUE)

cat(sprintf("Wrote %s (%d entries) and %s\n", opt$bib, length(bib_entries), opt$report))
cat(sprintf("  clean: %d | no-DOI: %d | mismatch: %d | not-found: %d\n",
            n_ok, length(grp_nodoi), length(grp_mismatch), length(grp_notfound)))
