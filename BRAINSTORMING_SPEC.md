# Dudley's Second Bedroom - Comprehensive Brainstorming & Improvement Spec

> **Inspiration Sources**: [bsherman/bos](https://github.com/bsherman/bos) | [ublue-os/bluefin](https://github.com/ublue-os/bluefin)
> 
> **Date**: October 5, 2025
> 
> **Status**: Living Document - Continuous Improvement Roadmap

---

## 🎯 Project Vision & Philosophy

### Current State Analysis
Your project "Dudley's Second Bedroom" is a personalized Universal Blue image extending Bluefin-DX, representing a pragmatic "step up from the closet" approach - functional but acknowledging room for growth.

### Refined Vision Statement
**Transform "Dudley's Second Bedroom" into a well-architected, maintainable, and professionally-structured custom OS image that balances personal customization with enterprise-grade infrastructure practices.**

Core Principles:
- **Simplicity over Complexity**: Surgical, minimal code changes (Bluefin philosophy)
- **Maintainability First**: Easy to understand, debug, and extend
- **Cloud-Native Infrastructure**: Leverage modern container and CI/CD practices
- **Personal but Professional**: Custom for your needs, structured for reliability
- **Documentation as Code**: Self-documenting through structure and tooling

---

## 🏗️ Architecture & Structure Improvements

### 1. **Adopt Multi-Stage Build Architecture** (Inspired by Bluefin)

**Current State**: Single-stage Containerfile with basic script execution

**Proposed Enhancement**:
```dockerfile
# Stage 1: Context layer (static files)
FROM scratch AS ctx
COPY build_files /build_files
COPY system_files /system_files
COPY custom_wallpapers /custom_wallpapers

# Stage 2: Base customizations
FROM ghcr.io/ublue-os/bluefin-dx:stable AS base
ARG FEDORA_MAJOR_VERSION="41"
ARG IMAGE_NAME="dudleys-second-bedroom"
ARG IMAGE_VENDOR="joshyorko"
ARG VERSION="1.0.0"

RUN --mount=type=bind,from=ctx,src=/,dst=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=cache,dst=/var/cache/rpm-ostree \
    /ctx/build_files/shared/build-base.sh

# Stage 3: Developer enhancements (if needed)
FROM base AS developer
RUN --mount=type=bind,from=ctx,src=/,dst=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    /ctx/build_files/shared/build-developer.sh
```

**Benefits**:
- Layer caching optimization
- Clear separation of concerns
- Ability to create variants (minimal, developer, power-user)
- Reduced build times through mount caching

---

### 2. **Modular Build Script Organization** (Inspired by bOS + Bluefin)

**Current Structure**:
```
build_files/
├── build.sh (monolithic)
├── 20-install-code-insiders-rpm.sh
├── 30-install-action-server.sh
└── 60-user-hook-code-insiders.sh
```

**Proposed Structure** (Hybrid bOS/Bluefin approach):
```
build_files/
├── shared/
│   ├── build-base.sh           # Main orchestrator
│   ├── cleanup.sh              # Aggressive cleanup (from bOS)
│   ├── package-install.sh      # DNF/RPM operations
│   ├── branding.sh             # Wallpapers, themes, icons
│   ├── signing.sh              # Container signing setup
│   └── utils/
│       ├── github-release-install.sh  # Reusable GitHub release fetcher
│       ├── copr-manager.sh            # COPR repo management
│       └── validation.sh              # Pre-flight checks
├── desktop/
│   ├── gnome-customizations.sh
│   ├── fonts-themes.sh
│   └── dconf-defaults.sh
├── developer/
│   ├── vscode-insiders.sh
│   ├── action-server.sh
│   ├── devcontainer-tools.sh
│   └── container-runtimes.sh
└── user-hooks/
    ├── 10-wallpaper-enforcement.sh
    ├── 20-vscode-extensions.sh
    └── 99-first-boot-welcome.sh
```

**Key Improvements**:
- **Separation of Concerns**: Each script has one job
- **Reusability**: Shared utilities can be called from multiple scripts
- **Testing**: Individual scripts can be tested in isolation
- **Clarity**: Self-documenting structure through directory names

---

### 3. **Advanced Cleanup Strategy** (From bOS)

Implement bsherman's aggressive cleanup approach:

**Create** `build_files/shared/cleanup.sh`:
```bash
#!/usr/bin/bash
set -eoux pipefail

# Disable all third-party repos to prevent accidental usage
repos=(
    charm.repo
    docker-ce.repo
    fedora-cisco-openh264.repo
    fedora-updates.repo
    gh-cli.repo
    google-chrome.repo
    tailscale.repo
    vscode.repo
    # Add your repos here
)

for repo in "${repos[@]}"; do
    if [[ -f "/etc/yum.repos.d/$repo" ]]; then
        sed -i 's@enabled=1@enabled=0@g' "/etc/yum.repos.d/$repo"
    fi
done

# Clean all package manager caches
dnf clean all || dnf5 clean all

# Aggressive cleanup (IMPORTANT for image size)
rm -rf /tmp/*
rm -rf /var/tmp/*
rm -rf /var/cache/*
rm -rf /var/log/*

# Commit ostree changes
ostree container commit

# Recreate required directories
mkdir -p /tmp /var/tmp /var/cache /var/log
chmod 1777 /tmp /var/tmp
```

**Benefits**:
- Smaller final image size
- No stale cache data
- Clean slate for users
- Faster downloads

---

## 📦 Package Management Modernization

### 1. **JSON-Based Package Configuration** (Bluefin Approach)

**Create** `packages.json`:
```json
{
  "all": {
    "include": {
      "base": [
        "fastfetch",
        "fish",
        "tmux",
        "curl",
        "git",
        "gcc",
        "make"
      ],
      "developer": [
        "android-tools",
        "podman-compose",
        "podman-tui",
        "docker-ce",
        "docker-ce-cli",
        "containerd.io"
      ],
      "optional": [
        "tailscale",
        "wireguard-tools",
        "rclone"
      ]
    },
    "exclude": {
      "base": [
        "firefox",
        "firefox-langpacks",
        "gnome-software"
      ]
    }
  },
  "41": {
    "include": {
      "base": [
        "google-noto-fonts-all"
      ]
    }
  }
}
```

**Create** `build_files/shared/package-install.sh`:
```bash
#!/usr/bin/bash
set -eoux pipefail

PACKAGES_JSON="/ctx/packages.json"
FEDORA_VERSION=$(rpm -E %fedora)

# Parse and install packages using jq
install_packages() {
    local category=$1
    local version=${2:-all}
    
    # Extract packages from JSON
    packages=$(jq -r \
        ".\"${version}\".include.\"${category}\"[]? // .all.include.\"${category}\"[]?" \
        "${PACKAGES_JSON}")
    
    if [[ -n "${packages}" ]]; then
        echo "Installing ${category} packages for Fedora ${FEDORA_VERSION}..."
        echo "${packages}" | xargs dnf5 install -y
    fi
}

# Remove excluded packages
remove_packages() {
    excluded=$(jq -r \
        ".all.exclude.base[]? // empty" \
        "${PACKAGES_JSON}")
    
    if [[ -n "${excluded}" ]]; then
        echo "Removing excluded packages..."
        echo "${excluded}" | xargs rpm-ostree override remove --install=- || true
    fi
}

# Execute
install_packages "base"
install_packages "developer"
remove_packages
```

**Benefits**:
- Centralized package management
- Version-specific package control
- Easy to review package changes in git diffs
- Programmatic validation possible

---

### 2. **Reusable GitHub Release Installer** (From bOS)

**Create** `build_files/shared/utils/github-release-install.sh`:
```bash
#!/usr/bin/bash
# Flexible GitHub release installer
# Usage: github-release-install.sh OWNER REPO PATTERN INSTALL_PATH

set -eou pipefail

OWNER="${1}"
REPO="${2}"
PATTERN="${3}"
INSTALL_PATH="${4:-/usr/local/bin}"

LATEST_URL="https://api.github.com/repos/${OWNER}/${REPO}/releases/latest"
DOWNLOAD_URL=$(curl -s "${LATEST_URL}" | \
    jq -r ".assets[] | select(.name | contains(\"${PATTERN}\")) | .browser_download_url" | \
    head -n1)

if [[ -z "${DOWNLOAD_URL}" ]]; then
    echo "ERROR: Could not find asset matching '${PATTERN}'"
    exit 1
fi

TEMP_FILE=$(mktemp)
curl -sL "${DOWNLOAD_URL}" -o "${TEMP_FILE}"

# Handle different file types
case "${DOWNLOAD_URL}" in
    *.tar.gz|*.tgz)
        tar -xzf "${TEMP_FILE}" -C "${INSTALL_PATH}"
        ;;
    *.zip)
        unzip -q "${TEMP_FILE}" -d "${INSTALL_PATH}"
        ;;
    *)
        # Assume it's a binary
        FILENAME=$(basename "${DOWNLOAD_URL}")
        mv "${TEMP_FILE}" "${INSTALL_PATH}/${FILENAME}"
        chmod +x "${INSTALL_PATH}/${FILENAME}"
        ;;
esac

rm -f "${TEMP_FILE}"
echo "✓ Installed ${OWNER}/${REPO} from ${DOWNLOAD_URL}"
```

**Example Usage**:
```bash
# Install latest Just binary
/ctx/build_files/shared/utils/github-release-install.sh \
    casey just "x86_64-unknown-linux-musl.tar.gz" /usr/local/bin

# Install latest gum
/ctx/build_files/shared/utils/github-release-install.sh \
    charmbracelet gum "linux_amd64.tar.gz" /usr/local/bin
```

---

## 🎨 Branding & User Experience

### 1. **GNOME Extensions** (From Bluefin Tips & Tricks)

Following the Bluefin maintainer recommendations, these GNOME extensions enhance the desktop experience:

**Essential Extensions**:
- [Just Perfection](https://extensions.gnome.org/extension/3843/just-perfection/) - Comprehensive configuration options
- [Tiling Shell](https://extensions.gnome.org/extension/7065/tiling-shell/) - Recommended tiling extension
- [Night Theme Switcher](https://extensions.gnome.org/extension/2236/night-theme-switcher/) - Automatic dark/light mode
- [Wiggle](https://extensions.gnome.org/extension/6784/wiggle/) - Find your cursor easily
- [Clipboard Indicator](https://extensions.gnome.org/extension/779/clipboard-indicator/) - Clipboard history

**Audio & Devices**:
- [Quick Settings Audio Hider](https://extensions.gnome.org/extension/5964/quick-settings-audio-devices-hider/)
- [Quick Settings Audio Renamer](https://extensions.gnome.org/extension/6000/quick-settings-audio-devices-renamer/)
- [Bluetooth Battery Meter](https://extensions.gnome.org/extension/6670/bluetooth-battery-meter/)
- [Battery Health Charging](https://github.com/maniacx/Battery-Health-Charging)

**Hardware Control**:
- [Control monitor brightness and volume with ddcutil](https://extensions.gnome.org/extension/6325/control-monitor-brightness-and-volume-with-ddcutil/)

**Installation Method**:
```bash
# Add to build_files/desktop/gnome-extensions.sh
gnome-extensions install just-perfection@gnome-shell-extensions.gcampax.github.com
gnome-extensions install tilingshell@ferrarodomenico.com
# ... etc
```

### 2. **VS Code Insiders Extensions** (Current Installation)

Based on your current VS Code Insiders setup, these extensions should be installed:

**Theme & UI**:
- `catppuccin.catppuccin-vsc` - Catppuccin color theme
- `catppuccin.catppuccin-vsc-icons` - Catppuccin icon theme
- `s-nlf-fh.glassit` - Window transparency

**AI & Copilot**:
- `github.copilot` - GitHub Copilot AI assistant
- `github.copilot-chat` - Copilot chat interface
- `ms-vscode.vscode-websearchforcopilot` - Web search for Copilot

**Remote Development**:
- `ms-vscode-remote.remote-containers` - Dev Containers support
- `ms-vscode-remote.remote-ssh` - Remote SSH development
- `ms-vscode-remote.remote-ssh-edit` - SSH configuration editing
- `ms-vscode.remote-explorer` - Remote connection explorer
- `ms-vscode.remote-repositories` - GitHub repository browsing
- `github.remotehub` - GitHub remote editing

**GitHub & Version Control**:
- `github.vscode-github-actions` - GitHub Actions workflows
- `github.vscode-pull-request-github` - GitHub PR management
- `github.codespaces` - GitHub Codespaces
- `ms-vscode.azure-repos` - Azure Repos

**Python Development**:
- `ms-python.python` - Python language support
- `ms-python.vscode-pylance` - Python language server
- `ms-python.debugpy` - Python debugger
- `ms-python.vscode-python-envs` - Python environment manager
- `ms-python.black-formatter` - Black code formatter

**Jupyter & Data Science**:
- `ms-toolsai.jupyter` - Jupyter notebook support
- `ms-toolsai.jupyter-keymap` - Jupyter keybindings
- `ms-toolsai.jupyter-renderers` - Jupyter output renderers
- `ms-toolsai.vscode-jupyter-cell-tags` - Cell tagging
- `ms-toolsai.vscode-jupyter-slideshow` - Slideshow support
- `ms-toolsai.datawrangler` - Data wrangler tool

**C/C++ Development**:
- `ms-vscode.cpptools` - C/C++ IntelliSense
- `ms-vscode.cpptools-extension-pack` - C++ tool bundle
- `ms-vscode.cpptools-themes` - C++ syntax themes
- `ms-vscode.cmake-tools` - CMake integration

**Containers & Docker**:
- `docker.docker` - Docker integration
- `ms-azuretools.vscode-containers` - Container management

**Robocorp/Automation**:
- `robocorp.robocorp-code` - Robocorp development tools
- `sema4ai.sema4ai` - Sema4.ai integration

**Utilities**:
- `mechatroner.rainbow-csv` - CSV file colorization
- `tomoki1207.pdf` - PDF viewer
- `ms-vscode.live-server` - Live development server
- `ms-vscode.vscode-speech` - Speech recognition

**Update** `build_files/60-user-hook-code-insiders.sh` with your extension list:
```bash
EXTENSIONS=( \
  # Core Remote Development
  ms-vscode-remote.remote-containers \
  ms-vscode-remote.remote-ssh \
  ms-vscode-remote.remote-ssh-edit \
  ms-vscode.remote-explorer \
  ms-vscode.remote-repositories \
  github.remotehub \
  
  # AI & Copilot
  github.copilot \
  github.copilot-chat \
  ms-vscode.vscode-websearchforcopilot \
  
  # GitHub Integration
  github.vscode-github-actions \
  github.vscode-pull-request-github \
  github.codespaces \
  ms-vscode.azure-repos \
  
  # Python Stack
  ms-python.python \
  ms-python.vscode-pylance \
  ms-python.debugpy \
  ms-python.vscode-python-envs \
  ms-python.black-formatter \
  
  # Jupyter/Data Science
  ms-toolsai.jupyter \
  ms-toolsai.jupyter-keymap \
  ms-toolsai.jupyter-renderers \
  ms-toolsai.vscode-jupyter-cell-tags \
  ms-toolsai.vscode-jupyter-slideshow \
  ms-toolsai.datawrangler \
  
  # C/C++ Development
  ms-vscode.cpptools \
  ms-vscode.cpptools-extension-pack \
  ms-vscode.cpptools-themes \
  ms-vscode.cmake-tools \
  
  # Containers
  docker.docker \
  ms-azuretools.vscode-containers \
  
  # Robocorp/Automation
  robocorp.robocorp-code \
  sema4ai.sema4ai \
  
  # Themes & UI
  catppuccin.catppuccin-vsc \
  catppuccin.catppuccin-vsc-icons \
  s-nlf-fh.glassit \
  
  # Utilities
  mechatroner.rainbow-csv \
  tomoki1207.pdf \
  ms-vscode.live-server \
  ms-vscode.vscode-speech \
)
install_extension "ms-vscode-remote.remote-ssh"            # Remote SSH
install_extension "ms-vscode.remote-repositories"          # Remote Repositories
install_extension "ms-vscode.cpptools-extension-pack"      # C++ tools

# AI & Productivity
install_extension "GitHub.copilot"                         # GitHub Copilot
install_extension "GitHub.copilot-chat"                    # Copilot Chat
install_extension "Tabnine.tabnine-vscode"                 # Tabnine AI

# Git & Version Control
install_extension "eamodio.gitlens"                        # GitLens
install_extension "GitHub.vscode-pull-request-github"      # GitHub PR

# Language Support
install_extension "ms-python.python"                       # Python
install_extension "ms-python.vscode-pylance"               # Pylance
install_extension "ms-vscode.cpptools"                     # C/C++
install_extension "rust-lang.rust-analyzer"                # Rust
install_extension "golang.go"                              # Go
install_extension "ms-vscode.vscode-typescript-next"       # TypeScript

# Web Development
install_extension "dbaeumer.vscode-eslint"                 # ESLint
install_extension "esbenp.prettier-vscode"                 # Prettier
install_extension "bradlc.vscode-tailwindcss"              # Tailwind CSS
install_extension "ritwickdey.LiveServer"                  # Live Server

# Docker & Containers
install_extension "ms-azuretools.vscode-docker"            # Docker
install_extension "ms-kubernetes-tools.vscode-kubernetes-tools" # Kubernetes

# Markdown & Documentation
install_extension "yzhang.markdown-all-in-one"             # Markdown All in One
install_extension "DavidAnson.vscode-markdownlint"         # Markdown Lint

# Code Quality
install_extension "usernamehw.errorlens"                   # Error Lens
install_extension "streetsidesoftware.code-spell-checker"  # Spell Checker
install_extension "wix.vscode-import-cost"                 # Import Cost

# Productivity
install_extension "formulahendry.auto-rename-tag"          # Auto Rename Tag
install_extension "formulahendry.auto-close-tag"           # Auto Close Tag
install_extension "christian-kohler.path-intellisense"     # Path Intellisense
install_extension "PKief.material-icon-theme"              # Material Icon Theme
install_extension "zhuangtongfa.material-theme"            # Material Theme

# Testing
install_extension "hbenl.vscode-test-explorer"             # Test Explorer
install_extension "ms-vscode.test-adapter-converter"       # Test Adapter

# Utilities
install_extension "albert.TabOut"                          # Tab Out
install_extension "usernamehw.commands"                    # Commands
install_extension "aaron-bond.better-comments"             # Better Comments

echo "✓ VS Code extensions installed"
```

**Update user hook** `build_files/user-hooks/20-vscode-extensions.sh`:
```bash
#!/usr/bin/bash
# Auto-install VS Code extensions on first login

MARKER_FILE="${HOME}/.config/.dudley-vscode-extensions-installed"
EXTENSION_LIST=(
    "ms-vscode-remote.remote-containers"
    "ms-vscode-remote.remote-ssh"
    "GitHub.copilot"
    "eamodio.gitlens"
    "ms-python.python"
    "ms-azuretools.vscode-docker"
)

if [[ -f "${MARKER_FILE}" ]]; then
    exit 0
fi

echo "Installing VS Code extensions for first-time setup..."

for ext in "${EXTENSION_LIST[@]}"; do
    code-insiders --install-extension "${ext}" || true
done

touch "${MARKER_FILE}"
echo "version=1" > "${MARKER_FILE}"
echo "✓ VS Code extensions configured"
```

### 3. **Dynamic Wallpaper System Enhancement**

**Current**: Basic wallpaper detection and installation

**Proposed**: XML-based slideshow with time-of-day transitions

**Create** `system_files/shared/usr/share/backgrounds/dudley/dudleys-slideshow.xml`:
```xml
<background>
  <starttime>
    <year>2024</year>
    <month>1</month>
    <day>1</day>
    <hour>0</hour>
    <minute>0</minute>
    <second>0</second>
  </starttime>
  
  <!-- Morning (6:00-12:00) -->
  <static>
    <duration>21600.0</duration>
    <file>/usr/share/backgrounds/dudley/morning.png</file>
  </static>
  
  <!-- Afternoon (12:00-18:00) -->
  <static>
    <duration>21600.0</duration>
    <file>/usr/share/backgrounds/dudley/afternoon.png</file>
  </static>
  
  <!-- Evening (18:00-24:00) -->
  <static>
    <duration>21600.0</duration>
    <file>/usr/share/backgrounds/dudley/evening.png</file>
  </static>
  
  <!-- Night (0:00-6:00) -->
  <static>
    <duration>21600.0</duration>
    <file>/usr/share/backgrounds/dudley/night.png</file>
  </static>
</background>
```

**Update** `system_files/shared/usr/share/glib-2.0/schemas/zz0-dudley-background.gschema.override`:
```ini
[org.gnome.desktop.background]
picture-uri='file:///usr/share/backgrounds/dudley/dudleys-slideshow.xml'
picture-uri-dark='file:///usr/share/backgrounds/dudley/dudleys-slideshow.xml'
picture-options='zoom'

[org.gnome.desktop.screensaver]
picture-uri='file:///usr/share/backgrounds/dudley/dudleys-second-bedroom-1.png'
```

---

### 2. **Welcome Screen & First Boot Experience**

**Create** `build_files/user-hooks/99-first-boot-welcome.sh`:
```bash
#!/usr/bin/bash
# First boot welcome message and configuration

MARKER_FILE="${HOME}/.config/.dudley-first-boot-complete"

if [[ -f "${MARKER_FILE}" ]]; then
    exit 0
fi

# Display welcome message
cat << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║      Welcome to Dudley's Second Bedroom! 🏠              ║
║                                                           ║
║  Your custom Universal Blue desktop is ready.            ║
║                                                           ║
║  Quick Start:                                            ║
║    • VS Code Insiders is installed (code-insiders)      ║
║    • Developer tools available via `just`                ║
║    • Check updates: rpm-ostree status                    ║
║                                                           ║
║  Documentation: ~/.local/share/dudley/README.md          ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF

# Create local documentation
mkdir -p "${HOME}/.local/share/dudley"
cat > "${HOME}/.local/share/dudley/README.md" << 'DOCS'
# Dudley's Second Bedroom - User Guide

## What's Installed

### Development Tools
- VS Code Insiders (RPM version)
- Robocorp Action Server
- Docker CE
- Podman

### System Tools
- `just` - Command runner
- `tmux` - Terminal multiplexer
- Modern CLI tools (fastfetch, gum, etc.)

## Useful Commands

```bash
# Update your system
rpm-ostree upgrade

# Check system status
rpm-ostree status

# Rollback to previous version
rpm-ostree rollback

# List all just recipes
just --list

# VS Code Insiders
code-insiders
```

## Troubleshooting

If extensions aren't loading in VS Code:
```bash
code-insiders --install-extension ms-vscode-remote.remote-containers
```

## Customization

Edit wallpaper: Settings → Background
Change themes: Extensions → Themes

For more help, check: https://github.com/joshyorko/dudleys-second-bedroom
DOCS

# Mark as complete
touch "${MARKER_FILE}"
echo "version=1" > "${MARKER_FILE}"
echo "date=$(date -Iseconds)" >> "${MARKER_FILE}"
```

---

## 🔧 Development & Maintenance Tools

### 1. **Comprehensive Justfile** (Hybrid bOS/Bluefin)

**Enhance** `Justfile` with bsherman's patterns:

```just
# Dudley's Second Bedroom - Build & Development Tools
# Inspired by bOS and Bluefin

# Configuration
repo_image_name := "dudleys-second-bedroom"
repo_name := "joshyorko"
default_tag := "latest"

# Image variants configuration
images := '(
    [base]="bluefin-dx:stable"
    [developer]="bluefin-dx:latest"
    [nvidia]="bluefin-dx-nvidia:stable"
)'

# Detect sudo requirements
export SUDOIF := if `id -u` == "0" { "" } else { "sudo" }
export PODMAN := if path_exists("/usr/bin/podman") == "true" { "podman" } else { "docker" }

# Default command: list all recipes
[private]
default:
    @just --list

# ============================================
# Validation & Quality Control
# ============================================

# Check syntax of all Just files
[group('Validation')]
check:
    #!/usr/bin/env bash
    echo "Checking Justfile syntax..."
    just --unstable --fmt --check -f Justfile
    
    echo "Checking JSON files..."
    python3 -c "import json; json.load(open('packages.json'))"
    
    echo "Running pre-commit checks..."
    pre-commit run --all-files || true

# Fix formatting issues
[group('Validation')]
fix:
    just --unstable --fmt -f Justfile
    pre-commit run --all-files || true

# Lint all shell scripts
[group('Validation')]
lint:
    #!/usr/bin/env bash
    find build_files -name "*.sh" -exec shellcheck {} \;

# ============================================
# Build Operations
# ============================================

# Build container image
[group('Build')]
build variant="base" tag=default_tag:
    #!/usr/bin/env bash
    set -eoux pipefail
    
    echo "Building {{ repo_image_name }}:{{ variant }}"
    
    BUILD_ARGS=(
        "--file" "Containerfile"
        "--tag" "localhost/{{ repo_image_name }}:{{ tag }}"
        "--label" "org.opencontainers.image.title={{ repo_image_name }}"
        "--label" "org.opencontainers.image.version={{ tag }}"
        "--build-arg" "IMAGE_NAME={{ repo_image_name }}"
        "--build-arg" "IMAGE_VENDOR={{ repo_name }}"
    )
    
    {{ PODMAN }} build "${BUILD_ARGS[@]}" .

# Build with cache busting
[group('Build')]
rebuild variant="base" tag=default_tag:
    just clean
    just build {{ variant }} {{ tag }}

# ============================================
# Image Management
# ============================================

# Push image to registry
[group('Image')]
push tag=default_tag:
    {{ PODMAN }} push localhost/{{ repo_image_name }}:{{ tag }} \
        ghcr.io/{{ repo_name }}/{{ repo_image_name }}:{{ tag }}

# Tag image
[group('Image')]
tag old_tag new_tag:
    {{ PODMAN }} tag \
        localhost/{{ repo_image_name }}:{{ old_tag }} \
        localhost/{{ repo_image_name }}:{{ new_tag }}

# List local images
[group('Image')]
images:
    {{ PODMAN }} images | grep {{ repo_image_name }}

# ============================================
# ISO Building
# ============================================

# Build bootable ISO
[group('ISO')]
build-iso variant="base" ghcr="0":
    #!/usr/bin/env bash
    set -eoux pipefail
    
    mkdir -p {{ repo_image_name }}_build/output
    
    # Use local or remote image
    if [[ "{{ ghcr }}" == "1" ]]; then
        IMAGE="ghcr.io/{{ repo_name }}/{{ repo_image_name }}:{{ variant }}"
        {{ PODMAN }} pull "${IMAGE}"
    else
        IMAGE="localhost/{{ repo_image_name }}:{{ variant }}"
    fi
    
    # Build ISO using bootc-image-builder
    {{ SUDOIF }} {{ PODMAN }} run --rm --privileged \
        --pull=newer \
        --security-opt label=disable \
        -v "$(pwd)/{{ repo_image_name }}_build:/output" \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        ghcr.io/osbuild/bootc-image-builder:latest \
        --type iso \
        --output /output \
        "${IMAGE}"

# ============================================
# Testing & Validation
# ============================================

# Run tests in container
[group('Testing')]
test:
    #!/usr/bin/env bash
    {{ PODMAN }} run --rm -it \
        localhost/{{ repo_image_name }}:latest \
        /bin/bash -c "
            echo 'Testing VS Code Insiders...'
            code-insiders --version
            
            echo 'Testing Action Server...'
            action-server --version
            
            echo 'Testing Just...'
            just --version
            
            echo 'All tests passed!'
        "

# ============================================
# Cleanup & Maintenance
# ============================================

# Clean build artifacts
[group('Cleanup')]
clean:
    #!/usr/bin/env bash
    set -x
    rm -rf {{ repo_image_name }}_build
    rm -f output*.env changelog*.md version.txt
    {{ PODMAN }} system prune -f

# Deep clean including images
[group('Cleanup')]
deep-clean:
    just clean
    {{ PODMAN }} rmi -f $({{ PODMAN }} images -q {{ repo_image_name }}) || true
    {{ PODMAN }} system prune -af --volumes

# ============================================
# Developer Shortcuts
# ============================================

# Quick build and test cycle
[group('Developer')]
dev:
    just check
    just build
    just test

# Full release workflow
[group('Developer')]
release tag:
    just check
    just rebuild base {{ tag }}
    just push {{ tag }}
    just build-iso base 1
```

---

### 2. **CI/CD Pipeline Enhancements**

**Create** `.github/copilot-instructions.md` (Proper Location!):

```markdown
# Dudley's Second Bedroom - Copilot Instructions

## Project Overview

Custom Universal Blue image extending Bluefin-DX with personal development tools and customizations.

**Type**: Container-based immutable Linux distribution
**Base**: ghcr.io/ublue-os/bluefin-dx:stable
**Registry**: ghcr.io/joshyorko/dudleys-second-bedroom

## Quick Start

### Prerequisites (ALWAYS CHECK FIRST)
```bash
# Install Just (if not available)
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | \
    bash -s -- --to ~/.local/bin

# Validate environment
podman --version || docker --version
python3 -c "import json"
pre-commit --version || pip install pre-commit
```

### Essential Commands
```bash
# 1. Validate before any changes
just check && pre-commit run --all-files

# 2. Build image (30-60 minutes, 20GB+ disk)
just build base latest

# 3. Test locally
just test

# 4. Clean artifacts
just clean
```

## Repository Structure

```
├── Containerfile              # Multi-stage build definition
├── Justfile                   # Build automation (33KB)
├── packages.json              # Package management
├── build_files/               # Modular build scripts
│   ├── shared/               # Common utilities
│   ├── desktop/              # Desktop customizations  
│   └── developer/            # Dev tool installations
├── system_files/             # Static system files
│   └── shared/
│       ├── etc/              # System configurations
│       └── usr/              # User-space files
└── custom_wallpapers/        # Branding assets
```

## Common Tasks

### Adding Packages
1. Edit `packages.json`:
```json
{
  "all": {
    "include": {
      "base": ["new-package"]
    }
  }
}
```
2. Validate: `python3 -c "import json; json.load(open('packages.json'))"`
3. Test build (if critical change)

### Modifying Build Scripts
1. Edit relevant script in `build_files/`
2. Run `just lint` to check syntax
3. Test: `just rebuild`

### Changing Branding
1. Replace files in `custom_wallpapers/`
2. Keep `dudleys-second-bedroom-1.png` as primary
3. Rebuild: `just build`

## Validation Pipeline

**ALWAYS run before committing:**
```bash
just check                           # Validates Just syntax
pre-commit run --all-files          # Runs all hooks
python3 -c "import json; json.load(open('packages.json'))"  # Validates JSON
```

**Known Issues**:
- `.devcontainer.json` will fail JSON validation (contains comments) - this is expected

## Build Guidelines

1. **Avoid full builds** unless testing container changes
2. **Container builds require**: 20GB+ disk, 8GB+ RAM, 30+ minutes
3. **Use `just clean`** to reset state if issues arise
4. **Test locally** before pushing to CI/CD

## Critical Files

- `Containerfile` - Build instructions (edit carefully)
- `build_files/shared/build-base.sh` - Main orchestrator
- `packages.json` - Package definitions
- `system_files/` - User-facing configurations

## Maintenance Philosophy

- **Surgical changes**: Minimal, focused modifications
- **Self-documenting**: Structure conveys intent
- **Test locally**: Validate before CI/CD
- **Clean commits**: Conventional commits enforced

## Getting Help

- Issues: https://github.com/joshyorko/dudleys-second-bedroom/issues
- Universal Blue: https://universal-blue.discourse.group/
- Base Image: https://github.com/ublue-os/bluefin

---

**Trust these instructions.** Only search for additional information if:
- Instructions incomplete for your task
- Encountering undocumented errors
- Repository structure changed significantly
```

**Update** `.github/workflows/build.yml` to use the Justfile:

```yaml
name: Build Custom Image

on:
  push:
    branches:
      - main
  pull_request:
  workflow_dispatch:

env:
  IMAGE_REGISTRY: ghcr.io/${{ github.repository_owner }}
  IMAGE_NAME: dudleys-second-bedroom

jobs:
  validate:
    name: Validate Code
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install Just
        uses: extractions/setup-just@v2
      
      - name: Install Pre-commit
        run: pip install pre-commit
      
      - name: Run Validation
        run: |
          just check
          pre-commit run --all-files || true
      
      - name: Validate JSON
        run: |
          python3 -c "import json; json.load(open('packages.json'))"

  build:
    name: Build Container Image
    needs: validate
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write
    steps:
      - uses: actions/checkout@v4
      
      - name: Install Just
        uses: extractions/setup-just@v2
      
      - name: Build Image
        run: |
          just build base ${{ github.sha }}
      
      - name: Run Tests
        run: |
          just test
      
      - name: Push to Registry
        if: github.ref == 'refs/heads/main'
        run: |
          echo "${{ secrets.GITHUB_TOKEN }}" | \
            docker login ghcr.io -u ${{ github.actor }} --password-stdin
          
          just push ${{ github.sha }}
          just tag ${{ github.sha }} latest
          just push latest
      
      - name: Sign Image
        if: github.ref == 'refs/heads/main'
        uses: sigstore/cosign-installer@v3
      
      - name: Sign Container
        if: github.ref == 'refs/heads/main'
        run: |
          cosign sign --yes \
            ${{ env.IMAGE_REGISTRY }}/${{ env.IMAGE_NAME }}:latest
```

---

## 📚 Documentation Strategy

### 1. **Self-Documenting Project Structure**

**Create** `ARCHITECTURE.md`:
```markdown
# Architecture Documentation

## Overview
Dudley's Second Bedroom follows a modular, cloud-native architecture inspired by Bluefin and bOS.

## Build Stages

### Stage 1: Context Layer
- Purpose: Provide static files without bloating final image
- Contents: Build scripts, system files, wallpapers
- Technology: Multi-stage Docker build with `FROM scratch`

### Stage 2: Base Customizations
- Purpose: Core system modifications
- Includes: Package installation, system configuration, branding
- Caching: Uses BuildKit mount caching for faster rebuilds

### Stage 3: Cleanup
- Purpose: Minimize final image size
- Actions: Remove package caches, temp files, disabled repos
- Result: Lean, production-ready image

## Script Organization

```
build_files/
├── shared/           # Cross-cutting concerns
├── desktop/          # Desktop environment tweaks
├── developer/        # Development tooling
└── user-hooks/       # First-boot user configuration
```

## Package Management
- Centralized in `packages.json`
- Version-specific overrides supported
- Automated validation in CI/CD

## Quality Assurance
1. Pre-commit hooks (syntax validation)
2. Just syntax checking
3. JSON validation
4. Shell script linting
5. Container image testing

## Release Process
1. Local validation (`just check`)
2. Local build (`just build`)
3. Local testing (`just test`)
4. Push to main branch
5. CI/CD builds and signs image
6. ISO generation (optional)
```

### 2. **Inline Documentation Standards**

**All build scripts should follow**:
```bash
#!/usr/bin/bash
# Script: package-install.sh
# Purpose: Install packages from packages.json
# Dependencies: jq, dnf5/dnf
# Usage: Called by build-base.sh during container build
# Author: Josh Yorko
# Last Updated: 2025-10-05

set -eoux pipefail  # Exit on error, undefined vars, pipe failures

# Configuration
readonly PACKAGES_JSON="/ctx/packages.json"
readonly FEDORA_VERSION=$(rpm -E %fedora)
readonly DNF_CMD="${DNF:-dnf5}"

# Function: install_packages
# Description: Install packages for given category from JSON
# Arguments: $1 - category (base|developer|optional)
#            $2 - version (optional, defaults to 'all')
install_packages() {
    local category=$1
    local version=${2:-all}
    
    # ... implementation ...
}

# Main execution
main() {
    echo "::group::Installing Packages"
    install_packages "base"
    install_packages "developer"
    echo "::endgroup::"
}

main "$@"
```

---

## 🔐 Security & Signing

### 1. **Container Signing Setup** (From bOS)

**Create** `build_files/shared/signing.sh`:
```bash
#!/usr/bin/bash
# Setup container signature verification

set -eoux pipefail

# Install cosign public key for verification
if [[ ! -f "/etc/pki/containers/dudleys-second-bedroom.pub" ]]; then
    mkdir -p /etc/pki/containers
    cp /ctx/cosign.pub /etc/pki/containers/dudleys-second-bedroom.pub
fi

# Configure policy.json for signature verification
if [[ ! -f "/etc/containers/policy.json.d/dudleys-second-bedroom.json" ]]; then
    mkdir -p /etc/containers/policy.json.d
    
    cat > /etc/containers/policy.json.d/dudleys-second-bedroom.json << 'EOF'
{
  "default": [{"type": "insecureAcceptAnything"}],
  "transports": {
    "docker": {
      "ghcr.io/joshyorko/dudleys-second-bedroom": [
        {
          "type": "sigstoreSigned",
          "keyPath": "/etc/pki/containers/dudleys-second-bedroom.pub",
          "signedIdentity": {
            "type": "matchRepository"
          }
        }
      ]
    }
  }
}
EOF
fi

echo "✓ Container signing configured"
```

---

## 🚀 Quick Wins - Immediate Improvements

### Priority 1: Organization & Cleanup
- [ ] Reorganize `build_files/` into modular structure
- [ ] Implement aggressive cleanup script from bOS
- [ ] Add `packages.json` for centralized package management
- [ ] Move Copilot instructions to proper location

### Priority 2: Build Optimization
- [ ] Add multi-stage Containerfile with mount caching
- [ ] Implement layer caching strategies
- [ ] Add rechunking support (from bOS) for smaller updates

### Priority 3: Developer Experience
- [ ] Enhance Justfile with comprehensive recipes
- [ ] Add validation scripts (lint, format, check)
- [ ] Create first-boot welcome script
- [ ] Add inline documentation to all scripts

### Priority 4: CI/CD
- [ ] Update GitHub Actions to use Justfile
- [ ] Add automated testing stage
- [ ] Implement image signing with cosign
- [ ] Add changelog generation (from bOS)

### Priority 5: Documentation
- [ ] Create ARCHITECTURE.md
- [ ] Add inline script documentation
- [ ] Update README with new structure
- [ ] Document recovery procedures

---

## 🎯 Long-Term Vision

### Phase 1: Foundation (Current → 1 month)
- Restructure project with modular architecture
- Implement all "Quick Wins"
- Establish documentation standards
- Set up proper CI/CD pipeline

### Phase 2: Refinement & Optimization (1-3 months)
- Fine-tune package selections based on usage
- Optimize build times and caching strategies
- Implement rechunking for smaller updates
- Add advanced branding features (time-of-day wallpapers, custom themes)
- Enhance user-hooks for better first-boot experience

### Phase 3: Automation (3-6 months)
- Automated dependency updates (Renovate)
- Automated security scanning
- Automated ISO generation
- Release automation
- Automatic changelog generation

### Phase 4: Polish & Sustainability (6+ months)
- Comprehensive documentation site
- Recovery and troubleshooting guides
- Performance monitoring and metrics
- Long-term maintenance automation
- Backup and disaster recovery procedures

---

## 🔍 Comparison Matrix

| Feature | Current | bOS | Bluefin | Proposed |
|---------|---------|-----|---------|----------|
| **Build Organization** | Single script | Modular scripts | Highly modular | Hybrid modular |
| **Package Management** | Inline scripts | Inline scripts | JSON-based | JSON-based |
| **Cleanup Strategy** | Basic | Aggressive | Aggressive | Aggressive |
| **Variants** | Single | 12+ variants | Multiple | Single (personal) |
| **Documentation** | Good README | Minimal | Comprehensive | Enhanced |
| **CI/CD** | Basic | Advanced | Enterprise | Advanced |
| **Testing** | Manual | Automated | Automated | Automated |
| **Image Size** | Medium | Small | Medium | Small |
| **Build Time** | 30-45 min | 30-60 min | 45-90 min | 30-60 min |
| **Caching** | Basic | Advanced | Advanced | Advanced |
| **Signing** | Yes | Yes | Yes | Yes |

---

## 📝 Implementation Checklist

### Week 1: Foundation
- [ ] Create new directory structure
- [ ] Migrate existing scripts to modular format
- [ ] Create `packages.json`
- [ ] Update Containerfile to multi-stage
- [ ] Test local builds

### Week 2: Tooling
- [ ] Enhance Justfile with all recipes
- [ ] Add validation scripts
- [ ] Implement cleanup.sh
- [ ] Create developer utilities
- [ ] Document all changes

### Week 3: CI/CD
- [ ] Update GitHub Actions workflows
- [ ] Add automated testing
- [ ] Implement signing workflow
- [ ] Test ISO generation
- [ ] Set up automated releases

### Week 4: Polish & Documentation
- [ ] Create ARCHITECTURE.md
- [ ] Update README with new features
- [ ] Add inline documentation to scripts
- [ ] Create user welcome experience
- [ ] Final testing and validation

---

## 🎨 Copilot Instructions Placement

**IMPORTANT**: The Bluefin team put `copilot-instructions.md` in `.github/` directory, but the proper location per GitHub Copilot documentation is:

**Correct Location**: `.github/copilot-instructions.md` ✓ (what Bluefin did)
**Alternative**: `.copilot/instructions.md` or root level

The Bluefin placement is actually correct for repository-level instructions. For workspace-level instructions in VS Code, you'd use `.github/copilot-instructions.md` for repository context.

---

## 🔗 Resources & References

### Inspiration Projects
- [bsherman/bos](https://github.com/bsherman/bos) - Excellent modular structure and cleanup
- [ublue-os/bluefin](https://github.com/ublue-os/bluefin) - Enterprise-grade build system
- [Universal Blue Main](https://github.com/ublue-os/main) - Foundation patterns

### Documentation
- [Bluefin Copilot Instructions](https://github.com/ublue-os/bluefin/blob/main/.github/copilot-instructions.md)
- [bOS Justfile](https://github.com/bsherman/bos/blob/main/Justfile)
- [Universal Blue Discourse](https://universal-blue.discourse.group/)

### Tools
- [Just Command Runner](https://just.systems/)
- [Bootc Image Builder](https://osbuild.org/docs/bootc/)
- [Cosign](https://docs.sigstore.dev/cosign/overview/)
- [Pre-commit](https://pre-commit.com/)

---

## 💡 Final Thoughts

Your project "Dudley's Second Bedroom" has a solid foundation. By adopting:

1. **bOS's modular architecture** (clean separation of concerns)
2. **Bluefin's enterprise patterns** (JSON package management, comprehensive CI/CD)
3. **Aggressive cleanup** (smaller images, faster downloads)
4. **Proper documentation** (self-documenting structure, inline comments)

You'll transform it from "a step up from the closet" into a well-architected, maintainable, and professional custom OS image that:

- **Builds faster** (caching optimization)
- **Downloads faster** (smaller images)
- **Updates faster** (rechunking support)
- **Maintains easier** (modular, testable code)
- **Extends easier** (clear patterns, good docs)
- **Scales better** (variants, automation)

The key is **incremental improvement** - don't try to implement everything at once. Start with the Quick Wins, validate each change, and progressively enhance.

**Remember**: Like Dudley's journey, this is about continuous growth - each improvement brings you closer to the "Room of Requirement" experience you're aiming for! 🏠 → 🏰

---

**Document Version**: 1.0.0
**Last Updated**: 2025-10-05
**Status**: Ready for Implementation
