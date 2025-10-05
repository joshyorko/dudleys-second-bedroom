#!/usr/bin/bash
# Test script for packages.json validation

set -euo pipefail

PACKAGES_FILE="packages.json"
SCHEMA_FILE="package-config-schema.json"

echo "=== Package Configuration Validation Test ==="
echo

# Test 1: JSON syntax validity
echo "Test 1: Checking JSON syntax..."
if jq empty "$PACKAGES_FILE" 2>/dev/null; then
    echo "✓ JSON syntax is valid"
else
    echo "✗ ERROR: Invalid JSON syntax"
    exit 1
fi

# Test 2: Required fields
echo "Test 2: Checking required fields..."
if jq -e '.all' "$PACKAGES_FILE" >/dev/null 2>&1; then
    echo "✓ Required 'all' field exists"
else
    echo "✗ ERROR: Missing required 'all' field"
    exit 1
fi

# Test 3: Check for duplicate packages in install list
echo "Test 3: Checking for duplicate packages..."
if [[ $(jq -r '.all.install[]' "$PACKAGES_FILE" 2>/dev/null | wc -l) -gt 0 ]]; then
    duplicates=$(jq -r '.all.install[]' "$PACKAGES_FILE" | sort | uniq -d)
    if [[ -n "$duplicates" ]]; then
        echo "✗ ERROR: Duplicate packages found: $duplicates"
        exit 1
    else
        echo "✓ No duplicate packages in install list"
    fi
else
    echo "✓ Install list is empty (no duplicates possible)"
fi

# Test 4: Check for conflicts (package in both install and remove)
echo "Test 4: Checking for install/remove conflicts..."
if [[ $(jq -r '.all.install[]' "$PACKAGES_FILE" 2>/dev/null | wc -l) -gt 0 ]] && \
   [[ $(jq -r '.all.remove[]' "$PACKAGES_FILE" 2>/dev/null | wc -l) -gt 0 ]]; then
    conflicts=$(comm -12 \
        <(jq -r '.all.install[]' "$PACKAGES_FILE" | sort) \
        <(jq -r '.all.remove[]' "$PACKAGES_FILE" | sort))
    if [[ -n "$conflicts" ]]; then
        echo "✗ ERROR: Packages in both install and remove: $conflicts"
        exit 1
    else
        echo "✓ No conflicts between install and remove lists"
    fi
else
    echo "✓ No conflicts possible (one or both lists empty)"
fi

# Test 5: Check package name format
echo "Test 5: Checking package name format..."
invalid_packages=$(jq -r '.all.install[]' "$PACKAGES_FILE" 2>/dev/null | grep -v '^[a-zA-Z0-9._+-]*$' || true)
if [[ -n "$invalid_packages" ]]; then
    echo "✗ ERROR: Invalid package names found: $invalid_packages"
    exit 1
else
    echo "✓ All package names follow valid format"
fi

# Test 6: Check COPR repo format (if present)
echo "Test 6: Checking COPR repo format..."
if jq -e '.all.copr_repos' "$PACKAGES_FILE" >/dev/null 2>&1; then
    invalid_coprs=$(jq -r '.all.copr_repos[]?' "$PACKAGES_FILE" 2>/dev/null | grep -v '^[a-zA-Z0-9_-]*/[a-zA-Z0-9_-]*$' || true)
    if [[ -n "$invalid_coprs" ]]; then
        echo "✗ ERROR: Invalid COPR repo format: $invalid_coprs"
        exit 1
    else
        echo "✓ COPR repo format is valid"
    fi
else
    echo "✓ No COPR repos defined (skipping)"
fi

echo
echo "=== All package validation tests passed! ==="
exit 0
