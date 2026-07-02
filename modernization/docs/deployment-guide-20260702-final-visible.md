# 2026-07-02 最终部署运维文档

## 1. 部署范围

- 只部署 `modernization` 新 Laravel/Vue 系统。
- 旧 ThinkPHP 系统保持只读，不做代码修改。
- GitHub 仓库：`https://github.com/bos432/xm.git`
- 分支：`main`
- 最新上线提交：`ce6fa33 Restrict migration menu to super admin`

## 2. 宝塔终端部署命令

```bash
cd /www/wwwroot/nxm.zlck888.com

APP_ROOT=/www/wwwroot/nxm.zlck888.com \
REPO_URL=https://github.com/bos432/xm.git \
BRANCH=main \
PHP_BIN=/www/server/php/83/bin/php \
FRONTEND_API_BASE=/api \
RUN_SEED=1 \
bash ./deploy.sh
```

## 3. 部署后健康检查

```bash
cd /www/wwwroot/nxm.zlck888.com/current/backend

/www/server/php/83/bin/php artisan health:login-check \
  --username=health_check_user \
  --password='HealthCheck-2026'

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
HEALTH_CHECK_PASSWORD=HealthCheck-2026
```

如交付后修改健康检查密码，必须同步改：

1. 数据库中的 `health_check_user` 密码。
2. `shared/.env` 中的 `HEALTH_CHECK_PASSWORD`。
3. 部署脚本或人工健康检查命令中的密码。

## 5. 常用巡检命令

```bash
cd /www/wwwroot/nxm.zlck888.com/current/backend

/www/server/php/83/bin/php artisan migrate:status | tail -n 30
/www/server/php/83/bin/php artisan route:list | grep auth
/www/server/php/83/bin/php artisan health:login-check --username=health_check_user --password='HealthCheck-2026'
tail -n 200 storage/logs/laravel*.log
```

## 6. 回滚说明

部署脚本采用 releases/current 结构。如新版本异常：

1. 进入 `/www/wwwroot/nxm.zlck888.com/releases` 查看上一版本目录。
2. 将 `/www/wwwroot/nxm.zlck888.com/current` 链接切回上一版本。
3. 重载 nginx。
4. 重新执行健康检查。

回滚前建议先保留异常版本日志，避免问题线索丢失。

## 7. 交付后必须做的安全动作

- 修改 `admin / ChangeMe-2026` 默认密码。
- 修改 `health_check_user / HealthCheck-2026` 默认密码。
- 确认 `shared/.env` 不提交 Git。
- 安全中心检查登录白名单、临时放宽是否关闭。
- 定期清理 PHP 配置中的重复 `mbstring` 加载警告。

## 8. 已知非阻塞警告

部署时出现：

`PHP Warning: Module "mbstring" is already loaded`

含义：PHP 配置里重复加载了 `mbstring` 扩展。当前不影响 Laravel、路由、登录、前端访问。建议后续在宝塔 PHP 8.3 配置中保留一处 `extension=mbstring`，删除重复项。
