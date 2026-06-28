# Fluxer voice node (LiveKit)

A standalone regional voice server that a member can host. It relays voice/video media only.
It has **no access** to the instance database, NATS, or Valkey. If this node goes down, only its
region degrades: chat and other regions keep working, and new calls reroute to another region.

Privacy note: like any SFU, the node sees the media (audio/video) of the calls routed to it. It
never sees messages, accounts, or any instance data. Host it only with people you trust for media.

## 1. Prerequisites
- A machine with a public IP and a DNS name pointing to it (e.g. `voice-eu.example.org`).
- Docker + Docker Compose.
- Open ports:
  - `80/tcp` and `443/tcp` (TLS + signaling via Caddy)
  - `7881/tcp` and `7882/udp` (LiveKit RTC media)
  - `3478/udp` (TURN)

## 2. Configure
1. `cp .env.example .env` and set `NODE_DOMAIN` and `ACME_EMAIL`.
2. Generate a key/secret for this node (any random strings, secret >= 32 chars):
   ```bash
   echo "key_$(openssl rand -hex 6)"; openssl rand -hex 32
   ```
3. Edit `livekit.yaml`:
   - replace `REPLACE_API_KEY` / `REPLACE_API_SECRET` under `keys:` and `webhook.api_key`,
   - set the webhook URL to the instance: `https://<instance-domain>/api/webhooks/livekit`.

## 3. Run
```bash
docker compose up -d
docker compose logs -f livekit
```
The signaling endpoint is `wss://<NODE_DOMAIN>`.

## 4. Register the node on the instance (done by the instance admin)
Requires an admin API key with `VOICE_REGION_CREATE` and `VOICE_SERVER_CREATE` permissions.
Calls go to `https://<instance-domain>/api/admin/voice/...`.

Create the region (once per region):
```bash
curl -fsS -X POST "https://<instance-domain>/api/admin/voice/regions/create" \
  -H "Authorization: Bearer $ADMIN_API_KEY" -H "Content-Type: application/json" \
  -d '{"id":"eu-west","name":"EU West","emoji":"🇪🇺","latitude":48.85,"longitude":2.35}'
```

Register this node as a server in that region:
```bash
curl -fsS -X POST "https://<instance-domain>/api/admin/voice/servers/create" \
  -H "Authorization: Bearer $ADMIN_API_KEY" -H "Content-Type: application/json" \
  -d '{
    "region_id":"eu-west",
    "server_id":"member-alice-1",
    "endpoint":"wss://voice-eu.example.org",
    "api_key":"<node api_key>",
    "api_secret":"<node api_secret>",
    "latitude":48.85,
    "longitude":2.35
  }'
```
`endpoint` is the node `wss://` URL, `api_key`/`api_secret` are the node credentials from step 2.
Clients are routed to the nearest active region automatically.

## 5. Resilience
- Keep at least one operator-run region as a reliable fallback.
- Run `scripts/voice-node-healthcheck.sh` (cron) on the instance side: it auto-disables an
  unreachable node (so new calls reroute) and re-enables it when it returns. No manual action.

## 6. Locked-down networks (optional)
If members are behind firewalls that only allow `443`, enable TLS TURN in `livekit.yaml`
(`turn.tls_port: 5349` + `turn.domain`) and provide certs (Caddy can issue them; route TURN/TLS to
LiveKit). This is an enhancement, not required for most setups.
