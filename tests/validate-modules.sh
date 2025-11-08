#!/usr/bin/bash
# Test script for Build Module metadata validation

set -euo pipefail

echo "=== Build Module Metadata Validation Test ==="
echo

# Source validation utilities
if [[ -f build_files/shared/utils/validation.sh ]]; then
	# shellcheck source=build_files/shared/utils/validation.sh
	source build_files/shared/utils/validation.sh
else
	echo "✗ ERROR: validation.sh not found"
	exit 1
fi

# Find all shell scripts in build_files
total_modules=0
passed_modules=0
failed_modules=0
warning_modules=0

echo "Scanning for Build Modules in build_files/..."
echo

while IFS= read -r script; do
	total_modules=$((total_modules + 1))
	echo "Validating: $script"

	# Run validation checks
	exit_code=0
	validate_module_header "$script" || exit_code=$?

	if [[ -f "$script" ]] && [[ "$script" =~ build_files/(shared|desktop|developer|user-hooks)/ ]]; then
		validate_category_match "$script" || exit_code=$?
	fi

	case $exit_code in
	0)
		passed_modules=$((passed_modules + 1))
		echo "  ✓ Passed"
		;;
	1)
		failed_modules=$((failed_modules + 1))
		echo "  ✗ Failed with critical errors"
		;;
	2)
		warning_modules=$((warning_modules + 1))
		echo "  ⚠ Passed with warnings"
		;;
	esac
	echo
done < <(find build_files -type f -name "*.sh")

echo "=== Validation Summary ==="
echo "Total modules: $total_modules"
echo "Passed: $passed_modules"
echo "Warnings: $warning_modules"
echo "Failed: $failed_modules"
echo

if [[ $failed_modules -gt 0 ]]; then
	echo "✗ Module validation failed ($failed_modules modules with errors)"
	exit 1
elif [[ $warning_modules -gt 0 ]]; then
	echo "⚠ Module validation passed with warnings ($warning_modules modules)"
	exit 0
else
	echo "✓ All module validations passed!"
	exit 0
fi
