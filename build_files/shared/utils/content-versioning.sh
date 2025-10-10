#!/usr/bin/env bash

#
# Purpose: Content-based versioning utilities for user hooks
# Category: shared/utils
# Dependencies: bash 5.x, sha256sum, sed, sort
# Parallel-Safe: yes
# Usage: Source this file to use the functions: compute_content_hash, replace_version_placeholder, validate_hash_format
# Author: Dudley's Second Bedroom Project
# Date: 2025-10-10
#
# Provides functions for computing deterministic content hashes and managing
# version placeholders in hook scripts. Used during container build process.
#

set -euo pipefail

#
# compute_content_hash <file1> [file2] [file3] ...
#
# Computes an 8-character SHA256 hash from one or more files.
#
# Parameters:
#   file1, file2, ... - One or more file paths (relative or absolute)
#
# Returns:
#   Success (exit 0): Prints 8-character lowercase hex hash to stdout
#   Failure (exit 1): Prints error message to stderr
#
# Behavior:
#   - Validates all files exist
#   - Sorts file paths for determinism
#   - Concatenates and hashes content
#   - Truncates to 8 characters
#
compute_content_hash() {
    local files=("$@")
    
    # Check for arguments
    if [[ ${#files[@]} -eq 0 ]]; then
        echo "[dudley-versioning] ERROR: No files specified for hash computation" >&2
        echo "[dudley-versioning] Usage: compute_content_hash <file1> [file2] ..." >&2
        return 1
    fi
    
    # Validate all files exist
    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo "[dudley-versioning] ERROR: File not found: $file" >&2
            return 1
        fi
        if [[ ! -r "$file" ]]; then
            echo "[dudley-versioning] ERROR: File not readable: $file" >&2
            return 1
        fi
    done
    
    # Sort files for deterministic ordering
    local sorted_files=()
    mapfile -t sorted_files < <(printf '%s\n' "${files[@]}" | sort)
    
    # Compute hash (concatenate, hash, truncate to 8 chars)
    local hash
    hash=$(cat "${sorted_files[@]}" | sha256sum | cut -c1-8)
    
    echo "$hash"
}

#
# replace_version_placeholder <file> <hash>
#
# Replaces __CONTENT_VERSION__ placeholder in a file with computed hash.
#
# Parameters:
#   file - Path to file containing placeholder
#   hash - 8-character hash to inject
#
# Returns:
#   Success (exit 0): File modified in place
#   Failure (exit 1): Error message to stderr
#
# Behavior:
#   - Validates file exists and is writable
#   - Validates hash format (8 hex chars)
#   - Replaces all __CONTENT_VERSION__ occurrences
#   - Uses sed -i for in-place modification
#
replace_version_placeholder() {
    local file="$1"
    local hash="$2"
    
    # Validate arguments
    if [[ -z "$file" ]] || [[ -z "$hash" ]]; then
        echo "[dudley-versioning] ERROR: Missing required arguments" >&2
        echo "[dudley-versioning] Usage: replace_version_placeholder <file> <hash>" >&2
        return 1
    fi
    
    # Validate file exists
    if [[ ! -f "$file" ]]; then
        echo "[dudley-versioning] ERROR: File not found: $file" >&2
        return 1
    fi
    
    # Validate file is writable
    if [[ ! -w "$file" ]]; then
        echo "[dudley-versioning] ERROR: File not writable: $file" >&2
        return 1
    fi
    
    # Validate hash format
    if ! validate_hash_format "$hash"; then
        echo "[dudley-versioning] ERROR: Invalid hash format: $hash (expected 8 hex chars)" >&2
        return 1
    fi
    
    # Check if placeholder exists
    if ! grep -q "__CONTENT_VERSION__" "$file"; then
        echo "[dudley-versioning] WARNING: No __CONTENT_VERSION__ placeholder found in $file" >&2
        return 0  # Non-fatal warning
    fi
    
    # Replace placeholder
    sed -i "s/__CONTENT_VERSION__/$hash/g" "$file"
    
    echo "[dudley-versioning] Replaced version placeholder in $file with $hash" >&2
}

#
# validate_hash_format <hash>
#
# Validates a string matches the expected 8-character hex hash format.
#
# Parameters:
#   hash - String to validate
#
# Returns:
#   Success (exit 0): Hash is valid
#   Failure (exit 1): Hash is invalid (silent)
#
# Behavior:
#   - Checks length is exactly 8 characters
#   - Checks all characters are lowercase hex [a-f0-9]
#
validate_hash_format() {
    local hash="$1"
    
    # Check if provided
    if [[ -z "$hash" ]]; then
        return 1
    fi
    
    # Check format: exactly 8 lowercase hex characters
    if [[ "$hash" =~ ^[a-f0-9]{8}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Export functions for use by other scripts
export -f compute_content_hash
export -f replace_version_placeholder
export -f validate_hash_format
