#!/usr/bin/bash
# Script: 30-holotree-init.sh
# Purpose: Initialize RCC holotree for the current user to use shared holotree
# Category: user-hooks
# Dependencies: developer/rcc-cli.sh, developer/holotree-shared.sh
# Parallel-Safe: yes
# Usage: Installed as user hook; runs on first login to switch user to shared holotree
# Author: Build System
# Last Updated: 2025-11-12

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

	log "INFO" "Creating holotree init runtime hook..."
	cat >"$hook_dir/30-holotree-init.sh" <<'HOOK_EOF'
#!/usr/bin/env bash
# Holotree initialization user hook
set -euo pipefail

# Source Universal Blue setup library for version tracking
source /usr/lib/ublue/setup-services/libsetup.sh

# Check if hook should run based on content version
if [[ "$(version-script holotree-init __CONTENT_VERSION__)" == "skip" ]]; then
    echo "Dudley Hook: holotree-init already at version __CONTENT_VERSION__, skipping"
    exit 0
fi

echo "Dudley Hook: holotree-init starting (version __CONTENT_VERSION__)"

# Initialize RCC to use shared holotree for this user (idempotent)
if command -v rcc &>/dev/null; then
    echo "Dudley Hook: holotree-init initializing RCC holotree..."
    rcc holotree init || true
    echo "Dudley Hook: holotree-init RCC holotree initialized"
else
    echo "Dudley Hook: holotree-init RCC not installed, skipping"
fi

echo "Dudley Hook: holotree-init completed successfully"
HOOK_EOF

	chmod 0755 "$hook_dir/30-holotree-init.sh"
	log "INFO" "Holotree init hook installed"

	local end_time duration
	end_time=$(date +%s)
	duration=$((end_time - start_time))
	log "INFO" "DONE (duration: ${duration}s)"
}

main "$@"
