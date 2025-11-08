#!/usr/bin/env bash
set -euo pipefail

#
# Purpose: Build manifest generation utilities for content-based versioning
# Category: shared/utils
# Dependencies: bash 5.x, jq, date
# Parallel-Safe: yes
# Usage: Source this file to use the functions: init_manifest, add_hook_to_manifest, write_manifest, validate_manifest_schema
# Author: Dudley's Second Bedroom Project
# Date: 2025-10-10
#
# Provides functions for constructing and writing build manifest JSON files.
# Used during container build process after content hashes are computed.
#

#
# init_manifest <image_name> <base_image> <commit_sha>
#
# Initializes a new manifest structure with build metadata.
#
# Parameters:
#   image_name - Full OCI image reference with tag
#   base_image - Base image reference
#   commit_sha - Git commit SHA (7 or 40 characters)
#
# Returns:
#   Success (exit 0): Prints initial manifest JSON to stdout
#   Failure (exit 1): Error message to stderr
#
init_manifest() {
	local image_name="$1"
	local base_image="$2"
	local commit_sha="$3"

	# Validate arguments
	if [[ -z "$image_name" ]] || [[ -z "$base_image" ]] || [[ -z "$commit_sha" ]]; then
		echo "[dudley-versioning] ERROR: Missing required arguments" >&2
		echo "[dudley-versioning] Usage: init_manifest <image_name> <base_image> <commit_sha>" >&2
		return 1
	fi

	# Get current timestamp in ISO 8601 format (UTC)
	local build_date
	build_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

	# Construct manifest JSON
	jq -n \
		--arg version "1.0.0" \
		--arg date "$build_date" \
		--arg image "$image_name" \
		--arg base "$base_image" \
		--arg commit "$commit_sha" \
		'{
            version: $version,
            build: {
                date: $date,
                image: $image,
                base: $base,
                commit: $commit
            },
            hooks: {}
        }'
}

#
# add_hook_to_manifest <manifest_json> <hook_name> <version_hash> <dependencies_json> [metadata_json]
#
# Adds a hook version entry to an existing manifest JSON.
#
# Parameters:
#   manifest_json - Existing manifest JSON string
#   hook_name - Hook identifier (alphanumeric, dashes, underscores)
#   version_hash - 8-character content hash
#   dependencies_json - JSON array of dependency file paths
#   metadata_json - (optional) JSON object with hook-specific metadata
#
# Returns:
#   Success (exit 0): Prints updated manifest JSON to stdout
#   Failure (exit 1): Error message to stderr
#
add_hook_to_manifest() {
	local manifest_json="$1"
	local hook_name="$2"
	local version_hash="$3"
	local dependencies_json="$4"
	local metadata_json="${5:-}"

	# Set default if empty or unset
	if [[ -z "$metadata_json" ]]; then
		metadata_json="{}"
	fi

	# Validate arguments
	if [[ -z "$manifest_json" ]] || [[ -z "$hook_name" ]] || [[ -z "$version_hash" ]] || [[ -z "$dependencies_json" ]]; then
		echo "[dudley-versioning] ERROR: Missing required arguments" >&2
		echo "[dudley-versioning] Usage: add_hook_to_manifest <manifest_json> <hook_name> <version_hash> <dependencies_json> [metadata_json]" >&2
		return 1
	fi

	# Validate manifest is valid JSON
	if ! echo "$manifest_json" | jq -e . >/dev/null 2>&1; then
		echo "[dudley-versioning] ERROR: Invalid manifest JSON" >&2
		return 1
	fi

	# Validate hook name format (alphanumeric, dashes, underscores)
	if ! [[ "$hook_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
		echo "[dudley-versioning] ERROR: Invalid hook name format: $hook_name" >&2
		return 1
	fi

	# Validate version hash format (8 hex chars)
	if ! [[ "$version_hash" =~ ^[a-f0-9]{8}$ ]]; then
		echo "[dudley-versioning] ERROR: Invalid hash format: $version_hash (expected 8 hex chars)" >&2
		return 1
	fi

	# Validate dependencies is valid JSON array
	if ! echo "$dependencies_json" | jq -e 'if type == "array" then true else false end' >/dev/null 2>&1; then
		echo "[dudley-versioning] ERROR: Invalid dependencies JSON (must be array)" >&2
		return 1
	fi

	# Validate metadata is valid JSON object (if provided and not empty)
	if [[ -n "$metadata_json" ]] && [[ "$metadata_json" != "{}" ]]; then
		if ! echo "$metadata_json" | jq -e 'type == "object"' >/dev/null 2>&1; then
			echo "[dudley-versioning] ERROR: Invalid metadata JSON (must be object)" >&2
			return 1
		fi
	fi

	# Add hook to manifest using jq
	echo "$manifest_json" | jq \
		--arg hook "$hook_name" \
		--arg ver "$version_hash" \
		--argjson deps "$dependencies_json" \
		--argjson meta "$metadata_json" \
		'.hooks[$hook] = {
            version: $ver,
            dependencies: $deps,
            metadata: $meta
        }'
}

#
# write_manifest <manifest_json> <output_path>
#
# Writes manifest JSON to file with validation and proper permissions.
#
# Parameters:
#   manifest_json - Complete manifest JSON string
#   output_path - File path for manifest
#
# Returns:
#   Success (exit 0): File written, prints success message
#   Failure (exit 1): Error message to stderr
#
write_manifest() {
	local manifest_json="$1"
	local output_path="$2"

	# Validate arguments
	if [[ -z "$manifest_json" ]] || [[ -z "$output_path" ]]; then
		echo "[dudley-versioning] ERROR: Missing required arguments" >&2
		echo "[dudley-versioning] Usage: write_manifest <manifest_json> <output_path>" >&2
		return 1
	fi

	# Validate manifest is valid JSON
	if ! echo "$manifest_json" | jq -e . >/dev/null 2>&1; then
		echo "[dudley-versioning] ERROR: Invalid manifest JSON" >&2
		return 1
	fi

	# Validate schema
	if ! validate_manifest_schema "$manifest_json"; then
		echo "[dudley-versioning] ERROR: Manifest failed schema validation" >&2
		return 1
	fi

	# Create parent directory if needed
	local output_dir
	output_dir=$(dirname "$output_path")
	if [[ ! -d "$output_dir" ]]; then
		mkdir -p "$output_dir" || {
			echo "[dudley-versioning] ERROR: Failed to create directory: $output_dir" >&2
			return 1
		}
	fi

	# Write to temporary file first (atomic operation)
	local temp_file="${output_path}.tmp"
	echo "$manifest_json" | jq . >"$temp_file" || {
		echo "[dudley-versioning] ERROR: Failed to write temporary manifest file" >&2
		return 1
	}

	# Check file size (warn if > 50KB)
	local file_size
	file_size=$(stat -f%z "$temp_file" 2>/dev/null || stat -c%s "$temp_file" 2>/dev/null)
	if [[ $file_size -gt 51200 ]]; then
		echo "[dudley-versioning] WARNING: Manifest size exceeds 50KB ($((file_size / 1024)) KB)" >&2
	fi

	# Move temp file to final location (atomic)
	if ! mv "$temp_file" "$output_path"; then
		echo "[dudley-versioning] ERROR: Failed to move manifest to $output_path" >&2
		rm -f "$temp_file"
		return 1
	fi

	# Set permissions to 644 (world-readable)
	chmod 644 "$output_path" || {
		echo "[dudley-versioning] WARNING: Failed to set permissions on $output_path" >&2
	}

	echo "[dudley-versioning] Manifest written to $output_path ($((file_size / 1024)).${file_size: -3} KB)" >&2
}

#
# validate_manifest_schema <manifest_json>
#
# Validates a manifest JSON against the required schema.
#
# Parameters:
#   manifest_json - Manifest JSON string to validate
#
# Returns:
#   Success (exit 0): Manifest is valid
#   Failure (exit 1): Prints validation errors to stderr
#
validate_manifest_schema() {
	local manifest_json="$1"

	# Validate is valid JSON first
	if ! echo "$manifest_json" | jq -e . >/dev/null 2>&1; then
		echo "[dudley-versioning] ERROR: Not valid JSON" >&2
		return 1
	fi

	local errors=0

	# Check version field (required, semver pattern)
	if ! echo "$manifest_json" | jq -e '.version' >/dev/null 2>&1; then
		echo "[dudley-versioning] ERROR: Missing required field: version" >&2
		((errors++))
	elif ! echo "$manifest_json" | jq -e '.version | test("^\\d+\\.\\d+\\.\\d+$")' >/dev/null 2>&1; then
		echo "[dudley-versioning] ERROR: Invalid version format (expected semver)" >&2
		((errors++))
	fi

	# Check build object (required)
	if ! echo "$manifest_json" | jq -e '.build' >/dev/null 2>&1; then
		echo "[dudley-versioning] ERROR: Missing required field: build" >&2
		((errors++))
	else
		# Check build.date
		if ! echo "$manifest_json" | jq -e '.build.date' >/dev/null 2>&1; then
			echo "[dudley-versioning] ERROR: Missing required field: build.date" >&2
			((errors++))
		fi

		# Check build.image
		if ! echo "$manifest_json" | jq -e '.build.image' >/dev/null 2>&1; then
			echo "[dudley-versioning] ERROR: Missing required field: build.image" >&2
			((errors++))
		fi

		# Check build.base
		if ! echo "$manifest_json" | jq -e '.build.base' >/dev/null 2>&1; then
			echo "[dudley-versioning] ERROR: Missing required field: build.base" >&2
			((errors++))
		fi

		# Check build.commit
		if ! echo "$manifest_json" | jq -e '.build.commit' >/dev/null 2>&1; then
			echo "[dudley-versioning] ERROR: Missing required field: build.commit" >&2
			((errors++))
		fi
	fi

	# Check hooks object (required, non-empty)
	if ! echo "$manifest_json" | jq -e '.hooks' >/dev/null 2>&1; then
		echo "[dudley-versioning] ERROR: Missing required field: hooks" >&2
		((errors++))
	elif [[ $(echo "$manifest_json" | jq '.hooks | length') -eq 0 ]]; then
		echo "[dudley-versioning] ERROR: hooks object cannot be empty" >&2
		((errors++))
	else
		# Validate each hook
		local hook_names
		mapfile -t hook_names < <(echo "$manifest_json" | jq -r '.hooks | keys[]')

		for hook in "${hook_names[@]}"; do
			# Check version format
			local version
			version=$(echo "$manifest_json" | jq -r ".hooks[\"$hook\"].version")
			if ! [[ "$version" =~ ^[a-f0-9]{8}$ ]]; then
				echo "[dudley-versioning] ERROR: Hook '$hook' has invalid version format: '$version'" >&2
				((errors++))
			fi

			# Check dependencies array exists and non-empty
			if ! echo "$manifest_json" | jq -e ".hooks[\"$hook\"].dependencies" >/dev/null 2>&1; then
				echo "[dudley-versioning] ERROR: Hook '$hook' missing dependencies array" >&2
				((errors++))
			elif [[ $(echo "$manifest_json" | jq ".hooks[\"$hook\"].dependencies | length") -eq 0 ]]; then
				echo "[dudley-versioning] ERROR: Hook '$hook' has empty dependencies array" >&2
				((errors++))
			fi
		done
	fi

	# Return based on errors
	if [[ $errors -gt 0 ]]; then
		return 1
	fi

	return 0
}

# Export functions for use by other scripts
export -f init_manifest
export -f add_hook_to_manifest
export -f write_manifest
export -f validate_manifest_schema
