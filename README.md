![Dudley's Second Bedroom](./custom_wallpapers/dudleys-second-bedroom-1.png)

# Dudley's Second Bedroom

A step up from the closet under the stairs, but not quite the Room of Requirement yet.

This [Universal Blue](https://github.com/ublue-os/main) image extends the [Bluefin](https://github.com/ublue-os/bluefin) flavor with personalized modifications - your own space that's better than where you started, but with room to grow into something even better.

## ✨ What's New: Modular Build System

This image uses a **modular build architecture** that makes customization easier and builds faster:

### Key Benefits

- **🔧 Easy to Customize**: Add or modify features by editing modular scripts in `build_files/`
- **⚡ Fast Rebuilds**: Intelligent caching means most changes rebuild in <10 minutes (vs 30+ minutes)
- **✅ Validated**: Automatic validation ensures your customizations are correct before building
- **📦 Organized**: Build modules categorized by function: shared, desktop, developer, user-hooks

### Quick Customization

**Add a package:**
```bash
# Edit packages.json
{
  "all": {
    "install": ["your-package-here"]
  }
}
```

**Add a custom build module:**
```bash
# Create build_files/developer/my-tool.sh
#!/usr/bin/bash
# Script: my-tool.sh
# Purpose: Install my custom tool
# Category: developer
# Dependencies: none
# Parallel-Safe: yes
# ...
```

**Validate and build:**
```bash
just check    # Validate changes
just build    # Build image
```

### Architecture

See [ARCHITECTURE.md](./ARCHITECTURE.md) for complete documentation of the modular build system.

## VS Code Insiders (RPM)

Flatpak Insiders (flathub-beta) is unreliable right now for this workflow, so this image layers the official Microsoft `code-insiders` RPM.

After rebasing:
```bash
code-insiders --version
```

User extensions (Remote Containers, Remote SSH, Remote Repositories, C++ tools pack) are auto-installed on first login via a user setup hook.

If you later want to switch to the Flatpak variant, you can remove the RPM:
```bash
sudo rpm-ostree override remove code-insiders
```
…then install the Flatpak manually.

To pin a specific version, adjust the install script to request `code-insiders-<version>` and rebuild.

## Default Wallpaper & Branding

**Dynamic multi-image wallpaper system** for desktop sessions only:

### How It Works

The build system automatically discovers and installs **any PNG/JPG images** from the `custom_wallpapers/` directory.

**Current wallpapers:**
- `custom_wallpapers/dudleys-second-bedroom-1.png` → Primary desktop background  
- `custom_wallpapers/dudleys-second-bedroom-2.png` → Secondary wallpaper (available for user selection)

### Build Process

1. **Discovery**: Scans `custom_wallpapers/` for `*.png`, `*.jpg`, `*.jpeg` files
2. **Installation**: Copies all found images to `/usr/share/backgrounds/dudley/`  
3. **Schema Override**: Points desktop background to `dudleys-second-bedroom-1.png`
4. **User Hook**: A user-setup hook enforces the branded wallpaper. It now re-applies if settings drift, if its internal version changes, or if you force it.
5. **Login Screen**: Uses default Bluefin branding (no custom wallpaper)

### Adding/Changing Wallpapers

**Simple method:**
1. Add/replace images in `custom_wallpapers/` directory
2. Keep `dudleys-second-bedroom-1.{png|jpg}` as your primary wallpaper
3. Add numbered variants like `dudleys-second-bedroom-3.png`, etc.
4. Rebuild & rebase

**Advanced options:**
- Create XML slideshow definitions for rotating backgrounds
- Modify schema overrides for different light/dark wallpapers
- Add wallpaper categories or themes

Runtime user override (doesn’t modify the image):

```bash
gsettings set org.gnome.desktop.background picture-uri "file:///path/to/custom.png"
```

If removing branding entirely, delete the schema + dconf override files and rebuild.

### Forcing / Re-running the Wallpaper Hook

The hook writes a marker file at `~/.config/.dudley-wallpaper-applied` containing metadata:

```
version=1
uri=file:///usr/share/backgrounds/dudley/dudleys-second-bedroom-1.png
mode=stretched
```

It will automatically re-run if:
- The stored version differs from the script's `MARKER_VERSION`.
- The current `gsettings` picture-uri or picture-options doesn’t match the desired values.
- You export `DUDLEY_WALLPAPER_FORCE=1` for that run.

Manual force (one shot):
```bash
DUDLEY_WALLPAPER_FORCE=1 bash /usr/share/ublue-os/user-setup.hooks.d/20-dudley-wallpaper.sh
```

Reset and reapply cleanly:
```bash
rm -f ~/.config/.dudley-wallpaper-applied
bash /usr/share/ublue-os/user-setup.hooks.d/20-dudley-wallpaper.sh
```

Change mode (example switch to zoom):
```bash
sed -i "s/DESIRED_MODE=\"stretched\"/DESIRED_MODE=\"zoom\"/" /usr/share/ublue-os/user-setup.hooks.d/20-dudley-wallpaper.sh
rm -f ~/.config/.dudley-wallpaper-applied
MARKER_VERSION_BUMP=$(sudo grep -n 'MARKER_VERSION' /usr/share/ublue-os/user-setup.hooks.d/20-dudley-wallpaper.sh | cut -d: -f1)
# (Optionally bump MARKER_VERSION inside script then re-run)
bash /usr/share/ublue-os/user-setup.hooks.d/20-dudley-wallpaper.sh
```

### VS Code Insiders Extensions

VS Code Insiders extensions are automatically installed from the list at `/etc/skel/.config/vscode-extensions.list` on first login. The hook will:
- Install all extensions listed in the file
- Track installation with a version marker in `~/.config/Code - Insiders/.extensions-installed`
- Re-run automatically if the hook version is updated
- Skip installation if already completed

The marker is stored inside the VSCode directory, so if you delete `~/.config/Code - Insiders/`, the extensions will be reinstalled on the next hook run.

Manual force reinstall (deletes marker and reinstalls):
```bash
VSCODE_EXTENSIONS_FORCE=1 bash /usr/share/ublue-os/user-setup.hooks.d/20-vscode-extensions.sh
```

Reset and reapply cleanly:
```bash
rm -f ~/.config/Code\ -\ Insiders/.extensions-installed
bash /usr/share/ublue-os/user-setup.hooks.d/20-vscode-extensions.sh
```

Check which extensions are configured:
```bash
cat /etc/skel/.config/vscode-extensions.list
```

## About This Image

This is a customized Universal Blue OS image that extends `ghcr.io/ublue-os/bluefin:stable` with:

- The System76 COSMIC desktop environment (from the `ryanabx/cosmic-epoch` COPR).
- Developer tooling like `tmux`, `curl`, `gcc-c++`, and the Robocorp `rcc` CLI.
- Additional quality-of-life tweaks tailored for my specific workflow.

## Installation

To switch to this custom image from any bootc-compatible system, run:

```bash
sudo bootc switch ghcr.io/joshyorko/dudleys-second-bedroom:latest
```

After the command completes, reboot your system to boot into the new image.

## Community & Support

- [Universal Blue Forums](https://universal-blue.discourse.group/)
- [Universal Blue Discord](https://discord.gg/WEu6BdFEtp)
- [bootc discussion forums](https://github.com/bootc-dev/bootc/discussions)

# Repository Contents

## Containerfile

The [Containerfile](./Containerfile) defines the operations used to customize the selected image.This file is the entrypoint for your image build, and works exactly like a regular podman Containerfile. For reference, please see the [Podman Documentation](https://docs.podman.io/en/latest/Introduction.html).

## build.sh

The [build.sh](./build_files/build.sh) file is called from your Containerfile. It is the best place to install new packages or make any other customization to your system. There are customization examples contained within it for your perusal.

## build.yml

The [build.yml](./.github/workflows/build.yml) Github Actions workflow creates your custom OCI image and publishes it to the Github Container Registry (GHCR). By default, the image name will match the Github repository name. There are several environment variables at the start of the workflow which may be of interest to change.

# Building Disk Images

This template provides an out of the box workflow for creating disk images (ISO, qcow, raw) for your custom OCI image which can be used to directly install onto your machines.

This template provides a way to upload the disk images that is generated from the workflow to a S3 bucket. The disk images will also be available as an artifact from the job, if you wish to use an alternate provider. To upload to S3 we use [rclone](https://rclone.org/) which is able to use [many S3 providers](https://rclone.org/s3/).

## Setting Up ISO Builds

The [build-disk.yml](./.github/workflows/build-disk.yml) Github Actions workflow creates a disk image from your OCI image by utilizing the [bootc-image-builder](https://osbuild.org/docs/bootc/). In order to use this workflow you must complete the following steps:

1. Modify `disk_config/iso.toml` to point to your custom container image before generating an ISO image. The default file is tuned for the GNOME variant of this project and already targets `ghcr.io/joshyorko/dudleys-second-bedroom:latest`. If you need a different desktop experience, copy the relevant settings from `disk_config/iso-kde.toml` (or create your own) and update the workflow/Just recipe to point at that file instead.
2. If you changed your image name from the default in `build.yml` then in the `build-disk.yml` file edit the `IMAGE_REGISTRY`, `IMAGE_NAME` and `DEFAULT_TAG` environment variables with the correct values. If you did not make changes, skip this step.
3. Finally, if you want to upload your disk images to S3 then you will need to add your S3 configuration to the repository's Action secrets. This can be found by going to your repository settings, under `Secrets and Variables` -> `Actions`. You will need to add the following
  - `S3_PROVIDER` - Must match one of the values from the [supported list](https://rclone.org/s3/)
  - `S3_BUCKET_NAME` - Your unique bucket name
  - `S3_ACCESS_KEY_ID` - It is recommended that you make a separate key just for this workflow
  - `S3_SECRET_ACCESS_KEY` - See above.
  - `S3_REGION` - The region your bucket lives in. If you do not know then set this value to `auto`.
  - `S3_ENDPOINT` - This value will be specific to the bucket as well.

Once the workflow is done, you'll find the disk images either in your S3 bucket or as part of the summary under `Artifacts` after the workflow is completed.

# Artifacthub

This template comes with the necessary tooling to index your image on [artifacthub.io](https://artifacthub.io). Use the `artifacthub-repo.yml` file at the root to verify yourself as the publisher. This is important to you for a few reasons:

- The value of artifacthub is it's one place for people to index their custom images, and since we depend on each other to learn, it helps grow the community. 
- You get to see your pet project listed with the other cool projects in Cloud Native.
- Since the site puts your README front and center, it's a good way to learn how to write a good README, learn some marketing, finding your audience, etc. 

[Discussion Thread](https://universal-blue.discourse.group/t/listing-your-custom-image-on-artifacthub/6446)

# Justfile Documentation

The `Justfile` contains various commands and configurations for building and managing container images. It uses [just](https://just.systems/man/en/introduction.html), a command runner available by default on all Universal Blue images.

## Environment Variables

- `image_name`: The name of the image (default: "image-template").
- `default_tag`: The default tag for the image (default: "latest").
- `bib_image`: The Bootc Image Builder (BIB) image (default: "quay.io/centos-bootc/bootc-image-builder:latest").

## Validation Commands

### `just check`

Runs all validation checks (syntax, configuration, modules).

### `just lint`

Runs shellcheck on all Bash scripts.

### `just validate-packages`

Validates packages.json against schema and checks for conflicts.

### `just validate-modules`

Validates Build Module metadata and headers.

## Building The Image

### `just build`

Builds a container image using Podman with caching enabled.

```bash
just build $target_image $tag
```

Arguments:
- `$target_image`: The tag you want to apply to the image (default: `$image_name`).
- `$tag`: The tag for the image (default: `$default_tag`).

## File Management

### `just clean`

Cleans the repository by removing build artifacts.

### `just deep-clean`

Cleans build artifacts and removes container images.

## Building and Running Virtual Machines and ISOs

The below commands all build QCOW2 images. To produce or use a different type of image, substitute in the command with that type in the place of `qcow2`. The available types are `qcow2`, `iso`, and `raw`.

### `just build-qcow2`

Builds a QCOW2 virtual machine image.

```bash
just build-qcow2 $target_image $tag
```

### `just rebuild-qcow2`

Rebuilds a QCOW2 virtual machine image.

```bash
just rebuild-vm $target_image $tag
```

### `just run-vm-qcow2`

Runs a virtual machine from a QCOW2 image.

```bash
just run-vm-qcow2 $target_image $tag
```

### `just spawn-vm`

Runs a virtual machine using systemd-vmspawn.

```bash
just spawn-vm rebuild="0" type="qcow2" ram="6G"
```

## File Management

### `just check`

Checks the syntax of all `.just` files and the `Justfile`.

### `just fix`

Fixes the syntax of all `.just` files and the `Justfile`.

### `just clean`

Cleans the repository by removing build artifacts.

### `just lint`

Runs shell check on all Bash scripts.

### `just format`

Runs shfmt on all Bash scripts.

## Community Examples

These are images derived from this template (or similar enough to this template). Reference them when building your image!

- [m2Giles' OS](https://github.com/m2giles/m2os)
- [bOS](https://github.com/bsherman/bos)
- [Homer](https://github.com/bketelsen/homer/)
- [Amy OS](https://github.com/astrovm/amyos)
- [VeneOS](https://github.com/Venefilyn/veneos)
