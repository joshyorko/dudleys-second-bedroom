#!/usr/bin/env bash
set -euo pipefail

#
# Purpose: Display build manifest information on demand
# Category: shared/utils
# Dependencies: bash 5.x, jq
# Parallel-Safe: yes
# Usage: Installed as /usr/local/bin/dudley-build-info, run by end users
# Author: Dudley's Second Bedroom Project
# Date: 2025-10-10
#
# Command-line tool to view build information from the manifest.
# Installed as: /usr/local/bin/dudley-build-info
#

# Configuration
MANIFEST_PATH="/etc/dudley/build-manifest.json"

# Usage message
usage() {
	cat <<'USAGE'
Usage: dudley-build-info [OPTIONS]

Display build information for this Dudley's Second Bedroom image.

OPTIONS:
    --json, -j      Output raw JSON manifest
    --help, -h      Show this help message

EXAMPLES:
    dudley-build-info           # Display formatted build information
    dudley-build-info --json    # Output raw JSON for scripting

MANIFEST LOCATION:
    /etc/dudley/build-manifest.json
USAGE
}

# Display formatted output
display_formatted() {
	local manifest_path="$1"

	if [[ ! -f "$manifest_path" ]]; then
		echo "Error: Build manifest not found at $manifest_path" >&2
		echo "This may indicate a build issue or development environment." >&2
		exit 1
	fi

	if ! command -v jq &>/dev/null; then
		echo "Error: jq is required but not found" >&2
		exit 1
	fi

	# Extract build information
	local build_date build_image base_image git_commit
	build_date=$(jq -r '.build.date // "unknown"' "$manifest_path")
	build_image=$(jq -r '.build.image // "unknown"' "$manifest_path")
	base_image=$(jq -r '.build.base // "unknown"' "$manifest_path")
	git_commit=$(jq -r '.build.commit // "unknown"' "$manifest_path")

	# Display build info
	cat <<EOF
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║           Dudley's Second Bedroom - Build Info             ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝

Build Information:
  Date:   $build_date
  Image:  $build_image
  Base:   $base_image
  Commit: $git_commit

Homebrew Packages:
  Install dev tools:  ujust dudley-brews-dev
  Install all brews:  ujust dudley-brews-all

Content Versions:
EOF

	# Extract and display hook versions
	local hook_names
	mapfile -t hook_names < <(jq -r '.hooks | keys[]' "$manifest_path" 2>/dev/null | sort)

	for hook in "${hook_names[@]}"; do
		local version deps_count changed
		version=$(jq -r ".hooks[\"$hook\"].version" "$manifest_path")
		deps_count=$(jq -r ".hooks[\"$hook\"].dependencies | length" "$manifest_path")
		changed=$(jq -r ".hooks[\"$hook\"].metadata.changed // false" "$manifest_path")

		# Get hook-specific metadata
		local extra_info=""
		case "$hook" in
			"wallpaper")
				local wp_count
				wp_count=$(jq -r ".hooks[\"$hook\"].metadata.wallpaper_count // 0" "$manifest_path")
				extra_info=" ($wp_count wallpapers)"
				;;
		esac

		# Format changed indicator
		local changed_indicator=""
		if [[ "$changed" == "true" ]]; then
			changed_indicator=" [changed]"
		fi

		printf "  %-20s %s (%d dependencies)%s%s\n" \
			"$hook:" "$version" "$deps_count" "$extra_info" "$changed_indicator"
	done

	echo ""
	echo "For raw JSON output, use: dudley-build-info --json"
}

# Display raw JSON
display_json() {
	local manifest_path="$1"

	if [[ ! -f "$manifest_path" ]]; then
		echo '{"error": "Manifest not found", "path": "'"$manifest_path"'"}' >&2
		exit 1
	fi

	if ! command -v jq &>/dev/null; then
		# Fallback: cat the file
		cat "$manifest_path"
	else
		# Pretty-print with jq
		jq . "$manifest_path"
	fi
}

# Main
main() {
	local output_mode="formatted"

	# Parse arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--json | -j)
				output_mode="json"
				shift
				;;
			--help | -h)
				usage
				exit 0
				;;
			*)
				echo "Error: Unknown option: $1" >&2
				echo "Use --help for usage information" >&2
				exit 1
				;;
		esac
	done

	# Display based on mode
	case "$output_mode" in
		json)
			display_json "$MANIFEST_PATH"
			;;
		formatted)
			display_formatted "$MANIFEST_PATH"
			;;
	esac
}

# Execute
main "$@"
