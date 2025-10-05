<!--
Sync Impact Report:
─────────────────────────────────────────────────────────────────
Version Change: UNVERSIONED → 1.0.0
Status: Initial Constitution - Establishing Governance Framework

Modified Principles: N/A (Initial Creation)
Added Sections:
  - Core Principles (7 principles)
  - Build & Quality Standards
  - Development Workflow
  - Governance
  
Templates Status:
  ✅ plan-template.md - Reviewed, compatible with constitution
  ✅ spec-template.md - Reviewed, compatible with constitution  
  ✅ tasks-template.md - Reviewed, compatible with constitution
  ✅ agent-file-template.md - Reviewed, compatible with constitution
  
Follow-up TODOs: None
─────────────────────────────────────────────────────────────────
-->

# Dudley's Second Bedroom Constitution

## Core Principles

### I. Modularity & Maintainability
**Principle**: Every feature MUST be implemented as a modular, self-contained component with clear separation of concerns.

**Requirements**:
- Build scripts MUST be organized by function (base, desktop, developer, user-hooks)
- Each script MUST have a single, well-defined responsibility
- Dependencies between scripts MUST be explicit and documented
- Scripts MUST be independently testable where feasible

**Rationale**: Modular architecture enables easier debugging, testing, and maintenance. It allows team members to understand and modify specific components without comprehending the entire system. This directly supports the project's goal of maintainability and professional structure.

### II. Simplicity Over Complexity
**Principle**: Choose the simplest solution that meets requirements. Complexity MUST be justified and documented.

**Requirements**:
- Surgical, minimal code changes preferred (aligned with Bluefin philosophy)
- New dependencies MUST be justified by clear value add
- Complex patterns (factories, abstractions) require documented rationale
- "Good enough" solutions preferred over "perfect" but unmaintainable ones

**Rationale**: Unnecessary complexity creates maintenance burden and reduces accessibility to contributors. The "step up from the closet" philosophy acknowledges room for growth while maintaining pragmatic, understandable solutions.

### III. Documentation as Code
**Principle**: Code MUST be self-documenting through structure, naming, and inline documentation.

**Requirements**:
- Every build script MUST include header documentation (purpose, dependencies, usage, author, date)
- Complex logic MUST have explanatory comments
- Directory structure MUST convey purpose through naming
- User-facing features MUST have corresponding documentation updates
- All JSON configuration files MUST be validated as part of CI/CD

**Rationale**: Self-documenting code reduces onboarding time, prevents knowledge silos, and serves as living documentation that stays synchronized with implementation.

### IV. Validation Before Integration
**Principle**: All changes MUST pass automated validation before merging or deploying.

**Requirements**:
- All code MUST pass syntax validation (`just check`)
- Shell scripts MUST pass shellcheck linting
- JSON files MUST be syntactically valid
- Build processes MUST complete successfully in CI/CD
- Pre-commit hooks MUST be used to catch issues early

**Rationale**: Early detection of issues reduces debugging time, prevents broken builds, and maintains system stability. Automated validation scales better than manual review alone.

### V. Immutability & Reproducibility
**Principle**: OS images MUST be immutable and builds MUST be reproducible.

**Requirements**:
- No manual modifications to system after build
- All customizations MUST be defined in build scripts
- Package versions SHOULD be pinned where stability is critical
- Build artifacts MUST be versioned and signed
- Changes MUST be deployable via image updates, not runtime modifications

**Rationale**: Immutability ensures consistency across deployments, simplifies rollback procedures, and prevents configuration drift. This is fundamental to the Universal Blue/OSTree architecture.

### VI. Container-Native Infrastructure
**Principle**: Embrace container and cloud-native best practices throughout the stack.

**Requirements**:
- Multi-stage builds MUST be used to optimize image size
- Layer caching MUST be leveraged for faster builds
- BuildKit mount caching SHOULD be used where applicable
- Images MUST be signed with cosign for supply chain security
- CI/CD pipelines MUST follow GitHub Actions best practices

**Rationale**: Container-native patterns provide better performance, security, and developer experience. They align with Universal Blue's architectural decisions and industry standards.

### VII. User Experience First
**Principle**: End-user experience MUST drive technical decisions.

**Requirements**:
- First-boot experience MUST be welcoming and informative
- Default configurations MUST favor usability over technical purity
- Breaking changes MUST include migration documentation
- User-facing errors MUST be actionable and clear
- Documentation MUST be accessible to non-expert users

**Rationale**: The project exists to serve users, not to showcase technical prowess. User-centric design reduces support burden and increases adoption success.

## Build & Quality Standards

### Package Management
- Centralized package definitions MUST use `packages.json` format
- Packages MUST be categorized (base, developer, optional)
- Excluded packages MUST be documented with rationale
- Version-specific overrides MUST be supported for Fedora major versions
- Package installation failures MUST halt the build process

### Image Optimization
- Final images MUST implement aggressive cleanup (temp files, caches, logs)
- Disabled third-party repos MUST have enabled=0 set
- Build artifacts MUST not be present in final image layers
- Image size increases MUST be justified in PR descriptions
- Layer optimization MUST be considered for frequently changing components

### Testing & Validation
- Build scripts MUST be testable in isolation where feasible
- Critical functionality MUST be validated post-build (e.g., `code-insiders --version`)
- Integration testing SHOULD occur in CI/CD environments
- Manual testing checklists MUST be maintained for user-facing features
- Regression testing MUST occur before major releases

### Security & Signing
- All production images MUST be signed with cosign
- Public keys MUST be committed to repository
- Signature verification MUST be configured for end users
- Security updates MUST be applied within 72 hours of availability
- Vulnerabilities MUST be tracked and documented

## Development Workflow

### Change Management
- All changes MUST occur through feature branches
- Branch naming MUST follow convention: `###-feature-name`
- Commits MUST follow conventional commit format
- Pull requests MUST pass all CI/CD checks before merge
- Breaking changes MUST be flagged in PR title and description

### Code Review Requirements
- All PRs MUST be reviewed by at least one other person (if team exists)
- Self-review MUST include running `just check` and `just lint`
- Documentation updates MUST accompany user-facing changes
- Breaking changes MUST include migration guide
- Performance impacts MUST be assessed and documented

### Quality Gates
**Pre-Commit**:
- Syntax validation (Just, JSON, Shell)
- Formatting checks (shfmt for bash)
- Linting (shellcheck)

**CI/CD Pipeline**:
- Build success
- Image size validation
- Signature verification
- Functional smoke tests
- ISO generation (if applicable)

### Release Process
1. Validate all changes locally (`just dev`)
2. Ensure documentation is updated
3. Version bump follows semantic versioning
4. Tag release with version number
5. CI/CD builds, tests, signs, and publishes
6. ISO generation triggered for major/minor releases
7. Release notes generated with changelog

## Governance

### Authority & Precedence
- This constitution SUPERSEDES all other development practices
- Conflicts between constitution and other documents MUST be resolved in favor of constitution
- Exceptions require documented justification and approval
- Regular constitution reviews SHOULD occur quarterly

### Amendment Process
**Minor Amendments (PATCH)**:
- Clarifications, wording improvements, non-semantic changes
- Can be proposed via standard PR process
- Require simple approval

**Major Amendments (MINOR/MAJOR)**:
- New principles, removed principles, material changes to governance
- MUST include impact analysis of affected templates and processes
- MUST include sync report identifying downstream updates needed
- Require explicit discussion and consensus

### Version Semantics
- **MAJOR**: Breaking changes, principle removals, governance restructuring
- **MINOR**: New principles, additional constraints, expanded guidance
- **PATCH**: Clarifications, typo fixes, wording improvements

### Compliance & Enforcement
- All PRs MUST reference constitution principles where applicable
- Template files MUST be synchronized after constitution amendments
- Violations MUST be documented with justification or remediation plan
- Repeated violations indicate need for constitution update or training

### Related Documents
- **Runtime Guidance**: `.github/copilot-instructions.md` (AI agent context)
- **Architecture**: `ARCHITECTURE.md` (when created, technical deep-dive)
- **Development**: `README.md` (user-facing quick start)
- **Templates**: `.specify/templates/*.md` (feature development workflows)

### Continuous Improvement
- Constitution SHOULD evolve with project maturity
- Lessons learned MUST inform principle refinements
- Community feedback SHOULD be actively solicited
- Retrospectives SHOULD identify constitution gaps

**Version**: 1.0.0 | **Ratified**: 2025-10-05 | **Last Amended**: 2025-10-05