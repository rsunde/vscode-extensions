# PowerShell Automation (tools/)

This folder contains repo-level PowerShell tooling:

- Repo automation (scaffolding/build/validation)
- Asset generation (icons)

## Repo automation

### new-extension.ps1

Creates a new VS Code extension scaffold aligned to this repo.

Usage:

```powershell
.\tools\new-extension.ps1 -Name "MyCoolExtension" -DisplayName "My Extension" -Description "Does something useful"

# TypeScript scaffold (optional)
.\tools\new-extension.ps1 -Name "MyCoolExtension" -DisplayName "My Extension" -Description "Does something useful" -Language ts
```

### build-all.ps1

Builds all VS Code extensions in the repository.

Usage:

```powershell
# Build all extensions
.\tools\build-all.ps1

# Clean build (removes output folders first)
.\tools\build-all.ps1 -Clean

# Build without installing dependencies
.\tools\build-all.ps1 -SkipInstall
```

## Icon generation

Generate icons for all extensions:

```powershell
pwsh -NoProfile -File tools/generate-icons.ps1 -All
```
