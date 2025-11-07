# Dagger Module for Universal Blue OS

This Dagger module provides CI/CD automation for Dudley's Second Bedroom, a customized Universal Blue image based on Bluefin-DX.

## Features

- **Validation**: Shellcheck, JSON schema validation, module metadata checks
- **Building**: Build bootc-compatible container images with modular build system
- **Testing**: Validate build manifest, packages, and hooks
- **Publishing**: Push images to container registries (GHCR, Docker Hub, etc.)
- **ISO/QCOW2**: Generate bootable disk images using bootc-image-builder
- **CI/CD Pipeline**: Complete automated pipeline from validation to publishing

## Prerequisites

- [Dagger CLI](https://docs.dagger.io/install) installed
- Python 3.11+ (for local development)
- Container runtime (Podman or Docker)

## Quick Start

### List Available Functions

```bash
dagger functions
```

### Validate Configuration

```bash
dagger call validate --source=.
```

### Build Image

```bash
dagger call build \
  --source=. \
  --image-name=dudleys-second-bedroom \
  --tag=latest \
  --git-commit=$(git rev-parse --short HEAD)
```

### Run Tests

```bash
# First build the image
IMAGE=$(dagger call build --source=. --git-commit=$(git rev-parse --short HEAD))

# Then test it
dagger call test --image=$IMAGE
```

### Complete CI Pipeline

```bash
dagger call ci-pipeline \
  --source=. \
  --repository=joshyorko/dudleys-second-bedroom \
  --tag=latest \
  --git-commit=$(git rev-parse --short HEAD) \
  --run-tests=true \
  --publish-image=false
```

### Publish to GitHub Container Registry

```bash
# Set up secrets
export GITHUB_TOKEN="your_github_token"

dagger call publish \
  --image=$IMAGE \
  --registry=ghcr.io \
  --repository=joshyorko/dudleys-second-bedroom \
  --tag=latest \
  --username=env:GITHUB_USER \
  --password=env:GITHUB_TOKEN
```

### Build ISO Image

```bash
dagger call build-iso \
  --source=. \
  --image-ref=ghcr.io/joshyorko/dudleys-second-bedroom:latest \
  --config-file=disk_config/iso.toml \
  export --path=./output/image.iso
```

### Build QCOW2 Image

```bash
dagger call build-qcow2 \
  --source=. \
  --image-ref=ghcr.io/joshyorko/dudleys-second-bedroom:latest \
  --config-file=disk_config/disk.toml \
  export --path=./output/image.qcow2
```

## Function Reference

### `validate(source)`

Validates build configuration and scripts.

**Parameters:**
- `source`: Source directory containing project files

**Returns:** Container with validation results

**Example:**
```bash
dagger call validate --source=.
```

### `build(source, image_name, tag, base_image, git_commit)`

Builds the custom Universal Blue OS image.

**Parameters:**
- `source`: Source directory
- `image_name`: Name for output image (default: "dudleys-second-bedroom")
- `tag`: Image tag (default: "latest")
- `base_image`: Universal Blue base image (default: "ghcr.io/ublue-os/bluefin-dx:latest")
- `git_commit`: Git commit SHA (default: "unknown")

**Returns:** Built container image

**Example:**
```bash
dagger call build \
  --source=. \
  --image-name=my-image \
  --tag=v1.0.0 \
  --git-commit=$(git rev-parse --short HEAD)
```

### `test(image)`

Runs tests on the built image.

**Parameters:**
- `image`: The container image to test

**Returns:** Test results as string

**Example:**
```bash
dagger call test --image=$IMAGE
```

### `publish(image, registry, repository, tag, username, password)`

Publishes the built image to a container registry.

**Parameters:**
- `image`: Container image to publish
- `registry`: Container registry URL (default: "ghcr.io")
- `repository`: Repository path (e.g., "owner/repo")
- `tag`: Image tag (default: "latest")
- `username`: Registry username (Dagger secret)
- `password`: Registry password/token (Dagger secret)

**Returns:** Published image reference

**Example:**
```bash
dagger call publish \
  --image=$IMAGE \
  --registry=ghcr.io \
  --repository=joshyorko/dudleys-second-bedroom \
  --tag=latest \
  --username=env:GITHUB_USER \
  --password=env:GITHUB_TOKEN
```

### `ci_pipeline(source, registry, repository, tag, git_commit, username, password, run_tests, publish_image)`

Runs the complete CI/CD pipeline.

**Parameters:**
- `source`: Source directory
- `registry`: Container registry (default: "ghcr.io")
- `repository`: Repository path
- `tag`: Image tag (default: "latest")
- `git_commit`: Git commit SHA (default: "unknown")
- `username`: Registry username (Dagger secret)
- `password`: Registry password (Dagger secret)
- `run_tests`: Whether to run tests (default: true)
- `publish_image`: Whether to publish (default: false)

**Returns:** Pipeline results summary

**Example:**
```bash
dagger call ci-pipeline \
  --source=. \
  --repository=joshyorko/dudleys-second-bedroom \
  --tag=latest \
  --git-commit=$(git rev-parse --short HEAD) \
  --run-tests=true \
  --publish-image=true \
  --username=env:GITHUB_USER \
  --password=env:GITHUB_TOKEN
```

### `lint_containerfile(source)`

Lints the Containerfile using hadolint.

**Parameters:**
- `source`: Source directory containing Containerfile

**Returns:** Container with linting results

**Example:**
```bash
dagger call lint-containerfile --source=.
```

### `build_iso(source, image_ref, config_file)`

Builds an ISO installation image.

**Parameters:**
- `source`: Source directory containing disk_config
- `image_ref`: Full OCI image reference
- `config_file`: Path to disk config TOML (default: "disk_config/iso.toml")

**Returns:** ISO file

**Example:**
```bash
dagger call build-iso \
  --source=. \
  --image-ref=ghcr.io/joshyorko/dudleys-second-bedroom:latest \
  export --path=./output.iso
```

### `build_qcow2(source, image_ref, config_file)`

Builds a QCOW2 virtual machine image.

**Parameters:**
- `source`: Source directory containing disk_config
- `image_ref`: Full OCI image reference
- `config_file`: Path to disk config TOML (default: "disk_config/disk.toml")

**Returns:** QCOW2 disk image file

**Example:**
```bash
dagger call build-qcow2 \
  --source=. \
  --image-ref=ghcr.io/joshyorko/dudleys-second-bedroom:latest \
  export --path=./output.qcow2
```

## GitHub Actions Integration

See `examples/github-actions.yml` for a complete GitHub Actions workflow example.

## Local Development

```bash
# Install Python dependencies
cd .dagger
uv venv
source .venv/bin/activate
uv pip install -e .

# Run Dagger functions
cd ..
dagger call validate --source=.
```

## Tips

1. **Caching**: Dagger automatically caches build layers. Subsequent builds will be faster.

2. **Secrets**: Use Dagger secrets for sensitive data:
   ```bash
   dagger call publish \
     --username=env:REGISTRY_USER \
     --password=env:REGISTRY_TOKEN
   ```

3. **Export Files**: Use `export` to save files locally:
   ```bash
   dagger call build-iso --source=. --image-ref=... export --path=./my.iso
   ```

4. **Interactive Debugging**: Use `terminal` to get a shell in any container:
   ```bash
   dagger call build --source=. terminal
   ```

## Troubleshooting

### Import Errors

Import errors for `dagger` module in your editor are expected. Dagger handles these at runtime.

### Build Failures

Check validation first:
```bash
dagger call validate --source=.
```

### Permission Errors

Ensure your container runtime is properly configured:
```bash
# For Podman
systemctl --user enable --now podman.socket

# For Docker
sudo usermod -aG docker $USER
```

## Resources

- [Dagger Documentation](https://docs.dagger.io)
- [Universal Blue Documentation](https://universal-blue.org)
- [bootc Documentation](https://containers.github.io/bootc/)
- [Project README](../README.md)
