# Build Module Contract

**Version**: 1.0.0
**Date**: 2025-10-05

## Purpose

Defines the interface and expectations for all build modules in the modular build system.

## Module Interface

### File Location
- **Path Pattern**: `build_files/{category}/{module-name}.sh`
- **Categories**: `shared` | `desktop` | `developer` | `user-hooks`
- **Naming**: lowercase-with-dashes.sh

### Required Header

```bash
#!/usr/bin/bash
# Script: {module-name}.sh
# Purpose: [One-line description of what this module does]
# Category: [shared|desktop|developer|user-hooks]
# Dependencies: [comma-separated list of module names, or "none"]
# Parallel-Safe: [yes|no]
# Usage: [How and when this script is called]
# Author: [Maintainer name/handle]
# Last Updated: YYYY-MM-DD

set -eoux pipefail  # REQUIRED: Exit on error, undefined vars, pipe failures
```

### Execution Contract

#### Input Expectations
- **Environment Variables**:
  - `$FEDORA_VERSION`: Current Fedora major version (e.g., "41")
  - `$IMAGE_NAME`: Name of the image being built
  - `$BUILD_CONTEXT`: Path to build context (/ctx in container)

- **File System State**:
  - Working directory: unspecified (scripts must use absolute paths)
  - Read-only access to: `/ctx/` (build context via bind mount)
  - Read-write access to: system directories being customized

#### Output Requirements
- **Exit Codes**:
  - `0`: Success - module completed all operations
  - `1`: Error - module encountered unrecoverable error
  - `2`: Skipped - module determined it should not run (not an error)

- **Logging Format**:
  ```bash
  echo "[MODULE:${CATEGORY}/${MODULE_NAME}] START"
  echo "[MODULE:${CATEGORY}/${MODULE_NAME}] {action description}"
  echo "[MODULE:${CATEGORY}/${MODULE_NAME}] WARNING: {warning message}"
  echo "[MODULE:${CATEGORY}/${MODULE_NAME}] ERROR: {error message}"
  echo "[MODULE:${CATEGORY}/${MODULE_NAME}] DONE (duration: {seconds}s)"
  ```

- **Side Effects**:
  - Must be idempotent (safe to run multiple times)
  - Must clean up temporary files created
  - Must not modify files outside intended scope

#### Error Handling
- Errors MUST include actionable remediation hints
- Errors MUST trigger automatic cleanup of partial artifacts
- Scripts MUST NOT continue after critical errors (`set -e` enforcement)

### Dependency Declaration

**Format**: CSV list in header
```bash
# Dependencies: shared/package-install, shared/copr-manager
```

**Rules**:
- Dependencies MUST be declared before module execution
- Circular dependencies MUST be detected and rejected
- Missing dependencies MUST cause build failure with clear error
- Dependencies are automatically satisfied before module runs

**Parallel Safety**:
- `Parallel-Safe: yes` → Can run concurrently with other parallel-safe modules
- `Parallel-Safe: no` → Must run exclusively (no concurrent modules)

## Module Categories

### shared/
**Purpose**: Cross-cutting utilities and orchestration

**Responsibilities**:
- Package management (install, remove, repository configuration)
- Utility functions (GitHub release downloads, validation)
- Build orchestration (build-base.sh main entry point)
- Cleanup operations
- Branding and theming

**Constraints**:
- Must be desktop-environment agnostic
- Must not assume specific developer tools installed
- Must be reusable across variants

**Key Modules**:
- `build-base.sh`: Main orchestrator, calls other modules
- `package-install.sh`: Installs from packages.json
- `cleanup.sh`: Aggressive cleanup for image size
- `validation.sh`: Pre-flight validation checks
- `utils/*.sh`: Reusable utility functions

### desktop/
**Purpose**: Desktop environment customizations

**Responsibilities**:
- GNOME-specific settings
- Theme and font installation
- dconf defaults
- Desktop extension management

**Constraints**:
- Must only run if desktop environment detected
- Must not interfere with user preferences (use defaults, not overrides)
- Must be compatible with OSTree read-only filesystem

**Key Modules**:
- `gnome-customizations.sh`: GNOME Shell and settings
- `fonts-themes.sh`: Visual appearance
- `dconf-defaults.sh`: Default preferences

### developer/
**Purpose**: Developer tool installation and configuration

**Responsibilities**:
- IDE setup (VS Code Insiders)
- Developer toolchains
- Container and virtualization tools
- Language runtimes

**Constraints**:
- Must not install to user home directories (use system paths)
- Must handle tool version updates gracefully
- Must be optional (base system functional without these)

**Key Modules**:
- `vscode-insiders.sh`: VS Code Insiders RPM installation
- `action-server.sh`: Robocorp Action Server setup
- `devcontainer-tools.sh`: DevContainer prerequisites

### user-hooks/
**Purpose**: First-boot user-level customizations

**Responsibilities**:
- Per-user welcome messages
- User-specific extension installation
- Wallpaper enforcement
- User documentation placement

**Constraints**:
- Runs in user context (not as root)
- Must check for marker files (run-once semantics)
- Must not modify system files
- Must be fast (< 5 seconds per hook)

**Key Modules**:
- `10-wallpaper-enforcement.sh`: Ensure custom wallpaper set
- `20-vscode-extensions.sh`: Install user extensions
- `99-first-boot-welcome.sh`: Welcome message and docs

## Validation Contract

### Pre-execution Validation
All modules MUST pass these checks before build starts:

1. **Syntax Validation**
   ```bash
   shellcheck -e SC2086 build_files/**/*.sh
   ```

2. **Header Validation**
   - All required header fields present
   - Dependencies reference existing modules
   - Parallel-Safe value is "yes" or "no"

3. **Idempotency Check**
   - Script can be run multiple times safely
   - Uses marker files or conditional checks

### Runtime Validation
During execution:

1. **Progress Logging**
   - Module start logged
   - Key actions logged
   - Module completion logged with duration

2. **Error Detection**
   - Non-zero exit code caught
   - Error message logged
   - Cleanup triggered

3. **Artifact Verification**
   - Expected outputs verified to exist
   - File permissions correct
   - No orphaned temporary files

## Testing Contract

### Unit Testing
Each module SHOULD have:
- Test script: `tests/modules/{category}-{module-name}.sh`
- Tests run in isolation (mock dependencies)
- Tests verify both success and failure paths

### Integration Testing
Module integration tested via:
- Full container build with module included
- Verification of intended side effects
- Smoke tests post-build

## Example Implementation

```bash
#!/usr/bin/bash
# Script: example-module.sh
# Purpose: Example module demonstrating contract compliance
# Category: shared
# Dependencies: none
# Parallel-Safe: yes
# Usage: Called by build-base.sh during base stage
# Author: Example Author
# Last Updated: 2025-10-05

set -eoux pipefail

# Module metadata
readonly MODULE_NAME="example-module"
readonly CATEGORY="shared"

# Logging helper
log() {
    local level=$1
    shift
    echo "[MODULE:${CATEGORY}/${MODULE_NAME}] ${level}: $*"
}

# Main function
main() {
    local start_time
    start_time=$(date +%s)

    log "INFO" "START"

    # Marker file for idempotency
    if [[ -f "/etc/.example-module-done" ]]; then
        log "INFO" "Already run, skipping"
        exit 2
    fi

    # Do work here
    log "INFO" "Performing example operation"

    # Mark as complete
    touch "/etc/.example-module-done"

    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    log "INFO" "DONE (duration: ${duration}s)"
}

# Execute
main "$@"
```

## Contract Violations

**Common Violations**:
- Missing or incorrect header
- Not using `set -eoux pipefail`
- Hardcoded values instead of environment variables
- Modifying files outside intended scope
- Not handling errors properly
- Not logging progress
- Not idempotent

**Consequences**:
- Build failure (fail fast)
- Module excluded from execution
- CI/CD pipeline failure
- Requires fix before merge

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-10-05 | Initial contract definition |

---

**Status**: ✅ Contract defined, ready for implementation
