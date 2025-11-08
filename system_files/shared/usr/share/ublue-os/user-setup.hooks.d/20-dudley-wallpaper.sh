#!/usr/bin/env bash
set -euo pipefail

BG_PRIMARY="/usr/share/backgrounds/dudley/dudleys-second-bedroom-1.png"
MARKER_DIR="$HOME/.config"
MARKER_VERSION="3"
MARKER_FILE=".dudley-wallpaper-applied"
MARKER="$MARKER_DIR/$MARKER_FILE"

# Allow force re-run: set DUDLEY_WALLPAPER_FORCE=1 in env or remove marker.
# Auto re-run if version changes (bump MARKER_VERSION when logic changes).

DESIRED_URI="file://$BG_PRIMARY"
DESIRED_MODE="zoom"

mkdir -p "$MARKER_DIR"

# If marker exists, validate current settings; reapply if drift detected.
if [[ -f "$MARKER" ]]; then
	CURRENT_VERSION=$(awk -F= '/^version=/{print $2}' "$MARKER" 2>/dev/null || echo '')
	CUR_URI=$(gsettings get org.gnome.desktop.background picture-uri 2>/dev/null || echo '')
	CUR_MODE=$(gsettings get org.gnome.desktop.background picture-options 2>/dev/null || echo '')
	FORCE=${DUDLEY_WALLPAPER_FORCE:-0}
	if [[ "$FORCE" != "1" && "$CURRENT_VERSION" == "$MARKER_VERSION" && "$CUR_URI" == "'$DESIRED_URI'" && "$CUR_MODE" == "'$DESIRED_MODE'" ]]; then
		exit 0
	fi
	echo "Reapplying Dudley wallpaper (drift or version change detected)" >&2
fi

# Require primary wallpaper asset
if [[ ! -f "$BG_PRIMARY" ]]; then
	echo "dudley wallpaper hook: primary wallpaper missing" >&2
	exit 0
fi

if ! command -v gsettings >/dev/null 2>&1; then
	echo "dudley wallpaper hook: gsettings unavailable" >&2
	exit 0
fi

# Helper to tolerate missing session bus
run_gsettings() {
	if gsettings "$@"; then
		return 0
	fi
	if command -v dbus-run-session >/dev/null 2>&1; then
		dbus-run-session -- gsettings "$@"
	else
		return 1
	fi
}

run_gsettings set org.gnome.desktop.background picture-uri "$DESIRED_URI" || true
run_gsettings set org.gnome.desktop.background picture-uri-dark "$DESIRED_URI" || true
run_gsettings set org.gnome.desktop.background picture-options "$DESIRED_MODE" || true

# Optional: GNOME shell sometimes caches wallpapers in picture-uri
# Force reloading by touching the marker used by gnome-control-center
if [[ -d "$HOME/.cache/wallpaper" ]]; then
	rm -rf "$HOME/.cache/wallpaper"
fi

{
	echo "version=$MARKER_VERSION"
	echo "uri=$DESIRED_URI"
	echo "mode=$DESIRED_MODE"
} >"$MARKER" || true
