#!/usr/bin/env bash
# Apply and verify branch protection (idempotent, re-runnable).
# Requires gh installed + authenticated (gh auth login) with admin on the repo.
set -euo pipefail

REPO="${REPO:-KingDown-Assoc/fluxer}"

require_gh() {
  command -v gh >/dev/null 2>&1 || { echo "gh not found; install GitHub CLI then run 'gh auth login'"; exit 1; }
  gh auth status >/dev/null 2>&1 || { echo "gh not authenticated; run 'gh auth login'"; exit 1; }
}

# main: require PR (0 reviews), block force-push and deletion, admins can bypass.
protect_main() {
  echo "Protecting main (require PR, no overwrite)..."
  gh api --method PUT -H "Accept: application/vnd.github+json" \
    "repos/${REPO}/branches/main/protection" --input - <<'JSON'
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0,
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_linear_history": false
}
JSON
}

# dev/sync: block force-push and deletion, no PR requirement.
protect_open() {
  local branch="$1"
  echo "Protecting ${branch} (no force-push, no deletion)..."
  gh api --method PUT -H "Accept: application/vnd.github+json" \
    "repos/${REPO}/branches/${branch}/protection" --input - <<'JSON'
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
}

verify() {
  echo
  echo "Verification (${REPO}):"
  for B in main dev sync; do
    echo "[${B}]"
    gh api "repos/${REPO}/branches/${B}/protection" \
      --jq '{force_push: .allow_force_pushes.enabled, deletions: .allow_deletions.enabled, pr_required: (.required_pull_request_reviews != null)}' \
      2>/dev/null || echo "  (no protection or branch missing)"
  done
}

require_gh
protect_main
for b in dev sync; do protect_open "$b"; done
verify
echo
echo "Done."
