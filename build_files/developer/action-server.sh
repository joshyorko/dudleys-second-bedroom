#!/usr/bin/bash
# Script: action-server.sh
# Purpose: Install Sema4.ai Action Server
# Category: developer
# Dependencies: none
# Parallel-Safe: yes
# Usage: Called during build to install Action Server
# Author: Build System
# Last Updated: 2025-10-05

set -eoux pipefail

# Module metadata
readonly MODULE_NAME="action-server"
readonly CATEGORY="developer"
# Determine Action Server version: use env var if set, else read from config file, else fallback to default
if [[ -z "${ACTION_SERVER_VERSION:-}" ]]; then
	if [[ -f "./action-server-version.txt" ]]; then
		ACTION_SERVER_VERSION="$(cat ./action-server-version.txt)"
		readonly ACTION_SERVER_VERSION
	else
		readonly ACTION_SERVER_VERSION="latest"
	fi
else
	readonly ACTION_SERVER_VERSION="$ACTION_SERVER_VERSION"
fi

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
	if command -v action-server &>/dev/null; then
		log "INFO" "Action Server already installed, skipping"
		exit 2
	fi

	log "INFO" "Downloading Action Server version $ACTION_SERVER_VERSION..."
	local download_url="https://cdn.sema4.ai/action-server/releases/${ACTION_SERVER_VERSION}/linux64/action-server"

	curl -fsSL "$download_url" -o /tmp/action-server || {
		log "ERROR" "Failed to download Action Server"
		exit 1
	}

	log "INFO" "Installing Action Server to /usr/bin..."
	chmod +x /tmp/action-server
	install -m755 /tmp/action-server /usr/bin/action-server
	rm -f /tmp/action-server

	# Initialize action-server
	log "INFO" "Initializing Action Server..."
	local temp_home
	temp_home=$(mktemp -d)
	export HOME="$temp_home"
	export ROBOCORP_HOME="$temp_home/.robocorp"
	mkdir -p "$ROBOCORP_HOME"

	if /usr/bin/action-server version 2>&1 | grep -q '[0-9]'; then
		log "INFO" "Action Server initialized successfully"
	else
		log "WARNING" "Action Server version check produced unexpected output"
	fi

	# Clean up
	rm -rf "$temp_home"

	local end_time duration
	end_time=$(date +%s)
	duration=$((end_time - start_time))

	log "INFO" "DONE (duration: ${duration}s)"
}

# Execute
main "$@"
