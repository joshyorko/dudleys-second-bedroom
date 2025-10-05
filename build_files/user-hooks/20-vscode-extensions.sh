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

MARKER="$HOME/.config/.vscode-insiders.done"
if [[ -f "$MARKER" ]]; then
  exit 0
fi

EXTENSIONS=( \
  ms-vscode-remote.remote-containers \
  ms-vscode-remote.remote-ssh \
  ms-vscode.remote-repositories \
  ms-vscode.cpptools-extension-pack \
)

for ext in "${EXTENSIONS[@]}"; do
  if ! "$CMD" --list-extensions --user-data-dir "$USER_DATA_DIR" --no-sandbox 2>/dev/null | grep -q "^${ext}$"; then
    "$CMD" --install-extension "$ext" --user-data-dir "$USER_DATA_DIR" --no-sandbox || true
  fi
done

touch "$MARKER" || true
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
