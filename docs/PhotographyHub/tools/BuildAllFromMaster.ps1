# BuildAllFromMaster.ps1  (opens index.html when done)

$Tools = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root  = Split-Path -Parent $Tools
$Pages = Join-Path $Root 'pages'

$split = Join-Path $Tools 'Split-MasterSteps.ps1'
$conv  = Join-Path $Tools 'Convert-StepsToHtml.ps1'
$build = Join-Path $Tools 'BuildAllPages.ps1'   # change if your hub builder has a different name
$hub   = Join-Path $Root 'index.html'

# Sanity checks
if (-not (Test-Path $split)) { throw "Missing splitter: $split" }
if (-not (Test-Path $conv))  { throw "Missing converter: $conv" }

Write-Host "[1/3] Splitting MASTER into per-page steps..."
& $split

Write-Host "[2/3] Converting all steps -> HTML pages..."
$steps = Get-ChildItem $Pages -File |
  Where-Object { $_.Name -match '(-steps\.txt|\.steps\.txt)$' -and $_.Name -notmatch '^(?i)MASTER\.steps\.txt$' }

foreach ($s in $steps) {
  & $conv -InputTxt $s.FullName | Out-Null
  $html = ($s.Name -replace '(-steps\.txt|\.steps\.txt)$','.html')
  Write-Host ("Built: pages/{0}" -f $html)
}

if (Test-Path $build) {
  Write-Host "[3/3] Rebuilding hub (index.html)..."
  & $build
} else {
  Write-Host "WARNING: Hub builder not found at: $build"
  Write-Host "         If your hub builder has a different name, update `$build in this script."
}

Write-Host "All done."

# Auto-open the hub if it exists
if (Test-Path $hub) {
  try {
    Start-Process -FilePath $hub
  } catch {
    Write-Warning ("Could not open {0}: {1}" -f $hub, $_.Exception.Message)
  }
}
