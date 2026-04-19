#!/usr/bin/env bash

set -eoux pipefail

IMAGE_INFO="$(cat /usr/share/ublue-os/image-info.json)"
IMAGE_TAG="$(jq -r '."image-tag"' <<<"$IMAGE_INFO")"
IMAGE_REF="$(jq -r '."image-ref"' <<<"$IMAGE_INFO")"
IMAGE_REF="${IMAGE_REF##*://}"
SECURE_BOOT_KEY_URL='https://github.com/ublue-os/akmods/raw/main/certs/public_key.der'
MOK_ENROLLMENT_PASSWORD="${DUDLEY_MOK_ENROLLMENT_PASSWORD:-$(hexdump -vn 10 -e '/1 "%02x"' /dev/urandom)}"
MOK_PASSWORD_FILE="/usr/share/dudley-installer/mok-enrollment-password.txt"

# Re-enable the stock Fedora repos for ISO assembly.
# The base image intentionally ships with all repos disabled, but Titanoboa
# still needs them later when it installs dracut-live during initramfs creation.
enable_fedora_iso_repos() {
	local repo_dirs=(
		/etc/yum.repos.d
		/usr/etc/yum.repos.d
	)
	local repo_names=(
		fedora.repo
		fedora-updates.repo
	)
	local repo_dir repo_name repo_path

	for repo_dir in "${repo_dirs[@]}"; do
		[[ -d "$repo_dir" ]] || continue

		for repo_name in "${repo_names[@]}"; do
			repo_path="${repo_dir}/${repo_name}"
			[[ -f "$repo_path" ]] || continue

			sed -i 's/^enabled=0$/enabled=1/g' "$repo_path"
		done
	done
}

enable_fedora_iso_repos

# Configure the live environment for installer-focused use.
tee /usr/share/glib-2.0/schemas/zz2-org.gnome.shell.gschema.override <<'EOF'
[org.gnome.shell]
welcome-dialog-last-shown-version='4294967295'
favorite-apps = ['anaconda.desktop', 'org.mozilla.firefox.desktop', 'org.gnome.Nautilus.desktop']
EOF

tee /usr/share/glib-2.0/schemas/zz3-dudley-installer-power.gschema.override <<'EOF'
[org.gnome.settings-daemon.plugins.power]
sleep-inactive-ac-type='nothing'
sleep-inactive-battery-type='nothing'
sleep-inactive-ac-timeout=0
sleep-inactive-battery-timeout=0

[org.gnome.desktop.session]
idle-delay=uint32 0
EOF

rm -f /etc/xdg/autostart/org.gnome.Software.desktop

tee /usr/share/gnome-shell/search-providers/org.gnome.Software-search-provider.ini <<'EOF'
DefaultDisabled=true
EOF

glib-compile-schemas /usr/share/glib-2.0/schemas

systemctl disable rpm-ostree-countme.service || true
systemctl disable tailscaled.service || true
systemctl disable bootloader-update.service || true
systemctl disable brew-upgrade.timer || true
systemctl disable brew-update.timer || true
systemctl disable brew-setup.service || true
systemctl disable rpm-ostreed-automatic.timer || true
systemctl disable uupd.timer || true
systemctl disable ublue-system-setup.service || true
systemctl disable flatpak-preinstall.service || true
systemctl --global disable ublue-flatpak-manager.service || true
systemctl --global disable podman-auto-update.timer || true
systemctl --global disable ublue-user-setup.service || true

# Install Anaconda and the storage helpers needed for Btrfs installs.
mkdir -p /etc/anaconda/profile.d
mkdir -p /etc/motd.d
mkdir -p /usr/share/dudley-installer
mkdir -p /usr/share/anaconda/post-scripts

dnf install -y \
	libblockdev-btrfs \
	libblockdev-lvm \
	libblockdev-dm \
	anaconda-live \
	mokutil \
	openssl \
	rsync \
	firefox

# Create a Dudley-specific Anaconda profile while still matching the Bluefin base image.
tee /etc/anaconda/profile.d/dudley.conf <<'EOF'
# Anaconda configuration file for Dudley's Second Bedroom

[Profile]
profile_id = dudley

[Profile Detection]
os_id = bluefin

[Network]
default_on_boot = FIRST_WIRED_WITH_LINK

[Bootloader]
efi_dir = fedora
menu_auto_hide = True

[Storage]
default_scheme = BTRFS
btrfs_compression = zstd:1
default_partitioning =
    /     (min 1 GiB, max 70 GiB)
    /home (min 500 MiB, free 50 GiB)
    /var  (btrfs)

[User Interface]
hidden_spokes =
    NetworkSpoke
    PasswordSpoke
    UserSpoke
hidden_webui_pages =
    anaconda-screen-accounts

[Localization]
use_geolocation = False
EOF

. /etc/os-release
echo "Dudley's Second Bedroom installer for Bluefin $VERSION_ID" >/etc/system-release
sed -i 's/ANACONDA_PRODUCTVERSION=.*/ANACONDA_PRODUCTVERSION=""/' /usr/{,s}bin/liveinst || true
sed -i 's| Fedora| Dudley|' /usr/share/anaconda/gnome/fedora-welcome || true
sed -i 's|Activities|the dock|' /usr/share/anaconda/gnome/fedora-welcome || true

# Configure the interactive install to target the published Dudley image.
tee -a /usr/share/anaconda/interactive-defaults.ks <<EOF
# Require the configured container signature policy/keys to validate the image.
ostreecontainer --url=$IMAGE_REF:$IMAGE_TAG --transport=containers-storage
%include /usr/share/anaconda/post-scripts/install-configure-upgrade.ks
%include /usr/share/anaconda/post-scripts/install-flatpaks.ks
%include /usr/share/anaconda/post-scripts/secureboot-enroll-key.ks
EOF

tee /usr/share/anaconda/post-scripts/install-configure-upgrade.ks <<EOF
%post --erroronfail
bootc switch --mutate-in-place --transport registry $IMAGE_REF:$IMAGE_TAG
%end
EOF

tee /usr/share/anaconda/post-scripts/install-flatpaks.ks <<'EOF'
%post --erroronfail --nochroot
deployment="$(ostree rev-parse --repo=/mnt/sysimage/ostree/repo ostree/0/1/0)"
target="/mnt/sysimage/ostree/deploy/default/deploy/$deployment.0/var/lib/"
mkdir -p "$target"
rsync -aAXUHKP /var/lib/flatpak "$target"
%end
EOF

tee "$MOK_PASSWORD_FILE" <<EOF
Secure Boot key enrollment password for this installer build:
$MOK_ENROLLMENT_PASSWORD

Set DUDLEY_MOK_ENROLLMENT_PASSWORD during the ISO build if you need a custom value.
EOF

tee /etc/motd.d/90-dudley-mok-password <<EOF
Secure Boot enrollment password:
$MOK_ENROLLMENT_PASSWORD

Saved at $MOK_PASSWORD_FILE
EOF

curl --fail --show-error --location --retry 15 --output /etc/sb_pubkey.der "$SECURE_BOOT_KEY_URL"
if ! openssl x509 -inform DER -in /etc/sb_pubkey.der -noout >/dev/null 2>&1; then
	echo "Downloaded secure boot key is not a valid DER certificate: /etc/sb_pubkey.der" >&2
	rm -f /etc/sb_pubkey.der
	exit 1
fi

tee /usr/share/anaconda/post-scripts/secureboot-enroll-key.ks <<EOF
%post --erroronfail --nochroot
set -euo pipefail

readonly ENROLLMENT_PASSWORD="$MOK_ENROLLMENT_PASSWORD"
readonly SECUREBOOT_KEY="/etc/sb_pubkey.der"

if [[ ! -d "/sys/firmware/efi" ]]; then
    echo "EFI mode not detected. Skipping key enrollment."
    exit 0
fi

if [[ ! -f "$SECUREBOOT_KEY" ]]; then
    echo "Secure boot key not provided: $SECUREBOOT_KEY"
    exit 0
fi

mokutil --timeout -1 || :
echo -e "$ENROLLMENT_PASSWORD\n$ENROLLMENT_PASSWORD" | mokutil --import "$SECUREBOOT_KEY" || :
%end
EOF
