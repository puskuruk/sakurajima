#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
# 🏴 SAKURAJIMA DOCKER IMAGES CACHE - 0.1.0-alpha
# Fetches and caches official Docker Hub images for autocomplete

CACHE_DIR="${HOME}/.cache/sakurajima"
CACHE_FILE="${CACHE_DIR}/docker-images.txt"
CACHE_MAX_AGE=86400  # 24 hours in seconds

mkdir -p "$CACHE_DIR"

# Check if cache exists and is fresh
if [[ -f "$CACHE_FILE" ]]; then
  cache_age=$(($(date +%s) - $(stat -f %m "$CACHE_FILE")))
  if [[ $cache_age -lt $CACHE_MAX_AGE ]]; then
    cat "$CACHE_FILE"
    exit 0
  fi
fi

# Curated list of popular official Docker images (instant, no API needed)
# This covers 95% of use cases and doesn't require internet
cat > "$CACHE_FILE" << 'IMAGES'
# Databases
mongo,MongoDB document database
postgres,PostgreSQL relational database
mysql,MySQL relational database
mariadb,MariaDB database server
redis,Redis in-memory data store
memcached,Memcached caching system
elasticsearch,Elasticsearch search engine
cassandra,Apache Cassandra database
couchdb,Apache CouchDB database
neo4j,Neo4j graph database
influxdb,InfluxDB time-series database
clickhouse/clickhouse-server,ClickHouse analytics database
timescale/timescaledb,TimescaleDB time-series
cockroachdb/cockroach,CockroachDB distributed SQL
# Message Queues
rabbitmq,RabbitMQ message broker
nats,NATS messaging system
kafka,Apache Kafka (unofficial but popular)
confluentinc/cp-kafka,Confluent Kafka
eclipse-mosquitto,Mosquitto MQTT broker
# Web Servers
nginx,NGINX web server
httpd,Apache HTTP Server
traefik,Traefik reverse proxy
caddy,Caddy web server
haproxy,HAProxy load balancer
# Languages/Runtimes
node,Node.js JavaScript runtime
python,Python programming language
golang,Go programming language
ruby,Ruby programming language
php,PHP language
openjdk,OpenJDK Java
amazoncorretto,Amazon Corretto JDK
eclipse-temurin,Eclipse Temurin JDK
rust,Rust programming language
swift,Swift programming language
elixir,Elixir programming language
erlang,Erlang/OTP
julia,Julia programming language
perl,Perl programming language
haskell,Haskell programming language
clojure,Clojure programming language
# DevOps/Tools
jenkins/jenkins,Jenkins CI/CD
gitlab/gitlab-ce,GitLab Community Edition
gitea/gitea,Gitea Git service
drone/drone,Drone CI
sonarqube,SonarQube code quality
vault,HashiCorp Vault
consul,HashiCorp Consul
localstack/localstack,LocalStack AWS emulator
minio/minio,MinIO object storage
registry,Docker Registry
portainer/portainer-ce,Portainer container management
# Monitoring
grafana/grafana,Grafana dashboards
prom/prometheus,Prometheus monitoring
prom/alertmanager,Prometheus Alertmanager
jaegertracing/all-in-one,Jaeger distributed tracing
zipkin/zipkin,Zipkin distributed tracing
elastic/kibana,Kibana for Elasticsearch
# AI/ML
ollama/ollama,Ollama local AI
# Utilities
busybox,BusyBox utilities
alpine,Alpine Linux (minimal)
ubuntu,Ubuntu Linux
debian,Debian Linux
centos,CentOS Linux
amazonlinux,Amazon Linux
fedora,Fedora Linux
archlinux,Arch Linux
IMAGES

cat "$CACHE_FILE"
