# Developer Guide: Content-Based Versioning System

**Project**: Dudley's Second Bedroom
**Feature**: Automatic Content-Based Versioning for User Hooks
**Audience**: Developers extending the system with new hooks

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture](#architecture)
3. [When Hooks Run vs Skip](#when-hooks-run-vs-skip)
4. [How Hashes Are Computed](#how-hashes-are-computed)
5. [Build Manifest Structure](#build-manifest-structure)
6. [Creating a New Hook](#creating-a-new-hook)
7. [API Reference](#api-reference)
8. [Common Patterns](#common-patterns)
9. [Testing Your Hook](#testing-your-hook)
10. [Troubleshooting](#troubleshooting)

---

## System Overview

The content-based versioning system eliminates manual version management for user hooks by automatically computing SHA256 hashes of hook scripts and their data dependencies at build time. Hooks only re-execute when their content actually changes.

### Key Benefits

- **Zero manual version updates**: No more bumping version numbers in code
- **Precise change detection**: Hooks run only when dependencies change
- **Build transparency**: Manifest shows exactly what changed and when
- **Developer-friendly**: Simple patterns for adding new hooks

### How It Works

1. **Build Time**: System computes hash of hook script + data files
2. **Build Time**: Hash replaces `__CONTENT_VERSION__` placeholder in hook
3. **Build Time**: Manifest generated with all hook versions and metadata
4. **First Boot**: All hooks execute (no version recorded yet)
5. **Subsequent Boots**: Hooks skip if version unchanged, run if changed
6. **After Update**: Only hooks with changed content re-execute

---

## Architecture

```
Repository Files (Build Context)
        ↓
Content Versioning Utilities (build_files/shared/utils/)
    ├── content-versioning.sh    # Hash computation functions
    ├── manifest-builder.sh       # JSON manifest generation
    └── generate-manifest.sh      # Orchestration script
        ↓
Containerfile (Integration Point)
    ├── Copies utilities to temp location
    ├── Runs generate-manifest.sh
    ├── Replaces __CONTENT_VERSION__ in hooks
    └── Installs manifest to /etc/dudley/
        ↓
Final Image
    ├── /etc/dudley/build-manifest.json (immutable)
    ├── /usr/share/ublue-os/user-setup.hooks.d/*.sh (with versions)
    └── /usr/local/bin/dudley-build-info (CLI tool)
        ↓
User Boot (ublue-user-setup.service)
    ├── Hooks read their embedded version
    ├── version-script checks if version changed
    ├── Hook runs if version changed or first boot
    └── version-script records version after success
```

### Component Responsibilities

| Component | Responsibility | Phase |
|-----------|---------------|-------|
| `content-versioning.sh` | Compute deterministic hashes | Build |
| `manifest-builder.sh` | Construct JSON manifest | Build |
| `generate-manifest.sh` | Orchestrate manifest generation | Build |
| `Containerfile` | Integrate versioning into build | Build |
| Hook scripts | Execute conditional logic | Runtime |
| `version-script` | Track hook execution state | Runtime |
| `show-build-info.sh` | Display build information | Runtime |

---

## When Hooks Run vs Skip

Hooks use Universal Blue's `version-script` function to determine execution:

### Decision Flow

```bash
Hook starts
    ↓
version-script "$HOOK_NAME" "$HOOK_VERSION"
    ↓
Check /etc/ublue/version-script/$HOOK_NAME
    ↓
    ├─ File doesn't exist → return "run" (first boot)
    ├─ File exists, version matches → return "skip" (no changes)
    └─ File exists, version differs → return "run" (content changed)
    ↓
If "run":
    ├─ Execute hook logic
    ├─ Exit with status 0 (success)
    └─ version-script records new version
    ↓
If "skip":
    └─ Exit immediately (logged as skipped)
```

### Version Recording Rules

**Version is recorded ONLY if:**
- Hook completes successfully (exit 0)
- No errors occurred during execution

**Version is NOT recorded if:**
- Hook exits with non-zero status (error)
- Process is killed/interrupted
- System crashes during execution

This ensures automatic retry on failure without manual intervention.

---

## How Hashes Are Computed

### Hash Algorithm

```bash
# For single file
cat hook.sh | sha256sum | cut -c1-8
# Result: "8f7a2c3d"

# For multiple files (deterministic ordering)
cat file1 file2 file3 | sha256sum | cut -c1-8
# Files are sorted before hashing to ensure consistency
```

### Hash Properties

- **Format**: 8 lowercase hexadecimal characters
- **Source**: First 8 chars of SHA256 hash (truncated)
- **Determinism**: Same input always produces same output
- **Collision Risk**: Negligible for <1000 hooks (32-bit space)

### What Influences the Hash

✅ **Included in hash:**
- Hook script contents (including comments, whitespace)
- Data file contents (config files, lists, images, etc.)
- File concatenation order (sorted for determinism)

❌ **NOT included in hash:**
- File modification timestamps
- File permissions
- File paths/names (only contents matter)
- Build environment variables
- Git commit information

### Example Computation

```bash
# Wallpaper hook: script + all wallpaper images
hash=$(compute_content_hash \
    build_files/user-hooks/10-wallpaper-enforcement.sh \
    custom_wallpapers/default.jpg \
    custom_wallpapers/alt.png)
# Result: "1c4e9f2a"

# VS Code hook: script + extensions list
hash=$(compute_content_hash \
    build_files/user-hooks/20-vscode-extensions.sh \
    vscode-extensions.list)
# Result: "8f7a2c3d"

# Welcome hook: script only
hash=$(compute_content_hash \
    build_files/user-hooks/99-first-boot-welcome.sh)
# Result: "5b8d3e1f"
```

---

## Build Manifest Structure

The manifest is a JSON file at `/etc/dudley/build-manifest.json` containing:

### Full Schema

```json
{
  "version": "1.0.0",
  "build": {
    "date": "2025-10-10T14:30:00Z",
    "image": "ghcr.io/joshyorko/dudleys-second-bedroom:latest",
    "base": "ghcr.io/ublue-os/bluefin-dx:stable",
    "commit": "a3f2c1b"
  },
  "hooks": {
    "hook-name": {
      "version": "8f7a2c3d",
      "dependencies": [
        "build_files/user-hooks/20-hook.sh",
        "data-file.list"
      ],
      "metadata": {
        "item_count": 15,
        "changed": true,
        "custom_field": "any value"
      }
    }
  }
}
```

### Field Descriptions

| Field | Type | Description |
|-------|------|-------------|
| `version` | string | Manifest schema version (semver) |
| `build.date` | string | ISO 8601 build timestamp (UTC) |
| `build.image` | string | Full OCI image reference |
| `build.base` | string | Base image reference |
| `build.commit` | string | Git commit SHA (7 or 40 chars) |
| `hooks[name]` | object | Hook metadata entry |
| `hooks[name].version` | string | 8-char content hash |
| `hooks[name].dependencies` | array | File paths used in hash |
| `hooks[name].metadata` | object | Hook-specific data (extensible) |

### Accessing the Manifest

**From command line:**
```bash
# Formatted display
dudley-build-info

# Raw JSON
dudley-build-info --json
cat /etc/dudley/build-manifest.json | jq .
```

**From scripts (runtime):**
```bash
# Check if manifest exists
if [[ -f /etc/dudley/build-manifest.json ]]; then
    # Extract specific field
    version=$(jq -r '.hooks.myHook.version' /etc/dudley/build-manifest.json)

    # Extract metadata
    count=$(jq -r '.hooks.myHook.metadata.item_count' /etc/dudley/build-manifest.json)
fi
```

---

## Creating a New Hook

### Quick Start (5 Minutes)

Follow these steps to add a new hook with automatic versioning:

#### Step 1: Copy the Template

```bash
cd build_files/user-hooks/
cp TEMPLATE-new-hook.sh 30-my-new-hook.sh
```

#### Step 2: Customize the Template

Edit `30-my-new-hook.sh`:

1. Update header documentation (Purpose, Dependencies, Author, Date)
2. Update `MODULE_NAME` variable (line ~47)
3. Update `HOOK_NAME` variable in runtime hook section (line ~73)
4. Update priority number `NN-` to `30-` (line ~91)
5. Implement your hook logic (replace TODO comments)

#### Step 3: Register in Manifest Generator

Edit `build_files/shared/utils/generate-manifest.sh`:

Add before the "Write manifest" section:

```bash
# Compute hash for my-new-hook
echo "[dudley-versioning] Computing hash for my-new-hook..."
MY_HOOK_DEPS=(
    "$PROJECT_ROOT/build_files/user-hooks/30-my-new-hook.sh"
    "$PROJECT_ROOT/data/my-config-file.list"  # If you have data files
)

my_hook_hash=$(compute_content_hash "${MY_HOOK_DEPS[@]}")
my_hook_deps_json=$(printf '%s\n' "${MY_HOOK_DEPS[@]}" | sed "s|$PROJECT_ROOT/||" | jq -R . | jq -s .)
my_hook_meta='{"item_count": 10, "changed": true}'

echo "[dudley-versioning]   Version: $my_hook_hash"
manifest=$(add_hook_to_manifest "$manifest" "my-new-hook" "$my_hook_hash" "$my_hook_deps_json" "$my_hook_meta")
```

#### Step 4: Update Containerfile

Edit `Containerfile` to replace the version placeholder in your new hook:

Find the version replacement section and add:

```dockerfile
replace_version_placeholder /usr/share/ublue-os/user-setup.hooks.d/30-my-new-hook.sh "$MY_HOOK_VERSION" && \
```

Also add to the version export section in generate-manifest.sh:

```bash
echo "MY_HOOK_VERSION=$my_hook_hash"
```

#### Step 5: Test Locally

```bash
# Compute hash manually to verify
source build_files/shared/utils/content-versioning.sh
compute_content_hash build_files/user-hooks/30-my-new-hook.sh data/my-config-file.list

# Build image
just build  # or: podman build -t test .

# Check manifest includes your hook
podman run --rm test cat /etc/dudley/build-manifest.json | jq .hooks.my-new-hook
```

---

## API Reference

### Content Versioning Functions

See: [`contracts/content-versioning-api.md`](../specs/002-implement-automatic-content/contracts/content-versioning-api.md)

**`compute_content_hash <file1> [file2] ...`**
- Computes 8-character SHA256 hash from one or more files
- Returns: Hash string to stdout (exit 0) or error to stderr (exit 1)
- Example: `hash=$(compute_content_hash script.sh data.list)`

**`replace_version_placeholder <file> <hash>`**
- Replaces `__CONTENT_VERSION__` in file with hash
- Returns: Success (exit 0) or error (exit 1)
- Example: `replace_version_placeholder /path/to/hook.sh "8f7a2c3d"`

**`validate_hash_format <hash>`**
- Validates hash is 8 lowercase hex characters
- Returns: exit 0 if valid, exit 1 if invalid
- Example: `if validate_hash_format "$hash"; then echo "valid"; fi`

### Manifest Builder Functions

See: [`contracts/manifest-builder-api.md`](../specs/002-implement-automatic-content/contracts/manifest-builder-api.md)

**`init_manifest <image_name> <base_image> <commit_sha>`**
- Initializes manifest structure with build metadata
- Returns: JSON string to stdout
- Example: `manifest=$(init_manifest "$IMAGE_NAME" "$BASE_IMAGE" "$GIT_COMMIT")`

**`add_hook_to_manifest <manifest_json> <hook_name> <version_hash> <dependencies_json> [metadata_json]`**
- Adds hook entry to manifest
- Returns: Updated manifest JSON to stdout
- Example: `manifest=$(add_hook_to_manifest "$manifest" "my-hook" "$hash" "$deps" "$meta")`

**`write_manifest <manifest_json> <output_path>`**
- Writes manifest to file with validation
- Returns: exit 0 on success, exit 1 on failure
- Example: `write_manifest "$manifest" "/etc/dudley/build-manifest.json"`

**`validate_manifest_schema <manifest_json>`**
- Validates manifest against schema
- Returns: exit 0 if valid, exit 1 with errors to stderr
- Example: `if validate_manifest_schema "$manifest"; then echo "valid"; fi`

---

## Common Patterns

### Pattern 1: Script-Only Hook (No Data Dependencies)

**Use case**: Hook behavior is entirely in the script (e.g., welcome message)

```bash
# In generate-manifest.sh
welcome_hash=$(compute_content_hash "$PROJECT_ROOT/build_files/user-hooks/99-welcome.sh")
welcome_deps='["build_files/user-hooks/99-welcome.sh"]'
welcome_meta='{"changed": true}'

manifest=$(add_hook_to_manifest "$manifest" "welcome" "$welcome_hash" "$welcome_deps" "$welcome_meta")
```

**Triggers re-execution when**: Script content changes

---

### Pattern 2: Script + Single Data File

**Use case**: Hook processes a configuration file (e.g., VS Code extensions list)

```bash
# In generate-manifest.sh
VSCODE_DEPS=(
    "$PROJECT_ROOT/build_files/user-hooks/20-vscode-extensions.sh"
    "$PROJECT_ROOT/vscode-extensions.list"
)

vscode_hash=$(compute_content_hash "${VSCODE_DEPS[@]}")
vscode_deps_json=$(printf '%s\n' "${VSCODE_DEPS[@]}" | sed "s|$PROJECT_ROOT/||" | jq -R . | jq -s .)

# Add useful metadata
extension_count=$(grep -v '^\s*#' "$PROJECT_ROOT/vscode-extensions.list" | grep -v '^\s*$' | wc -l)
vscode_meta=$(printf '{"extension_count": %d, "changed": true}' "$extension_count")

manifest=$(add_hook_to_manifest "$manifest" "vscode-extensions" "$vscode_hash" "$vscode_deps_json" "$vscode_meta")
```

**Triggers re-execution when**: Script OR list file changes

---

### Pattern 3: Script + Multiple Related Files

**Use case**: Hook processes multiple files of same type (e.g., wallpaper images)

```bash
# In generate-manifest.sh
WALLPAPER_DEPS=(
    "$PROJECT_ROOT/build_files/user-hooks/10-wallpaper.sh"
)

# Add all wallpaper files
WALLPAPER_COUNT=0
if compgen -G "$PROJECT_ROOT/custom_wallpapers/*" > /dev/null; then
    mapfile -t WALLPAPER_FILES < <(find "$PROJECT_ROOT/custom_wallpapers" -type f | sort)
    WALLPAPER_DEPS+=("${WALLPAPER_FILES[@]}")
    WALLPAPER_COUNT=${#WALLPAPER_FILES[@]}
fi

wallpaper_hash=$(compute_content_hash "${WALLPAPER_DEPS[@]}")
wallpaper_deps_json=$(printf '%s\n' "${WALLPAPER_DEPS[@]}" | sed "s|$PROJECT_ROOT/||" | jq -R . | jq -s .)
wallpaper_meta=$(printf '{"wallpaper_count": %d, "changed": true}' "$WALLPAPER_COUNT")

manifest=$(add_hook_to_manifest "$manifest" "wallpaper" "$wallpaper_hash" "$wallpaper_deps_json" "$wallpaper_meta")
```

**Triggers re-execution when**: Script OR any wallpaper file changes (add/remove/modify)

---

### Pattern 4: Script + Scattered Configuration Files

**Use case**: Hook depends on multiple config files in different locations

```bash
# In generate-manifest.sh
COMPLEX_DEPS=(
    "$PROJECT_ROOT/build_files/user-hooks/50-complex.sh"
    "$PROJECT_ROOT/config/database.yaml"
    "$PROJECT_ROOT/config/api-keys.json"
    "$PROJECT_ROOT/templates/email.html"
    "$PROJECT_ROOT/data/seed-data.csv"
)

complex_hash=$(compute_content_hash "${COMPLEX_DEPS[@]}")
complex_deps_json=$(printf '%s\n' "${COMPLEX_DEPS[@]}" | sed "s|$PROJECT_ROOT/||" | jq -R . | jq -s .)
complex_meta='{"config_files": 4, "changed": true}'

manifest=$(add_hook_to_manifest "$manifest" "complex" "$complex_hash" "$complex_deps_json" "$complex_meta")
```

**Triggers re-execution when**: Script OR any configuration file changes

---

## Testing Your Hook

### Local Testing Workflow

```bash
# 1. Syntax check
bash -n build_files/user-hooks/30-my-hook.sh

# 2. Manual hash computation
source build_files/shared/utils/content-versioning.sh
hash=$(compute_content_hash build_files/user-hooks/30-my-hook.sh data.list)
echo "Computed hash: $hash"

# 3. Test manifest generation
bash build_files/shared/utils/generate-manifest.sh
cat /etc/dudley/build-manifest.json | jq .hooks.my-hook

# 4. Build test image
podman build -t test-hook .

# 5. Verify hook installed and version replaced
podman run --rm test-hook cat /usr/share/ublue-os/user-setup.hooks.d/30-my-hook.sh | grep __CONTENT_VERSION__
# Should return nothing (empty) - placeholder was replaced

# 6. Check manifest
podman run --rm test-hook cat /etc/dudley/build-manifest.json | jq .

# 7. Test hook execution (interactive)
podman run --rm -it test-hook bash
# Inside container:
bash /usr/share/ublue-os/user-setup.hooks.d/30-my-hook.sh
# Should execute and log "starting" and "completed" messages
```

### Integration Testing

```bash
# Run test suite
bash tests/run-all-tests.sh

# Run specific test
bash tests/test-hook-integration.sh

# Check logs after boot (on real system)
journalctl -u ublue-user-setup.service | grep "my-hook"
```

### Expected Behaviors to Verify

1. ✅ **First boot**: Hook executes, logs "starting" and "completed"
2. ✅ **Second boot (no changes)**: Hook logs "skipping"
3. ✅ **After changing data file**: Hook executes again
4. ✅ **After changing script**: Hook executes again
5. ✅ **Manifest contains hook**: `jq .hooks.my-hook` shows entry
6. ✅ **No placeholder remains**: `grep __CONTENT_VERSION__` returns nothing
7. ✅ **Version file created**: `/etc/ublue/version-script/my-hook` exists after first run

---

## Troubleshooting

### Hook Runs Every Boot (Should Skip)

**Symptoms**: Hook always shows "run" despite no changes

**Possible causes**:
1. `__CONTENT_VERSION__` placeholder not replaced
2. Hook not added to Containerfile version replacement section
3. Version file being deleted (unlikely)

**Debug steps**:
```bash
# Check if placeholder was replaced
grep __CONTENT_VERSION__ /usr/share/ublue-os/user-setup.hooks.d/30-my-hook.sh
# Should return nothing

# Check version file exists
ls -la /etc/ublue/version-script/my-hook
# Should exist after first run

# Check hash determinism
compute_content_hash file1 file2
compute_content_hash file1 file2
# Should be identical
```

---

### Hook Never Runs (Always Skips)

**Symptoms**: Hook skips even on first boot or after changes

**Possible causes**:
1. Version file already exists with matching version
2. Hook exits before version check
3. Script syntax error

**Debug steps**:
```bash
# Force re-run by deleting version file
sudo rm /etc/ublue/version-script/my-hook

# Check script syntax
bash -n /usr/share/ublue-os/user-setup.hooks.d/30-my-hook.sh

# Run hook manually with debug output
bash -x /usr/share/ublue-os/user-setup.hooks.d/30-my-hook.sh
```

---

### Build Fails: Hash Computation Error

**Symptoms**: `compute_content_hash` exits with error during build

**Possible causes**:
1. Dependency file doesn't exist
2. File path typo
3. Glob pattern matches no files

**Debug steps**:
```bash
# Check files exist
ls -la build_files/user-hooks/30-my-hook.sh
ls -la data/my-config-file.list

# Test glob pattern
echo custom_wallpapers/*.jpg
# Should show file paths, not literal "*.jpg"

# Test hash computation manually
source build_files/shared/utils/content-versioning.sh
compute_content_hash build_files/user-hooks/30-my-hook.sh
```

---

### Manifest Missing or Invalid

**Symptoms**: `dudley-build-info` fails, welcome hook errors

**Possible causes**:
1. Manifest not generated during build
2. Invalid JSON produced
3. Schema validation failed

**Debug steps**:
```bash
# Check manifest exists
ls -la /etc/dudley/build-manifest.json

# Validate JSON syntax
jq . /etc/dudley/build-manifest.json

# Validate against schema
bash build_files/shared/utils/manifest-builder.sh
# Then run validate_manifest_schema

# Check build logs
journalctl -b | grep dudley-versioning
```

---

### Hook Fails But Version Still Recorded

**Symptoms**: Hook encounters error but doesn't re-run next boot

**Cause**: Hook exits with status 0 despite error

**Fix**: Use proper error handling:

```bash
# WRONG - version recorded even if command fails
some-critical-command || echo "Warning: failed"
# Script exits 0, version recorded

# CORRECT - prevent version recording on failure
some-critical-command || exit 1
# Script exits 1, version NOT recorded, retry next boot
```

---

## Building with Custom Base Images

You can override the default base image (`ghcr.io/ublue-os/bluefin-dx:stable`) to test against other Universal Blue images (e.g., Aurora, Bazzite) or different tags.

### Local Build

Use the `BASE_IMAGE` environment variable:

```bash
# Build with Aurora DX
BASE_IMAGE="ghcr.io/ublue-os/aurora-dx:stable" just build

# Build with Bazzite
BASE_IMAGE="ghcr.io/ublue-os/bazzite:latest" just build
```

### CI/CD Build

The GitHub Actions workflow accepts a `base_image` input:

1. Go to **Actions** > **Build container image**.
2. Click **Run workflow**.
3. Enter the image reference in **Base image**.
4. Click **Run workflow**.

---

## Supply Chain Security

The build system includes comprehensive supply chain security features that ensure image integrity and traceability.

### Overview

Every production image built from the `main` branch includes:

- **SBOM (SPDX JSON)**: Complete software bill of materials
- **SLSA Provenance**: Build attestation with Git SHA and workflow context
- **Build Metadata**: Archived specs, docs, and build_files as OCI artifact
- **Dual Signatures**: Both key-based and keyless (OIDC) signatures

### Verifying Images

**Quick verification commands:**

```bash
# Key-based signature verification
cosign verify --key cosign.pub ghcr.io/joshyorko/dudleys-second-bedroom:latest

# Keyless (OIDC) verification
cosign verify \
  --certificate-identity-regexp "https://github.com/joshyorko/dudleys-second-bedroom/.github/workflows/build.yml@refs/heads/main" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  ghcr.io/joshyorko/dudleys-second-bedroom:latest

# Download and inspect SBOM
cosign download sbom ghcr.io/joshyorko/dudleys-second-bedroom:latest | jq .

# Verify provenance attestation
cosign verify-attestation --type slsaprovenance --key cosign.pub \
  ghcr.io/joshyorko/dudleys-second-bedroom:latest
```

### Accessing Build Metadata

Each image has associated metadata (specs, docs, build_files) stored as an OCI artifact:

```bash
# Get image digest
DIGEST=$(skopeo inspect docker://ghcr.io/joshyorko/dudleys-second-bedroom:latest | jq -r .Digest | cut -d: -f2)

# Pull metadata artifact
oras pull "ghcr.io/joshyorko/dudleys-second-bedroom:sha256-${DIGEST}.metadata"

# Extract and inspect
tar -xzf metadata.tar.gz
ls -la specs/ docs/ build_files/
```

### Verification Script

Use the project's verification script for comprehensive checks:

```bash
# Run all verification checks
./tests/verify-supply-chain.sh verify-all ghcr.io/joshyorko/dudleys-second-bedroom:latest

# Individual checks
./tests/verify-supply-chain.sh verify-sbom <image-ref>
./tests/verify-supply-chain.sh verify-provenance <image-ref>
./tests/verify-supply-chain.sh verify-metadata <image-ref>
./tests/verify-supply-chain.sh verify-signature-key <image-ref> cosign.pub
./tests/verify-supply-chain.sh verify-signature-oidc <image-ref>
```

### Enforcing Signature Policy

For system administrators who want to enforce signature verification:

See [docs/SIGNATURE-VERIFICATION.md](./SIGNATURE-VERIFICATION.md) for:
- Policy configuration examples
- registries.d setup
- bootc switch verification

### CI/CD Integration

The supply chain artifacts are generated in `.github/workflows/build.yml`:

1. **SBOM Generation**: Uses `trivy` to generate SPDX JSON (faster than syft for large images)
2. **SBOM Attachment**: `cosign attach sbom` links SBOM to image
3. **Provenance**: SLSA v0.2 predicate with build context
4. **Attestation**: `cosign attest` creates signed provenance
5. **Metadata**: `oras push` stores build files as OCI artifact
6. **Dual Signing**: Both key-based and keyless signatures

All supply chain steps are conditional on:
- Running on the default branch (main)
- Not being a pull request

---

## Additional Resources

### Documentation

- **Quickstart Guide**: [`specs/002-implement-automatic-content/quickstart.md`](../specs/002-implement-automatic-content/quickstart.md)
- **API Contracts**: [`specs/002-implement-automatic-content/contracts/`](../specs/002-implement-automatic-content/contracts/)
- **Data Model**: [`specs/002-implement-automatic-content/data-model.md`](../specs/002-implement-automatic-content/data-model.md)
- **Research Notes**: [`specs/002-implement-automatic-content/research.md`](../specs/002-implement-automatic-content/research.md)

### External Resources

- [Universal Blue Documentation](https://universal-blue.org/)
- [Universal Blue Setup Services](https://github.com/ublue-os/bluefin/tree/main/usr/share/ublue-os)
- [Bash Best Practices](https://mywiki.wooledge.org/BashGuide)
- [JSON Schema Validation](https://json-schema.org/)

### Getting Help

- **Universal Blue Forums**: https://universal-blue.discourse.group/
- **Universal Blue Discord**: https://discord.gg/WEu6BdFEtp
- **Project Repository**: https://github.com/joshyorko/dudleys-second-bedroom

---

## Summary

The content-based versioning system provides:

✅ **Automatic version management** - No manual updates needed
✅ **Precise change detection** - Hooks run only when needed
✅ **Build transparency** - Clear visibility into what changed
✅ **Developer-friendly patterns** - Simple to extend with new hooks
✅ **Fail-safe behavior** - Automatic retry on errors

By following the patterns in this guide, you can create robust user hooks that integrate seamlessly with the versioning system.
