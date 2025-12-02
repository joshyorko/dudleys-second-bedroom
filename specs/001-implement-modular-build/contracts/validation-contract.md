# Validation Contract

**Version**: 1.0.0
**Date**: 2025-10-05

## Purpose

Defines the validation requirements and contract for all build system components to ensure correctness before, during, and after builds.

## Validation Tiers

### Tier 1: Syntax Validation (Pre-Build)

**Purpose**: Catch basic syntax errors before any build execution

**Validators**:

#### Shell Script Validation
```bash
# Tool: shellcheck
# Target: All *.sh files in build_files/
# Command: shellcheck -e SC2086 build_files/**/*.sh

# Error Severity: ERROR (blocks build)
# Exit code: Non-zero on syntax errors
```

**Required Checks**:
- Valid bash syntax
- No undefined variables
- Proper quoting
- Correct use of conditionals
- Array syntax correctness

**Example Errors**:
- SC2086: Double quote to prevent globbing
- SC2154: Variable is referenced but not assigned
- SC2128: Expanding an array without an index

#### JSON Validation
```bash
# Tool: jq
# Target: packages.json, all *.json files
# Command: jq empty packages.json

# Error Severity: ERROR (blocks build)
# Exit code: Non-zero on JSON syntax errors
```

**Required Checks**:
- Valid JSON syntax
- No trailing commas
- Proper escaping
- Matching braces/brackets

#### Justfile Validation
```bash
# Tool: just
# Command: just --unstable --fmt --check

# Error Severity: WARNING (allows build with override)
# Exit code: Non-zero on formatting issues
```

---

### Tier 2: Configuration Validation (Pre-Build)

**Purpose**: Verify configurations are semantically correct

**Validators**:

#### Package Configuration Schema
```bash
# Tool: Custom script using jq
# Target: packages.json
# Schema: contracts/package-config-schema.json

# Validation Rules:
# 1. Schema compliance
# 2. No duplicate packages
# 3. No conflicts (package in both install and remove)
# 4. Valid COPR repo format (owner/repo)
# 5. Package names match pattern: [a-zA-Z0-9._+-]+
```

**Error Types**:
- **ERROR**: Schema violations (missing required fields, wrong types)
- **ERROR**: Duplicate packages across lists
- **ERROR**: Same package in install and remove lists
- **WARNING**: Unused version overrides
- **WARNING**: Large package count (>500 packages)

**Example Validation Script**:
```bash
#!/usr/bin/bash
# Validate packages.json against schema

set -euo pipefail

PACKAGES_FILE="packages.json"
SCHEMA_FILE="specs/001-implement-modular-build/contracts/package-config-schema.json"

# Basic JSON validity
if ! jq empty "$PACKAGES_FILE" 2>/dev/null; then
    echo "ERROR: Invalid JSON syntax in $PACKAGES_FILE"
    exit 1
fi

# Check for duplicates within install list
duplicates=$(jq -r '.all.install[]' "$PACKAGES_FILE" | sort | uniq -d)
if [[ -n "$duplicates" ]]; then
    echo "ERROR: Duplicate packages in install list: $duplicates"
    exit 1
fi

# Check for conflicts (package in both install and remove)
conflicts=$(comm -12 \
    <(jq -r '.all.install[]' "$PACKAGES_FILE" | sort) \
    <(jq -r '.all.remove[]' "$PACKAGES_FILE" | sort))
if [[ -n "$conflicts" ]]; then
    echo "ERROR: Packages in both install and remove: $conflicts"
    exit 1
fi

echo "✓ Package configuration valid"
```

#### Build Module Metadata
```bash
# Tool: Custom script
# Target: All scripts in build_files/

# Validation Rules:
# 1. Header exists and complete
# 2. Category matches directory
# 3. Dependencies reference existing modules
# 4. No circular dependencies
# 5. Parallel-Safe is yes or no
# 6. Script has execute permissions
```

**Error Types**:
- **ERROR**: Missing required header field
- **ERROR**: Category mismatch (file in desktop/ but header says shared)
- **ERROR**: Dependency references non-existent module
- **ERROR**: Circular dependency detected
- **ERROR**: Invalid Parallel-Safe value
- **WARNING**: No description provided
- **WARNING**: Author field empty

**Example Validation**:
```bash
#!/usr/bin/bash
# Validate module header

validate_module() {
    local script=$1
    local category=$(dirname "$script" | xargs basename)

    # Extract header
    header=$(sed -n '1,/^$/p' "$script")

    # Check required fields
    [[ $header =~ Purpose: ]] || echo "ERROR: Missing Purpose in $script"
    [[ $header =~ Category: ]] || echo "ERROR: Missing Category in $script"
    [[ $header =~ Dependencies: ]] || echo "ERROR: Missing Dependencies in $script"
    [[ $header =~ Parallel-Safe: ]] || echo "ERROR: Missing Parallel-Safe in $script"

    # Category matches directory
    declared_category=$(echo "$header" | grep "Category:" | cut -d: -f2 | xargs)
    if [[ "$declared_category" != "$category" ]]; then
        echo "ERROR: Category mismatch in $script (declared: $declared_category, directory: $category)"
    fi
}
```

#### Containerfile Linting
```bash
# Tool: hadolint (if available)
# Target: Containerfile
# Command: hadolint Containerfile

# Error Severity: WARNING (informational)
```

**Common Issues**:
- DL3006: Always tag the version of an image explicitly
- DL3008: Pin versions in apt-get install
- DL3003: Use WORKDIR to switch to a directory
- DL4006: Set the SHELL option -o pipefail

---

### Tier 3: Integration Validation (During/Post-Build)

**Purpose**: Verify the build produces expected results

**Validators**:

#### Container Build Success
```bash
# Tool: podman/docker build
# Success Criteria: Exit code 0
# Error Severity: ERROR (build failed)
```

**Checks**:
- Build completes without errors
- All stages execute successfully
- Final image is created
- Image size within expected range (< 8GB)

#### Artifact Presence
```bash
# Tool: podman run or podman mount
# Checks: Expected files exist in image

# Required Artifacts:
# - /usr/bin/code-insiders (if developer category included)
# - /usr/share/backgrounds/dudley/* (wallpapers)
# - /etc/.* marker files for completed modules
```

**Example Validation**:
```bash
#!/usr/bin/bash
# Verify built image contains expected artifacts

IMAGE="localhost/dudleys-second-bedroom:latest"

# Check VS Code Insiders
if podman run --rm "$IMAGE" test -f /usr/bin/code-insiders; then
    echo "✓ VS Code Insiders installed"
else
    echo "ERROR: VS Code Insiders not found"
    exit 1
fi

# Check wallpapers
wallpaper_count=$(podman run --rm "$IMAGE" \
    find /usr/share/backgrounds/dudley -type f | wc -l)
if [[ $wallpaper_count -gt 0 ]]; then
    echo "✓ Wallpapers installed ($wallpaper_count files)"
else
    echo "ERROR: No wallpapers found"
    exit 1
fi
```

#### Functional Smoke Tests
```bash
# Test basic functionality

# 1. Image boots (simulated via systemd check)
podman run --rm "$IMAGE" systemctl --version

# 2. Package manager works
podman run --rm "$IMAGE" rpm-ostree status

# 3. Custom commands available
podman run --rm "$IMAGE" just --version
```

#### Image Size Validation
```bash
# Tool: podman images
# Check: Image size within acceptable range

size_bytes=$(podman images --format "{{.Size}}" "$IMAGE")
max_size=$((8 * 1024 * 1024 * 1024))  # 8GB

if [[ $size_bytes -gt $max_size ]]; then
    echo "ERROR: Image size ($size_bytes) exceeds limit ($max_size)"
    exit 1
fi
```

---

## Validation Policy

### Error Handling

**Errors** (Severity: ERROR):
- MUST block build execution
- MUST provide clear, actionable error message
- MUST suggest remediation steps
- Cannot be overridden with flags

**Warnings** (Severity: WARNING):
- MAY allow build to proceed
- MUST log warning prominently
- CAN be suppressed with `--ignore-warnings` flag
- Should be addressed but not blocking

### Override Behavior

From clarifications: **Allow only for non-critical warnings, block errors**

```bash
# Validation exit codes:
# 0 = All checks passed
# 1 = Errors found (blocks build)
# 2 = Warnings only (build may proceed)

# Build command behavior:
just build              # Blocks on errors, stops on warnings
just build --force      # Blocks on errors, ignores warnings
just build --no-validate # Skips validation (CI/CD may reject)
```

### Validation Execution Order

**Local Development** (`just check`):
```
1. Syntax validation (Tier 1)
   ├─ shellcheck (parallel)
   ├─ jq validation (parallel)
   └─ just format check (parallel)
   → Stop if any fail

2. Configuration validation (Tier 2)
   ├─ Package config schema
   ├─ Module metadata
   └─ Containerfile lint
   → Stop if errors, warn on warnings

3. Ready for build
```

**CI/CD Pipeline**:
```
1. Syntax validation (same as local)
2. Configuration validation (same as local)
3. Build execution
4. Integration validation (Tier 3)
   ├─ Artifact presence
   ├─ Smoke tests
   └─ Image size check
5. Sign and publish (if all pass)
```

## Validation Commands

### Single Command Validation
```bash
# Run all validation checks
just check

# Equivalent to:
just lint && \
just validate-packages && \
just validate-modules && \
just validate-containerfile
```

### Individual Validators
```bash
# Shell script linting
just lint

# Package configuration validation
just validate-packages

# Module metadata validation
just validate-modules

# Containerfile linting
just validate-containerfile
```

### Pre-Commit Hook
```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: shellcheck
        name: shellcheck
        entry: shellcheck
        language: system
        types: [shell]
        args: [-e, SC2086]

      - id: validate-json
        name: validate-json
        entry: bash -c 'for f in "$@"; do jq empty "$f"; done'
        language: system
        types: [json]

      - id: just-fmt
        name: just-fmt
        entry: just --unstable --fmt --check
        language: system
        files: Justfile
        pass_filenames: false
```

## Validation Artifacts

### Validation Report Format
```json
{
  "timestamp": "2025-10-05T12:34:56Z",
  "validation_version": "1.0.0",
  "tiers": {
    "syntax": {
      "status": "passed",
      "errors": 0,
      "warnings": 0,
      "duration_ms": 1234
    },
    "configuration": {
      "status": "passed",
      "errors": 0,
      "warnings": 2,
      "warnings_details": [
        "Large package count: 487 packages",
        "Unused version override: 40"
      ],
      "duration_ms": 567
    },
    "integration": {
      "status": "passed",
      "errors": 0,
      "warnings": 0,
      "tests_run": 12,
      "tests_passed": 12,
      "duration_ms": 45678
    }
  },
  "overall_status": "passed_with_warnings",
  "build_allowed": true
}
```

## Error Message Standards

**Good Error Messages**:
```
ERROR: Package 'invalid pkg name' contains invalid characters
  → Package names must match pattern: [a-zA-Z0-9._+-]+
  → Found in: packages.json (line 45)
  → Fix: Rename to 'invalid-pkg-name'
```

**Bad Error Messages**:
```
ERROR: Invalid package
```

**Error Message Template**:
```
{SEVERITY}: {WHAT_FAILED}
  → {WHY_IT_FAILED}
  → {WHERE_THE_PROBLEM_IS}
  → {HOW_TO_FIX_IT}
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-10-05 | Initial validation contract |

---

**Status**: ✅ Validation contract defined, ready for implementation
