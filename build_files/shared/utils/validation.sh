#!/usr/bin/bash
# Script: validation.sh
# Purpose: Validation utilities for build system
# Category: shared
# Dependencies: none
# Parallel-Safe: yes
# Usage: Source this file to use validation functions
# Author: Build System
# Last Updated: 2025-10-05

set -euo pipefail

# Module metadata
readonly MODULE_NAME="validation"
readonly CATEGORY="shared/utils"

# Logging helper
log() {
    local level=$1
    shift
    echo "[MODULE:${CATEGORY}/${MODULE_NAME}] ${level}: $*"
}

# Validate shell script with shellcheck
# Args: $1 - path to shell script
# Returns: 0 if valid, 1 if critical error, 2 if warnings only
validate_shellcheck() {
    local script=$1
    
    if ! command -v shellcheck &>/dev/null; then
        log "WARNING" "shellcheck not found, skipping validation for $script"
        return 2
    fi
    
    if ! shellcheck -e SC2086 "$script" 2>/dev/null; then
        log "ERROR" "shellcheck failed for $script"
        return 1
    fi
    
    log "INFO" "shellcheck passed for $script"
    return 0
}

# Validate JSON file syntax
# Args: $1 - path to JSON file
# Returns: 0 if valid, 1 if invalid
validate_json() {
    local json_file=$1
    
    if ! command -v jq &>/dev/null; then
        log "ERROR" "jq not found, cannot validate JSON"
        return 1
    fi
    
    if ! jq empty "$json_file" 2>/dev/null; then
        log "ERROR" "Invalid JSON syntax in $json_file"
        return 1
    fi
    
    log "INFO" "JSON validation passed for $json_file"
    return 0
}

# Validate Build Module header
# Args: $1 - path to module script
# Returns: 0 if valid, 1 if critical error, 2 if warnings
validate_module_header() {
    local script=$1
    local errors=0
    local warnings=0
    
    # Extract header (first 20 lines or until first blank line after header)
    local header
    header=$(head -n 20 "$script")
    
    # Check required fields
    if ! echo "$header" | grep -q "^# Purpose:"; then
        log "ERROR" "Missing Purpose field in $script"
        errors=$((errors + 1))
    fi
    
    if ! echo "$header" | grep -q "^# Category:"; then
        log "ERROR" "Missing Category field in $script"
        errors=$((errors + 1))
    fi
    
    if ! echo "$header" | grep -q "^# Dependencies:"; then
        log "ERROR" "Missing Dependencies field in $script"
        errors=$((errors + 1))
    fi
    
    if ! echo "$header" | grep -q "^# Parallel-Safe:"; then
        log "ERROR" "Missing Parallel-Safe field in $script"
        errors=$((errors + 1))
    fi
    
    # Check Parallel-Safe value
    if echo "$header" | grep -q "^# Parallel-Safe:"; then
        parallel_safe=$(echo "$header" | grep "^# Parallel-Safe:" | cut -d: -f2 | xargs)
        if [[ "$parallel_safe" != "yes" ]] && [[ "$parallel_safe" != "no" ]]; then
            log "ERROR" "Parallel-Safe must be 'yes' or 'no' in $script (found: $parallel_safe)"
            errors=$((errors + 1))
        fi
    fi
    
    # Check for shebang
    if ! head -n 1 "$script" | grep -q "^#!/"; then
        log "ERROR" "Missing shebang in $script"
        errors=$((errors + 1))
    fi
    
    # Check for set -eoux pipefail or set -euo pipefail
    if ! head -n 15 "$script" | grep -q "set -e.*o.*pipefail"; then
        log "WARNING" "Missing 'set -eoux pipefail' or 'set -euo pipefail' in $script"
        warnings=$((warnings + 1))
    fi
    
    # Check Author field (warning only)
    if ! echo "$header" | grep -q "^# Author:"; then
        log "WARNING" "Missing Author field in $script"
        warnings=$((warnings + 1))
    fi
    
    if [[ $errors -gt 0 ]]; then
        log "ERROR" "$script has $errors critical errors"
        return 1
    elif [[ $warnings -gt 0 ]]; then
        log "WARNING" "$script has $warnings warnings"
        return 2
    else
        log "INFO" "Module header validation passed for $script"
        return 0
    fi
}

# Validate category matches directory
# Args: $1 - path to module script
# Returns: 0 if matches, 1 if mismatch
validate_category_match() {
    local script=$1
    
    # Extract declared category from header
    local declared_category
    declared_category=$(grep "^# Category:" "$script" | cut -d: -f2 | xargs)
    
    # Extract actual category from path
    local actual_category
    actual_category=$(dirname "$script" | sed 's|.*/build_files/||')
    
    if [[ "$declared_category" != "$actual_category" ]]; then
        log "ERROR" "Category mismatch in $script: declared '$declared_category' but in directory '$actual_category'"
        return 1
    fi
    
    log "INFO" "Category matches directory for $script"
    return 0
}

# Main validation orchestrator
# Args: $@ - list of files/patterns to validate
validate_all() {
    local exit_code=0
    
    log "INFO" "Starting comprehensive validation"
    
    # If no arguments, validate everything
    if [[ $# -eq 0 ]]; then
        # Validate all shell scripts in build_files
        while IFS= read -r script; do
            validate_shellcheck "$script" || exit_code=1
            validate_module_header "$script" || exit_code=1
            validate_category_match "$script" || exit_code=1
        done < <(find build_files -type f -name "*.sh")
        
        # Validate JSON files
        if [[ -f "packages.json" ]]; then
            validate_json "packages.json" || exit_code=1
        fi
    else
        # Validate specific files
        for file in "$@"; do
            if [[ "$file" == *.sh ]]; then
                validate_shellcheck "$file" || exit_code=1
                validate_module_header "$file" || exit_code=1
                validate_category_match "$file" || exit_code=1
            elif [[ "$file" == *.json ]]; then
                validate_json "$file" || exit_code=1
            fi
        done
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        log "INFO" "All validations passed"
    else
        log "ERROR" "Some validations failed"
    fi
    
    return $exit_code
}

# If script is executed (not sourced), run validation
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    validate_all "$@"
fi
