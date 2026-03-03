param(
  [string]$Master = "H:\Backup_Files_To_NAS\PhotographyHub\pages\MASTER.steps.txt",
  [string]$OutDir = "H:\Backup_Files_To_NAS\PhotographyHub\pages"
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $Master)) { throw "MASTER not found: $Master" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Slugify([string]$s){
  if(-not $s){ return "" }
  $s=$s.ToLowerInvariant()
  $s=($s -replace '[^a-z0-9-_]+','-').Trim('-')
  if(-not $s){ $s='page' }
  return $s
}

# Read lines
$raw   = Get-Content -LiteralPath $Master -Raw
$lines = $raw -split "`r?`n"

# Split into sections starting at @@ title:
$sections = @()
$cur = @{ header = New-Object System.Collections.Generic.List[string]; body = New-Object System.Collections.Generic.List[string] }
$inHeader = $false
$seenAny  = $false

for ($i=0; $i -lt $lines.Count; $i++) {
  $L = $lines[$i]
  if ($L -match '^\s*@@\s*title\s*:') {
    if ($seenAny) {
      $sections += ,$cur
      $cur = @{ header = New-Object System.Collections.Generic.List[string]; body = New-Object System.Collections.Generic.List[string] }
    }
    $cur.header.Add($L)
    $inHeader = $true
    $seenAny  = $true
  }
  elseif ($inHeader -and $L -match '^\s*@@\s*\w+\s*:') {
    $cur.header.Add($L)
  }
  elseif ($inHeader -and $L.Trim() -eq '') {
    # blank line ends header; body starts after this
    $inHeader = $false
  }
  else {
    $cur.body.Add($L)
  }
}
if ($seenAny) { $sections += ,$cur }

if (-not $sections -or $sections.Count -eq 0) {
  throw "No sections found. Each card must start with '@@ title: ...' followed by optional @@ lines, then a blank line, then steps."
}

# Write out per-section files
$written = 0
foreach ($sec in $sections) {

  # parse header into a hashtable
  $meta = @{}
  foreach ($h in $sec.header) {
    if ($h -match '^\s*@@\s*(\w+)\s*:\s*(.*)$') {
      $meta[$matches[1].ToLower()] = $matches[2].Trim()
    }
  }

  # derive slug
  $slug = $null
  if ($meta.ContainsKey('slug') -and -not [string]::IsNullOrWhiteSpace($meta['slug'])) {
    $slug = $meta['slug']
  } elseif ($meta.ContainsKey('title') -and -not [string]::IsNullOrWhiteSpace($meta['title'])) {
    $slug = Slugify $meta['title']
  } else {
    $slug = "page$written"
  }

  $outPath = Join-Path $OutDir ($slug + "-steps.txt")

  # Recompose: header, one blank line, then body
  $content = @()
  $content += $sec.header
  $content += ''
  $content += $sec.body

  Set-Content -Path $outPath -Value $content -Encoding UTF8
  Write-Host "Wrote steps: $(Split-Path $outPath -Leaf)"
  $written++
}

Write-Host "✅ Split complete. Wrote $written file(s) to $OutDir"
