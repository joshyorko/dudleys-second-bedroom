<!--
Sync Impact Report:
- Version change: 1.0.0 → 1.1.0
- Modified Principles: None
- Added Principles:
  - VI. Supply Chain Integrity (NEW)
- Added Sections:
  - Supply Chain Requirements (NEW subsection under Build System Constraints)
- Removed Sections: None
- Templates requiring updates:
  - ✅ plan-template.md (generic, no changes needed)
  - ✅ spec-template.md (generic, no changes needed)
  - ✅ tasks-template.md (generic, no changes needed)
- Follow-up TODOs: None
-->
# Dudley's Second Bedroom Constitution

## Core Principles

### I. Modular & Ordered Execution
The build process is a sequence of discrete, ordered modules. Each module must be self-contained and respect the execution order (Shared -> Desktop/Developer -> User Hooks). Modules must not rely on side effects of subsequent modules.

### II. Declarative Over Imperative
Configuration (packages, extensions, flatpaks) MUST be defined in declarative files (`packages.json`, `*.list`), not hardcoded in scripts. Imperative logic is reserved for the *application* of these configurations, not the definition.

### III. Content-Addressable State
Critical user-facing state (wallpapers, first-boot hooks) MUST be versioned by content hash to ensure correct updates and cache invalidation. The manifest generation system is the source of truth for these versions.

### IV. Idempotency & Safety
All build modules and user hooks MUST be idempotent. They must handle re-execution gracefully without duplicating state or causing errors. `set -euo pipefail` is mandatory for all shell scripts to ensure fail-fast behavior.

### V. Mandatory Validation
No changes are complete without passing the relevant validation suites (`just check`, `validate-modules.sh`). Validation scripts are the primary gatekeepers for code quality and correctness.

### VI. Supply Chain Integrity
Production images MUST include verifiable provenance and software bill of materials. All images built from the default branch MUST be signed (dual key-based and keyless OIDC signatures), include an SBOM (SPDX JSON format), and carry SLSA provenance attestation. This ensures end users can verify the authenticity and contents of any image they deploy.

## Build System Constraints

### Module Contract
Every build module MUST adhere to the standard header format, including Purpose, Category, Dependencies, and Parallel-Safe/Cache-Friendly flags. Modules failing validation will reject the build.

### File System Hierarchy
Modules must operate within the `/ctx` context during build and target `/usr/share/dudley` or standard system paths. Hardcoded paths outside these boundaries are prohibited.

### Supply Chain Requirements
- **SBOM Generation**: Every production build MUST generate an SPDX JSON software bill of materials.
- **Provenance Attestation**: Production images MUST include SLSA v0.2 provenance capturing Git SHA and workflow context.
- **Dual Signatures**: Images MUST carry both key-based (`cosign.pub`) and keyless (GitHub OIDC) signatures.
- **Metadata Archival**: Build context (specs, docs, build_files) MUST be archived as an OCI artifact for traceability.
- **Verification Tools**: The repository MUST provide verification scripts (`tests/verify-supply-chain.sh`) and documentation (`docs/SIGNATURE-VERIFICATION.md`).

## Development Workflow

### Validation-First
Developers MUST run `just check` before submitting changes. This includes linting (shellcheck), formatting (shfmt), and custom validation scripts.

### Documentation
Changes to the build architecture or module contracts MUST be reflected in `docs/` and `specs/`. The `copilot-instructions.md` file serves as the canonical reference for AI assistance and must be kept in sync.

## Governance

### Amendment Process
Amendments to this constitution require a Pull Request with a clear rationale. The `CONSTITUTION_VERSION` must be incremented according to semantic versioning:
- **MAJOR**: Backward incompatible governance/principle removals or redefinitions.
- **MINOR**: New principle/section added or materially expanded guidance.
- **PATCH**: Clarifications, wording, typo fixes, non-semantic refinements.

### Compliance
All Pull Requests must be reviewed against these principles. Deviations must be explicitly justified and approved by maintainers.

### Version History
| Version | Date | Summary |
|---------|------|---------|
| 1.0.0 | 2025-11-21 | Initial ratification with 5 core principles |
| 1.1.0 | 2026-01-01 | Added Principle VI (Supply Chain Integrity) and Supply Chain Requirements |

**Version**: 1.1.0 | **Ratified**: 2025-11-21 | **Last Amended**: 2026-01-01
