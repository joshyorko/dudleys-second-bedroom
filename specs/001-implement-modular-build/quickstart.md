# Quickstart: Modular Build System

**Feature**: Modular Build Architecture  
**Target Audience**: Developers and maintainers  
**Time to Complete**: 5-10 minutes

## Prerequisites

Ensure you have these tools installed:
- `podman` or `docker` (container runtime)
- `just` (command runner) - Install: `curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to ~/.local/bin`
- `jq` (JSON processor)
- `shellcheck` (shell script linter)
- `git` (version control)

```bash
# Verify prerequisites
podman --version || docker --version
just --version
jq --version
shellcheck --version
git --version
```

## Quick Start

### 1. Clone and Setup (1 minute)

```bash
# Clone the repository
git clone https://github.com/joshyorko/dudleys-second-bedroom.git
cd dudleys-second-bedroom

# Checkout the feature branch
git checkout 001-implement-modular-build

# View available commands
just --list
```

Expected output:
```
Available recipes:
    build         # Build container image
    check         # Run all validation checks
    clean         # Clean build artifacts
    lint          # Lint shell scripts
    test          # Run tests
    ...
```

### 2. Validate Configuration (1 minute)

Before making any changes, validate the current configuration:

```bash
# Run all validation checks
just check
```

Expected output:
```
✓ Shell scripts pass shellcheck
✓ JSON files are valid
✓ Justfile is properly formatted
✓ Package configuration valid
✓ Module metadata valid
All validation checks passed!
```

If you see errors, fix them before proceeding.

### 3. Explore the Structure (2 minutes)

```bash
# View the modular build structure
tree build_files/

build_files/
├── shared/              # Cross-cutting utilities
│   ├── build-base.sh   # Main orchestrator
│   ├── cleanup.sh      # Aggressive cleanup
│   ├── package-install.sh
│   └── utils/
├── desktop/             # Desktop customizations
│   ├── gnome-customizations.sh
│   └── fonts-themes.sh
├── developer/           # Developer tools
│   ├── vscode-insiders.sh
│   └── action-server.sh
└── user-hooks/          # First-boot user configs
    └── 99-first-boot-welcome.sh
```

### 4. Make a Simple Change (2 minutes)

Let's add a package to the configuration:

```bash
# Edit the package configuration
nano packages.json  # or your preferred editor

# Add a package to the "all" install list
# For example, add "neofetch" to the install array:
{
  "all": {
    "install": [
      "existing-package-1",
      "existing-package-2",
      "neofetch"  // Add this line
    ],
    ...
  }
}
```

Validate your change:
```bash
just validate-packages
```

Expected output:
```
✓ Package configuration valid
No duplicates found
No conflicts found
```

### 5. Build the Image (30-60 minutes first time, < 10 minutes incremental)

```bash
# Build with caching (recommended)
just build

# Or build without cache (clean build)
just rebuild

# Monitor the build progress - you'll see module execution logs:
# [MODULE:shared/package-install] START
# [MODULE:shared/package-install] Installing 45 packages...
# [MODULE:shared/package-install] DONE (duration: 120s)
```

**Note**: First build takes 30-60 minutes due to package downloads. Subsequent builds with cache are much faster (< 10 minutes for small changes).

### 6. Test the Built Image (2 minutes)

```bash
# Run smoke tests
just test

# Verify your package was installed
podman run --rm localhost/dudleys-second-bedroom:latest rpm -q neofetch
```

Expected output:
```
neofetch-7.x.x-x.fc41.noarch
```

### 7. Clean Up (< 1 minute)

```bash
# Remove build artifacts
just clean

# Deep clean (includes images)
just deep-clean
```

## Common Workflows

### Adding a New Build Module

1. Create the script in the appropriate category:
```bash
nano build_files/desktop/my-new-module.sh
```

2. Add the required header:
```bash
#!/usr/bin/bash
# Script: my-new-module.sh
# Purpose: Description of what this does
# Category: desktop
# Dependencies: none
# Parallel-Safe: yes
# Usage: Called by build-base.sh during base stage
# Author: Your Name
# Last Updated: 2025-10-05

set -eoux pipefail

echo "[MODULE:desktop/my-new-module] START"
# Your code here
echo "[MODULE:desktop/my-new-module] DONE"
```

3. Make it executable:
```bash
chmod +x build_files/desktop/my-new-module.sh
```

4. Validate:
```bash
just lint
just validate-modules
```

5. Test by building:
```bash
just build
```

### Modifying Package Configuration

1. Edit `packages.json`:
```bash
nano packages.json
```

2. Add/remove packages in the appropriate section:
```json
{
  "all": {
    "install": ["package-to-add"],
    "remove": ["package-to-remove"]
  }
}
```

3. Validate:
```bash
just validate-packages
```

4. Build and test:
```bash
just build
just test
```

### Testing Changes Locally

```bash
# Fast iteration cycle:
just check      # Validate (< 10 seconds)
just build      # Build with cache (< 10 minutes for small changes)
just test       # Smoke tests (< 1 minute)
```

### Debugging Build Failures

1. Check validation first:
```bash
just check
```

2. Look at the build logs for the failing module:
```
[MODULE:category/module-name] ERROR: Description
```

3. Test the module in isolation (if possible):
```bash
bash -x build_files/category/module-name.sh
```

4. Fix the issue and rebuild:
```bash
just clean
just build
```

## Validation Reference

### Pre-Build Validation
```bash
# Run all checks
just check

# Individual checks
just lint                 # Shell script linting
just validate-packages    # Package config validation
just validate-modules     # Module metadata validation
```

### Expected Validation Output

**Success**:
```
✓ All checks passed
Ready to build
```

**Errors** (blocks build):
```
ERROR: Syntax error in build_files/desktop/module.sh
  → Line 45: Unmatched quote
  → Fix: Add closing quote
FAILED: Build cannot proceed
```

**Warnings** (allows build with --force):
```
WARNING: Large package count (487 packages)
  → Consider splitting into categories
Build can proceed with: just build --force
```

## Performance Expectations

### Build Times
- **First build**: 30-60 minutes (downloading packages, no cache)
- **Incremental build** (1 file changed): < 10 minutes (with cache)
- **Wallpaper-only change**: < 5 minutes (most layers cached)
- **Clean rebuild**: 30-60 minutes (cache invalidated)

### Cache Hit Rates
- **Target**: ≥ 80% of layers cached for single-file changes
- **Reality**: Varies by what changed
- **Best case**: 90%+ (only final layers rebuild)
- **Worst case**: 0% (base image updated or full rebuild)

### Image Size
- **Target**: < 8 GB final image
- **Reduction goal**: ≥ 10% from aggressive cleanup
- **Check current size**: `podman images localhost/dudleys-second-bedroom`

## Troubleshooting

### Build Fails with "Module Not Found"
**Cause**: Dependency declared but module doesn't exist  
**Fix**: Check module name in Dependencies: header matches actual file

### Build Fails with "Validation Error"
**Cause**: Configuration file has syntax or semantic error  
**Fix**: Run `just check` to see specific error, fix the issue

### Build Takes Forever
**Cause**: Cache not being used or many packages changed  
**Fix**: Check if base image updated, consider `just clean` and rebuild

### "Permission Denied" Errors
**Cause**: Script not executable  
**Fix**: `chmod +x build_files/category/module-name.sh`

### Package Installation Fails
**Cause**: Package name wrong or not in Fedora repos  
**Fix**: Verify package name with `dnf search package-name`

## Next Steps

After completing this quickstart:

1. **Read the contracts**: Understand module and validation contracts
   - `specs/001-implement-modular-build/contracts/build-module-contract.md`
   - `specs/001-implement-modular-build/contracts/validation-contract.md`

2. **Review the research**: Understand technical decisions
   - `specs/001-implement-modular-build/research.md`

3. **Explore the data model**: Understand the system entities
   - `specs/001-implement-modular-build/data-model.md`

4. **Start implementing**: Follow the tasks in tasks.md (created by /tasks command)

## Getting Help

- **Issues**: https://github.com/joshyorko/dudleys-second-bedroom/issues
- **Discussions**: https://github.com/joshyorko/dudleys-second-bedroom/discussions
- **Universal Blue**: https://universal-blue.discourse.group/

## Success Checklist

You've successfully completed the quickstart when you can:
- ✅ Run `just check` without errors
- ✅ Build the image with `just build`
- ✅ Add a package and rebuild successfully
- ✅ Understand the modular directory structure
- ✅ Know how to validate changes before building
- ✅ Know where to find more documentation

---

**Status**: ✅ Ready to start development
