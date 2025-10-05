# =============================================================================
# Multi-Stage Containerfile for Dudley's Second Bedroom
# =============================================================================
#
# This Containerfile uses a modular build system with the following stages:
# 1. Context stage: Provides read-only access to build files
# 2. Base stage: Executes modular build scripts with caching optimizations
#
# Build caching strategy:
# - Package manager cache: Persisted across builds via --mount=type=cache
# - Bind mounts: Read-only access to context without copying into image
# - Layer ordering: Static files first, volatile configurations last
#
# For more information, see: specs/001-implement-modular-build/
# =============================================================================

# =============================================================================
# Stage 1: Context Layer (Static Build Files)
# =============================================================================
# This stage provides all build files via bind mount without bloating the
# final image. Using scratch minimizes the context layer size.

FROM scratch AS ctx
COPY build_files /build_files
COPY system_files /system_files
COPY custom_wallpapers /custom_wallpapers
COPY packages.json /packages.json
COPY cosign.pub /cosign.pub

# =============================================================================
# Stage 2: Base Customizations
# =============================================================================
# Inherits from Universal Blue's Bluefin-DX (Developer Experience) image
# with Fedora 41 and desktop environment pre-configured.

FROM ghcr.io/ublue-os/bluefin-dx:stable AS base

# Build arguments
ARG FEDORA_MAJOR_VERSION="41"
ARG IMAGE_NAME="dudleys-second-bedroom"

# Environment variables for build modules
ENV FEDORA_VERSION="${FEDORA_MAJOR_VERSION}"
ENV IMAGE_NAME="${IMAGE_NAME}"
ENV BUILD_CONTEXT="/ctx"

## Alternative base images (commented out):
# FROM ghcr.io/ublue-os/bazzite:latest
# FROM ghcr.io/ublue-os/bluefin-nvidia:stable
# FROM quay.io/fedora/fedora-bootc:41
# FROM quay.io/centos-bootc/centos-bootc:stream10
#
# Universal Blue Images: https://github.com/orgs/ublue-os/packages

# =============================================================================
# Build Execution with Caching
# =============================================================================
# The build-base.sh orchestrator automatically discovers and executes all
# Build Modules in the correct order:
#   1. shared/ - Core utilities (package install, branding, cleanup)
#   2. desktop/ - Desktop environment customizations
#   3. developer/ - Development tools (VS Code, RCC, Action Server)
#   4. user-hooks/ - First-boot user configuration hooks
#
# Mount types:
#   - bind: Read-only access to build context (no copy to image)
#   - cache: Persistent package manager cache across builds
#   - tmpfs: Fast temporary storage for build artifacts

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/dnf5,sharing=locked \
    --mount=type=cache,dst=/var/cache/yum,sharing=locked \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/shared/build-base.sh

# =============================================================================
# Final Validation
# =============================================================================
# Verify the image meets bootc container standards

RUN bootc container lint