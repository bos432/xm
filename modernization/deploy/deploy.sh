#!/usr/bin/env bash
set -Eeuo pipefail

APP_ROOT="${APP_ROOT:-/www/wwwroot/nxm.zlck888.com}"
REPO_URL="${REPO_URL:-https://github.com/bos432/xm.git}"
BRANCH="${BRANCH:-main}"
PHP_BIN="${PHP_BIN:-/www/server/php/83/bin/php}"
COMPOSER_BIN="${COMPOSER_BIN:-$APP_ROOT/shared/composer.phar}"
NODE_BIN="${NODE_BIN:-node}"
NPM_BIN="${NPM_BIN:-npm}"
WEB_USER="${WEB_USER:-www:www}"

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
    fail "Missing composer.phar. Expected $COMPOSER_BIN"
  fi
fi

if [ -d "$APP_ROOT/backend/storage" ] && [ ! -e "$SHARED_DIR/storage/app" ]; then
  log "Migrating existing storage to shared/storage"
  cp -a "$APP_ROOT/backend/storage/." "$SHARED_DIR/storage/"
fi

log "Cloning $REPO_URL#$BRANCH"
git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$SOURCE_DIR"

log "Building frontend"
cd "$SOURCE_DIR/modernization/frontend"
"$NPM_BIN" ci
"$NPM_BIN" run build

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
"$PHP_BIN" composer.phar install --no-dev --optimize-autoloader --no-interaction

log "Running database migrations"
"$PHP_BIN" artisan migrate --force

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
chown -h "$WEB_USER" "$CURRENT_LINK" || true
chown -R "$WEB_USER" "$RELEASE_DIR" "$SHARED_DIR" || true

log "Reloading nginx if available"
if command -v nginx >/dev/null 2>&1; then
  nginx -t && /etc/init.d/nginx reload || fail "nginx reload failed"
fi

log "Deployment complete: $RELEASE_ID"
log "Website root should be: $CURRENT_LINK/public"
