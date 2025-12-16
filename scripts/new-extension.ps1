<#
.SYNOPSIS
    Creates a new VS Code extension scaffold in the repository.

.DESCRIPTION
    This script helps create a new VS Code extension folder with basic structure.
    It creates the folder, initializes npm, and sets up basic files.

.PARAMETER Name
    The name of the extension (will be used as folder name in kebab-case)

.PARAMETER DisplayName
    The display name of the extension (human-readable)

.PARAMETER Description
    Brief description of what the extension does

.EXAMPLE
    .\new-extension.ps1 -Name "my-extension" -DisplayName "My Extension" -Description "Does something useful"

.NOTES
    Run this script from the repository root.
    Requires Node.js and npm to be installed.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Name,
    
    [Parameter(Mandatory=$true)]
    [string]$DisplayName,
    
    [Parameter(Mandatory=$true)]
    [string]$Description
)

# Ensure we're in the repository root
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host "Creating new VS Code extension: $DisplayName" -ForegroundColor Cyan

# Validate extension name (kebab-case)
if ($Name -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
    Write-Error "Extension name must be in kebab-case (lowercase with hyphens)"
    exit 1
}

# Check if extension already exists
$extensionPath = Join-Path $repoRoot $Name
if (Test-Path $extensionPath) {
    Write-Error "Extension folder '$Name' already exists"
    exit 1
}

Write-Host "Creating extension folder..." -ForegroundColor Green
New-Item -ItemType Directory -Path $extensionPath | Out-Null

# Create basic folder structure
$folders = @("src", "test", "resources")
foreach ($folder in $folders) {
    New-Item -ItemType Directory -Path (Join-Path $extensionPath $folder) | Out-Null
}

Write-Host "Creating package.json..." -ForegroundColor Green

# Create package.json
$packageJson = @{
    name = $Name
    displayName = $DisplayName
    description = $Description
    version = "0.0.1"
    engines = @{
        vscode = "^1.80.0"
    }
    categories = @("Other")
    activationEvents = @()
    main = "./out/extension.js"
    contributes = @{
        commands = @()
    }
    scripts = @{
        "vscode:prepublish" = "npm run compile"
        compile = "tsc -p ./"
        watch = "tsc -watch -p ./"
        pretest = "npm run compile"
        test = "node ./out/test/runTest.js"
    }
    devDependencies = @{
        "@types/vscode" = "^1.80.0"
        "@types/node" = "16.x"
        typescript = "^5.0.0"
        "@vscode/test-electron" = "^2.3.0"
    }
} | ConvertTo-Json -Depth 10

$packageJson | Out-File -FilePath (Join-Path $extensionPath "package.json") -Encoding utf8

Write-Host "Creating TypeScript configuration..." -ForegroundColor Green

# Create tsconfig.json
$tsconfigJson = @{
    compilerOptions = @{
        module = "commonjs"
        target = "ES2020"
        outDir = "out"
        lib = @("ES2020")
        sourceMap = $true
        rootDir = "src"
        strict = $true
    }
    exclude = @("node_modules", ".vscode-test")
} | ConvertTo-Json -Depth 10

$tsconfigJson | Out-File -FilePath (Join-Path $extensionPath "tsconfig.json") -Encoding utf8

Write-Host "Creating extension entry point..." -ForegroundColor Green

# Create src/extension.ts
$extensionTs = @"
import * as vscode from 'vscode';

export function activate(context: vscode.ExtensionContext) {
    console.log('Extension "$DisplayName" is now active');

    // Register commands here
    // Example:
    // let disposable = vscode.commands.registerCommand('$Name.helloWorld', () => {
    //     vscode.window.showInformationMessage('Hello World from $DisplayName!');
    // });
    // context.subscriptions.push(disposable);
}

export function deactivate() {}
"@

$extensionTs | Out-File -FilePath (Join-Path $extensionPath "src/extension.ts") -Encoding utf8

Write-Host "Creating .vscodeignore..." -ForegroundColor Green

# Create .vscodeignore
$vscodeignore = @"
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
"@

$vscodeignore | Out-File -FilePath (Join-Path $extensionPath ".vscodeignore") -Encoding utf8

Write-Host "Creating README.md..." -ForegroundColor Green

# Create README.md
$readme = @"
# $DisplayName

$Description

## Features

Describe the features of your extension here.

## Requirements

- Visual Studio Code 1.80.0 or higher

## Extension Settings

This extension contributes the following settings:

* Currently no settings

## Known Issues

None at this time.

## Release Notes

### 0.0.1

Initial release

## Development

### Building

``````bash
npm install
npm run compile
``````

### Testing

Press F5 in VS Code to open a new window with the extension loaded.

## License

See repository root for license information.
"@

$readme | Out-File -FilePath (Join-Path $extensionPath "README.md") -Encoding utf8

Write-Host "`nExtension scaffold created successfully!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. cd $Name"
Write-Host "2. npm install"
Write-Host "3. Update the root README.md to include this extension"
Write-Host "4. Open the extension folder in VS Code and start developing (F5 to test)"
Write-Host "`nDon't forget to update the root README.md Extensions section!" -ForegroundColor Cyan
