#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BACKUP_SCRIPT="$ROOT_DIR/modernization/deploy/site-backup.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/nxm-site-backup-test.XXXXXX")"
cleanup() {
  rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

MOCK_BIN="$TEST_ROOT/bin"
APP_ROOT="$TEST_ROOT/app"
BACKUP_DIR="$APP_ROOT/shared/backups/daily"
mkdir -p "$MOCK_BIN" "$APP_ROOT/shared/storage/app/private/project-files" \
  "$APP_ROOT/shared/storage/logs" "$BACKUP_DIR"
chmod +x "$BACKUP_SCRIPT"

cat > "$APP_ROOT/shared/.env" <<'ENV'
DB_CONNECTION=mysql
DB_DATABASE=nxm_test
DB_USERNAME=nxm_backup_user
DB_PASSWORD=fixture-secret-must-not-be-logged
DB_HOST=127.0.0.1
DB_PORT=3306
ENV
printf 'private fixture\n' > "$APP_ROOT/shared/storage/app/private/project-files/document.txt"
printf 'must not be archived\n' > "$APP_ROOT/shared/storage/logs/laravel.log"

cat > "$MOCK_BIN/mysqldump" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ "${MYSQL_PWD:-}" == fixture-secret-must-not-be-logged ]]
[[ "$*" != *fixture-secret-must-not-be-logged* ]]
printf 'CREATE DATABASE nxm_test;\n'
MOCK
chmod +x "$MOCK_BIN/mysqldump"

run_backup() {
  env PATH="$MOCK_BIN:$PATH" APP_ROOT="$APP_ROOT" \
    BACKUP_DIR="$BACKUP_DIR" RETENTION_DAYS=14 \
    bash "$BACKUP_SCRIPT" "$@"
}

if ! run_backup > "$TEST_ROOT/success.log" 2>&1; then
  cat "$TEST_ROOT/success.log" >&2
  exit 1
fi

DB_ARCHIVE=("$BACKUP_DIR"/nxm-database-*.sql.gz)
FILES_ARCHIVE=("$BACKUP_DIR"/nxm-private-files-*.tar.gz)
[[ -f "${DB_ARCHIVE[0]}" && -f "${FILES_ARCHIVE[0]}" ]]
gzip -t "${DB_ARCHIVE[0]}" "${FILES_ARCHIVE[0]}"
gzip -dc "${DB_ARCHIVE[0]}" | grep -q 'CREATE DATABASE nxm_test'
tar -tzf "${FILES_ARCHIVE[0]}" | grep -q 'project-files/document.txt'
! tar -tzf "${FILES_ARCHIVE[0]}" | grep -q 'laravel.log'
! grep -Fq 'fixture-secret-must-not-be-logged' "$TEST_ROOT/success.log"
[[ "$(stat -c '%a' "${DB_ARCHIVE[0]}")" == 600 ]]
[[ "$(stat -c '%a' "${FILES_ARCHIVE[0]}")" == 600 ]]
printf 'PASS database and private uploads are archived and verified without exposing credentials\n'

OLD_DB="$BACKUP_DIR/nxm-database-20000101-000000.sql.gz"
printf 'old backup\n' | gzip -c > "$OLD_DB"
touch -d '20 days ago' "$OLD_DB"
chmod +x "$MOCK_BIN/mysqldump"
cat > "$MOCK_BIN/mysqldump" <<'MOCK'
#!/usr/bin/env bash
exit 9
MOCK
chmod +x "$MOCK_BIN/mysqldump"

if run_backup > "$TEST_ROOT/failure.log" 2>&1; then
  printf 'FAIL failed database dump unexpectedly passed\n' >&2
  exit 1
fi
[[ -f "$OLD_DB" ]]
! compgen -G "$BACKUP_DIR/*.tmp" >/dev/null
printf 'PASS dump failure preserves existing backups and removes partial files\n'

cat > "$MOCK_BIN/mysqldump" <<'MOCK'
#!/usr/bin/env bash
printf 'CREATE DATABASE nxm_test;\n'
MOCK
chmod +x "$MOCK_BIN/mysqldump"
printf 'unrelated archive\n' > "$BACKUP_DIR/other-site-database-20000101.sql.gz"

if ! run_backup > "$TEST_ROOT/retention.log" 2>&1; then
  cat "$TEST_ROOT/retention.log" >&2
  exit 1
fi
[[ ! -e "$OLD_DB" ]]
[[ -f "$BACKUP_DIR/other-site-database-20000101.sql.gz" ]]
printf 'PASS retention removes only expired archives owned by this site\n'
