
# Implementation Plan: Modular Build Architecture with Multi-Stage Containerfile

**Branch**: `001-implement-modular-build` | **Date**: 2025-10-05 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/var/home/kdlocpanda/second_brain/Projects/dudleys-second-bedroom/specs/001-implement-modular-build/spec.md`

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path
   → If not found: ERROR "No feature spec at {path}"
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → Detect Project Type from file system structure or context (web=frontend+backend, mobile=app+api)
   → Set Structure Decision based on project type
3. Fill the Constitution Check section based on the content of the constitution document.
4. Evaluate Constitution Check section below
   → If violations exist: Document in Complexity Tracking
   → If no justification possible: ERROR "Simplify approach first"
   → Update Progress Tracking: Initial Constitution Check
5. Execute Phase 0 → research.md
   → If NEEDS CLARIFICATION remain: ERROR "Resolve unknowns"
6. Execute Phase 1 → contracts, data-model.md, quickstart.md, agent-specific template file (e.g., `CLAUDE.md` for Claude Code, `.github/copilot-instructions.md` for GitHub Copilot, `GEMINI.md` for Gemini CLI, `QWEN.md` for Qwen Code, or `AGENTS.md` for all other agents).
7. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
8. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
9. STOP - Ready for /tasks command
```

**IMPORTANT**: The /plan command STOPS at step 7. Phases 2-4 are executed by other commands:
- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary

Restructure the build system from monolithic scripts into a modular, multi-stage architecture that enables:
- Clear separation of build concerns (utilities, desktop, developer tools, user hooks)
- Layer caching optimization to reduce incremental builds from 30+ minutes to under 10 minutes
- Parallel execution of independent modules
- Centralized configuration management via JSON
- Automated validation and cleanup
- Self-documenting structure through naming conventions

The primary goal is maintainability and build performance while maintaining full compatibility with Universal Blue/Bluefin-DX base images and OSTree immutability principles.

## Technical Context
**Language/Version**: Bash 5.x (shell scripts), Containerfile (OCI/Docker format)
**Primary Dependencies**: 
- Container runtime: podman 4.x or docker 24.x
- Build tool: just 1.x (command runner)
- Base image: ghcr.io/ublue-os/bluefin-dx:stable (Fedora 41)
- Package manager: dnf5/dnf
- Validation tools: shellcheck, jq, pre-commit hooks
**Storage**: OSTree-based immutable filesystem, container layer storage  
**Testing**: Integration tests via container builds, shellcheck for syntax validation, just recipes for test automation  
**Target Platform**: Fedora 41 Atomic Desktop (Universal Blue/Bluefin-DX derivative), x86_64 architecture  
**Project Type**: Container image build system (infrastructure-as-code)  
**Performance Goals**: 
- Incremental builds: < 10 minutes (vs 30+ current)
- Full builds: < 60 minutes in CI/CD
- Cache hit rate: ≥ 80% for single-file changes
- Image size reduction: ≥ 10% through cleanup optimization
**Constraints**: 
- Must maintain Universal Blue base image compatibility
- Must preserve OSTree/rpm-ostree bootable image format
- Must support both local (podman/docker) and CI/CD (GitHub Actions) builds
- Must maintain existing customizations (VS Code Insiders, wallpapers, packages)
- Build artifacts auto-cleaned on failure (per FR-022)
- Critical validation errors block builds; non-critical warnings allow override (per FR-016)
- Base image fallback on pull failure (per FR-011)
**Scale/Scope**: 
- ~20-30 build scripts across 4 categories
- ~50-100 packages managed via JSON configuration
- 3-5 build stages in multi-stage Containerfile
- Support for parallel module execution

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle I: Modularity & Maintainability
- ✅ **PASS**: Core goal of feature is modularization
- Build Modules organized by function: shared/, desktop/, developer/, user-hooks/
- Each Build Module has single responsibility
- Dependencies explicitly documented
- Build Modules independently testable

### Principle II: Simplicity Over Complexity
- ✅ **PASS**: Surgical, minimal approach
- Reorganizes existing scripts rather than rewriting
- Uses standard container build patterns (multi-stage)
- Leverages existing tools (just, shellcheck, jq)
- No unnecessary abstractions or frameworks

### Principle III: Documentation as Code
- ✅ **PASS**: Self-documenting structure required
- FR-016: Scripts MUST include header documentation
- FR-017: Directory structure MUST be self-documenting
- JSON configuration centralized and validated
- Inline comments for complex logic

### Principle IV: Validation Before Integration
- ✅ **PASS**: Comprehensive validation strategy
- FR-012/FR-013: Configuration and syntax validation required
- FR-015: Single command for all validation checks
- FR-016/FR-017: Validation errors block builds
- Pre-commit hooks enforced

### Principle V: Immutability & Reproducibility
- ✅ **PASS**: Maintains immutable image paradigm
- All customizations in build scripts (no runtime mods)
- Builds reproducible with same inputs (FR-025)
- Compatible with OSTree/rpm-ostree architecture
- No manual post-build modifications

### Principle VI: Container-Native Infrastructure
- ✅ **PASS**: Embraces container best practices
- Multi-stage Containerfile with layer optimization
- BuildKit mount caching for performance
- Image signing with cosign maintained
- CI/CD integration required (FR-024)

### Principle VII: User Experience First
- ✅ **PASS**: Developer experience focused
- Clear error messages required (FR-014)
- Standard logging (module start/end + errors/warnings)
- Single commands for operations (build, test, clean, validate)
- Maintainer can locate code in < 5 minutes

**Overall Assessment**: ✅ **ALL PRINCIPLES SATISFIED** - No violations or exceptions needed.

## Project Structure

### Documentation (this feature)
```
specs/001-implement-modular-build/
├── spec.md              # Feature specification (complete)
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
│   ├── build-module-contract.md
│   ├── package-config-schema.json
│   └── validation-contract.md
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)
```
dudleys-second-bedroom/
├── Containerfile                      # Multi-stage build definition
├── Justfile                          # Build automation commands
├── packages.json                     # Centralized package configuration
├── build_files/                      # Modular Build Modules
│   ├── shared/                      # Cross-cutting utilities
│   │   ├── build-base.sh           # Main orchestrator
│   │   ├── cleanup.sh              # Aggressive cleanup
│   │   ├── package-install.sh      # DNF/RPM operations
│   │   ├── branding.sh             # Wallpapers, themes
│   │   ├── signing.sh              # Container signing
│   │   └── utils/                  # Reusable utilities
│   │       ├── github-release-install.sh
│   │       ├── copr-manager.sh
│   │       └── validation.sh
│   ├── desktop/                     # Desktop customizations
│   │   ├── gnome-customizations.sh
│   │   ├── fonts-themes.sh
│   │   └── dconf-defaults.sh
│   ├── developer/                   # Developer tools
│   │   ├── vscode-insiders.sh
│   │   ├── action-server.sh
│   │   └── devcontainer-tools.sh
│   └── user-hooks/                  # First-boot user configs
│       ├── 10-wallpaper-enforcement.sh
│       ├── 20-vscode-extensions.sh
│       └── 99-first-boot-welcome.sh
├── system_files/                    # Static system files
│   └── shared/
│       ├── etc/                     # System configurations
│       │   └── dconf/
│       └── usr/                     # User-space files
│           └── share/
│               ├── backgrounds/
│               └── glib-2.0/
├── custom_wallpapers/               # Branding assets
├── .github/
│   ├── workflows/
│   │   └── build.yml               # CI/CD pipeline
│   └── copilot-instructions.md     # AI context
└── tests/                           # Build validation tests
    ├── validate-structure.sh
    ├── validate-packages.sh
    └── validate-containerfile.sh
```

**Structure Decision**: Single infrastructure project (container build system). The modular organization within `build_files/` provides clear separation while maintaining a cohesive build pipeline. This structure is self-documenting: directory names indicate purpose (shared, desktop, developer, user-hooks), and the hierarchy reflects execution order and dependencies.

## Phase 0: Outline & Research
1. **Extract unknowns from Technical Context** above:
   - For each NEEDS CLARIFICATION → research task
   - For each dependency → best practices task
   - For each integration → patterns task

2. **Generate and dispatch research agents**:
   ```
   For each unknown in Technical Context:
     Task: "Research {unknown} for {feature context}"
   For each technology choice:
     Task: "Find best practices for {tech} in {domain}"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

**Output**: research.md with all NEEDS CLARIFICATION resolved

## Phase 1: Design & Contracts
*Prerequisites: research.md complete*

1. **Extract entities from feature spec** → `data-model.md`:
   - Entity name, fields, relationships
   - Validation rules from requirements
   - State transitions if applicable

2. **Generate API contracts** from functional requirements:
   - For each user action → endpoint
   - Use standard REST/GraphQL patterns
   - Output OpenAPI/GraphQL schema to `/contracts/`

3. **Generate contract tests** from contracts:
   - One test file per endpoint
   - Assert request/response schemas
   - Tests must fail (no implementation yet)

4. **Extract test scenarios** from user stories:
   - Each story → integration test scenario
   - Quickstart test = story validation steps

5. **Update agent file incrementally** (O(1) operation):
   - Run `.specify/scripts/bash/update-agent-context.sh copilot`
     **IMPORTANT**: Execute it exactly as specified above. Do not add or remove any arguments.
   - If exists: Add only NEW tech from current plan
   - Preserve manual additions between markers
   - Update recent changes (keep last 3)
   - Keep under 150 lines for token efficiency
   - Output to repository root

**Output**: data-model.md, /contracts/*, failing tests, quickstart.md, agent-specific file

## Phase 2: Task Planning Approach
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:

The /tasks command will generate a comprehensive, ordered task list by:

1. **Analyzing Phase 1 Design Artifacts**:
   - Parse data-model.md for entities → create data structure tasks
   - Parse build-module-contract.md → create module implementation tasks
   - Parse validation-contract.md → create validation test tasks
   - Parse quickstart.md user scenarios → create integration test tasks

2. **Task Categories**:
   - **Infrastructure**: Containerfile, directory structure, Justfile recipes
   - **Utilities**: Shared scripts (validation, cleanup, package-install)
   - **Modules**: Category-specific scripts (desktop, developer, user-hooks)
   - **Configuration**: packages.json, schema validation
   - **Testing**: Validation tests, integration tests, smoke tests
   - **Documentation**: Inline comments, README updates

3. **Task Ordering Strategy**:
   - **Phase 1: Foundation** (Infrastructure setup)
     - Create directory structure
     - Create packages.json with schema
     - Set up Justfile with validation recipes
   
   - **Phase 2: Core Utilities** (Shared functionality)
     - validation.sh utility [P]
     - cleanup.sh script [P]
     - package-install.sh script
     - github-release-install.sh utility [P]
   
   - **Phase 3: Multi-Stage Containerfile** (Build orchestration)
     - Create context stage
     - Create base stage with mount caching
     - Integrate build-base.sh orchestrator
     - Add cleanup stage
   
   - **Phase 4: Module Implementation** (Category-specific)
     - Desktop modules [P]
     - Developer modules [P]
     - User-hooks modules [P]
   
   - **Phase 5: Validation & Testing** (Quality assurance)
     - Create validation tests
     - Create integration tests
     - Update pre-commit hooks
     - CI/CD pipeline updates
   
   - **Phase 6: Documentation** (Polish)
     - Update README.md
     - Add inline documentation
     - Create migration guide
     - Update quickstart examples

4. **Parallelization Markers**:
   - Tasks marked [P] can be executed in parallel
   - Tasks without [P] must be executed sequentially
   - Dependencies explicitly noted in task descriptions

5. **Task Format** (each task will include):
   - Task number and title
   - Description with context
   - Acceptance criteria
   - Dependencies (task numbers or "none")
   - Estimated complexity (S/M/L)
   - Parallel execution marker [P] if applicable
   - Related contracts/specs

**Estimated Output**: 35-45 numbered, ordered tasks in tasks.md

**Priority Focus**:
- Early tasks establish foundation (structure, utilities, validation)
- Middle tasks implement core functionality (modules, Containerfile)
- Late tasks add polish (documentation, tests, CI/CD)
- Critical path: Foundation → Utilities → Containerfile → Modules
- Enables incremental validation at each phase

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)  
**Phase 4**: Implementation (execute tasks.md following constitutional principles)  
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking
*Fill ONLY if Constitution Check has violations that must be justified*

**No violations detected** - All constitutional principles are satisfied by this feature design. No complexity deviations require justification.


## Progress Tracking
*This checklist is updated during execution flow*

**Phase Status**:
- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning complete (/plan command - describe approach only)
- [x] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented (none required)

**Artifacts Generated**:
- [x] research.md - Technical decisions and rationale
- [x] data-model.md - Entity definitions and relationships
- [x] contracts/build-module-contract.md - Module interface specification
- [x] contracts/package-config-schema.json - JSON schema for packages
- [x] contracts/validation-contract.md - Validation requirements
- [x] quickstart.md - Getting started guide
- [x] .github/copilot-instructions.md - Updated with new technologies
- [x] tasks.md - 41 implementation tasks with dependencies and parallel execution guidance

---
*Based on Constitution v1.0.0 - See `.specify/memory/constitution.md`*
