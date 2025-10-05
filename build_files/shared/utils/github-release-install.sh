#!/usr/bin/bash
# Script: github-release-install.sh
# Purpose: Reusable utility to install binaries from GitHub releases
# Category: shared/utils
# Dependencies: none
# Parallel-Safe: yes
# Usage: Source this file or call install_github_release function
# Author: Build System
# Last Updated: 2025-10-05

set -euo pipefail

# Install a binary from GitHub releases
# Args:
#   $1 - OWNER (GitHub username or org)
#   $2 - REPO (repository name)
#   $3 - PATTERN (pattern to match release asset, e.g., "linux64", "x86_64.tar.gz")
#   $4 - INSTALL_PATH (where to install the binary, e.g., "/usr/bin/toolname")
# Returns: 0 on success, 1 on failure
install_github_release() {
    local owner=$1
    local repo=$2
    local pattern=$3
    local install_path=$4
    
    echo "[github-release-install] Fetching latest release for $owner/$repo"
    
    # Get latest release info
    local api_url="https://api.github.com/repos/$owner/$repo/releases/latest"
    local release_json
    release_json=$(curl -fsSL "$api_url") || {
        echo "[github-release-install] ERROR: Failed to fetch release info from $api_url"
        return 1
    }
    
    # Extract download URL matching pattern
    local download_url
    download_url=$(echo "$release_json" | jq -r ".assets[] | select(.name | contains(\"$pattern\")) | .browser_download_url" | head -n 1)
    
    if [[ -z "$download_url" || "$download_url" == "null" ]]; then
        echo "[github-release-install] ERROR: No asset matching pattern '$pattern' found"
        return 1
    fi
    
    echo "[github-release-install] Found asset: $download_url"
    
    # Download to temporary location
    local temp_file
    temp_file=$(mktemp)
    
    echo "[github-release-install] Downloading..."
    curl -fsSL "$download_url" -o "$temp_file" || {
        echo "[github-release-install] ERROR: Failed to download from $download_url"
        rm -f "$temp_file"
        return 1
    }
    
    # Determine file type and handle accordingly
    local file_type
    file_type=$(file -b "$temp_file")
    
    if [[ "$file_type" == *"gzip compressed"* ]] || [[ "$download_url" == *.tar.gz ]]; then
        echo "[github-release-install] Extracting tar.gz archive..."
        local extract_dir
        extract_dir=$(mktemp -d)
        tar -xzf "$temp_file" -C "$extract_dir" || {
            echo "[github-release-install] ERROR: Failed to extract archive"
            rm -rf "$temp_file" "$extract_dir"
            return 1
        }
        
        # Find the binary in extracted files (assuming it's the largest executable)
        local binary_file
        binary_file=$(find "$extract_dir" -type f -executable | head -n 1)
        
        if [[ -z "$binary_file" ]]; then
            # No executable found, try to find any file matching the base name
            local base_name
            base_name=$(basename "$install_path")
            binary_file=$(find "$extract_dir" -type f -name "$base_name" | head -n 1)
        fi
        
        if [[ -z "$binary_file" ]]; then
            echo "[github-release-install] ERROR: No suitable binary found in archive"
            rm -rf "$temp_file" "$extract_dir"
            return 1
        fi
        
        echo "[github-release-install] Installing from archive: $binary_file"
        install -m755 "$binary_file" "$install_path"
        rm -rf "$temp_file" "$extract_dir"
        
    elif [[ "$file_type" == *"executable"* ]] || [[ "$file_type" == *"ELF"* ]]; then
        echo "[github-release-install] Installing binary directly..."
        install -m755 "$temp_file" "$install_path"
        rm -f "$temp_file"
        
    elif [[ "$file_type" == *"Zip archive"* ]] || [[ "$download_url" == *.zip ]]; then
        echo "[github-release-install] Extracting zip archive..."
        local extract_dir
        extract_dir=$(mktemp -d)
        unzip -q "$temp_file" -d "$extract_dir" || {
            echo "[github-release-install] ERROR: Failed to extract zip"
            rm -rf "$temp_file" "$extract_dir"
            return 1
        }
        
        local binary_file
        binary_file=$(find "$extract_dir" -type f -executable | head -n 1)
        
        if [[ -z "$binary_file" ]]; then
            local base_name
            base_name=$(basename "$install_path")
            binary_file=$(find "$extract_dir" -type f -name "$base_name" | head -n 1)
        fi
        
        if [[ -z "$binary_file" ]]; then
            echo "[github-release-install] ERROR: No suitable binary found in zip"
            rm -rf "$temp_file" "$extract_dir"
            return 1
        fi
        
        echo "[github-release-install] Installing from zip: $binary_file"
        install -m755 "$binary_file" "$install_path"
        rm -rf "$temp_file" "$extract_dir"
        
    else
        echo "[github-release-install] WARNING: Unknown file type '$file_type', treating as binary"
        install -m755 "$temp_file" "$install_path"
        rm -f "$temp_file"
    fi
    
    echo "[github-release-install] Successfully installed to $install_path"
    
    # Verify installation
    if [[ -f "$install_path" ]] && [[ -x "$install_path" ]]; then
        echo "[github-release-install] Verification: OK"
        return 0
    else
        echo "[github-release-install] ERROR: Installation verification failed"
        return 1
    fi
}

# If script is executed directly (not sourced), show usage
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -ne 4 ]]; then
        echo "Usage: $0 OWNER REPO PATTERN INSTALL_PATH"
        echo "Example: $0 joshyorko rcc linux64 /usr/bin/rcc"
        exit 1
    fi
    
    install_github_release "$@"
fi
