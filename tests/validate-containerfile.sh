#!/usr/bin/bash
# Test script for Containerfile validation

set -euo pipefail

CONTAINERFILE="Containerfile"

echo "=== Containerfile Validation Test ==="
echo

# Test 1: File exists
echo "Test 1: Checking if Containerfile exists..."
if [[ -f "$CONTAINERFILE" ]]; then
    echo "✓ Containerfile found"
else
    echo "✗ ERROR: Containerfile not found"
    exit 1
fi

# Test 2: Has FROM directive
echo "Test 2: Checking for FROM directive..."
if grep -q "^FROM" "$CONTAINERFILE"; then
    echo "✓ FROM directive present"
else
    echo "✗ ERROR: No FROM directive found"
    exit 1
fi

# Test 3: Check for stage names (multi-stage)
echo "Test 3: Checking for multi-stage build..."
stage_count=$(grep -c "^FROM.*AS" "$CONTAINERFILE" || echo "0")
if [[ $stage_count -gt 0 ]]; then
    echo "✓ Multi-stage build detected ($stage_count stages)"
else
    echo "⚠ WARNING: Single-stage build (multi-stage recommended)"
fi

# Test 4: Check for duplicate stage names
echo "Test 4: Checking for duplicate stage names..."
stage_names=$(grep "^FROM.*AS" "$CONTAINERFILE" | awk '{print $NF}' | sort)
duplicate_stages=$(echo "$stage_names" | uniq -d)
if [[ -n "$duplicate_stages" ]]; then
    echo "✗ ERROR: Duplicate stage names: $duplicate_stages"
    exit 1
else
    echo "✓ No duplicate stage names"
fi

# Test 5: Check for cache mount usage (BuildKit optimization)
echo "Test 5: Checking for BuildKit cache mounts..."
if grep -q "mount=type=cache" "$CONTAINERFILE"; then
    echo "✓ BuildKit cache mounts detected"
else
    echo "⚠ WARNING: No cache mounts found (consider adding for performance)"
fi

# Test 6: Check for bind mounts
echo "Test 6: Checking for bind mounts..."
if grep -q "mount=type=bind" "$CONTAINERFILE"; then
    echo "✓ Bind mounts detected"
else
    echo "⚠ WARNING: No bind mounts found"
fi

# Test 7: Run hadolint if available
echo "Test 7: Running hadolint (if available)..."
if command -v hadolint &>/dev/null; then
    if hadolint "$CONTAINERFILE"; then
        echo "✓ hadolint passed"
    else
        echo "⚠ WARNING: hadolint found issues (non-blocking)"
    fi
else
    echo "⚠ hadolint not available, skipping"
fi

echo
echo "=== Containerfile validation complete ==="
exit 0
