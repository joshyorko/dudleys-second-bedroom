#!/usr/bin/env bash
# Test image-info metadata contracts used by Bluefin runtime recipes.

set -euo pipefail

TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

IMAGE_INFO_DIR="$TEST_DIR/ublue-os"
OS_RELEASE_FILE="$TEST_DIR/os-release"
mkdir -p "$IMAGE_INFO_DIR"
cat >"$OS_RELEASE_FILE" <<'EOF'
VERSION_ID=44
VARIANT_ID=bluefin-dx
EOF

IMAGE_NAME="dudleys-second-bedroom" \
	IMAGE_TAG="latest" \
	IMAGE_REF="ghcr.io/joshyorko/dudleys-second-bedroom:latest" \
	BASE_IMAGE="ghcr.io/ublue-os/bluefin-dx:latest@sha256:abc123" \
	IMAGE_INFO_DIR="$IMAGE_INFO_DIR" \
	OS_RELEASE_FILE="$OS_RELEASE_FILE" \
	bash build_files/shared/00-image-info.sh >/tmp/test-image-info.log

IMAGE_INFO="$IMAGE_INFO_DIR/image-info.json"

assert_json() {
	local query="$1"
	local expected="$2"
	local actual

	actual="$(jq -r "$query" "$IMAGE_INFO")"
	if [[ "$actual" != "$expected" ]]; then
		echo "FAIL: $query expected '$expected', got '$actual'" >&2
		exit 1
	fi
}

assert_json '."image-ref"' "ostree-image-signed:docker://ghcr.io/joshyorko/dudleys-second-bedroom"
assert_json '."image-tag"' "latest"
assert_json '."image-flavor"' "dx"
assert_json '."base-image-name"' "bluefin-dx"

if ! grep -q '^VARIANT_ID="bluefin-dx"$' "$OS_RELEASE_FILE"; then
	echo "FAIL: os-release custom VARIANT_ID did not preserve the inherited base variant" >&2
	exit 1
fi

echo "PASS: image-info preserves Dudley DX runtime metadata"
