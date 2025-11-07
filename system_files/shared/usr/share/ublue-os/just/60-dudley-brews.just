# Dudley's Brew Installation Commands
# Install Homebrew packages from various Brewfiles

# Install CLI tools and utilities
dudley-brews-cli:
    #!/usr/bin/bash
    set -euo pipefail
    BREWFILE="/usr/share/ublue-os/homebrew/dudley-cli.Brewfile"
    if [ -f "$BREWFILE" ]; then
        echo "Installing CLI tools from dudley-cli.Brewfile..."
        brew bundle --file="$BREWFILE"
        echo "✓ CLI tools installation complete"
    else
        echo "ERROR: $BREWFILE not found"
        exit 1
    fi

# Install development tools
dudley-brews-dev:
    #!/usr/bin/bash
    set -euo pipefail
    BREWFILE="/usr/share/ublue-os/homebrew/dudley-dev.Brewfile"
    if [ -f "$BREWFILE" ]; then
        echo "Installing development tools from dudley-dev.Brewfile..."
        brew bundle --file="$BREWFILE"
        echo "✓ Development tools installation complete"
    else
        echo "ERROR: $BREWFILE not found"
        exit 1
    fi

# Install fonts
dudley-brews-fonts:
    #!/usr/bin/bash
    set -euo pipefail
    BREWFILE="/usr/share/ublue-os/homebrew/dudley-fonts.Brewfile"
    if [ -f "$BREWFILE" ]; then
        echo "Installing fonts from dudley-fonts.Brewfile..."
        brew bundle --file="$BREWFILE"
        echo "✓ Fonts installation complete"
    else
        echo "ERROR: $BREWFILE not found"
        exit 1
    fi

# Install Kubernetes and cloud-native tools
dudley-brews-k8s:
    #!/usr/bin/bash
    set -euo pipefail
    BREWFILE="/usr/share/ublue-os/homebrew/dudley-k8s.Brewfile"
    if [ -f "$BREWFILE" ]; then
        echo "Installing Kubernetes tools from dudley-k8s.Brewfile..."
        brew bundle --file="$BREWFILE"
        echo "✓ Kubernetes tools installation complete"
    else
        echo "ERROR: $BREWFILE not found"
        exit 1
    fi

# Install all Dudley's brew packages
dudley-brews-all:
    #!/usr/bin/bash
    set -euo pipefail
    echo "Installing all Dudley's brew packages..."
    echo ""
    echo "=== Installing CLI tools ==="
    ujust dudley-brews-cli
    echo ""
    echo "=== Installing development tools ==="
    ujust dudley-brews-dev
    echo ""
    echo "=== Installing fonts ==="
    ujust dudley-brews-fonts
    echo ""
    echo "=== Installing Kubernetes tools ==="
    ujust dudley-brews-k8s
    echo ""
    echo "✓ All brew packages installation complete!"

# List available Brewfiles
dudley-brews-list:
    #!/usr/bin/bash
    set -euo pipefail
    echo "Available Brewfiles in /usr/share/ublue-os/homebrew/:"
    if [ -d "/usr/share/ublue-os/homebrew" ]; then
        ls -1 /usr/share/ublue-os/homebrew/*.Brewfile 2>/dev/null || echo "No Brewfiles found"
    else
        echo "Homebrew directory not found"
    fi
