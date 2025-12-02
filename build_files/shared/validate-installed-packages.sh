#!/usr/bin/env bash
# Purpose: Validate installed packages after build
# Category: shared
# Dependencies: package-install
# Parallel-Safe: yes
# Cache-Friendly: yes
# Author: Build System
set -euo pipefail

echo "::group:: ===$(basename "$0")==="

# Module metadata
readonly MODULE_NAME="validate-packages"
readonly CATEGORY="shared"

# Logging helper
log() {
	local level=$1
	shift
	echo "[MODULE:${CATEGORY}/${MODULE_NAME}] ${level}: $*"
}

log "INFO" "START - Validating installed packages"

# Critical packages that MUST be installed
IMPORTANT_PACKAGES=(
	distrobox
	fish
	flatpak
	zsh
)

log "INFO" "Checking for required packages..."
for package in "${IMPORTANT_PACKAGES[@]}"; do
	if ! rpm -q "${package}" >/dev/null 2>&1; then
		log "ERROR" "Missing required package: ${package}"
		exit 1
	fi
done
log "INFO" "✓ All required packages present"

# Packages that should NOT be in the image (footguns)
UNWANTED_PACKAGES=(
	# Add packages that shouldn't be in your image
	# gnome-software-rpm-ostree  # Example: if you don't want this
)

if [[ ${#UNWANTED_PACKAGES[@]} -gt 0 ]]; then
	log "INFO" "Checking for unwanted packages..."
	for package in "${UNWANTED_PACKAGES[@]}"; do
		if rpm -q "${package}" >/dev/null 2>&1; then
			log "ERROR" "Unwanted package found: ${package}"
			exit 1
		fi
	done
	log "INFO" "✓ No unwanted packages found"
fi

log "INFO" "DONE - Package validation passed"

echo "::endgroup::"
