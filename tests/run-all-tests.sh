#!/usr/bin/bash
# Integration test runner - runs all validation tests

set -euo pipefail

echo "========================================"
echo "  Integration Test Suite"
echo "========================================"
echo

TEST_DIR="tests"
PASSED=0
FAILED=0
TOTAL=0

# Array to store failed tests
declare -a FAILED_TESTS

# Run each test script
for test_script in "$TEST_DIR"/validate-*.sh; do
    if [[ -f "$test_script" ]]; then
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
    fi
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
