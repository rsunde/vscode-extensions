<#
.SYNOPSIS
    Creates a new VS Code extension scaffold in the repository.

.DESCRIPTION
    Creates a new extension folder aligned with this repo's conventions.

    Default scaffolding is JavaScript (like the existing extensions here).
    Use -Language ts if you want a TypeScript-based scaffold.

.PARAMETER Name
    Extension folder name (e.g. BranchFooExtension)

.PARAMETER PackageName
    Optional npm package name (kebab-case). If omitted, derived from -Name.

.PARAMETER DisplayName
    The display name shown in VS Code.

.PARAMETER Description
    Brief description of what the extension does.

.PARAMETER Language
    Scaffold style: 'js' (default) or 'ts'.

.EXAMPLE
    .\tools\new-extension.ps1 -Name "MyCoolExtension" -DisplayName "My Cool Extension" -Description "Does something" -Language js

.EXAMPLE
    .\tools\new-extension.ps1 -Name "MyCoolExtension" -DisplayName "My Cool Extension" -Description "Does something" -Language ts

.NOTES
    Run this script from the repository root.
    Supports -WhatIf.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $false)]
    [string]$PackageName,

    [Parameter(Mandatory = $true)]
    [string]$DisplayName,

    [Parameter(Mandatory = $true)]
    [string]$Description,

    [Parameter(Mandatory = $false)]
    [ValidateSet('js', 'ts')]
    [string]$Language = 'js'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host "Creating new VS Code extension: $DisplayName" -ForegroundColor Cyan

if ([string]::IsNullOrWhiteSpace($PackageName)) {
    $derived = $Name
    $derived = $derived -replace '\s+', '-'
    $derived = $derived -replace '_', '-'
    $derived = $derived -replace 'Extension$', ''
    $derived = $derived -replace '([a-z0-9])([A-Z])', '$1-$2'
    $derived = $derived.ToLowerInvariant()
    $PackageName = $derived
}

if ($PackageName -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
    throw "PackageName must be kebab-case (lowercase with hyphens). Got '$PackageName'."
}

$extensionPath = Join-Path $repoRoot $Name
if (Test-Path $extensionPath) {
    throw "Extension folder '$Name' already exists"
}

if (-not $PSCmdlet.ShouldProcess($extensionPath, "Create VS Code extension scaffold ($Language)")) {
    return
}

Write-Host "Creating extension folder..." -ForegroundColor Green
New-Item -ItemType Directory -Path $extensionPath | Out-Null

$folders = @('images', '.github')
if ($Language -eq 'ts') {
    $folders += @('src', 'test')
}
foreach ($folder in $folders) {
    New-Item -ItemType Directory -Path (Join-Path $extensionPath $folder) | Out-Null
}

Write-Host "Creating package.json..." -ForegroundColor Green

$packageJson = @{
    name             = $PackageName
    displayName      = $DisplayName
    description      = $Description
    version          = '0.0.1'
    publisher        = 'rsunde'
    repository       = @{
        type      = 'git'
        url       = 'https://github.com/rsunde/vscode-extensions.git'
        directory = $Name
    }
    engines          = @{
        vscode = '^1.70.0'
    }
    categories       = @('Other')
    icon             = 'images/icon.png'
    license          = 'MIT'
    main             = $(if ($Language -eq 'ts') { './out/extension.js' } else { './extension.js' })
    activationEvents = @()
    contributes      = @{
        commands      = @()
        configuration = @{
            title      = $DisplayName
            properties = @{}
        }
    }
}

if ($Language -eq 'ts') {
    $packageJson.scripts = @{
        'vscode:prepublish' = 'npm run compile'
        compile             = 'tsc -p .'
        watch               = 'tsc -watch -p .'
    }
    $packageJson.devDependencies = @{
        '@types/vscode' = '^1.70.0'
        '@types/node'   = '20.x'
        'typescript'    = '^5.0.0'
    }
}

($packageJson | ConvertTo-Json -Depth 15) | Out-File -FilePath (Join-Path $extensionPath 'package.json') -Encoding utf8

if ($Language -eq 'ts') {
    Write-Host "Creating TypeScript configuration..." -ForegroundColor Green
    $tsconfigJson = @{
        compilerOptions = @{
            module    = 'commonjs'
            target    = 'ES2020'
            outDir    = 'out'
            lib       = @('ES2020')
            sourceMap = $true
            rootDir   = 'src'
            strict    = $true
        }
        exclude         = @('node_modules', '.vscode-test')
    }
    ($tsconfigJson | ConvertTo-Json -Depth 10) | Out-File -FilePath (Join-Path $extensionPath 'tsconfig.json') -Encoding utf8
}

Write-Host "Creating extension entry point..." -ForegroundColor Green
if ($Language -eq 'ts') {
    @"
import * as vscode from 'vscode';

export function activate(context: vscode.ExtensionContext) {
    console.log('Extension "$DisplayName" is now active');
}

export function deactivate() {}
"@ | Out-File -FilePath (Join-Path $extensionPath 'src/extension.ts') -Encoding utf8
}
else {
    @"
const vscode = require('vscode');

/**
 * @param {import('vscode').ExtensionContext} context
 */
function activate(context) {
    console.log('Extension "$DisplayName" is now active');
}

function deactivate() {}

module.exports = { activate, deactivate };
"@ | Out-File -FilePath (Join-Path $extensionPath 'extension.js') -Encoding utf8
}

Write-Host "Creating .gitignore/.vscodeignore..." -ForegroundColor Green
"node_modules`n.vscode`n.DS_Store`n*.vsix`n" | Out-File -FilePath (Join-Path $extensionPath '.gitignore') -Encoding utf8

@"
.vscode/**
.vscode-test/**
src/**
test/**
.gitignore
.yarnrc
vsc-extension-quickstart.md
**/tsconfig.json
**/.eslintrc.json
**/*.map
**/*.ts
"@ | Out-File -FilePath (Join-Path $extensionPath '.vscodeignore') -Encoding utf8

Write-Host "Creating README.md..." -ForegroundColor Green
@"
# $DisplayName

## Overview

$Description

## Commands

TODO

## Settings

TODO

## Requirements

- Visual Studio Code 1.70.0 or higher

## Development

- Press `F5` to launch an Extension Development Host.
$(if ($Language -eq 'ts') { "- Run `npm install` then `npm run compile` if you add TypeScript." } else { "" })

## Packaging & Publishing

See the repo root README.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
"@ | Out-File -FilePath (Join-Path $extensionPath 'README.md') -Encoding utf8

Write-Host "Creating CHANGELOG.md..." -ForegroundColor Green
@"
# Change Log

All notable changes to the "$PackageName" extension will be documented in this file.

## [0.0.1] - $(Get-Date -Format 'yyyy-MM-dd')

- Initial scaffold
"@ | Out-File -FilePath (Join-Path $extensionPath 'CHANGELOG.md') -Encoding utf8

Write-Host "Creating LICENSE..." -ForegroundColor Green
$licenseSource = Join-Path $repoRoot 'BranchMergerExtension\LICENSE'
if (Test-Path $licenseSource) {
    Copy-Item -Path $licenseSource -Destination (Join-Path $extensionPath 'LICENSE')
}
else {
    "The MIT License (MIT)" | Out-File -FilePath (Join-Path $extensionPath 'LICENSE') -Encoding utf8
}

Write-Host "Creating per-extension Copilot instructions..." -ForegroundColor Green
@"
# Copilot Instructions — $DisplayName

Follow the repo-wide instructions in `/.github/copilot-instructions.md`.

## Public API stability

- Do not rename command IDs or setting keys without asking first.
"@ | Out-File -FilePath (Join-Path $extensionPath '.github/copilot-instructions.md') -Encoding utf8

Write-Host "Creating icon drawing placeholder..." -ForegroundColor Green
@"
{
  "shapes": []
}
"@ | Out-File -FilePath (Join-Path $extensionPath 'images/icon.drawing.json') -Encoding utf8

Write-Host ""
Write-Host "Extension scaffold created successfully." -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Add the extension to the root README Extensions list"
Write-Host "2. (Optional) Generate icons: pwsh -NoProfile -File tools/generate-icons.ps1 -All"
Write-Host "3. Press F5 in VS Code to run/debug"
