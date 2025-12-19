# VS Code Extensions (Monorepo)

A small collection of VS Code extensions I maintain in a single repository.

This repo is a **monorepo**: one Git repository containing multiple independent VS Code extensions (each in its own folder with its own `package.json`).

## Extensions

- **Branch Merger Extension** — One-command merge workflow + optional polling/notifications.

  - Project: `BranchMergerExtension/`
  - Docs: [BranchMergerExtension/README.md](BranchMergerExtension/README.md)

- **Branch Name Template** — Create branches with a consistent prefix template.

  - Project: `BranchNameTemplateExtension/`
  - Docs: [BranchNameTemplateExtension/README.md](BranchNameTemplateExtension/README.md)

- **WPF DataContext MVP** — F12 Go To Definition for simple WPF XAML `{Binding Property}` (design-time DataContext only). (Currently untested; best-effort.)

  - Project: `WpfDataContextMvpExtension/`
  - Docs: [WpfDataContextMvpExtension/README.md](WpfDataContextMvpExtension/README.md)

## Repo Standards ("mine")

These standards apply to **this repo** and to **each extension**.

- **Docs format**: Every extension README must include (in this order): **Overview**, **Commands**, **Settings**, **Multi-root / Workspace behavior** (if relevant), **Requirements**, **Development**, **Packaging & Publishing**, **Changelog**.
- **Stability**: Treat command IDs and setting keys as public API; don’t rename them casually.
- **AI assistance**: Follow the repo’s Copilot guidance in `.github/copilot-instructions.md`.
- **Release hygiene**: When behavior changes, update the extension `README.md`, `CHANGELOG.md`, and version in `package.json`.
- **Monorepo metadata**: Each extension’s `package.json` must point `repository.url` at this repo and include `repository.directory` for its subfolder.

## Development (local)

Prereqs:

- VS Code
- Git
- Node.js (use the current **Node LTS**)

Typical workflow:

1. Open this repo in VS Code.
2. Open the extension folder you want to work on (or keep the monorepo open).
3. Press `F5` to launch an **Extension Development Host**.
4. Use the Command Palette in the Dev Host to run that extension’s commands.

## Automation

This repo includes PowerShell scripts for automation:

- Repo automation (scaffolding/build): see [tools/README.md](tools/README.md)
- Icon generation: `pwsh -NoProfile -File tools/generate-icons.ps1 -All`

## Packaging & Publishing (prepare now, publish later)

Each extension is packaged/published from its own folder.

Install the VS Code Extension CLI (once):

```bash
npm install -g @vscode/vsce
```

Package an extension (example):

```bash
cd BranchMergerExtension
vsce package
```

Publish (when ready):

```bash
cd BranchMergerExtension
vsce publish
```

Marketplace readiness checklist (quick):

- Provide an `icon` in each extension `package.json`
- Ensure `repository`, `bugs`, and `homepage` metadata are correct
- Review README screenshots/usage notes
- Confirm activation events are minimal and correct

## What “monorepo” changes vs one-repo-per-extension?

- **Pros**: shared standards/docs, one place to manage releases, easy cross-extension improvements.
- **Gotchas**: packaging/publishing is still **per extension folder**, and metadata should include the subfolder (`repository.directory`).
