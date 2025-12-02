#!/usr/bin/env bash
# Purpose: Install DevPod CLI and Desktop App (AppImage)
# Category: developer
# Dependencies: none
# Parallel-Safe: yes
# Cache-Friendly: yes
# Author: Build System
set -euo pipefail

# Module metadata
readonly MODULE_NAME="devpod"
readonly CATEGORY="developer"
readonly DEVPOD_VERSION="${DEVPOD_VERSION:-v0.7.0-alpha.34}"

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

	log "INFO" "START - Installing DevPod ${DEVPOD_VERSION}"

	# Check if already installed
	if command -v devpod &>/dev/null; then
		log "INFO" "DevPod CLI already installed, skipping"
		exit 2
	fi

	# Create directories
	# Use /usr/share for AppImage (standard location, avoids /opt symlink issues on OSTree)
	mkdir -p /usr/share/devpod
	mkdir -p /usr/share/applications

	# URLs
	local base_url="https://github.com/loft-sh/devpod/releases/download/${DEVPOD_VERSION}"
	local cli_url="${base_url}/devpod-linux-amd64"
	local appimage_url="${base_url}/DevPod_linux_amd64.AppImage"
	local desktop_url="${base_url}/DevPod.desktop"

	# Install CLI to /usr/bin (same pattern as rcc-cli.sh)
	log "INFO" "Downloading DevPod CLI..."
	curl -fsSL "$cli_url" -o /tmp/devpod || {
		log "ERROR" "Failed to download DevPod CLI"
		exit 1
	}
	install -m755 /tmp/devpod /usr/bin/devpod
	rm -f /tmp/devpod

	# Install AppImage to /usr/share/devpod
	log "INFO" "Downloading DevPod AppImage..."
	curl -fsSL "$appimage_url" -o /usr/share/devpod/DevPod.AppImage || {
		log "ERROR" "Failed to download DevPod AppImage"
		exit 1
	}
	chmod +x /usr/share/devpod/DevPod.AppImage

	# Install Desktop File
	log "INFO" "Downloading DevPod .desktop file..."
	curl -fsSL "$desktop_url" -o /usr/share/applications/devpod.desktop || {
		log "ERROR" "Failed to download DevPod desktop file"
		exit 1
	}

	# Fix Desktop File Exec path to point to our AppImage location
	sed -i "s|Exec=.*|Exec=/usr/share/devpod/DevPod.AppImage %U|g" /usr/share/applications/devpod.desktop

	# Verify CLI installation
	log "INFO" "Verifying DevPod CLI installation..."
	devpod version || {
		log "ERROR" "DevPod CLI verification failed"
		exit 1
	}

	log "INFO" "DevPod installed successfully"

	local end_time duration
	end_time=$(date +%s)
	duration=$((end_time - start_time))

	log "INFO" "DONE (duration: ${duration}s)"
}

# Execute
main "$@"
