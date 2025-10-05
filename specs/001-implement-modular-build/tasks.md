# Tasks: Modular Build Architecture with Multi-Stage Containerfile

**Input**: Design documents from `/var/home/kdlocpanda/second_brain/Projects/dudleys-second-bedroom/specs/001-implement-modular-build/`
**Prerequisites**: plan.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

## Execution Flow (main)
```
✅ 1. Loaded plan.md from feature directory
   → Extracted: Bash 5.x, Containerfile, podman/docker, just, jq, shellcheck
   → Structure: Single infrastructure project with modular build_files/
✅ 2. Loaded optional design documents:
   → data-model.md: 7 entities identified
   → contracts/: 3 contract documents
   → research.md: 10 technical decisions
   → quickstart.md: User scenarios and workflows
✅ 3. Generated tasks by category (41 tasks total)
✅ 4. Applied task rules:
   → Different files marked [P] for parallel (26 parallel tasks)
   → Sequential tasks for shared files
   → TDD order: Tests before implementation
✅ 5. Numbered tasks sequentially (T001-T041)
✅ 6. Generated dependency graph
✅ 7. Created parallel execution examples
✅ 8. Validated task completeness
```

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions
- Estimated complexity: (S)mall < 1hr, (M)edium 1-3hrs, (L)arge 3-8hrs

## Path Conventions
All paths relative to repository root: `/var/home/kdlocpanda/second_brain/Projects/dudleys-second-bedroom/`

---

## Phase 3.1: Foundation & Setup

### T001 - Create Modular Directory Structure (M)
**Description**: Create the new modular directory structure for organizing Build Modules as defined in the plan.

**Actions**:
- Create `build_files/shared/` directory for shared Build Modules
- Create `build_files/shared/utils/` directory for utility functions
- Create `build_files/desktop/` directory for desktop Build Modules
- Create `build_files/developer/` directory for developer Build Modules
- Create `build_files/user-hooks/` directory for user-level Build Modules (if not exists)
- Create `tests/` directory for validation tests
- Preserve existing files in their current locations (to be moved in subsequent tasks)

**Acceptance Criteria**:
- All directories exist
- No existing files are deleted
- Structure matches plan.md Project Structure section

**Dependencies**: None

**Files Created**:
- `build_files/shared/` (directory)
- `build_files/shared/utils/` (directory)
- `build_files/desktop/` (directory)
- `build_files/developer/` (directory)
- `build_files/user-hooks/` (directory)
- `tests/` (directory)

---

### T002 - Create Package Configuration Schema (S)
**Description**: Create the JSON schema file for package configuration validation.

**Actions**:
- Copy `specs/001-implement-modular-build/contracts/package-config-schema.json` to repository root
- Verify schema is valid JSON
- Add schema validation to Justfile

**Acceptance Criteria**:
- Schema file exists at `package-config-schema.json`
- Schema validates with `jq empty package-config-schema.json`
- Can be referenced in packages.json once created

**Dependencies**: None

**Files Created**:
- `package-config-schema.json`

---

### T003 [P] - Create Initial packages.json (M)
**Description**: Create centralized package configuration file with current packages.

**Actions**:
- Create `packages.json` at repository root
- Migrate existing package declarations from build scripts
- Organize into "all" category with install/remove lists
- Add validation against schema

**Acceptance Criteria**:
- Valid JSON syntax
- Passes schema validation
- Contains all currently installed packages
- No duplicate packages

**Dependencies**: T002 (schema must exist)

**Files Created**:
- `packages.json`

**Example Structure**:
```json
{
  "all": {
    "install": [
      "tmux",
      "htop",
      "git"
    ],
    "remove": [
      "gnome-tour"
    ]
  },
  "41": {
    "install": []
  }
}
```

---

### T004 [P] - Update Justfile with Validation Recipes (M)
**Description**: Add validation commands to Justfile as defined in validation contract.

**Actions**:
- Add `check` recipe (runs all validations)
- Add `lint` recipe (shellcheck for bash scripts)
- Add `validate-packages` recipe (packages.json validation)
- Add `validate-modules` recipe (module metadata validation)
- Add `validate-containerfile` recipe (hadolint if available)
- Add `clean` recipe (remove build artifacts)
- Add `deep-clean` recipe (remove images too)
- Group recipes appropriately

**Acceptance Criteria**:
- `just check` runs without errors
- `just lint` validates shell scripts
- `just validate-packages` validates JSON
- All recipes have descriptions
- Recipes follow conventions from research.md

**Dependencies**: T002, T003

**Files Modified**:
- `Justfile`

---

## Phase 3.2: Validation & Testing Infrastructure (TDD Setup)

### T005 [P] - Create Validation Utility Script (M)
**Description**: Implement `build_files/shared/utils/validation.sh` per validation contract and FR-016/FR-017.

**Actions**:
- Create script with proper header (per build-module-contract.md)
- Implement shellcheck validation function
- Implement JSON validation function  
- Implement Build Module metadata validation function
- Distinguish critical errors (block builds) vs non-critical warnings (allow override)
- Add logging per contract standards
- Make executable

**Acceptance Criteria**:
- Script follows build module contract header format
- Can validate shell scripts with shellcheck
- Can validate JSON with jq
- Can parse and validate Build Module headers
- Returns proper exit codes (0=success, 1=critical error, 2=warning/skipped)
- Logs using `[MODULE:shared/validation] {level}: {message}` format
- Implements critical vs non-critical distinction per FR-016

**Dependencies**: T001

**Files Created**:
- `build_files/shared/utils/validation.sh`

---

### T006 [P] - Create Package Validation Test (S)
**Description**: Create test script that validates packages.json against schema and rules.

**Actions**:
- Create `tests/validate-packages.sh`
- Test JSON syntax validity
- Test schema compliance
- Test for duplicate packages
- Test for install/remove conflicts
- Test COPR repo format

**Acceptance Criteria**:
- Test script is executable
- Tests fail on invalid packages.json
- Tests pass on valid packages.json
- Clear error messages for each failure type

**Dependencies**: T002, T003, T005

**Files Created**:
- `tests/validate-packages.sh`

---

### T007 [P] - Create Module Metadata Validation Test (S)
**Description**: Create test that validates Build Module headers and metadata.

**Actions**:
- Create `tests/validate-modules.sh`
- Test header completeness (all required fields per build-module-contract.md)
- Test category/directory consistency
- Test dependency references (Build Modules exist)
- Test circular dependency detection
- Test Parallel-Safe field validity

**Acceptance Criteria**:
- Test script is executable
- Detects missing header fields in Build Modules
- Detects category mismatches
- Detects invalid dependencies
- Detects circular dependencies
- Clear error messages

**Dependencies**: T001, T005

**Files Created**:
- `tests/validate-modules.sh`

---

### T008 [P] - Create Containerfile Validation Test (S)
**Description**: Create test for Containerfile syntax and best practices.

**Actions**:
- Create `tests/validate-containerfile.sh`
- Test basic Dockerfile syntax
- Test stage name uniqueness
- Test FROM references validity
- Optionally use hadolint if available

**Acceptance Criteria**:
- Test script is executable
- Validates Containerfile syntax
- Reports stage issues
- Gracefully handles missing hadolint

**Dependencies**: T001

**Files Created**:
- `tests/validate-containerfile.sh`

---

### T009 [P] - Create Integration Test Runner (S)
**Description**: Create script to run all validation tests.

**Actions**:
- Create `tests/run-all-tests.sh`
- Execute all validation scripts
- Collect and report results
- Exit with appropriate code (0=all pass, 1=any fail)
- Format output clearly

**Acceptance Criteria**:
- Runs all test scripts in tests/
- Reports pass/fail for each
- Summary at end
- Proper exit code

**Dependencies**: T006, T007, T008

**Files Created**:
- `tests/run-all-tests.sh`

---

## Phase 3.3: Core Utilities (Shared Scripts)

### T010 [P] - Create Cleanup Script (M)
**Description**: Implement `build_files/shared/cleanup.sh` per cleanup specification in data-model.md.

**Actions**:
- Create script with proper module header
- Implement package manager cache cleanup
- Implement temp directory cleanup (/tmp, /var/tmp)
- Implement log cleanup (/var/log)
- Implement disabled repo handling
- Implement directory recreation with correct permissions
- Add OSTree commit
- Add duration logging

**Acceptance Criteria**:
- Follows build module contract
- Removes all specified cleanup targets
- Recreates required directories (tmp, log) with correct permissions
- Commits OSTree changes
- Idempotent (safe to run multiple times)
- Logs start, actions, and completion with duration

**Dependencies**: T001

**Files Created**:
- `build_files/shared/cleanup.sh`

---

### T011 [P] - Create Package Install Script (L)
**Description**: Implement `build_files/shared/package-install.sh` that reads packages.json.

**Actions**:
- Create script with proper module header
- Load packages.json with jq
- Detect Fedora version
- Parse install list for "all" and version-specific
- Parse remove list
- Handle install-overrides
- Enable COPR repos if specified
- Install packages with dnf5/dnf
- Remove excluded packages
- Add error handling and validation
- Log each operation

**Acceptance Criteria**:
- Follows build module contract
- Reads packages.json correctly
- Installs all specified packages
- Removes excluded packages
- Handles version-specific overrides
- Proper error handling (fails on package install failure)
- Logs package counts and operations

**Dependencies**: T003, T001

**Files Created**:
- `build_files/shared/package-install.sh`

---

### T012 [P] - Create GitHub Release Installer Utility (M)
**Description**: Implement `build_files/shared/utils/github-release-install.sh` per research.md.

**Actions**:
- Create reusable utility script
- Accept parameters: OWNER, REPO, PATTERN, INSTALL_PATH
- Fetch latest release from GitHub API
- Filter assets by pattern
- Download matching asset
- Handle different archive types (tar.gz, zip, rpm, deb, binary)
- Extract/install to target path
- Set executable permissions if needed
- Add error handling

**Acceptance Criteria**:
- Can install binaries from GitHub releases
- Handles tar.gz archives
- Handles standalone binaries
- Proper error messages if asset not found
- Cleans up temporary files
- Logs download URL and installation

**Dependencies**: T001

**Files Created**:
- `build_files/shared/utils/github-release-install.sh`

---

### T013 [P] - Create COPR Manager Utility (S)
**Description**: Implement `build_files/shared/utils/copr-manager.sh` for COPR repository handling.

**Actions**:
- Create utility script
- Function to enable COPR repo
- Function to disable COPR repo  
- Function to list enabled COPR repos
- Handle repo already enabled/disabled gracefully
- Add error handling

**Acceptance Criteria**:
- Can enable COPR repos with owner/repo format
- Can disable COPR repos
- Idempotent operations
- Proper error messages
- Logs operations

**Dependencies**: T001

**Files Created**:
- `build_files/shared/utils/copr-manager.sh`

---

### T014 [P] - Create Branding Script (M)
**Description**: Implement `build_files/shared/branding.sh` for wallpapers and theming.

**Actions**:
- Create script with proper module header
- Copy wallpapers from custom_wallpapers/ to /usr/share/backgrounds/dudley/
- Copy gschema overrides to /usr/share/glib-2.0/schemas/
- Compile gschema if needed
- Set proper permissions
- Add logging

**Acceptance Criteria**:
- Follows build module contract
- Copies all wallpaper files
- Installs gschema overrides
- Files have correct permissions (644 for files, 755 for dirs)
- Wallpapers accessible at boot
- Logs file counts and locations

**Dependencies**: T001

**Files Created**:
- `build_files/shared/branding.sh`

---

### T015 [P] - Create Signing Script (S)
**Description**: Implement `build_files/shared/signing.sh` for container signature setup.

**Actions**:
- Create script with proper module header
- Copy cosign.pub to /etc/pki/containers/
- Create policy.json.d entry for signature verification
- Set proper permissions
- Add logging

**Acceptance Criteria**:
- Follows build module contract
- Installs public key correctly
- Creates policy configuration
- Enables signature verification
- Proper permissions

**Dependencies**: T001

**Files Created**:
- `build_files/shared/signing.sh`

---

### T016 - Create Build Orchestrator Script (L)
**Description**: Implement `build_files/shared/build-base.sh` as main orchestrator per FR-004 and FR-022.

**Actions**:
- Create script with proper Build Module header (NOT parallel-safe)
- Implement Build Module discovery (scan directories)
- Parse Build Module headers for dependencies and parallel-safe flag
- Build dependency DAG per FR-004
- Implement parallel execution for parallel-safe Build Modules
- Implement sequential execution for dependent Build Modules
- Call Build Modules in correct order
- Aggregate logging per FR-017
- Error handling (auto-cleanup on failure per FR-022: remove incomplete layers, /tmp files, /var/cache)
- Track and report duration

**Acceptance Criteria**:
- Follows build module contract
- Discovers all Build Modules automatically
- Respects dependencies and executes in correct order
- Executes parallel-safe Build Modules concurrently
- Fails fast on Build Module errors
- Triggers cleanup of partial artifacts on failure (per FR-022)
- Logs Build Module execution (start, end, duration)
- Total build time logged

**Dependencies**: T010, T011, T012, T013, T014, T015 (needs utilities to exist)

**Files Created**:
- `build_files/shared/build-base.sh`

---

## Phase 3.4: Desktop Customization Scripts

### T017 [P] - Create GNOME Customizations Script (M)
**Description**: Implement `build_files/desktop/gnome-customizations.sh`.

**Actions**:
- Create script with proper module header
- Category: desktop, Parallel-Safe: yes
- Implement GNOME Shell customizations
- Configure default extensions
- Set desktop environment preferences
- Add dconf defaults
- Add logging

**Acceptance Criteria**:
- Follows build module contract
- Sets GNOME defaults without overriding user choices
- Compatible with OSTree read-only filesystem
- Logs actions taken

**Dependencies**: T001

**Files Created**:
- `build_files/desktop/gnome-customizations.sh`

---

### T018 [P] - Create Fonts and Themes Script (S)
**Description**: Implement `build_files/desktop/fonts-themes.sh`.

**Actions**:
- Create script with proper module header
- Category: desktop, Parallel-Safe: yes
- Install custom fonts if any
- Install theme packages
- Configure font rendering
- Add logging

**Acceptance Criteria**:
- Follows build module contract
- Installs specified fonts and themes
- Sets proper font configuration
- Logs installed items

**Dependencies**: T001

**Files Created**:
- `build_files/desktop/fonts-themes.sh`

---

### T019 [P] - Create dconf Defaults Script (S)
**Description**: Implement `build_files/desktop/dconf-defaults.sh`.

**Actions**:
- Create script with proper module header
- Category: desktop, Parallel-Safe: yes
- Copy dconf database files
- Compile dconf databases
- Set proper permissions
- Add logging

**Acceptance Criteria**:
- Follows build module contract
- Installs dconf defaults
- Compiles databases correctly
- Doesn't override user settings
- Logs database operations

**Dependencies**: T001

**Files Created**:
- `build_files/desktop/dconf-defaults.sh`

---

## Phase 3.5: Developer Tools Scripts

### T020 [P] - Move and Update VS Code Insiders Script (M)
**Description**: Move existing VS Code Insiders script to new location and update to contract.

**Actions**:
- Move `build_files/20-install-code-insiders-rpm.sh` to `build_files/developer/vscode-insiders.sh`
- Update header to match build module contract
- Set Category: developer, Parallel-Safe: yes
- Update logging to match contract format
- Ensure idempotency with marker file
- Add duration tracking

**Acceptance Criteria**:
- Script moved to new location
- Follows build module contract completely
- Installs VS Code Insiders RPM
- Idempotent (marker file prevents re-run)
- Logs in standard format

**Dependencies**: T001

**Files Modified**:
- `build_files/20-install-code-insiders-rpm.sh` → `build_files/developer/vscode-insiders.sh`

---

### T021 [P] - Move and Update Action Server Script (M)
**Description**: Move existing Action Server script to new location and update to contract.

**Actions**:
- Move `build_files/30-install-action-server.sh` to `build_files/developer/action-server.sh`
- Update header to match build module contract
- Set Category: developer, Parallel-Safe: yes
- Update logging to match contract format
- Ensure idempotency
- Add duration tracking

**Acceptance Criteria**:
- Script moved to new location
- Follows build module contract
- Installs Robocorp Action Server
- Idempotent
- Logs in standard format

**Dependencies**: T001

**Files Modified**:
- `build_files/30-install-action-server.sh` → `build_files/developer/action-server.sh`

---

### T022 [P] - Create DevContainer Tools Script (S)
**Description**: Create script for DevContainer prerequisites if needed.

**Actions**:
- Create script with proper module header
- Category: developer, Parallel-Safe: yes
- Install DevContainer CLI if needed
- Install required dependencies
- Add logging

**Acceptance Criteria**:
- Follows build module contract
- Installs DevContainer tools
- Logs operations

**Dependencies**: T001

**Files Created**:
- `build_files/developer/devcontainer-tools.sh`

---

## Phase 3.6: User Hooks Scripts

### T023 [P] - Create Wallpaper Enforcement Hook (S)
**Description**: Implement `build_files/user-hooks/10-wallpaper-enforcement.sh`.

**Actions**:
- Create script with proper module header
- Category: user-hooks, Parallel-Safe: yes
- Check for marker file (run-once)
- Set custom wallpaper via gsettings
- Create marker file
- Add logging

**Acceptance Criteria**:
- Follows build module contract
- Runs only once per user (marker file)
- Sets wallpaper correctly
- Logs actions

**Dependencies**: T001

**Files Created**:
- `build_files/user-hooks/10-wallpaper-enforcement.sh`

---

### T024 [P] - Move and Update VS Code Extensions Hook (M)
**Description**: Move existing VS Code user hook to new location and update.

**Actions**:
- Move `build_files/60-user-hook-code-insiders.sh` to `build_files/user-hooks/20-vscode-extensions.sh`
- Update header to match build module contract
- Set Category: user-hooks, Parallel-Safe: yes
- Update logging format
- Ensure marker file logic
- Add duration tracking

**Acceptance Criteria**:
- Script moved to new location
- Follows build module contract
- Installs VS Code extensions for user
- Run-once behavior with marker
- Logs in standard format

**Dependencies**: T001

**Files Modified**:
- `build_files/60-user-hook-code-insiders.sh` → `build_files/user-hooks/20-vscode-extensions.sh`

---

### T025 [P] - Create First Boot Welcome Hook (M)
**Description**: Implement `build_files/user-hooks/99-first-boot-welcome.sh`.

**Actions**:
- Create script with proper module header
- Category: user-hooks, Parallel-Safe: yes
- Check for marker file
- Display welcome message (ASCII art box)
- Create local documentation in ~/.local/share/dudley/
- Create README.md with useful information
- Create marker file
- Add logging

**Acceptance Criteria**:
- Follows build module contract
- Displays welcome on first boot
- Creates user documentation
- Run-once behavior
- Logs actions

**Dependencies**: T001

**Files Created**:
- `build_files/user-hooks/99-first-boot-welcome.sh`

---

### T025a [P] - Implement Base Image Fallback Logic (M)
**Description**: Implement base image fallback mechanism per FR-011 to handle unavailable primary base images.

**Actions**:
- Create `build_files/shared/base-image-manager.sh` utility
- Implement base image pull with retry logic
- Store last-known-good base image digest in cache marker file
- On pull failure, fall back to cached digest
- Log warning notification to maintainer (visible in build output)
- Test both success and fallback scenarios
- Document fallback behavior in script header

**Acceptance Criteria**:
- Follows build module contract
- Detects base image pull failures
- Falls back to last-known-good digest from cache
- Logs clear warning: "[WARNING] Base image pull failed, using cached image: <digest>"
- Updates cache marker on successful pulls
- Does not fail build on fallback (warning only)
- Tested with simulated pull failure

**Dependencies**: T001

**Files Created**:
- `build_files/shared/base-image-manager.sh`
- `tests/test-base-image-fallback.sh` (test script)

---

## Phase 3.7: Multi-Stage Containerfile

### T026 - Create Multi-Stage Containerfile (L)
**Description**: Rewrite Containerfile with multi-stage build per research.md decisions and FR-008/FR-009/FR-011.

**Actions**:
- Create Stage 1 (context): FROM scratch with COPY
- Create Stage 2 (base): FROM bluefin-dx:stable with mount caching
- Add BuildKit mount syntax: `--mount=type=bind,from=ctx,src=/,dst=/ctx` for read-only context
- Add BuildKit cache mount: `--mount=type=cache,dst=/var/cache/dnf5` for package manager
- Integrate base-image-manager.sh for fallback handling (from T025a)
- Call build-base.sh orchestrator
- Add build arguments (FEDORA_VERSION, IMAGE_NAME, etc.)
- Order layers by change frequency (wallpapers last for FR-009 cache optimization)
- Add cleanup stage call
- Preserve signing and metadata
- Add comments explaining each stage and cache strategy

**Acceptance Criteria**:
- Three distinct stages (context, base, optional cleanup)
- Uses --mount=type=bind for read-only context
- Uses --mount=type=cache for package manager
- Calls build-base.sh as orchestrator
- Layer ordering optimizes caching
- Builds successfully
- Compatible with podman and docker

**Dependencies**: T016 (build-base.sh must exist)

**Files Modified**:
- `Containerfile`

**Example Structure**:
```dockerfile
# Stage 1: Context layer (static files)
FROM scratch AS ctx
COPY build_files /build_files
COPY system_files /system_files
COPY custom_wallpapers /custom_wallpapers
COPY packages.json /packages.json

# Stage 2: Base customizations
FROM ghcr.io/ublue-os/bluefin-dx:stable AS base
ARG FEDORA_MAJOR_VERSION="41"

RUN --mount=type=bind,from=ctx,src=/,dst=/ctx \
    --mount=type=cache,dst=/var/cache/dnf5 \
    /ctx/build_files/shared/build-base.sh
```

---

## Phase 3.8: Integration & Polish

### T027 - Update GitHub Actions Workflow (M)
**Description**: Update `.github/workflows/build.yml` to use Justfile commands.

**Actions**:
- Add validation step using `just check`
- Update build step to use `just build`
- Add test step using `just test`
- Ensure cache configuration for BuildKit
- Keep existing signing and push logic
- Add error handling

**Acceptance Criteria**:
- Workflow uses Justfile commands
- Validation runs before build
- Tests run after build
- Cache configured properly
- Workflow passes on valid changes

**Dependencies**: T004, T026

**Files Modified**:
- `.github/workflows/build.yml`

---

### T028 [P] - Update Pre-Commit Configuration (S)
**Description**: Update `.pre-commit-config.yaml` with validation hooks.

**Actions**:
- Add shellcheck hook for build scripts
- Add JSON validation hook
- Add just format check hook
- Configure to run on appropriate file types

**Acceptance Criteria**:
- Hooks run automatically on commit
- Shellcheck validates bash scripts
- JSON validated
- Justfile formatting checked

**Dependencies**: T004

**Files Modified**:
- `.pre-commit-config.yaml` (create if doesn't exist)

---

### T029 [P] - Create Migration Guide (M)
**Description**: Document how to migrate from old to new structure.

**Actions**:
- Create `MIGRATION.md` at repository root
- Document directory structure changes
- Document script name changes
- Document new validation commands
- Document Containerfile changes
- Provide rollback instructions
- Add troubleshooting section

**Acceptance Criteria**:
- Clear before/after comparison
- Step-by-step migration instructions
- Rollback procedure documented
- Common issues addressed

**Dependencies**: None (can be written anytime)

**Files Created**:
- `MIGRATION.md`

---

### T030 [P] - Update Main README (M)
**Description**: Update `README.md` with new structure and commands.

**Actions**:
- Update quick start section with `just` commands
- Document new directory structure
- Update development workflow
- Add link to migration guide
- Update examples
- Keep existing content relevant

**Acceptance Criteria**:
- README reflects new structure
- Commands are up-to-date
- Examples work
- Links are valid

**Dependencies**: T029

**Files Modified**:
- `README.md`

---

### T031 [P] - Update Copilot Instructions (S)
**Description**: Update `.github/copilot-instructions.md` with final implementation details.

**Actions**:
- Update commands section with validation commands
- Update common tasks with new structure
- Update critical files list
- Verify instructions reflect implemented system
- Keep under 150 lines

**Acceptance Criteria**:
- Instructions match implementation
- Commands are correct
- File paths are accurate
- Under 150 lines

**Dependencies**: T027 (CI/CD must be final)

**Files Modified**:
- `.github/copilot-instructions.md`

---

### T032 [P] - Create Architecture Documentation (M)
**Description**: Create `ARCHITECTURE.md` documenting the build system design.

**Actions**:
- Document multi-stage build architecture
- Explain module system and dependency resolution
- Document validation tiers
- Explain caching strategy
- Document parallel execution
- Include diagrams (ASCII art)
- Reference contracts and specifications

**Acceptance Criteria**:
- Comprehensive architecture overview
- Clear diagrams
- Explains design decisions
- References technical documents

**Dependencies**: T026

**Files Created**:
- `ARCHITECTURE.md`

---

## Phase 3.9: Testing & Validation

### T033 - Run Full Validation Suite (S)
**Description**: Execute all validation tests and fix any issues.

**Actions**:
- Run `just check`
- Fix any shellcheck warnings
- Fix any JSON validation errors
- Fix any module metadata issues
- Run `just lint`
- Verify all tests pass

**Acceptance Criteria**:
- `just check` passes with no errors
- All shellcheck issues resolved
- All JSON valid
- All module headers complete and correct

**Dependencies**: T005, T006, T007, T008, T009

**Files Modified**: Various (fixes)

---

### T034 - Test Local Container Build (L)
**Description**: Build the container image locally and verify it works.

**Actions**:
- Run `just clean` to clear cache
- Run `just build` (full build)
- Monitor logs for proper module execution
- Verify build completes successfully
- Check image size (should be < 8GB)
- Note build duration

**Acceptance Criteria**:
- Build completes without errors
- All modules execute in correct order
- Parallel modules run concurrently
- Image size within limits
- Build time reasonable (< 60 min)

**Dependencies**: T026, T016, All module scripts

**Commands**:
```bash
just clean
just build
podman images localhost/dudleys-second-bedroom
```

---

### T035 - Test Incremental Build Performance (M)
**Description**: Test caching by making small changes and rebuilding per FR-009 scenarios.

**Actions**:
- Test Scenario A: Single Build Module change (e.g., add comment to desktop/gnome-customizations.sh)
- Test Scenario B: Wallpaper-only change (add/modify file in custom_wallpapers/)
- Test Scenario C: Single package addition to packages.json
- Run `just build` for each scenario
- Verify cache is used (build < 10 minutes per FR-009)
- Calculate cache hit rate
- Document actual build times

**Acceptance Criteria**:
- Scenario A (Build Module change): < 10 minutes
- Scenario B (Wallpaper change): < 5 minutes per FR-009 clarification
- Scenario C (Package addition): < 10 minutes
- Cache hit rate ≥ 80% per Success Metric #6
- Logs show "CACHED" or "Using cache" messages for unchanged layers

**Dependencies**: T034

**Commands**:
```bash
# Edit a file
echo "# Cache test" >> build_files/shared/branding.sh
just build
```

---

### T036 - Test Validation Error Handling (S)
**Description**: Verify validation properly blocks builds on critical errors per FR-016.

**Actions**:
- Test Critical Error: Introduce syntax error in a Build Module
- Run `just check` - should fail with exit code 1
- Fix error
- Run `just check` - should pass
- Test Non-Critical Warning: Introduce style issue (e.g., missing comment)
- Verify build can proceed with `--force` flag for warnings
- Verify build blocks without flag for critical errors (cannot be overridden)

**Acceptance Criteria**:
- Critical errors (syntax, security, missing required fields) block builds per FR-016
- Non-critical warnings (style, unused configs) allow override with explicit flag
- Clear distinction in error messages: "ERROR" vs "WARNING"
- Remediation hints provided for each error type
- Exit codes: 0=pass, 1=critical error (blocks), 2=warning only

**Dependencies**: T033

---

### T037 - Test Module Parallel Execution (M)
**Description**: Verify parallel-safe Build Modules execute concurrently per FR-004.

**Actions**:
- Add timestamp logging to multiple parallel-safe Build Modules (e.g., T017, T018, T019)
- Run build and capture logs
- Parse log timestamps to verify overlap
- Calculate total parallel phase time vs sum of individual module times
- Verify independent Build Modules run together
- Verify dependent Build Modules run in sequential order

**Acceptance Criteria**:
- Parallel-safe Build Modules have overlapping execution timestamps (start times within 5 seconds of each other)
- Total parallel phase time < 60% of sum of individual module times (demonstrates parallelization benefit)
- Dependent Build Modules respect dependency order (no child starts before parent completes)
- Logs show clear "START" and "DONE" timestamps for each Build Module
- Example: If 3 parallel modules take 10min each, total time should be ~10-12min, not 30min

**Dependencies**: T034

---

### T038 - Test Failure and Cleanup Behavior (M)
**Description**: Verify automatic cleanup on build failure per FR-022.

**Actions**:
- Introduce intentional failure in a Build Module (exit 1 after creating test artifacts)
- Run build
- Verify build fails fast
- Verify cleanup runs automatically
- Check for removal of partial artifacts per FR-022:
  * Incomplete container layers (verify with `podman images --all`)
  * Temporary files in /tmp
  * Downloaded packages in /var/cache
- Fix failure and rebuild
- Verify successful build after cleanup

**Acceptance Criteria**:
- Build fails on Build Module error
- Error message is clear and actionable (shows which Build Module failed)
- Cleanup removes all partial artifacts defined in FR-022
- No orphaned container layers remain
- No leftover files in /tmp or /var/cache
- Subsequent build succeeds cleanly

**Dependencies**: T034

---

### T039 - Test Package Management (M)
**Description**: Test package installation from packages.json.

**Actions**:
- Add new package to packages.json
- Validate with `just validate-packages`
- Build image
- Verify package installed: `podman run --rm {image} rpm -q {package}`
- Remove package from JSON
- Rebuild
- Verify package removed

**Acceptance Criteria**:
- Package installation works
- Package removal works
- packages.json validation catches errors
- Version-specific overrides work (if tested)

**Dependencies**: T034, T011

---

### T040 - Run Quickstart Walkthrough (M)
**Description**: Follow the quickstart guide as a new user would.

**Actions**:
- Follow each step in `specs/001-implement-modular-build/quickstart.md`
- Verify all commands work
- Verify expected outputs match
- Note any issues or unclear steps
- Update quickstart if needed

**Acceptance Criteria**:
- All quickstart steps work
- Commands produce expected output
- Timing estimates are accurate
- No confusing steps

**Dependencies**: T034, T035

---

### T041 - Final Documentation Review (S)
**Description**: Review all documentation for accuracy and completeness.

**Actions**:
- Review README.md
- Review ARCHITECTURE.md
- Review MIGRATION.md
- Review quickstart.md (in specs/)
- Review .github/copilot-instructions.md
- Verify all links work
- Verify all commands are correct
- Fix any discrepancies

**Acceptance Criteria**:
- All documentation accurate
- No broken links
- Commands verified to work
- Examples are correct

**Dependencies**: T029, T030, T031, T032, T040

---

## Dependencies Graph

```
Foundation:
  T001 (structure)
    └─> T002 (schema)
         └─> T003 [P] (packages.json)
         └─> T004 [P] (Justfile)
         └─> T025a [P] (base-image-manager.sh)

Validation:
  T001 + T002 + T003
    └─> T005 [P] (validation.sh)
    └─> T006 [P] (package test)
    └─> T007 [P] (module test)
    └─> T008 [P] (containerfile test)
         └─> T009 [P] (test runner)

Core Utilities (can run parallel):
  T001
    └─> T010 [P] (cleanup.sh)
    └─> T011 [P] (package-install.sh) - needs T003
    └─> T012 [P] (github-release.sh)
    └─> T013 [P] (copr-manager.sh)
    └─> T014 [P] (branding.sh)
    └─> T015 [P] (signing.sh)
         └─> T016 (build-base.sh) - needs all utilities

Desktop Scripts (can run parallel):
  T001
    └─> T017 [P] (gnome-customizations.sh)
    └─> T018 [P] (fonts-themes.sh)
    └─> T019 [P] (dconf-defaults.sh)

Developer Scripts (can run parallel):
  T001
    └─> T020 [P] (vscode-insiders.sh)
    └─> T021 [P] (action-server.sh)
    └─> T022 [P] (devcontainer-tools.sh)

User Hooks (can run parallel):
  T001
    └─> T023 [P] (wallpaper hook)
    └─> T024 [P] (vscode extensions hook)
    └─> T025 [P] (welcome hook)
    └─> T025a [P] (base-image-manager.sh)

Integration:
  T016 (build-base.sh) + T025a (base-image-manager)
    └─> T026 (Containerfile) - needs orchestrator and fallback handler
         └─> T027 (CI/CD)
         └─> T028 [P] (pre-commit)

Documentation (can run parallel):
  T029 [P] (migration guide)
    └─> T030 [P] (README)
  T027 └─> T031 [P] (copilot instructions)
  T026 └─> T032 [P] (architecture)

Testing (sequential):
  T009 + All scripts
    └─> T033 (validation suite)
         └─> T034 (local build)
              └─> T035 (incremental build)
              └─> T036 (error handling)
              └─> T037 (parallel execution)
              └─> T038 (cleanup behavior)
              └─> T039 (package management)
              └─> T040 (quickstart walkthrough)
                   └─> T041 (doc review)
```

---

## Parallel Execution Examples

### Phase 1: Foundation (Sequential)
```bash
# T001 must complete first
# Then T002, T003, T004 can run
```

### Phase 2: Core Utilities (Parallel)
```bash
# After T001 completes, run these in parallel:
Task: "Create cleanup.sh script in build_files/shared/cleanup.sh"
Task: "Create github-release-install.sh in build_files/shared/utils/"
Task: "Create copr-manager.sh in build_files/shared/utils/"
Task: "Create branding.sh in build_files/shared/branding.sh"
Task: "Create signing.sh in build_files/shared/signing.sh"
# T011 depends on T003, so runs after packages.json created
```

### Phase 3: Category Scripts (Parallel)
```bash
# After T001, run all category scripts in parallel:
Task: "Create gnome-customizations.sh in build_files/desktop/"
Task: "Create fonts-themes.sh in build_files/desktop/"
Task: "Create dconf-defaults.sh in build_files/desktop/"
Task: "Move vscode-insiders script to build_files/developer/"
Task: "Move action-server script to build_files/developer/"
Task: "Create devcontainer-tools.sh in build_files/developer/"
Task: "Create wallpaper hook in build_files/user-hooks/"
Task: "Move vscode-extensions hook to build_files/user-hooks/"
Task: "Create welcome hook in build_files/user-hooks/"
```

### Phase 4: Documentation (Parallel)
```bash
# After implementation complete:
Task: "Create MIGRATION.md"
Task: "Update README.md"
Task: "Update .github/copilot-instructions.md"
Task: "Create ARCHITECTURE.md"
```

---

## Validation Checklist
*Checked before task list delivery*

- [x] All contracts have corresponding validation tests (T006, T007, T008)
- [x] All entities from data-model.md have implementation tasks (Build Module, Package Config, Build Stage, etc.)
- [x] All validation tests come before implementation (Phase 3.2 before 3.3)
- [x] Parallel tasks [P] are truly independent (different files)
- [x] Each task specifies exact file path
- [x] No task modifies same file as another [P] task (verified: all [P] tasks touch different files)
- [x] Dependencies clearly documented
- [x] Task ordering follows: Setup → Tests → Utilities → Modules → Integration → Polish

---

## Execution Strategy

### Recommended Approach

**Week 1: Foundation & Validation (T001-T009)**
- Day 1: T001-T004 (structure, schema, packages, justfile)
- Day 2-3: T005-T009 (validation infrastructure)
- Goal: `just check` passes

**Week 2: Core Utilities (T010-T016)**
- Day 1: T010-T013 [P] (cleanup, package-install, utilities)
- Day 2: T014-T015 [P] (branding, signing)
- Day 3: T016 (build orchestrator - complex task)
- Goal: All shared scripts complete

**Week 3: Category Scripts (T017-T025)**
- Day 1: T017-T019 [P] (desktop scripts)
- Day 2: T020-T022 [P] (developer scripts)
- Day 3: T023-T025 [P] (user hooks)
- Goal: All modules complete

**Week 4: Integration (T026-T032)**
- Day 1-2: T026 (Containerfile - complex)
- Day 3: T027-T028 (CI/CD, pre-commit)
- Day 4-5: T029-T032 [P] (documentation)
- Goal: End-to-end working system

**Week 5: Testing & Polish (T033-T041)**
- Day 1: T033-T034 (validation, initial build)
- Day 2: T035-T037 (performance, parallel testing)
- Day 3: T038-T039 (failure handling, package management)
- Day 4: T040-T041 (quickstart, final review)
- Goal: Fully tested, documented system

### Critical Path
```
T001 → T002 → T003 → T011 → T016 → T026 → T034
(Structure → Schema → Packages → Install → Orchestrator → Containerfile → Build)
```
This path MUST complete for system to be functional.

### Quick Wins
These tasks provide immediate value:
- T004: Validation commands available
- T010: Cleanup script reduces image size
- T016: Orchestrator enables modular execution
- T026: Multi-stage build enables caching

---

## Notes

- **[P] tasks** = Different files, no dependencies, can run in parallel
- **Verify tests work**: Run validation after each phase
- **Commit frequently**: After each task or logical group
- **Avoid scope creep**: Stick to defined tasks, note improvements for future
- **Test incrementally**: Don't wait until end to test builds
- **Document as you go**: Update docs when behavior changes

---

**Total Tasks**: 42
**Parallel Tasks**: 27 (64%)
**Sequential Tasks**: 15 (36%)
**Estimated Total Effort**: 12-15 days (assuming full-time work)

**Status**: ✅ Ready for implementation (updated with remediation fixes)
