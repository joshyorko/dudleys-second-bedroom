#!/usr/bin/bash
# Script: system-services.sh
# Purpose: Enable system services
# Category: shared
# Dependencies: none
# Parallel-Safe: yes
# Usage: Called during build to enable system services
# Author: Build System
# Last Updated: 2025-10-05

set -eoux pipefail

# Module metadata
readonly MODULE_NAME="system-services"
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
    
    log "INFO" "START"
    
    # Enable podman socket service
    log "INFO" "Enabling podman.socket..."
    systemctl enable podman.socket || {
        log "WARNING" "Failed to enable podman.socket (may not be critical)"
    }
    
    # Add other system services here as needed
    
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    log "INFO" "DONE (duration: ${duration}s)"
}

# Execute
main "$@"
