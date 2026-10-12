# 2026-07-02 最终部署运维文档

## 1. 部署范围

- 只部署 `modernization` 新 Laravel/Vue 系统。
- 旧 ThinkPHP 系统保持只读，不做代码修改。
- GitHub 仓库：`https://github.com/bos432/xm.git`
- 分支：`main`
- 本轮安全整改需先推送到 `main`，使用推送后的提交部署。

## 2. 宝塔终端部署命令

```bash
cd /www/wwwroot/nxm.zlck888.com

APP_ROOT=/www/wwwroot/nxm.zlck888.com \
REPO_URL=https://github.com/bos432/xm.git \
BRANCH=main \
PHP_BIN=/www/server/php/83/bin/php \
FRONTEND_API_BASE=/api \
bash ./deploy.sh
```

常规发布默认不执行数据库迁移或 Seeder。先确认宝塔网站根目录指向
`/www/wwwroot/nxm.zlck888.com/current/public`，检查数据库备份和待执行迁移；
仅在已审阅迁移并完成应用数据库备份后，才增加 `RUN_MIGRATIONS=1`。仅在需同步
健康账号或种子数据时再增加 `RUN_SEED=1`。

## 3. 部署后健康检查

```bash
cd /www/wwwroot/nxm.zlck888.com/current/backend

/www/server/php/83/bin/php artisan health:login-check

curl -I https://nxm.zlck888.com/
curl -I https://nxm.zlck888.com/dashboard
curl -I https://nxm.zlck888.com/application-batches
```

预期结果：

- `Health login passed for [health_check_user].`
- 三个 `curl -I` 均返回 `HTTP/2 200`

## 4. 关键环境变量

服务器文件：

`/www/wwwroot/nxm.zlck888.com/shared/.env`

必须包含：

```env
APP_URL=https://nxm.zlck888.com
HEALTH_CHECK_USERNAME=health_check_user
HEALTH_CHECK_PASSWORD=<生产环境随机强密码，至少20位>
```

健康检查命令只从 Laravel 配置读取凭据。密码只保存在服务器 `.env`
和受控密码管理器中，不写入命令行、脚本或交付文档。更新密码后运行
设置新随机强密码后，使用 `RUN_SEED=1` 部署以同步专用账号并撤销旧 token。

## 5. 常用巡检命令

```bash
cd /www/wwwroot/nxm.zlck888.com/current/backend

/www/server/php/83/bin/php artisan migrate:status | tail -n 30
/www/server/php/83/bin/php artisan route:list | grep auth
/www/server/php/83/bin/php artisan health:login-check
tail -n 200 storage/logs/laravel*.log
```

## 6. 回滚说明

部署脚本采用 releases/current 结构。如新版本异常：

1. 进入 `/www/wwwroot/nxm.zlck888.com/releases` 查看上一版本目录。
2. 将 `/www/wwwroot/nxm.zlck888.com/current` 链接切回上一版本。
3. 重新执行健康检查。切换站点 `current` 链接不需要重载 Nginx。

回滚前建议先保留异常版本日志，避免问题线索丢失。

## 7. 交付后必须做的安全动作

- 轮换历史交付材料中公开过的测试凭据；生产超管账号通过受控密码渠道管理。
- 为 `health_check_user` 设置仅保存在服务器 `.env` 中的随机强密码；交付文档不记录密码。
- 确认 `shared/.env` 不提交 Git。
- 安全中心检查登录白名单、临时放宽是否关闭。
- 定期清理 PHP 配置中的重复 `mbstring` 加载警告。

## 8. 已知非阻塞警告

部署时出现：

`PHP Warning: Module "mbstring" is already loaded`

含义：PHP 配置里重复加载了 `mbstring` 扩展。当前不影响 Laravel、路由、登录、前端访问。建议后续在宝塔 PHP 8.3 配置中保留一处 `extension=mbstring`，删除重复项。
