#!/usr/bin/env bash

#
# Purpose: Integration tests for hook content versioning
# Dependencies: bash 5.x, jq
# Author: Dudley's Second Bedroom Project
# Date: 2025-10-10
#

set -euo pipefail

# Disable exit on error for tests
set +e

# Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
pass() {
	echo "✓ PASS: $1"
	((TESTS_PASSED++))
	((TESTS_RUN++))
}

fail() {
	echo "✗ FAIL: $1"
	if [[ -n "${2:-}" ]]; then
		echo "  Details: $2"
	fi
	((TESTS_FAILED++))
	((TESTS_RUN++))
}

echo "========================================="
echo "Hook Integration Tests"
echo "========================================="
echo ""

# Test: Hook scripts contain __CONTENT_VERSION__ placeholder
test_placeholders_present() {
	local hooks=(
		"$PROJECT_ROOT/build_files/user-hooks/10-wallpaper-enforcement.sh"
		"$PROJECT_ROOT/build_files/user-hooks/20-vscode-extensions.sh"
		"$PROJECT_ROOT/build_files/user-hooks/30-holotree-init.sh"
	)

	local all_have_placeholder=true
	for hook in "${hooks[@]}"; do
		if ! grep -q "__CONTENT_VERSION__" "$hook"; then
			all_have_placeholder=false
			fail "Placeholder check" "Missing __CONTENT_VERSION__ in $(basename "$hook")"
			return
		fi
	done

	if $all_have_placeholder; then
		pass "All hook scripts contain __CONTENT_VERSION__ placeholder"
	fi
}

# Test: Hooks use version-script function
test_version_script_usage() {
	local hooks=(
		"$PROJECT_ROOT/build_files/user-hooks/10-wallpaper-enforcement.sh"
		"$PROJECT_ROOT/build_files/user-hooks/20-vscode-extensions.sh"
		"$PROJECT_ROOT/build_files/user-hooks/30-holotree-init.sh"
	)

	local all_use_version_script=true
	for hook in "${hooks[@]}"; do
		if ! grep -q "version-script" "$hook"; then
			all_use_version_script=false
			fail "version-script usage" "Missing version-script call in $(basename "$hook")"
			return
		fi
	done

	if $all_use_version_script; then
		pass "All hook scripts use version-script function"
	fi
}

# Test: Hooks source libsetup.sh
test_libsetup_sourced() {
	local hooks=(
		"$PROJECT_ROOT/build_files/user-hooks/10-wallpaper-enforcement.sh"
		"$PROJECT_ROOT/build_files/user-hooks/20-vscode-extensions.sh"
		"$PROJECT_ROOT/build_files/user-hooks/30-holotree-init.sh"
	)

	local all_source_libsetup=true
	for hook in "${hooks[@]}"; do
		if ! grep -q "source.*libsetup.sh" "$hook"; then
			all_source_libsetup=false
			fail "libsetup.sh sourcing" "Missing libsetup.sh source in $(basename "$hook")"
			return
		fi
	done

	if $all_source_libsetup; then
		pass "All hook scripts source libsetup.sh"
	fi
}

# Test: Generate manifest produces valid JSON
test_manifest_generation() {
	local temp_manifest
	temp_manifest=$(mktemp)
	trap 'rm -f "$temp_manifest"' RETURN

	if MANIFEST_OUTPUT="$temp_manifest" bash "$PROJECT_ROOT/build_files/shared/utils/generate-manifest.sh" >/dev/null 2>&1; then
		if [[ -f "$temp_manifest" ]] && jq -e . "$temp_manifest" >/dev/null 2>&1; then
			pass "Manifest generation produces valid JSON"
		else
			fail "Manifest generation" "Invalid or missing JSON output"
		fi
	else
		fail "Manifest generation" "Script execution failed"
	fi
}

# Test: Manifest contains all three hooks
test_manifest_hooks() {
	local temp_manifest
	temp_manifest=$(mktemp)
	trap 'rm -f "$temp_manifest"' RETURN

	MANIFEST_OUTPUT="$temp_manifest" bash "$PROJECT_ROOT/build_files/shared/utils/generate-manifest.sh" >/dev/null 2>&1

	if [[ -f "$temp_manifest" ]]; then
		local wallpaper vscode holotree
		wallpaper=$(jq -r '.hooks.wallpaper.version' "$temp_manifest")
		vscode=$(jq -r '.hooks["vscode-extensions"].version' "$temp_manifest")
		holotree=$(jq -r '.hooks["holotree-init"].version' "$temp_manifest")

		if [[ "$wallpaper" =~ ^[a-f0-9]{8}$ ]] &&
			[[ "$vscode" =~ ^[a-f0-9]{8}$ ]] &&
			[[ "$holotree" =~ ^[a-f0-9]{8}$ ]]; then
			pass "Manifest contains all hooks with valid version hashes"
		else
			fail "Manifest hooks" "Missing or invalid hook versions: wallpaper=$wallpaper, vscode=$vscode, holotree=$holotree"
		fi
	else
		fail "Manifest hooks" "Manifest file not created"
	fi
}

# Test: Manifest size < 50KB
test_manifest_size() {
	local temp_manifest
	temp_manifest=$(mktemp)
	trap 'rm -f "$temp_manifest"' RETURN

	MANIFEST_OUTPUT="$temp_manifest" bash "$PROJECT_ROOT/build_files/shared/utils/generate-manifest.sh" >/dev/null 2>&1

	if [[ -f "$temp_manifest" ]]; then
		local size
		size=$(stat -c%s "$temp_manifest" 2>/dev/null || stat -f%z "$temp_manifest" 2>/dev/null)

		if [[ $size -lt 51200 ]]; then
			pass "Manifest size < 50KB ($((size / 1024)) KB)"
		else
			fail "Manifest size" "Manifest exceeds 50KB: $((size / 1024)) KB"
		fi
	else
		fail "Manifest size" "Manifest file not created"
	fi
}

# Test: Hooks have fail-fast error handling
test_hook_error_handling() {
	local hooks=(
		"$PROJECT_ROOT/build_files/user-hooks/10-wallpaper-enforcement.sh"
		"$PROJECT_ROOT/build_files/user-hooks/20-vscode-extensions.sh"
		"$PROJECT_ROOT/build_files/user-hooks/30-holotree-init.sh"
	)

	local all_have_failfast=true
	for hook in "${hooks[@]}"; do
		# Check for set -euo pipefail in the heredoc content
		if ! grep -A5 "'HOOK_EOF'" "$hook" | grep -q "set -euo pipefail"; then
			all_have_failfast=false
			fail "Fail-fast error handling" "Missing 'set -euo pipefail' in runtime hook: $(basename "$hook")"
			return
		fi
	done

	if $all_have_failfast; then
		pass "All runtime hooks have fail-fast error handling"
	fi
}

# Test: Hooks have logging statements
test_hook_logging() {
	local hooks=(
		"$PROJECT_ROOT/build_files/user-hooks/10-wallpaper-enforcement.sh"
		"$PROJECT_ROOT/build_files/user-hooks/20-vscode-extensions.sh"
		"$PROJECT_ROOT/build_files/user-hooks/30-holotree-init.sh"
	)

	local all_have_logging=true
	for hook in "${hooks[@]}"; do
		if ! grep -q "Dudley Hook:" "$hook"; then
			all_have_logging=false
			fail "Hook logging" "Missing logging statements in $(basename "$hook")"
			return
		fi
	done

	if $all_have_logging; then
		pass "All hook scripts have logging statements"
	fi
}

# Run all tests
test_placeholders_present
test_version_script_usage
test_libsetup_sourced
test_manifest_generation
test_manifest_hooks
test_manifest_size
test_hook_error_handling
test_hook_logging

# Summary
echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
echo "Tests run:    $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"

if [[ $TESTS_FAILED -eq 0 ]]; then
	echo ""
	echo "✓ All integration tests passed!"
	exit 0
else
	echo ""
	echo "✗ Some tests failed"
	exit 1
fi
