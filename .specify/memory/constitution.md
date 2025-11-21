<!--
Sync Impact Report:
- Version change: 1.0.0 (Initial)
- Added Principles:
  - I. Modular & Ordered Execution
  - II. Declarative Over Imperative
  - III. Content-Addressable State
  - IV. Idempotency & Safety
  - V. Mandatory Validation
- Added Governance: Standard amendment process.
- Templates requiring updates: None (Templates are generic enough).
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

## Build System Constraints

### Module Contract
Every build module MUST adhere to the standard header format, including Purpose, Category, Dependencies, and Parallel-Safe/Cache-Friendly flags. Modules failing validation will reject the build.

### File System Hierarchy
Modules must operate within the `/ctx` context during build and target `/usr/share/dudley` or standard system paths. Hardcoded paths outside these boundaries are prohibited.

## Development Workflow

### Validation-First
Developers MUST run `just check` before submitting changes. This includes linting (shellcheck), formatting (shfmt), and custom validation scripts.

### Documentation
Changes to the build architecture or module contracts MUST be reflected in `docs/` and `specs/`. The `copilot-instructions.md` file serves as the canonical reference for AI assistance and must be kept in sync.

## Governance

### Amendment Process
Amendments to this constitution require a Pull Request with a clear rationale. The `CONSTITUTION_VERSION` must be incremented according to semantic versioning.

### Compliance
All Pull Requests must be reviewed against these principles. Deviations must be explicitly justified and approved by maintainers.

**Version**: 1.0.0 | **Ratified**: 2025-11-21 | **Last Amended**: 2025-11-21
