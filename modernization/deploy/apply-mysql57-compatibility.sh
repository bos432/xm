#!/usr/bin/env bash
set -Eeuo pipefail

BACKEND_DIR="${1:-}"
[[ -n "$BACKEND_DIR" && -d "$BACKEND_DIR/database/migrations" ]] || {
  printf 'Usage: %s <release-backend-directory>\n' "$0" >&2
  exit 2
}

BACKEND_REAL="$(realpath "$BACKEND_DIR")"
[[ "$BACKEND_REAL" == */releases/*/backend || "${ALLOW_NON_RELEASE_BACKEND:-0}" == "1" ]] || {
  printf 'Refusing MySQL compatibility transforms outside a release backend directory.\n' >&2
  exit 2
}

CORE_MIGRATION="$BACKEND_REAL/database/migrations/2026_06_06_000001_create_modernization_core_tables.php"
RUNTIME_MIGRATION="$BACKEND_REAL/database/migrations/2026_06_06_000002_create_runtime_support_tables.php"
[[ -f "$CORE_MIGRATION" && -f "$RUNTIME_MIGRATION" ]] || {
  printf 'Required migration files are missing; refusing compatibility transforms.\n' >&2
  exit 2
}

sed -i "s/->json(/->longText(/g" "$CORE_MIGRATION"
sed -i "s/string('key')->primary()/string('key', 191)->primary()/g" "$RUNTIME_MIGRATION"
sed -i "s/string('owner')/string('owner', 191)/g" "$RUNTIME_MIGRATION"
sed -i "s/string('id')->primary()/string('id', 191)->primary()/g" "$RUNTIME_MIGRATION"
sed -i "s/string('queue')->index()/string('queue', 191)->index()/g" "$RUNTIME_MIGRATION"
sed -i "s/string('name')/string('name', 191)/g" "$RUNTIME_MIGRATION"
sed -i "s/string('uuid')->unique()/string('uuid', 191)->unique()/g" "$RUNTIME_MIGRATION"
