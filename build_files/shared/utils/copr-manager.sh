#!/usr/bin/bash
# Script: copr-manager.sh
# Purpose: Manage COPR repositories (enable, disable, list)
# Category: shared/utils
# Dependencies: none
# Parallel-Safe: yes
# Usage: Source this file or call functions directly
# Author: Build System
# Last Updated: 2025-10-05

set -euo pipefail

# Enable a COPR repository
# Args: $1 - COPR repo in format "owner/repo"
# Returns: 0 on success, 1 on failure
copr_enable() {
	local repo=$1

	if [[ ! "$repo" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$ ]]; then
		echo "[copr-manager] ERROR: Invalid COPR repo format: $repo (expected: owner/repo)"
		return 1
	fi

	echo "[copr-manager] Enabling COPR: $repo"

	# Try dnf5 first, fall back to dnf
	if command -v dnf5 &>/dev/null; then
		if dnf5 -y copr enable "$repo"; then
			echo "[copr-manager] Successfully enabled: $repo"
			return 0
		else
			echo "[copr-manager] ERROR: Failed to enable COPR: $repo"
			return 1
		fi
	elif command -v dnf &>/dev/null; then
		if dnf -y copr enable "$repo"; then
			echo "[copr-manager] Successfully enabled: $repo"
			return 0
		else
			echo "[copr-manager] ERROR: Failed to enable COPR: $repo"
			return 1
		fi
	else
		echo "[copr-manager] ERROR: Neither dnf5 nor dnf found"
		return 1
	fi
}

# Disable a COPR repository
# Args: $1 - COPR repo in format "owner/repo"
# Returns: 0 on success, 1 on failure
copr_disable() {
	local repo=$1

	echo "[copr-manager] Disabling COPR: $repo"

	# Try dnf5 first, fall back to dnf
	if command -v dnf5 &>/dev/null; then
		if dnf5 -y copr disable "$repo"; then
			echo "[copr-manager] Successfully disabled: $repo"
			return 0
		else
			echo "[copr-manager] WARNING: Failed to disable COPR: $repo (may not be enabled)"
			return 0 # Not a critical error
		fi
	elif command -v dnf &>/dev/null; then
		if dnf -y copr disable "$repo"; then
			echo "[copr-manager] Successfully disabled: $repo"
			return 0
		else
			echo "[copr-manager] WARNING: Failed to disable COPR: $repo (may not be enabled)"
			return 0 # Not a critical error
		fi
	else
		echo "[copr-manager] ERROR: Neither dnf5 nor dnf found"
		return 1
	fi
}

# List enabled COPR repositories
# Returns: List of enabled COPR repos
copr_list() {
	echo "[copr-manager] Listing enabled COPR repositories..."

	if [[ -d /etc/yum.repos.d ]]; then
		local copr_repos
		copr_repos=$(find /etc/yum.repos.d -name '*copr*.repo' -type f)

		if [[ -z "$copr_repos" ]]; then
			echo "[copr-manager] No COPR repositories found"
			return 0
		fi

		for repo_file in $copr_repos; do
			local enabled
			enabled=$(grep -E "^enabled\s*=\s*1" "$repo_file" || echo "")

			if [[ -n "$enabled" ]]; then
				local repo_name
				repo_name=$(basename "$repo_file" .repo)
				echo "[copr-manager]   - $repo_name (enabled)"
			fi
		done
	else
		echo "[copr-manager] ERROR: /etc/yum.repos.d not found"
		return 1
	fi

	return 0
}

# Disable all COPR repositories
# Returns: 0 on success
copr_disable_all() {
	echo "[copr-manager] Disabling all COPR repositories..."

	if [[ ! -d /etc/yum.repos.d ]]; then
		echo "[copr-manager] ERROR: /etc/yum.repos.d not found"
		return 1
	fi

	local count=0
	for repo_file in /etc/yum.repos.d/*copr*.repo; do
		if [[ -f "$repo_file" ]]; then
			echo "[copr-manager] Setting enabled=0 in $(basename "$repo_file")"
			sed -i 's/enabled=1/enabled=0/g' "$repo_file" || true
			count=$((count + 1))
		fi
	done

	echo "[copr-manager] Disabled $count COPR repositories"
	return 0
}

# If script is executed directly (not sourced), show usage
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	case "${1:-}" in
	enable)
		if [[ $# -ne 2 ]]; then
			echo "Usage: $0 enable OWNER/REPO"
			exit 1
		fi
		copr_enable "$2"
		;;
	disable)
		if [[ $# -ne 2 ]]; then
			echo "Usage: $0 disable OWNER/REPO"
			exit 1
		fi
		copr_disable "$2"
		;;
	list)
		copr_list
		;;
	disable-all)
		copr_disable_all
		;;
	*)
		echo "Usage: $0 {enable|disable|list|disable-all} [OWNER/REPO]"
		echo "Examples:"
		echo "  $0 enable ublue-os/staging"
		echo "  $0 disable ublue-os/staging"
		echo "  $0 list"
		echo "  $0 disable-all"
		exit 1
		;;
	esac
fi
