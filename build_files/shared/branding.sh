#!/usr/bin/bash
# Script: branding.sh
# Purpose: Install wallpapers and system branding/theming
# Category: shared
# Dependencies: none
# Parallel-Safe: yes
# Usage: Called during build to install branding assets
# Author: Build System
# Last Updated: 2025-10-05

set -eoux pipefail

echo "::group:: ===$(basename "$0")==="

# Module metadata
readonly MODULE_NAME="branding"
readonly CATEGORY="shared"
readonly PRIMARY_WALLPAPER_NAME="dudleys-second-bedroom-1"

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

	log "INFO" "START - Installing branding and wallpapers"

	# Sync static system files (wallpaper asset placeholder, schema + dconf overrides)
	local sys_shared="/ctx/system_files/shared"
	if [[ ! -d "$sys_shared" ]] && [[ -d /ctx/system_files ]]; then
		# Try alternate path
		sys_shared="/ctx/system_files"
	fi

	if [[ -d "$sys_shared" ]]; then
		log "INFO" "Rsyncing branding/system overrides from $sys_shared"
		rsync -a "$sys_shared"/ / || {
			log "ERROR" "Failed to rsync system files"
			exit 1
		}

		# Set correct permissions for user-setup hooks
		if [[ -d /usr/share/ublue-os/user-setup.hooks.d ]]; then
			find /usr/share/ublue-os/user-setup.hooks.d -type f -name '*.sh' -exec chmod 0755 {} +
			log "INFO" "Set execute permissions on user-setup hooks"
		fi

		# Set correct permissions for just files
		if [[ -d /usr/share/ublue-os/just ]]; then
			chmod 0644 /usr/share/ublue-os/just/*.just 2>/dev/null || true
			log "INFO" "Set read permissions on ujust files"
		fi
	else
		log "WARNING" "System files directory not found (checked $sys_shared)"
	fi

	# Install wallpapers from custom_wallpapers directory
	local bg_dir="/usr/share/backgrounds/dudley"
	mkdir -p "$bg_dir"
	log "INFO" "Created wallpaper directory: $bg_dir"

	if [[ -d /ctx/custom_wallpapers ]]; then
		local wallpaper_count=0

		for wallpaper in /ctx/custom_wallpapers/*.{png,jpg,jpeg}; do
			if [[ -f "$wallpaper" ]]; then
				local basename
				basename=$(basename "$wallpaper")
				install -m644 "$wallpaper" "$bg_dir/$basename"
				log "INFO" "Installed wallpaper: $basename"
				wallpaper_count=$((wallpaper_count + 1))
			fi
		done

		log "INFO" "Total wallpapers installed: $wallpaper_count"

		# Verify the primary wallpaper exists
		if [[ ! -f "$bg_dir/${PRIMARY_WALLPAPER_NAME}.png" ]] && [[ ! -f "$bg_dir/${PRIMARY_WALLPAPER_NAME}.jpg" ]]; then
			log "WARNING" "No primary wallpaper (${PRIMARY_WALLPAPER_NAME}.png/jpg) found for schema override"
		fi
	else
		log "WARNING" "No custom_wallpapers directory found at /ctx/custom_wallpapers"
	fi

	# Compile GLib schemas if any overrides were added
	if [[ -d /usr/share/glib-2.0/schemas ]]; then
		log "INFO" "Compiling GLib schemas..."
		glib-compile-schemas /usr/share/glib-2.0/schemas || {
			log "WARNING" "glib-compile-schemas failed (may not be critical)"
		}
	fi

	# Update dconf database if gdm.d overrides exist
	if find /etc/dconf/db/gdm.d -name '*.conf' -o -name '*-*' 2>/dev/null | grep -v '.gitkeep' | grep -q .; then
		log "INFO" "Updating dconf database..."
		dconf update || {
			log "WARNING" "dconf update failed (may not be critical)"
		}
		log "INFO" "Updated GDM dconf database"
	else
		log "INFO" "No GDM overrides found, skipping dconf update"
	fi

	local end_time duration
	end_time=$(date +%s)
	duration=$((end_time - start_time))

	log "INFO" "DONE (duration: ${duration}s)"
}

# Execute
main "$@"

echo "::endgroup::"
