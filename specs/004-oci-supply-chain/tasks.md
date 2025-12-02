# Tasks: Upgrade Dudley into a Full OCI Supply-Chain Project

**Input**: Design documents from `/specs/004-oci-supply-chain/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, quickstart.md

**Tests**: Not explicitly requested in the feature specification. Tests are included as validation scripts per project convention.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

- **CI Workflow**: `.github/workflows/build.yml`
- **Validation Scripts**: `tests/`
- **Documentation**: `docs/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add required tooling and CI infrastructure for supply chain operations

 - [x] T001 Add `syft` setup step to install SBOM generator in `.github/workflows/build.yml`  # implemented in .github/workflows/build.yml
 - [x] T002 [P] Add `oras` setup step to install OCI artifact tool in `.github/workflows/build.yml`  # implemented in .github/workflows/build.yml
 - [x] T003 [P] Add `COSIGN_PRIVATE_KEY` secret documentation to README.md for key-based signing  # README.md updated
 - [x] T004 Update `permissions` block in `.github/workflows/build.yml` to ensure `id-token: write` for OIDC signing  # permissions already included for build_push

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core signing and attestation infrastructure that MUST be complete before user stories

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

 - [x] T005 Refactor existing signing step in `.github/workflows/build.yml` to use `COSIGN_PRIVATE_KEY` secret name (currently uses `SIGNING_SECRET`)  # build.yml now consumes secrets.COSIGN_PRIVATE_KEY
 - [x] T006 Add condition to skip signing/attestation when not on main branch (local/PR builds) in `.github/workflows/build.yml`  # existing if guards preserved/enforced for signing/attestation
 - [x] T007 [P] Create verification script skeleton at `tests/verify-supply-chain.sh` with function stubs  # added initial script with stubs
 - [x] T008 Add error handling to fail build if SBOM generation, provenance attestation, OR metadata artifact (ORAS push) steps fail in `.github/workflows/build.yml`  # run steps use `set -euo pipefail` and explicit checks

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Verify Image Provenance & SBOM (Priority: P1) 🎯 MVP

**Goal**: Enable security-conscious users to verify provenance and inspect SBOM of the Dudley image

**Independent Test**: Run `cosign verify-attestation --type slsaprovenance` and `cosign download sbom` against built image

### Implementation for User Story 1

 - [x] T009 [US1] Add SBOM generation step using `anchore/sbom-action` in `.github/workflows/build.yml`  # implemented using syft in the workflow
 - [x] T010 [US1] Add `cosign attach sbom` step to attach SBOM to pushed image in `.github/workflows/build.yml`  # implemented in build.yml
 - [x] T011 [US1] Create provenance predicate JSON (SLSA v0.2) containing Git SHA and workflow run ID in `.github/workflows/build.yml`  # predicate.json generation added
 - [x] T012 [US1] Add `cosign attest` step to attach SLSA provenance attestation in `.github/workflows/build.yml`  # cosign attest step added
 - [x] T013 [US1] Implement SBOM verification function in `tests/verify-supply-chain.sh`  # implemented (cosign download + basic jq checks)
 - [x] T014 [US1] Implement provenance verification function in `tests/verify-supply-chain.sh`  # implemented (cosign verify-attestation)

**Checkpoint**: User Story 1 complete - SBOM and provenance can be verified for any built image

---

## Phase 4: User Story 2 - Access Build Metadata (Priority: P2)

**Goal**: Enable developers/auditors to access specs, docs, and build_files associated with a specific image version

**Independent Test**: Run `oras discover` and `oras pull` to retrieve metadata artifact for image digest

### Implementation for User Story 2

- [x] T015 [US2] Add step to create `metadata.tar.gz` from `specs/`, `docs/`, and `build_files/` in `.github/workflows/build.yml`  # implemented in build.yml
- [x] T016 [US2] Add step to extract image digest and construct metadata tag (`sha256-<digest>.metadata`) in `.github/workflows/build.yml`  # implemented in build.yml
- [x] T017 [US2] Add `oras push` step to attach metadata artifact with type `application/vnd.dudley.metadata.v1` in `.github/workflows/build.yml`  # implemented in build.yml
- [x] T018 [US2] Implement metadata artifact verification function in `tests/verify-supply-chain.sh`  # implemented verify_metadata function
- [x] T019 [P] [US2] Add ORAS discovery example to `specs/004-oci-supply-chain/quickstart.md`  # comprehensive examples added

**Checkpoint**: User Story 2 complete - metadata can be discovered and pulled for any built image

---

## Phase 5: User Story 3 - Enforce Signature Policy (Priority: P3)

**Goal**: Enable sysadmins to enforce signature verification so only trusted images can be booted

**Independent Test**: Configure `registries.d` policy and verify `bootc switch` behavior with signed/unsigned images

### Implementation for User Story 3

- [x] T020 [P] [US3] Create example signature policy file at `docs/signature-policy/policy.json`  # created with key-based and keyless examples
- [x] T021 [P] [US3] Create example registries.d configuration at `docs/signature-policy/dudley.yaml`  # created with sigstore configuration
- [x] T022 [US3] Write documentation for signature enforcement setup in `docs/SIGNATURE-VERIFICATION.md`  # comprehensive guide created
- [x] T023 [US3] Add signature verification commands to `specs/004-oci-supply-chain/quickstart.md`  # commands added with examples
- [x] T024 [US3] Implement key-based signature verification function in `tests/verify-supply-chain.sh`  # implemented verify_signature_key function

**Checkpoint**: User Story 3 complete - documentation and policy examples available for signature enforcement

---

## Phase 6: User Story 4 - Keyless Verification (Priority: P4)

**Goal**: Enable users to verify the image using GitHub OIDC identity without managing public keys

**Independent Test**: Run `cosign verify` with OIDC issuer and repository subject against built image

### Implementation for User Story 4

- [x] T025 [US4] Add keyless signing step using `cosign sign` without key argument in `.github/workflows/build.yml`  # implemented keyless OIDC signing step
- [x] T026 [US4] Ensure dual signing (key-pair + OIDC) occurs for main branch builds in `.github/workflows/build.yml`  # both signing methods active
- [x] T027 [US4] Add keyless verification example to `specs/004-oci-supply-chain/quickstart.md`  # examples with OIDC issuer and identity
- [x] T028 [US4] Update `docs/SIGNATURE-VERIFICATION.md` with keyless verification instructions  # complete keyless section added
- [x] T029 [US4] Implement OIDC signature verification function in `tests/verify-supply-chain.sh`  # implemented verify_signature_oidc function

**Checkpoint**: User Story 4 complete - both key-based and keyless verification work for images

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final integration, documentation, and validation

- [x] T030 [P] Update README.md with supply chain verification section  # comprehensive verification section added
- [x] T031 [P] Add supply chain section to `docs/DEVELOPER-GUIDE.md`  # supply chain security section added
- [ ] T032 Run `tests/verify-supply-chain.sh` against a test build to validate all functions  # requires published image to test
- [ ] T033 Run quickstart.md validation commands against published image  # requires published image to test
- [x] T034 Update `.github/workflows/build.yml` with inline comments explaining supply chain steps  # detailed comments added
- [x] T035 Run `just check` to validate all changes pass project validation  # all checks passed

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-6)**: All depend on Foundational phase completion
  - User stories can proceed in priority order (P1 → P2 → P3 → P4)
  - Some tasks within stories can run in parallel
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational - Independent of US1
- **User Story 3 (P3)**: Can start after Foundational - Requires signing to be working (US1 provides context)
- **User Story 4 (P4)**: Can start after Foundational - Extends US1 signing with keyless mode

### Within Each User Story

- CI workflow changes before verification script updates
- Core implementation before documentation
- Story complete before moving to next priority

### Parallel Opportunities

- T002, T003 can run in parallel with T001
- T007 can run in parallel with T005, T006
- T019 can run in parallel with T015-T018
- T020, T021 can run in parallel
- T030, T031 can run in parallel

---

## Parallel Example: User Story 1

```bash
# These tasks are sequential (workflow dependencies):
T009 → T010  # SBOM generation then attachment
T011 → T012  # Provenance creation then attestation

# Verification tasks can start once workflow is ready:
T013, T014  # Both verification functions can be developed in parallel
```

## Parallel Example: User Story 3

```bash
# Launch documentation tasks in parallel:
Task T020: "Create example signature policy file at docs/signature-policy/policy.json"
Task T021: "Create example registries.d configuration at docs/signature-policy/dudley.yaml"

# Then sequential:
T022 → T023 → T024  # Documentation, quickstart update, verification function
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T004)
2. Complete Phase 2: Foundational (T005-T008)
3. Complete Phase 3: User Story 1 (T009-T014)
4. **STOP and VALIDATE**: Test SBOM download and provenance verification
5. Deploy/demo if ready - users can now verify image integrity

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 (SBOM + Provenance) → Test → Deploy (MVP!)
3. Add User Story 2 (Metadata Artifacts) → Test → Deploy
4. Add User Story 3 (Signature Policy Docs) → Test → Deploy
5. Add User Story 4 (Keyless Signing) → Test → Deploy
6. Each story adds verification capability without breaking previous stories

### File Modification Summary

| File | Stories | Tasks |
|------|---------|-------|
| `.github/workflows/build.yml` | US1, US2, US4 | T001-T002, T004-T006, T008-T012, T015-T017, T025-T026, T034 |
| `tests/verify-supply-chain.sh` | US1, US2, US3, US4 | T007, T013-T014, T018, T024, T029 |
| `docs/SIGNATURE-VERIFICATION.md` | US3, US4 | T022, T028 |
| `docs/signature-policy/` | US3 | T020-T021 |
| `specs/004-oci-supply-chain/quickstart.md` | US2, US3, US4 | T019, T023, T027 |
| `README.md` | Setup, Polish | T003, T030 |
| `docs/DEVELOPER-GUIDE.md` | Polish | T031 |

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- FR-009 mandates build failure on any supply chain step failure
- FR-010 mandates dual signing (key + OIDC) on main branch
- FR-012 mandates skipping signing in local/non-CI environments
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
