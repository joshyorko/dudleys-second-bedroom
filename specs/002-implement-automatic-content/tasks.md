---
description: "Task list for automatic content-based versioning implementation"
---

# Tasks: Automatic Content-Based Versioning for User Hooks

**Input**: Design documents from `/specs/002-implement-automatic-content/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Tests are included per constitution requirement IV (Validation Before Integration). Test scripts verify hash computation, manifest generation, and hook behavior.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure for content versioning utilities

- [X] **T001** [P] Create `build_files/shared/utils/` directory for versioning utilities
- [X] **T002** [P] Create `system_files/shared/etc/dudley/` directory for manifest storage
- [X] **T003** [P] Create `tests/` directory structure for test scripts

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core utility functions and manifest generation that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Utility Functions Implementation

- [X] **T004** Implement `build_files/shared/utils/content-versioning.sh` with header documentation:
  - Function: `compute_content_hash <file1> [file2] ...` (compute 8-char SHA256 hash)
  - Function: `replace_version_placeholder <file> <hash>` (replace `__CONTENT_VERSION__`)
  - Function: `validate_hash_format <hash>` (validate 8 hex chars)
  - Include full header: Purpose, Dependencies, Author, Date per constitution III
  - Source with `set -euo pipefail` for fail-fast behavior (FR-020)
  - Log to stderr with `[dudley-versioning]` prefix for build-time visibility (FR-021)

- [X] **T005** Implement `build_files/shared/utils/manifest-builder.sh` with header documentation:
  - Function: `init_manifest <image_name> <base_image> <commit_sha>` (initialize manifest structure)
  - Function: `add_hook_to_manifest <manifest_json> <hook_name> <version_hash> <dependencies_json> [metadata_json]` (add hook entry)
  - Function: `write_manifest <manifest_json> <output_path>` (write to file with validation)
  - Function: `validate_manifest_schema <manifest_json>` (validate against schema)
  - Include full header documentation per constitution III
  - Use `jq` for all JSON operations (FR-019)
  - Set output file permissions to 644 (world-readable)

### Test Suite for Utilities

- [X] **T006** [P] Implement `tests/test-content-versioning.sh`:
  - Test: Hash determinism (compute same hash 10 times, assert identical)
  - Test: Multi-file ordering (hash(a,b,c) == hash(c,b,a), verifies sorting)
  - Test: Missing file error (assert exit 1, error message contains filename)
  - Test: Placeholder replacement success (assert hash present, placeholder gone)
  - Test: Placeholder replacement - no placeholder (assert warning, exit 0)
  - Test: Hash format validation (valid cases exit 0, invalid exit 1)
  - Use bash test framework with clear pass/fail output

- [X] **T007** [P] Implement `tests/test-manifest-generation.sh`:
  - Test: `init_manifest` creates valid structure (parse with jq, assert fields)
  - Test: `add_hook_to_manifest` adds single hook (assert present, others unchanged)
  - Test: `add_hook_to_manifest` adds multiple hooks (assert all three present)
  - Test: `add_hook_to_manifest` rejects invalid hook name (assert exit 1)
  - Test: `add_hook_to_manifest` rejects invalid hash (assert exit 1)
  - Test: `write_manifest` creates file with 644 permissions (check exists, check perms)
  - Test: `write_manifest` fails on invalid JSON (assert exit 1, file not created)
  - Test: `validate_manifest_schema` passes valid manifest (exit 0)
  - Test: `validate_manifest_schema` fails on missing field (exit 1, error mentions field)
  - Test: `validate_manifest_schema` fails on empty hooks (exit 1)

- [X] **T008** Run utility tests and verify all pass before proceeding:
  ```bash
  bash tests/test-content-versioning.sh
  bash tests/test-manifest-generation.sh
  ```

**Checkpoint**: Foundation ready - utility functions tested and working. User story implementation can now begin.

---

## Phase 3: User Story 1 - Automatic Hook Re-execution Based on Content Changes (Priority: P1) 🎯 MVP

**Goal**: Eliminate manual version management by auto-computing content hashes and injecting them into hooks. Hooks run only when dependencies change.

**Independent Test**: Modify `vscode-extensions.list`, rebuild image, verify only VS Code extensions hook re-runs on boot while other hooks skip.

### Implementation for User Story 1

- [X] **T009** [US1] Create manifest generation orchestration script `build_files/shared/utils/generate-manifest.sh`:
  - Source `content-versioning.sh` and `manifest-builder.sh`
  - Get build metadata: `IMAGE_NAME`, `BASE_IMAGE`, `GIT_COMMIT` (from env or git)
  - Initialize manifest with `init_manifest`
  - Compute hash for wallpaper hook: `compute_content_hash build_files/user-hooks/10-wallpaper-enforcement.sh custom_wallpapers/*`
  - Compute hash for vscode-extensions hook: `compute_content_hash build_files/user-hooks/20-vscode-extensions.sh vscode-extensions.list`
  - Compute hash for welcome hook: `compute_content_hash build_files/user-hooks/99-first-boot-welcome.sh`
  - Add each hook to manifest with `add_hook_to_manifest` (include metadata: extension_count, wallpaper_count)
  - Validate manifest with `validate_manifest_schema`
  - Write manifest to `/etc/dudley/build-manifest.json` with `write_manifest`
  - Add header documentation per constitution III
  - Ensure script is executable: `chmod +x`

- [X] **T010** [US1] Modify `build_files/user-hooks/10-wallpaper-enforcement.sh`:
  - Replace hardcoded version number with `__CONTENT_VERSION__` placeholder
  - Ensure version-script call: `version-script "wallpaper" "__CONTENT_VERSION__"`
  - Ensure script uses `set -euo pipefail` (FR-009a: fail = no version recorded)
  - Add logging: `echo "Dudley Hook: wallpaper starting (version $HOOK_VERSION)"`
  - Add logging: `echo "Dudley Hook: wallpaper completed successfully"` at end
  - Update header documentation to mention content versioning

- [X] **T011** [US1] Modify `build_files/user-hooks/20-vscode-extensions.sh`:
  - Replace hardcoded version number with `__CONTENT_VERSION__` placeholder
  - Ensure version-script call: `version-script "vscode-extensions" "__CONTENT_VERSION__"`
  - Ensure script uses `set -euo pipefail`
  - Add logging: `echo "Dudley Hook: vscode-extensions starting (version $HOOK_VERSION)"`
  - Add logging: `echo "Dudley Hook: vscode-extensions completed successfully"` at end
  - Update header documentation to mention content versioning

- [X] **T012** [US1] Integrate versioning into `Containerfile`:
  - Copy utility scripts: `COPY build_files/shared/utils/*.sh /tmp/build-scripts/`
  - Run manifest generation: `RUN /tmp/build-scripts/generate-manifest.sh`
  - Replace version placeholders in wallpaper hook: `RUN /tmp/build-scripts/content-versioning.sh replace_version_placeholder /usr/share/ublue-os/user-setup.hooks.d/10-wallpaper-enforcement.sh $(compute_content_hash ...)`
  - Replace version placeholders in vscode-extensions hook: `RUN /tmp/build-scripts/content-versioning.sh replace_version_placeholder /usr/share/ublue-os/user-setup.hooks.d/20-vscode-extensions.sh $(compute_content_hash ...)`
  - Ensure manifest is in `/etc/dudley/build-manifest.json`
  - Clean up temp build scripts: `RUN rm -rf /tmp/build-scripts`
  - Add comments explaining each step

- [X] **T013** [US1] Implement `tests/test-hook-integration.sh` for end-to-end validation:
  - Test: Build image, check manifest exists at `/etc/dudley/build-manifest.json`
  - Test: Verify manifest is valid JSON (parse with jq)
  - Test: Verify all three hooks present in manifest with valid version hashes
  - Test: Check hook scripts no longer contain `__CONTENT_VERSION__` placeholder
  - Test: Verify manifest size < 50KB (SC-010)
  - Test: Count VS Code extensions in vscode-extensions.list, verify matches manifest metadata
  - Test: Verify hook scripts are executable (have execute permissions)

- [X] **T014** [US1] Run integration tests and verify User Story 1 acceptance scenarios:
  ```bash
  bash tests/test-hook-integration.sh
  ```
  - Scenario 1: First boot - all hooks execute (verify by checking version files created)
  - Scenario 2: Rebuild with no changes - no hooks re-execute (verify logs show "skip")
  - Scenario 3: Modify vscode-extensions.list - only that hook re-executes
  - Scenario 4: Replace wallpaper image - only wallpaper hook re-executes  
  - Scenario 5: Modify hook script - hook re-executes (hash includes script)

**Checkpoint**: User Story 1 is fully functional - automatic versioning works for all hooks. Test independently before proceeding.

---

## Phase 4: User Story 2 - Build Transparency and Change Summary (Priority: P2)

**Goal**: Enhance welcome hook to read build manifest and display formatted summary of what changed in this build.

**Independent Test**: Create manifest with mock data, verify welcome hook displays formatted change information correctly.

### Implementation for User Story 2

- [X] **T015** [US2] Modify `build_files/user-hooks/99-first-boot-welcome.sh`:
  - Replace hardcoded version with `__CONTENT_VERSION__` placeholder
  - Ensure version-script call: `version-script "welcome" "__CONTENT_VERSION__"`
  - Add logic to read `/etc/dudley/build-manifest.json` with jq
  - Extract and display: Build date, image name, base image, git commit (FR-007)
  - Extract and display: VS Code extension count and changed status (FR-011, FR-018)
  - Extract and display: Wallpaper changed status (FR-011)
  - Format output with clear headers and sections
  - Handle missing manifest gracefully (warn but don't fail - development scenario)
  - Add logging: `echo "Dudley Hook: welcome starting"`
  - Update header documentation

- [X] **T016** [US2] Add metadata tracking to `build_files/shared/utils/generate-manifest.sh`:
  - Compute "changed" flag for each hook (compare current hash to previous, default true)
  - Count VS Code extensions: `wc -l vscode-extensions.list` (FR-018)
  - Count wallpapers: `ls custom_wallpapers/* | wc -l`
  - Include metadata in `add_hook_to_manifest` calls:
    - wallpaper: `{"wallpaper_count": N, "changed": true/false}`
    - vscode-extensions: `{"extension_count": N, "changed": true/false}`
    - welcome: `{"changed": true/false}`

- [X] **T017** [US2] Update `Containerfile` to replace welcome hook placeholder:
  - Add placeholder replacement for `99-first-boot-welcome.sh`
  - Use computed hash of welcome script: `compute_content_hash build_files/user-hooks/99-first-boot-welcome.sh`
  - Ensure manifest includes welcome hook entry

- [X] **T018** [US2] Create command-line tool `build_files/shared/utils/show-build-info.sh` (FR-017):
  - Read and display build manifest from `/etc/dudley/build-manifest.json`
  - Format output same as welcome hook display
  - Make executable and install to `/usr/local/bin/dudley-build-info`
  - Add usage message: `dudley-build-info` or `dudley-build-info --json`
  - Add header documentation

- [X] **T019** [US2] Test User Story 2 acceptance scenarios:
  - Scenario 1: Fresh boot after update - welcome displays change summary (check systemd journal)
  - Scenario 2: Build with new extensions - see updated count and "changed" indicator
  - Scenario 3: Build with updated wallpapers - see "changed" indicator for wallpapers
  - Scenario 4: Package changes - verify displayed (note: may be "future enhancement" per scope)
  - Scenario 5: Run `dudley-build-info` command - displays summary on demand

**Checkpoint**: User Story 2 is functional - welcome message provides transparency. Both US1 and US2 work independently.

---

## Phase 5: User Story 3 - Developer Hook Creation with Content Versioning (Priority: P3)

**Goal**: Document patterns and provide quickstart guide for developers to create new hooks with automatic versioning.

**Independent Test**: Follow quickstart.md to create a new test hook, build image, verify hook behaves correctly (runs on first boot, skips on unchanged rebuilds).

### Implementation for User Story 3

- [X] **T020** [US3] Enhance `specs/002-implement-automatic-content/quickstart.md`:
  - Add real working examples using actual project file paths
  - Add section on adding new hooks to `generate-manifest.sh`
  - Add troubleshooting section with common issues (already present, verify completeness)
  - Add section on testing new hooks locally before committing
  - Add reference to API contracts for advanced usage

- [X] **T021** [US3] Create template hook script `build_files/user-hooks/TEMPLATE-new-hook.sh`:
  - Complete working template following constitution III header format
  - Include `__CONTENT_VERSION__` placeholder correctly positioned
  - Include proper version-script integration
  - Include logging statements
  - Include error handling with `set -euo pipefail`
  - Add extensive comments explaining each section
  - Add TODO markers for customization points

- [X] **T022** [US3] Create `docs/DEVELOPER-GUIDE.md` (or update existing README):
  - Document the content versioning system architecture
  - Explain when hooks run vs skip (version-script behavior)
  - Explain how hashes are computed (deterministic, includes script + data)
  - Document the manifest structure and fields
  - Link to contracts/ for API details
  - Link to quickstart.md for hands-on guide
  - Include examples of all four patterns from quickstart:
    - Single data file dependency
    - Multiple file dependencies
    - Script-only dependency
    - Complex dependencies

- [X] **T023** [US3] Test User Story 3 acceptance scenarios:
  - Scenario 1: Create new hook following template - verify implements versioning correctly
  - Scenario 2: New hook with dependencies - verify re-executes when dependencies change
  - Scenario 3: New hook with multiple files - verify tracks changes to any file
  - Scenario 4: Find documentation for API - verify examples clear and complete
  - Real test: Create `build_files/user-hooks/88-test-new-hook.sh` using template
  - Add to `generate-manifest.sh`, build, verify appears in manifest
  - Boot, verify executes first time, verify skips second boot

**Checkpoint**: All user stories complete and independently functional. Development patterns documented.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories and final validation

- [X] **T024** [P] Add comprehensive header documentation to all scripts per constitution III:
  - Verify `content-versioning.sh` has: Purpose, Dependencies, Author, Date
  - Verify `manifest-builder.sh` has: Purpose, Dependencies, Author, Date
  - Verify `generate-manifest.sh` has: Purpose, Dependencies, Author, Date
  - Verify all modified hooks have updated headers mentioning content versioning

- [X] **T025** [P] Create `tests/run-all-tests.sh` orchestration script:
  - Run `test-content-versioning.sh` and capture result
  - Run `test-manifest-generation.sh` and capture result
  - Run `test-hook-integration.sh` and capture result
  - Report summary: X/Y tests passed
  - Exit with code 1 if any test fails
  - Make executable: `chmod +x`

- [X] **T026** [P] Update main project `README.md`:
  - Add section on content-based versioning system
  - Link to feature spec and design docs
  - Document `dudley-build-info` command for users
  - Note automatic version management (no manual bumping needed)

- [ ] **T027** [P] Validate all success criteria from spec.md (SC-001 through SC-010):
  - SC-001: Zero manual version updates (verify no hardcoded versions in hooks)
  - SC-002: Hooks re-execute only on dependency changes (run 3 builds test)
  - SC-003: Manifest generation < 5 seconds (time the build step)
  - SC-004: Welcome display < 1 second (test first boot timing)
  - SC-005: Hash determinism (100 consecutive builds test - may defer to CI)
  - SC-006: View build info on demand < 2 seconds (test `dudley-build-info`)
  - SC-007: New hook template success (verify TEMPLATE-new-hook.sh works)
  - SC-008: Build fails on missing dependencies (test with missing file)
  - SC-009: No regressions (verify all existing hooks still work)
  - SC-010: Manifest < 50KB (check file size)

- [ ] **T028** Run complete quickstart validation per quickstart.md:
  - Follow "For Existing Hook Developers" section - verify works
  - Follow "For New Hook Developers" section - verify creates working hook
  - Test all four common patterns - verify each works correctly
  - Verify troubleshooting section has accurate debug commands

- [ ] **T029** Code cleanup and final validation:
  - Remove any debug echo statements not needed for production
  - Verify all test scripts are executable
  - Verify all utility scripts are executable
  - Run shellcheck on all new/modified bash scripts
  - Verify JSON schema validates manifest: `jq -e . /etc/dudley/build-manifest.json`
  - Check git status - ensure no untracked build artifacts committed

- [ ] **T030** Create feature summary for documentation:
  - Document what changed (files added/modified)
  - Document breaking changes (none expected, but note if any)
  - Document migration path for other projects using this pattern
  - Update `.github/copilot-instructions.md` if needed (already done by `/speckit.plan`)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
  - Must have working utility functions before any hook can be modified
  - Must have passing tests before proceeding to integration
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User Story 1 (P1): Core functionality - can start after Foundational
  - User Story 2 (P2): Depends on US1 manifest generation being complete
  - User Story 3 (P3): Depends on US1 and US2 working (needs real examples)
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Foundation must be complete (Phase 2)
  - No dependencies on other stories - this is the MVP
  - Delivers: Automatic versioning for all three hooks
  
- **User Story 2 (P2)**: User Story 1 must be complete
  - Requires: Manifest generation from US1 (build manifest structure)
  - Depends on: `generate-manifest.sh` existing and working
  - Delivers: Welcome message enhancement reading manifest
  
- **User Story 3 (P3)**: User Stories 1 and 2 must be complete
  - Requires: Working examples from US1 and US2 to document
  - Depends on: All utilities and patterns established
  - Delivers: Documentation and templates for future developers

### Within Each User Story

**User Story 1**:
- T009 (manifest generation) can start after T004-T008 complete
- T010-T011 (hook modifications) can run in parallel [P] after T009
- T012 (Containerfile) depends on T009-T011 complete
- T013 (integration tests) can run after T012
- T014 (validation) must be last

**User Story 2**:
- T015-T016 can run in parallel [P] (different files)
- T017 depends on T015-T016
- T018 can run in parallel [P] with T015-T017
- T019 (validation) must be last

**User Story 3**:
- T020-T022 can run in parallel [P] (different files)
- T023 (validation) must be last

**Polish Phase**:
- T024-T026 can run in parallel [P] (different files)
- T027-T028 (validation tasks) should run sequentially
- T029-T030 must be last

### Parallel Opportunities

**Within Foundational Phase**:
```bash
# Can run these in parallel after T001-T003:
Task T004: Implement content-versioning.sh
Task T005: Implement manifest-builder.sh

# Can run these in parallel after T004-T005:
Task T006: Test content-versioning.sh
Task T007: Test manifest-generation.sh
```

**Within User Story 1**:
```bash
# Can run these in parallel after T009:
Task T010: Modify wallpaper hook
Task T011: Modify vscode-extensions hook
```

**Within User Story 2**:
```bash
# Can run these in parallel:
Task T015: Modify welcome hook
Task T016: Add metadata tracking
Task T018: Create CLI tool
```

**Within User Story 3**:
```bash
# Can run all documentation in parallel:
Task T020: Enhance quickstart.md
Task T021: Create TEMPLATE-new-hook.sh
Task T022: Create DEVELOPER-GUIDE.md
```

**Within Polish Phase**:
```bash
# Can run these in parallel:
Task T024: Add header documentation
Task T025: Create run-all-tests.sh
Task T026: Update README.md
```

---

## Parallel Example: User Story 1

```bash
# After Foundation complete, launch hook modifications together:
Task T010: "Modify build_files/user-hooks/10-wallpaper-enforcement.sh"
Task T011: "Modify build_files/user-hooks/20-vscode-extensions.sh"

# Both modify different files, can work in parallel
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. **Complete Phase 1**: Setup (T001-T003) - ~15 minutes
2. **Complete Phase 2**: Foundational (T004-T008) - ~4 hours
   - Implement utilities: ~2 hours
   - Write and pass tests: ~2 hours
   - **CRITICAL CHECKPOINT**: Tests must pass before proceeding
3. **Complete Phase 3**: User Story 1 (T009-T014) - ~4 hours
   - Manifest generation: ~1 hour
   - Hook modifications: ~1 hour
   - Containerfile integration: ~1 hour
   - Integration tests: ~1 hour
4. **STOP and VALIDATE**: Test User Story 1 independently
   - Build image
   - Boot and verify all hooks run first time
   - Rebuild with no changes, verify hooks skip
   - Change vscode-extensions.list, verify only that hook runs
   - If all pass: **MVP COMPLETE** ✅
5. Deploy/demo MVP if ready

**Estimated MVP Time**: ~8-9 hours of focused work

### Incremental Delivery

1. **Foundation** (Phase 1-2) → Utility functions ready
2. **Add User Story 1** (Phase 3) → Test independently → **MVP Release**
3. **Add User Story 2** (Phase 4) → Test independently → **Enhanced Release**
4. **Add User Story 3** (Phase 5) → Test independently → **Developer-Ready Release**
5. **Polish** (Phase 6) → Final validation → **Production Release**

Each phase adds value without breaking previous work.

### Parallel Team Strategy

With multiple developers:

1. **Together**: Complete Setup + Foundational (critical path)
2. **Once Foundational done**:
   - **Developer A**: User Story 1 (T009-T014) - ~4 hours
   - **Developer B**: Start on User Story 2 docs (T020-T022 prep work)
3. **After US1 complete**:
   - **Developer A**: User Story 2 (T015-T019) - ~3 hours
   - **Developer B**: User Story 3 (T020-T023) - ~3 hours (starts immediately)
4. **Polish**: Both work on validation and cleanup (T024-T030)

**Estimated Parallel Time**: ~7-8 hours total with 2 developers

---

## Notes

- **[P] tasks** = different files, no dependencies, can run in parallel
- **[Story] label** maps task to specific user story for traceability
- Each user story should be independently completable and testable
- **Tests before implementation**: Follow TDD within each story phase
- Commit after each task or logical group
- Stop at checkpoints to validate story independently
- **Constitution compliance**: Header docs (III), tests (IV), modularity (I)
- All bash scripts must use `set -euo pipefail` for fail-fast
- All new scripts must be executable: `chmod +x`
- Manifest must be valid JSON parseable by `jq`

---

## Task Summary

**Total Tasks**: 30
- Phase 1 (Setup): 3 tasks
- Phase 2 (Foundational): 5 tasks (BLOCKING)
- Phase 3 (User Story 1 - P1): 6 tasks 🎯 MVP
- Phase 4 (User Story 2 - P2): 5 tasks
- Phase 5 (User Story 3 - P3): 4 tasks
- Phase 6 (Polish): 7 tasks

**Parallel Opportunities**: 12 tasks marked [P] can run in parallel within their phase

**Independent Test Criteria**:
- **US1**: Modify dependency file → rebuild → verify only that hook re-runs
- **US2**: Check welcome message → verify displays correct build info
- **US3**: Create new hook from template → verify runs on first boot, skips on second

**Suggested MVP Scope**: Phase 1-3 (User Story 1 only) = Core automatic versioning

**Estimated Timeline**:
- Solo developer (sequential): ~12-15 hours
- Two developers (parallel): ~7-8 hours
- MVP only (US1): ~8-9 hours
