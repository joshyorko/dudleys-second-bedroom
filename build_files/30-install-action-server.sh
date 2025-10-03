#!/usr/bin/env bash
set -euo pipefail

echo "::group:: Install Sema4.ai Action Server"

# Download and install action-server
curl -fsSL https://cdn.sema4.ai/action-server/releases/2.14.2/linux64/action-server \
  -o /tmp/action-server

# Make executable and install to /usr/bin
chmod +x /tmp/action-server
install -m755 /tmp/action-server /usr/bin/action-server
rm -f /tmp/action-server

# Create a temporary home directory for initialization
TEMP_HOME=$(mktemp -d)
export HOME="$TEMP_HOME"
export ROBOCORP_HOME="$TEMP_HOME/.robocorp"
mkdir -p "$ROBOCORP_HOME"

# Initialize action-server by running version check
# This extracts internal assets to the home directory
if /usr/bin/action-server version 2>&1 | grep -q '[0-9]'; then
    echo "Action Server initialized successfully"
else
    echo "Warning: Action Server version check produced unexpected output"
fi

# Clean up temporary home
rm -rf "$TEMP_HOME"

echo "::endgroup::"
