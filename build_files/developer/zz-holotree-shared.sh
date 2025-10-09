#!/usr/bin/bash
# Script: zz-holotree-shared.sh
# Purpose: Enable RCC Shared Holotree system-wide (Linux) and verify setup
# Category: developer
# Dependencies: developer/rcc-cli.sh
# Parallel-Safe: yes
# Usage: Called during build after RCC is installed to enable shared holotree
# Author: Build System
# Last Updated: 2025-10-09

set -eoux pipefail

# Module metadata
readonly MODULE_NAME="holotree-shared"
readonly CATEGORY="developer"

# Logging helper
log() {
    local level=$1
    shift
    echo "[MODULE:${CATEGORY}/${MODULE_NAME}] ${level}: $*"
}

main() {
    local start_time
    start_time=$(date +%s)

    log "INFO" "START - Enabling RCC Shared Holotree (Linux)"

    if ! command -v rcc &>/dev/null; then
        log "ERROR" "rcc not found; ensure developer/rcc-cli.sh runs before this module"
        exit 1
    fi

    # Expected shared holotree location on Linux per RCC docs
    local shared_ht_root="/opt/robocorp/ht"

    # Pre-create directory structure to avoid RCC mkdir errors in container builds
    log "INFO" "Pre-creating shared holotree directory structure at $shared_ht_root"
    mkdir -p "$shared_ht_root" || true
    chmod 2775 "$shared_ht_root" 2>/dev/null || true

    # Enable shared holotree once per system; idempotent due to --once
    # Note: In container builds, RCC may error on existing dirs but still configure correctly
    log "INFO" "Enabling shared holotree at $shared_ht_root"
    if ! rcc holotree shared --enable --once 2>&1 | tee /tmp/rcc-enable.log; then
        if grep -qi "already exists\|file exists" /tmp/rcc-enable.log; then
            log "WARNING" "RCC reported directory exists errors (expected in container builds); continuing"
        else
            log "ERROR" "RCC shared holotree enable failed with unexpected errors"
            cat /tmp/rcc-enable.log
            exit 1
        fi
    fi
    rm -f /tmp/rcc-enable.log

    # Verify directory exists with correct permissions
    if [[ -d "$shared_ht_root" ]]; then
        log "INFO" "Shared holotree directory confirmed at $shared_ht_root"
        chmod 2775 "$shared_ht_root" 2>/dev/null || true
    else
        log "WARNING" "Shared holotree directory not found after enable command: $shared_ht_root"
    fi

    # Diagnostics for build logs
    if rcc diagnostics | grep -qi "shared holotree"; then
        log "INFO" "Shared holotree appears enabled (see diagnostics above)"
    else
        log "WARNING" "Unable to confirm shared holotree via diagnostics; continuing"
    fi

    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    log "INFO" "DONE (duration: ${duration}s)"
}

main "$@"
