# VS Code Extensions Repository

## Overview

This repository serves as a centralized collection of Visual Studio Code extensions. Each extension is self-contained within its own folder, making it easy to manage multiple extensions in one place while maintaining organization and clarity.

## Purpose

This repository is designed to:
- Host multiple VS Code extension projects in a single, organized location
- Facilitate AI-assisted development and maintenance of extensions
- Enable automation through PowerShell scripts
- Share common configuration files across extensions where beneficial
- Maintain clear documentation of each extension's purpose and functionality

## Repository Structure

Each extension folder contains:
- Complete extension source code
- Individual README.md with extension-specific documentation
- Package.json and extension manifest
- Any extension-specific configuration files

Some extensions may share common configuration files stored at the repository root or in a shared configuration folder.

## Extensions

This repository currently contains the following extensions:

*No extensions yet. Extensions will be listed here as they are added.*

<!-- When adding a new extension, add it to the list above using the following format:
- **[Extension Name](./extension-folder-name/)** - Brief description of what the extension does
-->

## AI Usage Guidelines

This repository is designed to work seamlessly with AI assistance. The AI should:

1. **Maintain This README**: Keep the extensions list updated whenever a new extension is added or removed
2. **Follow Extension Structure**: Each extension should be self-contained in its own folder
3. **Update Documentation**: Keep both root and extension-specific documentation current
4. **Respect Shared Resources**: Be aware of and properly manage shared configuration files
5. **Create Automation**: Generate PowerShell scripts when automation is needed

See `.ai-instructions.md` for detailed AI guidelines.

## PowerShell Automation

PowerShell scripts are used to automate common tasks such as:
- Creating new extension scaffolding
- Building multiple extensions
- Publishing extensions
- Managing shared configurations

Automation scripts are stored in the `scripts/` folder (when created).

## Shared Configuration

Some extensions may share common configuration files to maintain consistency. These are documented in each extension's README and may include:
- ESLint configurations
- TypeScript configurations
- Testing configurations
- Common dependencies

## Contributing

When adding a new extension:

1. Create a new folder with a descriptive name (e.g., `my-extension`)
2. Initialize the extension using `yo code` or similar scaffolding tool
3. Update this README to include the new extension in the Extensions section
4. Add extension-specific documentation in the extension's README
5. Commit changes with clear commit messages

## Getting Started

To work with an extension in this repository:

1. Navigate to the extension's folder
2. Run `npm install` to install dependencies
3. Follow the extension-specific README for development instructions
4. Use VS Code's extension development host to test (F5)

## Requirements

- Node.js (LTS version recommended)
- npm or yarn
- Visual Studio Code
- PowerShell (for automation scripts)