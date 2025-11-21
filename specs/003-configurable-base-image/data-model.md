# Data Model: Configurable Base Image

**Feature**: 003-configurable-base-image

## Configuration Entities

### Base Image Configuration

| Field | Type | Default | Description | Source |
|-------|------|---------|-------------|--------|
| `BASE_IMAGE` | String (OCI Ref) | `ghcr.io/ublue-os/bluefin-dx:stable` | The upstream image to build upon. | `Containerfile` (ARG) |

## State Transitions

N/A - Stateless build configuration.

## Validation Rules

1. **Format**: Must be a valid OCI image reference (Registry/Repository:Tag).
2. **Availability**: Image must be pullable by the build environment.
3. **Compatibility**: Image must provide expected UBlue directory structure (e.g., `/usr/share/ublue-os`).
