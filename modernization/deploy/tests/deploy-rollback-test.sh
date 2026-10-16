#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/modernization-deploy-test.XXXXXX")"

cleanup() {
  case "$TEMP_ROOT" in
    "${TMPDIR:-/tmp}"/modernization-deploy-test.*) rm -rf -- "$TEMP_ROOT" ;;
    *) printf 'Refusing to remove unexpected test path: %s\n' "$TEMP_ROOT" >&2 ;;
  esac
}
trap cleanup EXIT

APP_ROOT="$TEMP_ROOT/app"
MOCK_BIN="$TEMP_ROOT/bin"
mkdir -p "$APP_ROOT/shared/storage" "$APP_ROOT/shared/bootstrap-cache" "$APP_ROOT/releases/previous" "$MOCK_BIN"
ln -s "$APP_ROOT/releases/previous" "$APP_ROOT/current"
printf '%s\n' 'APP_KEY=base64:dGVzdC1rZXktdmFsdWUtZm9yLXRlc3Rz' 'APP_URL=https://nxm.zlck888.com' \
  'HEALTH_CHECK_USERNAME=health_check_user' \
  'HEALTH_CHECK_PASSWORD=Fixture-Health-Check-Password-2026' > "$APP_ROOT/shared/.env"
printf 'fixture composer\n' > "$TEMP_ROOT/composer.phar"
cp "$TEMP_ROOT/composer.phar" "$APP_ROOT/shared/composer.phar"

for name in git node npm php curl chown nginx; do
  ln -s "$SCRIPT_DIR/mock-command.sh" "$MOCK_BIN/$name"
done
chmod +x "$SCRIPT_DIR/mock-command.sh"

export PATH="$MOCK_BIN:$PATH"
export APP_ROOT
export COMPOSER_BIN="$TEMP_ROOT/composer.phar"
export NODE_BIN=node
export NPM_BIN=npm
export PHP_BIN="$MOCK_BIN/php"
export WEB_USER=fixture:fixture
export DEPLOY_TEST_COMMAND_LOG="$TEMP_ROOT/commands.log"
export DEPLOY_TEST_CURL_ARGS="$TEMP_ROOT/curl-args.log"
export DEPLOY_TEST_NGINX_CALLED="$TEMP_ROOT/nginx-called"

run_deploy() {
  REPO_URL=fixture BRANCH=main FRONTEND_API_BASE=/api RUN_SEED=0 \
    bash "$REPO_ROOT/modernization/deploy/deploy.sh" > "$TEMP_ROOT/deploy.log" 2>&1
}

if ! run_deploy; then
  cat "$TEMP_ROOT/deploy.log" >&2
  exit 1
fi
FIRST_RELEASE="$(readlink "$APP_ROOT/current")"
[[ "$FIRST_RELEASE" == "$APP_ROOT"/releases/* ]]
[[ ! -e "$DEPLOY_TEST_NGINX_CALLED" ]]
[[ -L "$FIRST_RELEASE/backend/storage" ]]
[[ -L "$FIRST_RELEASE/backend/bootstrap/cache" ]]
for runtime_dir in \
  "$APP_ROOT/shared/storage/app/private" \
  "$APP_ROOT/shared/storage/app/public" \
  "$APP_ROOT/shared/storage/framework/cache" \
  "$APP_ROOT/shared/storage/framework/sessions" \
  "$APP_ROOT/shared/storage/framework/views" \
  "$APP_ROOT/shared/storage/logs" \
  "$APP_ROOT/shared/bootstrap-cache"; do
  [[ -d "$runtime_dir" ]]
done
! grep -q 'composer.phar config -g' "$DEPLOY_TEST_COMMAND_LOG"
! grep -Fq 'Fixture-Health-Check-Password-2026' "$DEPLOY_TEST_COMMAND_LOG" "$DEPLOY_TEST_CURL_ARGS"
! grep -Fq '/api/auth/login' "$DEPLOY_TEST_CURL_ARGS"

sleep 1
if DEPLOY_TEST_FAIL_HOMEPAGE=1 run_deploy; then
  printf 'Expected the simulated homepage health check to fail.\n' >&2
  exit 1
fi

[[ "$(readlink "$APP_ROOT/current")" == "$FIRST_RELEASE" ]]
[[ ! -e "$DEPLOY_TEST_NGINX_CALLED" ]]
grep -q 'restored previous release' "$TEMP_ROOT/deploy.log"
printf 'Deployment isolation and rollback checks passed.\n'
