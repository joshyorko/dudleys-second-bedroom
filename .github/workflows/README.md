# GitHub Actions Workflows

This directory contains the CI/CD workflows for Dudley's Second Bedroom.

## Workflows Overview

### `build.yml` - Main Build Pipeline
**Purpose:** Build and publish the container image

**Triggers:**
- Pull requests to main
- Push to main branch
- Daily schedule (10:05 UTC)
- Manual dispatch

**Stages:**
1. **Pre-Build Validation** - Fast static checks (`just check`)
2. **Unit Tests** - Fast unit tests (runs in parallel with validation)
3. **Build** - Container image build
4. **Verify** - Post-build verification (`just verify-build`)
5. **Push & Sign** - Publish to registry (main branch only)

### `test.yml` - Comprehensive Test Suite
**Purpose:** Run full test suite for code changes

**Triggers:**
- Pull requests affecting build files or tests
- Push to main (same path filter)
- Daily schedule (02:30 UTC)
- Manual dispatch

**Stages:**
1. **Validation** - Static checks (`just check`)
2. **Unit Tests** - Unit tests (`just test-unit`)
3. **Integration Tests** - Integration tests (`just test-integration`)
4. **Full Test Suite** - Complete verification (`just test-all`)

### `build-disk.yml` - Disk Image Build
**Purpose:** Build bootable disk images (QCOW2, ISO, RAW)

**Triggers:**
- Manual dispatch
- Pull requests affecting disk configuration

**Stages:**
1. **Validation** - Configuration validation (PR only)
2. **Build** - Disk image generation

### `clean.yml` - Image Cleanup
**Purpose:** Remove old container images

**Triggers:**
- Weekly schedule (Sunday 00:15 UTC)
- Manual dispatch

**Actions:**
- Deletes images older than 5 days
- Keeps 5 tagged and 5 untagged images

## Test Integration

All workflows leverage Just commands for consistency:

```bash
just check              # Pre-build validation
just test-unit         # Unit tests
just test-integration  # Integration tests
just test-all          # Full test suite
just verify-build      # Post-build verification
```

See [CI/CD Integration Documentation](../../docs/ci-cd-integration.md) for detailed information.

## Local Testing

Before pushing changes, run:

```bash
# Quick checks (runs in ~30 seconds)
just check

# Unit tests (runs in ~1 minute)
just test-unit

# Full verification (runs in ~2 minutes)
just test-all
```

## Monitoring

- **Status:** Check the Actions tab for workflow runs
- **Logs:** Click on individual workflow runs for detailed logs
- **Badges:** Add status badges to README.md

## Workflow Dependencies

```
build.yml:
  pre-build-validation ──┐
                         ├──> build_push ──> verify ──> push/sign
  unit-tests ────────────┘

test.yml:
  validation ──> unit-tests ──> integration-tests ──> full-test-suite

build-disk.yml:
  validate ──> build
```

## Security

- Workflows use pinned action versions (SHA-based)
- Secrets stored in GitHub repository settings
- Push/sign only on main branch, never on PRs
- Minimal permissions per job

## Maintenance

When updating workflows:
1. Validate YAML syntax locally
2. Test with manual workflow dispatch
3. Monitor first run carefully
4. Update documentation as needed

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Universal Blue CI/CD Patterns](https://universal-blue.org/contributing/building/)
- [Just Command Runner](https://just.systems/)
