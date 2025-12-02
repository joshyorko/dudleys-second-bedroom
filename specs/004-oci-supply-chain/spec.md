# Feature Specification: Upgrade Dudley into a Full OCI Supply-Chain Project

**Feature Branch**: `004-oci-supply-chain`
**Created**: 2025-11-24
**Status**: Draft
**Input**: User description: "Upgrade Dudley into a Full OCI Supply-Chain Project"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Verify Image Provenance & SBOM (Priority: P1)

As a security-conscious user, I want to verify the provenance and inspect the SBOM of the Dudley image so that I can trust the build process and components.

**Why this priority**: Core requirement for supply chain security and compliance.

**Independent Test**: Can be tested by pulling the image and running `cosign verify-attestation` and `cosign download sbom`.

**Acceptance Scenarios**:

1. **Given** a built image in the registry, **When** I run `cosign verify-attestation --type slsaprovenance`, **Then** it should pass and show the GitHub Actions provenance details (commit SHA, workflow run).
2. **Given** a built image in the registry, **When** I run `cosign download sbom`, **Then** I should receive a valid SPDX JSON SBOM file.

---

### User Story 2 - Access Build Metadata (Priority: P2)

As a developer or auditor, I want to access the build specs and docs associated with a specific image version so that I have the exact context for that build without needing to clone the repo at that specific commit.

**Why this priority**: Enhances transparency and auditability of the build artifacts.

**Independent Test**: Can be tested by running `oras pull` to retrieve the metadata artifact associated with the image digest.

**Acceptance Scenarios**:

1. **Given** a built image digest, **When** I run `oras discover <image-digest>`, **Then** I should see the metadata artifact with type `application/vnd.dudley.metadata.v1`.
2. **Given** the metadata artifact digest, **When** I run `oras pull <artifact-digest>`, **Then** I should get a tarball containing `specs/`, `docs/`, and `build_files/`.

---

### User Story 3 - Enforce Signature Policy (Priority: P3)

As a system administrator, I want to enforce signature verification on my Dudley systems so that only trusted images signed by the project key (or OIDC identity) can be booted or updated to.

**Why this priority**: Hardens the runtime environment against tampering.

**Independent Test**: Can be tested by configuring `/etc/containers/registries.d` and attempting to `bootc switch` to a signed and an unsigned image.

**Acceptance Scenarios**:

1. **Given** a configured signature policy enforcing the Dudley key, **When** I run `bootc switch` to the signed Dudley image, **Then** the operation should succeed.
2. **Given** a configured signature policy enforcing the Dudley key, **When** I run `bootc switch` to an unsigned or untrusted image, **Then** the operation should fail with a signature verification error.

---

### User Story 4 - Keyless Verification (Priority: P4)

As a user who prefers OIDC-based trust, I want to verify the image using GitHub OIDC identity so that I don't have to manage public keys manually.

**Why this priority**: Provides a modern, keyless alternative for verification.

**Independent Test**: Can be tested using `cosign verify` with the OIDC issuer and subject.

**Acceptance Scenarios**:

1. **Given** a built image signed with keyless mode, **When** I run `cosign verify` specifying the GitHub OIDC issuer and repository subject, **Then** the verification should succeed.

### Edge Cases

- What happens if SBOM generation fails? The build pipeline should fail.
- What happens if the image is already signed? Cosign should append the new signature/attestation.
- How does the system handle missing metadata? `oras pull` will fail, but the image itself should still be usable.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The build pipeline MUST generate an SBOM for the image in SPDX JSON format using `syft`.
- **FR-002**: The build pipeline MUST attach the generated SBOM to the image in the registry using `cosign attach sbom`.
- **FR-003**: The build pipeline MUST generate a SLSA-style provenance attestation including the Git commit SHA and GitHub workflow run ID.
- **FR-004**: The build pipeline MUST attach the provenance attestation to the image using `cosign attest`.
- **FR-005**: The build pipeline MUST package **exclusively** the `specs/`, `docs/`, and `build_files/` directories into a compressed archive (tarball).
- **FR-006**: The build pipeline MUST attach the metadata archive as an OCI artifact to the image using `oras`, using the tag naming convention `sha256-<digest>.metadata` to link it to the image digest.
- **FR-007**: The project MUST provide documentation and an example `registries.d` policy file for enforcing signature verification. This policy MUST NOT be embedded in the image itself.
- **FR-008**: The build pipeline MUST support optional keyless signing using GitHub OIDC. The documented verification procedure MUST enforce the `refs/heads/main` branch constraint.
- **FR-009**: The build pipeline MUST fail if any of the artifact generation or attachment steps (SBOM, provenance, ORAS) fail.
- **FR-010**: The build pipeline MUST perform "Dual Signing" (both key-pair and OIDC) for every build on the `main` branch.
- **FR-011**: The CI pipeline MUST retrieve the signing key from the `COSIGN_PRIVATE_KEY` repository secret.
- **FR-012**: The build pipeline MUST skip signing, attestation, and SBOM attachment steps when running in a local environment (non-CI).

### Key Entities *(include if feature involves data)*

- **Image**: The bootc container image (OS artifact).
- **SBOM**: Software Bill of Materials describing the packages in the image.
- **Provenance**: Attestation describing how and where the image was built.
- **Metadata Artifact**: An OCI artifact containing project documentation and specifications, linked to the image.
- **Signature Policy**: Configuration defining trusted keys and identities for image verification.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Provenance verification of the built image succeeds using the project's standard verification tool.
- **SC-002**: A valid SPDX JSON SBOM can be retrieved for the image from the registry.
- **SC-003**: Metadata artifacts (specs, docs) can be discovered and retrieved from the registry.
- **SC-004**: Systems configured with signature enforcement successfully boot signed images and reject unsigned ones.
- **SC-005**: Image verification succeeds using OIDC-based identity without requiring local public keys.

## Clarifications

### Session 2025-11-24

- Q: What OIDC subject constraint should be enforced for keyless verification? → A: Repository + Branch (`refs/heads/main`)
- Q: How should the signature enforcement policy be distributed? → A: Documentation only (user installs manually)
- Q: What content should be included in the metadata artifact? → A: Specified directories only (`specs/`, `docs/`, `build_files/`)
- Q: When should keyless signing be triggered? → A: Always (Dual Signing) - Sign with both key-pair and OIDC on every main branch build.

### Session 2025-12-02

- Q: How should the private key for signing be managed in CI? → A: GitHub Repository Secret (`COSIGN_PRIVATE_KEY`)
- Q: How should signing/attestation be handled for local builds? → A: Skip signing/attestation locally (CI only)
- Q: How should the metadata artifact be linked to the image? → A: Tag Naming Convention (e.g., `sha256-<digest>.metadata`)
