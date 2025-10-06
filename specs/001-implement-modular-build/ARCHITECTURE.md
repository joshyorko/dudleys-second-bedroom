# Architecture: Modular Build System

**Version**: 1.0.0  
**Date**: 2025-10-05  
**Feature**: Modular Build Architecture with Multi-Stage Containerfile

## Overview

This document describes the modular build system architecture for Dudley's Second Bedroom, a customized Universal Blue OS image. The system replaces a monolithic build script with a modular, maintainable, and cacheable approach.

## Design Principles

1. **Modularity**: Build functionality separated into independent, single-purpose modules
2. **Maintainability**: Self-documenting structure with clear naming conventions
3. **Performance**: Aggressive caching and parallel execution where possible
4. **Validation**: Comprehensive pre-build, build-time, and post-build validation
5. **Simplicity**: Standard tools (bash, just, jq) with minimal abstractions

## System Architecture

### High-Level Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     Multi-Stage Containerfile                │
│                                                              │
│  Stage 1: Context (scratch)                                 │
│    ├─ build_files/                                          │
│    ├─ system_files/                                         │
│    ├─ custom_wallpapers/                                    │
│    └─ packages.json                                         │
│                                                              │
│  Stage 2: Base (bluefin-dx:stable)                          │
│    └─ RUN build-base.sh (orchestrator)                      │
│         ├─ Phase 1: Shared utilities                        │
│         ├─ Phase 2: Desktop customizations                  │
│         ├─ Phase 3: Developer tools                         │
│         ├─ Phase 4: User hooks                              │
│         └─ Phase 5: Cleanup                                 │
└─────────────────────────────────────────────────────────────┘
```

### Directory Structure

```
build_files/
├── shared/                    # Cross-cutting utilities
│   ├── build-base.sh         # Main orchestrator (entry point)
│   ├── package-install.sh    # Installs from packages.json
│   ├── cleanup.sh            # Image size optimization
│   ├── branding.sh           # Wallpapers and theming
│   ├── signing.sh            # Container signatures
│   ├── system-services.sh    # Enable systemd services
│   └── utils/                # Reusable utilities
│       ├── validation.sh     # Validation functions
│       ├── github-release-install.sh
│       └── copr-manager.sh
│
├── desktop/                   # Desktop environment customizations
│   ├── gnome-customizations.sh
│   ├── fonts-themes.sh
│   └── dconf-defaults.sh
│
├── developer/                 # Developer tool installations
│   ├── vscode-insiders.sh    # VS Code Insiders RPM
│   ├── action-server.sh      # Robocorp Action Server
│   ├── rcc-cli.sh            # Robocorp RCC CLI
│   └── devcontainer-tools.sh
│
└── user-hooks/                # First-boot user configurations
    ├── 10-wallpaper-enforcement.sh
    ├── 20-vscode-extensions.sh
    └── 99-first-boot-welcome.sh
```

## Build Module Contract

Every Build Module follows a standard contract:

### Required Header

```bash
#!/usr/bin/bash
# Script: module-name.sh
# Purpose: [One-line description]
# Category: [shared|desktop|developer|user-hooks]
# Dependencies: [comma-separated module names, or "none"]
# Parallel-Safe: [yes|no]
# Usage: [How and when called]
# Author: [Maintainer]
# Last Updated: YYYY-MM-DD

set -eoux pipefail
```

### Standard Logging Format

```bash
[MODULE:category/module-name] INFO: START
[MODULE:category/module-name] INFO: Action description
[MODULE:category/module-name] ERROR: Error message
[MODULE:category/module-name] INFO: DONE (duration: Xs)
```

### Exit Codes

- `0`: Success - module completed all operations
- `1`: Error - unrecoverable failure (triggers cleanup)
- `2`: Skipped - module determined it should not run (not an error)

## Build Orchestration

### Discovery Phase

The `build-base.sh` orchestrator:

1. Scans category directories for `*.sh` files
2. Reads module headers to extract metadata
3. Determines execution order based on:
   - Category (shared → desktop → developer → user-hooks)
   - Alphabetical order within category
   - Dependencies (future enhancement)

### Execution Phases

**Phase 1: Shared Utilities**
- Package installation from `packages.json`
- Branding and wallpaper setup
- System service enablement
- Signature configuration

**Phase 2: Desktop Customizations**
- GNOME-specific settings
- Font and theme installations
- dconf default configurations

**Phase 3: Developer Tools**
- VS Code Insiders installation
- Action Server setup
- RCC CLI installation
- DevContainer prerequisites

**Phase 4: User Hooks**
- Scripts installed to `/usr/share/ublue-os/user-setup.hooks.d/`
- Executed on first user login (not during build)
- Run-once semantics via marker files

**Phase 5: Cleanup**
- Package manager cache removal
- Temporary file cleanup
- Log file removal
- COPR repository disabling
- OSTree commit

### Error Handling

On module failure:
1. Log error with context
2. Trigger cleanup.sh to remove partial artifacts
3. Exit with code 1 (build fails)

## Caching Strategy

### BuildKit Mount Types

**Bind Mounts** (`--mount=type=bind`)
- Read-only access to build context
- No copy into final image
- Used for: build scripts, configuration files

**Cache Mounts** (`--mount=type=cache`)
- Persistent across builds
- Shared between concurrent builds (with locking)
- Used for: `/var/cache/dnf5`, `/var/cache/yum`

**Tmpfs Mounts** (`--mount=type=tmpfs`)
- Fast in-memory storage
- Automatically cleaned up
- Used for: `/tmp` during build

### Layer Ordering Strategy

```dockerfile
# Static, infrequently changed layers first
COPY build_files /build_files
COPY packages.json /packages.json

# Dynamic, frequently changed layers last
COPY custom_wallpapers /custom_wallpapers
```

**Cache Hit Optimization**:
- Single file change invalidates only affected layers
- Target: ≥80% cache hit rate for typical changes
- Wallpaper-only changes: <5 minute rebuild (vs 30+ minutes full rebuild)

## Configuration Management

### packages.json Schema

Centralized package management:

```json
{
  "all": {
    "install": ["pkg1", "pkg2"],
    "remove": ["bloat"],
    "copr_repos": ["owner/repo"]
  },
  "41": {
    "install": ["fedora41-specific"],
    "install_overrides": {
      "old-pkg": "new-pkg"
    }
  }
}
```

**Benefits**:
- Single source of truth
- Version control diff clarity
- Programmatic validation
- Conditional package installation by Fedora version

## Validation System

### Three-Tier Validation

**Tier 1: Syntax** (Pre-Build)
- shellcheck for bash scripts
- jq for JSON files
- just format check

**Tier 2: Configuration** (Pre-Build)
- Package configuration schema validation
- Module header completeness
- Dependency verification
- Circular dependency detection

**Tier 3: Integration** (Post-Build)
- Container build success
- Artifact presence verification
- Image size validation (<8GB)
- Functional smoke tests

### Validation Commands

```bash
# Run all validations
just check

# Individual validators
just lint                 # shellcheck
just validate-packages    # JSON schema
just validate-modules     # Module headers
just validate-containerfile  # hadolint (if available)
```

## Performance Characteristics

### Build Times

| Scenario | Target | Actual (varies by system) |
|----------|--------|---------------------------|
| First build | <60 min | 30-60 min |
| Incremental (1 file) | <10 min | 5-10 min |
| Wallpaper-only change | <5 min | 2-5 min |
| Clean rebuild | <60 min | 30-60 min |

### Image Size

- **Target**: <8GB final image
- **Cleanup savings**: ≥10% reduction
- **Monitored via**: `podman images` or validation tests

### Parallel Execution

- **Current**: Sequential execution (simple, predictable)
- **Future**: Parallel execution of independent modules marked `Parallel-Safe: yes`
- **Benefit**: 30-40% faster builds for independent operations

## Failure Recovery

### Automatic Cleanup (FR-022)

On build failure, cleanup.sh removes:
- Incomplete container layers
- Temporary files in `/tmp`
- Downloaded packages in `/var/cache`
- Partial log files

### Base Image Fallback (FR-011)

When base image pull fails:
1. Log warning: "Base image pull failed, using cached image"
2. Use last-known-good base image digest
3. Continue build (non-blocking warning)
4. Update cache on successful pull

## Extension Points

### Adding a New Module

1. Create script in appropriate category directory:
   ```bash
   build_files/category/my-module.sh
   ```

2. Add required header with metadata

3. Make executable: `chmod +x`

4. Validate: `just validate-modules`

5. Test: `just build`

**No code changes needed** - build-base.sh automatically discovers new modules!

### Adding a New Package

1. Edit `packages.json`:
   ```json
   {
     "all": {
       "install": ["new-package"]
     }
   }
   ```

2. Validate: `just validate-packages`

3. Build: `just build`

## Troubleshooting

### Build Fails

1. Check validation: `just check`
2. Review module logs for `[MODULE:*/failed-module] ERROR`
3. Test module in isolation: `bash build_files/category/module.sh`

### Slow Builds

1. Check cache usage: Look for `CACHED` in build output
2. Verify base image not updated: `podman images`
3. Consider `just clean` to reset caches

### Module Not Found

1. Verify file location matches category in header
2. Check script is executable: `ls -l build_files/category/`
3. Run validation: `just validate-modules`

## Security Considerations

1. **No secrets in image**: All credentials via environment/runtime
2. **Signature verification**: cosign.pub for container signatures
3. **Minimal attack surface**: Aggressive cleanup removes build tools
4. **Immutable infrastructure**: OSTree read-only filesystem

## Future Enhancements

1. **Parallel execution**: Implement dependency DAG, execute independent modules concurrently
2. **Conditional builds**: Skip categories based on build args (e.g., `--no-desktop`)
3. **Build profiles**: Different module sets for different use cases
4. **Remote module caching**: CDN-hosted module dependencies
5. **Incremental validation**: Only validate changed modules

## References

- **Build Module Contract**: `specs/001-implement-modular-build/contracts/build-module-contract.md`
- **Validation Contract**: `specs/001-implement-modular-build/contracts/validation-contract.md`
- **Data Model**: `specs/001-implement-modular-build/data-model.md`
- **Implementation Tasks**: `specs/001-implement-modular-build/tasks.md`

---

**Status**: ✅ Architecture implemented and operational
