# Copilot Instructions — Branch Merger Extension

Purpose: streamline merging changes from a chosen source branch into the current branch, optionally notify when the default branch advances.

## API stability (do not break)

- Commands:
  - `branch-merger-extension.mergeBranch`
  - `branch-merger-extension.checkDefaultUpdates`
- Settings prefix: `branchMergerExtension.*`

Do not rename these without explicit user approval.

## Behavioral constraints

- Never lose working changes: stash only when needed, and restore reliably.
- Prefer informative errors over silent failures.
- Treat multi-root workspaces as first-class: use the active editor’s workspace folder when possible; prompt when ambiguous.

## Docs standards

Keep the extension README aligned with repo standards (Overview → Commands → Settings → Multi-root behavior → Requirements → Development → Packaging & Publishing → Changelog).

## When changing git behavior

Ask first if the change affects:

- checkout strategy (merge via remote ref vs local branch)
- whether to fetch/pull
- default branch detection order
- polling frequency/notifications
