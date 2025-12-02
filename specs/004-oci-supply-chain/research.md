# Research: OCI Supply Chain Upgrade

## Unknowns & Clarifications

### 1. CI vs Build Time
**Question**: Should signing/attestation happen in `Containerfile` or CI?
**Finding**: These are post-build operations that interact with the registry. They must happen in the CI pipeline (`build.yml`) after the `push` step.
**Decision**: Modify `.github/workflows/build.yml`.

### 2. Keyless Signing Configuration
**Question**: How to enable keyless signing in GitHub Actions?
**Finding**: Requires `id-token: write` permission (already present). `cosign sign` without a key argument defaults to keyless (OIDC) mode.
**Decision**: Add a second `cosign sign` step for keyless signing.

### 3. Metadata Artifact Packaging
**Question**: How to package and attach `specs/`, `docs/`, `build_files/`?
**Finding**: `tar` can create the archive. `oras push` can attach it as a distinct artifact type.
**Decision**:
1. Create `metadata.tar.gz`.
2. `oras push ${IMAGE_REGISTRY}/${IMAGE_NAME}:sha256-${DIGEST}.metadata metadata.tar.gz:application/vnd.dudley.metadata.v1`

### 4. SBOM Generation
**Question**: Best tool for SBOM?
**Finding**: `syft` is the standard. It can generate SPDX JSON which `cosign attach sbom` expects.
**Decision**: Use `anchore/sbom-action` to generate, then `cosign attach sbom` to upload.

## Technology Choices

### Cosign (Sigstore)
**Rationale**: Industry standard for container signing and attestation. Supports both key-based and keyless workflows.
**Alternatives**: `skopeo` (signing only, no attestation), `notary` (v1 is deprecated, v2 is `notation` - less integrated with GitHub Actions than Cosign).

### ~~Syft (Anchore)~~ → Trivy (Aquasecurity)
**Original Rationale**: Syft was chosen as best-in-class SBOM generator with excellent Cosign integration.
**Update (2025-12-02)**: Switched to `trivy` due to performance issues with syft on large images (~13GB Bluefin-DX). Trivy generates valid SPDX JSON significantly faster.
**Alternatives**: `syft` (original choice, slower), `docker sbom` (uses syft under the hood).

### ORAS (OCI Registry as Storage)
**Rationale**: Native way to push arbitrary artifacts (metadata) to OCI registries.
**Alternatives**: Embedding metadata in image labels (size limits), separate git repo (disconnects metadata from image version).

## Implementation Strategy

1. **Install Tools**: Add `trivy` and `oras` setup steps to `build.yml`.
2. **Generate Artifacts**: Run `trivy` and `tar` after build.
3. **Push & Sign**:
   - Push image.
   - Sign image (Key).
   - Sign image (Keyless).
   - Attach SBOM.
   - Attest Provenance.
   - Push Metadata.
