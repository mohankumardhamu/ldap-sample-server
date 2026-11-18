FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends slapd ldap-utils gettext-base ca-certificates \
 && rm -rf /var/lib/apt/lists/* /etc/ldap/slapd.d/* /var/lib/ldap/*
COPY config/ /opt/ldap/config/
COPY scripts/entrypoint.sh scripts/anon-bind.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh && ln -s /usr/local/bin/anon-bind.sh /usr/local/bin/anon-bind
EXPOSE 389
VOLUME ["/etc/ldap/slapd.d", "/var/lib/ldap"]
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
