# Implementation Plan: Upgrade Dudley into a Full OCI Supply-Chain Project

**Branch**: `004-oci-supply-chain` | **Date**: 2025-12-02 | **Spec**: [specs/004-oci-supply-chain/spec.md](specs/004-oci-supply-chain/spec.md)
**Input**: Feature specification from `/specs/004-oci-supply-chain/spec.md`

## Summary

This feature upgrades the Dudley build pipeline to a full OCI supply-chain compliant project. It introduces automated SBOM generation (Trivy), SLSA provenance attestation (Cosign), dual signing (Key-pair + OIDC), and metadata artifact attachment (ORAS). These enhancements ensure image integrity, auditability, and compliance with modern security standards.

## Technical Context

**Language/Version**: Bash, YAML (GitHub Actions)
**Primary Dependencies**: `cosign` (v2+), `trivy`, `oras`, `jq`, `skopeo` (for digest inspection)
**Storage**: OCI Registry (ghcr.io)
**Testing**: `cosign verify`, `oras discover`, `bats` (for validation scripts)
**Target Platform**: GitHub Actions (CI), Fedora Atomic (Runtime)
**Project Type**: Container Build System
**Performance Goals**: Minimal impact on build duration (< 2 mins overhead)
**Constraints**: Must run within GitHub Actions runners; Keyless signing requires OIDC token.
**Scale/Scope**: Single container image, multiple associated OCI artifacts.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Modular & Ordered Execution**: The new CI steps occur *after* the container build, respecting the existing module order.
- **II. Declarative Over Imperative**: Signature policies are declarative configuration files.
- **III. Content-Addressable State**: OCI artifacts are immutable and content-addressable.
- **IV. Idempotency & Safety**: Signing and attestation operations are idempotent (append-only or replace).
- **V. Mandatory Validation**: New validation steps (`verify-build.sh` updates) will be added.

## Project Structure

### Documentation (this feature)

```text
specs/004-oci-supply-chain/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (N/A for this feature)
└── tasks.md             # Phase 2 output
```

### Source Code (repository root)

```text
.github/workflows/
└── build.yml            # Modified to include supply chain steps

tests/
└── verify-supply-chain.sh # New validation script
```

**Structure Decision**: The logic resides primarily in the CI workflow (`build.yml`) as these are post-build supply chain operations. A new test script will verify the artifacts.

**Note**: `build_files/shared/signing.sh` is out of scope for this feature. All signing operations occur in CI (`build.yml`) using the existing `COSIGN_PRIVATE_KEY` secret and keyless OIDC. The signing.sh module handles image-level signing configuration, not supply chain attestations.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | | |
