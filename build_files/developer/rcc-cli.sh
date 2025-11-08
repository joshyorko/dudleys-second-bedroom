#!/usr/bin/bash
# Script: rcc-cli.sh
# Purpose: Install Robocorp RCC CLI tool
# Category: developer
# Dependencies: shared/utils/github-release-install.sh
# Parallel-Safe: yes
# Usage: Called during build to install RCC CLI
# Author: Build System
# Last Updated: 2025-10-05

set -eoux pipefail

# Module metadata
readonly MODULE_NAME="rcc-cli"
readonly CATEGORY="developer"
readonly RCC_VERSION="${RCC_VERSION:-v18.8.0}"

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

	log "INFO" "START"

	# Check if already installed
	if command -v rcc &>/dev/null; then
		log "INFO" "RCC CLI already installed, skipping"
		exit 2
	fi

	log "INFO" "Installing RCC CLI version $RCC_VERSION..."
	local rcc_url="https://github.com/joshyorko/rcc/releases/download/${RCC_VERSION}/rcc-linux64"

	curl -fsSL "$rcc_url" -o /tmp/rcc || {
		log "ERROR" "Failed to download RCC"
		exit 1
	}

	install -m755 /tmp/rcc /usr/bin/rcc
	rm -f /tmp/rcc

	log "INFO" "Verifying RCC installation..."
	local robocorp_home="/tmp/robocorp"
	mkdir -p "$robocorp_home"
	ROBOCORP_HOME="$robocorp_home" rcc version || {
		log "ERROR" "RCC verification failed"
		exit 1
	}
	rm -rf "$robocorp_home"

	log "INFO" "RCC CLI installed successfully"

	local end_time duration
	end_time=$(date +%s)
	duration=$((end_time - start_time))

	log "INFO" "DONE (duration: ${duration}s)"
}

# Execute
main "$@"
