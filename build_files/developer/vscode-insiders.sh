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
	if rpm -q code-insiders &>/dev/null; then
		log "INFO" "VS Code Insiders already installed, skipping"
		exit 2
	fi

	log "INFO" "Adding Microsoft VS Code repository..."
	cat >/etc/yum.repos.d/vscode-insiders.repo <<'EOF'
[code-insiders]
name=Visual Studio Code Insiders Repository
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

	log "INFO" "Installing code-insiders RPM..."
	if ! dnf5 install -y code-insiders 2>/dev/null && ! dnf install -y code-insiders; then
		log "ERROR" "Failed to install code-insiders RPM"
		exit 1
	fi

	log "INFO" "VS Code Insiders installed successfully"

	local end_time duration
	end_time=$(date +%s)
	duration=$((end_time - start_time))

	log "INFO" "DONE (duration: ${duration}s)"
}

# Execute
main "$@"
