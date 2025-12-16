# Copilot Instructions — Branch Name Template Extension

Purpose: help users create git branches with a consistent, configurable prefix template.

## API stability (do not break)

- Command:
  - `branch-name-template.createBranch`
- Settings prefix: `branchNameTemplate.*`

Do not rename these without explicit user approval.

## Behavioral constraints

- Do not create surprising branch names: keep variable replacement predictable.
- Avoid destructive git commands.
- Be careful with quoting/escaping in branch names.
- Multi-root behavior matters: current implementation uses the first workspace folder; ask before changing this selection logic.

## Docs standards

Keep the extension README aligned with repo standards (Overview → Commands → Settings → Multi-root behavior → Requirements → Development → Packaging & Publishing → Changelog).
