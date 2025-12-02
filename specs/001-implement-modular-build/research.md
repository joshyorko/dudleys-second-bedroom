# Phase 0: Research & Technical Decisions

**Feature**: Modular Build Architecture with Multi-Stage Containerfile
**Date**: 2025-10-05

## Research Areas

### 1. Multi-Stage Containerfile Patterns

**Decision**: Use three-stage build with scratch-based context layer

**Rationale**:
- **Stage 1 (Context)**: FROM scratch with COPY only - provides build files without bloating final image
- **Stage 2 (Base)**: Customizations with mount caching - leverages BuildKit for faster rebuilds
- **Stage 3 (Cleanup)**: Optional stage for aggressive cleanup if needed

**Alternatives Considered**:
- Single-stage build: Rejected due to poor layer caching and larger images
- Five+ stage build: Rejected as overly complex for current needs (violates Principle II)

**Best Practices**:
- Use `--mount=type=bind` for read-only access to context files
- Use `--mount=type=cache` for package manager caches (dnf/dnf5)
- Minimize layers by combining related RUN commands
- Order layers by change frequency (static files first, volatile last)

**References**:
- Bluefin Containerfile: https://github.com/ublue-os/bluefin
- bOS approach: https://github.com/bsherman/bos
- BuildKit mount documentation

---

### 2. Modular Shell Script Organization

**Decision**: Four-category structure with shared utilities

**Rationale**:
- **shared/**: Common functions, utilities, orchestration (build-base.sh as entry point)
- **desktop/**: GNOME-specific customizations isolated from other concerns
- **developer/**: Dev tools separate from base system for maintainability
- **user-hooks/**: First-boot scripts that run in user context, not build context

**Alternatives Considered**:
- Flat structure with numbered prefixes (20-, 30-): Rejected as harder to navigate
- Feature-based (one dir per feature): Rejected as too granular for current scale

**Best Practices**:
- Each script starts with shebang, set -eoux pipefail
- Header documentation with purpose, dependencies, usage
- Exit codes: 0=success, 1=error, 2=skipped (already done)
- Scripts ≤200 lines (split if larger)
- Functions prefixed with script name to avoid namespace collisions

**References**:
- Google Shell Style Guide
- bOS modular script patterns
- Fedora packaging guidelines for scriptlets

---

### 3. Package Management via JSON Configuration

**Decision**: Single packages.json with category-based organization

**Rationale**:
- Centralized definition prevents scattered package declarations
- JSON enables validation, programmatic processing, and version control diff clarity
- Category structure (base, developer, optional) supports conditional builds
- Version-specific overrides support Fedora major version differences

**Schema Design**:
```json
{
  "all": {
    "install": ["package1", "package2"],
    "remove": ["bloat-package"]
  },
  "41": {
    "install": ["fedora41-specific"],
    "install-overrides": {"old-pkg": "new-pkg"}
  }
}
```

**Alternatives Considered**:
- YAML: Rejected due to parsing complexity in bash (requires yq)
- TOML: Rejected as less common, requires additional tooling
- Multiple JSON files: Rejected as harder to get holistic view

**Best Practices**:
- Validate JSON syntax in pre-commit hooks
- Use jq for parsing in shell scripts
- Document package purpose in adjacent comments (if schema extended)
- Pin versions only for stability-critical packages

**References**:
- Bluefin package management patterns
- jq manual for JSON querying
- DNF5 JSON output capabilities

---

### 4. Build Validation Strategy

**Decision**: Three-tier validation (syntax → configuration → integration)

**Rationale**:
- **Tier 1 (Syntax)**: shellcheck for bash, jq for JSON - catches basic errors early
- **Tier 2 (Configuration)**: Schema validation, dependency checks - prevents build failures
- **Tier 3 (Integration)**: Container build smoke tests - validates end-to-end

**Error vs Warning Policy** (from clarifications):
- Errors (syntax, missing required fields, invalid configs): BLOCK all builds
- Warnings (style issues, optional improvements): Allow override with acknowledgment

**Alternatives Considered**:
- All-or-nothing validation: Rejected as too rigid for development workflow
- No validation: Rejected as causes runtime failures and wastes CI time
- Manual validation only: Rejected as not scalable or reliable

**Best Practices**:
- Run shellcheck with `-e SC2086` for quote warnings
- Validate JSON against schema before parsing
- Create validation script: `build_files/shared/utils/validation.sh`
- Single command runs all checks: `just check`

**References**:
- shellcheck wiki for common issues
- JSON Schema specification
- pre-commit framework documentation

---

### 5. Layer Caching Optimization

**Decision**: BuildKit mount caching with dependency-based invalidation

**Rationale**:
- Mount caching preserves package manager caches across builds
- Dependency tracking ensures cache invalidation when needed
- Layer ordering by change frequency maximizes cache hits

**Cache Strategy**:
```dockerfile
# Slow-changing layers first
RUN --mount=type=cache,dst=/var/cache/dnf5 \
    install base packages

# Medium-changing layers
RUN --mount=type=bind,from=ctx,src=/,dst=/ctx \
    /ctx/build_files/desktop/gnome-customizations.sh

# Fast-changing layers last
COPY custom_wallpapers /usr/share/backgrounds/
```

**Alternatives Considered**:
- No caching strategy: Rejected - 30+ minute builds unsustainable
- External cache mounts only: Rejected - doesn't help with CI/CD
- Aggressive layer combining: Rejected - defeats caching purpose

**Best Practices**:
- Use cache mounts for package managers
- Use bind mounts for read-only script access
- Order Containerfile stages by change frequency
- Document cache dependencies in comments

**Cache Invalidation** (from clarifications):
- Automatic when mount source changes
- Manual via `just clean` or `--no-cache` flag
- Base image unavailable: Fall back to cached image with warning

**References**:
- BuildKit cache mount documentation
- Docker layer caching best practices
- Universal Blue build optimization techniques

---

### 6. Parallel Module Execution

**Decision**: Auto-detect independent modules, execute in parallel

**Rationale** (from clarifications):
- Reduces build time for independent operations
- No manual annotation required (automatic dependency analysis)
- Maintains correct order for dependent modules

**Dependency Detection Strategy**:
- Parse script headers for "Depends:" declarations
- Build DAG (directed acyclic graph) of dependencies
- Execute leaf nodes in parallel
- Progress to parent nodes as dependencies complete

**Alternatives Considered**:
- Sequential only: Rejected - wastes time on independent operations
- Manual parallel declaration: Rejected - maintenance burden, error-prone
- Always parallel everything: Rejected - breaks dependency chains

**Best Practices**:
- Scripts declare dependencies in header comments
- Orchestrator (build-base.sh) parses and schedules
- Use `wait` for parallel process synchronization
- Log parallel execution clearly (module start/end)

**Safety Considerations**:
- Dependent modules MUST NOT run before dependencies
- Resource-intensive modules may need throttling
- Failure in any parallel module stops all siblings

**References**:
- GNU parallel for reference patterns
- Makefile parallel job execution (-j flag)
- Task dependency graph algorithms

---

### 7. Cleanup and Artifact Management

**Decision**: Aggressive cleanup with automatic artifact deletion on failure

**Rationale** (from clarifications):
- Minimize final image size (target: ≥10% reduction)
- Clean state prevents cache pollution
- Failed builds auto-clean to prevent confusion

**Cleanup Targets**:
```bash
# Package manager caches
/var/cache/dnf*
/var/cache/yum*

# Temporary files
/tmp/*
/var/tmp/*

# Build artifacts
/root/.cache/*

# Disabled repo files (set enabled=0)
/etc/yum.repos.d/*.repo

# Logs (except critical)
/var/log/* (recreate directories after)
```

**Alternatives Considered**:
- Keep artifacts for debugging: Rejected - can re-run build if needed
- Selective cleanup: Rejected - partial cleanup still bloats image
- Manual cleanup only: Rejected - easy to forget, inconsistent

**Best Practices**:
- Run cleanup as last stage in Containerfile
- Commit OSTree after cleanup
- Recreate required directories (tmp, log) with correct permissions
- Document what's cleaned and why

**References**:
- bOS aggressive cleanup script
- Fedora RPM macros for cleanup
- OSTree container commit best practices

---

### 8. Observability and Logging

**Decision**: Standard logging with structured module events (from clarifications)

**Rationale**:
- Module start/end events provide build progress visibility
- Errors and warnings always logged for debugging
- Excludes verbose command output (too noisy for default)

**Log Format**:
```
[MODULE:shared/package-install] START
[MODULE:shared/package-install] Installing 45 packages...
[MODULE:shared/package-install] WARNING: Package X has newer version available
[MODULE:shared/package-install] DONE (duration: 120s)
```

**Alternatives Considered**:
- Minimal logging (errors only): Rejected - hard to debug hangs
- Verbose logging (all commands): Rejected - overwhelming, hard to parse
- JSON structured logs: Deferred - overkill for current needs

**Best Practices**:
- Use consistent log prefixes ([MODULE:path])
- Include timestamps for performance analysis
- Errors include actionable remediation hints
- Summary at end: modules run, duration, errors/warnings count

**References**:
- GitHub Actions output grouping (::group::)
- Systemd journal structured logging
- 12-factor app logging principles

---

### 9. Justfile Command Patterns

**Decision**: Task-based recipes with clear naming conventions

**Rationale**:
- `just build`: Main build operation
- `just check`: All validation checks
- `just lint`: Shell script linting
- `just clean`: Remove build artifacts
- `just test`: Run validation tests
- Recipe groups for organization (Build, Validation, Cleanup)

**Alternatives Considered**:
- Makefile: Rejected - just has better DX (cleaner syntax, built-in help)
- Bash scripts: Rejected - just provides better structure and discoverability
- Task runner (like npm scripts): Rejected - just is purpose-built for this

**Best Practices**:
- Group related recipes with `[group('name')]`
- Default recipe lists all available recipes
- Use variables for image names, tags
- Document complex recipes with comments
- Support common flags (--verbose, --no-cache)

**References**:
- just manual and cookbook
- bOS Justfile patterns
- Bluefin build automation

---

### 10. CI/CD Integration Strategy

**Decision**: GitHub Actions with matrix builds for variants

**Rationale**:
- Reuse local just commands in CI (consistency)
- Matrix strategy for future variant support
- Cosign integration for image signing
- Artifact caching between workflow runs

**Workflow Structure**:
```yaml
jobs:
  validate:
    - Run just check
    - Run shellcheck
  build:
    - Run just build
    - Sign with cosign
    - Push to registry
  test:
    - Pull built image
    - Run smoke tests
```

**Alternatives Considered**:
- Separate CI scripts: Rejected - duplicates logic, divergence risk
- Manual builds only: Rejected - not scalable for team
- Other CI systems: Rejected - already using GitHub, no reason to change

**Best Practices**:
- Use GitHub Actions cache for build layers
- Fail fast on validation errors
- Separate validation, build, test stages
- Sign images before pushing
- Generate provenance metadata (SLSA)

**References**:
- Universal Blue CI/CD patterns
- GitHub Actions workflow syntax
- Cosign signing workflow examples

---

## Technical Decisions Summary

| Decision Area | Choice | Key Justification |
|---------------|--------|-------------------|
| Build Stages | 3-stage (context, base, cleanup) | Balance complexity vs. optimization |
| Script Organization | 4 categories (shared, desktop, developer, user-hooks) | Clear separation of concerns |
| Package Config | Single packages.json | Centralized, validatable, version-controllable |
| Validation | 3-tier (syntax, config, integration) | Catch errors early, fail fast |
| Caching | BuildKit mounts + layer ordering | Maximize cache hits, minimize rebuild time |
| Parallelization | Auto-detect independent modules | Optimize build time without manual overhead |
| Cleanup | Aggressive + auto-clean on failure | Minimize image size, clean state |
| Logging | Standard (module events + errors/warnings) | Visibility without noise |
| Automation | just task runner | Better DX than make or bash scripts |
| CI/CD | GitHub Actions with matrix | Leverage existing infrastructure |

---

## Risks and Mitigations

### Risk 1: BuildKit cache not available in all environments
**Mitigation**: Graceful degradation - builds work without cache, just slower

### Risk 2: Parallel execution race conditions
**Mitigation**: Strict dependency declarations, careful file access patterns

### Risk 3: Breaking changes to Universal Blue base
**Mitigation**: Pin base image tags, test against new releases before updating

### Risk 4: Cleanup removes needed files
**Mitigation**: Test cleanup thoroughly, document what's preserved and why

### Risk 5: Complex validation slows development
**Mitigation**: Fast validation tier (syntax) runs first, slower tiers only in CI if needed

---

## Open Questions

None remaining - all technical context clarified through research and user clarification session.

---

**Status**: ✅ Research complete, ready for Phase 1 (Design & Contracts)
