# Dudley's Second Bedroom - Copilot Instructions

This document provides essential information for coding agents working with this repository to minimize exploration time and avoid common build failures.

## Repository Overview

**Dudley's Second Bedroom** is a custom Universal Blue Fedora Atomic remix with a modular build system, declarative configuration, and a content-versioned first-boot experience.

- **Type**: Container-based Linux distribution build system
- **Base**: Universal Blue's Bluefin-DX (Developer Experience) image
- **Languages**: Bash scripts, JSON configuration
- **Build System**: Just (command runner), Podman containers, GitHub Actions
- **Target**: Personalized developer desktop OS

## Repository Structure

### Key Directories
- `system_files/` - User-space files, configurations copied into the image
- `build_files/` - Build modules organized by category:
  - `shared/` - Core platform modules and utilities
  - `desktop/` - Desktop environment customizations
  - `developer/` - Development tools (VS Code, DevPod, Action Server)
  - `user-hooks/` - First-boot user configuration hooks
- `.github/workflows/` - CI/CD pipelines
- `brew/` - Homebrew Brewfile definitions
- `flatpaks/` - Flatpak application lists
- `custom_wallpapers/` - Wallpaper assets (content-versioned)
- `tests/` - Validation and test scripts
- `docs/` and `specs/` - Architecture references and design docs

### Architecture
- **Base Image**: `ghcr.io/ublue-os/bluefin-dx:stable`
- **Build Process**: Modular shell scripts auto-discovered and executed in category order
- **Content Versioning**: Automatic hash-based versioning for first-boot hooks

## Build Instructions

### Essential Commands

**Build validation (ALWAYS run before making changes):**
```bash
# Run all validation checks
just check

# Run full test suite
just test-all

# Fix formatting issues
just fix
```

**Build commands:**
```bash
# Build container image
just build

# Build and verify
just build && just verify-build

# Build bootable media
just build-qcow2  # Virtual machine image
just build-iso    # ISO installer
```

### Common Build Failures & Workarounds

**Module validation failures:**
- Ensure module has required header (Purpose, Category, Dependencies, etc.)
- Check file has execute permission: `chmod +x build_files/.../*.sh`
- Run `just validate-modules` to identify issues

**Package conflicts:**
- Check `packages.json` for duplicates: `just validate-packages`
- Ensure packages aren't in both install and remove lists

## Module Development

### Module Header Contract
Every module **must** start with:
```bash
#!/usr/bin/env bash
# Purpose: <succinct summary>
# Category: <shared|desktop|developer|user-hooks>
# Dependencies: <comma-separated module names or 'none'>
# Parallel-Safe: <yes|no>
# Cache-Friendly: <yes|no>
set -euo pipefail
```

### Module Execution Order
1. `shared/` - Core utilities (00-image-info, package-install, branding, cleanup)
2. `desktop/` - Desktop customizations (dconf, fonts, GNOME)
3. `developer/` - Dev tools (devpod, vscode, action-server)
4. `user-hooks/` - First-boot scripts installed to `/usr/share/ublue-os/user-setup.hooks.d/`

### Exit Codes
- `0` - Success
- `1` - Failure (halts build)
- `2` - Intentional skip (non-error, continues build)

## Configuration Files

### Key Files
- `packages.json` - Declarative package install/remove lists
- `flatpaks/system-flatpaks.list` - System Flatpak applications
- `vscode-extensions.list` - VS Code extensions for first-boot
- `brew/*.Brewfile` - Homebrew package collections

### Making Package Changes
1. Edit `packages.json` (prefer this over inline dnf calls)
2. Run `just validate-packages`
3. Test with `just build`

## Content Versioning System

### How It Works
- `generate-manifest.sh` computes content hashes across tracked assets
- Hashes stored in `/etc/dudley/build-manifest.json`
- Hooks use `__CONTENT_VERSION__` placeholder replaced at build time

### When to Update
- Adding new wallpapers to `custom_wallpapers/`
- Modifying hook scripts in `build_files/user-hooks/`
- Changing `vscode-extensions.list`

## Development Guidelines

### Making Changes
1. **ALWAYS validate first:** `just check`
2. **Make minimal modifications** - prefer configuration over code changes
3. **Test locally:** `just build` before pushing
4. **Run tests:** `just test-unit` for quick feedback

### File Editing Best Practices
- **Shell scripts**: Follow existing patterns, use `shellcheck`
- **JSON files**: Validate syntax with `jq empty filename.json`
- **Modules**: Include required header, use logging helper

### Adding a New Module
1. Create file in appropriate category directory
2. Add required header metadata
3. Make executable: `chmod +x`
4. Test: `just validate-modules && just build`

## Trust These Instructions

The information in this document has been validated against the current repository state. Only search for additional information if:
- Instructions are incomplete for your specific task
- You encounter errors not covered here
- Repository structure has changed significantly

## Important Rules

- Ensure [conventional commits](https://www.conventionalcommits.org/) are used
- Keep modules idempotent (safe to re-run)
- Prefer declarative inputs (`packages.json`) over imperative installs
- Document complex behavior in `docs/` or `specs/`
- Run validation scripts before pushing changes
