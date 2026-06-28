#!/usr/bin/env bash
# Health-check for registered Fluxer voice nodes (run on a cron on the instance side).
# Lists voice servers via the admin API, probes each endpoint, and toggles is_active so that a
# dead node is taken out of routing automatically and re-added when it recovers. No core change.
#
# Env:
#   INSTANCE_API   base API URL, e.g. https://chat.example.org/api   (required)
#   ADMIN_API_KEY  admin API key with VOICE_SERVER_LIST + VOICE_SERVER_UPDATE  (required)
#   PROBE_TIMEOUT  per-probe timeout in seconds (default 5)
set -euo pipefail

: "${INSTANCE_API:?set INSTANCE_API (e.g. https://chat.example.org/api)}"
: "${ADMIN_API_KEY:?set ADMIN_API_KEY}"
PROBE_TIMEOUT="${PROBE_TIMEOUT:-5}"

command -v jq >/dev/null 2>&1 || { echo "jq is required"; exit 1; }

api() {
  # api <path> <json-body>
  curl -fsS -X POST "${INSTANCE_API}${1}" \
    -H "Authorization: Bearer ${ADMIN_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "${2}"
}

set_active() {
  # set_active <region_id> <server_id> <true|false>
  api "/admin/voice/servers/update" \
    "$(jq -nc --arg r "$1" --arg s "$2" --argjson a "$3" '{region_id:$r,server_id:$s,is_active:$a}')" >/dev/null
}

reachable() {
  # reachable <wss-or-https-endpoint> -> 0 if the host answers, non-zero otherwise
  local url="${1/#wss:/https:}"
  curl -s -o /dev/null --max-time "$PROBE_TIMEOUT" "$url"
}

main() {
  local regions servers count=0 changed=0
  regions="$(api "/admin/voice/regions/list" '{"include_servers":true}')"

  # Flatten to: region_id \t server_id \t endpoint \t is_active
  while IFS=$'\t' read -r region server endpoint active; do
    [ -n "$server" ] || continue
    count=$((count + 1))
    if reachable "$endpoint"; then
      if [ "$active" = "false" ]; then
        echo "UP   ${region}/${server} -> re-enabling"
        set_active "$region" "$server" true
        changed=$((changed + 1))
      fi
    else
      if [ "$active" = "true" ]; then
        echo "DOWN ${region}/${server} (${endpoint}) -> disabling"
        set_active "$region" "$server" false
        changed=$((changed + 1))
      fi
    fi
  done < <(echo "$regions" | jq -r '.regions[].servers[]? | [.region_id,.server_id,.endpoint,(.is_active|tostring)] | @tsv')

  echo "checked ${count} server(s), ${changed} state change(s)"
}

main "$@"
