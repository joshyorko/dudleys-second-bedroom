#!/usr/bin/bash
# Script: 30-holotree-init.sh
# Purpose: Initialize RCC holotree for the current user to use shared holotree
# Category: user-hooks
# Dependencies: developer/rcc-cli.sh, developer/holotree-shared.sh
# Parallel-Safe: yes
# Usage: Installed as user hook; runs on first login to switch user to shared holotree
# Author: Build System
# Last Updated: 2025-10-09

set -eoux pipefail

# Module metadata
readonly MODULE_NAME="holotree-init"
readonly CATEGORY="user-hooks"

# Logging helper
log() {
    local level=$1
    shift
    echo "[MODULE:${CATEGORY}/${MODULE_NAME}] ${level}: $*"
}

main() {
    local start_time
    start_time=$(date +%s)

    log "INFO" "START - Installing holotree init user hook"

    local hook_dir="/usr/share/ublue-os/user-setup.hooks.d"
    install -d "$hook_dir"

    cat >"$hook_dir/30-holotree-init.sh" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail

# Initialize RCC to use shared holotree for this user (idempotent)
if command -v rcc &>/dev/null; then
  rcc holotree init || true
fi
HOOK

    chmod 0755 "$hook_dir/30-holotree-init.sh"
    log "INFO" "Holotree init hook installed"

    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    log "INFO" "DONE (duration: ${duration}s)"
}

main "$@"
