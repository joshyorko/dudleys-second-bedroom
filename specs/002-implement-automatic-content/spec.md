# Feature Specification: Automatic Content-Based Versioning for User Hooks

**Feature Branch**: `002-implement-automatic-content`
**Created**: 2025-10-10
**Status**: Draft
**Input**: User description: "Implement automatic content-based versioning for user hooks that only re-run when their dependencies actually change. Replace manual version bumping with SHA256 content hashes, and enhance the welcome hook to display a build summary showing what changed."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Automatic Hook Re-execution Based on Content Changes (Priority: P1)

As a system maintainer updating configuration files (like VS Code extension lists or wallpapers), I want hooks to automatically detect and respond to content changes without manual version management, so that my updates take effect immediately on the next user boot without requiring me to remember version bumps.

**Why this priority**: This is the core value proposition - eliminating manual version management while ensuring hooks run when needed. Without this, the entire feature provides no value.

**Independent Test**: Can be fully tested by modifying a single dependency file (e.g., `vscode-extensions.list`), rebuilding the image, and verifying the corresponding hook re-runs on first boot while other hooks skip execution. Delivers immediate value by removing manual version tracking for at least one hook.

**Acceptance Scenarios**:

1. **Given** a built image with current content versions, **When** I boot the system for the first time, **Then** all hooks execute and record their content versions
2. **Given** an existing system with recorded hook versions, **When** I rebuild the image with no content changes, **Then** no hooks re-execute on next boot
3. **Given** a system with recorded versions, **When** I modify `vscode-extensions.list` and rebuild, **Then** only the VS Code extensions hook re-executes on next boot
4. **Given** a system with recorded versions, **When** I replace a wallpaper image and rebuild, **Then** only the wallpaper hook re-executes on next boot
5. **Given** a hook's content file unchanged but hook script logic modified, **When** I rebuild the image, **Then** the hook re-executes to apply the logic changes

---

### User Story 2 - Build Transparency and Change Summary (Priority: P2)

As a system user logging in after an update, I want to see a clear summary of what changed in this build (new extensions, updated wallpapers, package changes), so that I understand what's different and can take advantage of new features.

**Why this priority**: Enhances user experience and adoption by making changes visible and transparent. Valuable but not essential for core functionality.

**Independent Test**: Can be fully tested by creating a build manifest with mock data and verifying the welcome hook displays formatted change information. Delivers value by improving user awareness even without the versioning system fully operational.

**Acceptance Scenarios**:

1. **Given** a fresh boot after an update, **When** I log in, **Then** I see a welcome message displaying what hooks changed and what stayed the same
2. **Given** a build with new VS Code extensions added, **When** I view the welcome summary, **Then** I see the updated extension count and a "changed" indicator
3. **Given** a build with updated wallpapers, **When** I view the welcome summary, **Then** I see which wallpapers were modified
4. **Given** a build with package additions/removals, **When** I view the welcome summary, **Then** I see what packages were added, removed, and updated
5. **Given** I want to review build information later, **When** I run a command, **Then** I can view the build summary again without waiting for next boot

---

### User Story 3 - Developer Hook Creation with Content Versioning (Priority: P3)

As a developer adding new user hooks to the build system, I want a documented pattern and reusable utilities for content-based versioning, so that I can easily create new hooks that follow the same automatic versioning approach without understanding implementation details.

**Why this priority**: Supports maintainability and extensibility but not required for initial feature value. Can be added after core functionality proves stable.

**Independent Test**: Can be fully tested by following documentation to create a new hook with content versioning, building the image, and verifying the hook behaves correctly (runs on first boot, skips on unchanged rebuilds). Delivers value by enabling team scalability.

**Acceptance Scenarios**:

1. **Given** I need to create a new user hook, **When** I follow the documented template pattern, **Then** I can implement content versioning without writing hash computation logic
2. **Given** a new hook using the versioning utility, **When** the hook's dependencies change, **Then** the hook automatically re-executes using the new content version
3. **Given** a new hook's dependencies, **When** I include multiple files in the version computation, **Then** the system correctly tracks changes to any of those files
4. **Given** documentation for the versioning API, **When** I need to add version tracking to my hook, **Then** I can find clear examples of all common patterns (single file, multiple files, combined script + data)

---

### Edge Cases

- **Hook execution failure**: If a hook fails partway through, its content version is NOT recorded until successful completion. Failed hooks automatically retry on next boot with the same version, ensuring recovery without manual intervention.
- **Missing dependency files at build time**: Build MUST fail with clear error message. Missing dependencies are treated as build-time configuration errors that must be resolved before image creation.
- **Build manifest corrupted/missing at runtime**: Not applicable - manifest corruption cannot occur in production since build failures prevent image deployment. If encountered during development, treat as build system bug.
- **Clean first boot vs. failed hook boot**: System distinguishes these naturally - clean first boot has no recorded versions (all hooks run), failed hook boot has some versions recorded (only failed hooks retry).
- **Large file hash computation time**: Acceptable as long as SC-003 met (under 5 seconds for <100MB). Larger files deferred to future optimization work.
- **Identical wallpaper content, different filenames**: System hashes file content only (ignoring filenames) to prevent false "changed" signals from simple renames.
- **Multiple builds without boots**: Each build generates independent manifest; no cumulative tracking needed (latest manifest is authoritative).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST compute SHA256 content hashes for specified file dependencies at build time
- **FR-002**: System MUST truncate content hashes to 8 characters for version identifiers to match existing version-script format
- **FR-003**: System MUST replace version placeholders in hook scripts with computed content hashes during build process
- **FR-004**: System MUST support hash computation for single files, multiple files, and combinations of data files with hook scripts
- **FR-005**: System MUST generate a build manifest JSON file containing all hook versions, dependencies, and metadata at build time
- **FR-006**: System MUST store the build manifest at `/etc/dudley/build-manifest.json` in the final image
- **FR-007**: System MUST record build date, image name, base image, and git commit information in the build manifest
- **FR-008**: System MUST track for each hook: version hash, list of dependency file paths, and whether content changed from previous build
- **FR-009**: System MUST integrate with existing Universal Blue `version-script` functionality for version tracking
- **FR-009a**: Hook version MUST be recorded by version-script only AFTER successful hook completion (not at start), ensuring failed hooks automatically retry on next boot
- **FR-010**: Welcome hook MUST read the build manifest and display formatted summary of changes on first boot
- **FR-011**: Welcome hook summary MUST include: VS Code extension count and change status, wallpaper change status, base image information. Package changes (added/removed/updated) SHOULD be included if feasible during Phase 2 implementation, otherwise deferred to future release per scope boundaries.
- **FR-012**: System MUST provide reusable utility functions for: computing content hashes, generating build manifests, retrieving hook versions from manifests
- **FR-013**: System MUST ensure deterministic hash generation - identical file content MUST produce identical hashes across builds
- **FR-014**: VS Code extensions hook MUST use combined content hash of `vscode-extensions.list` AND the hook script file (`20-vscode-extensions.sh`) as its version identifier
- **FR-015**: Wallpaper hook MUST use combined content hash of all wallpaper image file contents (ignoring filenames) AND the hook script file (`10-wallpaper-enforcement.sh`) as its version identifier
- **FR-016**: Welcome hook MUST use content hash of its own script file (`99-first-boot-welcome.sh`) as its version identifier
- **FR-017**: System MUST provide a command-line tool installed at `/usr/local/bin/dudley-build-info` for users to view build information on demand after initial welcome
- **FR-018**: Build manifest MUST track count of VS Code extensions for display purposes
- **FR-019**: Build manifest MUST be valid JSON parseable by standard tools like `jq`
- **FR-020**: System MUST fail the build with clear error message when dependency files are missing (missing dependencies are build-time configuration errors requiring resolution before image creation)
- **FR-021**: System MUST log hash computation and hook execution events to systemd journal with structured metadata including: hook name, dependency file paths, computed hash values, and execution status
- **FR-022**: Content hash computation MUST include both the hook script file AND its data dependency files, ensuring logic changes trigger re-execution
- **FR-023**: For multi-file dependencies (e.g., wallpapers), system MUST hash file contents only (ignoring filenames) to prevent false "changed" detection from simple file renames

### Key Entities

- **Content Hash**: An 8-character truncated SHA256 hash representing the current state of file dependencies. Used as version identifier for hooks.
- **Build Manifest**: A JSON document containing comprehensive metadata about a specific image build, including all hook versions, dependency tracking, package changes, and build environment details.
- **User Hook**: An executable script that runs during user's first login or when content versions change. Uses version-script to track execution state.
- **Hook Dependency**: A file or set of files whose content determines whether a hook needs to re-execute. Changes to dependencies trigger new version hashes.
- **Version Placeholder**: A literal string `__CONTENT_VERSION__` embedded in hook template scripts, replaced with actual computed hash during build process.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Zero manual version number updates required in hook scripts after initial implementation
- **SC-002**: Hooks re-execute only when their specific dependencies change, not on every rebuild (verified by testing 3 sequential builds: clean, no changes, single dependency change)
- **SC-003**: Build manifest generation completes within 5 seconds for typical repository size (under 100MB of tracked files). Typical repository includes ~20 wallpaper images, ~50 VS Code extensions in list, ~300 packages in packages.json, and ~10 hook scripts.
- **SC-004**: Welcome hook displays build summary in under 1 second on first boot
- **SC-005**: Content hash computation produces identical results for unchanged files across 100 consecutive builds
- **SC-006**: Users can view build information on demand after initial boot within 2 seconds
- **SC-007**: New hooks following the documented template pattern successfully integrate content versioning without code review assistance (measured by first-time success rate)
- **SC-008**: Build process fails fast with clear error messages when dependency files are missing (no ambiguous runtime failures)
- **SC-009**: All existing hook functionality continues to work without regression after migration to content-based versioning
- **SC-010**: Build manifest file size remains under 50KB to avoid storage concerns in the image

## Assumptions

- The Universal Blue `version-script` function and supporting library (`/usr/lib/ublue/setup-services/libsetup.sh`) are available and stable in the base image
- The `version-script` function supports recording versions only after successful execution (or this behavior will be implemented in hook wrapper logic)
- Standard Unix tools (`sha256sum`, `cat`, `cut`, `jq`) are available in the build environment
- Git repository information is available during build time for commit hash inclusion in manifest
- The build context directory structure remains consistent with current organization
- Hook scripts are executed with bash interpreter and standard error handling (`set -euo pipefail`)
- Build manifest JSON format can evolve in future versions without breaking compatibility as long as required fields remain present
- Package change tracking (added/removed/updated) is desired but can be implemented in a future phase if initial implementation complexity is too high
- The 8-character hash truncation provides sufficient uniqueness for version identification (collision probability acceptably low)
- Hooks run in an environment where they can read files from `/etc/dudley/` directory

## Scope Boundaries

### In Scope

- Automatic content-based versioning for existing user hooks (wallpaper, VS Code extensions, welcome)
- Build manifest generation and storage
- Welcome hook enhancement to display build summary
- Reusable utility functions for content versioning
- Documentation for creating new hooks with content versioning
- Testing for hash computation and hook re-execution logic
- Command-line tool for viewing build information on demand

### Out of Scope

- Automatic package change detection (may be added in Phase 2 if feasible)
- Version history tracking across multiple builds
- Rollback functionality to previous versions
- Web dashboard or GUI for viewing build information
- Notification system for specific types of changes
- Differential update display showing exact extension additions/removals (future enhancement)
- Support for non-bash hooks or alternative scripting languages
- Migration of hooks beyond the three specified (wallpaper, VS Code extensions, welcome)
- Performance optimization for extremely large dependency files (>1GB)

## Dependencies

- Universal Blue base image with `version-script` functionality
- Git repository for commit hash retrieval
- `jq` JSON processor availability in build environment
- Standard Unix utilities: `sha256sum`, `cat`, `cut`, `sed`
- Bash 5.x shell for hook script execution
- Write access to `/etc/dudley/` directory during build process
- Existing build orchestration system that can integrate versioning utility
- Systemd journal for runtime logging (expected to be available in Universal Blue base)

## Security Considerations

- Build manifest stored in `/etc/dudley/` is world-readable, ensuring transparency
- No sensitive information (passwords, keys, tokens) should be included in build manifest
- Content hashes expose dependency file names and structure but not content
- Git commit hash in manifest may reveal repository structure if repo is private (acceptable for public repos)
- Hash computation uses SHA256 for cryptographic strength, though not used for security verification here
- Build manifest integrity depends on image build process security (no runtime tampering protection needed)

## Clarifications

### Session 2025-10-10

- Q: When a hook execution fails partway through but the version-script has already recorded the new content version, what should happen on the next boot? → A: Hook version is only recorded AFTER successful completion (record at end, not beginning)
- Q: When dependency files are missing during build time (FR-020 "handle gracefully"), what should the system do? → A: Fail the build with clear error message (missing dependencies are build-time errors)
- Q: What logging/debugging capabilities should be available when hash computation or hook execution fails? → A: Standard: Write to systemd journal with structured metadata (hook name, dependencies, hashes)
- Q: Should the content hash computation include the hook script itself as a dependency, or only the data files it processes? → A: Hash both script AND data files together - any change to script or data triggers re-execution
- Q: When identical wallpaper content exists under different filenames, should the system detect this and treat them as unchanged? → A: Yes - compute combined hash of file contents only (ignore filenames), prevent false "changed" signals

## Open Questions

None - all critical decisions have been resolved with documented assumptions.
