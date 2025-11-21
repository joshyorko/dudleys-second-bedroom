# Implementation Plan: Configurable Base Image

**Branch**: `003-configurable-base-image` | **Date**: 2025-11-21 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-configurable-base-image/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Enable configuration of the build's base image via the `BASE_IMAGE` environment variable (local) and a workflow input (CI). Defaults to `ghcr.io/ublue-os/bluefin-dx:stable` if unspecified. This allows developers to test against alternative Universal Blue upstreams (e.g., Aurora, Bazzite) without code changes.

## Technical Context

**Language/Version**: Containerfile (OCI), Bash 5.x, YAML (GitHub Actions)
**Primary Dependencies**: `podman`/`buildah` (Build Tooling), GitHub Actions
**Storage**: N/A
**Testing**: Manual verification of build output; `tests/verify-build.sh`
**Target Platform**: Linux (Container Build)
**Project Type**: System Configuration / Build System
**Performance Goals**: Zero impact on standard build times.
**Constraints**: Must maintain compatibility with UBlue module system.
**Scale/Scope**: Modifies `Containerfile`, `Justfile`, and `.github/workflows/build.yml`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Modular & Ordered Execution**: N/A (Base image setup precedes modules).
- [x] **II. Declarative Over Imperative**: Uses declarative configuration (Env/Input) rather than imperative scripts.
- [x] **III. Content-Addressable State**: N/A (Base image is an input, not a generated artifact).
- [x] **IV. Idempotency & Safety**: `Containerfile` `ARG` usage is idempotent.
- [x] **V. Mandatory Validation**: Changes will be validated via `just check` and build verification.

## Project Structure

### Documentation (this feature)

```text
specs/003-configurable-base-image/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output
```

### Source Code (repository root)

```text
.github/
└── workflows/
    └── build.yml        # CI input configuration

Containerfile            # ARG instruction for FROM

Justfile                 # Pass BASE_IMAGE env var to build command
```

**Structure Decision**: Single project (Repository Root). Modifications are limited to build configuration files.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

N/A

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
