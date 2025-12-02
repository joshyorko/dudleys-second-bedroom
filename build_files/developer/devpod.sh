#!/usr/bin/env bash
# Purpose: Install latest DevPod from tar.gz
# Category: developer
# Dependencies: none
# Parallel-Safe: yes
# Cache-Friendly: yes
# Author: Build System
set -euo pipefail

# Module metadata
readonly MODULE_NAME="devpod"
readonly CATEGORY="developer"
readonly DEVPOD_VERSION="${DEVPOD_VERSION:-0.6.15}"

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
	if command -v devpod &>/dev/null && [[ -f "/usr/bin/dev-pod-desktop" ]]; then
		log "INFO" "DevPod already installed, skipping"
		exit 2
	fi

	# Download the latest DevPod tar.gz from GitHub releases
	local tar_url="https://github.com/loft-sh/devpod/releases/download/v${DEVPOD_VERSION}/DevPod_linux_x86_64.tar.gz"
	log "INFO" "Downloading DevPod tarball from ${tar_url}"

	curl -fsSL --retry 3 --retry-delay 5 "${tar_url}" -o /tmp/devpod.tar.gz || {
		log "ERROR" "Failed to download DevPod tarball"
		exit 1
	}

	# Extract tarball directly to /
	log "INFO" "Extracting tarball..."
	tar -xzf /tmp/devpod.tar.gz -C / || {
		log "ERROR" "Failed to extract tarball"
		exit 1
	}

	# Create symlink from devpod-cli to devpod
	log "INFO" "Creating devpod symlink..."
	ln -sf /usr/bin/devpod-cli /usr/bin/devpod

	# Ensure binaries are executable
	chmod +x /usr/bin/dev-pod-desktop
	chmod +x /usr/bin/devpod-cli
	log "INFO" "Set DevPod binaries as executable"

	# Fix desktop entry
	log "INFO" "Configuring desktop entry..."
	cat >/usr/share/applications/DevPod.desktop <<-'EOF'
		[Desktop Entry]
		Name=DevPod
		Comment=Spin up dev environments in any infra
		Exec="/usr/bin/dev-pod-desktop" --no-sandbox %U
		Icon=dev-pod-desktop
		Terminal=false
		Type=Application
		Categories=Development;
		StartupWMClass=DevPod
	EOF
	log "INFO" "Desktop entry configured"

	# Cleanup
	log "INFO" "Cleaning up temporary files..."
	rm -f /tmp/devpod.tar.gz

	# Verify installation
	log "INFO" "Verifying DevPod installation..."
	if command -v devpod &>/dev/null; then
		local version
		version=$(devpod version 2>/dev/null || echo "unknown")
		log "INFO" "DevPod CLI installed successfully (version: ${version})"
	else
		log "ERROR" "DevPod CLI not found after installation"
		exit 1
	fi

	if [[ -f "/usr/bin/dev-pod-desktop" ]]; then
		log "INFO" "DevPod desktop app installed successfully"
	else
		log "ERROR" "DevPod desktop app not found"
		exit 1
	fi

	local end_time duration
	end_time=$(date +%s)
	duration=$((end_time - start_time))

	log "INFO" "DONE (duration: ${duration}s)"
}

# Execute
main "$@"
