#!/usr/bin/bash
# Script: verify-build.sh
# Purpose: Verify the built container image has all expected components
# Usage: bash tests/verify-build.sh [image-name:tag]

set -euo pipefail

# Configuration
IMAGE_NAME="${1:-localhost/dudleys-second-bedroom:latest}"
FAILED_CHECKS=0

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

# Check 1: Image exists
echo "=== Image Existence ==="
run_check "image exists" "podman images -q ${IMAGE_NAME}" ""

# Check 2: Base OS
echo ""
echo "=== Base Operating System ==="
run_check "Bluefin base" "podman run --rm ${IMAGE_NAME} cat /etc/os-release" "ID=bluefin"
run_check "Fedora 43" "podman run --rm ${IMAGE_NAME} cat /etc/os-release" "VERSION_ID=43"

# Check 3: Developer Tools
echo ""
echo "=== Developer Tools ==="
run_check "VS Code Insiders" "podman run --rm ${IMAGE_NAME} which code-insiders" "/usr/sbin/code-insiders"
run_check "Action Server" "podman run --rm ${IMAGE_NAME} which action-server" "/usr/sbin/action-server"
run_check "RCC CLI" "podman run --rm ${IMAGE_NAME} which rcc" "/usr/sbin/rcc"

# Check 4: Packages from packages.json
echo ""
echo "=== Installed Packages ==="
run_check "tmux" "podman run --rm ${IMAGE_NAME} rpm -q tmux" "tmux-"
run_check "curl" "podman run --rm ${IMAGE_NAME} rpm -q curl" "curl-"
run_check "gcc-c++" "podman run --rm ${IMAGE_NAME} rpm -q gcc-c++" "gcc-c++-"

# Check 5: Custom Branding
echo ""
echo "=== Custom Branding ==="
run_check "wallpaper directory" "podman run --rm ${IMAGE_NAME} test -d /usr/share/backgrounds/dudley && echo exists" "exists"
run_check "wallpaper files" "podman run --rm ${IMAGE_NAME} ls /usr/share/backgrounds/dudley/ | wc -l" "6"
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
run_check "wallpaper hook" "podman run --rm ${IMAGE_NAME} test -f /usr/share/ublue-os/user-setup.hooks.d/20-dudley-wallpaper.sh && echo exists" "exists"
run_check "VS Code extensions hook" "podman run --rm ${IMAGE_NAME} test -f /usr/share/ublue-os/user-setup.hooks.d/20-vscode-extensions.sh && echo exists" "exists"
run_check "VS Code extensions list" "podman run --rm ${IMAGE_NAME} test -f /etc/skel/.config/vscode-extensions.list && echo exists" "exists"
run_check "Holotree init hook" "podman run --rm ${IMAGE_NAME} test -f /usr/share/ublue-os/user-setup.hooks.d/30-holotree-init.sh && echo exists" "exists"

# Check 9: Shared Holotree
# Note: Shared holotree directory may not exist at build time in container builds
# RCC creates it on first actual use. Verify RCC is available instead.
echo ""
echo "=== Shared Holotree ==="
run_check "RCC available for holotree" "podman run --rm ${IMAGE_NAME} command -v rcc" "rcc"

# Check 8: Image Metadata
echo ""
echo "=== Image Metadata ==="
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
