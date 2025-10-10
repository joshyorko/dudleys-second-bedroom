# Research: Automatic Content-Based Versioning

**Feature**: 002-implement-automatic-content  
**Date**: 2025-10-10  
**Status**: Complete

## Overview

This document consolidates research findings for implementing automatic content-based versioning in user hooks, addressing all technical unknowns identified in the implementation plan.

---

## 1. Universal Blue version-script API and Behavior

### Decision
Use the existing `version-script` function from `/usr/lib/ublue/setup-services/libsetup.sh` with post-execution version recording pattern.

### Research Findings

**Current Implementation Pattern**:
```bash
# Source the library
source /usr/lib/ublue/setup-services/libsetup.sh

# Check if hook should run
if [[ "$(version-script SCRIPT_NAME VERSION_NUMBER)" == "run" ]]; then
    # Hook logic here
    # ...
    # Version recorded automatically after script exits successfully
fi
```

**Key Behaviors**:
- `version-script` returns "run" if version file doesn't exist or version changed
- Returns "skip" if version matches and hook previously completed
- Version is recorded at `/etc/ublue/version-script/SCRIPT_NAME` after successful execution
- Script must exit with status 0 for version to be recorded (non-zero prevents recording)

**Integration Strategy for Content Versioning**:
1. Replace hardcoded `VERSION_NUMBER` with computed content hash (8-char truncated SHA256)
2. Compute hash at build time, inject into hook script via placeholder replacement
3. Version recording happens after hook completes (natural retry on failure)
4. Use `set -euo pipefail` to ensure any command failure prevents version recording

### Rationale
The existing `version-script` function already provides the exact semantics needed: skip-on-match, run-on-change, record-on-success. No need to create parallel versioning system. The function's exit-code-based recording naturally implements the "record only after success" requirement from clarifications.

### Alternatives Considered
- **Custom version tracking**: Rejected because it duplicates existing functionality and breaks Universal Blue patterns
- **Pre-execution recording**: Rejected because it prevents automatic retry on failure
- **Separate success flag**: Rejected as unnecessary complexity given `version-script` behavior

### Implementation Notes
- Hook scripts must maintain `set -euo pipefail` to ensure failures prevent version recording
- The `__CONTENT_VERSION__` placeholder will be replaced at build time with actual hash
- Must source `libsetup.sh` before calling `version-script`

---

## 2. Bash Hash Computation Best Practices

### Decision
Use `sha256sum` with sorted file concatenation, truncate to 8 characters, include both script and data files.

### Research Findings

**Hash Computation Pattern**:
```bash
compute_content_hash() {
    local files=("$@")
    local combined_hash
    
    # Sort files for deterministic ordering
    IFS=$'\n' sorted_files=($(sort <<<"${files[*]}"))
    unset IFS
    
    # Concatenate and hash
    combined_hash=$(cat "${sorted_files[@]}" | sha256sum | cut -c1-8)
    echo "$combined_hash"
}
```

**Best Practices**:
- Always sort input files to ensure deterministic order
- Use `cat` for file concatenation (handles binary files correctly)
- Pipe directly to `sha256sum` (no temp files needed)
- Use `cut -c1-8` for truncation (more reliable than parameter expansion for different sha256sum output formats)
- Check file existence before hashing to fail fast

**Collision Risk Analysis**:
- 8 hex characters = 32 bits = 4.3 billion possible values
- For 100 hooks with independent changes: collision probability negligible (<0.0001%)
- Birthday paradox applies but not concerning at this scale
- If collision occurs: hook runs unnecessarily (safe failure mode)

**Multi-File Handling**:
```bash
# For wallpapers (content-only, ignore filenames)
find custom_wallpapers/ -type f -exec sha256sum {} \; | sort | sha256sum | cut -c1-8

# For script + data combined
cat build_files/user-hooks/20-vscode-extensions.sh vscode-extensions.list | sha256sum | cut -c1-8
```

### Rationale
Standard Unix tools (`sha256sum`, `cut`) are universally available, fast, and well-tested. 8-character truncation balances readability (matches existing version format) with sufficient uniqueness for this use case. Including both script and data files ensures any logic changes trigger re-execution.

### Alternatives Considered
- **MD5**: Rejected due to cryptographic weakness (even though not used for security here, SHA256 is standard)
- **Full 64-char hash**: Rejected as unnecessarily long for version identifiers
- **4-char truncation**: Rejected due to higher collision probability
- **Separate script/data hashes**: Rejected as unnecessary complexity (single combined hash sufficient)

### Implementation Notes
- Must handle spaces in filenames (use proper quoting)
- Consider using `find -print0` with `xargs -0` for robustness with unusual filenames
- Error handling: exit immediately if any file missing

---

## 3. Systemd Journal Logging from Bash

### Decision
Use `systemd-cat` with structured metadata for build-time logging, `echo` with identifiers for runtime logging (captured by systemd automatically).

### Research Findings

**Build-Time Logging** (during container build):
```bash
# Simple structured logging
echo "[dudley-versioning] Computing hash for hook: $HOOK_NAME" >&2
echo "[dudley-versioning] Dependencies: ${files[*]}" >&2
echo "[dudley-versioning] Hash result: $hash" >&2
```

**Runtime Logging** (during user boot):
```bash
# Hooks run via systemd service, output automatically captured
echo "Dudley Hook: $HOOK_NAME starting with version $VERSION"
echo "Dudley Hook: Processing dependencies: ${deps[*]}"

# Error logging
echo "ERROR: Dudley Hook $HOOK_NAME failed: $error_message" >&2
exit 1  # Prevents version recording
```

**Querying Logs**:
```bash
# View all hook activity
journalctl -u ublue-user-setup.service

# View specific hook
journalctl -u ublue-user-setup.service | grep "Dudley Hook: 20-vscode-extensions"
```

**Structured Metadata** (optional enhancement):
```bash
# Using logger for syslog-compatible structured fields
logger -t dudley-hook -p user.info \
    "HOOK_NAME=$HOOK_NAME VERSION=$VERSION STATUS=starting"
```

### Rationale
Universal Blue's `ublue-user-setup.service` already captures stdout/stderr from hooks to systemd journal. No special logging infrastructure needed. Consistent prefixes enable easy filtering. Build-time logging to stderr is visible in container build output for debugging.

### Alternatives Considered
- **systemd-cat wrapper**: Rejected as unnecessary (systemd service already captures output)
- **Separate log files**: Rejected (violates immutable OS principles, systemd journal is standard)
- **Complex structured logging library**: Rejected as overengineering (simple echo statements sufficient)

### Implementation Notes
- Use consistent prefix format: `[dudley-versioning]` for build, `Dudley Hook:` for runtime
- Always include hook name in log messages for filtering
- Log both success and failure paths
- Use stderr for errors and warnings

---

## 4. Build-Time vs Runtime File Access Patterns

### Decision
Generate manifest during Containerfile build, copy to `/etc/dudley/` in final image layer, read as immutable data at runtime.

### Research Findings

**Build-Time Pattern** (in Containerfile):
```dockerfile
# Compute hashes and generate manifest
RUN /tmp/build-scripts/generate-manifest.sh > /etc/dudley/build-manifest.json

# Inject hashes into hook scripts
RUN sed -i "s/__CONTENT_VERSION__/$(compute_hash)/g" /usr/share/ublue-os/user-setup.hooks.d/*.sh

# Copy hooks to final location
COPY build_files/user-hooks/*.sh /usr/share/ublue-os/user-setup.hooks.d/
```

**Runtime Pattern** (in hooks):
```bash
# Read manifest (immutable, no parsing errors expected in production)
MANIFEST_PATH="/etc/dudley/build-manifest.json"
if [[ -f "$MANIFEST_PATH" ]]; then
    # Extract info using jq
    EXTENSION_COUNT=$(jq -r '.hooks["vscode-extensions"].metadata.extension_count' "$MANIFEST_PATH")
fi
```

**Directory Structure**:
- Build scripts: `/tmp/build-scripts/` (ephemeral, cleaned in final layer)
- Final manifest: `/etc/dudley/build-manifest.json` (immutable, world-readable)
- Hook scripts: `/usr/share/ublue-os/user-setup.hooks.d/` (Universal Blue standard location)
- Version tracking: `/etc/ublue/version-script/` (created by version-script at runtime)

### Rationale
Separation of build-time computation and runtime consumption aligns with immutable OS principles. Manifest is generated once during build with full context (git info, file access), then consumed read-only at runtime. Universal Blue's established directory structure for hooks ensures compatibility.

### Alternatives Considered
- **Runtime hash computation**: Rejected (slow, unnecessary recomputation, files may not be accessible)
- **Manifest in /var**: Rejected (/etc is appropriate for immutable config data)
- **Manifest in /usr/share**: Rejected (/etc is standard for system configuration)

### Implementation Notes
- Ensure `/etc/dudley/` directory exists before writing manifest
- Set manifest permissions to 644 (world-readable)
- Clean up temporary build scripts in final Containerfile layer
- Use multi-stage build if needed to keep intermediate artifacts out of final image

---

## 5. JSON Manifest Schema Design

### Decision
Flat, extensible JSON schema with top-level metadata and `hooks` object containing per-hook details.

### Schema Definition

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["version", "build", "hooks"],
  "properties": {
    "version": {
      "type": "string",
      "description": "Manifest schema version (semver)",
      "pattern": "^\\d+\\.\\d+\\.\\d+$"
    },
    "build": {
      "type": "object",
      "required": ["date", "image", "base", "commit"],
      "properties": {
        "date": {
          "type": "string",
          "format": "date-time",
          "description": "ISO 8601 build timestamp"
        },
        "image": {
          "type": "string",
          "description": "Full image name with tag"
        },
        "base": {
          "type": "string",
          "description": "Base image reference"
        },
        "commit": {
          "type": "string",
          "description": "Git commit SHA (full or short)"
        }
      }
    },
    "hooks": {
      "type": "object",
      "description": "Map of hook name to hook metadata",
      "patternProperties": {
        "^[a-zA-Z0-9_-]+$": {
          "type": "object",
          "required": ["version", "dependencies"],
          "properties": {
            "version": {
              "type": "string",
              "description": "8-character content hash",
              "pattern": "^[a-f0-9]{8}$"
            },
            "dependencies": {
              "type": "array",
              "items": {"type": "string"},
              "description": "List of file paths used in hash computation"
            },
            "metadata": {
              "type": "object",
              "description": "Hook-specific metadata (extensible)",
              "additionalProperties": true
            }
          }
        }
      }
    }
  }
}
```

### Example Manifest

```json
{
  "version": "1.0.0",
  "build": {
    "date": "2025-10-10T14:30:00Z",
    "image": "ghcr.io/joshyorko/dudleys-second-bedroom:latest",
    "base": "ghcr.io/ublue-os/bluefin-dx:40",
    "commit": "a3f2c1b"
  },
  "hooks": {
    "vscode-extensions": {
      "version": "8f7a2c3d",
      "dependencies": [
        "build_files/user-hooks/20-vscode-extensions.sh",
        "vscode-extensions.list"
      ],
      "metadata": {
        "extension_count": 15,
        "changed": true
      }
    },
    "wallpaper": {
      "version": "1c4e9f2a",
      "dependencies": [
        "build_files/user-hooks/10-wallpaper-enforcement.sh",
        "custom_wallpapers/default.jpg",
        "custom_wallpapers/secondary.png"
      ],
      "metadata": {
        "wallpaper_count": 2,
        "changed": false
      }
    },
    "welcome": {
      "version": "5b8d3e1f",
      "dependencies": [
        "build_files/user-hooks/99-first-boot-welcome.sh"
      ],
      "metadata": {
        "changed": false
      }
    }
  }
}
```

### Rationale

**Flat structure**: Easy to parse with `jq`, minimal nesting reduces complexity.

**Extensible metadata**: Each hook can include custom fields (e.g., extension_count) without schema changes.

**Version field**: Allows schema evolution (future versions can add fields while maintaining backward compatibility).

**Dependencies array**: Transparency about what files affect each hook, useful for debugging.

**Changed flag**: Optional metadata for welcome hook to display which hooks are new/modified.

### Alternatives Considered

- **Nested hierarchy**: Rejected (harder to query with jq, unnecessary structure)
- **Separate files per hook**: Rejected (complicates build process, atomic manifest preferred)
- **YAML format**: Rejected (JSON more universally supported, jq standard in Universal Blue)
- **Include file contents**: Rejected (bloats manifest, unnecessary)

### Implementation Notes

- Use `jq` for manifest generation to ensure valid JSON
- Pretty-print for human readability (development benefit)
- Validate schema in test suite
- Keep manifest under 50KB (track in success criteria)
- Use ISO 8601 for timestamps (UTC recommended)

---

## Summary of Decisions

| Research Area | Decision | Key Rationale |
|--------------|----------|---------------|
| **version-script Integration** | Use existing function, replace version number with computed hash | Already provides exact semantics needed, no duplication |
| **Hash Computation** | sha256sum with sorted concatenation, 8-char truncation, script+data | Standard tools, sufficient uniqueness, deterministic |
| **Logging** | Simple echo with prefixes, captured by systemd | No special infrastructure needed, Universal Blue pattern |
| **File Access** | Generate at build time, read-only at runtime | Immutable OS principles, clean separation of concerns |
| **Manifest Schema** | Flat JSON with extensible metadata per hook | Easy parsing, future-proof, transparent dependencies |

## Next Steps

Proceed to Phase 1: Design & Contracts with all unknowns resolved.
