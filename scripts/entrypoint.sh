#!/bin/sh

set -e

python3 /app/scripts/wait.py

if [ ! -f /deploy/touched ]; then
    python3 /app/scripts/entrypoint.py
    touch /deploy/touched
fi

cd /opt/jans/jetty/fido2
exec java \
    -server \
    -XX:+DisableExplicitGC \
    -XX:+UseContainerSupport \
    -XX:MaxRAMPercentage=$CN_MAX_RAM_PERCENTAGE \
    -Djans.base=/etc/jans \
    -Dserver.base=/opt/jans/jetty/fido2 \
    -Dlog.base=/opt/jans/jetty/fido2 \
    -Djava.io.tmpdir=/tmp \
    ${CN_JAVA_OPTIONS} \
    -jar /opt/jetty/start.jar
