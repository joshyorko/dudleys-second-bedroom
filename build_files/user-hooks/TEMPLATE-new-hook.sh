#!/usr/bin/bash
#
# Script: TEMPLATE-new-hook.sh
# Purpose: [TODO: Describe what this hook does - e.g., "Install custom fonts and themes"]
# Category: user-hooks
# Dependencies: [TODO: List any other hooks or build modules this depends on]
# Parallel-Safe: yes
# Usage: Installed to /usr/share/ublue-os/user-setup.hooks.d/ and run on first user login
# Author: [TODO: Your Name]
# Date: [TODO: Current Date]
#
# This is a template for creating new user hooks with automatic content-based versioning.
# Follow the TODO markers to customize this template for your specific use case.
#
# IMPORTANT: After creating your hook, you MUST also:
# 1. Add it to build_files/shared/utils/generate-manifest.sh
# 2. Test it locally before committing
# 3. Update this file's header documentation
#

set -eoux pipefail

# ==============================================================================
# MODULE METADATA
# ==============================================================================
# This section defines basic metadata for logging and identification

# TODO: Update these to match your hook name
readonly MODULE_NAME="new-hook-name"  # Use kebab-case: e.g., "custom-fonts"
readonly CATEGORY="user-hooks"

# Logging helper function
log() {
    local level=$1
    shift
    echo "[MODULE:${CATEGORY}/${MODULE_NAME}] ${level}: $*"
}

# ==============================================================================
# MAIN BUILD-TIME FUNCTION
# ==============================================================================
# This function runs during IMAGE BUILD and installs the runtime hook script
# to /usr/share/ublue-os/user-setup.hooks.d/

main() {
    local start_time
    start_time=$(date +%s)
    
    log "INFO" "START - Installing ${MODULE_NAME} hook"
    
    # Create hook directory if it doesn't exist
    local hook_dir="/usr/share/ublue-os/user-setup.hooks.d"
    install -d "$hook_dir"
    
    # TODO: If your hook needs data files, copy them here
    # Example:
    # local config_dir="/etc/skel/.config/my-app"
    # install -d "$config_dir"
    # cp "$BUILD_CONTEXT/my-config-file.conf" "$config_dir/"
    
    log "INFO" "Creating ${MODULE_NAME} runtime hook..."
    
    # TODO: Update the priority number (NN) to control execution order
    # 10-19: System/environment setup
    # 20-29: Application installation/configuration
    # 90-99: Finalization and welcome messages
    cat >"$hook_dir/NN-${MODULE_NAME}.sh" <<'HOOK_EOF'
#!/usr/bin/env bash
#
# Runtime Hook: [TODO: Hook description]
# This script runs on first user login and on subsequent logins if content changes
#

set -euo pipefail

# ==============================================================================
# VERSION TRACKING INTEGRATION
# ==============================================================================
# This section integrates with Universal Blue's version-script for automatic
# content-based versioning. DO NOT MODIFY unless you understand the system.

# Source Universal Blue setup library
source /usr/lib/ublue/setup-services/libsetup.sh

# TODO: Update hook name to match MODULE_NAME above
HOOK_NAME="new-hook-name"

# CRITICAL: Leave __CONTENT_VERSION__ exactly as-is - it gets replaced at build time
HOOK_VERSION="__CONTENT_VERSION__"

# Check if hook should run based on content version
if [[ "$(version-script "$HOOK_NAME" "$HOOK_VERSION")" == "skip" ]]; then
    echo "Dudley Hook: $HOOK_NAME already at version $HOOK_VERSION, skipping"
    exit 0
fi

# Log hook start (helps with debugging via journalctl)
echo "Dudley Hook: $HOOK_NAME starting (version $HOOK_VERSION)"

# ==============================================================================
# HOOK LOGIC - CUSTOMIZE THIS SECTION
# ==============================================================================
# This is where you implement your hook's functionality.
# Best practices:
# - Check if required commands exist before using them
# - Use || true for non-critical operations that may fail
# - Log important actions for debugging
# - Keep operations idempotent (safe to run multiple times)

# Example: Check if a command exists
if ! command -v some-command &>/dev/null; then
    echo "Warning: some-command not found, skipping some operations"
else
    echo "Running some-command..."
    # some-command --option value || echo "Warning: some-command failed"
fi

# TODO: Implement your hook logic here
# Example patterns:

# Pattern 1: Install/configure software
# Example:
# if command -v flatpak &>/dev/null; then
#     echo "Installing flatpak applications..."
#     flatpak install -y flathub org.example.App || true
# fi

# Pattern 2: Configure user settings
# Example:
# if command -v gsettings &>/dev/null; then
#     echo "Configuring GNOME settings..."
#     gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' || true
# fi

# Pattern 3: Copy/setup files
# Example:
# echo "Setting up configuration files..."
# mkdir -p "$HOME/.config/my-app"
# cp /etc/skel/.config/my-app/* "$HOME/.config/my-app/" || true

# Pattern 4: Run initialization commands
# Example:
# echo "Initializing application..."
# my-app --init || echo "Warning: initialization failed"

# ==============================================================================
# HOOK COMPLETION
# ==============================================================================
# Log completion - version will be recorded automatically by version-script

echo "Dudley Hook: $HOOK_NAME completed successfully"

# IMPORTANT: Version is recorded ONLY if this script exits with status 0
# If any critical operation above should prevent version recording, use:
#   some-critical-command || exit 1
# For non-critical operations, use:
#   some-optional-command || true
HOOK_EOF
    
    # Make hook executable
    chmod 0755 "$hook_dir/NN-${MODULE_NAME}.sh"
    log "INFO" "${MODULE_NAME} hook installed"
    
    # Calculate and log duration
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    log "INFO" "DONE (duration: ${duration}s)"
}

# ==============================================================================
# EXECUTION
# ==============================================================================
# Execute main function with all script arguments
main "$@"
