#!/usr/bin/env bash
# Installs the same scanners CI uses, so `make scan` gives the same verdict locally.
set -euo pipefail

pip install --user --upgrade checkov ansible-core ansible-lint pre-commit
ansible-galaxy collection install -r ansible/requirements.yml

# Trivy from Aqua's signed apt repository
sudo apt-get update -qq
sudo apt-get install -y -qq wget gnupg
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | sudo tee /etc/apt/sources.list.d/trivy.list >/dev/null
sudo apt-get update -qq
sudo apt-get install -y -qq trivy

pre-commit install
echo "Ready. Run: make scan"
