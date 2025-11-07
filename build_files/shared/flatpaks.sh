#!/usr/bin/bash
# Script: flatpaks.sh
# Purpose: Install system flatpak configurations
# Category: shared
# Dependencies: none
# Parallel-Safe: yes
# Usage: Copies flatpak list files to the system
# Author: Build System
# Last Updated: 2025-10-05

set -eoux pipefail

# Module metadata
readonly MODULE_NAME="flatpaks"
readonly CATEGORY="shared"

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
    
    log "INFO" "START - Installing flatpak configurations"
    
    # Get build context path
    local build_context="${BUILD_CONTEXT:-/ctx}"
    
    # Create flatpak config directory
    local flatpak_dir="/usr/share/ublue-os/flatpaks"
    install -d "$flatpak_dir"
    
    # Copy flatpak list files if they exist
    if [[ -f "$build_context/flatpaks/system-flatpaks.list" ]]; then
        log "INFO" "Installing system flatpaks list..."
        cp "$build_context/flatpaks/system-flatpaks.list" "$flatpak_dir/system-flatpaks.list"
        chmod 0644 "$flatpak_dir/system-flatpaks.list"
    else
        log "WARNING" "system-flatpaks.list not found, skipping"
    fi
    
    if [[ -f "$build_context/flatpaks/system-flatpaks-dx.list" ]]; then
        log "INFO" "Installing DX flatpaks list..."
        cp "$build_context/flatpaks/system-flatpaks-dx.list" "$flatpak_dir/system-flatpaks-dx.list"
        chmod 0644 "$flatpak_dir/system-flatpaks-dx.list"
    else
        log "WARNING" "system-flatpaks-dx.list not found, skipping"
    fi
    
    log "INFO" "Flatpak lists installed to $flatpak_dir"
    log "INFO" "Flatpaks will be installed on first boot by ublue-os setup scripts"
    
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    log "INFO" "DONE (duration: ${duration}s)"
}

# Execute
main "$@"
