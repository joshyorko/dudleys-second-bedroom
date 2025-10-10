#!/usr/bin/bash
# Script: devpod-alpha.sh
# Purpose: Install DevPod alpha release from GitHub (replaces Flatpak version)
# Category: developer
# Dependencies: curl, jq
# Parallel-Safe: yes
# Usage: Installs DevPod v0.7.0-alpha.34 from GitHub releases
# Author: Build System
# Last Updated: 2025-10-10

set -eoux pipefail

# Module metadata
readonly MODULE_NAME="devpod-alpha"
readonly CATEGORY="developer"
readonly DEVPOD_VERSION="v0.7.0-alpha.34"

# Logging helper
log() {
    local level=$1
    shift
    echo "[MODULE:${CATEGORY}/${MODULE_NAME}] ${level}: $*"
}

main() {
    local start_time
    start_time=$(date +%s)

    log "INFO" "START - Installing DevPod ${DEVPOD_VERSION} from GitHub"

    # Determine architecture
    local arch
    arch=$(uname -m)
    local appimage_pattern=""
    local cli_pattern=""
    
    case "$arch" in
        x86_64)
            appimage_pattern="DevPod_linux_amd64.AppImage"
            cli_pattern="devpod-linux-amd64"
            ;;
        aarch64)
            appimage_pattern="DevPod_linux_arm64.AppImage"
            cli_pattern="devpod-linux-arm64"
            ;;
        *)
            log "ERROR" "Unsupported architecture: $arch"
            return 1
            ;;
    esac

    log "INFO" "Detected architecture: $arch"

    # Fetch release info for specific version
    local api_url="https://api.github.com/repos/loft-sh/devpod/releases/tags/${DEVPOD_VERSION}"
    log "INFO" "Fetching release info from GitHub API..."
    
    local release_json
    if ! release_json=$(curl -fsSL "$api_url"); then
        log "ERROR" "Failed to fetch release info from $api_url"
        return 1
    fi

    # Extract download URLs for both AppImage (GUI) and CLI binary
    local appimage_url
    appimage_url=$(echo "$release_json" | jq -r ".assets[] | select(.name == \"$appimage_pattern\") | .browser_download_url" | head -n 1)
    
    local cli_url
    cli_url=$(echo "$release_json" | jq -r ".assets[] | select(.name == \"$cli_pattern\") | .browser_download_url" | head -n 1)

    if [[ -z "$appimage_url" || "$appimage_url" == "null" ]]; then
        log "ERROR" "No AppImage asset matching pattern '$appimage_pattern' found in release"
        log "INFO" "Available assets:"
        echo "$release_json" | jq -r '.assets[].name'
        return 1
    fi

    log "INFO" "Found AppImage: $appimage_url"
    log "INFO" "Found CLI binary: $cli_url"

    # Download and install AppImage (GUI application)
    local temp_appimage
    temp_appimage=$(mktemp)
    
    log "INFO" "Downloading DevPod AppImage..."
    if ! curl -fsSL "$appimage_url" -o "$temp_appimage"; then
        log "ERROR" "Failed to download from $appimage_url"
        rm -f "$temp_appimage"
        return 1
    fi

    # Install AppImage to /usr/bin
    log "INFO" "Installing DevPod AppImage to /usr/bin/devpod-gui..."
    install -m755 "$temp_appimage" /usr/bin/devpod-gui
    rm -f "$temp_appimage"

    # Download and install CLI binary (for terminal use)
    if [[ -n "$cli_url" && "$cli_url" != "null" ]]; then
        local temp_cli
        temp_cli=$(mktemp)
        
        log "INFO" "Downloading DevPod CLI binary..."
        if curl -fsSL "$cli_url" -o "$temp_cli"; then
            log "INFO" "Installing DevPod CLI to /usr/bin/devpod..."
            install -m755 "$temp_cli" /usr/bin/devpod
            rm -f "$temp_cli"
        else
            log "WARNING" "Failed to download CLI binary, skipping"
        fi
    fi

    # Install desktop entry so it shows in application menu
    log "INFO" "Installing desktop entry..."
    install -d /usr/share/applications
    cat > /usr/share/applications/devpod.desktop <<'DESKTOP'
[Desktop Entry]
Name=DevPod
Comment=Codespaces but open-source, client-only and unopinionated
Exec=/usr/bin/devpod-gui
Icon=devpod
Terminal=false
Type=Application
Categories=Development;IDE;
Keywords=devcontainer;container;kubernetes;docker;
StartupWMClass=DevPod
DESKTOP

    chmod 0644 /usr/share/applications/devpod.desktop
    log "INFO" "Desktop entry installed"

    # Install icon (download from GitHub)
    log "INFO" "Installing application icon..."
    local icon_url="https://raw.githubusercontent.com/loft-sh/devpod/main/desktop/src-tauri/icons/icon.png"
    local icon_dir="/usr/share/icons/hicolor/512x512/apps"
    install -d "$icon_dir"
    
    if curl -fsSL "$icon_url" -o "$icon_dir/devpod.png"; then
        chmod 0644 "$icon_dir/devpod.png"
        log "INFO" "Application icon installed"
    else
        log "WARNING" "Failed to download icon, using default"
    fi

    # Verify installation
    if [[ -x /usr/bin/devpod-gui ]]; then
        log "INFO" "DevPod GUI installed successfully at /usr/bin/devpod-gui"
    else
        log "ERROR" "DevPod GUI installation verification failed"
        return 1
    fi
    
    if [[ -x /usr/bin/devpod ]] && /usr/bin/devpod version &>/dev/null; then
        local installed_version
        installed_version=$(/usr/bin/devpod version | head -n1 || echo "unknown")
        log "INFO" "DevPod CLI installed successfully: $installed_version"
    else
        log "WARNING" "DevPod CLI not available (GUI will still work)"
    fi

    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    log "INFO" "DONE (duration: ${duration}s)"
}

main "$@"
