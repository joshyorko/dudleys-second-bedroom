#!/usr/bin/env bash
set -euo pipefail

#
# Purpose: Generate build manifest with content-based versions for all hooks
# Category: shared/utils
# Dependencies: content-versioning.sh, manifest-builder.sh, jq, git
# Parallel-Safe: yes
# Usage: Run during container build to generate /etc/dudley/build-manifest.json
# Author: Dudley's Second Bedroom Project
# Date: 2025-10-10
#
# Orchestrates manifest generation by computing hashes for all hooks and
# their dependencies, then writing the manifest to /etc/dudley/build-manifest.json
#

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# If we're in a bind mount context (/ctx), use /ctx as root, otherwise calculate from script dir
if [[ "$SCRIPT_DIR" == /tmp/* ]]; then
	PROJECT_ROOT="/ctx"
else
	PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

# Source required utilities
# shellcheck disable=SC1091
source "$SCRIPT_DIR/content-versioning.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/manifest-builder.sh"

echo "[dudley-versioning] ========================================" >&2
echo "[dudley-versioning] Build Manifest Generation" >&2
echo "[dudley-versioning] ========================================" >&2

# Get build metadata
IMAGE_NAME="${IMAGE_NAME:-ghcr.io/joshyorko/dudleys-second-bedroom:latest}"
BASE_IMAGE="${BASE_IMAGE:-ghcr.io/ublue-os/bluefin-dx:stable}"

# Get git commit from environment variable (set during build) or fall back to git
if [[ -n "${GIT_COMMIT:-}" && "$GIT_COMMIT" != "unknown" ]]; then
	# Already set via environment variable from build arg
	: # no-op
elif git rev-parse --git-dir >/dev/null 2>&1; then
	GIT_COMMIT=$(git rev-parse --short=7 HEAD 2>/dev/null || echo "unknown")
else
	GIT_COMMIT="unknown"
fi

echo "[dudley-versioning] Image: $IMAGE_NAME" >&2
echo "[dudley-versioning] Base: $BASE_IMAGE" >&2
echo "[dudley-versioning] Commit: $GIT_COMMIT" >&2
echo "[dudley-versioning]" >&2

# Initialize manifest
echo "[dudley-versioning] Initializing manifest..." >&2
manifest=$(init_manifest "$IMAGE_NAME" "$BASE_IMAGE" "$GIT_COMMIT")

# Compute hash for wallpaper hook
echo "[dudley-versioning] Computing hash for wallpaper hook..." >&2
WALLPAPER_DEPS=(
	"$PROJECT_ROOT/build_files/user-hooks/10-wallpaper-enforcement.sh"
)
# Add wallpaper files if they exist
WALLPAPER_COUNT=0
if compgen -G "$PROJECT_ROOT/custom_wallpapers/*" >/dev/null; then
	mapfile -t WALLPAPER_FILES < <(find "$PROJECT_ROOT/custom_wallpapers" -type f 2>/dev/null | sort)
	WALLPAPER_DEPS+=("${WALLPAPER_FILES[@]}")
	WALLPAPER_COUNT=${#WALLPAPER_FILES[@]}
fi

wallpaper_hash=$(compute_content_hash "${WALLPAPER_DEPS[@]}")
wallpaper_deps_json=$(printf '%s\n' "${WALLPAPER_DEPS[@]}" | sed "s|$PROJECT_ROOT/||" | jq -R . | jq -s .)
wallpaper_meta=$(printf '{"wallpaper_count": %d, "changed": true}' "$WALLPAPER_COUNT")

echo "[dudley-versioning]   Version: $wallpaper_hash (${#WALLPAPER_DEPS[@]} files, $WALLPAPER_COUNT wallpapers)" >&2
manifest=$(add_hook_to_manifest "$manifest" "wallpaper" "$wallpaper_hash" "$wallpaper_deps_json" "$wallpaper_meta")

# Compute hash for vscode-extensions hook
echo "[dudley-versioning] Computing hash for vscode-extensions hook..." >&2
VSCODE_DEPS=(
	"$PROJECT_ROOT/build_files/user-hooks/20-vscode-extensions.sh"
)
# Add extensions list if it exists
extension_count=0
if [[ -f "$PROJECT_ROOT/vscode-extensions.list" ]]; then
	VSCODE_DEPS+=("$PROJECT_ROOT/vscode-extensions.list")
	extension_count=$(grep -v '^\s*#' "$PROJECT_ROOT/vscode-extensions.list" | grep -c -v '^\s*$')
fi

vscode_hash=$(compute_content_hash "${VSCODE_DEPS[@]}")
vscode_deps_json=$(printf '%s\n' "${VSCODE_DEPS[@]}" | sed "s|$PROJECT_ROOT/||" | jq -R . | jq -s .)
vscode_meta=$(printf '{"extension_count": %d, "changed": true}' "$extension_count")

echo "[dudley-versioning]   Version: $vscode_hash ($extension_count extensions)" >&2
manifest=$(add_hook_to_manifest "$manifest" "vscode-extensions" "$vscode_hash" "$vscode_deps_json" "$vscode_meta")

# Compute hash for holotree hook (script only, no data dependencies)
echo "[dudley-versioning] Computing hash for holotree hook..." >&2
holotree_hash=$(compute_content_hash "$PROJECT_ROOT/build_files/user-hooks/30-holotree-init.sh")
holotree_deps_json='["build_files/user-hooks/30-holotree-init.sh"]'
holotree_meta='{"changed": true}'

echo "[dudley-versioning]   Version: $holotree_hash" >&2
manifest=$(add_hook_to_manifest "$manifest" "holotree-init" "$holotree_hash" "$holotree_deps_json" "$holotree_meta")

# Compute hash for welcome hook (script only, no data dependencies)
echo "[dudley-versioning] Computing hash for welcome hook..." >&2
welcome_hash=$(compute_content_hash "$PROJECT_ROOT/build_files/user-hooks/99-first-boot-welcome.sh")
welcome_deps_json='["build_files/user-hooks/99-first-boot-welcome.sh"]'
welcome_meta='{"changed": true}'

echo "[dudley-versioning]   Version: $welcome_hash" >&2
manifest=$(add_hook_to_manifest "$manifest" "welcome" "$welcome_hash" "$welcome_deps_json" "$welcome_meta")

# Validate manifest
echo "[dudley-versioning]" >&2
echo "[dudley-versioning] Validating manifest..." >&2
if ! validate_manifest_schema "$manifest"; then
	echo "[dudley-versioning] ERROR: Manifest validation failed!" >&2
	exit 1
fi
echo "[dudley-versioning] Manifest validation passed" >&2

# Write manifest
OUTPUT_PATH="${MANIFEST_OUTPUT:-/etc/dudley/build-manifest.json}"
echo "[dudley-versioning]" >&2
echo "[dudley-versioning] Writing manifest to $OUTPUT_PATH..." >&2
write_manifest "$manifest" "$OUTPUT_PATH"

echo "[dudley-versioning]" >&2
echo "[dudley-versioning] ========================================" >&2
echo "[dudley-versioning] Build Manifest Generation Complete" >&2
echo "[dudley-versioning] ========================================" >&2

# Export computed hashes for use by Containerfile (optional)
echo "WALLPAPER_VERSION=$wallpaper_hash"
echo "VSCODE_VERSION=$vscode_hash"
echo "HOLOTREE_VERSION=$holotree_hash"
echo "WELCOME_VERSION=$welcome_hash"
