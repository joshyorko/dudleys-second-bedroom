#!/usr/bin/bash
# Script: 10-wallpaper-enforcement.sh
# Purpose: Enforce custom wallpaper on first user login
# Category: user-hooks
# Dependencies: none
# Parallel-Safe: yes
# Usage: Installed to /usr/share/ublue-os/user-setup.hooks.d/ and run on first login
# Author: Build System
# Last Updated: 2025-10-05

set -eoux pipefail

# Module metadata
readonly MODULE_NAME="wallpaper-enforcement"
readonly CATEGORY="user-hooks"

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
    
    log "INFO" "START - Installing wallpaper enforcement hook"
    
    local hook_dir="/usr/share/ublue-os/user-setup.hooks.d"
    install -d "$hook_dir"
    
    log "INFO" "Creating wallpaper enforcement hook..."
    cat >"$hook_dir/10-wallpaper-enforcement.sh" <<'HOOK_EOF'
#!/usr/bin/env bash
# Wallpaper enforcement user hook
set -euo pipefail

# Source ublue setup library for version tracking
source /usr/lib/ublue/setup-services/libsetup.sh

# Check if hook should run based on content version
if [[ "$(version-script wallpaper __CONTENT_VERSION__)" == "skip" ]]; then
    echo "Dudley Hook: wallpaper already at version __CONTENT_VERSION__, skipping"
    exit 0
fi

echo "Dudley Hook: wallpaper starting (version __CONTENT_VERSION__)"

# Set custom wallpaper via gsettings
if command -v gsettings &>/dev/null; then
    # Set wallpaper for GNOME
    WALLPAPER_DIR="/usr/share/backgrounds/dudley"
    if [[ -f "$WALLPAPER_DIR/dudleys-second-bedroom-1.png" ]]; then
        gsettings set org.gnome.desktop.background picture-uri "file://$WALLPAPER_DIR/dudleys-second-bedroom-1.png" || true
        gsettings set org.gnome.desktop.background picture-uri-dark "file://$WALLPAPER_DIR/dudleys-second-bedroom-1.png" || true
        echo "Custom wallpaper set successfully"
    fi
fi

echo "Dudley Hook: wallpaper completed successfully"
HOOK_EOF
    
    chmod 0755 "$hook_dir/10-wallpaper-enforcement.sh"
    log "INFO" "Wallpaper enforcement hook installed"
    
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    log "INFO" "DONE (duration: ${duration}s)"
}

# Execute
main "$@"
