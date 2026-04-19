#!/usr/bin/env bash

set -euo pipefail

# The base image intentionally leaves repos disabled. Titanoboa's initramfs
# recipe installs dracut-live before the post-rootfs hook runs, so the stock
# Fedora repos need to be enabled ahead of that step.
repo_dirs=(
	/etc/yum.repos.d
	/usr/etc/yum.repos.d
)
repo_names=(
	fedora.repo
	fedora-updates.repo
)

for repo_dir in "${repo_dirs[@]}"; do
	[[ -d "$repo_dir" ]] || continue

	for repo_name in "${repo_names[@]}"; do
		repo_path="${repo_dir}/${repo_name}"
		[[ -f "$repo_path" ]] || continue

		sed -i 's/^enabled=0$/enabled=1/g' "$repo_path"
	done
done
