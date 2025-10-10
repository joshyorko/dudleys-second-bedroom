#!/usr/bin/env bash

#
# Purpose: Unit tests for manifest-builder.sh utilities
# Dependencies: bash 5.x, jq, manifest-builder.sh
# Author: Dudley's Second Bedroom Project
# Date: 2025-10-10
#

set -euo pipefail

# Disable exit on error for tests (we want to catch failures)
set +e

# Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Source the utility module
# shellcheck source=../build_files/shared/utils/manifest-builder.sh
source "$PROJECT_ROOT/build_files/shared/utils/manifest-builder.sh"

# Re-disable exit on error for tests (sourced file re-enables it)
set +e

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

# Test: init_manifest creates valid structure
test_init_manifest() {
    local manifest
    manifest=$(init_manifest "test-image:tag" "base-image:tag" "abc1234")
    
    # Parse with jq to validate JSON
    if ! echo "$manifest" | jq -e . >/dev/null 2>&1; then
        fail "init_manifest creates valid JSON" "Failed to parse as JSON"
        return
    fi
    
    # Check required fields
    local version build_date image base commit
    version=$(echo "$manifest" | jq -r '.version')
    build_date=$(echo "$manifest" | jq -r '.build.date')
    image=$(echo "$manifest" | jq -r '.build.image')
    base=$(echo "$manifest" | jq -r '.build.base')
    commit=$(echo "$manifest" | jq -r '.build.commit')
    
    if [[ "$version" == "1.0.0" ]] && \
       [[ -n "$build_date" ]] && \
       [[ "$image" == "test-image:tag" ]] && \
       [[ "$base" == "base-image:tag" ]] && \
       [[ "$commit" == "abc1234" ]]; then
        pass "init_manifest creates valid structure"
    else
        fail "init_manifest structure" "Missing or invalid fields"
    fi
}

# Test: add_hook_to_manifest adds single hook
test_add_single_hook() {
    local manifest
    manifest=$(init_manifest "test:tag" "base:tag" "abc1234")
    
    # Skip metadata for simplicity (it's optional)
    manifest=$(add_hook_to_manifest "$manifest" \
        "test-hook" \
        "8f7a2c3d" \
        '["file1.sh", "file2.txt"]')
    
    local hook_version
    hook_version=$(echo "$manifest" | jq -r '.hooks["test-hook"].version')
    
    if [[ "$hook_version" == "8f7a2c3d" ]]; then
        pass "add_hook_to_manifest adds single hook"
    else
        fail "add single hook" "Hook not found or incorrect version: $hook_version"
    fi
}

# Test: add_hook_to_manifest adds multiple hooks
test_add_multiple_hooks() {
    local manifest
    manifest=$(init_manifest "test:tag" "base:tag" "abc1234")
    
    manifest=$(add_hook_to_manifest "$manifest" "hook1" "11111111" '["f1"]')
    manifest=$(add_hook_to_manifest "$manifest" "hook2" "22222222" '["f2"]')
    manifest=$(add_hook_to_manifest "$manifest" "hook3" "33333333" '["f3"]')
    
    local count
    count=$(echo "$manifest" | jq '.hooks | length')
    
    local h1 h2 h3
    h1=$(echo "$manifest" | jq -r '.hooks.hook1.version')
    h2=$(echo "$manifest" | jq -r '.hooks.hook2.version')
    h3=$(echo "$manifest" | jq -r '.hooks.hook3.version')
    
    if [[ $count -eq 3 ]] && [[ "$h1" == "11111111" ]] && [[ "$h2" == "22222222" ]] && [[ "$h3" == "33333333" ]]; then
        pass "add_hook_to_manifest adds multiple hooks"
    else
        fail "add multiple hooks" "count=$count, h1=$h1, h2=$h2, h3=$h3"
    fi
}

# Test: add_hook_to_manifest rejects invalid hook name
test_invalid_hook_name() {
    local manifest
    manifest=$(init_manifest "test:tag" "base:tag" "abc1234")
    
    local exit_code=0
    add_hook_to_manifest "$manifest" "bad name!" "8f7a2c3d" '["file"]' 2>/dev/null || exit_code=$?
    
    if [[ $exit_code -eq 1 ]]; then
        pass "add_hook_to_manifest rejects invalid hook name"
    else
        fail "reject invalid hook name" "Expected exit 1, got $exit_code"
    fi
}

# Test: add_hook_to_manifest rejects invalid hash
test_invalid_hash() {
    local manifest
    manifest=$(init_manifest "test:tag" "base:tag" "abc1234")
    
    local exit_code=0
    add_hook_to_manifest "$manifest" "test-hook" "INVALID" '["file"]' 2>/dev/null || exit_code=$?
    
    if [[ $exit_code -eq 1 ]]; then
        pass "add_hook_to_manifest rejects invalid hash"
    else
        fail "reject invalid hash" "Expected exit 1, got $exit_code"
    fi
}

# Test: write_manifest creates file with 644 permissions
test_write_manifest_permissions() {
    local manifest
    manifest=$(init_manifest "test:tag" "base:tag" "abc1234")
    manifest=$(add_hook_to_manifest "$manifest" "hook" "8f7a2c3d" '["file"]')
    
    local output_file="$TEST_DIR/test-manifest.json"
    write_manifest "$manifest" "$output_file" 2>/dev/null
    
    if [[ -f "$output_file" ]]; then
        local perms
        perms=$(stat -c "%a" "$output_file" 2>/dev/null || stat -f "%Lp" "$output_file" 2>/dev/null)
        if [[ "$perms" == "644" ]]; then
            pass "write_manifest creates file with 644 permissions"
        else
            fail "write manifest permissions" "Expected 644, got $perms"
        fi
    else
        fail "write manifest" "File not created"
    fi
}

# Test: write_manifest fails on invalid JSON
test_write_invalid_json() {
    local exit_code=0
    write_manifest "invalid json{" "$TEST_DIR/invalid.json" 2>/dev/null || exit_code=$?
    
    if [[ $exit_code -eq 1 ]] && [[ ! -f "$TEST_DIR/invalid.json" ]]; then
        pass "write_manifest fails on invalid JSON"
    else
        fail "write invalid JSON" "Expected exit 1 and no file, got exit $exit_code"
    fi
}

# Test: validate_manifest_schema passes valid manifest
test_validate_valid_manifest() {
    local manifest
    manifest=$(init_manifest "test:tag" "base:tag" "abc1234")
    manifest=$(add_hook_to_manifest "$manifest" "hook" "8f7a2c3d" '["file"]')
    
    if validate_manifest_schema "$manifest" 2>/dev/null; then
        pass "validate_manifest_schema passes valid manifest"
    else
        fail "validate valid manifest" "Valid manifest failed validation"
    fi
}

# Test: validate_manifest_schema fails on missing field
test_validate_missing_field() {
    local manifest='{"version":"1.0.0","build":{},"hooks":{"h":{"version":"12345678","dependencies":["f"]}}}'
    
    local exit_code=0
    validate_manifest_schema "$manifest" 2>/dev/null || exit_code=$?
    
    if [[ $exit_code -eq 1 ]]; then
        pass "validate_manifest_schema fails on missing build fields"
    else
        fail "validate missing field" "Expected failure, got exit $exit_code"
    fi
}

# Test: validate_manifest_schema fails on empty hooks
test_validate_empty_hooks() {
    local manifest='{"version":"1.0.0","build":{"date":"2025-01-01T00:00:00Z","image":"i:t","base":"b:t","commit":"abc1234"},"hooks":{}}'
    
    local exit_code=0
    validate_manifest_schema "$manifest" 2>/dev/null || exit_code=$?
    
    if [[ $exit_code -eq 1 ]]; then
        pass "validate_manifest_schema fails on empty hooks"
    else
        fail "validate empty hooks" "Expected failure, got exit $exit_code"
    fi
}

# Run all tests
echo "========================================="
echo "Manifest Builder Utility Tests"
echo "========================================="
echo ""

test_init_manifest
test_add_single_hook
test_add_multiple_hooks
test_invalid_hook_name
test_invalid_hash
test_write_manifest_permissions
test_write_invalid_json
test_validate_valid_manifest
test_validate_missing_field
test_validate_empty_hooks

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
    echo "✓ All tests passed!"
    exit 0
else
    echo ""
    echo "✗ Some tests failed"
    exit 1
fi
