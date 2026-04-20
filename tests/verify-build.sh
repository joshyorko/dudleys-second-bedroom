#!/usr/bin/env bash
# Script: verify-build.sh
# Purpose: Verify the built container image has all expected components
# Usage: bash tests/verify-build.sh [image-name:tag]

set -euo pipefail

# Configuration
IMAGE_NAME="${1:-localhost/dudleys-second-bedroom:latest}"
FAILED_CHECKS=0
EXPECTED_WALLPAPER_COUNT=6
EXPECTED_OS_ID="${EXPECTED_OS_ID:-bluefin}"
EXPECTED_VERSION_ID="${EXPECTED_VERSION_ID:-}"
EXPECTED_VARIANT_ID="${EXPECTED_VARIANT_ID:-}"
EXPECTED_IMAGE_NAME="${IMAGE_NAME##*/}"
EXPECTED_IMAGE_NAME="${EXPECTED_IMAGE_NAME%:*}"
EXPECTED_IMAGE_TAG="${IMAGE_NAME##*:}"
OS_RELEASE_CONTENT=""

if [[ -d custom_wallpapers ]]; then
	EXPECTED_WALLPAPER_COUNT=$(find custom_wallpapers -maxdepth 1 -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) | wc -l | tr -d ' ')
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "==================================="
echo "Build Verification Test Suite"
echo "==================================="
echo "Image: ${IMAGE_NAME}"
echo ""

# Function to run check
run_check() {
	local description="$1"
	local command="$2"
	local expected="$3"

	echo -n "Checking ${description}... "

	if result=$(eval "${command}" 2>&1); then
		if [[ -n "${expected}" ]]; then
			if echo "${result}" | grep -q "${expected}"; then
				echo -e "${GREEN}✓${NC}"
				return 0
			else
				echo -e "${RED}✗${NC} (expected: ${expected}, got: ${result})"
				FAILED_CHECKS=$((FAILED_CHECKS + 1))
				return 1
			fi
		else
			echo -e "${GREEN}✓${NC}"
			return 0
		fi
	else
		echo -e "${RED}✗${NC} (command failed)"
		FAILED_CHECKS=$((FAILED_CHECKS + 1))
		return 1
	fi
}

escape_regex() {
	printf '%s' "$1" | sed -e 's/[][(){}.^$*+?|\\/]/\\&/g'
}

run_os_release_check() {
	local description="$1"
	local key="$2"
	local expected_value="$3"
	local escaped_value
	local pattern

	escaped_value=$(escape_regex "${expected_value}")
	pattern="^${key}=\"?${escaped_value}\"?$"

	echo -n "Checking ${description}... "
	if printf '%s\n' "${OS_RELEASE_CONTENT}" | grep -Eq "${pattern}"; then
		echo -e "${GREEN}✓${NC}"
		return 0
	fi

	echo -e "${RED}✗${NC} (expected ${key}=${expected_value}, got: ${OS_RELEASE_CONTENT})"
	FAILED_CHECKS=$((FAILED_CHECKS + 1))
	return 1
}

run_manifest_image_check() {
	local manifest_image
	local manifest_repo
	local manifest_name
	local manifest_tag

	echo -n "Checking build manifest image ref... "

	if ! manifest_image=$(podman run --rm "${IMAGE_NAME}" jq -r '.build.image // "unknown"' /etc/dudley/build-manifest.json 2>&1); then
		echo -e "${RED}✗${NC} (command failed)"
		FAILED_CHECKS=$((FAILED_CHECKS + 1))
		return 1
	fi

	manifest_repo="${manifest_image##*/}"
	manifest_name="${manifest_repo%:*}"
	manifest_tag="${manifest_image##*:}"

	if [[ "${manifest_name}" == "${EXPECTED_IMAGE_NAME}" ]] && [[ "${manifest_tag}" == "${EXPECTED_IMAGE_TAG}" ]]; then
		echo -e "${GREEN}✓${NC}"
		return 0
	fi

	echo -e "${RED}✗${NC} (expected name/tag: ${EXPECTED_IMAGE_NAME}:${EXPECTED_IMAGE_TAG}, got: ${manifest_image})"
	FAILED_CHECKS=$((FAILED_CHECKS + 1))
	return 1
}

# Check 1: Image exists
echo "=== Image Existence ==="
run_check "image exists" "podman images -q ${IMAGE_NAME}" ""

# Check 2: Base OS
echo ""
echo "=== Base Operating System ==="
if OS_RELEASE_CONTENT="$(podman run --rm "${IMAGE_NAME}" cat /etc/os-release 2>&1)"; then
	run_os_release_check "base OS" "ID" "${EXPECTED_OS_ID}"

	if [[ -n "${EXPECTED_VERSION_ID}" ]]; then
		run_os_release_check "Fedora version" "VERSION_ID" "${EXPECTED_VERSION_ID}"
	fi

	if [[ -n "${EXPECTED_VARIANT_ID}" ]]; then
		run_os_release_check "base variant" "VARIANT_ID" "${EXPECTED_VARIANT_ID}"
	fi
else
	echo -e "${RED}✗${NC} (failed to read /etc/os-release)"
	FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Check 3: Packages from packages.json
echo ""
echo "=== Installed Packages ==="
run_check "tmux" "podman run --rm ${IMAGE_NAME} rpm -q tmux" "tmux-"
run_check "curl" "podman run --rm ${IMAGE_NAME} rpm -q curl" "curl-"
run_check "gcc-c++" "podman run --rm ${IMAGE_NAME} rpm -q gcc-c++" "gcc-c++-"

# Check 5: Custom Branding
echo ""
echo "=== Custom Branding ==="
run_check "wallpaper directory" "podman run --rm ${IMAGE_NAME} test -d /usr/share/backgrounds/dudley && echo exists" "exists"
run_check "wallpaper files" "podman run --rm ${IMAGE_NAME} find /usr/share/backgrounds/dudley -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) | wc -l" "${EXPECTED_WALLPAPER_COUNT}"
run_check "GNOME schema override" "podman run --rm ${IMAGE_NAME} test -f /usr/share/glib-2.0/schemas/zz0-dudley-background.gschema.override && echo exists" "exists"

# Check 6: Flatpaks Configuration
echo ""
echo "=== Flatpaks Configuration ==="
run_check "flatpaks directory" "podman run --rm ${IMAGE_NAME} test -d /usr/share/ublue-os/flatpaks && echo exists" "exists"
run_check "system flatpaks list" "podman run --rm ${IMAGE_NAME} test -f /usr/share/ublue-os/flatpaks/system-flatpaks.list && echo exists" "exists"
run_check "DX flatpaks list" "podman run --rm ${IMAGE_NAME} test -f /usr/share/ublue-os/flatpaks/system-flatpaks-dx.list && echo exists" "exists"

# Check 7: User Hooks
echo ""
echo "=== User Setup Hooks ==="
run_check "wallpaper hook" "podman run --rm ${IMAGE_NAME} test -f /usr/share/ublue-os/user-setup.hooks.d/10-wallpaper-enforcement.sh && echo exists" "exists"
run_check "usr/local symlink target" "podman run --rm ${IMAGE_NAME} sh -c 'test -L /usr/local && readlink /usr/local'" "var/usrlocal"
run_check "random wallpaper script" "podman run --rm ${IMAGE_NAME} test -x /usr/bin/dudley-random-wallpaper && echo exists" "exists"
run_check "random wallpaper autostart" "podman run --rm ${IMAGE_NAME} test -f /etc/xdg/autostart/dudley-random-wallpaper.desktop && echo exists" "exists"

# Check 7b: VS Code Runtime Configuration
echo ""
echo "=== VS Code Runtime Configuration ==="
run_check "VS Code extensions list" "podman run --rm ${IMAGE_NAME} test -f /usr/share/ublue-os/vscode-extensions.list && echo exists" "exists"
run_check "VS Code not baked into image" "podman run --rm ${IMAGE_NAME} bash -lc '! command -v code-insiders >/dev/null 2>&1 && echo absent'" "absent"
run_check "Dudley just recipes" "podman run --rm ${IMAGE_NAME} test -f /usr/share/ublue-os/just/60-dudley.just && echo exists" "exists"

# Note: RCC is now installed via Homebrew (ujust dudley brew dev) instead of being baked into the image

# Check 8: Image Metadata
echo ""
echo "=== Image Metadata ==="
run_check "build manifest exists" "podman run --rm ${IMAGE_NAME} test -f /etc/dudley/build-manifest.json && echo exists" "exists"
run_manifest_image_check
run_check "image-info exists" "podman run --rm ${IMAGE_NAME} test -f /usr/share/ublue-os/image-info.json && echo exists" "exists"
run_check "image-info tag" "podman run --rm ${IMAGE_NAME} cat /usr/share/ublue-os/image-info.json | jq -r '.\"image-tag\"'" "^$(escape_regex "${EXPECTED_IMAGE_TAG}")$"

IMAGE_SIZE=$(podman inspect "${IMAGE_NAME}" | jq -r '.[0].Size')
IMAGE_SIZE_GB=$(awk "BEGIN {printf \"%.1f\", ${IMAGE_SIZE} / 1024 / 1024 / 1024}")
echo "Image size: ${IMAGE_SIZE_GB} GB"

LAYER_COUNT=$(podman inspect "${IMAGE_NAME}" | jq -r '.[0].RootFS.Layers | length')
echo "Layer count: ${LAYER_COUNT}"

# Summary
echo ""
echo "==================================="
if [[ ${FAILED_CHECKS} -eq 0 ]]; then
	echo -e "${GREEN}✓ ALL CHECKS PASSED${NC}"
	echo "==================================="
	exit 0
else
	echo -e "${RED}✗ ${FAILED_CHECKS} CHECK(S) FAILED${NC}"
	echo "==================================="
	exit 1
fi
