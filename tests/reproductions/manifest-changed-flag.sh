#!/usr/bin/env bash
# Purpose: Minimal reproduction for manifest metadata "changed" flag bug
# Bug: generate-manifest.sh always reports metadata.changed as "true" even on identical builds
# Usage: Run from repository root: bash tests/reproductions/manifest-changed-flag.sh
# Expectation: Second manifest should report metadata.changed == false when no dependencies change
# Actual: Second manifest still reports metadata.changed == true for every hook
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
	echo "This repro requires jq (JSON processor) to be installed." >&2
	exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

MANIFEST_ONE="${TMPDIR}/manifest-first.json"
MANIFEST_TWO="${TMPDIR}/manifest-second.json"

# Common build metadata (keep constant between runs)
REPRO_IMAGE_NAME="${REPRO_IMAGE_NAME:-repro.dudley/example:latest}"
REPRO_BASE_IMAGE="${REPRO_BASE_IMAGE:-ghcr.io/ublue-os/bluefin-dx:stable}"
REPRO_GIT_COMMIT="${REPRO_GIT_COMMIT:-deadbee}"

run_manifest_generation() {
	local output_path="$1"

	(
		cd "$PROJECT_ROOT"
		MANIFEST_OUTPUT="$output_path" \
			IMAGE_NAME="$REPRO_IMAGE_NAME" \
			BASE_IMAGE="$REPRO_BASE_IMAGE" \
			GIT_COMMIT="$REPRO_GIT_COMMIT" \
			bash build_files/shared/utils/generate-manifest.sh >/dev/null
	)
}

run_manifest_generation "$MANIFEST_ONE"
run_manifest_generation "$MANIFEST_TWO"

assert_changed_flag() {
	local hook_name="$1"
	local manifest_path="$2"
	local expected="false"
	local actual

	actual="$(jq -r ".hooks[\"${hook_name}\"].metadata.changed" "$manifest_path")"

	if [[ "$actual" != "$expected" ]]; then
		cat <<EOF
Bug reproduced for hook "${hook_name}":
  Expected metadata.changed = ${expected}
  Actual metadata.changed   = ${actual}
  Manifest path: ${manifest_path}
EOF
		return 1
	fi
}

# The second manifest should mark hooks as unchanged because no dependencies changed between runs.
assert_changed_flag "wallpaper" "$MANIFEST_TWO"
assert_changed_flag "vscode-extensions" "$MANIFEST_TWO"
assert_changed_flag "holotree-init" "$MANIFEST_TWO"

cat <<'EOF'
Reproduction complete: manifest metadata.changed stayed "false" after identical rebuild.
If this message prints, the bug is no longer present.
EOF
