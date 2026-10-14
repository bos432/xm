#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_SCRIPT="$(cd "$SCRIPT_DIR/.." && pwd)/deploy.sh"
TEST_ROOT="$(mktemp -d)"
cleanup() {
  status=$?
  if [ "$status" -ne 0 ]; then
    printf 'Test artifacts retained at %s\n' "$TEST_ROOT" >&2
    for log_file in "$TEST_ROOT"/*.log; do
      [ -f "$log_file" ] || continue
      printf '\n--- %s ---\n' "$log_file" >&2
      cat "$log_file" >&2
    done
  else
    rm -rf "$TEST_ROOT"
  fi
}
trap cleanup EXIT

MOCK_BIN="$TEST_ROOT/bin"
APP_ROOT="$TEST_ROOT/app"
export RUN_MIGRATIONS=1
mkdir -p "$MOCK_BIN" "$APP_ROOT/shared/storage" "$APP_ROOT/shared/bootstrap-cache" \
  "$APP_ROOT/releases/previous/public" "$APP_ROOT/releases/previous/backend"
command -v flock >/dev/null 2>&1 || { printf 'flock is required by deploy.sh\n' >&2; exit 1; }
ln -s "$APP_ROOT/releases/previous" "$APP_ROOT/current"
cat > "$APP_ROOT/shared/.env" <<'ENV'
APP_KEY=base64:dGVzdC1rZXktdmFsdWUtZm9yLXRlc3Rz
APP_URL=https://nxm.zlck888.com
HEALTH_CHECK_USERNAME=health_check_user
HEALTH_CHECK_PASSWORD=Long-Random-Health-Secret-For-Tests
DB_CONNECTION=mysql
DB_DATABASE=app_test
DB_USERNAME=app_test_user
DB_PASSWORD=not-a-real-production-password
DB_HOST=127.0.0.1
DB_PORT=3306
ENV
touch "$APP_ROOT/shared/composer.phar"
touch "$TEST_ROOT/composer.phar"

cat > "$MOCK_BIN/git" <<'MOCK'
#!/usr/bin/env bash
set -e
destination="${@: -1}"
mkdir -p "$destination/modernization/frontend" "$destination/modernization/backend/database/migrations" \
    "$destination/modernization/backend/bootstrap" "$destination/modernization/backend/storage" \
    "$destination/modernization/deploy"
printf '{"scripts":{"build":"true"}}\n' > "$destination/modernization/frontend/package.json"
touch "$destination/modernization/backend/database/migrations/2026_06_06_000001_create_modernization_core_tables.php"
for name in 2026_06_06_000002_create_runtime_support_tables.php; do
  touch "$destination/modernization/backend/database/migrations/$name"
done
mkdir -p "$destination/modernization/frontend/dist"
touch "$destination/modernization/frontend/dist/index.html"
  touch "$destination/modernization/deploy/queue-worker-watchdog.sh"
MOCK

cat > "$MOCK_BIN/node" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK

cat > "$MOCK_BIN/npm" <<'MOCK'
#!/usr/bin/env bash
set -e
case "$1" in
  ci|install) mkdir -p node_modules/.bin; touch node_modules/.bin/vite; chmod +x node_modules/.bin/vite ;;
  run) mkdir -p dist; touch dist/index.html ;;
esac
MOCK

cat > "$MOCK_BIN/php" <<'MOCK'
#!/usr/bin/env bash
set -e
printf '%s\n' "$*" >> "${MOCK_PHP_LOG:?}"
if [[ "$*" == *"health:login-check"* ]] && [[ "${MOCK_HEALTH_LOGIN_FAIL:-0}" == "1" ]]; then
  exit 1
fi
exit 0
MOCK

cat > "$MOCK_BIN/curl" <<'MOCK'
#!/usr/bin/env bash
set -e
if [[ "${MOCK_HEALTH_FAIL:-0}" == "1" && "$*" == *"https://nxm.zlck888.com/"* ]]; then
  exit 1
fi
exit 0
MOCK

cat > "$MOCK_BIN/chown" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK

cat > "$MOCK_BIN/mysqldump" <<'MOCK'
#!/usr/bin/env bash
printf 'mock sql backup\n'
MOCK

chmod +x "$MOCK_BIN"/*
: > "$TEST_ROOT/php.log"

run_deploy() {
  env PATH="$MOCK_BIN:$PATH" APP_ROOT="$APP_ROOT" REPO_URL=https://example.invalid/repo.git \
    PHP_BIN="$MOCK_BIN/php" COMPOSER_BIN="$TEST_ROOT/composer.phar" NODE_BIN=node NPM_BIN=npm \
    MYSQLDUMP_BIN="$MOCK_BIN/mysqldump" MOCK_PHP_LOG="$TEST_ROOT/php.log" WEB_USER=www:www "$@" bash "$DEPLOY_SCRIPT"
}

if ! run_deploy > "$TEST_ROOT/success.log" 2>&1; then
  cat "$TEST_ROOT/success.log" >&2
  exit 1
fi
SUCCESS_TARGET="$(readlink -f "$APP_ROOT/current")"
[[ "$SUCCESS_TARGET" != "$APP_ROOT/releases/previous" ]]
! grep -q 'nginx reload' "$TEST_ROOT/success.log"
grep -q 'HTTPS captcha/login/logout health check passed' "$TEST_ROOT/success.log"
compgen -G "$APP_ROOT/shared/backups/database/app_test-before-*.sql.gz" >/dev/null
gzip -t "$APP_ROOT"/shared/backups/database/*.sql.gz
grep -q 'artisan migrate --force' "$TEST_ROOT/php.log"
printf 'PASS successful deploy backs up database, switches current, and does not reload nginx\n'

sleep 1
ln -sfn "$APP_ROOT/releases/previous" "$APP_ROOT/current"
if run_deploy MOCK_HEALTH_LOGIN_FAIL=1 > "$TEST_ROOT/failure.log" 2>&1; then
  printf 'FAIL health failure unexpectedly passed\n' >&2
  exit 1
fi
[[ "$(readlink -f "$APP_ROOT/current")" == "$APP_ROOT/releases/previous" ]]
if ! grep -q 'restored previous release' "$TEST_ROOT/failure.log"; then
  cat "$TEST_ROOT/failure.log" >&2
  exit 1
fi
grep -q 'Local login health check failed' "$TEST_ROOT/failure.log"
printf 'PASS failed HTTP login health check restores the previous release\n'

sleep 1
printf 'APP_KEY=base64:dGVzdC1rZXktdmFsdWUtZm9yLXRlc3Rz\nAPP_URL=https://nxm.zlck888.com\nDB_CONNECTION=mysql\nDB_DATABASE=app_test\nDB_USERNAME=app_test_user\nDB_PASSWORD=x\n' > "$APP_ROOT/shared/.env"
if run_deploy > "$TEST_ROOT/missing-credentials.log" 2>&1; then
  printf 'FAIL missing health credentials unexpectedly passed\n' >&2
  exit 1
fi
[[ "$(readlink -f "$APP_ROOT/current")" == "$APP_ROOT/releases/previous" ]]
grep -q 'login health credentials missing' "$TEST_ROOT/missing-credentials.log"
printf 'PASS missing health credentials fail before switching releases\n'

sleep 1
printf 'APP_KEY=base64:dGVzdC1rZXktdmFsdWUtZm9yLXRlc3Rz\nAPP_URL=https://nxm.zlck888.com\nHEALTH_CHECK_USERNAME=health_check_user\nHEALTH_CHECK_PASSWORD=Long-Random-Health-Secret-For-Tests\nDB_CONNECTION=mysql\nDB_DATABASE=app_test\nDB_USERNAME=app_test_user\nDB_PASSWORD=x\n' > "$APP_ROOT/shared/.env"
export RUN_MIGRATIONS=1
cat > "$MOCK_BIN/mysqldump" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
chmod +x "$MOCK_BIN/mysqldump"
: > "$TEST_ROOT/php.log"
if run_deploy > "$TEST_ROOT/backup-failure.log" 2>&1; then
  printf 'FAIL failed database backup unexpectedly passed\n' >&2
  exit 1
fi
[[ "$(readlink -f "$APP_ROOT/current")" == "$APP_ROOT/releases/previous" ]]
grep -q 'Database backup failed; migration was not started' "$TEST_ROOT/backup-failure.log"
! grep -q 'artisan migrate' "$TEST_ROOT/php.log"
if compgen -G "$APP_ROOT/shared/backups/database/*.tmp" >/dev/null; then
  printf 'FAIL temporary database backup was not cleaned after failure\n' >&2
  exit 1
fi
printf 'PASS failed database backup stops before release switch and migration\n'

sleep 1
cat > "$MOCK_BIN/mysqldump" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
chmod +x "$MOCK_BIN/mysqldump"
: > "$TEST_ROOT/php.log"
if run_deploy > "$TEST_ROOT/backup-corrupt.log" 2>&1; then
  printf 'FAIL corrupt database backup unexpectedly passed\n' >&2
  exit 1
fi
[[ "$(readlink -f "$APP_ROOT/current")" == "$APP_ROOT/releases/previous" ]]
grep -q 'Database backup is empty' "$TEST_ROOT/backup-corrupt.log"
! grep -q 'artisan migrate' "$TEST_ROOT/php.log"
! compgen -G "$APP_ROOT/shared/backups/database/*.tmp" >/dev/null
printf 'PASS empty database backup stops before release switch and migration\n'

sleep 1
SQLITE_DB="$APP_ROOT/shared/test.sqlite"
printf 'sqlite fixture\n' > "$SQLITE_DB"
printf 'APP_KEY=base64:dGVzdC1rZXktdmFsdWUtZm9yLXRlc3Rz\nAPP_URL=https://nxm.zlck888.com\nHEALTH_CHECK_USERNAME=health_check_user\nHEALTH_CHECK_PASSWORD=Long-Random-Health-Secret-For-Tests\nDB_CONNECTION=sqlite\nDB_DATABASE=%s\n' "$SQLITE_DB" > "$APP_ROOT/shared/.env"
if ! run_deploy RUN_MIGRATIONS=1 > "$TEST_ROOT/sqlite-success.log" 2>&1; then
  cat "$TEST_ROOT/sqlite-success.log" >&2
  exit 1
fi
cmp -s "$SQLITE_DB" "$APP_ROOT/shared/backups/database/sqlite-before-"*.sqlite || {
  printf 'FAIL SQLite database backup does not match source\n' >&2
  exit 1
}
printf 'PASS SQLite database backup is made before migration\n'

sleep 1
printf 'APP_KEY=base64:dGVzdC1rZXktdmFsdWUtZm9yLXRlc3Rz\nAPP_URL=https://nxm.zlck888.com\nHEALTH_CHECK_USERNAME=health_check_user\nHEALTH_CHECK_PASSWORD=Long-Random-Health-Secret-For-Tests\nDB_CONNECTION=sqlite\nDB_DATABASE=relative.sqlite\n' > "$APP_ROOT/shared/.env"
if run_deploy > "$TEST_ROOT/sqlite-relative.log" 2>&1; then
  printf 'FAIL relative SQLite path unexpectedly passed\n' >&2
  exit 1
fi
grep -q 'DB_DATABASE must be an absolute path' "$TEST_ROOT/sqlite-relative.log"
printf 'PASS relative SQLite path is rejected before migration\n'
