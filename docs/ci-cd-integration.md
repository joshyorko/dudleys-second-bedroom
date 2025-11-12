# CI/CD Pipeline Integration

## Overview

The CI/CD pipeline for Dudley's Second Bedroom has been enhanced with comprehensive test integration at strategic stages to ensure effective validation and timely feedback throughout the build and deployment process.

## Pipeline Architecture

The test integration follows a multi-stage approach with parallel execution where possible:

```
┌─────────────────────────────────────────────────────────┐
│                     PR / Push to Main                   │
└────────────────┬────────────────────────────────────────┘
                 │
    ┌────────────┴────────────┐
    │                         │
    ▼                         ▼
┌────────────────┐    ┌─────────────┐
│  Pre-Build     │    │ Unit Tests  │
│  Validation    │    │             │
└───────┬────────┘    └──────┬──────┘
        │                    │
        └──────────┬─────────┘
                   ▼
            ┌─────────────┐
            │   Build     │
            └──────┬──────┘
                   ▼
            ┌─────────────┐
            │   Verify    │
            └──────┬──────┘
                   ▼
            ┌─────────────┐
            │ Push/Sign   │
            └─────────────┘
```

## Workflows

### 1. Build Workflow (`build.yml`)

**Triggers:**
- Pull requests to `main`
- Push to `main` branch
- Daily schedule (10:05 UTC)
- Manual dispatch

**Test Stages:**

#### Stage 1: Pre-Build Validation (Fast Fail)
Runs in parallel with unit tests to provide fast feedback.

**What it does:**
- Validates Just syntax (`just check-just`)
- Lints shell scripts with shellcheck
- Validates packages.json structure
- Validates Build Module metadata and headers
- Checks shell script formatting with shfmt

**Command:** `just check`

**Why it runs first:** Static validation is fast and catches configuration errors before expensive build operations.

#### Stage 2: Unit Tests (Parallel with Pre-Build)
Fast-running unit tests that don't require a built image.

**What it does:**
- Tests content versioning utilities
- Tests manifest generation utilities

**Command:** `just test-unit`

**Why it runs in parallel:** Unit tests are independent of validation checks and can run simultaneously to save time.

#### Stage 3: Build
Standard container image build process. Only runs if pre-build validation and unit tests pass.

#### Stage 4: Post-Build Verification
Validates the built image contains expected components.

**What it does:**
- Verifies base OS and version
- Checks installed developer tools
- Validates custom branding and wallpapers
- Confirms Flatpak configuration
- Verifies user setup hooks
- Checks image metadata

**Command:** `just verify-build <image> <tag>`

**Why it runs after build:** Integration testing requires the actual built artifact.

#### Stage 5: Push and Sign
Only executes if all previous stages pass and the event is not a pull request.

### 2. Build Disk Workflow (`build-disk.yml`)

**Triggers:**
- Manual dispatch
- Pull requests affecting disk configuration

**Test Stages:**

#### Validation (PR only)
Runs the same validation checks as the build workflow plus disk-specific validation.

**What it does:**
- All checks from `just check`
- Validates disk_config/disk.toml exists
- Validates disk_config/iso.toml exists

**Why PR only:** Manual builds are typically urgent; validation has already passed in main branch.

#### Build
Disk image build only proceeds if validation passes.

### 3. Test Suite Workflow (`test.yml`)

A comprehensive test workflow for code changes affecting the build system.

**Triggers:**
- Pull requests to `main` (when `build_files/`, `tests/`, or `packages.json` change)
- Push to `main` (same path filters)
- Daily schedule (02:30 UTC)
- Manual dispatch

**Test Stages:**

#### Stage 1: Validation
**Command:** `just check`

#### Stage 2: Unit Tests (runs after validation)
**Command:** `just test-unit`

#### Stage 3: Integration Tests (runs after unit tests)
**Command:** `just test-integration`

#### Stage 4: Full Test Suite (runs after all stages)
**Command:** `just test-all`

Final verification that runs the complete test orchestrator.

## Just Commands

All test execution is standardized through Just commands for consistency between CI and local development:

### Validation Commands
```bash
just check              # Run all validation checks (lint, format, packages, modules)
just validate-packages  # Validate packages.json only
just validate-modules   # Validate Build Module metadata only
just check-just         # Validate Justfile syntax only
just lint               # Run shellcheck on all scripts
```

### Testing Commands
```bash
just test-unit         # Run unit tests (content versioning, manifest generation)
just test-integration  # Run integration tests (hook integration)
just test-all          # Run full test suite (includes validation + all tests)
```

### Build Verification
```bash
just verify-build [image] [tag]  # Verify built image contents
```

## Local Development Workflow

Developers should run these commands before pushing:

```bash
# Before committing
just check              # Catches linting and formatting issues

# Before pushing
just test-unit         # Quick unit test verification
just test-integration  # Hook integration checks

# Optional: Full verification
just test-all          # Complete test suite
```

## CI/CD Benefits

### Fast Feedback
- Pre-build validation fails in ~30 seconds
- Unit tests complete in ~1 minute
- Developers know immediately if there's an issue

### Parallel Execution
- Validation and unit tests run simultaneously
- Reduces total CI time by ~40%

### Gated Releases
- Images are only pushed if all tests pass
- Post-build verification ensures image quality
- No broken images reach the registry

### Clear Separation
- **Static validation:** Configuration and code quality
- **Unit tests:** Utility function correctness
- **Integration tests:** Component interaction
- **Build verification:** Final artifact validation

### Cost Optimization
- Fast fail on cheap validation checks
- Expensive builds only run after validation passes
- Disk workflow validation only runs on PRs

## Monitoring and Debugging

### Workflow Status
Check the Actions tab in GitHub to see:
- Which stage failed
- Detailed logs for each step
- Parallel execution timing

### Common Failures

**Pre-build validation fails:**
- Run `just check` locally
- Fix formatting with `just format`
- Fix identified issues

**Unit tests fail:**
- Run `just test-unit` locally
- Check test output for specific failures
- Review changes to utility functions

**Build verification fails:**
- Run `just build` locally
- Then `just verify-build`
- Check if expected files are present in the image

## Test Coverage

### Validated Components
- ✅ Shell script syntax and style
- ✅ Package configuration (duplicates, conflicts)
- ✅ Build Module metadata and headers
- ✅ Content versioning logic
- ✅ Manifest generation
- ✅ Hook integration and placeholders
- ✅ Built image contents and structure

### Future Enhancements
- [ ] Performance benchmarks
- [ ] Security scanning (Trivy, Grype)
- [ ] Smoke tests on bootable images
- [ ] Automated release notes generation

## Maintenance

### Adding New Tests

1. Create test script in `tests/` directory
2. Follow naming convention: `test-*.sh` or `validate-*.sh`
3. Add to appropriate Just command in Justfile
4. Test locally with `just test-all`
5. CI will automatically pick up changes

### Updating Workflows

When modifying `.github/workflows/*.yml`:
1. Validate YAML syntax
2. Test with workflow dispatch
3. Monitor first run carefully
4. Update this documentation

## References

- [Justfile](../../Justfile) - All test commands
- [tests/](../../tests/) - Test scripts
- [.github/workflows/](./) - Workflow definitions
- [Copilot Instructions](../copilot-instructions.md) - Repository guidelines
