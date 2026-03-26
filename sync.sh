#!/bin/sh
#
# Orchestrates ssl-from-router then ssl-push-1panel (two compose services, shared ./ssl).
# With set -e, the exit code is that of the first failing step; logs come from the
# scripts inside each container plus Docker.
#
set -e
cd "$(dirname "$0")"
echo "[sync] === ssl-from-router ===" >&2
docker compose run --rm ssl-from-router
echo "[sync] router step OK, starting 1Panel step..." >&2
echo "[sync] === ssl-push-1panel ===" >&2
docker compose run --rm ssl-push-1panel
echo "[sync] === done ===" >&2
