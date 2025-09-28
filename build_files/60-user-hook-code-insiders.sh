#!/usr/bin/bash
set -euo pipefail

echo "::group:: Install user setup hook for code-insiders extensions"
HOOK_DIR="/usr/share/ublue-os/user-setup.hooks.d"
install -d "$HOOK_DIR"
cat >"$HOOK_DIR/15-code-insiders-extensions.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CMD="code-insiders"
command -v "$CMD" >/dev/null 2>&1 || exit 0

# Ensure config directories exist
mkdir -p "$HOME/.config" || true
USER_DATA_DIR="$HOME/.config/Code - Insiders"
mkdir -p "$USER_DATA_DIR" || true

MARKER="$HOME/.config/.vscode-insiders.done"
if [[ -f "$MARKER" ]]; then
  exit 0
fi

EXTENSIONS=( \
  ms-vscode-remote.remote-containers \
  ms-vscode-remote.remote-ssh \
  ms-vscode.remote-repositories \
  ms-vscode.cpptools-extension-pack \
)

for ext in "${EXTENSIONS[@]}"; do
  if ! "$CMD" --list-extensions --user-data-dir "$USER_DATA_DIR" --no-sandbox 2>/dev/null | grep -q "^${ext}$"; then
    "$CMD" --install-extension "$ext" --user-data-dir "$USER_DATA_DIR" --no-sandbox || true
  fi
done

touch "$MARKER" || true
EOF
chmod 0755 "$HOOK_DIR/15-code-insiders-extensions.sh"
echo "::endgroup::"
