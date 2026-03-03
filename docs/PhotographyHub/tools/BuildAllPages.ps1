# BuildAllPages.ps1 — scans pages\*-steps.txt, asks converter for metadata,
# ensures the HTML page exists, then writes index.html (hub).

$Tools = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root  = Split-Path -Parent $Tools
$Pages = Join-Path $Root 'pages'
$Conv  = Join-Path $Tools 'Convert-StepsToHtml.ps1'
$Hub   = Join-Path $Root 'index.html'

if (-not (Test-Path $Conv)) { throw "Converter missing: $Conv" }

function HtmlEscape([string]$s){
  if (-not $s) { return "" }
  $s = $s -replace '&','&amp;'
  $s = $s -replace '<','&lt;'
  $s = $s -replace '>','&gt;'
  $s = $s -replace '"','&quot;'
  $s = $s -replace "'","&#39;"
  return $s
}

# Gather steps files (exclude MASTER)
$steps = Get-ChildItem $Pages -File |
  Where-Object {
    $_.Name -match '(-steps\.txt|\.steps\.txt)$' -and
    $_.Name -notmatch '^(?i)(MASTER|template).*\.steps\.txt$'
  } |
  Sort-Object Name

$cards = @()

foreach ($s in $steps) {
  # Request metadata from the converter
  $metaJson = & $Conv -InputTxt $s.FullName -ReturnJson 2>$null
  if (-not $metaJson) { Write-Warning ("Skipping (no metadata): {0}" -f $s.Name); continue }
  $m = $metaJson | ConvertFrom-Json

  # Ensure the HTML page exists
  $htmlPath = Join-Path $Root $m.Href
  if (-not (Test-Path $htmlPath)) {
    & $Conv -InputTxt $s.FullName | Out-Null
  }

  $cards += [pscustomobject]@{
    Title   = $m.Title
    Summary = $m.Summary
    Href    = $m.Href
    Order   = $(if ($m.Order -ne $null) { [int]$m.Order } else { 9999 })
  }
}

# Sort by Order, then Title
$cards = $cards | Sort-Object Order, Title

# Build index.html
$sb = New-Object Text.StringBuilder
[void]$sb.AppendLine('<!doctype html>')
[void]$sb.AppendLine('<html lang="en"><head>')
[void]$sb.AppendLine('  <meta charset="utf-8" />')
[void]$sb.AppendLine('  <title>Photography Workflow Hub</title>')
[void]$sb.AppendLine('  <meta name="viewport" content="width=device-width, initial-scale=1" />')
[void]$sb.AppendLine('  <style>')
[void]$sb.AppendLine('    body{margin:24px;font:16px/1.5 system-ui,-apple-system,"Segoe UI",Arial,sans-serif;background:#eef1f4}')
[void]$sb.AppendLine('    h1{margin:0 0 16px;color:#051a41}')
[void]$sb.AppendLine('    .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:16px}')
[void]$sb.AppendLine('    .card{background:#fff;border-radius:12px;padding:16px;border:1px solid #dde3ea}')
[void]$sb.AppendLine('    .card h3{margin:0 0 8px;font-size:18px}')
[void]$sb.AppendLine('    .card p{margin:0;color:#333}')
[void]$sb.AppendLine('    a{color:#0e49c2;text-decoration:none}')
[void]$sb.AppendLine('    a:hover{text-decoration:underline}')
[void]$sb.AppendLine('  </style>')
[void]$sb.AppendLine('</head><body>')
[void]$sb.AppendLine('  <h1>Photography Workflow Hub</h1>')
[void]$sb.AppendLine('  <div class="grid">')

foreach ($c in $cards) {
  $t = HtmlEscape $c.Title
  $u = HtmlEscape $c.Href
  $d = HtmlEscape $c.Summary
  if (-not $d) { $d = '' }
  [void]$sb.AppendLine("    <a class=""card"" href=""$u""><h3>$t</h3><p>$d</p></a>")
}

[void]$sb.AppendLine('  </div>')
[void]$sb.AppendLine('</body></html>')

Set-Content -Path $Hub -Value $sb.ToString() -Encoding UTF8
Write-Host ("Rebuilt hub: {0}" -f $Hub)
