#!/bin/bash
# Bootstraps OpenLDAP on first start (anonymous bind ON), then runs slapd.
set -euo pipefail

export LDAP_DOMAIN="${LDAP_DOMAIN:-example.com}"
export LDAP_ORGANISATION="${LDAP_ORGANISATION:-Example Corp}"
export LDAP_BASE_DN="${LDAP_BASE_DN:-dc=$(echo "$LDAP_DOMAIN" | sed 's/\./,dc=/g')}"
export LDAP_DC="${LDAP_DOMAIN%%.*}"
export LDAP_CONF_DIR="${LDAP_CONF_DIR:-/etc/ldap/slapd.d}"
export LDAP_DATA_DIR="${LDAP_DATA_DIR:-/var/lib/ldap}"
export LDAP_RUN_DIR="${LDAP_RUN_DIR:-/run/slapd}"
LDAP_URLS="${LDAP_URLS:-ldap:/// ldapi:///}"
TEMPLATES="${LDAP_TEMPLATES:-/opt/ldap/config}"
RUN_AS="${LDAP_RUN_AS:-openldap}"

mkdir -p "$LDAP_CONF_DIR" "$LDAP_DATA_DIR" "$LDAP_RUN_DIR"

if [ ! -e "$LDAP_CONF_DIR/cn=config.ldif" ]; then
  echo "[entrypoint] First start: creating $LDAP_BASE_DN"
  export ADMIN_HASH="$(slappasswd -s "${LDAP_ADMIN_PASSWORD:-admin123}")"
  export USER_HASH="$(slappasswd -s "${LDAP_USER_PASSWORD:-Passw0rd!}")"
  export SVC_HASH="$(slappasswd -s "${LDAP_SVC_PASSWORD:-SvcPassw0rd!}")"
  tmp="$(mktemp -d)"
  envsubst < "$TEMPLATES/slapd-config.ldif" > "$tmp/config.ldif"
  envsubst < "$TEMPLATES/seed.ldif"         > "$tmp/seed.ldif"
  slapadd -n0 -F "$LDAP_CONF_DIR" -l "$tmp/config.ldif"
  slapadd -n1 -F "$LDAP_CONF_DIR" -l "$tmp/seed.ldif"
  rm -rf "$tmp"
fi

if [ -n "$RUN_AS" ] && id "$RUN_AS" >/dev/null 2>&1; then
  chown -R "$RUN_AS:$RUN_AS" "$LDAP_CONF_DIR" "$LDAP_DATA_DIR" "$LDAP_RUN_DIR"
  exec slapd -h "$LDAP_URLS" -u "$RUN_AS" -g "$RUN_AS" -F "$LDAP_CONF_DIR" -d "${LDAP_LOG_LEVEL:-stats}"
fi
exec slapd -h "$LDAP_URLS" -F "$LDAP_CONF_DIR" -d "${LDAP_LOG_LEVEL:-stats}"
