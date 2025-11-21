# Utility Function Contract: Manifest Builder

**Module**: `build_files/shared/utils/manifest-builder.sh`  
**Purpose**: Generate build manifest JSON file with all hook versions and build metadata  
**Date**: 2025-10-10

## Overview

This module provides functions to construct and write the build manifest JSON file. Used during container build process after all content hashes have been computed.

---

## Function: `init_manifest`

### Purpose
Initialize a new manifest structure with build metadata.

### Signature
```bash
init_manifest <image_name> <base_image> <commit_sha>
```

### Parameters
- `image_name` (required): Full OCI image reference with tag (e.g., `ghcr.io/owner/repo:tag`)
- `base_image` (required): Base image reference
- `commit_sha` (required): Git commit SHA (7 or 40 characters)

### Return Value
- **Success (exit 0)**: Prints initial manifest JSON to stdout
- **Failure (exit 1)**: Error message to stderr

### Behavior
1. Validates parameters are non-empty
2. Gets current timestamp in ISO 8601 format (UTC)
3. Constructs manifest JSON with version 1.0.0
4. Includes empty `hooks` object
5. Prints JSON to stdout

### Example
```bash
manifest=$(init_manifest \
    "ghcr.io/joshyorko/dudleys-second-bedroom:latest" \
    "ghcr.io/ublue-os/bluefin-dx:stable" \
    "a3f2c1b")

echo "$manifest"
# Output:
# {
#   "version": "1.0.0",
#   "build": {
#     "date": "2025-10-10T14:30:00Z",
#     "image": "ghcr.io/joshyorko/dudleys-second-bedroom:latest",
#     "base": "ghcr.io/ublue-os/bluefin-dx:stable",
#     "commit": "a3f2c1b"
#   },
#   "hooks": {}
# }
```

### Preconditions
- Three non-empty string arguments
- `date` command available
- ISO 8601 date formatting supported

### Postconditions
- Returns valid JSON string
- Timestamp is current UTC time
- `hooks` object is empty (ready for population)

### Error Cases
- **Missing parameter**: Prints usage, exits 1
- **Empty parameter**: Prints validation error, exits 1

---

## Function: `add_hook_to_manifest`

### Purpose
Add a hook version entry to an existing manifest JSON.

### Signature
```bash
add_hook_to_manifest <manifest_json> <hook_name> <version_hash> <dependencies_json> [metadata_json]
```

### Parameters
- `manifest_json` (required): Existing manifest JSON string
- `hook_name` (required): Hook identifier (alphanumeric, dashes, underscores)
- `version_hash` (required): 8-character content hash
- `dependencies_json` (required): JSON array of dependency file paths
- `metadata_json` (optional): JSON object with hook-specific metadata

### Return Value
- **Success (exit 0)**: Prints updated manifest JSON to stdout
- **Failure (exit 1)**: Error message to stderr

### Behavior
1. Validates manifest_json is valid JSON
2. Validates hook_name format
3. Validates version_hash format (8 hex chars)
4. Validates dependencies_json is valid JSON array
5. Optionally validates metadata_json is valid JSON object
6. Uses `jq` to merge hook entry into manifest
7. Prints updated manifest to stdout

### Examples
```bash
# Initialize manifest
manifest=$(init_manifest "image:tag" "base:tag" "abc123")

# Add vscode-extensions hook with metadata
manifest=$(add_hook_to_manifest "$manifest" \
    "vscode-extensions" \
    "8f7a2c3d" \
    '["build_files/user-hooks/20-vscode-extensions.sh", "vscode-extensions.list"]' \
    '{"extension_count": 15, "changed": true}')

# Add wallpaper hook without metadata
manifest=$(add_hook_to_manifest "$manifest" \
    "wallpaper" \
    "1c4e9f2a" \
    '["build_files/user-hooks/10-wallpaper-enforcement.sh", "custom_wallpapers/default.jpg"]')

echo "$manifest" | jq .
# Output shows both hooks in manifest
```

### Preconditions
- `manifest_json` must be valid JSON with `hooks` object
- `hook_name` must not already exist in manifest (idempotent: latest entry wins)
- All JSON strings must be properly quoted

### Postconditions
- Manifest contains new hook entry
- Original manifest structure preserved
- Invalid JSON inputs rejected before modification

### Error Cases
- **Invalid manifest JSON**: Prints parse error, exits 1
- **Invalid hook name**: Prints format error, exits 1
- **Invalid hash format**: Prints validation error, exits 1
- **Invalid dependencies JSON**: Prints parse error, exits 1
- **Invalid metadata JSON**: Prints parse error, exits 1

---

## Function: `write_manifest`

### Purpose
Write manifest JSON to file with validation and proper permissions.

### Signature
```bash
write_manifest <manifest_json> <output_path>
```

### Parameters
- `manifest_json` (required): Complete manifest JSON string
- `output_path` (required): File path for manifest (e.g., `/etc/dudley/build-manifest.json`)

### Return Value
- **Success (exit 0)**: File written, prints success message
- **Failure (exit 1)**: Error message to stderr

### Behavior
1. Validates manifest_json is valid JSON
2. Validates manifest against schema (required fields present)
3. Checks manifest size < 50KB
4. Creates parent directory if needed
5. Writes to temporary file first
6. Validates written file is parseable
7. Moves temp file to final location (atomic)
8. Sets permissions to 644 (world-readable)
9. Prints success message with file path

### Examples
```bash
# Write completed manifest
write_manifest "$manifest" "/etc/dudley/build-manifest.json"
# Output: "Manifest written to /etc/dudley/build-manifest.json (2.3 KB)"

# Write to custom location (testing)
write_manifest "$manifest" "/tmp/test-manifest.json"
```

### Preconditions
- Manifest JSON is complete and valid
- Output directory is writable
- Sufficient disk space available

### Postconditions
- File exists at output_path
- File is valid JSON
- File permissions are 644
- File size < 50KB (warning if exceeded, not fatal)

### Error Cases
- **Invalid JSON**: Prints validation error, exits 1
- **Missing required fields**: Prints schema error, exits 1
- **Directory not writable**: Prints permission error, exits 1
- **Disk full**: Prints I/O error, exits 1
- **Size > 50KB**: Prints warning, continues (exit 0)

---

## Function: `validate_manifest_schema`

### Purpose
Validate a manifest JSON against the required schema.

### Signature
```bash
validate_manifest_schema <manifest_json>
```

### Parameters
- `manifest_json` (required): Manifest JSON string to validate

### Return Value
- **Success (exit 0)**: Manifest is valid
- **Failure (exit 1)**: Prints validation errors to stderr

### Behavior
1. Checks `version` field present and matches semver pattern
2. Checks `build` object has all required fields (date, image, base, commit)
3. Checks `hooks` object present and non-empty
4. For each hook, validates: version format, dependencies array non-empty
5. Prints specific validation errors for failures

### Examples
```bash
# Validate complete manifest
if validate_manifest_schema "$manifest"; then
    echo "Manifest is valid"
else
    echo "Validation failed"
fi

# Check specific errors
validate_manifest_schema "$invalid_manifest"
# stderr: "ERROR: Missing required field: build.commit"
# stderr: "ERROR: Hook 'vscode-extensions' has invalid version format: 'abc'"
```

### Preconditions
- Input is valid JSON (fails fast if not)

### Postconditions
- No side effects (read-only validation)
- Exit code indicates validity

### Error Cases
- **Not valid JSON**: Prints parse error, exits 1
- **Missing required field**: Prints field name, exits 1
- **Invalid format**: Prints format error with specifics, exits 1
- **Empty hooks**: Prints error, exits 1

---

## Integration Pattern

### Complete Manifest Generation Workflow

```bash
#!/usr/bin/env bash
set -euo pipefail

# Source utilities
source build_files/shared/utils/content-versioning.sh
source build_files/shared/utils/manifest-builder.sh

# Get build metadata
IMAGE_NAME="ghcr.io/joshyorko/dudleys-second-bedroom:latest"
BASE_IMAGE="ghcr.io/ublue-os/bluefin-dx:stable"
GIT_COMMIT=$(git rev-parse --short=7 HEAD)

# Initialize manifest
manifest=$(init_manifest "$IMAGE_NAME" "$BASE_IMAGE" "$GIT_COMMIT")

# Add vscode-extensions hook
vscode_hash=$(compute_content_hash \
    "build_files/user-hooks/20-vscode-extensions.sh" \
    "vscode-extensions.list")
vscode_deps='["build_files/user-hooks/20-vscode-extensions.sh", "vscode-extensions.list"]'
vscode_meta='{"extension_count": 15, "changed": true}'
manifest=$(add_hook_to_manifest "$manifest" \
    "vscode-extensions" "$vscode_hash" "$vscode_deps" "$vscode_meta")

# Add wallpaper hook
wallpaper_hash=$(compute_content_hash \
    "build_files/user-hooks/10-wallpaper-enforcement.sh" \
    custom_wallpapers/*.jpg)
wallpaper_deps=$(printf '%s\n' "build_files/user-hooks/10-wallpaper-enforcement.sh" custom_wallpapers/*.jpg | jq -R . | jq -s .)
wallpaper_meta='{"wallpaper_count": 2, "changed": false}'
manifest=$(add_hook_to_manifest "$manifest" \
    "wallpaper" "$wallpaper_hash" "$wallpaper_deps" "$wallpaper_meta")

# Add welcome hook
welcome_hash=$(compute_content_hash "build_files/user-hooks/99-first-boot-welcome.sh")
welcome_deps='["build_files/user-hooks/99-first-boot-welcome.sh"]'
welcome_meta='{"changed": false}'
manifest=$(add_hook_to_manifest "$manifest" \
    "welcome" "$welcome_hash" "$welcome_deps" "$welcome_meta")

# Validate before writing
validate_manifest_schema "$manifest" || exit 1

# Write to file
write_manifest "$manifest" "/etc/dudley/build-manifest.json"

echo "Build manifest generation complete"
```

---

## Testing Contract

### Unit Tests Required

**Test: `init_manifest` creates valid structure**
- Initialize manifest with test data
- Parse result with `jq`
- Assert all required fields present
- Assert hooks object empty

**Test: `add_hook_to_manifest` adds single hook**
- Initialize manifest
- Add one hook
- Assert hook present in output
- Assert other fields unchanged

**Test: `add_hook_to_manifest` adds multiple hooks**
- Initialize manifest
- Add three hooks sequentially
- Assert all three present
- Assert order preserved (not required, but nice)

**Test: `add_hook_to_manifest` rejects invalid hook name**
- Attempt to add hook with invalid name (spaces, special chars)
- Assert exit code 1
- Assert error message

**Test: `add_hook_to_manifest` rejects invalid hash**
- Attempt to add hook with invalid hash (wrong length, non-hex)
- Assert exit code 1

**Test: `write_manifest` creates file with correct permissions**
- Write manifest to temp file
- Check file exists
- Check permissions are 644
- Check content matches input

**Test: `write_manifest` fails on invalid JSON**
- Attempt to write malformed JSON
- Assert exit code 1
- Assert file not created

**Test: `validate_manifest_schema` passes valid manifest**
- Create valid manifest
- Validate
- Assert exit code 0

**Test: `validate_manifest_schema` fails on missing field**
- Create manifest without required field
- Validate
- Assert exit code 1
- Assert error message mentions field

**Test: `validate_manifest_schema` fails on empty hooks**
- Create manifest with empty hooks object
- Validate
- Assert exit code 1

---

## Dependencies

**Required Tools**:
- `bash` 5.x
- `jq` (JSON processor) - critical dependency
- `date` (for ISO 8601 timestamps)
- `mkdir` (for directory creation)
- `chmod` (for permission setting)
- `mv` (for atomic file writes)

**Environment**:
- Build-time execution only
- Write access to `/etc/dudley/` or specified output directory
- Git repository for commit SHA retrieval

---

## Versioning

**Current Version**: 1.0.0

**Future Extensions**:
- `merge_manifests`: Combine multiple manifest files
- `diff_manifests`: Compare two manifests and show changes
- `get_hook_metadata`: Extract specific hook metadata from manifest

**Schema Evolution**:
- Version 1.1.0 could add optional `packages` field
- Version 2.0.0 might restructure `hooks` (breaking change)

---

## Performance Characteristics

**Time Complexity**:
- `init_manifest`: O(1)
- `add_hook_to_manifest`: O(n) where n = manifest size (jq merge)
- `write_manifest`: O(m) where m = manifest size
- `validate_manifest_schema`: O(h) where h = number of hooks

**Expected Performance**:
- Manifest generation for 3 hooks: <0.5 seconds
- Manifest validation: <0.1 seconds
- Total overhead: Negligible compared to hash computation

**Optimization Notes**:
- Use `jq` for all JSON manipulation (reliable, fast)
- Atomic file write prevents partial states
- Validation happens before write (fail fast)
