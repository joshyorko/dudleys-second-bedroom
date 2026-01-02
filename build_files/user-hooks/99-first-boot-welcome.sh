#!/usr/bin/bash
# Script: 99-first-boot-welcome.sh
# Purpose: Install login welcome script and create user documentation
# Category: user-hooks
# Dependencies: none
# Parallel-Safe: yes
# Usage: Installed to /usr/share/ublue-os/user-setup.hooks.d/ and run on first login
# Author: Build System
# Last Updated: 2026-01-02

set -eoux pipefail

# Module metadata
readonly MODULE_NAME="first-boot-welcome"
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

	log "INFO" "START - Installing welcome profile script and first-boot hook"

	local hook_dir="/usr/share/ublue-os/user-setup.hooks.d"
	local profile_dir="/etc/profile.d"
	install -d "$hook_dir"

	# =========================================================================
	# Profile.d script: Shows welcome message on EVERY login
	# =========================================================================
	log "INFO" "Creating login welcome profile script..."
	cat >"$profile_dir/dudley-welcome.sh" <<'PROFILE_EOF'
# Dudley's Second Bedroom - Login Welcome Message
# Runs on every interactive shell login

# Only show for interactive shells
[[ $- != *i* ]] && return

# Only show once per session (not in every subshell)
[[ -n "${DUDLEY_WELCOME_SHOWN:-}" ]] && return
export DUDLEY_WELCOME_SHOWN=1

# Read build info if available
_dudley_build_info=""
if [[ -f /etc/dudley/build-manifest.json ]] && command -v jq &>/dev/null; then
    _build_date=$(jq -r '.build.date // empty' /etc/dudley/build-manifest.json 2>/dev/null | cut -c1-10)
    _git_commit=$(jq -r '.build.commit // empty' /etc/dudley/build-manifest.json 2>/dev/null)
    if [[ -n "$_build_date" ]]; then
        _dudley_build_info=" (built: $_build_date${_git_commit:+, $_git_commit})"
    fi
fi

cat <<WELCOME

╔════════════════════════════════════════════════════════════╗
║        Welcome to Dudley's Second Bedroom!                 ║
╚════════════════════════════════════════════════════════════╝
  Build Info: Run 'dudley-build-info' for details${_dudley_build_info}
  Commands:   Run 'ujust' to see available commands

WELCOME

unset _dudley_build_info _build_date _git_commit
PROFILE_EOF

	chmod 0644 "$profile_dir/dudley-welcome.sh"
	log "INFO" "Login profile script installed at $profile_dir/dudley-welcome.sh"

	# =========================================================================
	# First-boot hook: Creates user docs (runs once per content version)
	# =========================================================================
	log "INFO" "Creating first-boot documentation hook..."
	cat >"$hook_dir/99-first-boot-welcome.sh" <<'HOOK_EOF'
#!/usr/bin/env bash
# First boot setup: create user documentation
set -euo pipefail

# Source ublue setup library for version tracking
source /usr/lib/ublue/setup-services/libsetup.sh

# Check if hook should run based on content version
if [[ "$(version-script welcome __CONTENT_VERSION__)" == "skip" ]]; then
    echo "Dudley Hook: welcome already at version __CONTENT_VERSION__, skipping"
    exit 0
fi

echo "Dudley Hook: welcome starting (version __CONTENT_VERSION__)"

# Create user documentation directory
DOC_DIR="$HOME/.local/share/dudley"
mkdir -p "$DOC_DIR"

cat >"$DOC_DIR/README.md" <<'README'
# Dudley's Second Bedroom

Welcome to your customized Universal Blue OS!

## Build Information

To view detailed build information at any time, run:

```bash
dudley-build-info
```

## Installed Tools

- **RCC CLI**: Robocorp toolchain - `rcc --help`
- **Action Server**: Sema4.ai tool - `action-server --help`
- **VS Code Insiders**: Install via `ujust dudley-vscode-insiders`

## Homebrew Packages

Install packages using ujust commands:

```bash
ujust dudley-brews-all     # Install all brew bundles
ujust dudley-brews-dev     # Development tools (includes VS Code Insiders)
ujust dudley-brews-cli     # CLI utilities
ujust dudley-brews-k8s     # Kubernetes tools
ujust dudley-brews-fonts   # Fonts
ujust dudley-vscode-insiders  # VS Code Insiders only
```

## Customizations

- Custom wallpapers in `/usr/share/backgrounds/dudley/`
- GNOME settings optimized for development
- Container tools pre-configured

## Getting Help

- Universal Blue Forums: https://universal-blue.discourse.group/
- Universal Blue Discord: https://discord.gg/WEu6BdFEtp
- Repository: https://github.com/joshyorko/dudleys-second-bedroom

## Updating

```bash
sudo bootc upgrade
```

## Customizing

This image is built from a Containerfile. Fork the repository and customize it!
README

echo "User documentation created at: $DOC_DIR/README.md"
echo "Dudley Hook: welcome completed successfully"
HOOK_EOF

	chmod 0755 "$hook_dir/99-first-boot-welcome.sh"
	log "INFO" "First-boot hook installed"

	local end_time duration
	end_time=$(date +%s)
	duration=$((end_time - start_time))

	log "INFO" "DONE (duration: ${duration}s)"
}

# Execute
main "$@"
