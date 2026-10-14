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
- 后续复核验证：Supervisor RPC Unix socket 为 `/var/run/supervisor.sock`，权限 `srwx------ root:root`。正确格式的临时 `supervisorctl` 配置 `[supervisorctl] serverurl=unix:///var/run/supervisor.sock` 可连通；`reread` 返回 `nxm_queue_worker: changed`，随后仅对该 program 执行 `update nxm_queue_worker` 返回 `stopped` / `updated process group`。但其后状态为 `ERROR (no such process)`，没有 worker 运行；未执行 `start`。因此目前不能宣称异步邮件可用。更新期间全局 Supervisor PID 未变，Nginx/MySQL 均 active。当前仅该 program 的 ini 是 `user=www` + 直接 PHP CLI 命令。

## 2026-10-14 后续运营排障复核

- 宝塔终端现场复核：`systemctl is-active nginx mysqld supervisord` 输出依次为 `active / active / active`；`readlink -f /www/wwwroot/nxm.zlck888.com/current` 指向 `/www/wwwroot/nxm.zlck888.com/releases/20261014020739`；PHP 8.3 CLI 文件存在。未发现任何 `artisan queue:work` 运行进程。
- 以 `www` 身份在本站 backend 执行 `php artisan about --only=environment` 成功，Laravel 11.44.7、PHP 8.3.30、production 环境；`queue:failed` 输出 `No failed jobs found.`。该检查证明 CLI/数据库基本连接可用，不证明异步 job 被消费。
- 宝塔自带客户端 `/www/server/panel/pyenv/bin/supervisorctl -c /etc/supervisor/supervisord.conf status nxm_queue_worker` 与临时 socket 配置查询均输出 `nxm_queue_worker: ERROR (no such process)`。配置结构确认 `user=www`、`numprocs=1`，PHP CLI 指向 `/www/server/php/83/bin/php`，命令参数为 database/default 队列、3 次尝试、90 秒 timeout、3 秒 sleep；没有显示或采集 `.env` 密钥。
- 为避免触碰全局 Supervisor socket / 其它程序，评估本站专属 systemd unit。服务器返回 `bash: /etc/systemd/system/nxm-zlck888-queue.service: Operation not permitted`；随后检查文件确认 `absent`，未产生部分 unit。未执行 `systemctl daemon-reload`、enable 或 start。该限制说明当前会话/主机策略不允许创建该系统级服务，未尝试 chmod、sudo 绕行或改用其它写入渠道。
- 操作后复核：本站 Supervisor program 仍为 `ERROR (no such process)`；Nginx、MySQL、Supervisor 均为 `active`；`https://nxm.zlck888.com/` 和 `/api/auth/captcha` 均为 HTTP 200。没有重启、停止或重载共享服务，也没有改动其它站点配置。
- 结论：worker 仍是生产运营阻断项，异步邮件/队列处理未验收。需要具备系统服务配置授权的主机运维人员在维护窗口为该站点创建独立、最小权限的 worker unit，或修复宝塔 Supervisor 客户端控制通道后只管理 `nxm_queue_worker`；启动后验证进程属主 `www`、持续运行、队列消费和错误日志，并复核共享服务状态。当前不能宣称系统已达到完整运营就绪。
- 随后进一步定位：当前 Supervisor 总览把唯一进程列为 `nxm_queue_worker:nxm_queue_worker_00 FATAL`。worker ini 当前配置为直接执行 `/www/server/php/83/bin/php artisan queue:work database --queue=default --tries=3 --timeout=90 --sleep=3`。PHP ELF 文件存在，`www` 用户直接运行 `php -v` 和 Laravel `artisan about --only=environment` 均成功；挂载无 `noexec` 证据。Supervisor stderr 混有历史失败：早先 `/bin/bash`、直接 PHP 命令均曾 `couldn't exec`，最近日志还出现旧 MySQL `Connection refused`。当前时点无法从现存日志精确区分 Supervisor spawn 错误与重启前遗留输出。
- 验证直接应用命令：`timeout 12s runuser -u www -- php artisan queue:work database --queue=default --tries=3 --timeout=90 --sleep=1 --once` 输出 `Processing jobs from the [default] queue.`，退出码 0。此处只处理单次队列迭代，没有写业务数据。
- 在只执行该目标的前提下调用 `reread`、`update nxm_queue_worker`、`start nxm_queue_worker:00` 后，program 仍为 FATAL/ERROR；未发现常驻 `artisan queue:work` 进程。未重启 Supervisor 全局服务。最终复核 MainPID 仍为 `315111`，Nginx、MySQL、Supervisor 均 active，首页 HTTP 200。
- 运维建议：先检查该主机 Supervisor 的 process spawn 配置/资源限制及当前错误日志时间戳，再选择面板支持的方式修复这一 program；不可将旧错误日志直接当成当前根因，也不可通过重启全局 Supervisor试错。异步队列仍未就绪。
- 2026-10-14 再次现场追踪 Supervisor：`supervisord` PID 315111，进程限制 `Max open files=262144`、`Max processes=60630`；系统进程数约 380，未见资源耗尽。`/www/server/php/83/bin/php` 为有效 x86-64 ELF、权限 755；`www` 用户执行 PHP CLI 正常。最近错误时间为 2026-10-14 02:52 CST，Supervisor 在仅针对本站 start 时再次记录 `couldn't exec /www/server/php/83/bin/php: 0`、`child process was not spawned`，程序进入 FATAL。内核 journal 未发现对应拒绝/SELinux AVC 记录，Supervisor systemd journal 无新条目。
- 通过实际子进程名 `nxm_queue_worker_00` 和通配组名再次仅针对本站 clear/start，仍为 `FATAL / ERROR(spawn error)`，没有 queue worker 进程；Supervisor PID 未变化，其它已检查服务仍 active。由此排除“先前只是把 Supervisor 子进程名写错”这一假设。未再重复启动，避免不断写入错误日志和触发 autorestart。
- 数据路径核对发现 `app/Jobs/SendMailLogJob.php` implements `ShouldQueue`，因此异步邮件确实依赖 worker。单次 `queue:work ... --once` 成功只证明 worker 命令可用，不能证明常驻队列服务可运营。当前控制台 mailbox/邮件任务仍未通过线上投递闭环验证。
- 仍未建立确定的 Supervisor spawn 根因：当前 ini 里的 PHP 命令可由 shell 下的 `www` 成功执行，但 Supervisor fork/exec 报错；没有内核拒绝证据，主机又拒绝在 `/etc/systemd/system` 写入站点独立 unit。安全边界下不重启全局 Supervisor、不绕过权限、不修改整机服务。需主机维护方检查 Supervisor 服务的 Python/C 扩展/子进程 spawn 行为，或通过宝塔正式插件重新创建该 program 后只针对本站测试。
- 2026-10-14 隔离探针：同一宝塔 Python/同一本站工作目录/`user=www` 的临时独立 Supervisor 能让 `/bin/sleep 2` 进入 RUNNING；复用本站现有 root-owned worker 日志文件也能成功。因此主机 fork/exec、www 权限、工作目录和日志文件本身不是独立探针的必要阻断。全局 Supervisor 中本站 program 仍对 PHP 和 `/bin/sleep` 都报 `couldn't exec ...: 0`，根因集中在全局 Supervisor 实例或其宝塔配置运行环境。
- 发现本站 Supervisor 日志文件原为 `root:root 0644`，`www` 直接追加会 `Permission denied`；已仅将 `nxm_queue_worker.out.log`、`nxm_queue_worker.err.log` 调整为 `www:www 0660`，目录未改。该修复单独不足以解决全局 Supervisor spawn error，但满足 worker 输出所需的最小写权限。
- 由于系统加固拒绝写入 `/var/spool/cron/www`，直接安装 `www` crontab 失败；未关闭加固绕过。随后通过宝塔计划任务界面创建本站 `www` 用户每分钟 watchdog 时，面板提示“文件写入失败，请检查是否开启系统加固功能”，并要求临时关闭系统加固。尚未确认该安全设置变更，当前没有持久化 watchdog。
- 为保持当前业务可用，已创建 `/www/wwwroot/nxm.zlck888.com/shared/bin/queue-worker-watchdog.sh`（`www:www`、750），使用本站 backend、PHP 8.3、`flock` 锁和 default database queue；手动以 `www` 启动后，观察到 flock 和 PHP `artisan queue:work` 进程持续存在，单次日志仅有已知 mbstring 重复加载警告。该进程目前是一次性后台进程，重启后不会自动恢复，计划任务需在安全加固允许后落地。
- 2026-10-14 尝试 systemd transient 兜底：`systemd-run` 创建本站临时 unit，但 wrapper 入口被 `SIGSEGV` 终止；去掉 wrapper、直接执行本站 PHP 以及用 `/bin/sh -c exec PHP` 均返回 `status=203/EXEC`。相关 transient unit 已停止/清理，没有常驻残留；这不是应用命令失败，而是当前主机 systemd transient 执行策略无法运行该路径。共享服务仍 active。
- systemd 探针之后已重新以 `www` 启动已验证的后台 watchdog；复核观察到 `/usr/bin/flock` 与 PHP `artisan queue:work` 进程，首页 HTTP 200，Nginx、MySQL、Supervisor 均 active。当前业务异步队列可运行，但还没有重启后自动恢复证据。
- 将 watchdog 升级为循环脚本：worker 退出后等待 5 秒，再以 `flock` 防重复方式拉起。现场先终止本站 PHP worker PID 1033658，约 8 秒后观察到新 PHP worker PID 1034676、watchdog PID 1033655 仍在，首页 HTTP 200；这证明运行期间的异常自恢复有效。该测试只终止了本站 worker，Nginx、MySQL、Supervisor、crond 均保持 active。

## 2026-10-14 持久化队列守护补强

- 经授权通过宝塔 UI 临时放行系统加固 5 分钟，仅新增本站计划任务：`nxm.zlck888.com 队列 worker 守护`，执行用户 `www`、每分钟、启用任务锁，状态显示正常；未关闭其它安全策略或变更其它站点。
- 首次执行验证发现宝塔每分钟再次启动循环 watchdog，造成守护壳进程累积。已在生产 watchdog 增加 `storage/framework/nxm_queue_worker_watchdog.lock` 外层单实例锁；锁文件由 `www` 创建，属主/权限 `www:www 0640`。随后等待完整 cron 周期，确认只保留一个 watchdog 和一个 queue worker。另对本站 queue worker 做定向终止，约 8 秒后新 worker PID 出现；这验证了任务周期和进程内自恢复，不等同于整机重启恢复演练。
- 失败队列为 0；Nginx、MySQL、Supervisor、crond 均 active；首页仍返回 HTTP 200。未重启或 reload 任何共享服务。
- 候选仓库已加入同款 watchdog、部署安装步骤和文档。发布脚本安装 watchdog 时同时将属主设为 `$WEB_USER`，避免 `www` 计划任务无法执行 root-owned 文件。提交 `62d8002` 尚未推到 GitHub，当前网络对 `github.com:443` 超时/重置。
- 整机重启恢复仍未验证。静态 HTML 安全头、mbstring 重复加载、六角色线上流程、SMTP 真实投递、备份恢复演练与压力测试仍未闭环。

## 2026-10-14 最终现场复核补充

- 生产 watchdog 与锁文件权限已修正为本站最小范围：脚本 `www:www 0750`，外层锁 `www:www 0660`。以 `www` 用户尝试打开锁时返回 `LOCK_BUSY`（已有本站 watchdog 持锁），证明计划任务用户具备访问权限且单实例锁有效。
- 定向终止本站 PHP queue worker 后，约 8 秒内由本站 watchdog 拉起新的 PHP worker；之后复核仍只有一个 watchdog 和一个 worker，失败队列为 `0`。该验证覆盖 cron 运行期间自恢复，不等同于整机重启恢复。
- Nginx 配置仅修改 `/www/server/panel/vhost/nginx/nxm.zlck888.com.conf`，修改前已生成 `*.pre-security-headers-*` 备份；`nginx -t` 和平滑 reload 成功。静态 `/` 与 Laravel API 均返回 `X-Content-Type-Options`、`X-Frame-Options`、`Referrer-Policy`、`Permissions-Policy`，原有 HSTS 保持；Nginx、MySQL、Supervisor、crond 均为 `active`。
- PHP 8.3 的 mbstring 已编译加载，`php.ini` 与 `php-cli.ini` 的重复 extension 声明已备份后注释；`php -v` 不再输出重复加载 warning，`php -m` 仍包含 `mbstring`。未重启 PHP-FPM。
- 清理并重新缓存 Laravel 配置后，使用已配置的健康账号执行 `artisan health:login-check`，真实验证码、登录、logout 链路通过；未记录或导出密码。旧示例密码曾失败一次，未修改账号密码。

## 2026-10-14 release `20261014041039`

- `main` 提交 `94ac2f8` 已通过站点根目录部署脚本发布到本站 `current`；部署命令使用 `RUN_MIGRATIONS=0 RUN_SEED=0`，数据库未改动。部署输出显示前端构建、Composer 安装、Laravel 配置/路由缓存、首页/API/验证码和真实登录健康检查均通过，并明确 `no shared services were reloaded`。
- 发布后复核：watchdog `www:www 0750`，外层锁 `www:www 0660`；只有一个本站 watchdog 和一个 PHP queue worker；`queue:failed-count` 为 `0`；Nginx、MySQL、Supervisor、crond 均 `active`；首页返回 `HTTP/2 200`，静态响应头和 HSTS 均存在。
- 本次发布只切换本站 `current`，没有重启整机、Nginx、PHP-FPM、MySQL 或 Supervisor，也没有改动同机其它站点。
- 发布后线上 E2E run `20261014-041420`：公开首页用例 `1 passed`；六角色登录/页面、专家认证权限、超管首页素材与安全中心共 `8 skipped`，原因仍是本机未配置专用 E2E 账号密码。该结果证明公开入口，不证明角色业务全流程。

## 2026-10-14 延续验收：本机门禁与线上匿名暴露面

- 在隔离分支 `codex/qa-gates-production`（HEAD 与 `origin/main` 同为 `18598c7f103f8c23eec36eb3353fafbfa623e8f6`）复跑：前端 `npm test` 为 3/3、`npm run typecheck`、`npm run lint`、`npm run build` 均退出 0；后端 `vendor/bin/phpunit --display-warnings --display-deprecations --display-notices` 输出 `OK (187 tests, 834 assertions)`。以上只证明自动化代码门禁，不是生产角色验收。
- 对生产域执行匿名只读 HTTPS GET：`/`、`/login`、`/dashboard`、`/application-batches`、`/public-home`、`/api/auth/captcha`、`/api/public/homepage` 均 HTTP 200。验证码接口只核对字段存在（`captcha_id, question`），未记录验证码 ID；门户 API 的 `brand.logo_url`、`brand.favicon_url` 均存在。静态 HTML 有 HSTS 和 `X-Content-Type-Options: nosniff`。
- 同一只读探测 `/ .env`（实际路径 `/.env`）和 `/storage/logs/laravel.log` 返回 404，响应正文未匹配 APP_KEY、DB_PASSWORD 或 MAIL_PASSWORD 模式。探测 `/vendor/phpunit/phpunit/phpunit` 返回 200 `text/html`，正文与根路径完全相同且不含 PHPUnit 字样，证实这是 SPA history fallback，并非 PHPUnit 源文件暴露；后续可考虑 Nginx deny 规则减少扫描噪音，但当前没有证据显示敏感文件可下载。
- 当前远端 HEAD 与本机一致；本机 `gh auth status` 输出 `You are not logged into any GitHub hosts`，所以无法从 Actions API 核验最新 workflow run 明细或在线 E2E Secrets 状态。既有本仓库 Actions 成功记录仍可参考，但不能当作本次运行证据。
- 不依赖生产写入继续验证的项目已完成。仍未闭环且不能虚报：六角色完整提交/区县/部门/多专家评分/终审/延期/验收业务流；SMTP 实际收信；备份恢复演练；并发/压力测试；整机重启后 watchdog 自动恢复。六角色 E2E 必须使用专用测试账号并在确认其为安全测试数据后运行；重启演练必须由运维安排维护窗口，因其可能影响同机其他站点。

## 2026-10-14 API 未认证错误协商缺陷

- 生产匿名 GET `/api/auth/me`、`/api/projects`、`/api/reviews/tasks`、`/api/settings/groups`、`/api/users`、`/api/security/events`（不带 `Accept`）均稳定返回 500 HTML，正文是通用 Symfony 错误页，没有堆栈或密钥；带 `Accept: application/json` 时同一组接口均返回 `401 application/json` 和 `{"message":"Unauthenticated."}`。因此未认证请求不会越权，但非标准客户端/健康探针省略 Accept 时收到 500，属 P1 可用性与错误码问题。
- 根因由本地最小回归用例复现：Laravel 默认访客回调调用不存在的 `route('login')`，导致 `RouteNotFoundException`。修复为 API 访客不生成页面重定向、返回认证异常 JSON 401；非 API 页面继续跳转 `/login`。新增无 Accept 头回归测试。
- 修复后最初后端全量 `vendor/bin/phpunit --display-warnings --display-deprecations --display-notices`：`OK (188 tests, 836 assertions)`；扩大无 Accept 回归覆盖到 6 个受保护 API 后，当前结果更新为 `OK (188 tests, 846 assertions)`，定向 `AuthProfileTest` 为 `OK (14 tests, 82 assertions)`。前端测试 3/3、typecheck、lint、build 均通过。部署脚本 Bash 模拟在当前 Windows WSL 因 `CreateInstance/E_FAIL` 无法启动，已改用隔离 Ubuntu Docker 验证。
- 补丁仍在隔离候选分支，未部署；生产匿名接口的无 Accept 500 尚未被生产修复，需候选 CI 通过并经安全发布流程部署后复测。此次只读复测均带 JSON Accept，仍为 401。
- 候选 Actions 运行 `38500876398` 在已固定 `ubuntu-24.04` 后仍失败于“本站隔离和回滚”模拟；公开 annotations 仅有 exit code 1，Actions 日志下载 API 返回 403。复核 mock 仓库后发现其也未生成部署脚本要求的 `queue-worker-watchdog.sh`；已在 `modernization/deploy/tests/mock-command.sh` 补齐该 fixture。
- 为获得 Linux 等价验证，在本机隔离 Docker Ubuntu 24.04 容器运行：`bash -n modernization/deploy/tests/deploy-release-safety-test.sh modernization/deploy/tests/deploy-rollback-test.sh modernization/deploy/tests/mock-command.sh && bash modernization/deploy/tests/deploy-release-safety-test.sh && bash modernization/deploy/tests/deploy-rollback-test.sh`。完整输出的关键结果：`PASS successful deploy backs up database, switches current, and does not reload nginx`、health failure rollback、缺健康凭据 fail closed、数据库备份失败/空备份保护、SQLite 备份与相对路径拒绝均 PASS，最后 `Deployment isolation and rollback checks passed.`。容器内无生产凭据、无生产挂载，仅挂载候选工作区供测试。
- 当前机器到 GitHub HTTPS 443 连接失败；最新夹具提交 `3a1535f` 尚未推送，`main` 仍为 `18598c7`。需网络恢复后推候选并确认 Actions 全绿；在此之前补丁不应部署。
- 2026-10-14 再次运行前端供应链检查：`npm audit --audit-level=low` 输出 `found 0 vulnerabilities`；`npm run e2e -- --list` 列出 9 项场景。
- 2026-10-14 生产线上 E2E run `20261014-103437`：公开首页 `1 passed`；其余 8 项（六角色页面、角色权限 API、超管门户/安全中心）因六角色专用凭据未配置而 skipped。运行前 grep 筛选在 Windows 参数传递下未匹配测试，随即直接运行完整 E2E 套件成功执行公开首页；未猜测账号或写入业务数据。
- 最新工作区候选分支有 2 个本地提交未推送（`3a1535f` 与 `754adaa`），推送再次因 GitHub 443 `Failed to connect` 失败；远端最新可读状态仍停留在 `486441b`，主线 `18598c7` 未动。Docker Ubuntu 24.04 本地模拟验证对应夹具通过，但最终候选版本尚无 CI 结果。
- 2026-10-14 最新再测 `github.com:443`：TLS/HTTP 推送端点不可连接，GitHub REST API 可读；SSH 连接返回 `Permission denied (publickey)`。没有检测或输出任何凭据。六路径匿名认证矩阵回归通过，修复仍未部署。
- 2026-10-14 候选分支推送恢复后，最新提交 `1dbd616781f58496097e39575d9f28cadd7f3828` 的 GitHub Actions run `38502151470` 终态 `success`：Frontend lint and build、Backend feature tests、Deployment backup and rollback simulations 全部 success；Optional online E2E 为 skipped（未配置六角色测试 Secrets）。
- 经候选与主线各项必需 CI 全通过后，`main` 快进更新至 `e8d85b730e89affc61585b813e1864f90ad1924b`。2026-10-14 生产只部署本站 release `20261014104851`，部署前归档 `/www/wwwroot/nxm.zlck888.com/predeploy-e8d85b7-20261014024500.tar.gz`（2.5 MB，`tar -tzf` 校验通过，权限 0600）；环境明确 `RUN_MIGRATIONS=0 RUN_SEED=0`。
- 部署日志确认前端构建、Composer 依赖、Laravel config/route cache 成功；数据库迁移与 seed 跳过；本站 `current` 已切换；健康账号验证码/登录/logout 检查通过；明确输出 `no shared services were reloaded`。没有 reload/restart Nginx、PHP-FPM、MySQL、Supervisor、crond 或整机。
- 发布后宝塔终端复核：`current` 指向 `/www/wwwroot/nxm.zlck888.com/releases/20261014104851`；Nginx、MySQL、Supervisor、crond 均 `active`；`/`、`/login`、`/api/auth/captcha`、`/api/public/homepage` HTTP 200。六个匿名受保护 API `/api/auth/me`、`/api/projects`、`/api/reviews/tasks`、`/api/settings/groups`、`/api/users`、`/api/security/events` 在未提供 Accept 头时均返回 `401 application/json` 和 `{"message":"Unauthenticated."}`，无 Accept 头 500 已在线修复。
- 发布后 `queue:failed-count` 输出 `0`；观察到本站 watchdog 与一个 queue worker（PID 1045658）在运行。这里只做读取与状态确认，没有提交新的申报、审核或验收业务记录。
- 2026-10-14 持续运营核验：本站 watchdog 实际只有一个持锁进程 PID `1041252`，另两个是宝塔 cron 的 `sudo/bash` 启动壳（均自 `07:09:45` 开始等待）；锁文件由 `www:www` 持有，`flock -n` 未提示第二个持锁进程。一个 queue worker PID `1045658` 正在跑；`queue:failed-count` 为 `0`。之前粗略 grep 把 cron wrapper 计作 watchdog 的误读已通过完整进程树纠正，没有杀进程。
- 发现 `/www/wwwroot/nxm.zlck888.com/shared/backups` 与 `/www/backup/nxm.zlck888.com` 均不存在；当前可见备份只有若干本站部署前 tar 包，时间跨度不构成定期应用数据备份/异地备份。`artisan tinker` 命令不存在，未查询邮件队列表，也未读取业务邮件日志；SMTP 实投仍未验证。备份/灾备、SMTP 仍是运营验收缺口。
- 2026-10-14 新增本站专属备份工具 `modernization/deploy/site-backup.sh`：从本站 `.env` 获取数据库连接信息，不打印密码；用 mysqldump 备份本站 MySQL，用 tar 备份 `storage/app/private`；归档验证后以 `0600` 保存至本站 `shared/backups/daily`，14 天清理仅匹配本站文件名，锁与路径校验避免并发及目录越界。TDD 测试在隔离 Ubuntu Docker 中通过成功、dump 失败和过期留存清理路径；部署模拟也通过并断言 release 安装 `shared/bin/site-backup.sh`。候选提交 `e60b20a` 已推送，但 GitHub CI 当前无法读取（匿名 API rate limit，已登录浏览器访问失败），因此还未部署；生产仍无每日自动备份，不能视作已解除该运营风险。
- 数据恢复仍待生产侧验证：计划在每日任务创建且生成首份归档后，使用临时隔离数据库及临时解压目录验证可恢复性；不向生产数据库导入、不覆盖线上上传目录。离线/异地副本尚无目标和凭据配置；仅本站磁盘留存不能满足整机/磁盘故障灾备。

## 2026-10-14 本站每日备份计划任务

- 已在宝塔计划任务页面仅新增 `nxm.zlck888.com 本站数据库与上传备份`：Shell 脚本每天 02:10（服务器本地时区），执行用户 `www`，进程锁开启，命令只调用 `/www/wwwroot/nxm.zlck888.com/shared/bin/site-backup.sh` 并追加本站日志。宝塔列表显示任务状态“正常”，执行周期“每天的02:10执行一次”。未修改或删除其它站点/系统任务；既有本站 worker 守护任务保持原状。
- 通过宝塔手动执行该任务后，面板提示“任务已执行!”；任务日志记录 `2026-10-14 11:31:54 Successful`。任务日志同时有 `setlocale: LC_ALL: cannot change locale (en_US.UTF-8)` 警告，未阻止备份脚本成功；可后续单独统一任务 locale，不属于备份失败。
- 此前以 `www` 手工运行备份脚本，数据库与 private uploads 两份归档均通过脚本校验，属主 `www:www`、权限 `0600`。手工验证时间为 11:28 CST；本次宝塔 cron 成功时间为 11:31 CST。当前 UI 未暴露归档目录内容，因此本次任务级证据确认脚本退出成功，但没有从终端再次核对 11:31 新归档文件名、大小和 mode。
- 隔离恢复验证仍未完成：本站 MySQL 账号没有创建临时数据库的权限，MySQL 返回 `Access denied`。没有更改线上数据库权限或对生产库导入。需 DBA 提供短期、限定隔离库的恢复权限，或准备隔离 MySQL 实例。
- 异地/离线副本仍未配置；计划任务只保存在同一台主机磁盘，不能抵御整机/磁盘故障。生产运营就绪仍有灾备缺口，不能将本地备份等同于异地灾备，也不能称数据库恢复演练通过。
- 安全策略说明：本次创建任务成功，UI 没有要求关闭系统加固；因此没有关闭系统加固，也没有调整其他安全项或共享服务。
- 后续通过宝塔主机终端进行只读复核：`readlink -f current` 指向 `/www/wwwroot/nxm.zlck888.com/releases/20261014112743`；`systemctl is-active nginx mysqld supervisord crond` 依次输出 `active`。首页和验证码 API 分别返回 HTTP 200。
- 归档目录直接核验到本次任务产生 `nxm-database-20261014-113154.sql.gz`（73,256 bytes，`www:www`，`0600`）和 `nxm-private-files-20261014-113154.tar.gz`（1,639,961 bytes，`www:www`，`0600`）。同目录的 `.backup.lock` 显示 `0644`，只作为 flock 锁文件，不包含归档内容；备份数据本身保持 `0600`。当前磁盘每日备份已验证生成。
- 只读进程检查看到一个本站 watchdog PID `1045657` 和一个 PHP `artisan queue:work` PID `1045658`；`artisan queue:failed-count` 输出 `0`。该快照证明检查时运行，不构成整机重启恢复演练或邮件 SMTP 实际投递证明。
- 复核未重启或 reload Nginx、MySQL、Supervisor、crond、PHP-FPM 或主机，也未修改其它站点。
- 继续只读查看 `shared/.env` 的非敏感配置键和值：`MAIL_MAILER=log`、`QUEUE_CONNECTION=database`；`artisan queue:monitor database:default --max=100` 输出队列大小 `[0] OK`，`queue:failed-count` 输出 `0`。因此队列消费者虽运行正常，邮件目前配置为写日志而非 SMTP，真实邮件通知不可用；未读取邮箱密码等凭据、未改 `.env`、未发送邮件。该项是运营上线前阻断，需由系统运营方提供 SMTP 主机/端口/加密类型/发件账号及密码后，使用专用测试收件箱验证投递。
- 上述只读终端还确认 `/` 分区 54%（79G 中使用 41G、可用 35G），`/www` 分区 67%（295G 中使用 201G、可用 94G），`nginx -t` 成功；`migrate:status` 当前 10 项均为 Ran。曾误试不存在的 `artisan config:get` 子命令，仅返回 usage/error，未修改配置；之后只读取 `.env` 中两个非敏感键并使用受支持的 `queue:monitor` 完成检查。
- 2026-10-14 再通过 Laravel bootstrap + `RuntimeConfig::applyMailSettings()` 执行脱敏运行时检查，确认数据库配置覆盖后的**实际生效** `mail.default=log`、`queue.default=database`，SMTP host/port/encryption 字段非空，但 SMTP username/password 均未设置；没有输出具体主机/端口/加密值、用户名或密码。`jobs` 和 `failed_jobs` 表计数均为 0。由此确认邮件当前不会通过 SMTP 外发，邮件通知属于生产功能阻断，而不仅是配置推测。未触发测试邮件或修改配置。
- 当前生产 release 为 `20261014112743`，只读探测显示其目录不是 Git checkout，不能从生产文件直接取得源码 SHA；GitHub 主线当前为 `f071e470bc22d7923f35567b4999d2fb1ccd687e`。当日 deploy 记录证明此前发布 release `20261014112743` 是当时版本，但 `f071e47` 仅含文档提交，故生产代码与主线代码等价于 `f071e47` 的父代码提交 `2ac82e8`，未为文档变化重新部署。

## 2026-10-14 本轮复验与恢复权限检查

- 候选分支当前 `b8ba020` 上，在隔离 Ubuntu 24.04 容器执行 `bash -n modernization/deploy/site-backup.sh modernization/deploy/tests/site-backup-test.sh && bash modernization/deploy/tests/site-backup-test.sh`，三项均 PASS：凭据不泄露且两类归档校验通过；dump 失败保留旧备份并清理临时文件；过期清理仅删除本站归档。首次错误使用只读容器挂载导致脚本无法 chmod、测试未启动；随即换成一次性可写挂载重跑通过，候选 Git 工作区最终无变更。
- 前端 `npm ci --include=optional --no-audit --no-fund` 成功；`npm test` 为 3/3，`npm run typecheck`、`npm run lint`、`npm run build` 均退出 0。后端在本机执行 `php vendor/bin/phpunit --display-warnings --display-deprecations --display-notices`，输出 `OK (188 tests, 846 assertions)`。
- 尝试为安全恢复演练只读检查主机 MySQL 授权：`command -v mysql` 找到 `/usr/bin/mysql`，版本 `mysql Ver 14.14 Distrib 5.7.40`；不提供密码执行 `mysql -NBe "SHOW GRANTS FOR CURRENT_USER()"` 返回 `ERROR 1045 (28000): Access denied for user 'root'@'localhost' (using password: NO)`。未查询/读取密码、未创建数据库、未修改 grants 或生产数据。此前网站 DB 账号创建隔离库也已被拒绝，因此数据库恢复演练仍缺独立 DBA 授权的隔离库或单独的隔离 MySQL 实例。
- 本轮未执行线上业务写流程、未向用户发送邮件、未改变任何服务器服务。SMTP 参数/测试收件箱、隔离恢复环境和六角色专用账号仍是完成端到端运营验收所需的外部条件。
- 复核宝塔任务的系统调度时间线：root crontab 存在 `10 2 * * * flock ... /www/server/cron/34d85a97c6aecf07dc65118ecafd7a88`，`crond` 为 active，日志显示宝塔在 `2026-10-14 11:32 CST` reload 了该 root crontab。主机当前时间 `2026-10-14 12:02 CST`，所以该任务下一个自然触发时点是 `2026-10-15 02:10 CST`，尚未到达；面板“上次执行时间”仍为 `2026-10-14 11:31:54` 的人工成功记录属于预期。此处不能据此认定 cron 故障，也尚不能声称已经观察到自动日常备份；应在首次计划触发后检查新的归档和 cron 记录。
- 曾尝试经宝塔终端只读查询交付手册所列五个专用 E2E 用户的用户名/角色/启用状态（不查密码哈希），终端在命令送达前显示 `token error`，没有得到数据库查询结果。没有尝试任何密码。受控 E2E 密码不在本机环境变量，六角色线上 E2E 仍未执行。

## 2026-10-14 本站 TLS 异常与恢复

- 在宝塔 `nxm.zlck888.com` 专属站点设置的 SSL 详情页中发现旧证书私钥以明文文本框显示。后续只读面板快照再次意外包含证书文本，按密钥已泄露处理；本记录不包含密钥内容、证书 PEM 或任何可复用秘密。旧私钥不得继续用于任何域名，应在受控运维流程中撤销/替换。
- 发现本站 SSL 页处于“未部署SSL”，本站域名管理显示 HTTPS 端口未开启。公网 SNI 握手错误地返回 `CN=413.chaimen666.com`，Windows `curl.exe` 返回 `SEC_E_WRONG_PRINCIPAL`；HTTP 仍为 200。确认这是本站 TLS 虚拟主机证书路由故障。
- 通过宝塔“站点修改[nxm.zlck888.com] -> SSL -> 免费证书”中严格匹配本站域名的已签发新订单部署。没有操作面板 IP 证书、其他域名证书或全局 TLS 设置。部署后本站 SSL 页显示认证域名 `nxm.zlck888.com`、状态“已部署SSL”、强制 HTTPS 已开启。
- 恢复后的独立公网验证：`http://nxm.zlck888.com/`、`https://nxm.zlck888.com/`、`https://nxm.zlck888.com/login`、`https://nxm.zlck888.com/api/auth/captcha` 均 HTTP 200；验证码响应含 captcha_id 和 question。TLS SNI 返回 `CN=nxm.zlck888.com`，有效期至 `2027-01-12 10:59:59 UTC`，新指纹 `53F1FFCF82C87B5375B5ECE4B91314D6F0D9CACF`。
- 新证书只在本站设置页对应订单上部署。本轮通过宝塔本站 UI 执行了订单续签/部署（这是本站 TLS 配置写操作）；没有运行服务器 shell 写命令、没有重启/reload Nginx 或其他共享服务，也没有操作同机其他站点。需要后续通过面板审计日志/站点配置快照确认部署器的文件变更范围，并安排旧私钥撤销；不能把面板私钥明文展示风险视为已彻底消除。
- 本轮仍确认 OSS 配置项缺失、SMTP 用户名和密码缺失；没有发起 OSS 上传、邮件发送、业务数据写入或跨站点测试。OSS 异地灾备、SMTP 实投、隔离数据库恢复和六角色端到端验收仍未闭环，系统尚未达到完整运营验收。
- TLS 恢复后的追加复核：本地 `php artisan test --compact --filter=OssBackupCommandTest` 输出 `Tests: 8 passed (36 assertions)`。隔离 Ubuntu 24.04 Docker 命令 `bash -n ... && bash modernization/deploy/tests/site-backup-test.sh && bash modernization/deploy/tests/deploy-release-safety-test.sh && bash modernization/deploy/tests/deploy-rollback-test.sh` 全部通过，包括 OSS 失败保留本地归档、拒绝错误目标、健康检查失败回滚且不 reload Nginx 等场景；容器未挂载任何生产路径或凭据。
- 同轮线上只读再次验证 `https://nxm.zlck888.com/`、`/login`、`/api/auth/captcha`、`/api/public/homepage` 均 HTTP 200；验证码 JSON 有 captcha_id/question，首页有 favicon 配置；TLS 仍为 `CN=nxm.zlck888.com`，到期 `2027-01-12 10:59:59 UTC`。未再操作证书 UI、未运行生产写操作。
- 后续 Chromium 真实浏览器 E2E 发现先前 TLS 结论不稳定：`npm run e2e -- --grep public` 首跑 `ERR_CERT_COMMON_NAME_INVALID`。独立 DNS/SNI 复核显示 `nxm.zlck888.com -> 47.239.156.27`，443 返回 `CN=413.chaimen666.com`；本站 vhost 实际只有 `listen 80`，无本站 TLS listener。宝塔订单签发/部署状态没有持久化为 Nginx 本站配置。此前短时 PowerShell 200 不构成稳定浏览器证据。
- 根因修复限于本站：先将 `/www/server/panel/vhost/nginx/nxm.zlck888.com.conf` 备份为同目录 `*.pre-tls-20261014220919`（root:root 0600）；本站现有 extension include 目录仅有 `site_total.conf`，故新增 `extension/nxm.zlck888.com/nxm-tls.conf`，加载 443 TLS、TLS 1.2/1.3 和本站证书路径。未编辑其他站点 vhost、全局默认 SSL 或面板 IP 证书。本站私钥 `/www/server/panel/vhost/cert/nxm.zlck888.com/privkey.pem` 原为 root:root 0644，现已收紧为 0600；证书与私钥的公钥 SHA-256 相同，证书 SAN 为 `DNS:nxm.zlck888.com`。配置文件 root:root 0600。
- `nginx -t` 输出 `syntax is ok` / `test is successful` 后，仅发送 `nginx -s reload` 平滑 reload；随后 `systemctl is-active nginx mysqld supervisord crond` 均为 active。新 SNI 返回 `CN=nxm.zlck888.com`，到期 `2027-01-12 10:59:59 UTC`、指纹 `53F1FFCF82C87B5375B5ECE4B91314D6F0D9CACF`。线上首页、登录、验证码、公开首页均 HTTP 200；Playwright `npm run e2e -- --grep public` 两项通过。代表性同机域名 `413.chaimen666.com`、`rd.chaimen666.com`、`mongoyia.com` 的 HTTPS HEAD 均 HTTP 200。
- 本次因真实浏览器复现而进行本站 Nginx 平滑 reload；未重启服务/整机、未更改全局 nginx.conf、未操作其他站点。历史明文显示意味着旧私钥仍按可能泄露处置；文件权限已收紧，但 CA 撤销/旧密钥作废仍需持续跟进。
