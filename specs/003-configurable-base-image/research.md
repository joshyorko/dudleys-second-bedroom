# Research: Configurable Base Image

**Feature**: Configurable Base Image (003)
**Date**: 2025-11-21

## Unknowns & Clarifications

### 1. Containerfile `FROM` Instruction Support
**Question**: Can `ARG` be used in `FROM` instructions?
**Finding**: Yes, Docker/OCI standard supports `ARG` before `FROM`.
**Decision**: Use `ARG BASE_IMAGE="ghcr.io/ublue-os/bluefin-dx:stable"` before the `FROM` instruction.

### 2. CI/Local Parity
**Question**: How to ensure consistency between local `just build` and CI `buildah-build`?
**Finding**:
- Local: `Justfile` uses `podman build`.
- CI: Uses `redhat-actions/buildah-build`.
**Decision**:
- Modify `Justfile` to accept `BASE_IMAGE` env var and pass it as `--build-arg`.
- Modify `build.yml` to accept `workflow_dispatch` input and pass it as `build-args` to the action.
- This maintains the current toolchain while exposing the new parameter.

### 3. Default Value Handling
**Question**: How to handle the default value to avoid duplication?
**Finding**: `Containerfile` allows setting a default value for `ARG`.
**Decision**:
- `Containerfile`: Define default `ghcr.io/ublue-os/bluefin-dx:stable`.
- `Justfile`: Only pass `--build-arg BASE_IMAGE` if the env var is set.
- CI: Only pass `BASE_IMAGE` build arg if the input is provided.

## Implementation Details

### Containerfile
```dockerfile
ARG BASE_IMAGE="ghcr.io/ublue-os/bluefin-dx:stable"
FROM ${BASE_IMAGE} AS base
```

### Justfile
```bash
build $target_image=image_name $tag=default_tag:
    # ...
    if [[ -n "${BASE_IMAGE:-}" ]]; then
        BUILD_ARGS+=("--build-arg" "BASE_IMAGE=${BASE_IMAGE}")
    fi
    # ...
```

### GitHub Actions
```yaml
on:
  workflow_dispatch:
    inputs:
      base_image:
        description: 'Base image to build from'
        required: false
        type: string

# ...

      - name: Build Image
        with:
          build-args: |
            BASE_IMAGE=${{ inputs.base_image }}
```
*Note*: If `inputs.base_image` is empty, passing `BASE_IMAGE=` might override the default with an empty string. We need to ensure we pass the default or handle the empty string in Containerfile.
*Refinement*: `ARG BASE_IMAGE` default only applies if the arg is *not* passed. If passed as empty, it is empty.
*Solution*: In CI, we can use a shell step to set an output or env var that defaults to the standard image if input is empty, OR we can use conditional logic in the `build-args` block if supported, OR we can rely on `Containerfile` logic like `ARG BASE_IMAGE` and then `FROM ${BASE_IMAGE:-ghcr.io/ublue-os/bluefin-dx:stable}` (shell expansion not supported in FROM).
*Better Solution*: In CI, set `BASE_IMAGE` env var to the input. If input is empty, do NOT set the env var. Then in `build-args`, use `${{ env.BASE_IMAGE }}`? No, that doesn't help if we want to omit the arg.
*Alternative*: Use `ARG BASE_IMAGE` in Containerfile. In CI, construct the `build-args` string dynamically.

## Alternatives Considered

- **Hardcoding in Justfile**: Rejected. Violates Principle II (Declarative).
- **Separate Containerfiles**: Rejected. Maintenance burden.
- **Enforcing Registry**: Rejected. Limits flexibility for testing forks.
