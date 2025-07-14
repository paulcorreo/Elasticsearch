#!/bin/sh

# Obtener info del host
HOSTNAME=$(hostname)
IP=$(hostname -i)

# URL de Elasticsearch
ES_URL="http://elasticsearch:9200"
INDEX="jboss-logs"

echo "Esperando a Elasticsearch..."
until curl -s "$ES_URL" >/dev/null; do
  sleep 2
done

echo "Verificando si el índice '$INDEX' existe..."

if ! curl -s -o /dev/null -w "%{http_code}" "$ES_URL/$INDEX" | grep -q "200"; then
  echo "Índice no existe. Creando con mapping correcto..."
  curl -s -X PUT "$ES_URL/$INDEX" -H 'Content-Type: application/json' -d '{
    "mappings": {
      "properties": {
        "@timestamp": { "type": "date" },
        "level": { "type": "keyword" },
        "logger": { "type": "keyword" },
        "thread": { "type": "keyword" },
        "hostname": { "type": "keyword" },
        "ip": { "type": "ip" },
        "message": { "type": "text" }
      }
    }
  }'
  echo "Índice creado."
else
  echo "Índice ya existe. Continuando..."
fi

echo "Enviando logs estilo JBoss..."

while true; do
  TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%S.%3NZ')
  LEVEL=$(shuf -n1 -e INFO WARN ERROR DEBUG)
  THREAD=$(shuf -n1 -e "ServerService Thread Pool -- 19" "Controller Boot Thread" "EJB default - 5" "management-handler-thread")
  LOGGER=$(shuf -n1 -e "org.jboss.as.controller" "org.jboss.as.server" "org.jboss.as.ejb3" "org.jboss.as.security" "org.jboss.modules")
  MESSAGE=$(shuf -n1 -e \
    "WFLYSRV0010: Deployed \"myapp.war\" (runtime-name : \"myapp.war\")" \
    "WFLYCTL0183: Service status report" \
    "WFLYSRV0025: JBoss EAP 7.4.0 started" \
    "WFLYSEC0027: Security realm ManagementRealm using cache" \
    "WFLYEJB0473: JNDI bindings for HelloBean")

  # Formato JSON
  JSON_LOG=$(jq -n \
    --arg ts "$TIMESTAMP" \
    --arg level "$LEVEL" \
    --arg logger "$LOGGER" \
    --arg thread "$THREAD" \
    --arg host "$HOSTNAME" \
    --arg ip "$IP" \
    --arg msg "$MESSAGE" \
    '{ "@timestamp": $ts, "level": $level, "logger": $logger, "thread": $thread, "hostname": $host, "ip": $ip, "message": $msg }')

  curl -s -H "Content-Type: application/json" -XPOST "$ES_URL/$INDEX/_doc" -d "$JSON_LOG" >/dev/null

  echo "$TIMESTAMP $LEVEL [$LOGGER] ($THREAD) [host=$HOSTNAME, ip=$IP] $MESSAGE"

  sleep 2
done

