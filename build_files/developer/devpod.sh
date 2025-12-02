#!/usr/bin/env bash
# Purpose: Install latest DevPod by extracting DEB package
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
	if command -v devpod &>/dev/null && [[ -f /usr/bin/DevPod ]]; then
		log "INFO" "DevPod already installed, skipping"
		exit 2
	fi

	# Download the latest DevPod DEB from GitHub releases
	local deb_url="https://github.com/loft-sh/devpod/releases/download/v${DEVPOD_VERSION}/DevPod_${DEVPOD_VERSION}_amd64.deb"
	log "INFO" "Downloading DevPod DEB from ${deb_url}"

	curl -fsSL --retry 3 --retry-delay 5 "${deb_url}" -o /tmp/devpod.deb || {
		log "ERROR" "Failed to download DevPod DEB"
		exit 1
	}

	# Extract DEB package directly (no conversion needed)
	log "INFO" "Extracting DEB package..."
	cd /tmp
	ar x devpod.deb || {
		log "ERROR" "Failed to extract DEB archive"
		exit 1
	}

	# Extract the data tarball
	log "INFO" "Extracting package contents..."
	tar -xf data.tar.* -C / || {
		log "ERROR" "Failed to extract package data"
		exit 1
	}

	# Create symlink from devpod-cli to devpod
	log "INFO" "Creating devpod symlink..."
	ln -sf /usr/bin/devpod-cli /usr/bin/devpod

	# Download and install icon
	log "INFO" "Installing DevPod icon..."
	mkdir -p /usr/share/icons/hicolor/512x512/apps
	curl -fsSL --retry 3 \
		"https://raw.githubusercontent.com/loft-sh/devpod/main/desktop/src-tauri/icons/icon.png" \
		-o /usr/share/icons/hicolor/512x512/apps/devpod.png || {
		log "WARN" "Failed to download icon, continuing anyway"
	}

	# Update desktop entry to fix sandboxing issues and use correct binary path
	log "INFO" "Updating desktop entry..."
	if [[ -f /usr/share/applications/devpod.desktop ]]; then
		# DEB installs binary as /usr/bin/DevPod
		sed -i 's|^Exec=.*|Exec=/usr/bin/DevPod --no-sandbox %U|' \
			/usr/share/applications/devpod.desktop
		sed -i 's|^Icon=.*|Icon=devpod|' \
			/usr/share/applications/devpod.desktop
	else
		log "WARN" "Desktop entry not found, creating one..."
		cat >/usr/share/applications/devpod.desktop <<-'EOF'
			[Desktop Entry]
			Name=DevPod
			Comment=Codespaces but open-source, client-only and unopinionated
			Exec=/usr/bin/DevPod --no-sandbox %U
			Icon=devpod
			Terminal=false
			Type=Application
			Categories=Development;
			StartupWMClass=DevPod
		EOF
	fi

	# Ensure GUI binary is executable
	if [[ -f /usr/bin/DevPod ]]; then
		chmod +x /usr/bin/DevPod
	fi

	# Cleanup
	log "INFO" "Cleaning up temporary files..."
	rm -f /tmp/devpod.deb /tmp/control.tar.* /tmp/data.tar.* /tmp/debian-binary

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

	if [[ -f /usr/bin/DevPod ]]; then
		log "INFO" "DevPod desktop app installed successfully"
	else
		log "WARN" "DevPod desktop app not found, but CLI is available"
	fi

	local end_time duration
	end_time=$(date +%s)
	duration=$((end_time - start_time))

	log "INFO" "DONE (duration: ${duration}s)"
}

# Execute
main "$@"
