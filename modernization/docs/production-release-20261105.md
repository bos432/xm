# 本站安全更新发布与复验记录

日期：2026-11-05。范围仅 `nxm.zlck888.com`；本记录不表示业务全流程已验收。

## 当前线上版本

- release：`20261105105750`
- commit：`cef21d38e6989cffc9cc5e516dbd14f4a445d6c5`
- 前一版本：`20261018050541` / `59bbdec`
- PHP 8.3.36，Node 20.19.2，npm 10.8.2。
- CI：[Modernization CI](https://github.com/bos432/xm/actions/runs/41952385666)、[Quality Gate](https://github.com/bos432/xm/actions/runs/41952385683)，均成功且对应本次 SHA。

## 实际发布

云助手任务 `t-hk0725n6ge53lds`，退出码 0。执行前检查 remote main 与固定候选 SHA 相同；下载的部署脚本 Git blob 为 `d7ed6acf2509ea580a80b753f33ee9492a8d8ef0`，与仓库版本一致。

```sh
sg www -c 'umask 027; APP_ROOT=/www/wwwroot/nxm.zlck888.com REPO_URL=https://github.com/bos432/xm.git BRANCH=main PHP_BIN=/www/server/php/83/bin/php FRONTEND_API_BASE=/api RUN_SEED=0 RUN_MIGRATIONS=0 nice -n 15 ionice -c 3 bash /www/wwwroot/nxm.zlck888.com/shared/bin/deploy-cef21d3.sh'
```

结果片段：

```text
DEPLOYED_CURRENT=/www/wwwroot/nxm.zlck888.com/releases/20261105105750
DEPLOYED_COMMIT=cef21d38e6989cffc9cc5e516dbd14f4a445d6c5
ExitCode 0
```

首次尝试曾因外层 umask 077 产生 root 私有缓存，HTTP 登录健康失败（任务 `t-hk0725lpfjtyhvk`，退出码 1），脚本自动切回旧 release。随后仅修复本站缓存所有者与权限，以 www 重建旧版本缓存并通过登录健康检查（任务 `t-hk0725mvkjzi800`，退出码 0）。本次成功重试保留全部健康门禁。此失败不隐瞒，也不计为通过。

## 独立复验

任务 `t-hk0725nrafxzmyo`，退出码 0：

```sh
cd /www/wwwroot/nxm.zlck888.com/current/backend
runuser -u www -- /www/server/php/83/bin/php artisan health:login-check
runuser -u www -- /www/server/php/83/bin/php artisan queue:restart
runuser -u www -- /www/server/php/83/bin/php artisan queue:failed-count
```

```text
Health HTTP login passed for [health_check_user]; token revoked via logout.
INFO  Broadcasting queue restart signal.
FAILED_JOBS
0
```

对 `/`、`/login`、`/dashboard`、`/application-batches`、`/api/auth/captcha`、`/api/public/homepage`、`/api/public/application-batches/open` 分别执行 `curl --max-time 20 -fsS -o /dev/null -w '%{http_code}\n' https://nxm.zlck888.com<path>`，全部返回 200。这仅证明这些入口可达，不能证明登录后的业务处理通过。

任务 `t-hk0725o8k0ewikg` 通过 `/proc` 读取本站 artisan queue:work 进程的 executable 和 cwd，退出码 0：

```text
PID=2136789 EXE=/usr/bin/flock CWD=/www/wwwroot/nxm.zlck888.com/releases/20261105105750/backend
PID=2136790 EXE=/www/server/php/83/bin/php CWD=/www/wwwroot/nxm.zlck888.com/releases/20261105105750/backend
SITE_PHP_WORKERS=1
```

共享 bootstrap 缓存最终为 `640 www:www`。未重启 Nginx、MySQL、整机或其他站点；未运行迁移和 Seeder；未创建或修改正式项目。健康账号登录会产生并撤销专用 token，以及正常认证审计痕迹。

## 匿名浏览器测试

在隔离工作区 frontend 目录，用进程环境设置 NODE_PATH 为该 frontend 的 node_modules，E2E_RUN_ID 为 `20261105-postrelease-public`：

```sh
node node_modules/@playwright/test/cli.js test --config ../e2e/playwright.config.js --grep 'public homepage|public and anonymous'
```

```text
Running 2 tests using 1 worker
ok 1 public homepage exposes portal login and no duplicate old registration link
ok 2 public and anonymous API probes return safe responses
2 passed (5.7s)
```

退出码 0；JSON/HTML/截图保留于 `modernization/e2e/reports/runs/20261105-postrelease-public/`。测试验证门户入口、六个匿名受保护接口的 JSON 401，以及 `.env` 与日志公开路径的 404。没有登录角色账号或写入业务。

工具问题：首次 `npm run e2e -- --grep ...` 经 Windows shell 把正则管道当成命令，退出码 1；直接 Playwright CLI 初次缺少 NODE_PATH，退出码 1。设置进程环境后通过。后续 QA-01 已修改启动器，直接使用 process.execPath 调用 Playwright CLI，不再经过 shell。用原失败命令复测退出码 0、2 passed（4.4s），证据目录 `modernization/e2e/reports/runs/20261105-postrelease-wrapper/`。P2 测试工具缺陷已本地修复；该工具改动尚未发布生产，且不影响线上运行代码。

## 尚未验收

- 六角色隔离环境端到端：申报、退回重报、多专家分配和评分、终审、延期与验收关闭。
- 专家看不到待评任务的生产具体原因，需要角色与分配数据的定向只读证据。
- SMTP 真实投递：尚无有效参数与批准测试收件箱的投递证据。
- OSS 下载及隔离数据库恢复演练：不得导入生产数据库；现有 runbook 不等于恢复成功。
- 部署脚本遇到严格 umask 的长期健壮性，以及回滚时共享缓存的版本隔离，需要单独测试增量。
- 本次未运行覆盖率统计，不能以两条 E2E 或先前单测数字代表全系统覆盖率。

下一步：核查本地隔离运行时和现有测试夹具，建立禁止外部投递的独立数据库/文件环境，验证六角色业务闭环，再更新角色截图教程及交付材料。
