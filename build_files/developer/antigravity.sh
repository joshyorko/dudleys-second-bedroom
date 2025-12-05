#!/usr/bin/env bash
# Purpose: Install Antigravity product
# Category: developer
# Dependencies: none
# Parallel-Safe: no
# Cache-Friendly: yes
# Author: Build System
set -euo pipefail

# Module metadata
readonly MODULE_NAME="antigravity"
readonly CATEGORY="developer"

# Logging helper
log() {
	local level=$1
	shift
	echo "[MODULE:${CATEGORY}/${MODULE_NAME}] ${level}: $*"
}

log "INFO" "START - Installing Antigravity"

# 1. Add the repository
log "INFO" "Adding Antigravity RPM repository..."
cat <<EOF >/etc/yum.repos.d/antigravity.repo
[antigravity-rpm]
name=Antigravity RPM Repository
baseurl=https://us-central1-yum.pkg.dev/projects/antigravity-auto-updater-dev/antigravity-rpm
enabled=1
gpgcheck=0
EOF

# 2. Install the package
log "INFO" "Installing antigravity package..."
if command -v dnf5 &>/dev/null; then
	dnf5 install -y antigravity
else
	dnf install -y antigravity
fi

log "INFO" "DONE - Antigravity installed"
