#!/bin/sh
#
# ssl-from-router: pull TLS key and certificate from the router over SSH into /ssl.
#
# - This script never prints PEM material, passwords, or other secrets to the terminal.
# - Writes only /ssl/key.pem and /ssl/cert.pem inside the container (shared volume).
# - Progress and status messages go to stderr so stdout stays free for future piping.
# - Failures usually surface on stderr from ssh-keyscan, sshpass, or ssh (connection,
#   auth, or remote errors).
# - Uses set -e: any failing step exits non-zero immediately.
#
set -e

SSH_DIR="${HOME:-/root}/.ssh"

ROUTER_USER="${ROUTER_USER:?ROUTER_USER is required}"
ROUTER_IP="${ROUTER_IP:?ROUTER_IP is required}"
ROUTER_PORT="${ROUTER_SSH_PORT:-22}"
ROUTER_PASSWORD="${ROUTER_PASSWORD:?ROUTER_PASSWORD is required}"
KEY_PATH_ON_ROUTER="${KEY_PATH_ON_ROUTER:?KEY_PATH_ON_ROUTER is required}"
CERT_PATH_ON_ROUTER="${CERT_PATH_ON_ROUTER:?CERT_PATH_ON_ROUTER is required}"

export SSHPASS="$ROUTER_PASSWORD"

echo "[ssl-from-router] Getting router RSA host key..." >&2
ROUTER_RSA_KEY=$(ssh-keyscan -p "$ROUTER_PORT" -t rsa "$ROUTER_IP")

mkdir -p "$SSH_DIR"
touch "$SSH_DIR/known_hosts"

if ! grep -q "$ROUTER_RSA_KEY" "$SSH_DIR/known_hosts" 2>/dev/null; then
	echo "[ssl-from-router] Adding host to known_hosts..." >&2
	printf '%s\n' "$ROUTER_RSA_KEY" >> "$SSH_DIR/known_hosts"
else
	echo "[ssl-from-router] Host already in known_hosts." >&2
fi

chmod 644 "$SSH_DIR/known_hosts"

echo "[ssl-from-router] Pulling key and certificate via SSH..." >&2
sshpass -e ssh \
	-o StrictHostKeyChecking=yes \
	-o "UserKnownHostsFile=$SSH_DIR/known_hosts" \
	-p "$ROUTER_PORT" \
	"${ROUTER_USER}@${ROUTER_IP}" \
	"cat ${KEY_PATH_ON_ROUTER}" > /ssl/key.pem

sshpass -e ssh \
	-o StrictHostKeyChecking=yes \
	-o "UserKnownHostsFile=$SSH_DIR/known_hosts" \
	-p "$ROUTER_PORT" \
	"${ROUTER_USER}@${ROUTER_IP}" \
	"cat ${CERT_PATH_ON_ROUTER}" > /ssl/cert.pem

unset SSHPASS

echo "[ssl-from-router] Wrote /ssl/key.pem and /ssl/cert.pem." >&2
