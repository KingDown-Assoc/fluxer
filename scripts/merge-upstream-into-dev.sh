#!/usr/bin/env bash
# Merge `sync` (upstream mirror) into `dev`.
# Clean merge: re-apply permanent fork patches.
# Conflicts: resolve by category (see docs/FORK-MAINTENANCE.md):
#   permanent customization (e.g. tests.yaml) -> take upstream, then re-patch
#   ahead-of-upstream patch                   -> official fix landed: take upstream + mark superseded
#                                                else keep ours
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
SYNC_BRANCH="${SYNC_BRANCH:-sync}"

git checkout dev
git pull --ff-only

if git merge --no-ff "$SYNC_BRANCH"; then
  ./scripts/apply-fork-patches.sh
  if ! git diff --quiet; then
    git add -A
    git commit -m "chore(fork): re-apply permanent patches after upstream import"
  fi
  echo "dev updated, permanent customizations re-applied."
  exit 0
fi

cat <<'EOF'

Merge conflicts. Resolve by category (see docs/FORK-MAINTENANCE.md):
  1. Permanent customization (e.g. .github/workflows/tests.yaml):
       git checkout --theirs <file> && git add <file>
     After resolving all conflicts: ./scripts/apply-fork-patches.sh
  2. Ahead-of-upstream patch (ledger 1.b):
       official fix landed -> git checkout --theirs <file> (mark 'superseded' in ledger)
       not yet             -> keep ours
  3. git add -A && git commit
EOF
exit 1
