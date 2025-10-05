#!/usr/bin/bash
# Script: signing.sh
# Purpose: Set up container signature verification
# Category: shared
# Dependencies: none
# Parallel-Safe: yes
# Usage: Called during build to configure container signing
# Author: Build System
# Last Updated: 2025-10-05

set -eoux pipefail

# Module metadata
readonly MODULE_NAME="signing"
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
    
    log "INFO" "START - Configuring container signature verification"
    
    # Check if cosign.pub exists
    if [[ ! -f /ctx/cosign.pub ]]; then
        log "WARNING" "cosign.pub not found at /ctx/cosign.pub, skipping signature setup"
        exit 2
    fi
    
    # Create containers policy directory
    local policy_dir="/etc/pki/containers"
    mkdir -p "$policy_dir"
    log "INFO" "Created policy directory: $policy_dir"
    
    # Copy cosign public key
    install -m644 /ctx/cosign.pub "$policy_dir/cosign.pub"
    log "INFO" "Installed cosign public key to $policy_dir/cosign.pub"
    
    # Create policy.json.d entry for signature verification
    # Note: This is a placeholder - actual policy configuration would be more complex
    local policy_d="/etc/containers/policy.json.d"
    if [[ -d "$policy_d" ]]; then
        log "INFO" "Container policy directory exists: $policy_d"
        # Could add custom policy here if needed
    else
        log "INFO" "Container policy directory not found (may not be needed)"
    fi
    
    # Set proper permissions
    chmod 644 "$policy_dir/cosign.pub"
    log "INFO" "Set permissions on cosign.pub"
    
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    log "INFO" "DONE (duration: ${duration}s)"
}

# Execute
main "$@"
