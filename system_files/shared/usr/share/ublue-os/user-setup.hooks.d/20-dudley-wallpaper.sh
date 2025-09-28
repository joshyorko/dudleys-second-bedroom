#!/usr/bin/env bash
set -euo pipefail

BG_PRIMARY="/usr/share/backgrounds/dudley/dudleys-second-bedroom-1.png"
MARKER="$HOME/.config/.dudley-wallpaper-applied"

# Only run once per user
mkdir -p "$HOME/.config"
if [[ -f "$MARKER" ]]; then
  exit 0
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

URI="file://$BG_PRIMARY"
run_gsettings set org.gnome.desktop.background picture-uri "$URI" || true
run_gsettings set org.gnome.desktop.background picture-uri-dark "$URI" || true
run_gsettings set org.gnome.desktop.background picture-options 'zoom' || true

# Optional: GNOME shell sometimes caches wallpapers in picture-uri
# Force reloading by touching the marker used by gnome-control-center
if [[ -d "$HOME/.cache/wallpaper" ]]; then
  rm -rf "$HOME/.cache/wallpaper"
fi

touch "$MARKER" || true
