#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing OpenTofu..."
curl -fsSL https://get.opentofu.org/install-opentofu.sh -o /tmp/install-opentofu.sh
chmod +x /tmp/install-opentofu.sh
sudo /tmp/install-opentofu.sh --install-method deb
rm /tmp/install-opentofu.sh
tofu --version

echo "==> Installing Task..."
sudo sh -c "$(curl -fsSL https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin
task --version

echo "==> Installing Claude Code..."
npm install -g @anthropic-ai/claude-code
claude --version

echo "==> Done."
