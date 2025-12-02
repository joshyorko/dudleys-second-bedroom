#!/usr/bin/env bash
# Purpose: Validate all repositories are disabled before committing image
# Category: shared
# Dependencies: none
# Parallel-Safe: yes
# Cache-Friendly: yes
# Author: Build System
set -euo pipefail

echo "::group:: ===$(basename "$0")==="

# Module metadata
readonly MODULE_NAME="validate-repos"
readonly CATEGORY="shared"

# Logging helper
log() {
	local level=$1
	shift
	echo "[MODULE:${CATEGORY}/${MODULE_NAME}] ${level}: $*"
}

REPOS_DIR="/etc/yum.repos.d"
VALIDATION_FAILED=0
ENABLED_REPOS=()

log "INFO" "Validating all repository files are disabled..."

# Check if repos directory exists
if [[ ! -d "$REPOS_DIR" ]]; then
	log "WARNING" "$REPOS_DIR does not exist"
	echo "::endgroup::"
	exit 0
fi

# Function to check if a repo file has any enabled repos
check_repo_file() {
	local repo_file="$1"
	local basename_file
	basename_file=$(basename "$repo_file")

	# Skip if file doesn't exist or isn't readable
	[[ ! -f "$repo_file" ]] && return 0
	[[ ! -r "$repo_file" ]] && return 0

	# Check for enabled=1 in the file
	if grep -q "^enabled=1" "$repo_file" 2>/dev/null; then
		log "WARNING" "ENABLED: $basename_file"
		ENABLED_REPOS+=("$basename_file")
		VALIDATION_FAILED=1
	fi
}

# Check all repo files
log "INFO" "Checking COPR repositories..."
for repo in "$REPOS_DIR"/_copr_*.repo; do
	[[ -f "$repo" ]] && check_repo_file "$repo"
done

log "INFO" "Checking other third-party repositories..."
for repo in "$REPOS_DIR"/*.repo; do
	[[ -f "$repo" ]] && check_repo_file "$repo"
done

if [[ $VALIDATION_FAILED -eq 1 ]]; then
	log "ERROR" "The following repositories are still enabled:"
	for repo in "${ENABLED_REPOS[@]}"; do
		echo "  • $repo"
	done
	log "ERROR" "All repositories must be disabled before image commit"
	echo "::endgroup::"
	exit 1
fi

log "INFO" "✓ All repositories are properly disabled"
echo "::endgroup::"
