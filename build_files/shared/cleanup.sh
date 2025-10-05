#!/usr/bin/bash
# Script: cleanup.sh
# Purpose: Aggressive cleanup to reduce image size
# Category: shared
# Dependencies: none
# Parallel-Safe: yes
# Usage: Called at end of build process
# Author: Build System
# Last Updated: 2025-10-05

set -eoux pipefail

# Module metadata
readonly MODULE_NAME="cleanup"
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
    
    log "INFO" "START - Aggressive cleanup for image size reduction"
    
    # Clean package manager caches
    log "INFO" "Cleaning package manager caches..."
    rm -rf /var/cache/dnf* /var/cache/yum* || true
    rm -rf /var/lib/dnf/history* || true
    
    # Clean temporary directories
    log "INFO" "Cleaning temporary directories..."
    rm -rf /tmp/* /var/tmp/* || true
    
    # Clean log files
    log "INFO" "Cleaning log files..."
    rm -rf /var/log/* || true
    
    # Disable COPR repos (don't want them enabled in final image)
    log "INFO" "Disabling COPR repositories..."
    if compgen -G "/etc/yum.repos.d/*copr*.repo" > /dev/null; then
        for repo in /etc/yum.repos.d/*copr*.repo; do
            if [[ -f "$repo" ]]; then
                log "INFO" "Setting enabled=0 in $repo"
                sed -i 's/enabled=1/enabled=0/g' "$repo" || true
            fi
        done
    else
        log "INFO" "No COPR repositories found"
    fi
    
    # Recreate required directories with correct permissions
    log "INFO" "Recreating required directories..."
    mkdir -p /tmp /var/tmp /var/log
    chmod 1777 /tmp /var/tmp
    chmod 0755 /var/log
    
    # Commit OSTree changes
    log "INFO" "Committing OSTree container changes..."
    ostree container commit || {
        log "WARNING" "OSTree commit skipped (not in OSTree context)"
    }
    
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    log "INFO" "DONE (duration: ${duration}s)"
}

# Execute
main "$@"
