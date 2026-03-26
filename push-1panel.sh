#!/bin/sh
#
# ssl-push-1panel: upload key/cert to 1Panel website SSL API (paste mode).
#
# Exit codes:
#   1 — Cannot read PEM files, HTTP status is not 200, or JSON field .code is not 200.
#   2 — Response body is not valid JSON.
#
# On success: full API JSON is printed to stdout, then a blank line, then a prefixed
# status line (also stdout). The API key/token is never echoed; whether the JSON
# contains sensitive fields depends on 1Panel — scrub logs after troubleshooting.
#
# Network/DNS/TLS errors often appear as curl messages on stderr (curl uses -sS).
#
set -e

BASE_URL="${ONEPANEL_BASE_URL:?ONEPANEL_BASE_URL is required}"
API_KEY="${ONEPANEL_API_KEY:?ONEPANEL_API_KEY is required}"
SSL_ID="${ONEPANEL_SSL_ID:-0}"
API_PATH="${ONEPANEL_API_PATH:-/api/v2/websites/ssl/upload}"
DESC="${ONEPANEL_SSL_DESCRIPTION:-}"
KEY_FILE="${ONEPANEL_KEY_FILE:-/ssl/key.pem}"
CERT_FILE="${ONEPANEL_CERT_FILE:-/ssl/cert.pem}"

case "$API_PATH" in
/*) ;;
*) API_PATH="/$API_PATH" ;;
esac

if [ ! -r "$KEY_FILE" ] || [ ! -r "$CERT_FILE" ]; then
	echo "[ssl-push-1panel] Cannot read key or cert: $KEY_FILE / $CERT_FILE" >&2
	exit 1
fi

TS=$(date +%s)
TOKEN=$(printf '1panel%s%s' "$API_KEY" "$TS" | openssl md5 | awk '{print $2}')

URL="${BASE_URL%/}${API_PATH}"

CURL_OPTS="-sS"
case "${ONEPANEL_SKIP_TLS_VERIFY:-0}" in
1 | true | yes) CURL_OPTS="$CURL_OPTS -k" ;;
esac

# 网站 → 证书：Upload（paste），与面板系统 HTTPS 的 core/settings/ssl/update 不同
BODY=$(jq -n \
	--rawfile keyPem "$KEY_FILE" \
	--rawfile certPem "$CERT_FILE" \
	--arg type paste \
	--argjson sslID "$SSL_ID" \
	--arg desc "$DESC" \
	'{type: $type, privateKey: $keyPem, certificate: $certPem, sslID: $sslID, description: $desc}')

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

case "$BASE_URL" in
*://*) _url_host="${BASE_URL#*://}" ;;
*) _url_host="$BASE_URL" ;;
esac
_url_host="${_url_host%%/*}"
echo "[ssl-push-1panel] POST ${_url_host}${API_PATH} sslID=${SSL_ID}" >&2

HTTP_CODE=$(curl $CURL_OPTS -X POST "$URL" \
	-H "accept: application/json" \
	-H "Content-Type: application/json; charset=utf-8" \
	-H "1Panel-Token: $TOKEN" \
	-H "1Panel-Timestamp: $TS" \
	-d "$BODY" \
	-o "$TMP" -w '%{http_code}')

if [ "$HTTP_CODE" != "200" ]; then
	echo "[ssl-push-1panel] HTTP status: $HTTP_CODE" >&2
	head -c 800 "$TMP" >&2 || true
	echo >&2
	exit 1
fi

if ! jq -e . "$TMP" >/dev/null 2>&1; then
	echo "[ssl-push-1panel] 响应不是合法 JSON。" >&2
	head -c 400 "$TMP" >&2 || true
	echo >&2
	exit 2
fi

cat "$TMP"
echo ""

API_CODE=$(jq -r '.code // empty' "$TMP")
if [ -n "$API_CODE" ] && [ "$API_CODE" != "200" ]; then
	echo "[ssl-push-1panel] 1Panel API code: $API_CODE" >&2
	jq -r '.message // empty' "$TMP" >&2 || true
	exit 1
fi

echo "[ssl-push-1panel] 1Panel website SSL upload OK."
