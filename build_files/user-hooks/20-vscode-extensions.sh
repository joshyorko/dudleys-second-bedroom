#!/usr/bin/bash
# Script: 20-vscode-extensions.sh
# Purpose: Install VS Code extensions for the user once a CLI is available
# Category: user-hooks
# Dependencies: none
# Parallel-Safe: yes
# Usage: Installed to /usr/share/ublue-os/user-setup.hooks.d/ and run on first login
# Author: Build System
# Last Updated: 2026-03-28

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
	local runtime_dir="/usr/share/ublue-os"
	install -d "$hook_dir" "$runtime_dir"

	log "INFO" "Creating VS Code extensions hook..."

	# Get build context path
	local build_context="${BUILD_CONTEXT:-/ctx}"

	# Install the extensions list to a single runtime path used by both
	# first-login hooks and manual ujust entrypoints.
	local extensions_list="$runtime_dir/vscode-extensions.list"
	if [[ -f "$build_context/vscode-extensions.list" ]]; then
		install -m 0644 "$build_context/vscode-extensions.list" "$extensions_list"
		log "INFO" "VS Code extensions list copied to $extensions_list"
	else
		log "WARNING" "vscode-extensions.list not found, creating default list"
		cat >"$extensions_list" <<'EXTENSIONS_EOF'
# VS Code Extensions - one per line
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
# VS Code extensions user hook
set -euo pipefail

resolve_vscode_cli() {
    local brew_prefix=""
    if command -v brew >/dev/null 2>&1; then
        brew_prefix="$(brew --prefix 2>/dev/null || true)"
    fi

    local candidates=()
    if [[ -n "$brew_prefix" ]]; then
        candidates+=("$brew_prefix/bin/code-insiders" "$brew_prefix/bin/code")
    fi
    candidates+=("code-insiders" "code")

    local candidate
    for candidate in "${candidates[@]}"; do
        if [[ -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi

        if command -v "$candidate" >/dev/null 2>&1; then
            command -v "$candidate"
            return 0
        fi
    done

    return 1
}

VSCODE_CMD="$(resolve_vscode_cli || true)"
if [[ -z "$VSCODE_CMD" ]]; then
    echo "Dudley Hook: vscode-extensions skipped because no VS Code CLI is installed yet"
    exit 0
fi

# Source ublue setup library for version tracking
source /usr/lib/ublue/setup-services/libsetup.sh

# Check if hook should run based on content version
if [[ "$(version-script vscode-extensions __CONTENT_VERSION__)" == "skip" ]]; then
    echo "Dudley Hook: vscode-extensions already at version __CONTENT_VERSION__, skipping"
    exit 0
fi

echo "Dudley Hook: vscode-extensions starting (version __CONTENT_VERSION__)"

# Ensure config directories exist
mkdir -p "$HOME/.config" || true
USER_DATA_DIR="$HOME/.config/Code - Insiders"
if [[ "$(basename "$VSCODE_CMD")" == "code" ]]; then
  USER_DATA_DIR="$HOME/.config/Code"
fi
mkdir -p "$USER_DATA_DIR" || true

# Keep marker file for manual tracking/debugging
MARKER="$USER_DATA_DIR/.extensions-installed"

# Force flag for manual re-installation (deletes marker and resets version)
if [[ "${VSCODE_EXTENSIONS_FORCE:-}" == "1" ]]; then
  echo "Force flag set, will reinstall extensions"
  rm -f "$MARKER" || true
  # Reset the version in setup_versioning.json to trigger reinstall
  SETUP_FILE="$HOME/.local/share/ublue/setup_versioning.json"
  if [[ -f "$SETUP_FILE" ]]; then
    TEMP_FILE=$(mktemp)
    jq 'del(.version.user."vscode-extensions")' "$SETUP_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$SETUP_FILE"
  fi
fi

echo "Installing VS Code extensions with $(basename "$VSCODE_CMD")..."

# Read extensions from list file
EXTENSIONS_LIST="/usr/share/ublue-os/vscode-extensions.list"
if [[ ! -f "$EXTENSIONS_LIST" ]]; then
  echo "ERROR: $EXTENSIONS_LIST not found"
  exit 1
fi

# Install each extension from the list
while IFS= read -r ext || [[ -n "$ext" ]]; do
  # Skip empty lines and comments
  [[ -z "$ext" ]] && continue
  [[ "$ext" =~ ^#.*$ ]] && continue

  # Trim whitespace
  ext=$(echo "$ext" | xargs)
  [[ -z "$ext" ]] && continue

  echo "Installing/updating extension: $ext"
  "$VSCODE_CMD" --install-extension "$ext" --force --user-data-dir "$USER_DATA_DIR" --no-sandbox || echo "Failed to install $ext"
done < "$EXTENSIONS_LIST"

# Write marker with version
cat >"$MARKER" <<MARKER_CONTENT
# VS Code extensions installed
# VERSION=__CONTENT_VERSION__
# Date: $(date -Iseconds)
# CLI: $VSCODE_CMD
MARKER_CONTENT

echo "Dudley Hook: vscode-extensions completed successfully"
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
