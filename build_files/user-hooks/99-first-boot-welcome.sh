#!/usr/bin/bash
# Script: 99-first-boot-welcome.sh
# Purpose: Display welcome message and create user documentation
# Category: user-hooks
# Dependencies: none
# Parallel-Safe: yes
# Usage: Installed to /usr/share/ublue-os/user-setup.hooks.d/ and run on first login
# Author: Build System
# Last Updated: 2025-10-05

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
    
    log "INFO" "START - Installing welcome hook"
    
    local hook_dir="/usr/share/ublue-os/user-setup.hooks.d"
    install -d "$hook_dir"
    
    log "INFO" "Creating welcome hook..."
    cat >"$hook_dir/99-first-boot-welcome.sh" <<'HOOK_EOF'
#!/usr/bin/env bash
# First boot welcome message user hook
set -euo pipefail

MARKER="$HOME/.config/.first-boot-welcome.done"
if [[ -f "$MARKER" ]]; then
  exit 0
fi

# Display welcome message
cat <<'WELCOME'
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║           Welcome to Dudley's Second Bedroom!              ║
║                                                            ║
║  A customized Universal Blue OS image with:                ║
║    • COSMIC desktop environment                            ║
║    • Developer tools (VS Code Insiders, RCC, Action Server)║
║    • Custom branding and wallpapers                        ║
║                                                            ║
║  Documentation: ~/.local/share/dudley/README.md            ║
║  Support: https://universal-blue.discourse.group/          ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
WELCOME

# Create user documentation directory
DOC_DIR="$HOME/.local/share/dudley"
mkdir -p "$DOC_DIR"

# Create README
cat >"$DOC_DIR/README.md" <<'README'
# Dudley's Second Bedroom

Welcome to your customized Universal Blue OS!

## Installed Tools

- **VS Code Insiders**: Launch with `code-insiders`
- **RCC CLI**: Robocorp toolchain - `rcc --help`
- **Action Server**: Sema4.ai tool - `action-server --help`

## Customizations

- Custom wallpapers in `/usr/share/backgrounds/dudley/`
- GNOME settings optimized for development
- Container tools pre-configured

## Getting Help

- Universal Blue Forums: https://universal-blue.discourse.group/
- Universal Blue Discord: https://discord.gg/WEu6BdFEtp
- Repository: https://github.com/joshyorko/dudleys-second-bedroom

## Updating

The system updates automatically via rpm-ostree. You can also manually update:

```bash
sudo bootc upgrade
```

## Customizing

This image is built from a Containerfile. Fork the repository and customize it!
README

echo "User documentation created at: $DOC_DIR/README.md"

touch "$MARKER" || true
HOOK_EOF
    
    chmod 0755 "$hook_dir/99-first-boot-welcome.sh"
    log "INFO" "Welcome hook installed"
    
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    log "INFO" "DONE (duration: ${duration}s)"
}

# Execute
main "$@"
