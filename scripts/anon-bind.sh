#!/bin/bash
# Toggle anonymous bind at runtime (no restart):  anon-bind on | off | status
# Uses the local ldapi socket as root (SASL EXTERNAL), so it must run inside the container.
set -euo pipefail
LDAPI="${LDAPI_URL:-ldapi:///}"
mod() { ldapmodify -Q -Y EXTERNAL -H "$LDAPI"; }

case "${1:-status}" in
  off)
    mod <<LDIF
dn: cn=config
changetype: modify
replace: olcDisallows
olcDisallows: bind_anon

dn: olcDatabase={-1}frontend,cn=config
changetype: modify
replace: olcRequires
olcRequires: authc

dn: olcDatabase={1}mdb,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to attrs=userPassword by self write by anonymous auth by * none
olcAccess: {1}to * by self read by users read by * none
LDIF
    echo "Anonymous bind DISABLED (clients must bind with a DN + password)";;
  on)
    mod <<LDIF
dn: cn=config
changetype: modify
replace: olcDisallows

dn: olcDatabase={-1}frontend,cn=config
changetype: modify
replace: olcRequires

dn: olcDatabase={1}mdb,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to attrs=userPassword by self write by anonymous auth by * none
olcAccess: {1}to * by self read by users read by anonymous read
LDIF
    echo "Anonymous bind ENABLED";;
  status)
    out="$(ldapsearch -LLL -Q -Y EXTERNAL -H "$LDAPI" -b cn=config -s base olcDisallows)" \
      || { echo "Cannot reach slapd on $LDAPI" >&2; exit 2; }
    grep -q bind_anon <<<"$out" && echo "Anonymous bind: DISABLED" || echo "Anonymous bind: ENABLED";;
  *) echo "usage: anon-bind on|off|status"; exit 1;;
esac
