#!/usr/bin/bash
set -euo pipefail

echo "::group:: Install Sema4.ai Action Server"

ACTION_SERVER_URL="https://cdn.sema4.ai/action-server/releases/latest/linux64/action-server"

# Download Action Server binary
curl -fsSL "${ACTION_SERVER_URL}" -o /tmp/action-server

# Install to /usr/bin (standard location for system binaries)
install -m755 /tmp/action-server /usr/bin/action-server

# Clean up
rm -f /tmp/action-server

# Verify installation
if action-server version 2>&1 | grep -q "^[0-9]"; then
    echo "Action Server installed successfully"
    action-server version 2>&1 | head -n 1
else
    echo "Warning: Action Server version check produced unexpected output" >&2
fi

echo "::endgroup::"
