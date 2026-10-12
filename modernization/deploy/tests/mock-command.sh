#!/usr/bin/env bash
set -Eeuo pipefail

command_name="$(basename "$0")"
printf '%s\n' "$command_name $*" >> "$DEPLOY_TEST_COMMAND_LOG"

case "$command_name" in
  git)
    destination="${!#}"
    mkdir -p "$destination/modernization/frontend" \
      "$destination/modernization/backend/bootstrap" \
      "$destination/modernization/backend/database/migrations"
    touch "$destination/modernization/backend/artisan" \
      "$destination/modernization/backend/database/migrations/2026_06_06_000001_create_modernization_core_tables.php" \
      "$destination/modernization/backend/database/migrations/2026_06_06_000002_create_runtime_support_tables.php"
    ;;
  node|chown)
    exit 0
    ;;
  npm)
    if [ "${1:-}" = "ci" ]; then
      mkdir -p node_modules/.bin
      touch node_modules/.bin/vite
      chmod +x node_modules/.bin/vite
    elif [ "${1:-}" = "run" ] && [ "${2:-}" = "build" ]; then
      mkdir -p dist
      printf '<html>test</html>\n' > dist/index.html
    fi
    ;;
  php)
    if [ "${1:-}" = "composer.phar" ]; then
      [[ "$COMPOSER_HOME" == "$APP_ROOT"/releases/*/backend/.composer ]]
      exit 0
    fi
    if [ "${1:-}" = "-r" ]; then
      case "${2:-}" in
        *captcha_id*)
          printf '{"username":"%s","password":"%s","captcha_id":"fixture","captcha_answer":1}' \
            "$HEALTH_CHECK_USERNAME" "$HEALTH_CHECK_PASSWORD"
          ;;
        *token*)
          printf 'fixture-token'
          ;;
      esac
      exit 0
    fi
    case "$*" in
      *queue:failed-count*) printf '0\n' ;;
    esac
    ;;
  curl)
    printf '%s\n' "$*" >> "$DEPLOY_TEST_CURL_ARGS"
    case "$*" in
      *https://nxm.zlck888.com/)
        [ "${DEPLOY_TEST_FAIL_HOMEPAGE:-0}" != "1" ] || exit 22
        ;;
    esac
    ;;
  nginx)
    touch "$DEPLOY_TEST_NGINX_CALLED"
    ;;
  *)
    printf 'Unexpected mock command: %s\n' "$command_name" >&2
    exit 90
    ;;
esac
