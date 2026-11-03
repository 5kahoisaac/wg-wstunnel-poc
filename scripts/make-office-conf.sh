#!/usr/bin/env bash
# Build office wg0.conf from the VPS's peer_office.conf.
#
# Usage:
#   On the VPS:   docker exec wg-hub cat /config/peer_office/peer_office.conf > peer_office.conf
#   Copy peer_office.conf to the office box, next to this repo, then:
#       ./scripts/make-office-conf.sh peer_office.conf
#   Writes: office/config-office/wg_confs/wg0.conf
#
# Reads office/.env for OFFICE_GW (optional) and OFFICE_ROUTES.
#   - MASQUERADE has NO -o filter (works on eth0, wlan0, anything).
#   - If OFFICE_GW is set, adds `ip route add <route> via OFFICE_GW` per OFFICE_ROUTES,
#     so the office box can reach internal subnets that aren't on its own default path.
set -euo pipefail

SELF="$(cd "$(dirname "$0")" && pwd)"
SRC="${1:-peer_office.conf}"
OUT="$SELF/../office/config-office/wg_confs/wg0.conf"
ENVF="$SELF/../office/.env"

[ -f "$SRC" ] || { echo "ERROR: $SRC not found. Pass the peer_office.conf path."; exit 1; }

# load OFFICE_GW / OFFICE_ROUTES from office/.env if present
OFFICE_GW=""; OFFICE_ROUTES=""
[ -f "$ENVF" ] && { set -a; . "$ENVF"; set +a; }

get() { grep -E "^$1 *=" "$SRC" | head -n1 | sed -E "s/^$1 *= *//"; }
PRIV=$(get PrivateKey); ADDR=$(get Address); PUB=$(get PublicKey); PSK=$(get PresharedKey || true)
[ -n "$PRIV" ] && [ -n "$ADDR" ] && [ -n "$PUB" ] || { echo "ERROR: missing keys in $SRC"; exit 1; }

# FORWARD accept + MASQUERADE (no -o, so it works on wlan0/eth0/etc.)
PU="iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -j MASQUERADE"
PD="iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -j MASQUERADE"

# optional static routes to internal subnets, via the office gateway
if [ -n "${OFFICE_GW:-}" ] && [ -n "${OFFICE_ROUTES:-}" ]; then
  IFS=',' read -ra RT <<< "$OFFICE_ROUTES"
  for r in "${RT[@]}"; do
    r="$(echo "$r" | xargs)"   # trim
    [ -n "$r" ] || continue
    PU="$PU; ip route add $r via $OFFICE_GW"
    PD="ip route del $r via $OFFICE_GW; $PD"
  done
  echo "[info] adding static routes via $OFFICE_GW for: $OFFICE_ROUTES"
else
  echo "[info] OFFICE_GW empty -> no static routes (office box must reach subnets natively)"
fi

mkdir -p "$(dirname "$OUT")"
{
  echo "[Interface]"
  echo "PrivateKey = $PRIV"
  echo "Address    = $ADDR"
  echo "PostUp     = $PU"
  echo "PostDown   = $PD"
  echo ""
  echo "[Peer]"
  echo "PublicKey    = $PUB"
  [ -n "$PSK" ] && echo "PresharedKey = $PSK"
  echo "Endpoint     = 127.0.0.1:51821"
  echo "AllowedIPs   = 10.13.13.0/24"
  echo "PersistentKeepalive = 25"
} > "$OUT"

echo "Wrote $OUT"
