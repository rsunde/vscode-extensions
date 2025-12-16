# Branch Name Template

Create git branches with a consistent naming convention using a configurable prefix template.

## Overview

- Pre-fills branch creation with a template (example: `MyTeam/main/jdoe/`).
- Variables: `${team}`, `${baseBranch}`, `${username}`.
- Username can be auto-detected from git config or OS username.
- Can create-and-checkout, or just create.

## Commands

- **Create Branch from Template** (`branch-name-template.createBranch`)

## Settings

- `branchNameTemplate.prefix` (string, default: `${team}/${baseBranch}/${username}/`)
- `branchNameTemplate.team` (string, default: `MyTeam`)
- `branchNameTemplate.autoDetectUsername` (boolean, default: `true`)
- `branchNameTemplate.username` (string, default: empty; used when auto-detect is off)
- `branchNameTemplate.checkout` (boolean, default: `true`)

## Multi-root / Workspace behavior

- Currently uses the **first** workspace folder as the target repo.
- If you often use multi-root workspaces, consider opening the specific repo folder before running the command.

## Requirements

- Git must be installed and available in your PATH.
- You must have a folder opened in VS Code that is a git repository.

## Development

1. Open the `BranchNameTemplateExtension/` folder in VS Code.
2. Press `F5` (Extension Development Host).
3. Run **Create Branch from Template** from the Command Palette.

## Packaging & Publishing

From the extension folder:

```bash
npm install -g @vscode/vsce
vsce package
```

Publishing (when ready):

```bash
vsce publish
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
