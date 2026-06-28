# Branching strategy (KingDown-Assoc/fluxer fork)

Public fork of upstream `fluxerapp/fluxer`, kept **ahead of upstream**: we land our bug fixes (and
sometimes features) before the official fixes, then reconcile once upstream ships them.

## Branches

| Branch | Role | Rules |
|---|---|---|
| `sync` | Pure upstream mirror; import landing zone. Never commit local code here. | no force-push, no deletion |
| `dev`  | Development + ahead-of-upstream patches. | no force-push, no deletion |
| `main` | Production. | PR required, no force-push, no deletion |

## Flow

```
fluxerapp/fluxer (upstream)
        |  scripts/sync-upstream.sh   (fast-forward only)
        v
      sync ---- scripts/merge-upstream-into-dev.sh ----> dev ---- PR ----> main (+ prod tag)
```

- Never `sync -> main` directly: upstream always goes through `dev` (integration + tests) before prod.
- Merge, never rebase: do not rewrite shared-branch history.
- `sync` stays fast-forwardable: the import script fails if commits were added there.

## Branch protection

Applied via [`scripts/setup-branch-protection.sh`](../scripts/setup-branch-protection.sh) (re-runnable).

- `main`: PR required (0 reviews enforced), force-push and deletion blocked, admin bypass allowed
  (`enforce_admins=false`).
- `dev` / `sync`: force-push and deletion blocked, no PR required.

### UI fallback (no gh)
`Settings > Branches > Add branch protection rule`:
- `main`: pattern `main`, check *Require a pull request before merging* (Required approvals = 0); leave
  *Allow force pushes* and *Allow deletions* unchecked; do not check *Do not allow bypassing*.
- `dev` and `sync`: separate rule, no *Require a pull request*; force-push and deletion unchecked.

## Opening a PR (inside the fork)

Target the fork explicitly:
```bash
gh repo set-default KingDown-Assoc/fluxer        # once
gh pr create --repo KingDown-Assoc/fluxer --base dev ...
```

See [`docs/FORK-MAINTENANCE.md`](FORK-MAINTENANCE.md) for divergence tracking and the import runbook.
