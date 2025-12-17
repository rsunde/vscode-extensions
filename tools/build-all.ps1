<#
.SYNOPSIS
    Builds all VS Code extensions in the repository.

.DESCRIPTION
    This script finds all extension folders (those containing package.json with VS Code engine),
    installs dependencies (when needed), and runs each extension's build step (when defined).

    Notes:
    - Not all extensions in this repo are TypeScript-based.
    - For JS-only extensions with no build scripts, this script will simply validate discovery and (optionally) install dependencies.

.PARAMETER Clean
    If specified, runs a clean build (deletes out/ folder before building)

.PARAMETER SkipInstall
    If specified, skips npm install and only runs compilation

.EXAMPLE
    .\tools\build-all.ps1
    Builds all extensions

.EXAMPLE
    .\tools\build-all.ps1 -Clean
    Performs a clean build of all extensions

.EXAMPLE
    .\tools\build-all.ps1 -SkipInstall
    Builds all extensions without running npm install

.NOTES
    Run this script from the repository root.
    Requires Node.js and npm to be installed.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Clean,

    [Parameter(Mandatory = $false)]
    [switch]$SkipInstall
)

# Ensure we're in the repository root
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host "Building all VS Code extensions in repository" -ForegroundColor Cyan
Write-Host "Repository root: $repoRoot`n" -ForegroundColor Gray

# Find all extension folders
$extensions = Get-ChildItem -Directory | Where-Object {
    $packageJsonPath = Join-Path $_.FullName 'package.json'
    if (-not (Test-Path $packageJsonPath)) { return $false }

    try {
        $packageJson = Get-Content -Raw $packageJsonPath | ConvertFrom-Json
        return $null -ne $packageJson.engines.vscode
    }
    catch {
        return $false
    }
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
        $packageJsonPath = Join-Path $extension.FullName 'package.json'
        $packageJson = Get-Content -Raw $packageJsonPath | ConvertFrom-Json

        $hasDependencies = ($null -ne $packageJson.dependencies) -or ($null -ne $packageJson.devDependencies)
        $hasLockFile = (Test-Path (Join-Path $extension.FullName 'package-lock.json'))

        $scripts = $packageJson.scripts
        $buildScriptName = $null
        if ($null -ne $scripts) {
            if ($null -ne $scripts.compile) { $buildScriptName = 'compile' }
            elseif ($null -ne $scripts.build) { $buildScriptName = 'build' }
        }

        # Clean build if requested
        if ($Clean) {
            $pathsToClean = @(
                (Join-Path $extension.FullName 'out'),
                (Join-Path $extension.FullName 'dist'),
                (Join-Path $extension.FullName 'node_modules'),
                (Join-Path $extension.FullName '.vscode-test')
            )

            foreach ($p in $pathsToClean) {
                if (Test-Path $p) {
                    Write-Host "Cleaning: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Yellow
                    Remove-Item -Path $p -Recurse -Force
                }
            }
        }

        # Install dependencies (only when the extension declares any)
        if (-not $SkipInstall) {
            if (-not $hasDependencies) {
                Write-Host "No dependencies declared; skipping npm install" -ForegroundColor Gray
            }
            else {
                Write-Host "Installing dependencies..." -ForegroundColor Yellow
                if ($hasLockFile) {
                    npm ci
                }
                else {
                    npm install
                }
                if ($LASTEXITCODE -ne 0) {
                    throw "Dependency install failed"
                }
            }
        }

        # Build (only when the extension defines a build script)
        if ($null -eq $buildScriptName) {
            Write-Host "No build script found (no scripts.compile/scripts.build); skipping build" -ForegroundColor Gray
        }
        else {
            Write-Host "Running npm run $buildScriptName..." -ForegroundColor Yellow
            npm run $buildScriptName
            if ($LASTEXITCODE -ne 0) {
                throw "Build failed"
            }
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
