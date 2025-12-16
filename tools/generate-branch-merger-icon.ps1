$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$generator = Join-Path $repoRoot 'tools/generate-icons.ps1'

pwsh -NoProfile -File $generator -DrawingPath 'BranchMergerExtension/images/icon.drawing.json'
