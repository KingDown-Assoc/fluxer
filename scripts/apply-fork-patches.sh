#!/usr/bin/env bash
# Re-apply permanent fork customizations on upstream files (idempotent).
# Single entry point to keep imports predictable; extend per new customization.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
TESTS=".github/workflows/tests.yaml"

# Blacksmith runners (third-party, absent on the fork) -> free GitHub-hosted runners (public).
if [ -f "$TESTS" ]; then
  sed -i \
    -e 's/blacksmith-4vcpu-ubuntu-2404-arm/ubuntu-24.04-arm/g' \
    -e 's/blacksmith-4vcpu-ubuntu-2404/ubuntu-24.04/g' \
    -e 's/blacksmith-32vcpu-windows-2025/windows-2025/g' \
    "$TESTS"
fi

echo "Permanent fork patches re-applied."
