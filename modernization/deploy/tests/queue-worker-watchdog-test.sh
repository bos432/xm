#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WATCHDOG="$SCRIPT_DIR/../queue-worker-watchdog.sh"
TEST_ROOT="$(mktemp -d)"
cleanup() {
  status=$?
  if [[ -n "${WORKER_PID:-}" ]]; then
    kill "$WORKER_PID" 2>/dev/null || true
    wait "$WORKER_PID" 2>/dev/null || true
  fi
  rm -rf "$TEST_ROOT"
  exit "$status"
}
trap cleanup EXIT

APP_ROOT="$TEST_ROOT/app"
MOCK_BIN="$TEST_ROOT/bin"
mkdir -p "$APP_ROOT/releases/one/backend" "$APP_ROOT/releases/two/backend" \
  "$APP_ROOT/shared/storage/framework" "$MOCK_BIN"
ln -s "$APP_ROOT/releases/one" "$APP_ROOT/current"

cat > "$MOCK_BIN/flock" <<'MOCK'
#!/usr/bin/env bash
set -e
if [[ "$1" == "-n" ]]; then
  if [[ "$2" =~ ^[0-9]+$ ]]; then
    exit 0
  fi
  lock_path="$2"
  shift 2
  exec "$@"
fi
exec "$@"
MOCK

cat > "$MOCK_BIN/sleep" <<'MOCK'
#!/usr/bin/env bash
set -e
exec /bin/sleep 0.05
MOCK

cat > "$MOCK_BIN/php" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$PWD" >> "$WATCHDOG_TEST_CWD_LOG"
if [[ "$(wc -l < "$WATCHDOG_TEST_CWD_LOG")" -eq 1 ]]; then
  ln -s "$WATCHDOG_TEST_RELEASE_TWO" "${WATCHDOG_TEST_CURRENT}.next"
  mv -Tf "${WATCHDOG_TEST_CURRENT}.next" "$WATCHDOG_TEST_CURRENT"
else
  : > "$WATCHDOG_TEST_STOP_FILE"
fi
exit 0
MOCK

chmod +x "$MOCK_BIN"/*
: > "$TEST_ROOT/cwd.log"
STOP_FILE="$TEST_ROOT/stop"

sed "s#guard=/www/wwwroot/nxm.zlck888.com/shared/storage/framework/nxm_queue_worker_watchdog.lock#guard=$APP_ROOT/shared/storage/framework/watchdog.lock#; s#/www/wwwroot/nxm.zlck888.com/current/backend#$APP_ROOT/current/backend#g; s#/www/wwwroot/nxm.zlck888.com/shared/storage/framework/nxm_queue_worker.lock#$APP_ROOT/shared/storage/framework/worker.lock#g; s#/usr/bin/flock#$MOCK_BIN/flock#g; s#/www/server/php/83/bin/php#$MOCK_BIN/php#g" "$WATCHDOG" > "$TEST_ROOT/watchdog.sh"
chmod +x "$TEST_ROOT/watchdog.sh"
PATH="$MOCK_BIN:$PATH" \
  WATCHDOG_TEST_CWD_LOG="$TEST_ROOT/cwd.log" \
  WATCHDOG_TEST_CURRENT="$APP_ROOT/current" \
  WATCHDOG_TEST_RELEASE_TWO="$APP_ROOT/releases/two" \
  WATCHDOG_TEST_STOP_FILE="$STOP_FILE" \
  "$TEST_ROOT/watchdog.sh" > "$TEST_ROOT/watchdog.log" 2>&1 &
WORKER_PID=$!
for _ in $(seq 1 100); do
  [[ -f "$STOP_FILE" ]] && break
  kill -0 "$WORKER_PID" 2>/dev/null || break
  /bin/sleep 0.05
done
[[ -f "$STOP_FILE" ]] || {
  cat "$TEST_ROOT/watchdog.log" >&2
  cat "$TEST_ROOT/cwd.log" >&2
  printf 'FAIL watchdog did not restart the worker after release switch\n' >&2
  exit 1
}
kill "$WORKER_PID" 2>/dev/null || true
wait "$WORKER_PID" 2>/dev/null || true
WORKER_PID=""

mapfile -t WORKER_DIRS < "$TEST_ROOT/cwd.log"
[[ "${#WORKER_DIRS[@]}" -ge 2 ]] || {
  cat "$TEST_ROOT/cwd.log" >&2
  printf 'FAIL watchdog did not restart the worker after release switch\n' >&2
  exit 1
}
[[ "${WORKER_DIRS[0]}" == "$APP_ROOT/releases/one/backend" ]]
[[ "${WORKER_DIRS[1]}" == "$APP_ROOT/releases/two/backend" ]]
printf 'PASS watchdog re-resolves current release before each worker start\n'
