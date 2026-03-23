#!/bin/sh
# 1panel-ssl-from-asus-router — router pull then 1Panel upload (two images, two runs).
set -e
cd "$(dirname "$0")"
echo "=== ssl-from-router ==="
docker compose run --rm ssl-from-router
echo "=== ssl-push-1panel ==="
docker compose run --rm ssl-push-1panel
echo "=== done ==="
