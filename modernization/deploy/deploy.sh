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
SKIP_LOGIN_HEALTH="${SKIP_LOGIN_HEALTH:-0}"
RELOAD_NGINX="${RELOAD_NGINX:-0}"
DB_BACKUP_DIR="${DB_BACKUP_DIR:-}"

RELEASE_ID="$(date +%Y%m%d%H%M%S)"
RELEASE_DIR="$APP_ROOT/releases/$RELEASE_ID"
SOURCE_DIR="$RELEASE_DIR/source"
BACKEND_DIR="$RELEASE_DIR/backend"
PUBLIC_DIR="$RELEASE_DIR/public"
SHARED_DIR="$APP_ROOT/shared"
CURRENT_LINK="$APP_ROOT/current"

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

fail() {
  printf '[deploy failed] %s\n' "$*" >&2
  exit 1
}

command -v git >/dev/null 2>&1 || fail "git is not installed"
[ -x "$PHP_BIN" ] || fail "PHP binary not found: $PHP_BIN"
command -v "$NODE_BIN" >/dev/null 2>&1 || fail "node is not installed or NODE_BIN is wrong"
command -v "$NPM_BIN" >/dev/null 2>&1 || fail "npm is not installed or NPM_BIN is wrong"
mkdir -p "$APP_ROOT"
exec 9>"$APP_ROOT/.deploy.lock"
flock -n 9 || fail "Another deployment is already running for $APP_ROOT."

if [ ! -f "$APP_ROOT/shared/.env" ] && [ ! -f "$APP_ROOT/backend/.env" ]; then
  fail "Missing shared/.env and legacy backend/.env; refusing to prepare a release without production configuration."
fi

ENV_FILE="$APP_ROOT/shared/.env"
[ -f "$ENV_FILE" ] || ENV_FILE="$APP_ROOT/backend/.env"
HEALTH_CHECK_USERNAME="$(grep -E '^HEALTH_CHECK_USERNAME=' "$ENV_FILE" | tail -n 1 | cut -d= -f2- | tr -d '\"' || true)"
HEALTH_CHECK_PASSWORD="$(grep -E '^HEALTH_CHECK_PASSWORD=' "$ENV_FILE" | tail -n 1 | cut -d= -f2- | tr -d '\"' || true)"
if [ -z "$HEALTH_CHECK_USERNAME" ] || [ -z "$HEALTH_CHECK_PASSWORD" ]; then
  [ "$SKIP_LOGIN_HEALTH" = "1" ] || fail "login health credentials missing: configure HEALTH_CHECK_USERNAME and HEALTH_CHECK_PASSWORD before deployment."
  log "WARNING: SKIP_LOGIN_HEALTH=1; login health checks will be skipped"
elif [ "${#HEALTH_CHECK_PASSWORD}" -lt 20 ]; then
  fail "HEALTH_CHECK_PASSWORD must contain at least 20 characters."
fi

PREVIOUS_RELEASE=""
if [ -L "$CURRENT_LINK" ]; then
  PREVIOUS_RELEASE="$(readlink -f "$CURRENT_LINK" || true)"
fi
RELEASE_SWITCHED=0
DB_BACKUP_TMP=""
rollback_on_failure() {
  status=$?
  if [ "$status" -ne 0 ] && [ -n "$DB_BACKUP_TMP" ]; then
    rm -f "$DB_BACKUP_TMP"
  fi
  if [ "$status" -ne 0 ] && [ "$RELEASE_SWITCHED" = "1" ]; then
    if [ -n "$PREVIOUS_RELEASE" ] && [ -d "$PREVIOUS_RELEASE" ]; then
      log "Deployment failed; restoring previous release"
      ln -sfn "$PREVIOUS_RELEASE" "$CURRENT_LINK"
    else
      log "Deployment failed; removing current link because there was no previous release"
      rm -f "$CURRENT_LINK"
    fi
  fi
  exit "$status"
}
trap rollback_on_failure EXIT

if [ "$RUN_SEED" = "1" ]; then
  INITIAL_ADMIN_PASSWORD="$(grep -E '^INITIAL_ADMIN_PASSWORD=' "$ENV_FILE" | tail -n 1 | cut -d= -f2- | tr -d '\"' || true)"
  if [ -z "$INITIAL_ADMIN_PASSWORD" ] && [ -z "$HEALTH_CHECK_PASSWORD" ]; then
    fail "RUN_SEED=1 requires at least one explicitly configured bootstrap secret; no fixed-password accounts are created."
  fi
  if [ -n "$INITIAL_ADMIN_PASSWORD" ] && [ "${#INITIAL_ADMIN_PASSWORD}" -lt 20 ]; then
    fail "INITIAL_ADMIN_PASSWORD must contain at least 20 characters."
  fi
fi

mkdir -p "$APP_ROOT/releases" "$SHARED_DIR/storage" "$SHARED_DIR/bootstrap-cache"

if [ ! -f "$SHARED_DIR/.env" ]; then
  if [ -f "$APP_ROOT/backend/.env" ]; then
    log "Migrating existing backend .env to shared/.env"
    cp "$APP_ROOT/backend/.env" "$SHARED_DIR/.env"
  else
    fail "Missing $SHARED_DIR/.env. Copy your production .env there before deploying."
  fi
fi

if [ ! -f "$COMPOSER_BIN" ]; then
  if [ -f "$APP_ROOT/backend/composer.phar" ]; then
    log "Migrating existing composer.phar to shared"
    cp "$APP_ROOT/backend/composer.phar" "$COMPOSER_BIN"
  else
    log "Downloading Composer to shared/composer.phar"
    "$PHP_BIN" -r "copy('https://getcomposer.org/composer-stable.phar', '$COMPOSER_BIN');" \
      || fail "Unable to download Composer. Put composer.phar at $COMPOSER_BIN and retry."
  fi
fi

if [ -d "$APP_ROOT/backend/storage" ] && [ ! -e "$SHARED_DIR/storage/app" ]; then
  log "Migrating existing storage to shared/storage"
  cp -a "$APP_ROOT/backend/storage/." "$SHARED_DIR/storage/"
fi

DB_CONNECTION="$(grep -E '^DB_CONNECTION=' "$SHARED_DIR/.env" | tail -n 1 | cut -d= -f2- | tr -d '\"' || true)"
DB_CONNECTION="${DB_CONNECTION:-mysql}"
if [ "$DB_CONNECTION" = "mysql" ]; then
  MYSQLDUMP_BIN="${MYSQLDUMP_BIN:-$(command -v mysqldump || true)}"
  [ -n "$MYSQLDUMP_BIN" ] && [ -x "$MYSQLDUMP_BIN" ] || fail "mysqldump is required to back up the production database before migrations."
  DB_NAME="$(grep -E '^DB_DATABASE=' "$SHARED_DIR/.env" | tail -n 1 | cut -d= -f2- | tr -d '\"')"
  DB_USER="$(grep -E '^DB_USERNAME=' "$SHARED_DIR/.env" | tail -n 1 | cut -d= -f2- | tr -d '\"')"
  DB_PASSWORD="$(grep -E '^DB_PASSWORD=' "$SHARED_DIR/.env" | tail -n 1 | cut -d= -f2- | tr -d '\"')"
  DB_HOST="$(grep -E '^DB_HOST=' "$SHARED_DIR/.env" | tail -n 1 | cut -d= -f2- | tr -d '\"' || true)"
  DB_PORT="$(grep -E '^DB_PORT=' "$SHARED_DIR/.env" | tail -n 1 | cut -d= -f2- | tr -d '\"' || true)"
  DB_SOCKET="$(grep -E '^DB_SOCKET=' "$SHARED_DIR/.env" | tail -n 1 | cut -d= -f2- | tr -d '\"' || true)"
  [ -n "$DB_NAME" ] && [ -n "$DB_USER" ] || fail "DB_DATABASE and DB_USERNAME are required for the pre-migration backup."
  DB_HOST="${DB_HOST:-127.0.0.1}"
  DB_PORT="${DB_PORT:-3306}"
  DB_BACKUP_DIR="${DB_BACKUP_DIR:-$SHARED_DIR/backups/database}"
  mkdir -p "$DB_BACKUP_DIR"
  chmod 700 "$DB_BACKUP_DIR"
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
  DB_PATH="$(grep -E '^DB_DATABASE=' "$SHARED_DIR/.env" | tail -n 1 | cut -d= -f2- | tr -d '\"')"
  [ -f "$DB_PATH" ] || fail "SQLite database file not found; refusing migration without a backup."
  DB_BACKUP_DIR="${DB_BACKUP_DIR:-$SHARED_DIR/backups/database}"
  mkdir -p "$DB_BACKUP_DIR"
  chmod 700 "$DB_BACKUP_DIR"
  cp -p "$DB_PATH" "$DB_BACKUP_DIR/sqlite-before-${RELEASE_ID}.sqlite"
  chmod 600 "$DB_BACKUP_DIR/sqlite-before-${RELEASE_ID}.sqlite"
else
  fail "Automatic pre-migration backup is unsupported for DB_CONNECTION=$DB_CONNECTION; configure a verified backup process before deployment."
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
mkdir -p bootstrap
ln -s "$SHARED_DIR/bootstrap-cache" bootstrap/cache
cp "$COMPOSER_BIN" composer.phar

log "Installing backend dependencies"
"$PHP_BIN" composer.phar config -g policy.advisories.block false
"$PHP_BIN" composer.phar install --no-dev --optimize-autoloader --no-interaction

if ! grep -q '^APP_KEY=base64:' .env; then
  log "Generating Laravel application key"
  "$PHP_BIN" artisan key:generate --force
fi

log "Running database migrations"
"$PHP_BIN" artisan migrate --force

if [ "$RUN_SEED" = "1" ]; then
  log "Seeding system defaults and explicitly configured bootstrap accounts"
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

log "Switching current release"
ln -sfn "$RELEASE_DIR" "$CURRENT_LINK"
RELEASE_SWITCHED=1
chown -h "$WEB_USER" "$CURRENT_LINK" || true
chown -R "$WEB_USER" "$RELEASE_DIR" "$SHARED_DIR" || true

if [ "$RELOAD_NGINX" = "1" ]; then
  log "RELOAD_NGINX=1: validating and reloading the shared nginx service"
  command -v nginx >/dev/null 2>&1 || fail "nginx binary not found"
  nginx -t && /etc/init.d/nginx reload || fail "nginx validation/reload failed"
else
  log "Skipping nginx reload; the app current link changed without shared service reload"
fi

APP_URL="$(grep -E '^APP_URL=' "$SHARED_DIR/.env" | tail -n 1 | cut -d= -f2- | tr -d '\"')"
APP_URL="${APP_URL:-https://nxm.zlck888.com}"
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
  "$PHP_BIN" "$BACKEND_DIR/artisan" health:login-check --username="$HEALTH_CHECK_USERNAME" --password="$HEALTH_CHECK_PASSWORD" \
    || fail "Local login health check failed"
  log "Running HTTP login health check"
  LOGIN_PAYLOAD="$(
    APP_URL="$APP_URL" HEALTH_CHECK_USERNAME="$HEALTH_CHECK_USERNAME" HEALTH_CHECK_PASSWORD="$HEALTH_CHECK_PASSWORD" \
    "$PHP_BIN" -r '
      $base = rtrim(getenv("APP_URL"), "/");
      $captcha = json_decode(file_get_contents($base."/api/auth/captcha"), true);
      if (!is_array($captcha) || empty($captcha["captcha_id"]) || empty($captcha["question"])) {
          fwrite(STDERR, "Unable to fetch captcha\n");
          exit(2);
      }
      preg_match_all("/\d+/", $captcha["question"], $matches);
      $answer = array_sum(array_map("intval", $matches[0] ?? []));
      echo json_encode([
          "username" => getenv("HEALTH_CHECK_USERNAME"),
          "password" => getenv("HEALTH_CHECK_PASSWORD"),
          "captcha_id" => $captcha["captcha_id"],
          "captcha_answer" => $answer,
      ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    '
  )" || fail "Unable to build login health check payload"
  LOGIN_RESPONSE="$(curl -fsS -H 'Accept: application/json' -H 'Content-Type: application/json' -d "$LOGIN_PAYLOAD" "$APP_URL/api/auth/login")" \
    || fail "HTTP login health check failed"
  LOGIN_TOKEN="$(
    LOGIN_RESPONSE="$LOGIN_RESPONSE" "$PHP_BIN" -r '
      $payload = json_decode(getenv("LOGIN_RESPONSE"), true);
      echo is_array($payload) ? ($payload["token"] ?? "") : "";
    '
  )"
  [ -n "$LOGIN_TOKEN" ] || fail "HTTP login health check did not return token"
  curl -fsS -X POST -H "Accept: application/json" -H "Authorization: Bearer $LOGIN_TOKEN" "$APP_URL/api/auth/logout" >/dev/null \
    || log "WARNING: login health check logout failed; token will expire normally"
fi
"$PHP_BIN" "$BACKEND_DIR/artisan" config:show queue.default >/dev/null 2>&1 || log "WARNING: queue config health check skipped"
FAILED_JOBS_COUNT="$("$PHP_BIN" "$BACKEND_DIR/artisan" queue:failed-count 2>/dev/null || echo 0)"
if [ "$FAILED_JOBS_COUNT" != "0" ]; then
  log "WARNING: failed queue jobs exist; check the mail/queue worker"
fi

log "Deployment complete: $RELEASE_ID"
log "Website root should be: $CURRENT_LINK/public"
RELEASE_SWITCHED=0
trap - EXIT
