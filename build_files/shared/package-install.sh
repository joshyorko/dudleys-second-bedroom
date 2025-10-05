#!/usr/bin/bash
# Script: package-install.sh
# Purpose: Install packages from packages.json configuration
# Category: shared
# Dependencies: none
# Parallel-Safe: no
# Usage: Called early in build process to install system packages
# Author: Build System
# Last Updated: 2025-10-05

set -eoux pipefail

# Module metadata
readonly MODULE_NAME="package-install"
readonly CATEGORY="shared"
readonly PACKAGES_JSON="${PACKAGES_JSON:-/ctx/packages.json}"

# Logging helper
log() {
    local level=$1
    shift
    echo "[MODULE:${CATEGORY}/${MODULE_NAME}] ${level}: $*"
}

# Detect Fedora version
detect_fedora_version() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "${VERSION_ID}"
    else
        log "ERROR" "Cannot detect Fedora version"
        exit 1
    fi
}

# Enable COPR repositories
enable_copr_repos() {
    local fedora_version=$1
    local copr_repos
    
    # Get COPR repos for "all"
    copr_repos=$(jq -r '.all.copr_repos[]?' "$PACKAGES_JSON" 2>/dev/null || echo "")
    
    if [[ -n "$copr_repos" ]]; then
        log "INFO" "Enabling COPR repositories from 'all'..."
        while IFS= read -r repo; do
            if [[ -n "$repo" ]]; then
                log "INFO" "Enabling COPR: $repo"
                dnf5 -y copr enable "$repo" || dnf -y copr enable "$repo" || {
                    log "ERROR" "Failed to enable COPR: $repo"
                    exit 1
                }
            fi
        done <<< "$copr_repos"
    fi
    
    # Get version-specific COPR repos
    copr_repos=$(jq -r ".[\"$fedora_version\"].copr_repos[]?" "$PACKAGES_JSON" 2>/dev/null || echo "")
    
    if [[ -n "$copr_repos" ]]; then
        log "INFO" "Enabling COPR repositories for Fedora $fedora_version..."
        while IFS= read -r repo; do
            if [[ -n "$repo" ]]; then
                log "INFO" "Enabling COPR: $repo"
                dnf5 -y copr enable "$repo" || dnf -y copr enable "$repo" || {
                    log "ERROR" "Failed to enable COPR: $repo"
                    exit 1
                }
            fi
        done <<< "$copr_repos"
    fi
}

# Install packages
install_packages() {
    local fedora_version=$1
    local packages_to_install=()
    local packages_to_remove=()
    
    # Get packages for "all"
    log "INFO" "Loading packages from 'all' category..."
    while IFS= read -r pkg; do
        if [[ -n "$pkg" ]]; then
            packages_to_install+=("$pkg")
        fi
    done < <(jq -r '.all.install[]?' "$PACKAGES_JSON" 2>/dev/null || echo "")
    
    # Get version-specific packages
    log "INFO" "Loading packages for Fedora $fedora_version..."
    while IFS= read -r pkg; do
        if [[ -n "$pkg" ]]; then
            packages_to_install+=("$pkg")
        fi
    done < <(jq -r ".[\"$fedora_version\"].install[]?" "$PACKAGES_JSON" 2>/dev/null || echo "")
    
    # Apply install overrides
    local overrides
    overrides=$(jq -r ".[\"$fedora_version\"].install_overrides | to_entries[]? | \"\(.key)=\(.value)\"" "$PACKAGES_JSON" 2>/dev/null || echo "")
    if [[ -n "$overrides" ]]; then
        log "INFO" "Applying install overrides..."
        while IFS='=' read -r old_pkg new_pkg; do
            if [[ -n "$old_pkg" ]] && [[ -n "$new_pkg" ]]; then
                log "INFO" "Override: $old_pkg -> $new_pkg"
                # Remove old package from list
                packages_to_install=("${packages_to_install[@]/$old_pkg}")
                # Add new package
                packages_to_install+=("$new_pkg")
            fi
        done <<< "$overrides"
    fi
    
    # Get packages to remove
    while IFS= read -r pkg; do
        if [[ -n "$pkg" ]]; then
            packages_to_remove+=("$pkg")
        fi
    done < <(jq -r '.all.remove[]?' "$PACKAGES_JSON" 2>/dev/null || echo "")
    
    while IFS= read -r pkg; do
        if [[ -n "$pkg" ]]; then
            packages_to_remove+=("$pkg")
        fi
    done < <(jq -r ".[\"$fedora_version\"].remove[]?" "$PACKAGES_JSON" 2>/dev/null || echo "")
    
    # Install packages
    if [[ ${#packages_to_install[@]} -gt 0 ]]; then
        log "INFO" "Installing ${#packages_to_install[@]} packages: ${packages_to_install[*]}"
        if command -v dnf5 &>/dev/null; then
            dnf5 install -y "${packages_to_install[@]}" || {
                log "ERROR" "Failed to install packages"
                exit 1
            }
        else
            dnf install -y "${packages_to_install[@]}" || {
                log "ERROR" "Failed to install packages"
                exit 1
            }
        fi
        log "INFO" "Package installation complete"
    else
        log "INFO" "No packages to install"
    fi
    
    # Remove packages
    if [[ ${#packages_to_remove[@]} -gt 0 ]]; then
        log "INFO" "Removing ${#packages_to_remove[@]} packages: ${packages_to_remove[*]}"
        if command -v dnf5 &>/dev/null; then
            dnf5 remove -y "${packages_to_remove[@]}" || log "WARNING" "Some packages failed to remove"
        else
            dnf remove -y "${packages_to_remove[@]}" || log "WARNING" "Some packages failed to remove"
        fi
        log "INFO" "Package removal complete"
    else
        log "INFO" "No packages to remove"
    fi
}

# Main function
main() {
    local start_time
    start_time=$(date +%s)
    
    log "INFO" "START"
    
    # Check if packages.json exists
    if [[ ! -f "$PACKAGES_JSON" ]]; then
        log "ERROR" "packages.json not found at $PACKAGES_JSON"
        exit 1
    fi
    
    # Detect Fedora version
    local fedora_version
    fedora_version=$(detect_fedora_version)
    log "INFO" "Detected Fedora version: $fedora_version"
    
    # Enable COPR repositories
    enable_copr_repos "$fedora_version"
    
    # Install packages
    install_packages "$fedora_version"
    
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    log "INFO" "DONE (duration: ${duration}s)"
}

# Execute
main "$@"
