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
	curl -fsSL --retry 3 --retry-delay 5 "$cli_url" -o /tmp/devpod || {
		log "ERROR" "Failed to download DevPod CLI"
		exit 1
	}
	install -m755 /tmp/devpod /usr/bin/devpod
	rm -f /tmp/devpod

	# Install AppImage to /usr/share/devpod
	log "INFO" "Downloading DevPod AppImage..."
	curl -fsSL --retry 3 --retry-delay 5 "$appimage_url" -o /usr/share/devpod/DevPod.AppImage || {
		log "ERROR" "Failed to download DevPod AppImage"
		exit 1
	}
	chmod +x /usr/share/devpod/DevPod.AppImage

	# Install Icon
	log "INFO" "Downloading DevPod icon..."
	mkdir -p /usr/share/icons/hicolor/512x512/apps
	curl -fsSL --retry 3 --retry-delay 5 "https://raw.githubusercontent.com/loft-sh/devpod/main/desktop/devpod.png" -o /usr/share/icons/hicolor/512x512/apps/devpod.png || {
		log "WARN" "Failed to download DevPod icon, continuing..."
	}

	# Install Desktop File
	log "INFO" "Downloading DevPod .desktop file..."
	curl -fsSL --retry 3 --retry-delay 5 "$desktop_url" -o /usr/share/applications/devpod.desktop || {
		log "ERROR" "Failed to download DevPod desktop file"
		exit 1
	}

	# Fix Desktop File
	# 1. Point Exec to AppImage with --no-sandbox (fixes blank window in some envs)
	# 2. Set Icon to 'devpod' to match the installed icon file
	sed -i "s|Exec=.*|Exec=/usr/share/devpod/DevPod.AppImage --no-sandbox %U|g" /usr/share/applications/devpod.desktop
	sed -i "s|Icon=.*|Icon=devpod|g" /usr/share/applications/devpod.desktop

	# Verify CLI installation
	log "INFO" "Verifying DevPod CLI installation..."
	if [[ -x /usr/bin/devpod ]]; then
		log "INFO" "DevPod CLI installed at /usr/bin/devpod"
	else
		log "ERROR" "DevPod CLI not found or not executable"
		exit 1
	fi

	log "INFO" "DevPod installed successfully"

	local end_time duration
	end_time=$(date +%s)
	duration=$((end_time - start_time))

	log "INFO" "DONE (duration: ${duration}s)"
}

# Execute
main "$@"
