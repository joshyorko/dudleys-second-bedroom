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

# Source ublue setup library for version tracking
source /usr/lib/ublue/setup-services/libsetup.sh

# Check if hook should run based on content version
if [[ "$(version-script welcome __CONTENT_VERSION__)" == "skip" ]]; then
    echo "Dudley Hook: welcome already at version __CONTENT_VERSION__, skipping"
    exit 0
fi

echo "Dudley Hook: welcome starting (version __CONTENT_VERSION__)"

# Read build manifest for build information
MANIFEST_PATH="/etc/dudley/build-manifest.json"
BUILD_INFO=""
HOOK_INFO=""

if [[ -f "$MANIFEST_PATH" ]] && command -v jq &>/dev/null; then
    # Extract build metadata
    BUILD_DATE=$(jq -r '.build.date // "unknown"' "$MANIFEST_PATH" 2>/dev/null || echo "unknown")
    IMAGE_NAME=$(jq -r '.build.image // "unknown"' "$MANIFEST_PATH" 2>/dev/null || echo "unknown")
    BASE_IMAGE=$(jq -r '.build.base // "unknown"' "$MANIFEST_PATH" 2>/dev/null || echo "unknown")
    GIT_COMMIT=$(jq -r '.build.commit // "unknown"' "$MANIFEST_PATH" 2>/dev/null || echo "unknown")

    # Extract hook information
    VSCODE_VERSION=$(jq -r '.hooks["vscode-extensions"].version // "unknown"' "$MANIFEST_PATH" 2>/dev/null || echo "unknown")
    VSCODE_COUNT=$(jq -r '.hooks["vscode-extensions"].metadata.extension_count // 0' "$MANIFEST_PATH" 2>/dev/null || echo "0")
    WALLPAPER_VERSION=$(jq -r '.hooks.wallpaper.version // "unknown"' "$MANIFEST_PATH" 2>/dev/null || echo "unknown")
    WALLPAPER_COUNT=$(jq -r '.hooks.wallpaper.metadata.wallpaper_count // 0' "$MANIFEST_PATH" 2>/dev/null || echo "0")

    # Format build info
    BUILD_INFO="
║  Build Information:                                        ║
║    Date: ${BUILD_DATE:0:19}                        ║
║    Commit: $GIT_COMMIT                                     ║
║    Base: ${BASE_IMAGE:0:40}      ║"

    # Format hook info
    HOOK_INFO="
║  Content Versions:                                         ║
║    VS Code Extensions: $VSCODE_VERSION ($VSCODE_COUNT installed)          ║
║    Wallpapers: $WALLPAPER_VERSION ($WALLPAPER_COUNT files)               ║"
else
    echo "Warning: Build manifest not found or jq not available" >&2
fi

# Display welcome message
cat <<WELCOME
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║           Welcome to Dudley's Second Bedroom!              ║
║                                                            ║
║  A customized Universal Blue OS image with:                ║
║    • COSMIC desktop environment                            ║
║    • Developer tools (VS Code Insiders, RCC, Action Server)║
║    • Custom branding and wallpapers                        ║${BUILD_INFO}${HOOK_INFO}
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
    # Display welcome message to terminal (if interactive)
    if [[ -t 1 ]]; then
        cat <<'WELCOME'

╔════════════════════════════════════════════════════════════╗
║                                                            ║
║        Welcome to Dudley's Second Bedroom!                 ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝

Your customized Universal Blue OS is ready!

  Build Info: Run 'dudley-build-info' to see version details
  VS Code:    Launch with 'code-insiders'
  Tools:      rcc, action-server, and container tools installed

Documentation saved to: ~/.local/share/dudley/README.md

WELCOME
    fi

    # Create README for user
    install -d "$user_docs"
    cat >"$user_docs/README.md" <<'README'
# Dudley's Second Bedroom

Welcome to your customized Universal Blue OS!

## Build Information

To view detailed build information at any time, run:

```bash
dudley-build-info
```

This will show you the build date, commit hash, and content versions for all hooks.

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

echo "Dudley Hook: welcome completed successfully"
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
