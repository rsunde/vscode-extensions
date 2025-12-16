<#
.SYNOPSIS
    Builds all VS Code extensions in the repository.

.DESCRIPTION
    This script finds all extension folders (those containing package.json with VS Code engine),
    installs dependencies if needed, and compiles each extension.

.PARAMETER Clean
    If specified, runs a clean build (deletes out/ folder before building)

.PARAMETER SkipInstall
    If specified, skips npm install and only runs compilation

.EXAMPLE
    .\build-all.ps1
    Builds all extensions

.EXAMPLE
    .\build-all.ps1 -Clean
    Performs a clean build of all extensions

.EXAMPLE
    .\build-all.ps1 -SkipInstall
    Builds all extensions without running npm install

.NOTES
    Run this script from the repository root.
    Requires Node.js and npm to be installed.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$Clean,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipInstall
)

# Ensure we're in the repository root
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host "Building all VS Code extensions in repository" -ForegroundColor Cyan
Write-Host "Repository root: $repoRoot`n" -ForegroundColor Gray

# Find all extension folders
$extensions = Get-ChildItem -Directory | Where-Object {
    $packageJsonPath = Join-Path $_.FullName "package.json"
    if (Test-Path $packageJsonPath) {
        $packageJson = Get-Content $packageJsonPath | ConvertFrom-Json
        return $packageJson.engines.vscode -ne $null
    }
    return $false
}

if ($extensions.Count -eq 0) {
    Write-Host "No extensions found in repository." -ForegroundColor Yellow
    Write-Host "Extensions must have a package.json with 'engines.vscode' field." -ForegroundColor Gray
    exit 0
}

Write-Host "Found $($extensions.Count) extension(s):`n" -ForegroundColor Green
$extensions | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor White }
Write-Host ""

$successCount = 0
$failureCount = 0
$failedExtensions = @()

foreach ($extension in $extensions) {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Building: $($extension.Name)" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    Set-Location $extension.FullName
    
    try {
        # Clean build if requested
        if ($Clean) {
            $outDir = Join-Path $extension.FullName "out"
            if (Test-Path $outDir) {
                Write-Host "Cleaning output directory..." -ForegroundColor Yellow
                Remove-Item -Path $outDir -Recurse -Force
            }
        }
        
        # Install dependencies if needed
        if (-not $SkipInstall) {
            if (-not (Test-Path "node_modules")) {
                Write-Host "Installing dependencies..." -ForegroundColor Yellow
                npm install
                if ($LASTEXITCODE -ne 0) {
                    throw "npm install failed"
                }
            } else {
                Write-Host "Dependencies already installed (use -Clean to reinstall)" -ForegroundColor Gray
            }
        }
        
        # Compile
        Write-Host "Compiling TypeScript..." -ForegroundColor Yellow
        npm run compile
        if ($LASTEXITCODE -ne 0) {
            throw "Compilation failed"
        }
        
        Write-Host "✓ Build successful for $($extension.Name)" -ForegroundColor Green
        $successCount++
    }
    catch {
        Write-Host "✗ Build failed for $($extension.Name): $_" -ForegroundColor Red
        $failureCount++
        $failedExtensions += $extension.Name
    }
    finally {
        Set-Location $repoRoot
        Write-Host ""
    }
}

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Build Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total extensions: $($extensions.Count)" -ForegroundColor White
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Failed: $failureCount" -ForegroundColor $(if ($failureCount -eq 0) { "Green" } else { "Red" })

if ($failureCount -gt 0) {
    Write-Host "`nFailed extensions:" -ForegroundColor Red
    $failedExtensions | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host "`nAll extensions built successfully! ✓" -ForegroundColor Green
exit 0
