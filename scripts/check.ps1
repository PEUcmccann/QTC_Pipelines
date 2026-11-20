param([string]$Root = (Split-Path $PSScriptRoot -Parent))
# Mechanical checks for this repo. Runs in the pre-commit hook and in CI. Needs PowerShell 7+.
# Judgement rules live in CODING_STANDARDS.md, not here.
$ErrorActionPreference = 'Stop'
$MaxWords = 20
$fail = [System.Collections.Generic.List[string]]::new()
Push-Location $Root
try {
  $files = git ls-files --cached --others --exclude-standard | Where-Object { Test-Path $_ -PathType Leaf }

  # 1. No BOM in JSON, YAML or Markdown files.
  foreach ($f in $files | Where-Object { $_ -match '\.(json|ya?ml|md)$' }) {
    $b = [IO.File]::ReadAllBytes((Join-Path $Root $f))
    if ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) { $fail.Add("BOM: $f") }
  }

  # 2. Export folders: name is <PROJECT>_<timestamp>_ALL, and no secret values.
  $exports = $files | Where-Object { $_ -match '^[^/]+/qtcp_project\.yaml$' } | ForEach-Object { $_.Split('/')[0] }
  foreach ($d in $exports) {
    if ($d -notmatch '^[A-Za-z0-9_]+_\d{4}-\d{2}-\d{2}T\d{2}_\d{2}_\d{2}\.\d{3}Z_ALL$') { $fail.Add("Export folder name: $d") }
  }
  $secret = '(?i)["'']?(password|passwd|secret|token|api_?key)["'']?\s*[:=]\s*["'']?[^\s"'',}{]+'
  foreach ($f in $files | Where-Object { $exports -contains $_.Split('/')[0] }) {
    $n = 0
    foreach ($line in [IO.File]::ReadLines((Join-Path $Root $f))) {
      $n++
      if ($line -match $secret) { $fail.Add("Possible secret: ${f}:$n") }
    }
  }

  # 3. Prose: each sentence has 20 words or fewer (ASD-STE100, see AGENTS.md).
  $prose = $files | Where-Object { $_ -match '^(AGENTS|GLOSSARY|CODING_STANDARDS)\.md$|^docs/[^/]+\.md$' }
  foreach ($f in $prose) {
    $inFence = $false; $n = 0
    foreach ($line in [IO.File]::ReadLines((Join-Path $Root $f))) {
      $n++
      if ($line -match '^\s*```') { $inFence = -not $inFence; continue }
      if ($inFence -or $line -match '^\s*#' -or $line -match '^\s*\|?\s*:?-{3,}') { continue }
      $t = $line -replace '`[^`]*`', 'X' -replace '\[([^\]]*)\]\([^)]*\)', '$1'
      foreach ($cell in $t -split '\|') {
        $c = $cell -replace '^\s*([-*]|\d+\.)\s+', ''
        foreach ($s in $c -split '(?<=[.!?])\s+') {
          $w = @($s -split '\s+' | Where-Object { $_ -match '[\p{L}\p{N}]' }).Count
          if ($w -gt $MaxWords) { $fail.Add("Sentence over $MaxWords words (${w}): ${f}:$n") }
        }
      }
    }
  }
}
finally { Pop-Location }

if ($fail.Count) { $fail; "check: $($fail.Count) problem(s)"; exit 1 }
'check: OK'
