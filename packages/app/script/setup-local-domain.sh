#!/usr/bin/env bash
#
# Maps ekowork.local to localhost so the Ekowork dev server is reachable at
# http://ekowork.local:<port> in a browser.
#
# This edits /etc/hosts and therefore requires sudo. It is a MANUAL, one-time
# step — run it yourself; the build tooling will not modify system files.
#
#   sudo ./packages/app/script/setup-local-domain.sh
#
# Idempotent: re-running it will not add duplicate entries.
set -euo pipefail

HOSTS_FILE="/etc/hosts"
DOMAIN="ekowork.local"

if [ "$(id -u)" -ne 0 ]; then
  echo "This script edits ${HOSTS_FILE} and must be run with sudo:" >&2
  echo "  sudo $0" >&2
  exit 1
fi

for entry in "127.0.0.1 ${DOMAIN}" "::1 ${DOMAIN}"; do
  if grep -qE "^[[:space:]]*[^#].*[[:space:]]${DOMAIN}([[:space:]]|$)" "$HOSTS_FILE" \
    && grep -qF "$entry" "$HOSTS_FILE"; then
    echo "Already present: ${entry}"
    continue
  fi
  echo "$entry" >> "$HOSTS_FILE"
  echo "Added: ${entry}"
done

echo "Done. Open http://${DOMAIN}:<port> (e.g. http://${DOMAIN}:4444) in your browser."
