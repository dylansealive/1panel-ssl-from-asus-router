#!/bin/sh
set -e

SSH_DIR="${HOME:-/root}/.ssh"

ROUTER_USER="${ROUTER_USER:?ROUTER_USER is required}"
ROUTER_IP="${ROUTER_IP:?ROUTER_IP is required}"
ROUTER_PORT="${ROUTER_SSH_PORT:-22}"
ROUTER_PASSWORD="${ROUTER_PASSWORD:?ROUTER_PASSWORD is required}"
KEY_PATH_ON_ROUTER="${KEY_PATH_ON_ROUTER:?KEY_PATH_ON_ROUTER is required}"
CERT_PATH_ON_ROUTER="${CERT_PATH_ON_ROUTER:?CERT_PATH_ON_ROUTER is required}"

export SSHPASS="$ROUTER_PASSWORD"

echo "Getting router RSA host key..."
ROUTER_RSA_KEY=$(ssh-keyscan -p "$ROUTER_PORT" -t rsa "$ROUTER_IP")

mkdir -p "$SSH_DIR"
touch "$SSH_DIR/known_hosts"

if ! grep -q "$ROUTER_RSA_KEY" "$SSH_DIR/known_hosts" 2>/dev/null; then
	echo "Adding host to known_hosts..."
	printf '%s\n' "$ROUTER_RSA_KEY" >> "$SSH_DIR/known_hosts"
else
	echo "Host already in known_hosts."
fi

chmod 644 "$SSH_DIR/known_hosts"

echo "Pulling key and certificate via SSH..."
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
