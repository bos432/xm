# 运营就绪整改记录

代码基线：`origin/main` `84da667`；运营安全头补丁上线提交：`5b320472fdeb9bf6254cfe54f62b6ea8626eb10b`。本次只部署 `nxm.zlck888.com` 站点，没有改动其他站点或整机服务。

## 已落实

- 后端 Feature 测试使用显式 testing 环境变量与 SQLite 内存库运行：`vendor/bin/phpunit --display-warnings --display-deprecations --display-notices`，结果 `OK (186 tests, 825 assertions)`，退出码 0。
- 前端把项目时间轴活动序号逻辑提取为纯 JS 工具函数，并新增 3 个 Node 内置测试；未增加 npm 依赖。新增 `npm test`、工具模块语法/JSDoc 检查 `npm run typecheck`，并将测试目录纳入 lint。
- GitHub Actions 已增加前端测试/typecheck、PHP PCOV 覆盖率文本输出，以及在线 E2E 所需六角色账号密钥的 fail-fast 检查；候选提交与 main CI 均已远端成功。
- 部署前只读核查生产站点：`current` 指向 release `20261013074937`；根分区使用率约 54%、`/www` 66%；当时迁移均已 Ran；首页、验证码 API、公开首页 API 均返回 HTTP 200。未读取密钥值或数据库业务内容。

## 远端分支 CI 复核

- 整改分支触发器已包含 `codex/**`，避免只在 `main` 执行而无法验证候选分支。
- 候选提交 `fb94ee7a4c5f1805e41fa1c1f890be9175e9b0e2` 的 GitHub Actions 运行 [38438733066](https://github.com/bos432/xm/actions/runs/38438733066) 结果为 `success`：Frontend lint and build、Backend feature tests、Deployment backup and rollback simulations 均成功；Optional online E2E 为 `skipped`。
- 提交 `0860b71bb0b1052ce432c308be8062216606ace3` 在 `main` 的 Actions 运行 [38439291063](https://github.com/bos432/xm/actions/runs/38439291063) 结果为 `success`：前端、后端和部署安全模拟均通过；在线 E2E skipped。
- 最初 coverage job 失败后，在 `phpunit.xml` 显式纳入 `app/**/*.php` 作为 coverage source，再跑 CI 成功。GitHub 公共 API 不提供该仓库 job 日志下载权限，因此此处不填未能读取的 coverage 百分比；CI 命令使用 `--coverage-text`，但覆盖率数值需有权限查看 Actions 日志后补录。
- 同一提交本机复验：PHPUnit `186 tests, 825 assertions` 全通过；无本机 coverage driver，故本机不报告覆盖率。

## 本地验证记录

- 前端：`npm test` 3/3；`npm run typecheck`、`npm run lint`、`npm run build` 退出码均为 0；Playwright 列出 9 项 E2E 场景。
- 后端：186 tests、825 assertions 全通过。PHPUnit 缓存与前端 coverage HTML 是本地测试生成物，不纳入版本控制。
- Pint 全库试跑结果 `138 files, 138 style issues`。这是现存格式问题，本轮未执行全库自动格式化；当前 workflow 不运行 Pint，因此不冒充运营阻断门禁。
- 前端仅有 3 个纯逻辑测试，没有前端 coverage provider；没有可报告的前端覆盖率数字。UI 角色权限和完整流程仍需端到端回归。

## 尚未验证/完成

- GitHub CLI 未认证，且仓库 Actions logs/API 对当前身份返回 403/401；因此无法读取精确 PCOV 百分比或核实六角色在线 secrets 是否已配置。
- 2026-10-14 生产 Playwright E2E 实跑：1 项公开首页用例通过，8 项因本机未配置六角色账号密码而 skipped。跳过项包括各角色登录/页面、专家认证权限 API、超管首页素材与安全中心；并未执行审批、评分、验收写操作。
- 部署隔离模拟已由 Ubuntu CI 通过。本地 Bash 模拟因 Windows 环境缺少 `flock` 无法运行。
- 生产 PHP CLI 曾输出 `Module "mbstring" is already loaded` 警告。本轮未改 PHP 全局配置或重启服务，需另行查明重复扩展配置来源。
- CAPTCHA 至 HTTP 服务的用户端网络链路、邮件 SMTP 实际投递、备份恢复演练、并发/压力测试、完整权限矩阵和真实六角色完整业务流均未验证。

## 发布安全边界

已发布到 `nxm.zlck888.com`。后续发布使用已同步到站点根目录的仓库版 `deploy.sh`，默认只切换该站点的 `current` 符号链接，不执行 Nginx/PHP-FPM/整机 reload；本次历史部署曾 reload Nginx，配置检查通过且服务保持 active。当前数据库迁移均已应用，除非逐项审阅发现新迁移，否则发布必须使用 `RUN_MIGRATIONS=0 RUN_SEED=0`。部署失败只允许回切该站点旧 release；不对生产数据库执行自动回滚。

## 2026-10-14 生产部署记录

- 已在部署前创建 `/www/wwwroot/nxm.zlck888.com/predeploy-0860b71-20261014014012.tar.gz`，约 2.5 MB；`tar -tzf` 完整性检查通过。旧 release `20261013074937` 保留，可用于只回切本站点。
- 生产 `current` 已切换到 `/www/wwwroot/nxm.zlck888.com/releases/20261014014012`，release source HEAD 与 `main` 一致，为 `0860b71bb0b1052ce432c308be8062216606ace3`。
- 部署前的专用健康账号密码只有 17 位，不满足部署脚本的 20 位最低要求。已先备份 `shared/.env`，再为仅供部署探测的 `health_check_user` 生成 48 位随机密码并同步更新该专用账号哈希，撤销其旧 tokens；密码未在终端回显。清理 Laravel config cache 后，`health:login-check` 的验证码、登录、logout 链路通过。
- 本次部署命令明确 `RUN_MIGRATIONS=0 RUN_SEED=0`。部署日志显示 `Nothing to migrate`；之后核对旧/新 release 迁移文件清单无差异，`migrate:status` 显示 11 项 Ran，没有 seed。
- 重要偏差：服务器根目录 `/www/wwwroot/nxm.zlck888.com/deploy.sh` 与版本库脚本不一致。根目录脚本会无条件运行 `artisan migrate --force`，且切换 release 后会 `nginx -t` 并 reload Nginx；这次 reload 成功，Nginx 保持 active，配置测试成功。仓库版脚本才正确按 `RUN_MIGRATIONS` 分支并不 reload 共享服务。后续部署必须先修复/替换根目录脚本，避免其忽略迁移开关；不可直接假定仓库版部署安全逻辑已经同步到服务器。
- 后续已把新 release 内经过 CI 的 `modernization/deploy/deploy.sh` 同步到站点根目录 `deploy.sh`。覆盖前备份为 `deploy.sh.pre-0860b71-20261014014356`；新旧脚本 SHA-256 相同（`5395130cc823f0fd3926a25699d9f22954a0a7cd60bb38eeb29a10276719e4f3`），`bash -n` 通过，显式 `RUN_MIGRATIONS=1` 才迁移，默认跳过；脚本说明无 shared services reload。同步后 Nginx 仍 active。
- 发布后验证：`/`、`/login`、`/dashboard`、`/api/auth/captcha`、`/api/public/homepage` 均 HTTP 200；`nginx -t` 成功；健康登录通过；已登录超级管理员后台成功渲染 Dashboard，浏览器无 console error。
- 发布后已登录浏览器直达并强刷 `/dashboard`、`/projects`、`/application-batches`、`/lifecycle`、`/acceptance`、`/public-home`、`/settings?group=review`，均呈现非空应用 DOM，console errors 为 0。此检查只覆盖当前超管会话，不证明匿名或其他角色权限矩阵。
- Playwright 运行 `20261014-015637`：`1 passed, 8 skipped`。本机缺少六角色测试账号密钥；在线 E2E 是仅手动触发 job，不能把 skipped 算作角色验收通过。需要配置专用 E2E 凭据后运行 `workflow_dispatch`，且只用测试账号和保留的 E2E 数据。
- 日志只读统计：Laravel 日志最近更新时间早于本次部署，累计 545 个 `production.ERROR` 标记；最近 24 小时 4 个，部署之后 0 个。没有读取或导出日志正文。首页观察到 HSTS；未观察到 CSP、X-Content-Type-Options、X-Frame-Options、Referrer-Policy、Permissions-Policy。可评估只对本域增加响应头，避免更改共享 Nginx 全局配置。
- 尚未完成全角色线上 E2E（申报单位、区县、部门、专家、管理员、超管），审批/专家评分/验收业务写流程没有实际提交。因此部署已完成且基础健康检查通过，但角色业务验收和“完整流程通过”仍未证实，不得对外宣称全部运营验收完成。

## 2026-10-14 安全响应头补丁发布

- 候选提交：`5b320472fdeb9bf6254cfe54f62b6ea8626eb10b`；远端 `main` 与候选一致。GitHub Actions [38443368872](https://github.com/bos432/xm/actions/runs/38443368872) 显示成功：Frontend lint and build、Backend feature tests、Deployment backup and rollback simulations 均成功；Optional online E2E skipped。
- 发布前归档：`/www/wwwroot/nxm.zlck888.com/predeploy-5b32047-20261014020739.tar.gz`，约 2.5 MB；`tar -tzf` 完整性检查通过。旧 release `20261014014012` 保留。
- 使用站点根目录经过 CI 验证的 `deploy.sh` 发布，命令设置 `RUN_MIGRATIONS=0 RUN_SEED=0`。发布输出明确显示数据库迁移跳过、切换本站 `current` 成功、健康登录通过，以及“no shared services were reloaded”。未重载 Nginx/PHP-FPM/整机服务。
- 新 `current`：`/www/wwwroot/nxm.zlck888.com/releases/20261014020739`；release 内 Git main SHA 为 `5b320472fdeb9bf6254cfe54f62b6ea8626eb10b`。
- 发布后验证：`/`、`/login`、`/api/auth/captcha`、`/api/public/homepage` HTTP 均为 200；Laravel API 响应返回 `X-Content-Type-Options: nosniff`、`X-Frame-Options: SAMEORIGIN`、`Referrer-Policy: strict-origin-when-cross-origin`、`Permissions-Policy: camera=(), microphone=(), geolocation=()`。当时没有单独记录静态 HTML 响应头；后续复核发现 `/` 与 `/login` 未返回这四项，见下文。Nginx active，`nginx -t` 成功；health:login-check 通过；`migrate:status` 当前列出的迁移全部 Ran。
- 已知未消除项：PHP CLI 仍提示 `Module "mbstring" is already loaded`，未改全局 PHP 配置；CI 仍有 GitHub Actions Node.js 20 弃用提示。六角色 E2E 仍因专用账号密钥缺失而未运行，不能据此宣称各角色流程全部通过。
- 2026-10-14 再次线上只读复核：PowerShell `Invoke-WebRequest` 对 `/`、`/login`、`/api/auth/captcha`、`/api/public/homepage` 均返回 200；公开首页返回正式 favicon URL。四个安全响应头仅在 Laravel API 返回，Nginx 直接提供的 `/` 和 `/login` 未返回这些头。原因是当前头部由 Laravel middleware 写入，静态 SPA HTML 不经过 Laravel。站点虚拟主机已有其它独立配置且 reload Nginx 会影响同机虚拟主机；因此没有擅自编辑或 reload Nginx。此项列为站点级安全加固待办，需在维护窗口核验 Nginx 配置后，仅改本站 server block 并做 `nginx -t`，再评估是否 reload。
- 2026-10-14 Playwright 线上复跑 `20261014-021700`：`1 passed, 8 skipped`。通过项为公开首页；六角色登录/页面、生命周期权限和超管素材/安全中心因测试凭据未设置而跳过。环境变量存在性检查显示 12 项 `E2E_*_USERNAME/PASSWORD` 均为 false；未读取或尝试其它账号。报告目录为 `modernization/e2e/reports/runs/20261014-021700`。
- 2026-10-14 `npm audit --audit-level=low` 输出 `found 0 vulnerabilities`；前端 `npm ci`、`npm test`（3/3）、`npm run typecheck`、`npm run lint`、`npm run build` 均退出 0；后端 PHPUnit 复跑 `187 passed (834 assertions)`。E2E 清单共 9 项。
- 2026-10-14 本机部署脚本模拟无法启动：Windows WSL service 返回 `E_FAIL`，故本次本机没有验证 Bash 脚本模拟。不要将此记作模拟测试通过；最新已知 Linux CI 的部署安全/回滚模拟成功结果仍是 Actions run `38443368872`。
- 运维记录提交 `710bb33af2d9e36a9258362c654ace7c87df2971` 尚未推送：GitHub `git push` 与 `git ls-remote` 连接 github.com:443 超时；远端 `main` 仍是补丁代码提交 `5b32047`。恢复连通后应先推送记录提交，再确认远端分支指针。
- 2026-10-14 运行依赖只读检查：系统 uptime 178 天，load average `0.12, 0.08, 0.08`，内存 14 GiB 总/7.9 GiB 可用，`/` 使用 54%、`/www` 使用 67%；Nginx active、PHP 8.3 FPM service active/exited（宝塔进程模型）。Laravel `queue:failed` 显示 `No failed jobs found`，`schedule:list` 显示 `No scheduled tasks have been defined`。
- 宝塔 Supervisor 全局守护进程 active（PID 315111）。`/etc/supervisor/supervisord.conf` 第 169-170 行确实 include `/www/server/panel/plugin/supervisor/profile/*.ini`。本站 `nxm_queue_worker` 最初以 root 配置，检查状态为 `ERROR (no such process)`，因为 RPC 端口冲突下调用的 `supervisorctl` 使用了错误 listener 配置。直接查询 `/var/log/supervisord.log` 后确认该任务实际为 `FATAL`；旧 stderr 记录有 MySQL `Connection refused`（2026-09-11），但当前 MySQL `mysqld.service` active、3306 监听，Laravel migrate:status 可连接，queue 深度/失败队列均为 0。
- 2026-10-14 查明宝塔插件将命令文本原样写入 Supervisor `command=`，且使用 `http://localhost` + `/var/run/supervisor.sock` 的 Unix stream transport；然而默认 `supervisorctl -c /etc/supervisor/supervisord.conf` 指向 HTTP localhost:9001，返回 connection refused。该守护进程 socket 可见但 mode 为 `srwx------ root:root`，只有 root 可访问。以临时 `[supervisorctl] serverurl=unix:///var/run/supervisor.sock` 配置调用仍回退 HTTP 9001，返回 connection refused。宝塔面板更新调用会报 RPC 端口冲突并造成终端重连。
- 本次曾尝试仅修正本站 program：将配置 `user` 改为 `www`，备份为 `/www/server/panel/plugin/supervisor/profile/nxm_queue_worker.ini.pre-www-20261014`；错误包装命令导致 exit 127 / `couldn't exec /bin/bash: ENOENT`，worker 进入 FATAL。随后把单条 `command=` 修正为直接 PHP CLI（PHP 路径 + Laravel artisan 参数），备份为 `/www/server/panel/plugin/supervisor/profile/nxm_queue_worker.ini.pre-command-20261014` 和 `.pre-unixsock-20261014`；由于宝塔 supervisorctl RPC 连接配置不通，无法安全 reread/update/start，worker 状态仍 `ERROR (no such process)`，没有运行实例。Supervisor 全局 PID 315111、Nginx 与 MySQL 仍 active；未重启全局 Supervisor 或其它服务。本站当前 ini 保留 `user=www` 和直接 PHP CLI 命令，不会再因错误 `/bin/bash -lc` 反复重试。队列深度和失败数均为 0；异步消费仍未验收。
- 恢复邮件 worker 需要先由运维管理员修复宝塔 Supervisor RPC endpoint（确保 CLI/插件连接到同一 supervisor socket，权限最小化，不开放 HTTP RPC 端口），再仅对 `nxm_queue_worker` 执行 reread/update/start，并确认 status 为稳定 RUNNING、进程属主 `www`、Supervisor 其它程序状态无变化。不得重启全局 Supervisor 来绕过 RPC 配置问题。
