# Dagger Quick Start Guide

Get started building Universal Blue OS images with Dagger in 5 minutes.

## Prerequisites

Ensure you have:
- ✅ Dagger CLI installed
- ✅ Container runtime (Podman or Docker)
- ✅ Git repository cloned

## Install Dagger

```bash
# Linux/macOS
curl -fsSL https://dl.dagger.io/dagger/install.sh | sh

# Or using Homebrew
brew install dagger/tap/dagger

# Verify installation
dagger version
```

## 1. Explore Available Functions

See what Dagger can do for your Universal Blue build:

```bash
cd /var/home/kdlocpanda/second_brain/Areas/dudleys-second-bedroom
dagger functions
```

Expected output:
```
DudleysSecondBedroom          Dagger module for building Universal Blue OS
├── build                     Build the custom Universal Blue OS image
├── buildIso                  Build an ISO installation image
├── buildQcow2                Build a QCOW2 virtual machine image
├── ciPipeline                Run the complete CI/CD pipeline
├── lintContainerfile         Lint the Containerfile
├── publish                   Publish the built image
├── test                      Run tests on the built image
└── validate                  Validate build configuration
```

## 2. Validate Your Configuration

Before building, ensure everything is properly configured:

```bash
dagger call validate --source=.
```

This checks:
- ✅ Shell scripts with shellcheck
- ✅ JSON configuration files
- ✅ Build module metadata
- ✅ Package configuration schema

## 3. Build Your Image

Build the custom Universal Blue OS image:

```bash
dagger call build \
  --source=. \
  --image-name=dudleys-second-bedroom \
  --tag=latest \
  --git-commit=$(git rev-parse --short HEAD)
```

**What happens:**
1. Containerfile is processed
2. Modular build scripts execute (shared, desktop, developer, user-hooks)
3. Content versioning is applied
4. Build manifest is generated
5. Image is validated with `bootc container lint`

Build time: ~15-30 minutes (first build), ~5-10 minutes (cached builds)

## 4. Test Your Build

Run automated tests on the built image:

```bash
# Store the built image reference
IMAGE=$(dagger call build --source=. --git-commit=$(git rev-parse --short HEAD))

# Run tests
dagger call test --image=$IMAGE
```

Tests verify:
- Build manifest exists at `/etc/dudley/build-manifest.json`
- CLI tool `dudley-build-info` is installed
- User hooks are properly installed
- Content versions are correctly computed

## 5. Run the Full Pipeline

Execute validation, build, and test in one command:

```bash
dagger call ci-pipeline \
  --source=. \
  --repository=joshyorko/dudleys-second-bedroom \
  --tag=latest \
  --git-commit=$(git rev-parse --short HEAD) \
  --run-tests=true \
  --publish-image=false
```

**Pipeline stages:**
1. 🔍 Validation
2. 🔨 Build
3. 🧪 Test
4. 📦 Publish (if enabled)

## Bonus: Build Bootable Media

### ISO Image

```bash
dagger call build-iso \
  --source=. \
  --image-ref=ghcr.io/joshyorko/dudleys-second-bedroom:latest \
  export --path=./my-image.iso
```

### QCOW2 VM Image

```bash
dagger call build-qcow2 \
  --source=. \
  --image-ref=ghcr.io/joshyorko/dudleys-second-bedroom:latest \
  export --path=./my-image.qcow2
```

### Test the VM

```bash
# Using QEMU
qemu-system-x86_64 \
  -m 4G \
  -cpu host \
  -enable-kvm \
  -drive file=my-image.qcow2,format=qcow2 \
  -boot d
```

## Using Helper Scripts

### Makefile (Recommended)

```bash
# Copy the example Makefile
cp .dagger/examples/Makefile ./Makefile

# See all commands
make help

# Common operations
make validate      # Validate configuration
make build        # Build image
make test         # Build and test
make pipeline     # Run full pipeline
make iso          # Build ISO image
make clean        # Clean up artifacts
```

### Bash Script

```bash
# Run the complete local build script
./.dagger/examples/local-build.sh
```

## Publishing to GitHub Container Registry

Set up your credentials:

```bash
export GITHUB_USER="your-username"
export GITHUB_TOKEN="your-personal-access-token"
```

Publish your image:

```bash
dagger call publish \
  --image=$IMAGE \
  --registry=ghcr.io \
  --repository=joshyorko/dudleys-second-bedroom \
  --tag=latest \
  --username=env:GITHUB_USER \
  --password=env:GITHUB_TOKEN
```

Or use the full pipeline with publishing:

```bash
dagger call ci-pipeline \
  --source=. \
  --registry=ghcr.io \
  --repository=joshyorko/dudleys-second-bedroom \
  --tag=latest \
  --git-commit=$(git rev-parse --short HEAD) \
  --username=env:GITHUB_USER \
  --password=env:GITHUB_TOKEN \
  --run-tests=true \
  --publish-image=true
```

## Customization Examples

### Build with Different Base Image

```bash
dagger call build \
  --source=. \
  --base-image=ghcr.io/ublue-os/bluefin-nvidia:stable \
  --git-commit=$(git rev-parse --short HEAD)
```

### Build with Custom Tag

```bash
dagger call build \
  --source=. \
  --tag=v1.2.3 \
  --git-commit=$(git rev-parse --short HEAD)
```

### Lint Only

```bash
dagger call lint-containerfile --source=.
```

## Troubleshooting

### Problem: Build fails with cache errors

**Solution:** Clear the Dagger cache:
```bash
dagger run --cleanup
```

### Problem: Permission denied for container runtime

**Solution (Podman):**
```bash
systemctl --user enable --now podman.socket
```

**Solution (Docker):**
```bash
sudo usermod -aG docker $USER
newgrp docker
```

### Problem: Import errors in editor for `dagger` module

**Expected behavior** - These are resolved by Dagger at runtime. Your code will work even with editor warnings.

### Problem: Slow first build

**Expected behavior** - First builds download base images and establish caches. Subsequent builds will be much faster (5-10 min vs 30+ min).

## Next Steps

1. **Customize your image**: Edit files in `build_files/` and `packages.json`
2. **Set up GitHub Actions**: Copy `.dagger/examples/github-actions.yml` to `.github/workflows/`
3. **Read the full README**: See `.dagger/README.md` for complete function reference
4. **Explore the architecture**: Check out `specs/001-implement-modular-build/ARCHITECTURE.md`

## Resources

- 📖 [Dagger Documentation](https://docs.dagger.io)
- 🌊 [Universal Blue Docs](https://universal-blue.org)
- 🚢 [bootc Documentation](https://containers.github.io/bootc/)
- 📦 [Project README](../README.md)

---

**Pro Tip:** Use `dagger call <function> --help` to see detailed help for any function!
