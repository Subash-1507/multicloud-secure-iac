#!/usr/bin/env bash
# Installs the same scanners CI uses, so `make scan` gives the same verdict locally.
set -euo pipefail

# Codespaces mounts the repo world-writable; Ansible then ignores ansible.cfg.
# Remove write access for "others" instead of working around that check.
chmod -R o-w "$PWD"

# Pinned versions, pre-built wheels only: no third-party setup.py is executed
pip install --user --require-hashes --only-binary :all: -r requirements-dev.txt
ansible-galaxy collection install -r ansible/requirements.yml

# Trivy from Aqua's signed apt repository (HTTPS only, TLS 1.2+, no downgrade on redirect)
sudo apt-get update -qq
sudo apt-get install -y -qq gnupg
curl -fsSL --proto '=https' --proto-redir '=https' --tlsv1.2 \
  https://aquasecurity.github.io/trivy-repo/deb/public.key \
  | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
  | sudo tee /etc/apt/sources.list.d/trivy.list >/dev/null
sudo apt-get update -qq
sudo apt-get install -y -qq trivy

pre-commit install
echo "Ready. Run: make scan"
