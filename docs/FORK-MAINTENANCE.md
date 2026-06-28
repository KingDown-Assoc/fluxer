# Fork maintenance: divergences, imports, reconciliation

Key document for the fork's longevity. Goal: control drift from upstream `fluxerapp/fluxer` and make
each import predictable. See also [`BRANCHING.md`](BRANCHING.md).

## 1. Divergence ledger

Two categories. Keep it updated on every new divergence.

### 1.a Permanent customizations
Re-applied automatically on every import via [`scripts/apply-fork-patches.sh`](../scripts/apply-fork-patches.sh).

| Divergence | File / Setting | Why | Re-apply |
|---|---|---|---|
| Blacksmith runners -> GitHub-hosted | `.github/workflows/tests.yaml`, `_build-image.yaml` | Fork has no Blacksmith; GitHub-hosted runners are free on public repos | `scripts/apply-fork-patches.sh` (idempotent sed) |
| GHCR owner forced lowercase | `.github/workflows/_build-image.yaml` | `github.repository_owner` is `KingDown-Assoc` (uppercase); Docker refs must be lowercase | `scripts/apply-fork-patches.sh` |
| Out-of-scope workflows disabled | UI setting (Actions tab) | Depend on the `FLUXER_CI_APP_*`/Weblate app or are upstream-specific | re-disable via UI if re-enabled |
| Branch protection | GitHub setting | Fork governance | `scripts/setup-branch-protection.sh` |
| Ops tooling | `scripts/`, `docs/`, `.github/workflows/build-self-hosted.yaml` | Fork maintenance (not in upstream) | versioned |

> Workflows disabled via UI: `pr-template-honeypot`, `labeller`, `lock-closed-conversations`,
> `i18n-source-sync`, `i18n-weblate-pr`.

> Self-hosted images: dispatch `build-self-hosted` to build the 10 server images to
> `ghcr.io/kingdown-assoc/`. Set each package public once, then point the compose at them with
> `FLUXER_REGISTRY_OWNER=kingdown-assoc` (see `deploy/self-hosting/`).

### 1.b Ahead-of-upstream patches (temporary)
Fixes/features landed before the official ones. Drop them once upstream ships the fix.

| Patch | File(s) | Why | Upstream tracking | Status |
|---|---|---|---|---|
| KLIPY embed + gif error handling | `fluxer_unfurl/src/resolvers/klipy.rs`, `fluxer_api/src/api/gif/*`, `NatsUnfurlerService.ts` | Resolve KLIPY embeds via the KLIPY API (direct fetch blocked by Cloudflare); return 503 instead of 500 on gif provider failure | none | `pending` |
| Gateway: remove erlcass from OTP app | `fluxer_gateway/src/fluxer_gateway.app.src` | Self-hosting has no Cassandra; erlcass in the app deps crashes the gateway on boot. Cherry-picked from upstream `4.99-pizza` (`110b3a75`) | upstream `4.99-pizza` has it, `main` does not yet | `pending` |

## 2. Commit convention (ahead-of-upstream patches)

- One fix = one commit (atomic), easy to `revert` once superseded.
- Optional trailer in the commit message (no upstream reference):
  ```
  Upstream-Status: pending
  ```
  becomes `superseded` once the official fix lands.
- Never put an `owner/repo#N`-style upstream reference (or an upstream issue URL) in commit messages,
  PR titles/descriptions, or comments: GitHub creates a cross-reference notification on the upstream
  project. Track upstream links in the ledger only, wrapped in backticks so they stay inert.
- List carried patches: `git log --grep "Upstream-Status: pending" --oneline`.

## 3. Import runbook (cadence: weekly or per upstream release)

1. `./scripts/sync-upstream.sh`: update `sync` from upstream.
2. `./scripts/merge-upstream-into-dev.sh`: merge `sync` into `dev`.
3. Resolve conflicts by category:
   - Permanent customization (e.g. `tests.yaml`): take upstream (`git checkout --theirs <file>`), then
     `./scripts/apply-fork-patches.sh`.
   - Ahead-of-upstream patch (ledger 1.b): if upstream now has the official fix, take upstream, drop our
     patch, mark the entry `superseded`; otherwise keep ours.
   - Finalize: `git add -A && git commit`.
4. Check CI is green on `dev` (`tests`, `validate`, `dart-sdk-validation`).
5. Promote to prod: PR `dev -> main`, merge, then tag: `git tag -a prod-YYYY-MM-DD -m "..." && git push --tags`.

## 4. Guardrails

- PR target: `gh repo set-default KingDown-Assoc/fluxer` so `gh pr create` defaults to this repo; pass
  `--repo KingDown-Assoc/fluxer` explicitly.
- Dependabot: keep disabled (dependencies come from upstream) to avoid noise.
- Watch: subscribe to `fluxerapp/fluxer` releases (Watch > Custom > Releases).
- Confirm the upstream default branch (`main` assumed) before pinning `UPSTREAM_BRANCH` in `sync-upstream.sh`.
