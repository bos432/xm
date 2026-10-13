#!/usr/bin/env bash
set -Eeuo pipefail

APP_ROOT="${APP_ROOT:-/www/wwwroot/nxm.zlck888.com}"
REPO_URL="${REPO_URL:-git@github.com:bos432/xm.git}"
BRANCH="${BRANCH:-main}"
PHP_BIN="${PHP_BIN:-/www/server/php/83/bin/php}"
COMPOSER_BIN="${COMPOSER_BIN:-$APP_ROOT/shared/composer.phar}"
NODE_BIN="${NODE_BIN:-node}"
NPM_BIN="${NPM_BIN:-npm}"
FRONTEND_API_BASE="${FRONTEND_API_BASE:-/api}"
WEB_USER="${WEB_USER:-www:www}"
RUN_SEED="${RUN_SEED:-0}"
RUN_MIGRATIONS="${RUN_MIGRATIONS:-0}"
SKIP_LOGIN_HEALTH="${SKIP_LOGIN_HEALTH:-0}"
DB_BACKUP_DIR="${DB_BACKUP_DIR:-}"

RELEASE_ID="$(date +%Y%m%d%H%M%S)"
RELEASE_DIR="$APP_ROOT/releases/$RELEASE_ID"
SOURCE_DIR="$RELEASE_DIR/source"
BACKEND_DIR="$RELEASE_DIR/backend"
PUBLIC_DIR="$RELEASE_DIR/public"
SHARED_DIR="$APP_ROOT/shared"
CURRENT_LINK="$APP_ROOT/current"
PREVIOUS_CURRENT=""
DEPLOY_SWITCHED=0
DB_BACKUP_TMP=""

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

fail() {
  printf '[deploy failed] %s\n' "$*" >&2
  exit 1
}

switch_current() {
  local target="$1"
  local temporary_link="$APP_ROOT/.current-${RELEASE_ID}"

  ln -s "$target" "$temporary_link"
  mv -Tf "$temporary_link" "$CURRENT_LINK"
}

finish_deploy() {
  local status=$?
  trap - EXIT

  if [ "$status" -ne 0 ] && [ -n "$DB_BACKUP_TMP" ]; then
    rm -f "$DB_BACKUP_TMP"
  fi

  if [ "$status" -ne 0 ] && [ "$DEPLOY_SWITCHED" = "1" ]; then
    if [ -n "$PREVIOUS_CURRENT" ]; then
      local rollback_link="$APP_ROOT/.current-rollback-${RELEASE_ID}"
      if ln -s "$PREVIOUS_CURRENT" "$rollback_link" && mv -Tf "$rollback_link" "$CURRENT_LINK"; then
        log "Deployment failed; restored previous release: $PREVIOUS_CURRENT"
      else
        log "ERROR: deployment failed and automatic rollback could not restore $PREVIOUS_CURRENT"
        rm -f "$rollback_link"
      fi
    elif [ -L "$CURRENT_LINK" ]; then
      rm -f "$CURRENT_LINK"
      log "Deployment failed; removed the first-release current link"
    fi
  fi

  exit "$status"
}

trap finish_deploy EXIT

if [ -e "$CURRENT_LINK" ] && [ ! -L "$CURRENT_LINK" ]; then
  fail "Current path exists but is not a symlink: $CURRENT_LINK"
fi
if [ -L "$CURRENT_LINK" ]; then
  PREVIOUS_CURRENT="$(readlink "$CURRENT_LINK")"
fi

command -v git >/dev/null 2>&1 || fail "git is not installed"
[ -x "$PHP_BIN" ] || fail "PHP binary not found: $PHP_BIN"
command -v "$NODE_BIN" >/dev/null 2>&1 || fail "node is not installed or NODE_BIN is wrong"
command -v "$NPM_BIN" >/dev/null 2>&1 || fail "npm is not installed or NPM_BIN is wrong"

mkdir -p "$APP_ROOT/releases"
exec 9>"$APP_ROOT/.deploy.lock"
flock -n 9 || fail "Another deployment is already running for this application"
[ -f "$SHARED_DIR/.env" ] || fail "Missing $SHARED_DIR/.env. Prepare the production environment file before deploying."
[ -d "$SHARED_DIR/storage" ] || fail "Missing $SHARED_DIR/storage. Prepare persistent application storage before deploying."
[ -f "$COMPOSER_BIN" ] || fail "Composer not found at $COMPOSER_BIN. Install it in shared before deploying."

grep -q '^APP_KEY=base64:' "$SHARED_DIR/.env" || fail "APP_KEY is missing from shared/.env; refusing to generate or change the production encryption key during deployment"
APP_URL="$(grep -E '^APP_URL=' "$SHARED_DIR/.env" | tail -n 1 | cut -d= -f2- | tr -d '\"')"
APP_URL="${APP_URL:-https://nxm.zlck888.com}"
case "$APP_URL" in
  https://nxm.zlck888.com|https://nxm.zlck888.com/*) ;;
  *) fail "APP_URL must target https://nxm.zlck888.com; refusing to send health checks to another host" ;;
esac

HEALTH_CHECK_USERNAME="$(grep -E '^HEALTH_CHECK_USERNAME=' "$SHARED_DIR/.env" | tail -n 1 | cut -d= -f2- | tr -d '\"' || true)"
HEALTH_CHECK_PASSWORD="$(grep -E '^HEALTH_CHECK_PASSWORD=' "$SHARED_DIR/.env" | tail -n 1 | cut -d= -f2- | tr -d '\"' || true)"
if [ -z "$HEALTH_CHECK_USERNAME" ] || [ -z "$HEALTH_CHECK_PASSWORD" ]; then
  [ "$SKIP_LOGIN_HEALTH" = "1" ] || fail "login health credentials missing; configure them in shared/.env or explicitly set SKIP_LOGIN_HEALTH=1"
  log "WARNING: login health credentials missing; SKIP_LOGIN_HEALTH=1"
elif [ "${#HEALTH_CHECK_PASSWORD}" -lt 20 ]; then
  fail "HEALTH_CHECK_PASSWORD must contain at least 20 characters; configure a new random password before deploying"
fi

if [ "$RUN_MIGRATIONS" = "1" ]; then
  DB_CONNECTION="$(grep -E '^DB_CONNECTION=' "$SHARED_DIR/.env" | tail -n 1 | cut -d= -f2- | tr -d '\"' || true)"
  DB_CONNECTION="${DB_CONNECTION:-mysql}"
  DB_BACKUP_DIR="${DB_BACKUP_DIR:-$SHARED_DIR/backups/database}"
  mkdir -p "$DB_BACKUP_DIR"
  chmod 700 "$DB_BACKUP_DIR"

  if [ "$DB_CONNECTION" = "mysql" ]; then
    MYSQLDUMP_BIN="${MYSQLDUMP_BIN:-$(command -v mysqldump || true)}"
    [ -n "$MYSQLDUMP_BIN" ] && [ -x "$MYSQLDUMP_BIN" ] || fail "mysqldump is required before database migrations."
    DB_NAME="$(grep -E '^DB_DATABASE=' "$SHARED_DIR/.env" | tail -n 1 | cut -d= -f2- | tr -d '\"' || true)"
    DB_USER="$(grep -E '^DB_USERNAME=' "$SHARED_DIR/.env" | tail -n 1 | cut -d= -f2- | tr -d '\"' || true)"
    DB_PASSWORD="$(grep -E '^DB_PASSWORD=' "$SHARED_DIR/.env" | tail -n 1 | cut -d= -f2- | tr -d '\"' || true)"
    DB_HOST="$(grep -E '^DB_HOST=' "$SHARED_DIR/.env" | tail -n 1 | cut -d= -f2- | tr -d '\"' || true)"
    DB_PORT="$(grep -E '^DB_PORT=' "$SHARED_DIR/.env" | tail -n 1 | cut -d= -f2- | tr -d '\"' || true)"
    DB_SOCKET="$(grep -E '^DB_SOCKET=' "$SHARED_DIR/.env" | tail -n 1 | cut -d= -f2- | tr -d '\"' || true)"
    [ -n "$DB_NAME" ] && [ -n "$DB_USER" ] || fail "DB_DATABASE and DB_USERNAME are required for the pre-migration backup."
    DB_HOST="${DB_HOST:-127.0.0.1}"
    DB_PORT="${DB_PORT:-3306}"
    DB_BACKUP_FILE="$DB_BACKUP_DIR/${DB_NAME}-before-${RELEASE_ID}.sql.gz"
    DB_BACKUP_TMP="$DB_BACKUP_FILE.tmp"
    log "Backing up database before migration to $DB_BACKUP_FILE"
    if [ -n "$DB_SOCKET" ]; then
      MYSQL_PWD="$DB_PASSWORD" "$MYSQLDUMP_BIN" --user="$DB_USER" --socket="$DB_SOCKET" --single-transaction --routines --triggers "$DB_NAME" | gzip -c > "$DB_BACKUP_TMP" \
        || fail "Database backup failed; migration was not started."
    else
      MYSQL_PWD="$DB_PASSWORD" "$MYSQLDUMP_BIN" --user="$DB_USER" --host="$DB_HOST" --port="$DB_PORT" --single-transaction --routines --triggers "$DB_NAME" | gzip -c > "$DB_BACKUP_TMP" \
        || fail "Database backup failed; migration was not started."
    fi
    chmod 600 "$DB_BACKUP_TMP"
    gzip -t "$DB_BACKUP_TMP" || fail "Database backup archive verification failed; migration was not started."
    DB_BACKUP_SIZE="$(gzip -dc "$DB_BACKUP_TMP" | wc -c)"
    [ "$DB_BACKUP_SIZE" -gt 0 ] || fail "Database backup is empty; migration was not started."
    mv "$DB_BACKUP_TMP" "$DB_BACKUP_FILE"
    DB_BACKUP_TMP=""
  elif [ "$DB_CONNECTION" = "sqlite" ]; then
    DB_PATH="$(grep -E '^DB_DATABASE=' "$SHARED_DIR/.env" | tail -n 1 | cut -d= -f2- | tr -d '\"' || true)"
    case "$DB_PATH" in
      /*) ;;
      *) fail "SQLite DB_DATABASE must be an absolute path so the correct persistent database can be backed up." ;;
    esac
    [ -f "$DB_PATH" ] || fail "SQLite database file not found; refusing migrations without a backup."
    DB_BACKUP_FILE="$DB_BACKUP_DIR/sqlite-before-${RELEASE_ID}.sqlite"
    cp -p "$DB_PATH" "$DB_BACKUP_FILE"
    chmod 600 "$DB_BACKUP_FILE"
  else
    fail "Automatic pre-migration backup is unsupported for DB_CONNECTION=$DB_CONNECTION."
  fi
fi

log "Cloning $REPO_URL#$BRANCH"
git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$SOURCE_DIR"

log "Building frontend"
cd "$SOURCE_DIR/modernization/frontend"
if ! "$NPM_BIN" ci --include=dev --include=optional --no-audit --no-fund; then
  log "WARNING: npm ci failed, falling back to npm install for platform optional dependencies"
  "$NPM_BIN" install --include=dev --include=optional --no-audit --no-fund
fi
[ -x "node_modules/.bin/vite" ] || fail "Frontend build dependency vite is missing; check npm dev dependency installation"
log "Using frontend API base: $FRONTEND_API_BASE"
VITE_API_BASE="$FRONTEND_API_BASE" "$NPM_BIN" run build

log "Preparing release directories"
cp -a "$SOURCE_DIR/modernization/backend" "$BACKEND_DIR"
cp -a "$SOURCE_DIR/modernization/frontend/dist" "$PUBLIC_DIR"

log "Applying production compatibility patches"
sed -i "s/->json(/->longText(/g" "$BACKEND_DIR/database/migrations/2026_06_06_000001_create_modernization_core_tables.php"
sed -i "s/string('key')->primary()/string('key', 191)->primary()/g" "$BACKEND_DIR/database/migrations/2026_06_06_000002_create_runtime_support_tables.php"
sed -i "s/string('owner')/string('owner', 191)/g" "$BACKEND_DIR/database/migrations/2026_06_06_000002_create_runtime_support_tables.php"
sed -i "s/string('id')->primary()/string('id', 191)->primary()/g" "$BACKEND_DIR/database/migrations/2026_06_06_000002_create_runtime_support_tables.php"
sed -i "s/string('queue')->index()/string('queue', 191)->index()/g" "$BACKEND_DIR/database/migrations/2026_06_06_000002_create_runtime_support_tables.php"
sed -i "s/string('name')/string('name', 191)/g" "$BACKEND_DIR/database/migrations/2026_06_06_000002_create_runtime_support_tables.php"
sed -i "s/string('uuid')->unique()/string('uuid', 191)->unique()/g" "$BACKEND_DIR/database/migrations/2026_06_06_000002_create_runtime_support_tables.php"

log "Linking shared backend runtime files"
cd "$BACKEND_DIR"
rm -rf storage bootstrap/cache
ln -s "$SHARED_DIR/.env" .env
ln -s "$SHARED_DIR/storage" storage
mkdir -p bootstrap/cache
cp "$COMPOSER_BIN" composer.phar

log "Installing site-local queue watchdog"
mkdir -p "$SHARED_DIR/bin"
install -m 750 "$SOURCE_DIR/modernization/deploy/queue-worker-watchdog.sh" "$SHARED_DIR/bin/queue-worker-watchdog.sh"
chown "$WEB_USER" "$SHARED_DIR/bin/queue-worker-watchdog.sh" || fail "Could not assign the queue watchdog to $WEB_USER"

log "Installing backend dependencies"
export COMPOSER_HOME="$BACKEND_DIR/.composer"
mkdir -p "$COMPOSER_HOME"
"$PHP_BIN" composer.phar install --no-dev --optimize-autoloader --no-interaction

if [ "$RUN_MIGRATIONS" = "1" ]; then
  log "Running database migrations; verified backup created and schema changes are not automatically reversible"
  "$PHP_BIN" artisan migrate --force
else
  log "Database migrations skipped; set RUN_MIGRATIONS=1 only after reviewing pending migrations and backing up the app database"
fi

if [ "$RUN_SEED" = "1" ]; then
  log "Seeding configured bootstrap accounts and system defaults"
  "$PHP_BIN" artisan db:seed --force
fi

log "Refreshing Laravel caches"
"$PHP_BIN" artisan config:clear
"$PHP_BIN" artisan route:clear
"$PHP_BIN" artisan config:cache
"$PHP_BIN" artisan route:cache

log "Ensuring public storage link"
rm -rf "$PUBLIC_DIR/storage"
ln -s "$SHARED_DIR/storage/app/public" "$PUBLIC_DIR/storage"

chown -R "$WEB_USER" "$RELEASE_DIR" || true

log "Switching current release"
switch_current "$RELEASE_DIR"
DEPLOY_SWITCHED=1
chown -h "$WEB_USER" "$CURRENT_LINK" || true

log "Activated the release through the site current symlink; no shared services were reloaded"

log "Running deployment health checks for $APP_URL"
curl -fsSI "$APP_URL/" >/dev/null || fail "Homepage health check failed"
curl -fsS "$APP_URL/api/auth/captcha" >/dev/null || fail "Captcha API health check failed"
curl -fsS "$APP_URL/api/public/homepage" >/dev/null || fail "Public homepage API health check failed"
if [ -z "$HEALTH_CHECK_USERNAME" ] || [ -z "$HEALTH_CHECK_PASSWORD" ]; then
  if [ "$SKIP_LOGIN_HEALTH" = "1" ]; then
    log "WARNING: login health credentials missing; SKIP_LOGIN_HEALTH=1, login health checks skipped"
  else
    fail "login health credentials missing: set HEALTH_CHECK_USERNAME and HEALTH_CHECK_PASSWORD in shared/.env, or set SKIP_LOGIN_HEALTH=1"
  fi
else
  "$PHP_BIN" "$BACKEND_DIR/artisan" health:login-check \
    || fail "Local login health check failed"
  log "Local credential validation and HTTPS captcha/login/logout health check passed"
fi
"$PHP_BIN" "$BACKEND_DIR/artisan" config:show queue.default >/dev/null 2>&1 || log "WARNING: queue config health check skipped"
FAILED_JOBS_COUNT="$("$PHP_BIN" "$BACKEND_DIR/artisan" queue:failed-count 2>/dev/null || echo 0)"
if [ "$FAILED_JOBS_COUNT" != "0" ]; then
  log "WARNING: failed queue jobs exist; check the mail/queue worker"
fi

log "Deployment complete: $RELEASE_ID"
log "Website root should be: $CURRENT_LINK/public"
