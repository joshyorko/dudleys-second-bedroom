# Implementation Plan: Automatic Content-Based Versioning for User Hooks

**Branch**: `002-implement-automatic-content` | **Date**: 2025-10-10 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-implement-automatic-content/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Replace manual version management in user hooks with automatic content-based versioning using SHA256 hashes. System computes hashes of hook scripts and their data dependencies at build time, replacing version placeholders. Hooks only re-execute when content actually changes. Build manifest captures all versions and metadata, enabling welcome hook to display transparent change summary on first boot.

## Technical Context

**Language/Version**: Bash 5.x  
**Primary Dependencies**: sha256sum, jq, Universal Blue version-script (/usr/lib/ublue/setup-services/libsetup.sh), systemd journal  
**Storage**: File-based JSON manifest at `/etc/dudley/build-manifest.json`  
**Testing**: Bash test scripts with manual build verification  
**Target Platform**: Fedora-based Universal Blue immutable image (Linux/OCI container)  
**Project Type**: Build system enhancement (Containerfile integration)  
**Performance Goals**: Hash computation <5 seconds for <100MB tracked files, welcome display <1 second  
**Constraints**: Must integrate with existing Universal Blue version-script patterns, no breaking changes to current hook behavior, fail-fast on build errors  
**Scale/Scope**: 3 initial hooks (wallpaper, VS Code extensions, welcome), extensible pattern for future hooks, manifest <50KB

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Initial Check (Before Phase 0)

| Principle | Status | Evidence |
|-----------|--------|----------|
| **I. Modularity & Maintainability** | ✅ PASS | Utility functions in `build_files/shared/utils/`, separate concerns for hash computation vs manifest generation vs hook integration |
| **II. Simplicity Over Complexity** | ✅ PASS | Standard Unix tools (sha256sum, jq), no complex patterns, surgical integration with existing hooks |
| **III. Documentation as Code** | ⚠️ REQUIRES | Must add header documentation to all new scripts per constitution requirements |
| **IV. Validation Before Integration** | ⚠️ REQUIRES | Must add test scripts to `tests/` for hash computation and manifest generation |
| **V. Immutability & Reproducibility** | ✅ PASS | Build-time only modifications, deterministic hash generation, no runtime changes |
| **VI. Container-Native Infrastructure** | ✅ PASS | Integrates with Containerfile build process, follows Universal Blue patterns |
| **VII. User Experience First** | ✅ PASS | Welcome message enhancement, transparent change tracking, clear error messages |

**Overall**: CONDITIONAL PASS - proceed to Phase 0 with commitment to add documentation headers and test scripts in implementation.

### Post-Phase 1 Check

| Principle | Status | Evidence |
|-----------|--------|----------|
| **I. Modularity & Maintainability** | ✅ PASS | Design confirms clean separation: content-versioning.sh (hash), manifest-builder.sh (JSON), hook integration (version-script) |
| **II. Simplicity Over Complexity** | ✅ PASS | Research validates simple tool choices, no unnecessary abstractions added |
| **III. Documentation as Code** | ✅ PASS | Comprehensive API contracts created, quickstart guide provided, header templates defined |
| **IV. Validation Before Integration** | ✅ COMMITTED | Test contracts defined in API docs, specific test cases identified for implementation |
| **V. Immutability & Reproducibility** | ✅ PASS | Data model confirms build-time generation, runtime read-only access, deterministic hashing |
| **VI. Container-Native Infrastructure** | ✅ PASS | Containerfile integration pattern defined, follows OCI best practices |
| **VII. User Experience First** | ✅ PASS | Welcome hook enhancement designed with clear metadata display, error handling graceful |

**Overall**: ✅ **FULL PASS** - All principles satisfied by design. Ready to proceed to Phase 2 (tasks.md generation via `/speckit.tasks`).

## Project Structure

### Documentation (this feature)

```
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```
build_files/
├── shared/
│   └── utils/
│       ├── content-versioning.sh      # NEW: Hash computation utilities
│       └── manifest-builder.sh        # NEW: Build manifest generation
└── user-hooks/
    ├── 10-wallpaper-enforcement.sh    # MODIFIED: Add content versioning
    ├── 20-vscode-extensions.sh        # MODIFIED: Add content versioning
    └── 99-first-boot-welcome.sh       # MODIFIED: Display build summary

system_files/
└── shared/
    └── etc/
        └── dudley/
            └── build-manifest.json    # NEW: Generated at build time

tests/
├── test-content-versioning.sh         # NEW: Hash computation tests
├── test-manifest-generation.sh        # NEW: Manifest builder tests
└── test-hook-integration.sh           # NEW: End-to-end hook tests

Containerfile                          # MODIFIED: Integrate versioning utilities
```

**Structure Decision**: Single project structure (build system enhancement). New utility scripts in `build_files/shared/utils/` follow existing modular organization. Modified hooks retain current locations. Build manifest generated during container build and stored in system_files path.

## Complexity Tracking

*No constitution violations requiring justification. All design choices align with simplicity and modularity principles.*

---

## Phase Completion Status

### ✅ Phase 0: Outline & Research - COMPLETE

**Deliverable**: `research.md`

**Research completed**:
- Universal Blue version-script API and behavior patterns
- Bash hash computation best practices with determinism analysis
- Systemd journal logging from bash scripts
- Build-time vs runtime file access patterns in containerized images
- JSON manifest schema design with extensibility considerations

**All unknowns resolved**: ✅ No NEEDS CLARIFICATION items remain

---

### ✅ Phase 1: Design & Contracts - COMPLETE

**Deliverables**:
- ✅ `data-model.md` - Core entities (ContentHash, HookVersion, BuildManifest) with validation rules
- ✅ `contracts/build-manifest-schema.json` - JSON Schema v7 specification
- ✅ `contracts/content-versioning-api.md` - Utility function contracts with test specifications
- ✅ `contracts/manifest-builder-api.md` - Manifest generation API contracts
- ✅ `quickstart.md` - Developer guide with common patterns and troubleshooting
- ✅ `.github/copilot-instructions.md` - Updated agent context with new technologies

**Design decisions finalized**:
- Content hash format (8-char truncated SHA256)
- Manifest structure (flat JSON with extensible metadata)
- API surface (7 public functions across 2 modules)
- Integration patterns (build-time generation, runtime consumption)
- Error handling strategy (fail-fast at build, graceful at runtime)

**Constitution re-check**: ✅ FULL PASS (all principles satisfied)

---

### ⏭️ Phase 2: Task Breakdown - PENDING

**Next command**: `/speckit.tasks`

**Expected deliverable**: `tasks.md` with prioritized implementation tasks

**Recommended approach**:
1. Run `/speckit.tasks` to generate task breakdown
2. Review task dependencies and sequencing
3. Begin implementation starting with utility functions
4. Iterate through hooks (wallpaper → vscode-extensions → welcome)
5. Add tests incrementally alongside implementation
