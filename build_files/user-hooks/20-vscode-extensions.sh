#!/usr/bin/bash
# Script: 20-vscode-extensions.sh
# Purpose: Install VS Code Insiders extensions for user
# Category: user-hooks
# Dependencies: developer/vscode-insiders.sh (must be installed first)
# Parallel-Safe: yes
# Usage: Installed to /usr/share/ublue-os/user-setup.hooks.d/ and run on first login
# Author: Build System
# Last Updated: 2025-10-05

set -eoux pipefail

# Module metadata
readonly MODULE_NAME="vscode-extensions"
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
    
    log "INFO" "START - Installing VS Code extensions hook"
    
    local hook_dir="/usr/share/ublue-os/user-setup.hooks.d"
    install -d "$hook_dir"
    
    log "INFO" "Creating VS Code extensions hook..."
    
    # Get build context path
    local build_context="${BUILD_CONTEXT:-/ctx}"
    
    # Copy the extensions list to the system
    local extensions_list="/etc/skel/.config/vscode-extensions.list"
    install -d "$(dirname "$extensions_list")"
    if [[ -f "$build_context/vscode-extensions.list" ]]; then
        cp "$build_context/vscode-extensions.list" "$extensions_list"
        chmod 0644 "$extensions_list"
        log "INFO" "VS Code extensions list copied to $extensions_list"
    else
        log "WARNING" "vscode-extensions.list not found, creating default list"
        cat >"$extensions_list" <<'EXTENSIONS_EOF'
# VS Code Insiders Extensions - one per line
ms-vscode-remote.remote-containers
ms-vscode-remote.remote-ssh
ms-vscode.remote-repositories
ms-vscode.cpptools-extension-pack
GitHub.copilot
GitHub.copilot-chat
EXTENSIONS_EOF
        chmod 0644 "$extensions_list"
    fi
    
    cat >"$hook_dir/20-vscode-extensions.sh" <<'HOOK_EOF'
#!/usr/bin/env bash
# VS Code Insiders extensions user hook
set -euo pipefail

CMD="code-insiders"
command -v "$CMD" >/dev/null 2>&1 || exit 0

# Ensure config directories exist
mkdir -p "$HOME/.config" || true
USER_DATA_DIR="$HOME/.config/Code - Insiders"
mkdir -p "$USER_DATA_DIR" || true

# Version tracking for re-installation when hook changes
readonly MARKER_VERSION=2
MARKER="$USER_DATA_DIR/.extensions-installed"

# Check if we should run
SHOULD_RUN=false

# Force flag for manual re-installation
if [[ "${VSCODE_EXTENSIONS_FORCE:-}" == "1" ]]; then
  echo "Force flag set, will reinstall extensions"
  SHOULD_RUN=true
  rm -f "$MARKER" || true
fi

# Check marker version
if [[ -f "$MARKER" ]]; then
  INSTALLED_VERSION=$(grep -oP '(?<=VERSION=)\d+' "$MARKER" 2>/dev/null || echo "0")
  if [[ "$INSTALLED_VERSION" -lt "$MARKER_VERSION" ]]; then
    echo "Hook updated (v$INSTALLED_VERSION -> v$MARKER_VERSION), will reinstall extensions"
    SHOULD_RUN=true
    rm -f "$MARKER" || true
  fi
else
  # No marker exists, first run
  SHOULD_RUN=true
fi

# Skip if not needed
if [[ "$SHOULD_RUN" == "false" ]]; then
  exit 0
fi

echo "Installing VS Code Insiders extensions..."

# Read extensions from list file
EXTENSIONS_LIST="/etc/skel/.config/vscode-extensions.list"
if [[ ! -f "$EXTENSIONS_LIST" ]]; then
  echo "Warning: $EXTENSIONS_LIST not found"
  exit 0
fi

# Install each extension from the list
while IFS= read -r ext || [[ -n "$ext" ]]; do
  # Skip empty lines and comments
  [[ -z "$ext" ]] && continue
  [[ "$ext" =~ ^#.*$ ]] && continue
  
  # Trim whitespace
  ext=$(echo "$ext" | xargs)
  [[ -z "$ext" ]] && continue
  
  echo "Installing extension: $ext"
  if ! "$CMD" --list-extensions --user-data-dir "$USER_DATA_DIR" --no-sandbox 2>/dev/null | grep -qi "^${ext}$"; then
    "$CMD" --install-extension "$ext" --user-data-dir "$USER_DATA_DIR" --no-sandbox || echo "Failed to install $ext"
  else
    echo "Extension $ext already installed"
  fi
done < "$EXTENSIONS_LIST"

# Write marker with version
cat >"$MARKER" <<MARKER_CONTENT
# VSCode Insiders extensions installed
# VERSION=$MARKER_VERSION
# Date: $(date -Iseconds)
MARKER_CONTENT

echo "VS Code Insiders extensions installation complete"
HOOK_EOF
    
    chmod 0755 "$hook_dir/20-vscode-extensions.sh"
    log "INFO" "VS Code extensions hook installed"
    
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    log "INFO" "DONE (duration: ${duration}s)"
}

# Execute
main "$@"
