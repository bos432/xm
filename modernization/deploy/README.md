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
