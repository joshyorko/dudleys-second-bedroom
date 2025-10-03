#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs packages from fedora repos
dnf5 install -y tmux curl gcc-c++

# VS Code Insiders via RPM (flatpak beta currently unsuitable)
bash /ctx/20-install-code-insiders-rpm.sh

# User extension hook for code-insiders
bash /ctx/60-user-hook-code-insiders.sh

# Sema4.ai Action Server
bash /ctx/30-install-action-server.sh

### Install rcc CLI

RCC_VERSION="v18.8.0"
RCC_URL="https://github.com/joshyorko/rcc/releases/download/${RCC_VERSION}/rcc-linux64"

curl -fsSL "${RCC_URL}" -o /tmp/rcc
install -m755 /tmp/rcc /usr/bin/rcc
rm -f /tmp/rcc

ROBOCORP_HOME="/tmp/robocorp"
mkdir -p "${ROBOCORP_HOME}"
ROBOCORP_HOME="${ROBOCORP_HOME}" rcc version
rm -rf "${ROBOCORP_HOME}"

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket

### Brand Wallpaper & GNOME Overrides

# Sync static system files (wallpaper asset placeholder, schema + dconf overrides)
SYS_SHARED="/ctx/system_files/shared"
if [ ! -d "$SYS_SHARED" ] && [ -d /ctx/shared ]; then
	# Backward compatibility if system_files was copied without top-level dir
	SYS_SHARED="/ctx/shared"
fi
if [ -d "$SYS_SHARED" ]; then
	echo "Rsyncing branding/system overrides from $SYS_SHARED"
	rsync -a "$SYS_SHARED"/ /
	if [ -d /usr/share/ublue-os/user-setup.hooks.d ]; then
		find /usr/share/ublue-os/user-setup.hooks.d -type f -name '*.sh' -exec chmod 0755 {} +
	fi
else
	echo "WARN: Expected system_files shared directory not found (checked /ctx/system_files/shared and /ctx/shared)"
fi

# Dynamic branded backgrounds (Jorge style)
BG_DIR="/usr/share/backgrounds/dudley"
mkdir -p "$BG_DIR"

# Install all wallpaper images from custom_wallpapers directory
if [ -d /ctx/custom_wallpapers ]; then
	WALLPAPER_COUNT=0
	for wallpaper in /ctx/custom_wallpapers/*.{png,jpg,jpeg}; do
		if [ -f "$wallpaper" ]; then
			BASENAME=$(basename "$wallpaper")
			install -m644 "$wallpaper" "$BG_DIR/$BASENAME"
			echo "Installed wallpaper: $BASENAME"
			WALLPAPER_COUNT=$((WALLPAPER_COUNT + 1))
		fi
	done
	echo "Total wallpapers installed: $WALLPAPER_COUNT"
	
	# Verify the primary wallpaper (-1) exists for schema override
	if [ ! -f "$BG_DIR/dudleys-second-bedroom-1.png" ] && [ -f "$BG_DIR/dudleys-second-bedroom-1.jpg" ]; then
		echo "WARN: Schema expects dudleys-second-bedroom-1.png but found .jpg - consider renaming"
	elif [ ! -f "$BG_DIR/dudleys-second-bedroom-1.png" ] && [ ! -f "$BG_DIR/dudleys-second-bedroom-1.jpg" ]; then
		echo "WARN: No primary wallpaper (dudleys-second-bedroom-1.png/jpg) found for schema override"
	fi
else
	echo "WARN: No custom_wallpapers directory found"
fi

# Compile GLib schemas if any overrides were added
if [ -d /usr/share/glib-2.0/schemas ]; then
	glib-compile-schemas /usr/share/glib-2.0/schemas || echo "WARN: glib-compile-schemas failed"
fi

# Update dconf database if gdm.d overrides exist (check for actual files, not just directory)
if [ -n "$(find /etc/dconf/db/gdm.d -name '*.conf' -o -name '*-*' 2>/dev/null | grep -v '.gitkeep')" ]; then
	dconf update || echo "WARN: dconf update failed"
	echo "Updated GDM dconf database"
else
	echo "No GDM overrides found, skipping dconf update"
fi

echo "Wallpaper + schema overrides integrated."
