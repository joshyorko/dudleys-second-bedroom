#!/usr/bin/bash
# Script: vscode-insiders.sh
# Purpose: Install Visual Studio Code Insiders via RPM
# Category: developer
# Dependencies: none
# Parallel-Safe: yes
# Usage: Called during build to install VS Code Insiders
# Author: Build System
# Last Updated: 2025-10-05

set -eoux pipefail

# Module metadata
readonly MODULE_NAME="vscode-insiders"
readonly CATEGORY="developer"
readonly FORCE_REFRESH="${VSCODE_FORCE_REFRESH:-0}"

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
	if [[ "$FORCE_REFRESH" != "1" ]] && rpm -q code-insiders &>/dev/null; then
		log "INFO" "VS Code Insiders already installed, skipping"
		exit 2
	fi

	local cdn_url="https://update.code.visualstudio.com/latest/linux-rpm-x64/insider"
	local rpm_path="/tmp/code-insiders-latest.rpm"

	log "INFO" "Downloading latest VS Code Insiders RPM from Microsoft CDN..."
	if ! curl -fsSL -o "$rpm_path" "$cdn_url"; then
		log "ERROR" "Failed to download VS Code Insiders RPM from CDN"
		exit 1
	fi

	local cdn_version
	cdn_version=$(rpm -qp --queryformat '%{VERSION}-%{RELEASE}' "$rpm_path" 2>/dev/null)
	log "INFO" "CDN RPM version: $cdn_version"

	if rpm -q code-insiders &>/dev/null; then
		local installed_version
		installed_version=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}' code-insiders)
		log "INFO" "Installed version: $installed_version"
	fi

	log "INFO" "Installing VS Code Insiders from CDN RPM..."
	if ! dnf5 install -y --allowerasing "$rpm_path" 2>/dev/null &&
		! dnf install -y --allowerasing "$rpm_path"; then
		log "ERROR" "Failed to install VS Code Insiders RPM"
		rm -f "$rpm_path"
		exit 1
	fi

	rm -f "$rpm_path"

	log "INFO" "VS Code Insiders installed successfully"

	local end_time duration
	end_time=$(date +%s)
	duration=$((end_time - start_time))

	log "INFO" "DONE (duration: ${duration}s)"
}

# Execute
main "$@"
