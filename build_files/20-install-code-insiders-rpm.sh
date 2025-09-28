#!/usr/bin/bash
set -euo pipefail

echo "::group:: Add Microsoft VS Code repository"
cat >/etc/yum.repos.d/vscode-insiders.repo <<'EOF'
[code-insiders]
name=Visual Studio Code Insiders Repository
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
echo "::endgroup::"

echo "::group:: Install code-insiders RPM"
if ! rpm -q code-insiders >/dev/null 2>&1; then
  if ! dnf5 install -y code-insiders; then
    echo "Failed to install code-insiders RPM" >&2
    exit 1
  fi
fi
echo "::endgroup::"
