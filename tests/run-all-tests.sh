#!/usr/bin/env bash
# Integration test runner - runs all validation tests

set -euo pipefail

echo "========================================"
echo "  Dudley's Content Versioning Test Suite"
echo "========================================"
echo

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASSED=0
FAILED=0
TOTAL=0

# Array to store failed tests
declare -a FAILED_TESTS

# Test patterns to run
TEST_PATTERNS=(
	"test-content-versioning.sh"
	"test-manifest-generation.sh"
	"test-hook-integration.sh"
	"validate-*.sh"
)

# Run each test pattern
for pattern in "${TEST_PATTERNS[@]}"; do
	for test_script in "$TEST_DIR"/$pattern; do
		# Check if file exists (glob may not match)
		if [[ ! -f "$test_script" ]]; then
			continue
		fi

		TOTAL=$((TOTAL + 1))
		test_name=$(basename "$test_script")

		echo "Running: $test_name"
		echo "----------------------------------------"

		if bash "$test_script"; then
			PASSED=$((PASSED + 1))
			echo "✓ $test_name PASSED"
		else
			FAILED=$((FAILED + 1))
			FAILED_TESTS+=("$test_name")
			echo "✗ $test_name FAILED"
		fi

		echo
	done
done

# Print summary
echo "========================================"
echo "  Test Summary"
echo "========================================"
echo "Total tests: $TOTAL"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo

if [[ $FAILED -gt 0 ]]; then
	echo "Failed tests:"
	for test in "${FAILED_TESTS[@]}"; do
		echo "  - $test"
	done
	echo
	echo "✗ Some tests failed"
	exit 1
else
	echo "✓ All tests passed!"
	exit 0
fi
