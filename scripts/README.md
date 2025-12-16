# PowerShell Automation Scripts

This folder contains PowerShell scripts to automate common tasks in the VS Code extensions repository.

## Available Scripts

### new-extension.ps1

Creates a new VS Code extension scaffold with all necessary files and folder structure.

**Usage:**
```powershell
.\scripts\new-extension.ps1 -Name "my-extension" -DisplayName "My Extension" -Description "Does something useful"
```

**Parameters:**
- `-Name`: Extension folder name (kebab-case)
- `-DisplayName`: Human-readable extension name
- `-Description`: Brief description of the extension

**What it creates:**
- Extension folder with standard structure
- package.json with VS Code extension configuration
- tsconfig.json for TypeScript compilation
- src/extension.ts entry point
- Basic README.md
- .vscodeignore file

**After running:**
1. Navigate to the extension folder
2. Run `npm install`
3. Update the root README.md to include the new extension
4. Start developing (press F5 in VS Code to test)

### build-all.ps1

Builds all VS Code extensions in the repository.

**Usage:**
```powershell
# Build all extensions
.\scripts\build-all.ps1

# Clean build (removes output folders first)
.\scripts\build-all.ps1 -Clean

# Build without installing dependencies
.\scripts\build-all.ps1 -SkipInstall
```

**Parameters:**
- `-Clean`: Removes output directories before building
- `-SkipInstall`: Skips npm install step

**What it does:**
- Finds all extension folders with valid package.json
- Installs dependencies if needed
- Compiles TypeScript to JavaScript
- Reports success/failure for each extension

## Requirements

- PowerShell 5.1 or higher (PowerShell Core 7+ recommended)
- Node.js LTS version
- npm

## Running Scripts

From the repository root:

```powershell
# Run a script
.\scripts\script-name.ps1

# Get help for a script
Get-Help .\scripts\script-name.ps1 -Detailed
```

## Adding New Scripts

When creating new automation scripts:

1. Use clear, descriptive names (verb-noun pattern)
2. Include comment-based help at the top
3. Accept parameters for flexibility
4. Provide clear output and error messages
5. Exit with appropriate exit codes (0 = success)
6. Document the script in this README

## Future Script Ideas

Scripts that could be added:

- `test-all.ps1` - Run tests for all extensions
- `package-extension.ps1` - Create .vsix package for an extension
- `publish-extension.ps1` - Publish extension to marketplace
- `update-dependencies.ps1` - Update dependencies across all extensions
- `validate-extensions.ps1` - Check all extensions meet quality standards
