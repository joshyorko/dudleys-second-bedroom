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
readonly DEVPOD_VERSION="${DEVPOD_VERSION:-v0.6.15}"

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
	mkdir -p /opt/devpod
	mkdir -p /usr/share/applications

	# URLs
	local base_url="https://github.com/loft-sh/devpod/releases/download/${DEVPOD_VERSION}"
	local cli_url="${base_url}/devpod-linux-amd64"
	local appimage_url="${base_url}/DevPod_linux_amd64.AppImage"
	local desktop_url="${base_url}/DevPod.desktop"

	# Install CLI
	log "INFO" "Downloading DevPod CLI..."
	curl -fsSL "$cli_url" -o /usr/bin/devpod
	chmod +x /usr/bin/devpod

	# Install AppImage
	log "INFO" "Downloading DevPod AppImage..."
	curl -fsSL "$appimage_url" -o /opt/devpod/DevPod.AppImage
	chmod +x /opt/devpod/DevPod.AppImage

	# Install Desktop File
	log "INFO" "Downloading DevPod .desktop file..."
	curl -fsSL "$desktop_url" -o /usr/share/applications/devpod.desktop

	# Fix Desktop File Exec path
	# Ensure it points to the AppImage
	sed -i "s|Exec=.*|Exec=/opt/devpod/DevPod.AppImage --no-sandbox %U|g" /usr/share/applications/devpod.desktop
    # Note: --no-sandbox might be needed for some electron apps in containers, but usually not on host. 
    # However, AppImages sometimes need FUSE. Bluefin has FUSE.
    # I'll remove --no-sandbox to be safe, or keep it if I suspect issues. 
    # Better to just point to the AppImage.
    sed -i "s|Exec=.*|Exec=/opt/devpod/DevPod.AppImage %U|g" /usr/share/applications/devpod.desktop

    # Fix Icon path if needed (assuming the desktop file expects 'devpod' icon which might not exist)
    # We don't have the icon easily. 
    # I'll leave the Icon= line as is, it might pick up a generic one or fail gracefully.

	log "INFO" "DevPod installed successfully"

	local end_time duration
	end_time=$(date +%s)
	duration=$((end_time - start_time))

	log "INFO" "DONE (duration: ${duration}s)"
}

# Execute
main "$@"
