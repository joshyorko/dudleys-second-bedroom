---
description: "Task list for Configurable Base Image feature"
---

# Tasks: Configurable Base Image

**Input**: Design documents from `/specs/003-configurable-base-image/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Tests are included as manual verification steps or script updates where applicable.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [x] T001 [US1] Update Containerfile to use ARG for base image in `Containerfile`

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core build system changes required for all stories

- [x] T002 [US1] Update Justfile to pass BASE_IMAGE build arg if set in `Justfile`
- [x] T003 [US1] Verify default build behavior remains unchanged (Manual Test)

## Phase 3: User Story 1 - Default Build Configuration (Priority: P1)

**Goal**: Ensure the build system uses the standard Bluefin DX image by default.

**Independent Test**: Run `just build` without arguments and verify `bluefin-dx` is used.

- [x] T004 [US1] Verify Containerfile default ARG value matches current base in `Containerfile`
- [x] T005 [US1] Verify Justfile does not pass empty build arg when env var is unset in `Justfile`

## Phase 4: User Story 2 - Custom Base Image via Environment Variable (Priority: P2)

**Goal**: Allow developers to override the base image using `BASE_IMAGE` environment variable.

**Independent Test**: Run `BASE_IMAGE=ghcr.io/ublue-os/aurora-dx:stable just build` and verify output.

- [x] T006 [US2] Test local build with custom BASE_IMAGE env var (Manual Test)
- [x] T007 [US2] Verify build fails with invalid BASE_IMAGE (Manual Test)
- [x] T008 [US2] Document BASE_IMAGE usage in `docs/DEVELOPER-GUIDE.md`

## Phase 5: User Story 3 - Custom Base Image via CI Input (Priority: P2)

**Goal**: Allow release managers to trigger builds with custom base images in CI.

**Independent Test**: Trigger `workflow_dispatch` with `base_image` input.

- [x] T009 [US3] Add workflow_dispatch input for base_image in `.github/workflows/build.yml`
- [x] T010 [US3] Update build job to pass base_image input to buildah-build action in `.github/workflows/build.yml`
- [x] T011 [US3] Configure CI workflow to omit BASE_IMAGE build arg when input is empty in `.github/workflows/build.yml`

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final cleanup and documentation

- [x] T012 Update quickstart documentation in `README.md` to include custom base image instructions
- [x] T013 Verify build logs show the base image being used

## Dependencies

- US1 (Default Config) must be completed first as it modifies the core `Containerfile`.
- US2 (Env Var) and US3 (CI Input) can be implemented in parallel after US1.

## Implementation Strategy

1.  **MVP**: Implement US1 (Containerfile changes) and US2 (Justfile changes) to enable local overrides.
2.  **CI**: Implement US3 to expose this capability in GitHub Actions.
