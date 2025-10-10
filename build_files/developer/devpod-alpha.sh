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
    local download_pattern=""
    
    case "$arch" in
        x86_64)
            download_pattern="devpod-linux-amd64"
            ;;
        aarch64)
            download_pattern="devpod-linux-arm64"
            ;;
        *)
            log "ERROR" "Unsupported architecture: $arch"
            return 1
            ;;
    esac

    log "INFO" "Detected architecture: $arch (pattern: $download_pattern)"

    # Fetch release info for specific version
    local api_url="https://api.github.com/repos/loft-sh/devpod/releases/tags/${DEVPOD_VERSION}"
    log "INFO" "Fetching release info from GitHub API..."
    
    local release_json
    if ! release_json=$(curl -fsSL "$api_url"); then
        log "ERROR" "Failed to fetch release info from $api_url"
        return 1
    fi

    # Extract download URL for the binary
    local download_url
    download_url=$(echo "$release_json" | jq -r ".assets[] | select(.name == \"$download_pattern\") | .browser_download_url" | head -n 1)

    if [[ -z "$download_url" || "$download_url" == "null" ]]; then
        log "ERROR" "No asset matching pattern '$download_pattern' found in release"
        log "INFO" "Available assets:"
        echo "$release_json" | jq -r '.assets[].name'
        return 1
    fi

    log "INFO" "Found asset: $download_url"

    # Download binary
    local temp_file
    temp_file=$(mktemp)
    
    log "INFO" "Downloading DevPod binary..."
    if ! curl -fsSL "$download_url" -o "$temp_file"; then
        log "ERROR" "Failed to download from $download_url"
        rm -f "$temp_file"
        return 1
    fi

    # Install to /usr/bin
    log "INFO" "Installing DevPod to /usr/bin/devpod..."
    install -m755 "$temp_file" /usr/bin/devpod
    rm -f "$temp_file"

    # Install desktop entry so it shows in application menu
    log "INFO" "Installing desktop entry..."
    install -d /usr/share/applications
    cat > /usr/share/applications/devpod.desktop <<'DESKTOP'
[Desktop Entry]
Name=DevPod
Comment=Codespaces but open-source, client-only and unopinionated
Exec=/usr/bin/devpod ui
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
    if /usr/bin/devpod version &>/dev/null; then
        local installed_version
        installed_version=$(/usr/bin/devpod version | head -n1 || echo "unknown")
        log "INFO" "DevPod installed successfully: $installed_version"
    else
        log "WARNING" "DevPod installed but version check failed (may still work)"
    fi

    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    log "INFO" "DONE (duration: ${duration}s)"
}

main "$@"
