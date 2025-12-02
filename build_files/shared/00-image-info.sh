#!/usr/bin/env bash
# Purpose: Generate image-info.json with build metadata
# Category: shared
# Dependencies: none
# Parallel-Safe: yes
# Cache-Friendly: no (generates dynamic content)
# Author: Build System
set -euo pipefail

echo "::group:: ===$(basename "$0")==="

# Module metadata
readonly MODULE_NAME="image-info"
readonly CATEGORY="shared"

# Configuration - customize these for your image
IMAGE_PRETTY_NAME="${IMAGE_PRETTY_NAME:-Dudleys Second Bedroom}"
HOME_URL="${HOME_URL:-https://github.com/joshyorko/dudleys-second-bedroom}"
DOCUMENTATION_URL="${DOCUMENTATION_URL:-https://github.com/joshyorko/dudleys-second-bedroom#readme}"
SUPPORT_URL="${SUPPORT_URL:-https://github.com/joshyorko/dudleys-second-bedroom/issues}"
BUG_SUPPORT_URL="${BUG_SUPPORT_URL:-https://github.com/joshyorko/dudleys-second-bedroom/issues}"
CODE_NAME="${CODE_NAME:-Dudley}"
IMAGE_NAME="${IMAGE_NAME:-dudleys-second-bedroom}"
IMAGE_VENDOR="${IMAGE_VENDOR:-joshyorko}"
VERSION="${VERSION:-$(date +%Y%m%d)}"

# Logging helper
log() {
	local level=$1
	shift
	echo "[MODULE:${CATEGORY}/${MODULE_NAME}] ${level}: $*"
}

log "INFO" "START - Generating image-info.json"

# Create directory for image info
IMAGE_INFO_DIR="/usr/share/ublue-os"
mkdir -p "$IMAGE_INFO_DIR"

IMAGE_INFO="$IMAGE_INFO_DIR/image-info.json"
IMAGE_REF="ostree-image-signed:docker://ghcr.io/$IMAGE_VENDOR/$IMAGE_NAME"

# Determine image flavor based on name
image_flavor="main"
if [[ "${IMAGE_NAME}" =~ nvidia ]]; then
	image_flavor="nvidia"
elif [[ "${IMAGE_NAME}" =~ dx ]]; then
	image_flavor="dx"
fi

# Get Fedora version if available
FEDORA_VERSION=""
if [[ -f /etc/os-release ]]; then
	FEDORA_VERSION=$(grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
fi

# Get kernel version (ensure single line, no embedded newlines)
KERNEL_VERSION=""
if command -v rpm &>/dev/null; then
	KERNEL_VERSION=$(rpm -qa 'kernel-*' --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' 2>/dev/null | head -1 | tr -d '\n' || echo "unknown")
fi
# Fallback if empty
if [[ -z "$KERNEL_VERSION" ]]; then
	KERNEL_VERSION="unknown"
fi

# Generate image-info.json
cat >"$IMAGE_INFO" <<EOF
{
  "image-name": "$IMAGE_NAME",
  "image-flavor": "$image_flavor",
  "image-vendor": "$IMAGE_VENDOR",
  "image-ref": "$IMAGE_REF",
  "image-tag": "${DEFAULT_TAG:-latest}",
  "base-image-name": "${BASE_IMAGE_NAME:-bluefin-dx}",
  "fedora-version": "$FEDORA_VERSION",
  "kernel-version": "$KERNEL_VERSION",
  "build-date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "git-commit": "${GIT_COMMIT:-unknown}"
}
EOF

log "INFO" "Generated image-info.json:"
cat "$IMAGE_INFO"

# Update os-release with custom branding
if [[ -f /usr/lib/os-release ]]; then
	log "INFO" "Updating os-release branding..."

	# Create custom os-release additions
	cat >>/usr/lib/os-release <<EOF

# Dudley's Second Bedroom customizations
PRETTY_NAME="${IMAGE_PRETTY_NAME}"
HOME_URL="${HOME_URL}"
DOCUMENTATION_URL="${DOCUMENTATION_URL}"
SUPPORT_URL="${SUPPORT_URL}"
BUG_REPORT_URL="${BUG_SUPPORT_URL}"
VARIANT="${IMAGE_NAME}"
VARIANT_ID="${image_flavor}"
EOF
fi

log "INFO" "DONE - Image info generation complete"

echo "::endgroup::"
