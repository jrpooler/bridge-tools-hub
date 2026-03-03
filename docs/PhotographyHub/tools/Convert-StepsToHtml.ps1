param(
  [Parameter(Mandatory=$true)][string]$InputTxt,
  [switch]$ReturnJson
)

$ErrorActionPreference = 'Stop'

# Discover folders relative to this script
$ToolsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir  = Split-Path -Parent $ToolsDir
$PagesDir = Join-Path $RootDir 'pages'

function HtmlEscape([string]$s){
  if(-not $s){return ""}
  $s=$s -replace '&','&amp;'
  $s=$s -replace '<','&lt;'
  $s=$s -replace '>','&gt;'
  $s=$s -replace '"','&quot;'
  $s=$s -replace '''','&#39;'
  return $s
}
function Slugify([string]$s){
  if(-not $s){return ""}
  $s=$s.ToLowerInvariant()
  $s=($s -replace '[^a-z0-9-_]+','-').Trim('-')
  if(-not $s){$s='page'}
  return $s
}
function Humanize([string]$s){
  if(-not $s){return 'Checklist'}
  $s=($s -replace '[-_]+',' ').Trim()
  return $s.Substring(0,1).ToUpper()+$s.Substring(1)
}

if (-not (Test-Path $InputTxt)) { throw "Input not found: $InputTxt" }

# Read entire file (preserve CRLF/LF fine)
$raw   = Get-Content -LiteralPath $InputTxt -Raw
$lines = $raw -split "`r?`n"

# Parse @@ header section
$meta = [ordered]@{ title=$null; slug=$null; summary=$null; back="../index.html"; order=$null }
$bodyStart = 0
for($i=0;$i -lt $lines.Count;$i++){
  $L = $lines[$i]
  if ($L -match '^\s*@@\s*(\w+)\s*:\s*(.*)$'){
    $k=$matches[1].ToLower(); $v=$matches[2].Trim()
    switch($k){
      'title'   { $meta['title']=$v }
      'slug'    { $meta['slug']=$v }
      'summary' { $meta['summary']=$v }
      'back'    { $meta['back']=$v }
      'order'   { if($v -match '^\d+$'){ $meta['order']=[int]$v } }
    }
  } elseif ($L.Trim() -eq '') {
    # allow blank lines in control header
  } else {
    $bodyStart=$i; break
  }
}
# Body is everything after the header/control block
$body = ($lines[$bodyStart..($lines.Count-1)] -join "`n")

# Defaults from filename if needed
$fname = [IO.Path]::GetFileNameWithoutExtension($InputTxt) # gps-tracking-steps
$fname = ($fname -replace '(-steps|\.steps)$','')          # gps-tracking
if(-not $meta.title){ $meta.title = Humanize $fname }
if(-not $meta.slug ){ $meta.slug  = Slugify $fname }

# Parse steps (# heading lines start a step, - lines are subitems)
$steps = @(); $cur = $null
foreach($ln in ($body -split "`r?`n")){
  $t = $ln.Trim()
  if([string]::IsNullOrWhiteSpace($t)){ continue }
  if($t -match '^\#\s*(.+)$'){
    $cur = [ordered]@{ title=$matches[1].Trim(); items = New-Object System.Collections.ArrayList }
    $steps += ,$cur
  } elseif ($t -match '^\-\s*(.+)$'){
    if($null -eq $cur){
      $cur = [ordered]@{ title='Step'; items = New-Object System.Collections.ArrayList }
      $steps += ,$cur
    }
    [void]$cur.items.Add($matches[1].Trim())
  } else {
    if($null -eq $cur){
      $cur = [ordered]@{ title='Step'; items = New-Object System.Collections.ArrayList }
      $steps += ,$cur
    }
    [void]$cur.items.Add($t)
  }
}

# Build nested <ol>
$sb = New-Object Text.StringBuilder
[void]$sb.AppendLine('<ol class="steps">')
foreach($s in $steps){
  [void]$sb.AppendLine('  <li>')
  [void]$sb.AppendLine("    <span class=""title"">$(HtmlEscape $s.title)</span>")
  if($s.items.Count -gt 0){
    [void]$sb.AppendLine('    <ol class="sub">')
    foreach($it in $s.items){ [void]$sb.AppendLine("      <li>$(HtmlEscape $it)</li>") }
    [void]$sb.AppendLine('    </ol>')
  }
  [void]$sb.AppendLine('  </li>')
}
[void]$sb.AppendLine('</ol>')
$stepsHtml = $sb.ToString()

# Page template
$Title  = $meta.title
$Back   = if($meta.back){ $meta.back } else { '../index.html' }
$Slug   = $meta.slug
$Out    = Join-Path $PagesDir ($Slug + '.html')
$RelOut = "pages/$Slug.html"

$page = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>$(HtmlEscape $Title)</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    body { margin: 24px; font: 16px/1.5 system-ui, -apple-system, "Segoe UI", Arial, sans-serif; }
    a { color: #0e49c2; text-decoration: none; } a:hover { text-decoration: underline; }
    h1 { margin: 0 0 12px; }
    .back { margin-bottom: 16px; display:inline-block; }
    ol.steps { counter-reset: step; list-style: none; padding-left: 0; margin: 12px 0 24px; }
    ol.steps > li { counter-increment: step; margin: 0 0 16px; }
    ol.steps > li > .title { font-weight: 600; }
    ol.steps > li > .title::before { content: "Step " counter(step) ": "; color: #0e49c2; }
    ol.sub { margin: 8px 0 0 28px; padding-left: 16px; list-style: decimal; }
    ol.sub li { margin: 6px 0; }
  </style>
</head>
<body>
  <a class="back" href="$(HtmlEscape $Back)">← Back to Hub</a>
  <h1>$(HtmlEscape $Title)</h1>

$stepsHtml
</body>
</html>
"@

# Write output file
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Out) | Out-Null
Set-Content -Path $Out -Value $page -Encoding UTF8

# Emit metadata for hub
$metaOut = [ordered]@{
  Title   = $meta.title
  Slug    = $Slug
  Summary = $meta.summary
  Order   = $meta.order
  Href    = $RelOut
}
if($ReturnJson){ $metaOut | ConvertTo-Json -Compress } else { Write-Host "✅ Wrote $Out" }
