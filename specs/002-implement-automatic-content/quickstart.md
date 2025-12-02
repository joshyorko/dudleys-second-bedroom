# Quickstart Guide: Content-Based Versioning

**Feature**: 002-implement-automatic-content
**Audience**: Developers adding new hooks or modifying existing ones
**Date**: 2025-10-10

## Overview

This guide shows you how to add content-based versioning to user hooks in 5 minutes. No manual version management required—the system automatically tracks changes and re-runs hooks only when content changes.

---

## For Existing Hook Developers

### Step 1: Add Version Placeholder to Your Hook

Open your hook script (e.g., `build_files/user-hooks/30-my-hook.sh`) and modify the version-script call:

**Before:**
```bash
#!/usr/bin/env bash
set -euo pipefail

source /usr/lib/ublue/setup-services/libsetup.sh

# Manual version - requires updating every change!
if [[ "$(version-script my-hook 1.0.5)" == "run" ]]; then
    echo "Running my hook..."
    # Your logic here
fi
```

**After:**
```bash
#!/usr/bin/env bash
set -euo pipefail

source /usr/lib/ublue/setup-services/libsetup.sh

# Automatic version - replaced at build time!
if [[ "$(version-script my-hook __CONTENT_VERSION__)" == "run" ]]; then
    echo "Running my hook..."
    # Your logic here
fi
```

**What changed**: Replace your hardcoded version number with the literal string `__CONTENT_VERSION__`.

---

### Step 2: Register Your Hook in the Manifest Generator

Edit the manifest generation script (you'll create this in implementation, typically `build_files/shared/utils/generate-manifest.sh`):

```bash
# Add your hook to the manifest generation
my_hook_hash=$(compute_content_hash \
    "build_files/user-hooks/30-my-hook.sh" \
    "my-data-file.list")

my_hook_deps='["build_files/user-hooks/30-my-hook.sh", "my-data-file.list"]'
my_hook_meta='{"item_count": 10, "changed": true}'

manifest=$(add_hook_to_manifest "$manifest" \
    "my-hook" "$my_hook_hash" "$my_hook_deps" "$my_hook_meta")
```

**Key points**:
- Include your hook script + all data files it depends on
- Metadata is optional but useful for welcome message display
- Hook name should match what you use in `version-script`

---

### Step 3: Test Locally

```bash
# Compute hash manually to verify
source build_files/shared/utils/content-versioning.sh
compute_content_hash "build_files/user-hooks/30-my-hook.sh" "my-data-file.list"
# Output: "a1b2c3d4"

# Build image and check manifest
just build
podman run --rm your-image:latest cat /etc/dudley/build-manifest.json | jq .hooks.my-hook
# Should show your hook with computed version
```

---

### Step 4: Verify Hook Behavior

After building:

1. **First boot**: Your hook should run (no version recorded yet)
2. **Second boot (no changes)**: Hook should skip
3. **Third boot (after modifying data file)**: Hook should run again

Check logs:
```bash
journalctl -u ublue-user-setup.service | grep "my-hook"
```

---

## For New Hook Developers

### Template Hook Script

Create `build_files/user-hooks/40-my-new-hook.sh`:

```bash
#!/usr/bin/env bash

#
# Purpose: Brief description of what this hook does
# Dependencies: List of files this hook reads/modifies
# Author: Your Name
# Date: 2025-10-10
#

set -euo pipefail

# Source Universal Blue setup library
source /usr/lib/ublue/setup-services/libsetup.sh

# Content-based version (replaced at build time)
HOOK_NAME="my-new-hook"
HOOK_VERSION="__CONTENT_VERSION__"

# Check if hook should run
if [[ "$(version-script "$HOOK_NAME" "$HOOK_VERSION")" == "skip" ]]; then
    echo "Dudley Hook: $HOOK_NAME already at version $HOOK_VERSION, skipping"
    exit 0
fi

# Log start
echo "Dudley Hook: $HOOK_NAME starting (version $HOOK_VERSION)"

# Your hook logic here
# Example: Install something, configure something, etc.

# Log completion
echo "Dudley Hook: $HOOK_NAME completed successfully"

# Version is automatically recorded by version-script after successful exit
```

---

### Register in Manifest Generator

Add to the manifest generation script:

```bash
# New hook registration
new_hook_hash=$(compute_content_hash \
    "build_files/user-hooks/40-my-new-hook.sh" \
    "config/my-new-hook-config.yaml")

new_hook_deps='["build_files/user-hooks/40-my-new-hook.sh", "config/my-new-hook-config.yaml"]'
new_hook_meta='{"config_items": 5, "changed": true}'

manifest=$(add_hook_to_manifest "$manifest" \
    "my-new-hook" "$new_hook_hash" "$new_hook_deps" "$new_hook_meta")
```

---

### Make Hook Executable

```bash
chmod +x build_files/user-hooks/40-my-new-hook.sh
```

---

### Add to Containerfile

Ensure your hook is copied to the correct location in the `Containerfile`:

```dockerfile
# Copy user hooks (including your new one)
COPY build_files/user-hooks/*.sh /usr/share/ublue-os/user-setup.hooks.d/
RUN chmod +x /usr/share/ublue-os/user-setup.hooks.d/*.sh
```

---

## Common Patterns

### Pattern 1: Single Data File Dependency

**Use case**: Hook processes a single configuration file (e.g., package list).

```bash
# Hash computation
hash=$(compute_content_hash \
    "build_files/user-hooks/20-hook.sh" \
    "config.list")

# Dependencies JSON
deps='["build_files/user-hooks/20-hook.sh", "config.list"]'
```

**Result**: Hook re-runs when either script or config changes.

---

### Pattern 2: Multiple File Dependencies

**Use case**: Hook processes multiple related files (e.g., wallpapers).

```bash
# Hash computation (glob expansion)
hash=$(compute_content_hash \
    "build_files/user-hooks/10-wallpaper.sh" \
    wallpapers/*.jpg \
    wallpapers/*.png)

# Dependencies JSON (convert file list to JSON array)
deps=$(printf '%s\n' "build_files/user-hooks/10-wallpaper.sh" wallpapers/*.{jpg,png} | jq -R . | jq -s .)
```

**Result**: Hook re-runs when script changes OR any wallpaper file changes.

---

### Pattern 3: Script-Only Dependency

**Use case**: Hook has no external data files (e.g., welcome message).

```bash
# Hash computation
hash=$(compute_content_hash "build_files/user-hooks/99-welcome.sh")

# Dependencies JSON
deps='["build_files/user-hooks/99-welcome.sh"]'
```

**Result**: Hook re-runs only when its script logic changes.

---

### Pattern 4: Complex Dependencies

**Use case**: Hook depends on multiple scattered files.

```bash
# List all dependencies explicitly
deps_array=(
    "build_files/user-hooks/50-complex.sh"
    "config/database.yaml"
    "config/api-keys.json"
    "templates/email.html"
)

# Hash computation
hash=$(compute_content_hash "${deps_array[@]}")

# Dependencies JSON
deps=$(printf '%s\n' "${deps_array[@]}" | jq -R . | jq -s .)
```

**Result**: Hook re-runs when ANY dependency changes.

---

## Metadata Best Practices

### Useful Metadata Fields

```json
{
  "item_count": 15,           // Number of items processed (extensions, packages, etc.)
  "changed": true,            // Did version change from previous build?
  "description": "VS Code extensions", // Human-readable description
  "runtime_seconds": 12       // Expected runtime (optional, for future use)
}
```

### Computing "changed" Flag

```bash
# In manifest generator (requires tracking previous build)
previous_hash="8f7a2c3d"  # Retrieved from previous manifest or git
current_hash=$(compute_content_hash ...)

if [[ "$previous_hash" != "$current_hash" ]]; then
    changed="true"
else
    changed="false"
fi

metadata="{\"item_count\": $count, \"changed\": $changed}"
```

---

## Troubleshooting

### Issue: Hook Runs Every Boot

**Symptoms**: Hook always shows "run" despite no changes.

**Likely causes**:
1. `__CONTENT_VERSION__` placeholder not replaced
2. Hash computation includes non-deterministic input (timestamps, etc.)
3. Version file being deleted on boot

**Debugging**:
```bash
# Check if placeholder was replaced
grep __CONTENT_VERSION__ /usr/share/ublue-os/user-setup.hooks.d/my-hook.sh
# Should return nothing (empty)

# Check version file
ls -la /etc/ublue/version-script/my-hook
# Should exist after first successful run

# Check hash determinism
compute_content_hash file1 file2
compute_content_hash file1 file2
# Should be identical
```

---

### Issue: Hook Never Runs

**Symptoms**: Hook skips even on first boot or after changes.

**Likely causes**:
1. Version file already exists with matching version
2. Hook script has syntax error (exits before version check)
3. version-script function not sourced

**Debugging**:
```bash
# Check version file
cat /etc/ublue/version-script/my-hook
# Delete to force re-run: rm /etc/ublue/version-script/my-hook

# Test hook script syntax
bash -n /usr/share/ublue-os/user-setup.hooks.d/my-hook.sh

# Check if library sourced
grep "source.*libsetup.sh" /usr/share/ublue-os/user-setup.hooks.d/my-hook.sh
```

---

### Issue: Build Fails During Hash Computation

**Symptoms**: `compute_content_hash` exits with error.

**Likely causes**:
1. Dependency file doesn't exist
2. File path typo
3. Glob pattern matches no files

**Debugging**:
```bash
# Check file existence
ls -la build_files/user-hooks/my-hook.sh
ls -la my-data-file.list

# Check glob expansion
echo custom_wallpapers/*.jpg
# Should show file paths, not literal "*.jpg"

# Validate in build script
if ! compute_content_hash "$file1" "$file2"; then
    echo "ERROR: Hash computation failed for my-hook"
    exit 1
fi
```

---

### Issue: Manifest Missing or Corrupted

**Symptoms**: Welcome hook can't read manifest, or `jq` errors.

**Likely causes**:
1. Manifest not copied to `/etc/dudley/`
2. Invalid JSON generated
3. Permissions issue

**Debugging**:
```bash
# Check manifest exists
ls -la /etc/dudley/build-manifest.json

# Validate JSON
jq . /etc/dudley/build-manifest.json

# Check permissions
# Should be: -rw-r--r-- (644)

# Test manifest from build context
just build
podman run --rm your-image:latest cat /etc/dudley/build-manifest.json | jq .
```

---

## Quick Reference

### Functions Available

From `content-versioning.sh`:
- `compute_content_hash <file1> [file2] ...` → Returns 8-char hash
- `replace_version_placeholder <file> <hash>` → Updates file in place
- `validate_hash_format <hash>` → Validates hash format (exit 0/1)

From `manifest-builder.sh`:
- `init_manifest <image> <base> <commit>` → Returns initial manifest JSON
- `add_hook_to_manifest <manifest> <name> <hash> <deps> [meta]` → Returns updated manifest
- `write_manifest <manifest> <path>` → Writes manifest to file
- `validate_manifest_schema <manifest>` → Validates manifest (exit 0/1)

### File Locations

- Hook scripts: `build_files/user-hooks/*.sh`
- Utilities: `build_files/shared/utils/*.sh`
- Runtime hooks: `/usr/share/ublue-os/user-setup.hooks.d/*.sh`
- Build manifest: `/etc/dudley/build-manifest.json`
- Version tracking: `/etc/ublue/version-script/<hook-name>`

### Testing Checklist

- [ ] Hook script has `__CONTENT_VERSION__` placeholder
- [ ] Hook registered in manifest generator
- [ ] All dependency files exist
- [ ] Hash computation succeeds
- [ ] Build completes successfully
- [ ] Manifest contains hook entry
- [ ] Hook runs on first boot
- [ ] Hook skips on second boot (no changes)
- [ ] Hook runs again after changing dependency
- [ ] Logs show correct hook name and version

---

## Next Steps

After implementing your hook with content versioning:

1. **Add tests** to `tests/test-hook-integration.sh`
2. **Update documentation** if hook provides user-facing features
3. **Consider metadata** for the welcome message display
4. **Monitor logs** on first deployment to verify behavior

**Questions?** See `contracts/content-versioning-api.md` and `contracts/manifest-builder-api.md` for complete API documentation.
