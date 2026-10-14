#!/usr/bin/env bash
set -Eeuo pipefail

APP_ROOT="${APP_ROOT:-/www/wwwroot/nxm.zlck888.com}"
SHARED_DIR="$APP_ROOT/shared"
ENV_FILE="$SHARED_DIR/.env"
BACKUP_DIR="${BACKUP_DIR:-$SHARED_DIR/backups/daily}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
MYSQLDUMP_BIN="${MYSQLDUMP_BIN:-$(command -v mysqldump || true)}"

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

fail() {
  log "ERROR: $*"
  exit 1
}

read_env_value() {
  local key="$1"
  local value

  value="$(sed -n "s/^${key}=//p" "$ENV_FILE" | tail -n 1)"
  value="${value%$'\r'}"
  if [[ "$value" == \"*\" || "$value" == \'*\' ]]; then
    value="${value:1:${#value}-2}"
  fi
  printf '%s' "$value"
}

[[ -f "$ENV_FILE" ]] || fail "Missing site environment file"
[[ -d "$SHARED_DIR/storage/app/private" ]] || fail "Private upload directory is missing"
[[ "$RETENTION_DAYS" =~ ^[1-9][0-9]*$ ]] || fail "RETENTION_DAYS must be a positive integer"
[[ -n "$MYSQLDUMP_BIN" && -x "$MYSQLDUMP_BIN" ]] || fail "mysqldump is not available"

DB_CONNECTION="$(read_env_value DB_CONNECTION)"
DB_NAME="$(read_env_value DB_DATABASE)"
DB_USER="$(read_env_value DB_USERNAME)"
DB_PASSWORD="$(read_env_value DB_PASSWORD)"
DB_HOST="$(read_env_value DB_HOST)"
DB_PORT="$(read_env_value DB_PORT)"
DB_SOCKET="$(read_env_value DB_SOCKET)"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"

[[ "$DB_CONNECTION" == mysql || "$DB_CONNECTION" == mariadb ]] || fail "Only the site's MySQL database is supported"
[[ -n "$DB_NAME" && -n "$DB_USER" && -n "$DB_PASSWORD" ]] || fail "Database connection settings are incomplete"
[[ "$DB_NAME" =~ ^[a-zA-Z0-9_$-]+$ ]] || fail "Database name contains unsupported characters"

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
BACKUP_REAL="$(realpath "$BACKUP_DIR")"
APP_REAL="$(realpath "$APP_ROOT")"
[[ "$BACKUP_REAL" == "$APP_REAL"/* ]] || fail "Backup directory must stay inside this site root"

exec 9>"$BACKUP_DIR/.backup.lock"
flock -n 9 || fail "This site's backup is already running"

STAMP="$(date '+%Y%m%d-%H%M%S')"
DB_TMP="$BACKUP_DIR/nxm-database-$STAMP.sql.gz.tmp"
FILES_TMP="$BACKUP_DIR/nxm-private-files-$STAMP.tar.gz.tmp"
DB_ARCHIVE="${DB_TMP%.tmp}"
FILES_ARCHIVE="${FILES_TMP%.tmp}"
cleanup() {
  rm -f -- "$DB_TMP" "$FILES_TMP"
}
trap cleanup EXIT

MYSQL_ARGS=("--user=$DB_USER" "--host=$DB_HOST" "--port=$DB_PORT" --single-transaction --no-tablespaces --routines --triggers "$DB_NAME")
if [[ -n "$DB_SOCKET" ]]; then
  MYSQL_ARGS=("--user=$DB_USER" "--socket=$DB_SOCKET" --single-transaction --no-tablespaces --routines --triggers "$DB_NAME")
fi

log "Starting site database and private-upload backup"
MYSQL_PWD="$DB_PASSWORD" "$MYSQLDUMP_BIN" "${MYSQL_ARGS[@]}" | gzip -c > "$DB_TMP" \
  || fail "Database dump failed"
tar -czf "$FILES_TMP" -C "$SHARED_DIR/storage/app/private" . \
  || fail "Private upload archive failed"

gzip -t "$DB_TMP" || fail "Database archive verification failed"
gzip -t "$FILES_TMP" || fail "Private upload archive verification failed"
[[ "$(gzip -dc "$DB_TMP" | wc -c)" -gt 0 ]] || fail "Database archive is empty"
HAS_SCHEMA="$(gzip -dc "$DB_TMP" | awk '/^(CREATE TABLE|-- Current Database:|DROP TABLE)/ { found = 1 } END { print found + 0 }')"
[[ "$HAS_SCHEMA" == 1 ]] || fail "Database archive contains no schema statements"
[[ "$(gzip -dc "$FILES_TMP" | wc -c)" -gt 0 ]] || fail "Private upload archive is empty"

chmod 600 "$DB_TMP" "$FILES_TMP"
mv -- "$DB_TMP" "$DB_ARCHIVE"
mv -- "$FILES_TMP" "$FILES_ARCHIVE"
log "Verified database and private-upload archives for this site"

PHP_BIN="${PHP_BIN:-$(command -v php || true)}"
if [[ -z "$PHP_BIN" || ! -x "$PHP_BIN" ]] && [[ -x /www/server/php/83/bin/php ]]; then
  PHP_BIN=/www/server/php/83/bin/php
fi
[[ -n "$PHP_BIN" && -x "$PHP_BIN" ]] || fail "PHP CLI is not available; verified local archives have been retained"
ARTISAN="$APP_ROOT/current/backend/artisan"
[[ -f "$ARTISAN" ]] || fail "Current release Artisan entry point is missing; verified local archives have been retained"
"$PHP_BIN" "$ARTISAN" site:backup:oss --database="$DB_ARCHIVE" --files="$FILES_ARCHIVE" \
  || fail "OSS backup failed; verified local archives have been retained"

find "$BACKUP_DIR" -maxdepth 1 -type f \
  \( -name 'nxm-database-*.sql.gz' -o -name 'nxm-private-files-*.tar.gz' \) \
  -mtime "+$RETENTION_DAYS" -delete
log "Removed only this site's archives older than $RETENTION_DAYS days"
