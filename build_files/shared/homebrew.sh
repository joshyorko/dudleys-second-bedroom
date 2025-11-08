#!/usr/bin/bash
# Script: homebrew.sh
# Purpose: Install Homebrew Brewfile configurations
# Category: shared
# Dependencies: none
# Parallel-Safe: yes
# Usage: Copies Brewfile configurations to the system for user installation
# Author: Build System
# Last Updated: 2025-11-07

set -eoux pipefail

# Module metadata
readonly MODULE_NAME="homebrew"
readonly CATEGORY="shared"

# Logging helper
log() {
	local level=$1
	shift
	echo "[MODULE:${CATEGORY}/${MODULE_NAME}] ${level}: $*"
}

# Main function
main() {
	local start_time
	start_time=$(date +%s)

	log "INFO" "START - Installing Homebrew Brewfile configurations"

	# Get build context path
	local build_context="${BUILD_CONTEXT:-/ctx}"

	# Create homebrew config directory (following Universal Blue pattern)
	local homebrew_dir="/usr/share/ublue-os/homebrew"
	install -d "$homebrew_dir"

	# Copy Brewfile configurations if they exist
	if [[ -d "$build_context/brew" ]]; then
		local brewfile_count=0

		# Copy all Brewfiles
		for brewfile in "$build_context/brew"/*.Brewfile; do
			if [[ -f "$brewfile" ]]; then
				log "INFO" "Installing Brewfile: $(basename "$brewfile")"
				cp "$brewfile" "$homebrew_dir/"
				chmod 0644 "$homebrew_dir/$(basename "$brewfile")"
				brewfile_count=$((brewfile_count + 1))
			fi
		done

		if [[ $brewfile_count -gt 0 ]]; then
			log "INFO" "Installed $brewfile_count Brewfile(s) to $homebrew_dir"
		else
			log "WARNING" "No Brewfiles found in $build_context/brew"
		fi
	else
		log "WARNING" "Brew directory not found at $build_context/brew, skipping"
	fi

	log "INFO" "Brewfiles will be available for user installation via ujust commands"

	local end_time duration
	end_time=$(date +%s)
	duration=$((end_time - start_time))

	log "INFO" "DONE (duration: ${duration}s)"
}

# Execute
main "$@"
