# Utility Function Contract: Content Versioning

**Module**: `build_files/shared/utils/content-versioning.sh`
**Purpose**: Provide reusable bash functions for computing content hashes and managing version placeholders
**Date**: 2025-10-10

## Overview

This module provides a public API for computing deterministic content hashes from files and replacing version placeholders in hook scripts. Used during container build process.

---

## Function: `compute_content_hash`

### Purpose
Compute an 8-character SHA256 hash from one or more files.

### Signature
```bash
compute_content_hash <file1> [file2] [file3] ...
```

### Parameters
- `file1, file2, ...` (required): One or more file paths to hash (relative or absolute)

### Return Value
- **Success (exit 0)**: Prints 8-character lowercase hex string to stdout
- **Failure (exit 1)**: Prints error message to stderr

### Behavior
1. Validates all files exist (exits with error if any missing)
2. Sorts file paths alphabetically for deterministic ordering
3. Concatenates file contents in sorted order
4. Computes SHA256 hash
5. Truncates to first 8 characters
6. Prints result to stdout

### Examples
```bash
# Single file
hash=$(compute_content_hash "vscode-extensions.list")
# Output: "8f7a2c3d"

# Multiple files (script + data)
hash=$(compute_content_hash "build_files/user-hooks/20-vscode-extensions.sh" "vscode-extensions.list")
# Output: "a1b2c3d4"

# Directory glob (wallpapers)
hash=$(compute_content_hash custom_wallpapers/*.jpg)
# Output: "1c4e9f2a"

# Error handling
hash=$(compute_content_hash "missing-file.txt") || echo "Hash computation failed"
# stderr: "ERROR: File not found: missing-file.txt"
# Exit code: 1
```

### Preconditions
- All specified files must exist and be readable
- At least one file path must be provided

### Postconditions
- No side effects (no files modified)
- Output is deterministic (same input → same output)
- Hash is exactly 8 lowercase hex characters [a-f0-9]

### Error Cases
- **Missing file**: Prints error, exits 1
- **No arguments**: Prints usage error, exits 1
- **Unreadable file**: Prints permission error, exits 1

---

## Function: `replace_version_placeholder`

### Purpose
Replace `__CONTENT_VERSION__` placeholder in a file with a computed hash.

### Signature
```bash
replace_version_placeholder <file> <hash>
```

### Parameters
- `file` (required): Path to file containing placeholder
- `hash` (required): 8-character hash to inject

### Return Value
- **Success (exit 0)**: File modified in place
- **Failure (exit 1)**: Error message to stderr, file unchanged

### Behavior
1. Validates file exists and is writable
2. Validates hash format (8 hex characters)
3. Searches for `__CONTENT_VERSION__` literal string
4. Replaces all occurrences with provided hash
5. Modifies file in place using `sed -i`

### Examples
```bash
# Replace placeholder in hook script
replace_version_placeholder "build_files/user-hooks/20-vscode-extensions.sh" "8f7a2c3d"
# File contents: version-script "vscode-extensions" "8f7a2c3d"

# Error: invalid hash format
replace_version_placeholder "hook.sh" "invalid"
# stderr: "ERROR: Invalid hash format: invalid (expected 8 hex chars)"
# Exit code: 1

# Error: placeholder not found (warning only)
replace_version_placeholder "no-placeholder.sh" "8f7a2c3d"
# stderr: "WARNING: No placeholder found in no-placeholder.sh"
# Exit code: 0 (not a fatal error)
```

### Preconditions
- File must exist and be writable
- Hash must be exactly 8 hex characters

### Postconditions
- File modified in place if placeholder found
- Original placeholder string removed
- File permissions preserved

### Error Cases
- **Missing file**: Prints error, exits 1
- **Unwritable file**: Prints permission error, exits 1
- **Invalid hash format**: Prints validation error, exits 1
- **No placeholder found**: Prints warning, exits 0 (non-fatal)

---

## Function: `validate_hash_format`

### Purpose
Validate a string matches the expected 8-character hex hash format.

### Signature
```bash
validate_hash_format <hash>
```

### Parameters
- `hash` (required): String to validate

### Return Value
- **Success (exit 0)**: Hash is valid
- **Failure (exit 1)**: Hash is invalid

### Behavior
1. Checks length is exactly 8 characters
2. Checks all characters are lowercase hex [a-f0-9]
3. Returns exit code indicating validity

### Examples
```bash
# Valid hash
if validate_hash_format "8f7a2c3d"; then
    echo "Valid"
fi
# Output: "Valid"

# Invalid: too short
validate_hash_format "8f7a2c"
# Exit code: 1

# Invalid: uppercase
validate_hash_format "8F7A2C3D"
# Exit code: 1

# Invalid: non-hex
validate_hash_format "8f7a2czd"
# Exit code: 1
```

### Preconditions
- One argument provided

### Postconditions
- No side effects (read-only operation)

### Error Cases
- **No argument**: Exits 1
- **Invalid format**: Exits 1 (silent, check via exit code)

---

## Integration Pattern

### Typical Build-Time Usage

```bash
#!/usr/bin/env bash
set -euo pipefail

# Source the utilities
source build_files/shared/utils/content-versioning.sh

# Compute hash for a hook
echo "Computing version for vscode-extensions hook..."
VSCODE_HASH=$(compute_content_hash \
    "build_files/user-hooks/20-vscode-extensions.sh" \
    "vscode-extensions.list")

echo "Version: $VSCODE_HASH"

# Replace placeholder in hook script
replace_version_placeholder \
    "build_files/user-hooks/20-vscode-extensions.sh" \
    "$VSCODE_HASH"

echo "Hook updated with content version"
```

### Error Handling Pattern

```bash
# Robust error handling
if ! hash=$(compute_content_hash "$dep1" "$dep2"); then
    echo "ERROR: Failed to compute hash" >&2
    exit 1
fi

if ! validate_hash_format "$hash"; then
    echo "ERROR: Generated invalid hash: $hash" >&2
    exit 1
fi

replace_version_placeholder "$hook_script" "$hash" || {
    echo "ERROR: Failed to update hook script" >&2
    exit 1
}
```

---

## Testing Contract

### Unit Tests Required

**Test: `compute_content_hash` determinism**
- Create temp file with known content
- Compute hash 10 times
- Assert all hashes identical

**Test: `compute_content_hash` multi-file ordering**
- Create files a.txt, b.txt, c.txt
- Compute hash(a, b, c) and hash(c, b, a)
- Assert hashes identical (verifies sorting)

**Test: `compute_content_hash` missing file**
- Attempt to hash non-existent file
- Assert exit code 1
- Assert error message contains filename

**Test: `replace_version_placeholder` success**
- Create file with `__CONTENT_VERSION__`
- Replace with valid hash
- Assert file contains hash, not placeholder

**Test: `replace_version_placeholder` no placeholder**
- Create file without placeholder
- Replace with hash
- Assert warning logged, exit code 0

**Test: `validate_hash_format` valid cases**
- Test valid 8-char hex strings
- Assert exit code 0

**Test: `validate_hash_format` invalid cases**
- Test too short, too long, uppercase, non-hex
- Assert exit code 1 for each

---

## Dependencies

**Required Tools**:
- `bash` 5.x (for array sorting)
- `sha256sum` (GNU coreutils)
- `cut` (GNU coreutils)
- `sed` (GNU sed, for -i flag)
- `cat` (for file concatenation)
- `sort` (for deterministic ordering)

**Environment**:
- Build-time execution only (not available at runtime)
- Must run in repository root context (for relative paths)
- Standard Unix file permissions (read access to dependencies, write access to hooks)

---

## Versioning

**Current Version**: 1.0.0

**Future Extensions**:
- `compute_directory_hash`: Hash all files in a directory recursively
- `get_previous_hash`: Retrieve hash from previous build for comparison
- `verify_hash`: Verify computed hash matches stored value

**Breaking Changes**:
- Changing hash truncation length (e.g., 8 → 12 chars) would break version-script integration
- Changing hash algorithm (SHA256 → SHA512) would invalidate all stored versions

---

## Performance Characteristics

**Time Complexity**:
- `compute_content_hash`: O(n) where n = total bytes in all files
- `replace_version_placeholder`: O(m) where m = file size
- `validate_hash_format`: O(1) (fixed 8-char check)

**Expected Performance**:
- Hash computation: <1 second for files <10MB
- Placeholder replacement: <0.1 second per file
- Total build overhead: <5 seconds (per SC-003)

**Optimization Notes**:
- File concatenation uses pipe (no temp files)
- Sorting happens in memory (shell array)
- Placeholder replacement is single-pass sed operation
