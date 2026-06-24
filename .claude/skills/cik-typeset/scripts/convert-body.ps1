<#
.SYNOPSIS
  CiK typesetting — mechanical Word -> Quarto body conversion (pinned Pandoc flags).

.DESCRIPTION
  Converts an author .docx manuscript into a MECHANICAL Quarto body file
  (_body.generated.qmd) and extracts embedded media into <OutDir>/media.

  This output is regenerated on every run and must NEVER be hand-edited. The
  curated, hand-polished article lives in a separate <lastname>-<word>.qmd that
  is assembled from this body. See SKILL.md ("Idempotency").

  Pinned flags (do not change casually — they keep diffs stable across re-runs):
    --from=docx
    --to=markdown+tex_math_dollars-simple_tables-multiline_tables-grid_tables+pipe_tables
    --wrap=none
    --markdown-headings=atx
    --extract-media=media

.PARAMETER Input
  Path to the author .docx manuscript.

.PARAMETER OutDir
  Output directory (default: the manuscript's folder). _body.generated.qmd and
  media/ are written here.

.EXAMPLE
  .\convert-body.ps1 -Input "manuscript.docx" -OutDir "."
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][Alias('Input')][string]$InputPath,
    [string]$OutDir
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $InputPath)) {
    throw "Input manuscript not found: $InputPath"
}
$InputItem = Get-Item -LiteralPath $InputPath
if ($InputItem.Extension -ne '.docx') {
    throw "Expected a .docx file. Got '$($InputItem.Extension)'. Re-save legacy .doc as .docx first."
}

if (-not $OutDir) { $OutDir = $InputItem.DirectoryName }
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }
$OutDir = (Resolve-Path -LiteralPath $OutDir).Path

$outBody = Join-Path $OutDir '_body.generated.qmd'

# Pinned conversion arguments. extract-media is relative to OutDir, so run with
# OutDir as the working directory.
$toFmt = 'markdown+tex_math_dollars-simple_tables-multiline_tables-grid_tables+pipe_tables'
$pandocArgs = @(
    $InputItem.FullName,
    '--from=docx',
    "--to=$toFmt",
    '--wrap=none',
    '--markdown-headings=atx',
    '--extract-media=media',
    '--output', $outBody
)

# Locate a Pandoc: prefer standalone pandoc, fall back to Quarto's bundled pandoc.
$pandocCmd = Get-Command pandoc -ErrorAction SilentlyContinue
$quartoCmd = Get-Command quarto -ErrorAction SilentlyContinue

Push-Location $OutDir
try {
    if ($pandocCmd) {
        Write-Host "Using pandoc: $($pandocCmd.Source)"
        & $pandocCmd.Source @pandocArgs
    }
    elseif ($quartoCmd) {
        Write-Host "Standalone pandoc not found; using bundled 'quarto pandoc': $($quartoCmd.Source)"
        & $quartoCmd.Source pandoc @pandocArgs
    }
    else {
        throw "Neither 'pandoc' nor 'quarto' found on PATH. Install Quarto 1.6+ (bundles Pandoc 3.4+)."
    }
    if ($LASTEXITCODE -ne 0) { throw "Pandoc exited with code $LASTEXITCODE." }
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "Wrote mechanical body : $outBody"
$mediaDir = Join-Path $OutDir 'media'
if (Test-Path -LiteralPath $mediaDir) {
    $n = (Get-ChildItem -LiteralPath $mediaDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Host "Extracted media       : $mediaDir ($n file(s))"
    Write-Host "  -> Move real figures into figures/ as fig_1, fig_2, ...; discard logos/equation rasters."
}
else {
    Write-Host "No embedded media found (figures likely supplied as separate files)."
}
Write-Host ""
Write-Host "NEXT: do not edit _body.generated.qmd. Assemble <lastname>-<word>.qmd from it (see SKILL.md)."
