#!/usr/bin/env bash
# Quick health check. Run on the VPS.
set -uo pipefail
echo "== wstunnel flags (confirm server/client/-L/--restrict-* exist) =="
docker run --rm --entrypoint /home/app/wstunnel ghcr.io/erebe/wstunnel --help 2>&1 | head -40
echo
echo "== hub peers (want BOTH home + office with recent handshake, transfer>0) =="
docker exec wg-hub wg show 2>&1 || echo "wg-hub not running"
