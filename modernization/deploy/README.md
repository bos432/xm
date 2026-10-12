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

## GitHub Repository

The repository is public, so production deployment should use the public HTTPS
URL and must not paste a GitHub token into the terminal command:

```bash
cd /www/wwwroot/nxm.zlck888.com

APP_ROOT=/www/wwwroot/nxm.zlck888.com \
REPO_URL=https://github.com/bos432/xm.git \
BRANCH=main \
PHP_BIN=/www/server/php/83/bin/php \
bash ./deploy.sh
```

Normal deployments do not run `db:seed` and do not reload the shared Nginx
service. The script takes an app-local deployment lock, creates and verifies a
restricted pre-migration database backup under `shared/backups/database`,
switches only this site's `current` symlink, checks the release, and restores
the previous symlink if post-switch health checks fail. It runs database
migrations; code rollback does not reverse schema migrations. Keep the
encrypted/off-host backup retention policy independent from release cleanup.

SSH deploy keys are still supported as an optional alternative. If using SSH,
verify `ssh -T git@github.com` before deployment and set
`REPO_URL=git@github.com:bos432/xm.git`.

Frontend dependencies are installed with:

```bash
npm ci --include=optional --no-audit --no-fund
```

If Linux optional dependencies are missing, the script falls back to `npm install --include=optional --no-audit --no-fund` and prints a warning.

Optional environment variables:

```bash
APP_ROOT=/www/wwwroot/nxm.zlck888.com \
REPO_URL=git@github.com:bos432/xm.git \
BRANCH=main \
PHP_BIN=/www/server/php/83/bin/php \
bash ./deploy.sh
```

## Health Checks

The deploy script checks the homepage, captcha API, public homepage API, local
login credentials, and the real HTTP login flow. Configure the health-check
account in `/www/wwwroot/nxm.zlck888.com/shared/.env`:

```env
HEALTH_CHECK_USERNAME=health_check_user
HEALTH_CHECK_PASSWORD=<random-secret-at-least-20-characters>
```

The health-check account must already exist as an active, minimum-permission
unit account with `metadata.health_check=true`; the deploy script will not
create a known-password account. `HEALTH_CHECK_PASSWORD` must be at least 20
characters. Missing credentials fail before release preparation unless the
operator explicitly sets `SKIP_LOGIN_HEALTH=1`; skipping login health is not
recommended for production. Set `RELOAD_NGINX=1` only when the site's Nginx
configuration changed and a host-level reload has been reviewed for other
virtual hosts.

For a genuinely new installation only, bootstrap accounts can be created by
setting random secrets in the protected `shared/.env` and explicitly running
`RUN_SEED=1`. The seeder creates absent accounts only, validates secrets of at
least 20 characters, and never resets existing account passwords. Never put
bootstrap secrets in shell history or Git.

## Rollback

List releases:

```bash
ls -lt /www/wwwroot/nxm.zlck888.com/releases
```

Switch back to a previous release:

```bash
cd /www/wwwroot/nxm.zlck888.com
ln -sfn releases/<previous-release-id> current
curl -fsSI https://nxm.zlck888.com/
```

Changing this site's `current` symlink does not require reloading Nginx when the
virtual-host configuration is unchanged. A host-wide Nginx reload is a separate
operations action and must be reviewed for impact on every virtual host first.

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

## E2E Smoke Test

Playwright tests read credentials from environment variables and keep generated
test data online for later regression:

```bash
cd modernization/frontend
E2E_BASE_URL=https://nxm.zlck888.com \
E2E_STAMP=E2E-20260630-103223 \
E2E_UNIT_USERNAME=... E2E_UNIT_PASSWORD=... \
E2E_COUNTY_USERNAME=... E2E_COUNTY_PASSWORD=... \
E2E_DEPARTMENT_USERNAME=... E2E_DEPARTMENT_PASSWORD=... \
E2E_EXPERT_USERNAME=... E2E_EXPERT_PASSWORD=... \
E2E_ADMIN_USERNAME=... E2E_ADMIN_PASSWORD=... \
E2E_SUPER_ADMIN_USERNAME=... E2E_SUPER_ADMIN_PASSWORD=... \
npm run e2e
```

HTML reports are written to `modernization/e2e/reports/html`.
