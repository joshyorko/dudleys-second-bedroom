#!/usr/bin/bash
# Script: 10-wallpaper-enforcement.sh
# Purpose: Install first-login wallpaper hook using random wallpaper selection
# Category: user-hooks
# Dependencies: none
# Parallel-Safe: yes
# Usage: Installed to /usr/share/ublue-os/user-setup.hooks.d/ and run on first login
# Author: Build System
# Last Updated: 2026-02-22

set -eoux pipefail

# Module metadata
readonly MODULE_NAME="wallpaper-enforcement"
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

	log "INFO" "START - Installing wallpaper enforcement hook"

	local hook_dir="/usr/share/ublue-os/user-setup.hooks.d"
	install -d "$hook_dir"

	log "INFO" "Creating wallpaper enforcement hook..."
	cat >"$hook_dir/10-wallpaper-enforcement.sh" <<'HOOK_EOF'
#!/usr/bin/env bash
# Wallpaper enforcement user hook
set -euo pipefail

# Source ublue setup library for version tracking
source /usr/lib/ublue/setup-services/libsetup.sh

# Check if hook should run based on content version
if [[ "$(version-script wallpaper __CONTENT_VERSION__)" == "skip" ]]; then
    echo "Dudley Hook: wallpaper already at version __CONTENT_VERSION__, skipping"
    exit 0
fi

echo "Dudley Hook: wallpaper starting (version __CONTENT_VERSION__)"

# Apply wallpaper via shared runtime randomizer if available.
# This keeps first-login behavior aligned with per-login autostart rotation.
RANDOMIZER_CMD="/usr/bin/dudley-random-wallpaper"
if [[ ! -x "$RANDOMIZER_CMD" ]] && [[ -x /usr/local/bin/dudley-random-wallpaper ]]; then
    # Backward compatibility for previously built images.
    RANDOMIZER_CMD="/usr/local/bin/dudley-random-wallpaper"
fi

if [[ -x "$RANDOMIZER_CMD" ]]; then
    "$RANDOMIZER_CMD" || true
    echo "Random custom wallpaper selected successfully"
elif command -v gsettings &>/dev/null; then
    WALLPAPER_DIR="/usr/share/backgrounds/dudley"
    mapfile -d '' WALLPAPERS < <(
        find "$WALLPAPER_DIR" -maxdepth 1 -type f \
            \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) \
            -print0
    )

    if (( ${#WALLPAPERS[@]} > 0 )); then
        SELECTED_WALLPAPER="${WALLPAPERS[$((RANDOM % ${#WALLPAPERS[@]}))]}"
        SELECTED_URI="file://$SELECTED_WALLPAPER"
        gsettings set org.gnome.desktop.background picture-uri "$SELECTED_URI" || true
        gsettings set org.gnome.desktop.background picture-uri-dark "$SELECTED_URI" || true
        echo "Random custom wallpaper selected successfully"
    fi
fi

echo "Dudley Hook: wallpaper completed successfully"
HOOK_EOF

	chmod 0755 "$hook_dir/10-wallpaper-enforcement.sh"
	log "INFO" "Wallpaper enforcement hook installed"

	local end_time duration
	end_time=$(date +%s)
	duration=$((end_time - start_time))

	log "INFO" "DONE (duration: ${duration}s)"
}

# Execute
main "$@"
