#!/usr/bin/env bash
# Import upstream (fluxerapp/fluxer) into the `sync` branch as a pure mirror.
# Never commit local code on `sync`; the ff-only merge fails if it diverged.
set -euo pipefail

UPSTREAM_URL="${UPSTREAM_URL:-https://github.com/fluxerapp/fluxer.git}"
UPSTREAM_REMOTE="${UPSTREAM_REMOTE:-upstream}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-main}"   # upstream default branch (confirm)
SYNC_BRANCH="${SYNC_BRANCH:-sync}"

cd "$(git rev-parse --show-toplevel)"

git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1 \
  || git remote add "$UPSTREAM_REMOTE" "$UPSTREAM_URL"

git fetch "$UPSTREAM_REMOTE" --prune
git checkout "$SYNC_BRANCH" 2>/dev/null || git checkout -b "$SYNC_BRANCH" "origin/${SYNC_BRANCH}"
git pull --ff-only origin "$SYNC_BRANCH"
git merge --ff-only "${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH}"
git push origin "$SYNC_BRANCH"

echo "sync updated from ${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH}. Next: ./scripts/merge-upstream-into-dev.sh"
