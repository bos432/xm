#!/bin/sh
set -u

guard=/www/wwwroot/nxm.zlck888.com/shared/storage/framework/nxm_queue_worker_watchdog.lock
exec 8>"$guard"
flock -n 8 || exit 0

while :; do
  cd -P /www/wwwroot/nxm.zlck888.com/current/backend || {
    sleep 5
    continue
  }
  /usr/bin/flock -n /www/wwwroot/nxm.zlck888.com/shared/storage/framework/nxm_queue_worker.lock \
    /www/server/php/83/bin/php artisan queue:work database --queue=default --tries=3 --timeout=90 --sleep=3
  sleep 5
done
