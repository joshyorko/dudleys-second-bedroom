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
COPY flatpaks /flatpaks
COPY packages.json /packages.json
COPY vscode-extensions.list /vscode-extensions.list
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
# Content-Based Versioning Integration
# =============================================================================
# Generate build manifest with content hashes for all hooks, then replace
# __CONTENT_VERSION__ placeholders in hook scripts with computed hashes.

# Copy versioning utilities to temporary location
COPY build_files/shared/utils/*.sh /tmp/dudley-versioning/

# Generate manifest and replace version placeholders in hooks
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    cd /ctx && \
    # Source the utilities
    source /tmp/dudley-versioning/content-versioning.sh && \
    source /tmp/dudley-versioning/manifest-builder.sh && \
    # Generate manifest (creates /etc/dudley/build-manifest.json)
    bash /tmp/dudley-versioning/generate-manifest.sh > /tmp/versions.env && \
    # Load computed hashes
    source /tmp/versions.env && \
    echo "[dudley-versioning] Replacing version placeholders in hooks..." && \
    echo "[dudley-versioning]   Wallpaper: $WALLPAPER_VERSION" && \
    echo "[dudley-versioning]   VS Code: $VSCODE_VERSION" && \
    echo "[dudley-versioning]   Welcome: $WELCOME_VERSION" && \
    # Replace placeholders in installed hooks
    replace_version_placeholder /usr/share/ublue-os/user-setup.hooks.d/10-wallpaper-enforcement.sh "$WALLPAPER_VERSION" && \
    replace_version_placeholder /usr/share/ublue-os/user-setup.hooks.d/20-vscode-extensions.sh "$VSCODE_VERSION" && \
    replace_version_placeholder /usr/share/ublue-os/user-setup.hooks.d/99-first-boot-welcome.sh "$WELCOME_VERSION" && \
    # Install build-info CLI tool
    install -D -m 0755 /tmp/dudley-versioning/show-build-info.sh /usr/local/bin/dudley-build-info && \
    echo "[dudley-versioning] Version placeholder replacement complete" && \
    # Clean up
    rm -rf /tmp/dudley-versioning /tmp/versions.env

# =============================================================================
# Final Validation
# =============================================================================
# Verify the image meets bootc container standards

RUN bootc container lint