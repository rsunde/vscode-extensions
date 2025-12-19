# WPF DataContext MVP

## Overview

Note: This extension is currently **untested** and was pushed directly to the main branch as a best-effort navigation hack.

Best-effort Go To Definition (F12) for WPF XAML bindings in this extremely limited scenario:

```xml
{Binding PropertyName}
```

Resolved using the nearest ancestor's design-time DataContext:

- `x:DataType="prefix:TypeName"`, or
- `d:DataContext="{d:DesignInstance Type=prefix:TypeName}"`

If anything is ambiguous or unsupported, the provider returns nothing.

## Commands

None.

## Settings

None.

## Multi-root / Workspace behavior

No special behavior.

## Requirements

- Visual Studio Code 1.70.0 or higher

## Development

- Press `F5` to launch an Extension Development Host.

Notes:

- The definition provider is registered for `xml` files but scoped to `**/*.xaml` via a document selector.


## Packaging & Publishing

See the repo root README.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
