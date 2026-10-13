# 2026-07-02 部署与验收文档

> 安全更新（2026-10）：历史固定密码和常规 `RUN_SEED=1` 示例已废止。常规部署不运行 Seeder、不 reload Nginx；请遵循 `modernization/deploy/README.md`。

## 1. 部署范围

- 只部署 `modernization` 新 Laravel/Vue 系统。
- 旧 ThinkPHP 系统保持只读，不改代码、不迁移旧逻辑。
- GitHub 仓库已公开，生产部署使用公开 HTTPS URL，不需要 GitHub Token。

## 2. 生产目录

推荐目录结构：

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

宝塔站点根目录应指向：

```text
/www/wwwroot/nxm.zlck888.com/current/public
```

## 3. 必备环境变量

`/www/wwwroot/nxm.zlck888.com/shared/.env` 至少需要包含：

```env
APP_URL=https://nxm.zlck888.com
HEALTH_CHECK_USERNAME=health_check_user
HEALTH_CHECK_PASSWORD=<按生产实际配置>
```

说明：

- `HEALTH_CHECK_USERNAME/PASSWORD` 用于部署期间真实登录健康检查。
- 正常生产部署不要跳过登录健康检查。
- 只有人工救急时才允许临时设置 `SKIP_LOGIN_HEALTH=1`。
- 不要把 GitHub Token、邮箱授权码、数据库密码写进 Git 仓库。

## 4. 标准部署命令

```bash
cd /www/wwwroot/nxm.zlck888.com

APP_ROOT=/www/wwwroot/nxm.zlck888.com \
REPO_URL=https://github.com/bos432/xm.git \
BRANCH=main \
PHP_BIN=/www/server/php/83/bin/php \
bash ./deploy.sh
```

常规发布跳过 Seeder 和数据库迁移。仅在已检查待执行迁移且完成应用数据库备份后，显式追加 `RUN_MIGRATIONS=1`；确需同步种子数据时再追加 `RUN_SEED=1`。

## 5. 部署脚本会执行的关键动作

1. 从 GitHub `main` 拉取代码。
2. 安装后端 Composer 依赖。
3. 安装前端依赖：

```bash
npm ci --include=optional --no-audit --no-fund
```

4. 构建前端。
5. 链接共享 `.env`、`storage`、`bootstrap-cache`。
6. 默认跳过数据库迁移和 Seeder；只有完成审查与数据库备份后才显式启用。
7. 执行健康检查：
   - `/`
   - `/api/auth/captcha`
   - `/api/public/homepage`
   - `php artisan health:login-check`（凭据从 Laravel 配置读取）
   - HTTP 真实登录和 logout
8. 健康检查通过后切换 `current`。

## 6. 部署后人工验收

部署完成后执行：

```bash
curl -s https://nxm.zlck888.com/api/auth/captcha
curl -s https://nxm.zlck888.com/api/public/homepage | head -c 300
curl -I https://nxm.zlck888.com/
```

浏览器强刷并检查：

1. 首页可打开。
2. 首页只显示一个“新单位注册”入口。
3. 验证码可加载。
4. 单位、区县、部门、专家、管理员、超管可登录。
5. `/projects?keyword=E2E-20260630-103223` 筛选正常。
6. `/lifecycle?project_id=5` 项目回显正常。
7. `/acceptance?scope=reviewed&keyword=E2E-20260630-103223` 验收历史可见。
8. `首页管理 -> 品牌素材` 可上传 Logo、Banner、Favicon。
9. `安全中心` 可查看登录风控状态。

## 7. E2E 回归命令

在本地或服务器具备 Node/Playwright 环境时：

```bash
cd modernization/frontend

E2E_BASE_URL=https://nxm.zlck888.com \
E2E_STAMP=E2E-20260630-103223 \
E2E_PROJECT_ID=5 \
E2E_UNIT_USERNAME=... E2E_UNIT_PASSWORD=... \
E2E_COUNTY_USERNAME=... E2E_COUNTY_PASSWORD=... \
E2E_DEPARTMENT_USERNAME=... E2E_DEPARTMENT_PASSWORD=... \
E2E_EXPERT_USERNAME=... E2E_EXPERT_PASSWORD=... \
E2E_ADMIN_USERNAME=... E2E_ADMIN_PASSWORD=... \
E2E_SUPER_ADMIN_USERNAME=... E2E_SUPER_ADMIN_PASSWORD=... \
npm run e2e
```

报告输出：

- JSON：`modernization/e2e/reports/results.json`
- HTML：`modernization/e2e/reports/html/index.html`
- 截图：`test-results/`

## 8. Favicon 上线步骤

由超级管理员操作：

1. 登录后台。
2. 打开 `首页管理 -> 品牌素材`。
3. 在“站点图标 Favicon”上传正式 `ico/png/svg` 文件。
4. 文件大小控制在 512KB 以内。
5. 上传成功后刷新或重新打开浏览器标签页。
6. 验证 `/api/public/homepage` 返回 `brand.favicon_url`。

未上传正式 favicon 时，系统继续使用 `/favicon.ico` 兜底。

## 9. 队列常驻

宝塔 Supervisor 建议配置：

```ini
directory=/www/wwwroot/nxm.zlck888.com/current/backend
command=/www/server/php/83/bin/php artisan queue:work database --queue=default --tries=3 --timeout=90 --sleep=3
user=www
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/www/wwwroot/nxm.zlck888.com/shared/storage/logs/queue-worker.log
```

若宝塔 Supervisor 仍无法启动本站 program，可用本站专属 watchdog 作为临时兜底。脚本带外层单实例锁，宝塔计划任务每分钟调用不会重复堆积：

```bash
/www/wwwroot/nxm.zlck888.com/shared/bin/queue-worker-watchdog.sh >> /www/wwwroot/nxm.zlck888.com/shared/storage/logs/queue-worker-watchdog.log 2>&1
```

计划任务执行用户必须为 `www`，并开启进程锁。上线核验命令：

```bash
pgrep -af 'queue-worker-watchdog|artisan queue:work'
cd /www/wwwroot/nxm.zlck888.com/current/backend
runuser -u www -- /www/server/php/83/bin/php artisan queue:failed-count
```

正常状态应为一个 watchdog、一个 queue worker，失败队列为 `0`。

## 10. 回滚

列出 release：

```bash
ls -lt /www/wwwroot/nxm.zlck888.com/releases
```

切换到上一版：

```bash
cd /www/wwwroot/nxm.zlck888.com
ln -sfn releases/<previous-release-id> current
```

站点使用 `current` 软链接发布时无需重载 Nginx；新部署的健康检查失败会自动恢复旧版本链接。

注意：回滚代码不会自动回滚数据库迁移。数据库问题必须使用已验证备份恢复。

## 11. 常见问题

### PHP CLI 出现 mbstring 重复加载警告

如果宝塔 PHP 8.3 CLI 同时在 `php.ini` 和 `php-cli.ini` 声明已编译的
`mbstring.so`，会出现 `Module "mbstring" is already loaded`。先备份对应
配置，再确认 `php -m` 仍包含 `mbstring`，只注释重复的 `extension` 行，
不要删除扩展文件，也不要为此重启整机服务。

### 静态首页安全响应头

Laravel middleware 只覆盖 API 时，Nginx 直接返回的 SPA HTML 不会继承这些
响应头。应在本站独立 server block 内添加安全头，修改前备份配置，执行
`nginx -t` 后再平滑 reload，并检查 `/` 和 `/api/public/homepage` 的响应头。

### GitHub 认证失败

仓库已公开，部署命令必须使用：

```bash
REPO_URL=https://github.com/bos432/xm.git
```

不要拼接 Token。

### 健康检查缺账号

如果部署日志提示：

```text
login health credentials missing
```

检查 `shared/.env` 是否存在：

```env
HEALTH_CHECK_USERNAME=...
HEALTH_CHECK_PASSWORD=...
```

### npm optional dependency 问题

当前本地验证 `npm ci --include=optional --no-audit --no-fund` 已可一次成功。如果生产仍出现 optional dependency 缺失，先确认 Node/npm 版本和 `package-lock.json` 是否为最新。

