# OpenLDAP test server — anonymous bind enabled

A throwaway OpenLDAP 2.6 server (Ubuntu 24.04) for testing UAA's LDAP integration.
It starts with **anonymous bind ON** and includes a script to turn it off and on at runtime,
so you can reproduce the switch from anonymous to authenticated bind locally.

## Start
```bash
docker compose up -d --build
docker compose logs -f openldap      # wait for "slapd starting"
```
Port 389 is published on the host. If 389 is taken or needs root, change it to `"1389:389"`.

## What's inside  (base DN: dc=example,dc=com)
| Entry | DN | Password |
|---|---|---|
| Admin (rootDN) | cn=admin,dc=example,dc=com | admin123 |
| User | uid=alice,ou=People,dc=example,dc=com | Passw0rd! |
| User | uid=bob,ou=People,dc=example,dc=com | Passw0rd! |
| Service account | cn=svc-uaa-ldap,ou=ServiceAccounts,dc=example,dc=com | SvcPassw0rd! |
| Group | cn=uaa-admins,ou=Groups,… (alice) | – |
| Group | cn=uaa-users,ou=Groups,… (alice, bob) | – |

Passwords are set in `docker-compose.yml`. They're applied only on the **first** start;
to change them later, run `docker compose down -v` to wipe the volumes, then start again.

Access rules: anonymous clients can search and read everything **except** `userPassword`,
and can still bind as a user to check that user's password.

## Test
```bash
# Anonymous search (no -D) — works while anonymous bind is ON
ldapsearch -x -H ldap://localhost:389 -b dc=example,dc=com "(uid=alice)"

# User login check
ldapwhoami -x -H ldap://localhost:389 -D uid=alice,ou=People,dc=example,dc=com -w 'Passw0rd!'

# Search as the service account
ldapsearch -x -H ldap://localhost:389 \
  -D cn=svc-uaa-ldap,ou=ServiceAccounts,dc=example,dc=com -w 'SvcPassw0rd!' \
  -b ou=People,dc=example,dc=com "(uid=bob)"
```
No ldap-utils on your host? Prefix the commands with `docker exec openldap`.

## Toggle anonymous bind (no restart)
```bash
docker exec openldap anon-bind status
docker exec openldap anon-bind off   # anon search -> "ldap_bind: Inappropriate authentication (48)"
docker exec openldap anon-bind on
```
`off` sets `olcDisallows: bind_anon` and `olcRequires: authc`, and removes anonymous read
from the ACL — the same effect as disabling anonymous bind on a corporate directory.

## UAA config
Anonymous bind ON (search-and-bind with no service account):
```yaml
ldap:
  profile: { file: ldap/ldap-search-and-bind.xml }
  base:
    url: ldap://<docker-host>:389
    userDn: ''
    password: ''
    searchBase: ou=People,dc=example,dc=com
    searchFilter: uid={0}
  groups:
    file: ldap/ldap-groups-map-to-scopes.xml
    searchBase: ou=Groups,dc=example,dc=com
    groupSearchFilter: member={0}
```
After `anon-bind off`, set `userDn: cn=svc-uaa-ldap,ou=ServiceAccounts,dc=example,dc=com`
and `password: SvcPassw0rd!`, or inject both from Vault.
Leaving them blank should reproduce the failure you hit.

Plain `ldap://` is fine for local testing only — use LDAPS for anything real.
