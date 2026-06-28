#!/usr/bin/env bash
# Re-apply permanent fork customizations on upstream files (idempotent).
# Single entry point to keep imports predictable; extend per new customization.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# Blacksmith runners (third-party, absent on the fork) -> free GitHub-hosted runners (public).
remap_runners() {
  [ -f "$1" ] || return 0
  sed -i \
    -e 's/blacksmith-4vcpu-ubuntu-2404-arm/ubuntu-24.04-arm/g' \
    -e 's/blacksmith-4vcpu-ubuntu-2404/ubuntu-24.04/g' \
    -e 's/blacksmith-32vcpu-windows-2025/windows-2025/g' \
    "$1"
}

remap_runners .github/workflows/tests.yaml
remap_runners .github/workflows/_build-image.yaml

# GHCR owner must be lowercase: org "KingDown-Assoc" has uppercase, Docker refs are lowercase-only.
BUILD_IMAGE=.github/workflows/_build-image.yaml
if [ -f "$BUILD_IMAGE" ]; then
  sed -i 's/GHCR_OWNER: .*github\.repository_owner.*/GHCR_OWNER: kingdown-assoc/' "$BUILD_IMAGE"
fi

echo "Permanent fork patches re-applied."
