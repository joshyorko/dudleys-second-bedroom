#!/usr/bin/env bash

#
# Purpose: Unit tests for content-versioning.sh utilities
# Dependencies: bash 5.x, content-versioning.sh
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
# shellcheck source=../build_files/shared/utils/content-versioning.sh
source "$PROJECT_ROOT/build_files/shared/utils/content-versioning.sh"

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

# Test: Hash determinism (compute same hash 10 times, assert identical)
test_hash_determinism() {
    echo "test content" > "$TEST_DIR/test1.txt"
    
    local hashes=()
    for _ in {1..10}; do
        hashes+=("$(compute_content_hash "$TEST_DIR/test1.txt")")
    done
    
    local first_hash="${hashes[0]}"
    local all_same=true
    
    for hash in "${hashes[@]}"; do
        if [[ "$hash" != "$first_hash" ]]; then
            all_same=false
            break
        fi
    done
    
    if $all_same; then
        pass "Hash determinism (10 iterations identical)"
    else
        fail "Hash determinism" "Hashes varied across iterations"
    fi
}

# Test: Multi-file ordering (hash(a,b,c) == hash(c,b,a), verifies sorting)
test_multifile_ordering() {
    echo "file a" > "$TEST_DIR/a.txt"
    echo "file b" > "$TEST_DIR/b.txt"
    echo "file c" > "$TEST_DIR/c.txt"
    
    local hash1
    hash1=$(compute_content_hash "$TEST_DIR/a.txt" "$TEST_DIR/b.txt" "$TEST_DIR/c.txt")
    local hash2
    hash2=$(compute_content_hash "$TEST_DIR/c.txt" "$TEST_DIR/b.txt" "$TEST_DIR/a.txt")
    
    if [[ "$hash1" == "$hash2" ]]; then
        pass "Multi-file ordering (hash order-independent)"
    else
        fail "Multi-file ordering" "hash1=$hash1, hash2=$hash2"
    fi
}

# Test: Missing file error (assert exit 1, error message contains filename)
test_missing_file_error() {
    local output
    local exit_code=0
    
    output=$(compute_content_hash "$TEST_DIR/nonexistent.txt" 2>&1) || exit_code=$?
    
    if [[ $exit_code -eq 1 ]] && [[ "$output" =~ nonexistent.txt ]]; then
        pass "Missing file error handling"
    else
        fail "Missing file error" "exit_code=$exit_code, output=$output"
    fi
}

# Test: Placeholder replacement success (assert hash present, placeholder gone)
test_placeholder_replacement_success() {
    echo 'version-script "test" "__CONTENT_VERSION__"' > "$TEST_DIR/hook.sh"
    
    local test_hash="8f7a2c3d"
    replace_version_placeholder "$TEST_DIR/hook.sh" "$test_hash" 2>/dev/null
    
    local content
    content=$(cat "$TEST_DIR/hook.sh")
    
    if [[ "$content" =~ $test_hash ]] && ! [[ "$content" =~ __CONTENT_VERSION__ ]]; then
        pass "Placeholder replacement success"
    else
        fail "Placeholder replacement" "content=$content"
    fi
}

# Test: Placeholder replacement - no placeholder (assert warning, exit 0)
test_placeholder_no_placeholder() {
    echo 'echo "no placeholder here"' > "$TEST_DIR/hook_no_placeholder.sh"
    
    local exit_code=0
    local output
    output=$(replace_version_placeholder "$TEST_DIR/hook_no_placeholder.sh" "8f7a2c3d" 2>&1) || exit_code=$?
    
    if [[ $exit_code -eq 0 ]] && [[ "$output" =~ WARNING ]]; then
        pass "Placeholder replacement with no placeholder (warns but succeeds)"
    else
        fail "Placeholder no placeholder" "exit_code=$exit_code, output=$output"
    fi
}

# Test: Hash format validation (valid cases exit 0, invalid exit 1)
test_hash_format_validation() {
    local valid_tests=("abcd1234" "deadbeef" "00000000" "ffffffff")
    local invalid_tests=("ABCD1234" "abcd123" "abcd12345" "ghij1234" "abcd-234" "")
    
    local all_valid_pass=true
    for hash in "${valid_tests[@]}"; do
        if ! validate_hash_format "$hash"; then
            all_valid_pass=false
            fail "Hash format validation (valid)" "Failed on valid hash: $hash"
            return
        fi
    done
    
    local all_invalid_fail=true
    for hash in "${invalid_tests[@]}"; do
        if validate_hash_format "$hash"; then
            all_invalid_fail=false
            fail "Hash format validation (invalid)" "Passed on invalid hash: '$hash'"
            return
        fi
    done
    
    if $all_valid_pass && $all_invalid_fail; then
        pass "Hash format validation (all cases)"
    fi
}

# Test: Hash is 8 characters
test_hash_length() {
    echo "test" > "$TEST_DIR/hashtest.txt"
    local hash
    hash=$(compute_content_hash "$TEST_DIR/hashtest.txt")
    
    if [[ ${#hash} -eq 8 ]]; then
        pass "Hash length is 8 characters"
    else
        fail "Hash length" "Expected 8 chars, got ${#hash}: $hash"
    fi
}

# Test: Hash contains only hex characters
test_hash_format() {
    echo "test" > "$TEST_DIR/hextest.txt"
    local hash
    hash=$(compute_content_hash "$TEST_DIR/hextest.txt")
    
    if [[ "$hash" =~ ^[a-f0-9]{8}$ ]]; then
        pass "Hash format is lowercase hex"
    else
        fail "Hash format" "Hash contains non-hex: $hash"
    fi
}

# Run all tests
echo "========================================="
echo "Content Versioning Utility Tests"
echo "========================================="
echo ""

test_hash_determinism
test_multifile_ordering
test_missing_file_error
test_placeholder_replacement_success
test_placeholder_no_placeholder
test_hash_format_validation
test_hash_length
test_hash_format

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
