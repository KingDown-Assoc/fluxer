# Decentralized hosting

This instance is one logical Fluxer deployment whose services can be spread across several machines,
including machines run by members. It is **distribution of one instance**, not federation of
independent servers. Two rules decide who can host what: **backbone access** (trust) and **failure
impact** (resilience).

Golden rule: **no member node may take down the whole instance.** Failures must stay local.

## What runs where, and what happens if it dies

| Component | Backbone access | If it dies | Who can host it |
|---|---|---|---|
| Backbone (Postgres, NATS, Valkey, Meilisearch, S3) | is the root | GLOBAL outage | operator only, ideally HA |
| api / worker / gateway / primary shards | full (DB + NATS) | core impact | operator only |
| Voice node (LiveKit) | none | LOCAL: its region only | any member (sees only media of its calls) |
| Edge (media-proxy, static) | S3 + secret, no DB | LOCAL: media degraded, chat fine | trusted member |
| Extra core shard (messages/users) | DB + NATS | LOCAL: ~1/N of channels until restart | full-trust member, reliable host |

The operator always keeps the backbone plus at least one reliable voice region. That socle never
depends on a member.

## Cumulative tiers (pick per member, by trust)

A contributor enables the capabilities they want, cumulatively:

- **V (voice)** lowest trust: host a voice node = their own region. No backbone access.
- **E (edge)** trusted: V plus media-proxy/static. Needs S3 + media-proxy secret.
- **C (core)** full trust: E plus extra message/user shards over a private network. Full data access.

## Tier V: add a voice node

Use the kit in [`deploy/voice-node/`](../deploy/voice-node/README.md): the member runs LiveKit, the
operator registers it via the admin API (`/admin/voice/regions/create` + `/admin/voice/servers/create`).
Clients route to the nearest active region automatically.

Resilience: a voice server has no automatic health probe in core, so run
[`scripts/voice-node-healthcheck.sh`](../scripts/voice-node-healthcheck.sh) on a cron. It probes each
registered node and toggles `is_active` via the admin API, so a dead node drops out of routing and
returns automatically. Keep one operator-run region as fallback.

## Tier E: add an edge node

media-proxy and static are stateless edge services (no DB). A trusted member can run extra replicas
behind a load balancer or in a different location. They need S3 reachability and the media-proxy
secret. Media is non-blocking for chat, so a dead edge node only degrades media delivery, and a load
balancer routes around it.

## Tier C: add core services (private fleet)

Only for full-trust hosts on reliable machines.

1. Build a secured private network (e.g. WireGuard mesh) so Postgres, NATS, and Valkey are reachable
   privately between machines and never exposed to the public internet.
2. Run extra service instances pointing at the shared backbone via env:
   `FLUXER_*_NATS_URL`, `FLUXER_POSTGRES_*`, `FLUXER_INTERNAL_*_ENDPOINT`.
3. Shard messages/users with `FLUXER_SVC_SHARD_COUNT` and `FLUXER_SVC_SHARD_ID`. Data stays in the
   central database; shards are stateless query workers.

SPOF warning: today each `shard_id` is a single point of failure for its key slice (no replica
failover). A dead shard makes its ~1/N of channels time out until it restarts (data is not lost).
Do not put a sole shard on an unreliable machine. To make shards redundant, add a NATS queue group
per `shard_id` with multiple replicas (a core change, ahead-of-upstream patch). Until then, keep core
on operator-grade infra.

## Summary

- Voice and edge are failure-isolated and safe to delegate by trust level.
- Core is isolated per slice but a SPOF, so reserve it for reliable, full-trust hosts.
- The backbone is the only global dependency and stays with the operator.
