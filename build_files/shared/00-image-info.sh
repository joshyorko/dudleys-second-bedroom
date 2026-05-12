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
IMAGE_TAG="${IMAGE_TAG:-${DEFAULT_TAG:-latest}}"
IMAGE_VENDOR="${IMAGE_VENDOR:-joshyorko}"
VERSION="${VERSION:-$(date +%Y%m%d)}"

# Normalize image references to the contract Bluefin recipes expect:
# image-ref is the repository ref without a tag, while image-tag carries the tag.
normalize_transport_ref() {
	local ref="$1"
	ref="${ref#ostree-image-signed:docker://}"
	ref="${ref#docker://}"
	printf '%s' "$ref"
}

strip_ref_tag() {
	local ref="$1"
	local digestless="${ref%@*}"
	local last_component="${digestless##*/}"

	if [[ "$last_component" == *:* ]]; then
		printf '%s' "${digestless%:*}"
	else
		printf '%s' "$digestless"
	fi
}

ref_tag() {
	local ref="$1"
	local digestless="${ref%@*}"
	local last_component="${digestless##*/}"

	if [[ "$last_component" == *:* ]]; then
		printf '%s' "${last_component##*:}"
	else
		printf '%s' "$IMAGE_TAG"
	fi
}

image_name_from_ref() {
	local ref="$1"
	local digestless="${ref%@*}"
	local last_component="${digestless##*/}"
	printf '%s' "${last_component%%:*}"
}

# Logging helper
log() {
	local level=$1
	shift
	echo "[MODULE:${CATEGORY}/${MODULE_NAME}] ${level}: $*"
}

log "INFO" "START - Generating image-info.json"

# Create directory for image info
IMAGE_INFO_DIR="${IMAGE_INFO_DIR:-/usr/share/ublue-os}"
mkdir -p "$IMAGE_INFO_DIR"

IMAGE_INFO="$IMAGE_INFO_DIR/image-info.json"
OCI_IMAGE_REF="$(normalize_transport_ref "${IMAGE_REF:-ghcr.io/$IMAGE_VENDOR/$IMAGE_NAME:$IMAGE_TAG}")"
IMAGE_REPOSITORY_REF="$(strip_ref_tag "$OCI_IMAGE_REF")"
IMAGE_TAG="$(ref_tag "$OCI_IMAGE_REF")"
BASE_IMAGE_REF="$(normalize_transport_ref "${BASE_IMAGE:-}")"
BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-$(image_name_from_ref "$BASE_IMAGE_REF")}"
if [[ -z "$BASE_IMAGE_NAME" ]]; then
	BASE_IMAGE_NAME="bluefin-dx"
fi

# Determine image flavor from the custom image name and inherited base image.
image_flavor="${IMAGE_FLAVOR:-}"
if [[ -z "$image_flavor" ]]; then
	if [[ "${IMAGE_NAME}" =~ dx || "${BASE_IMAGE_NAME}" =~ dx || "${BASE_IMAGE_REF}" =~ dx ]]; then
		image_flavor="dx"
	else
		image_flavor="main"
	fi

	if [[ "${IMAGE_NAME}" =~ nvidia || "${BASE_IMAGE_NAME}" =~ nvidia || "${BASE_IMAGE_REF}" =~ nvidia ]]; then
		if [[ "$image_flavor" == "dx" ]]; then
			image_flavor="dx-nvidia"
		else
			image_flavor="nvidia"
		fi
	fi
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
  "image-ref": "ostree-image-signed:docker://${IMAGE_REPOSITORY_REF}",
  "image-tag": "$IMAGE_TAG",
  "base-image-name": "$BASE_IMAGE_NAME",
  "fedora-version": "$FEDORA_VERSION",
  "kernel-version": "$KERNEL_VERSION",
  "build-date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "git-commit": "${GIT_COMMIT:-unknown}"
}
EOF

log "INFO" "Generated image-info.json:"
cat "$IMAGE_INFO"

# Update os-release with custom branding
OS_RELEASE_FILE="${OS_RELEASE_FILE:-/usr/lib/os-release}"
if [[ -f "$OS_RELEASE_FILE" ]]; then
	log "INFO" "Updating os-release branding..."

	# Create custom os-release additions
	cat >>"$OS_RELEASE_FILE" <<EOF

# Dudley's Second Bedroom customizations
PRETTY_NAME="${IMAGE_PRETTY_NAME}"
HOME_URL="${HOME_URL}"
DOCUMENTATION_URL="${DOCUMENTATION_URL}"
SUPPORT_URL="${SUPPORT_URL}"
BUG_REPORT_URL="${BUG_SUPPORT_URL}"
VARIANT="${IMAGE_NAME}"
VARIANT_ID="${BASE_IMAGE_NAME}"
EOF
fi

log "INFO" "DONE - Image info generation complete"

echo "::endgroup::"
