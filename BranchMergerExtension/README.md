# Branch Merger Extension

Merge changes from another branch into your current branch with a guided workflow, plus optional polling to notify you when your default branch advances.

## Overview

- Stashes uncommitted changes (if any), performs the merge, then restores your stash.
- Offers a Quick Pick list of local branches, prioritizing your configured default source branch.
- Optional polling can fetch + notify when your default branch has new commits.

## Commands

- **Merge Branch into Current** (`branch-merger-extension.mergeBranch`)
- **Check Default Branch for Updates** (`branch-merger-extension.checkDefaultUpdates`)

## Settings

- `branchMergerExtension.defaultSourceBranch` (string, default: `auto`): default merge source branch name, or `auto`.
- `branchMergerExtension.rememberDetectedDefaultBranch` (boolean, default: `true`): cache detected/picked default branch per repo.
- `branchMergerExtension.pollForUpdates` (boolean, default: `false`): enable periodic update checks.
- `branchMergerExtension.pollIntervalMinutes` (number, default: `5`): poll interval (minutes).
- `branchMergerExtension.autoFetchBeforePoll` (boolean, default: `true`): run `git fetch --prune` before checking.
- `branchMergerExtension.remoteName` (string, default: `origin`): remote used for tracking refs.
- `branchMergerExtension.preferRemoteTracking` (boolean, default: `true`): prefer `origin/<branch>` when present.
- `branchMergerExtension.notifyOnUpdates` (boolean, default: `true`): show notifications when updates are detected.

## Default Branch Detection

When `branchMergerExtension.defaultSourceBranch` is `auto`, the extension tries (in order):

1. Remote HEAD ref (example: `refs/remotes/origin/HEAD` -> `origin/main`)
2. Common local branches (`main`, `master`, `develop`, `dev`)
3. `git config init.defaultBranch`

If it still can't determine the default branch, it prompts you once and (optionally) remembers your choice for that repo.

## Multi-root / Workspace behavior

- Commands run against the repo that contains your **active editor file**.
- If VS Code can't infer the repo, you'll be prompted to pick a workspace folder.
- When polling is enabled, it checks **all** git repos in the workspace.

## Requirements

- Git must be installed and available in your PATH.
- Your workspace folder must be a git repository.

## Development

1. Open the `BranchMergerExtension/` folder in VS Code.
2. Press `F5` (Extension Development Host).
3. Run **Merge Branch into Current** from the Command Palette.

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
