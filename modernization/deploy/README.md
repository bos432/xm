# Git Deployment

This directory contains the production deployment script for the rebuilt project application system.

## Server Layout

Recommended production layout:

```text
/www/wwwroot/nxm.zlck888.com/
├── current -> releases/<release-id>
├── releases/
└── shared/
    ├── .env
    ├── composer.phar
    ├── storage/
    └── bootstrap-cache/
```

The BT Panel website root should point to:

```text
/www/wwwroot/nxm.zlck888.com/current/public
```

## First Run

Upload or copy `deploy.sh` to the server, then run:

```bash
cd /www/wwwroot/nxm.zlck888.com
bash /path/to/deploy.sh
```

The script will migrate the current `backend/.env`, `backend/composer.phar`, and `backend/storage` into `shared/` if they are not there yet.

## Normal Deployment

After pushing code to GitHub:

```bash
cd /www/wwwroot/nxm.zlck888.com
bash ./deploy.sh
```

Frontend dependencies are installed with:

```bash
npm ci --include=optional --no-audit --no-fund
```

If Linux optional dependencies are missing, the script falls back to `npm install --include=optional --no-audit --no-fund` and prints a warning.

Optional environment variables:

```bash
APP_ROOT=/www/wwwroot/nxm.zlck888.com \
REPO_URL=https://github.com/bos432/xm.git \
BRANCH=main \
PHP_BIN=/www/server/php/83/bin/php \
bash ./deploy.sh
```

## Rollback

List releases:

```bash
ls -lt /www/wwwroot/nxm.zlck888.com/releases
```

Switch back to a previous release:

```bash
cd /www/wwwroot/nxm.zlck888.com
ln -sfn releases/<previous-release-id> current
nginx -t && /etc/init.d/nginx reload
```

Rollback does not roll back database migrations. For database changes, restore from a verified backup when required.

## Queue Worker

邮件中心使用 Laravel database queue。宝塔 Supervisor 可配置：

```ini
directory=/www/wwwroot/nxm.zlck888.com/current/backend
command=/www/server/php/83/bin/php artisan queue:work database --queue=default --tries=3 --timeout=90 --sleep=3
user=www
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/www/wwwroot/nxm.zlck888.com/shared/storage/logs/queue-worker.log
```

若不使用 Supervisor，可临时用计划任务兜底：

```bash
cd /www/wwwroot/nxm.zlck888.com/current/backend
/www/server/php/83/bin/php artisan queue:work database --queue=default --tries=3 --timeout=90 --stop-when-empty
```
