# Build System Contracts

## Containerfile Interface

The `Containerfile` exposes the following build arguments:

```dockerfile
ARG BASE_IMAGE="ghcr.io/ublue-os/bluefin-dx:stable"
```

- **Usage**: `FROM ${BASE_IMAGE} AS base`
- **Constraint**: Must be defined before the first `FROM` instruction that uses it.

## Justfile Interface

The `build` recipe accepts the following environment variable:

- **Variable**: `BASE_IMAGE`
- **Behavior**: If set, passed as `--build-arg BASE_IMAGE="${BASE_IMAGE}"` to `podman build`.
- **Default**: If unset, no build argument is passed (relying on Containerfile default).

## CI Interface (GitHub Actions)

The `build` workflow accepts the following `workflow_dispatch` input:

```yaml
inputs:
  base_image:
    description: 'Base image to build from (default: ghcr.io/ublue-os/bluefin-dx:stable)'
    required: false
    type: string
```

- **Behavior**: Passed to `buildah-build` action as `BASE_IMAGE` build argument if provided.
