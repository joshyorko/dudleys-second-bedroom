# Dudley runtime commands
#
# One entrypoint for Homebrew bundles and VS Code extensions.
#
# Examples:
#   ujust dudley
#   ujust dudley brew dev
#   ujust dudley extensions
#   ujust dudley extensions force

# ujust dudley list
dudley action="setup" target="all" mode="":
    #!/usr/bin/env bash
    set -euo pipefail

    ACTION="{{ action }}"
    TARGET="{{ target }}"
    MODE="{{ mode }}"
    BREW_DIR="/usr/share/ublue-os/homebrew"
    EXTENSIONS_HOOK="/usr/share/ublue-os/user-setup.hooks.d/20-vscode-extensions.sh"

    ensure_brew() {
        if ! command -v brew >/dev/null 2>&1; then
            echo "ERROR: Homebrew is not available on PATH"
            exit 1
        fi
    }

    run_bundle() {
        local bundle="$1"
        local brewfile="$BREW_DIR/$bundle"

        ensure_brew
        if [[ ! -f "$brewfile" ]]; then
            echo "ERROR: $brewfile not found"
            exit 1
        fi

        echo "Installing $(basename "$bundle" .Brewfile) ..."
        brew bundle --file="$brewfile"
        echo "✓ $(basename "$bundle" .Brewfile) complete"
    }

    run_extensions() {
        if [[ ! -x "$EXTENSIONS_HOOK" ]]; then
            echo "ERROR: $EXTENSIONS_HOOK not found"
            exit 1
        fi

        if [[ "$MODE" == "force" ]]; then
            echo "Forcing VS Code extension reinstall..."
            VSCODE_EXTENSIONS_FORCE=1 bash "$EXTENSIONS_HOOK"
        else
            bash "$EXTENSIONS_HOOK"
        fi
    }

    show_list() {
        echo "Available Dudley Brewfiles:"
        if [[ -d "$BREW_DIR" ]]; then
            ls -1 "$BREW_DIR"/dudley-*.Brewfile 2>/dev/null || echo "No Brewfiles found"
        else
            echo "Homebrew directory not found"
        fi

        echo ""
        echo "Examples:"
        echo "  ujust dudley                 # install all Brewfiles, then VS Code extensions"
        echo "  ujust dudley brew dev        # install dev Brewfile only"
        echo "  ujust dudley extensions      # install/update VS Code extensions"
        echo "  ujust dudley extensions force"
    }

    case "$ACTION" in
        setup)
            case "$TARGET" in
                all)
                    run_bundle "dudley-cli.Brewfile"
                    run_bundle "dudley-dev.Brewfile"
                    run_bundle "dudley-fonts.Brewfile"
                    run_bundle "dudley-k8s.Brewfile"
                    run_extensions
                    ;;
                cli)
                    run_bundle "dudley-cli.Brewfile"
                    ;;
                dev)
                    run_bundle "dudley-dev.Brewfile"
                    run_extensions
                    ;;
                fonts)
                    run_bundle "dudley-fonts.Brewfile"
                    ;;
                k8s)
                    run_bundle "dudley-k8s.Brewfile"
                    ;;
                *)
                    echo "ERROR: Unknown setup target '$TARGET'"
                    exit 1
                    ;;
            esac
            ;;
        brew)
            case "$TARGET" in
                all)
                    run_bundle "dudley-cli.Brewfile"
                    run_bundle "dudley-dev.Brewfile"
                    run_bundle "dudley-fonts.Brewfile"
                    run_bundle "dudley-k8s.Brewfile"
                    ;;
                cli)
                    run_bundle "dudley-cli.Brewfile"
                    ;;
                dev)
                    run_bundle "dudley-dev.Brewfile"
                    ;;
                fonts)
                    run_bundle "dudley-fonts.Brewfile"
                    ;;
                k8s)
                    run_bundle "dudley-k8s.Brewfile"
                    ;;
                *)
                    echo "ERROR: Unknown brew target '$TARGET'"
                    exit 1
                    ;;
            esac
            ;;
        extensions)
            run_extensions
            ;;
        list|help|--help|-h)
            show_list
            ;;
        *)
            echo "ERROR: Unknown Dudley action '$ACTION'"
            show_list
            exit 1
            ;;
    esac
