FROM adoptopenjdk/openjdk11:jre-11.0.8_10-alpine

# symlink JVM
RUN mkdir -p /usr/lib/jvm/default-jvm /usr/java/latest \
    && ln -sf /opt/java/openjdk /usr/lib/jvm/default-jvm/jre \
    && ln -sf /usr/lib/jvm/default-jvm/jre /usr/java/latest/jre

# ===============
# Alpine packages
# ===============

RUN apk update \
    && apk add --no-cache openssl py3-pip tini curl \
    && apk add --no-cache --virtual build-deps wget git gcc musl-dev python3-dev libffi-dev openssl-dev

# =====
# Jetty
# =====

ARG JETTY_VERSION=9.4.26.v20200117
ARG JETTY_HOME=/opt/jetty
ARG JETTY_BASE=/opt/jans/jetty
ARG JETTY_USER_HOME_LIB=/home/jetty/lib

# Install jetty
RUN wget -q https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-distribution/${JETTY_VERSION}/jetty-distribution-${JETTY_VERSION}.tar.gz -O /tmp/jetty.tar.gz \
    && mkdir -p /opt \
    && tar -xzf /tmp/jetty.tar.gz -C /opt \
    && mv /opt/jetty-distribution-${JETTY_VERSION} ${JETTY_HOME} \
    && rm -rf /tmp/jetty.tar.gz

# Ports required by jetty
EXPOSE 8080

# =====
# FIDO2
# =====

ENV CN_VERSION=5.0.0-SNAPSHOT
ENV CN_BUILD_DATE="2020-11-09 13:03"
ENV CN_SOURCE_URL=https://maven.jans.io/maven/io/jans/jans-fido2-server/${CN_VERSION}/jans-fido2-server-${CN_VERSION}.war

# Install FIDO2
RUN wget -q ${CN_SOURCE_URL} -O /tmp/fido2.war \
    && mkdir -p ${JETTY_BASE}/jans-fido2/webapps/jans-fido2 \
    && unzip -qq /tmp/fido2.war -d ${JETTY_BASE}/jans-fido2/webapps/jans-fido2 \
    && java -jar ${JETTY_HOME}/start.jar jetty.home=${JETTY_HOME} jetty.base=${JETTY_BASE}/jans-fido2 --add-to-start=server,deploy,resources,http,http-forwarded,threadpool,jsp \
    && rm -f /tmp/fido2.war

# ======
# Python
# ======

RUN apk add --no-cache #py3-cryptography
COPY requirements.txt /app/requirements.txt
RUN pip3 install -U pip wheel \
    && pip3 install --no-cache-dir -r /app/requirements.txt \
    && rm -rf /src/jans-pycloudlib/.git

# =======
# Cleanup
# =======

RUN apk del build-deps \
    && rm -rf /var/cache/apk/*

# =======
# License
# =======

RUN mkdir -p /licenses
COPY LICENSE /licenses/

# ==========
# Config ENV
# ==========

ENV CN_CONFIG_ADAPTER=consul \
    CN_CONFIG_CONSUL_HOST=localhost \
    CN_CONFIG_CONSUL_PORT=8500 \
    CN_CONFIG_CONSUL_CONSISTENCY=stale \
    CN_CONFIG_CONSUL_SCHEME=http \
    CN_CONFIG_CONSUL_VERIFY=false \
    CN_CONFIG_CONSUL_CACERT_FILE=/etc/certs/consul_ca.crt \
    CN_CONFIG_CONSUL_CERT_FILE=/etc/certs/consul_client.crt \
    CN_CONFIG_CONSUL_KEY_FILE=/etc/certs/consul_client.key \
    CN_CONFIG_CONSUL_TOKEN_FILE=/etc/certs/consul_token \
    CN_CONFIG_CONSUL_NAMESPACE=jans \
    CN_CONFIG_KUBERNETES_NAMESPACE=default \
    CN_CONFIG_KUBERNETES_CONFIGMAP=jans \
    CN_CONFIG_KUBERNETES_USE_KUBE_CONFIG=false

# ==========
# Secret ENV
# ==========

ENV CN_SECRET_ADAPTER=vault \
    CN_SECRET_VAULT_SCHEME=http \
    CN_SECRET_VAULT_HOST=localhost \
    CN_SECRET_VAULT_PORT=8200 \
    CN_SECRET_VAULT_VERIFY=false \
    CN_SECRET_VAULT_ROLE_ID_FILE=/etc/certs/vault_role_id \
    CN_SECRET_VAULT_SECRET_ID_FILE=/etc/certs/vault_secret_id \
    CN_SECRET_VAULT_CERT_FILE=/etc/certs/vault_client.crt \
    CN_SECRET_VAULT_KEY_FILE=/etc/certs/vault_client.key \
    CN_SECRET_VAULT_CACERT_FILE=/etc/certs/vault_ca.crt \
    CN_SECRET_VAULT_NAMESPACE=jans \
    CN_SECRET_KUBERNETES_NAMESPACE=default \
    CN_SECRET_KUBERNETES_SECRET=jans \
    CN_SECRET_KUBERNETES_USE_KUBE_CONFIG=false

# ===============
# Persistence ENV
# ===============

ENV CN_PERSISTENCE_TYPE=ldap \
    CN_PERSISTENCE_LDAP_MAPPING=default \
    CN_LDAP_URL=localhost:1636 \
    CN_COUCHBASE_URL=localhost \
    CN_COUCHBASE_USER=admin \
    CN_COUCHBASE_CERT_FILE=/etc/certs/couchbase.crt \
    CN_COUCHBASE_PASSWORD_FILE=/etc/jans/conf/couchbase_password \
    CN_COUCHBASE_CONN_TIMEOUT=10000 \
    CN_COUCHBASE_CONN_MAX_WAIT=20000 \
    CN_COUCHBASE_SCAN_CONSISTENCY=not_bounded

# ===========
# Generic ENV
# ===========

ENV CN_MAX_RAM_PERCENTAGE=75.0 \
    CN_WAIT_MAX_TIME=300 \
    CN_WAIT_SLEEP_DURATION=10 \
    CN_JAVA_OPTIONS="" \
    CN_SSL_CERT_FROM_SECRETS=false \
    CN_NAMESPACE=jans

# ==========
# misc stuff
# ==========

LABEL name="FIDO2" \
    maintainer="Janssen io <support@jans.io>" \
    vendor="Janssen Project" \
    version="5.0.0" \
    release="dev" \
    summary="Janssen FIDO2" \
    description="FIDO2 server"

RUN mkdir -p /etc/certs /deploy \
    /etc/jans/conf \
    /app/templates

COPY jetty/*.xml ${JETTY_BASE}/jans-fido2/webapps/
COPY conf/*.tmpl /app/templates/
COPY conf/fido2 /etc/jans/conf/fido2
RUN mkdir -p /etc/jans/conf/fido2/mds/cert \
    /etc/jans/conf/fido2/mds/toc \
    /etc/jans/conf/fido2/server_metadata

COPY scripts /app/scripts
RUN chmod +x /app/scripts/entrypoint.sh

ENTRYPOINT ["tini", "-e", "143", "-g", "--"]
CMD ["sh", "/app/scripts/entrypoint.sh"]
