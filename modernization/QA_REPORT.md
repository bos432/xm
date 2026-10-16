# 新系统 QA 验收报告（2026-10-17 更新）

## 范围

本报告汇总 modernization 系统自动化测试、2026-10-17 对 `https://nxm.zlck888.com` 的只读生产探测，以及当日仅本站 release `20261017040227` 的发布后验证。E2E 批次隔离变更提交 `c0750b1` 已推送 `main` 并部署本站；QA 报告更新提交 `402544a` 只更新文档。部署使用 `RUN_SEED=0`、`RUN_MIGRATIONS=0`，没有重启共享服务或触碰其他站点。超管只读页面显示 OSS 已启用且目标参数已填写，但未做上传/恢复；SMTP 仍为 `log` 且 SMTP 主机/发件邮箱为空，未发测试邮件。

## 验收清单

状态定义：**已覆盖测试**表示有自动化集成/单元测试证据，不等于线上浏览器全流程已验收；**仅实现未测**表示代码存在但本轮无对应验证；**未实现**表示从当前证据无法证明能力已交付。

| 编号 | 应具备能力 | 状态 | 证据与边界 |
| --- | --- | --- | --- |
| A-01 | 申报单位创建、保存、提交项目 | 已覆盖测试 | `ProjectApplicationWorkflowTest::test_unit_user_can_create_submit_and_withdraw_project`；浏览器端完整申报未验 |
| A-02 | 区县、部门、专家、管理员按阶段审核 | 已覆盖测试 | `ReviewWorkflowTest::test_project_can_move_through_full_review_chain`；生产角色 E2E 未验 |
| A-03 | 专家评分项/评分规则校验 | 已覆盖测试 | `ProjectApplicationWorkflowTest` 中专家评分维度相关测试 |
| A-04 | 并发重复专家评分不能重复推进 | 已覆盖测试 | `ReviewWorkflowTest::test_only_one_concurrent_expert_review_can_advance_the_project` |
| A-05 | 验收材料提交、延期、延期审核、项目关闭 | 已覆盖测试 | `ProjectAcceptanceWorkflowTest` 中提交材料、延期处理、待延期禁止关闭及关闭测试 |
| A-06 | 草稿、专家认证、审核/验收记录的角色数据隔离 | 已覆盖测试 | `ProjectAuthorizationTest`、`ProjectLifecycleManagementTest`、`ReviewAndAdminAuthorizationTest`、`ProjectAcceptanceWorkflowTest`；六角色线上验证未完成 |
| A-07 | OSS 上传失败时 fail-closed 并保留本地归档 | 已覆盖测试 | `OssBackupCommandTest` 和隔离 shell 模拟；生产成功路径另见当前复核 |
| A-08 | 部署健康检查失败回滚本站 release 且不 reload Nginx | 已覆盖测试 | `deploy-release-safety-test.sh`、`deploy-rollback-test.sh` 隔离模拟；生产回滚未触发 |
| A-09 | 生产 HTTPS 证书匹配本站域名 | 已覆盖测试 | 修复后公网 SNI 返回 `CN=nxm.zlck888.com`，有效期至 `2027-01-12 10:59:59 UTC`；Chromium 线上公开 E2E 与首页/登录/验证码/公开首页均通过 |
| A-10 | OSS 异地备份及隔离环境恢复 | 上传/对象校验已证实；恢复未完成 | 超管页面显示 OSS 已启用、Bucket/前缀已填写；本站备份日志 2026-10-16 11:19、10-17 00:24、02:10 均记录本地归档校验及 `Uploaded and verified 2 OSS backup objects.`；未执行隔离下载/恢复 |
| A-11 | SMTP 实际投递至批准的测试邮箱 | 未启用/未完成验收 | 超管页面 Mailer 为 `log`，SMTP 主机和发件邮箱为空；未发送测试邮件 |
| A-12 | 六角色浏览器完整流程：申报至终审/验收 | 部分覆盖，未完成闭环 | 六个 E2E 账号历史 API 验证有记录；当前标签共享超管会话，未切换账号、未创建项目或推进流程。专家认证页只有 2 条 E2E 专家认证已通过记录，不能证明有足够正式认证专家 |
| A-13 | 测试覆盖率数字及未覆盖高风险文件排序 | 未实现验收证据 | PHPUnit coverage driver 不可用，未生成覆盖率或逐文件覆盖数据 |

## 缺陷表

| ID | 严重级 | 模块 | 复现命令/证据 | 实际 vs 预期 | 修复建议 |
| --- | --- | --- | --- | --- | --- |
| QA-01 | P0 阻断运营验收 | 异地灾备 | 本轮未执行真实 OSS 上传/恢复 | 无站外备份及隔离恢复证据 | 在后台配置最小权限 RAM 与目标 Bucket，验证 PUT/HEAD 后恢复到隔离 MySQL/存储 |
| QA-02 | P0 阻断运营验收 | 邮件通知 | 本轮未向批准测试收件箱发送邮件 | SMTP 投递与到达未验 | 配置 SMTP 与专用测试收件箱，发送测试邮件并核对投递及日志 |
| QA-03 | P1 严重 | 证书密钥管理 | 宝塔本站 SSL 详情曾显示私钥明文；本站私钥文件原权限 `0644` | 私钥曾可被非 root 本地用户读取；预期 root-only | 文件权限已改为 `0600 root:root`；仍应将历史明文暴露视为可能泄露，确认撤销旧密钥及宝塔回显策略 |
| QA-06 | P0 阻断（已修复，需持续观测） | 本站 HTTPS/Nginx | Playwright 线上首页用例曾报 `ERR_CERT_COMMON_NAME_INVALID`；Nginx 检查本站 vhost 只有 `listen 80` | 443 请求命中默认 `413.chaimen666.com` 证书；预期本站独立 TLS vhost | 已新增仅被本站 vhost extension include 的 TLS 配置、测试后平滑 reload；HTTPS 与 Chromium E2E 已复测通过 |
| QA-04 | P1 严重 | 浏览器 E2E | `cd modernization/frontend && npm run e2e -- --list`；检查 `modernization/e2e/tests/smoke.spec.js` | 共 10 个用例，角色用例检查登录、页面/权限；不覆盖“提交 -> 区县 -> 部门 -> 多专家评分 -> 终审 -> 验收关闭”全链 | 提供隔离数据库/存储及六角色专用凭据，扩展并实际运行完整 E2E，保留 E2E 数据 |
| QA-05 | P2 一般 | 测试基础设施 | PHPUnit 全量可运行；当前 PHP `-m` 未见 `xdebug`/`pcov` | 功能测试通过但覆盖率未知，未生成逐文件覆盖统计 | 仅在 CI/测试镜像启用 Xdebug 或 PCOV，发布覆盖率报告；不在生产安装 |
| QA-07 | 已修复、已部署、线上已复验 | API 未认证响应 / health headers | `GET https://nxm.zlck888.com/api/auth/me` 无凭据；`GET https://nxm.zlck888.com/up` | `/api/auth/me` 返回 401 JSON `Unauthenticated.`；`/up` 返回原 HTML health page 且包含 `X-Content-Type-Options: nosniff`、`X-Frame-Options`、`Referrer-Policy`、`Permissions-Policy` | 持续监控；无须对其他站点或共享服务做改动 |

## 已执行命令与完整关键输出

### 后端全量测试

命令：`$env:APP_BASE_PATH='X:\modernization\backend'; php '<主工作区 vendor>\bin\phpunit' -c phpunit.xml --bootstrap qa-bootstrap.php`

```text
OK (206 tests, 935 assertions)
Duration: 3.879s
exit code: 0
```

定向回归命令：`php '<主工作区 vendor>\bin\phpunit' -c phpunit.xml --bootstrap qa-bootstrap.php --filter 'test_unauthenticated_api_requests_return_json_even_without_accept_header|test_application_responses_include_browser_security_headers'`

```text
OK (2 tests, 21 assertions)
exit code: 0
```

Pint：`pint --test bootstrap/app.php app/Http/Middleware/Authenticate.php`

```text
PASS 2 files
exit code: 0
```

### 前端 lint、测试、类型检查、构建

命令：`cd modernization/frontend && npm run lint && npm test && npm run typecheck && npm run build`

```text
eslint src tests --ext .js,.vue
exit code: 0
tests 4
pass 4
fail 0
typecheck exit code: 0
vite v8.0.16 ... ✓ built in 578ms
exit code: 0
```

### OSS 专项测试

命令：`cd modernization/backend && php artisan test --compact --filter=OssBackupCommandTest`

```text
Tests:    8 passed (36 assertions)
Duration: 0.73s
exit code: 0
```

### 前端隔离构建检查

命令：`npm ci --include=dev --no-audit --no-fund && npm run lint && npm run typecheck && npm test && npm run build`

```text
added 167 packages
lint exit code: 0
typecheck exit code: 0
tests 4; pass 4; fail 0
vite v8.0.16; 1628 modules transformed; built in 447ms
exit code: 0
```

### Linux 备份/部署隔离模拟

命令：`docker run --rm --entrypoint bash -v "${PWD}:/workspace" -w /workspace ubuntu:24.04 -lc "bash -n modernization/deploy/site-backup.sh modernization/deploy/tests/site-backup-test.sh modernization/deploy/tests/deploy-release-safety-test.sh modernization/deploy/tests/deploy-rollback-test.sh modernization/deploy/tests/mock-command.sh && bash modernization/deploy/tests/site-backup-test.sh && bash modernization/deploy/tests/deploy-release-safety-test.sh && bash modernization/deploy/tests/deploy-rollback-test.sh"`

```text
PASS database and private uploads are archived and verified without exposing credentials
PASS dump failure preserves existing backups and removes partial files
PASS OSS failure preserves the newly verified local archives and skips retention cleanup
PASS retention removes only expired archives owned by this site
PASS successful deploy backs up database, switches current, and does not reload nginx
PASS failed HTTP login health check restores the previous release
PASS missing health credentials fail before switching releases
PASS failed database backup stops before release switch and migration
PASS empty database backup stops before release switch and migration
PASS SQLite database backup is made before migration
PASS relative SQLite path is rejected before migration
Deployment isolation and rollback checks passed.
exit code: 0
```

### 覆盖率尝试

命令：`cd modernization/backend && php artisan test --compact --coverage`

```text
ERROR Code coverage driver not available. Did you install Xdebug or PCOV?
exit code: 1
覆盖率：不可得，不能报告百分比
```

### 浏览器 E2E 用例清单

命令：`cd modernization/frontend && npm run e2e -- --list`

```text
public homepage exposes portal login and no duplicate old registration link
public and anonymous API probes return safe responses
unit can log in and open project lifecycle and acceptance history
county can log in and open project lifecycle and acceptance history
department can log in and open project lifecycle and acceptance history
expert can log in and open project lifecycle and acceptance history
admin can log in and open project lifecycle and acceptance history
super_admin can log in and open project lifecycle and acceptance history
lifecycle expert certification permissions match role configuration
super admin can inspect homepage assets and security center
Total: 10 tests in 1 file
exit code: 0
```

### 线上公开浏览器 E2E（只读）

首次命令：`E2E_BASE_URL=https://nxm.zlck888.com npm run e2e -- --grep public`（Windows PowerShell 设置环境变量后执行）

修复前实际输出：

```text
Error: page.goto: net::ERR_CERT_COMMON_NAME_INVALID at https://nxm.zlck888.com/
1 failed
1 did not run
```

修复后同一筛选重跑：

```text
ok 1 public homepage exposes portal login and no duplicate old registration link
ok 2 public and anonymous API probes return safe responses
2 passed (4.5s)
exit code: 0
```

修复根因证据：DNS `nxm.zlck888.com -> 47.239.156.27`；当时 SNI 返回 `CN=413.chaimen666.com`；本站 `/www/server/panel/vhost/nginx/nxm.zlck888.com.conf` 只有 `listen 80`，没有 TLS listener。本站证书 SAN 为 `DNS:nxm.zlck888.com`，证书与私钥公钥 SHA-256 匹配。通过本站已有 extension include 新增 `nxm-tls.conf`，配置只引用本站证书；`nginx -t` 成功后仅发送 Nginx 平滑 reload。本站私钥权限从 `0644` 收紧到 `0600 root:root`。

同机回归：`https://413.chaimen666.com/`、`https://rd.chaimen666.com/`、`https://mongoyia.com/` 均 HTTP 200；Nginx、MySQL、Supervisor、crond 均 active。

### 线上只读冒烟

PowerShell `Invoke-WebRequest` GET `/`、`/login`、`/api/auth/captcha`、`/api/public/homepage`，另执行 `nxm.zlck888.com:443` 的 TLS SNI 握手：

```text
https://nxm.zlck888.com/ HTTP 200
https://nxm.zlck888.com/login HTTP 200
https://nxm.zlck888.com/api/auth/captcha HTTP 200 captcha_id=True;question=True
https://nxm.zlck888.com/api/public/homepage HTTP 200 favicon=True;title=True
TLS CN=nxm.zlck888.com until=2027-01-12 10:59:59 UTC
```

## 无法验证的部分

- 未能用隔离数据走六角色浏览器完整申报、审核、评分、延期及验收链；现有浏览器用例不覆盖完整链路，也没有隔离账号/环境凭据。
- 未执行 OSS 对象 GET/下载及隔离恢复；真实 PUT/HEAD 已由本站备份日志证明成功，但没有独立恢复演练证据。
- 未向批准的测试邮箱发送 SMTP 邮件；没有 SMTP 账号凭据及测试收件确认。
- 未能给出覆盖率百分比或基于实际覆盖数据的高风险未覆盖文件 TOP5；PHP 覆盖率驱动缺失。不能把文件重要性排序伪装成覆盖率结果。
- 未执行生产压力/并发或整机重启恢复测试；没有隔离生产等价环境/维护窗口，不以线上业务承担此类破坏性验证。
- 未验证宝塔证书部署器的全部历史文件影响范围，也未完成历史暴露私钥的 CA 撤销；当前本站新证书有效且 HTTPS 经浏览器确认通过。

## 高风险文件候选（静态风险排序，不代表覆盖率排名）

由于覆盖率工具不可用，以下仅是按安全/资金/流程影响挑选的后续优先覆盖候选，不声称它们未覆盖或覆盖比例为零：

1. `modernization/backend/app/Http/Controllers/ReviewController.php`：审核授权、专家评分、终审支持和状态迁移。
2. `modernization/backend/app/Http/Controllers/ProjectController.php`：项目提交、详情访问控制和材料处理。
3. `modernization/backend/app/Http/Controllers/AcceptanceController.php`：验收、延期及完成状态。
4. `modernization/backend/app/Console/Commands/UploadOssBackups.php`：签名上传、远端校验和凭据错误处理。
5. `modernization/deploy/site-backup.sh`：生产备份、留存和故障路径。

## 历史发布记录（2026-10-17 03:38）

- GitHub `main` 已推进到 `85d78ca`，包含历史默认批次保护、Dashboard 批次统计修复和 QA-07 修复。
- 已通过宝塔终端仅部署 `/www/wwwroot/nxm.zlck888.com`，release `20261017033857`；`RUN_SEED=0`、`RUN_MIGRATIONS=0`，没有改数据库/调用 Seeder/重载 Nginx、MySQL或服务器。
- 部署脚本完成首页、验证码、公开首页 API 和本站专用健康账号登录/登出检查。
- 线上只读探测：`/`、`/login`、`/api/auth/captcha`、`/api/public/homepage` 均 200；`/api/auth/me` 未认证为 401 JSON；`/up` 为原 HTML 页面并有浏览器安全头。
- 生产队列检查：`failed_jobs=0`；queue watchdog/worker 进程存在；Nginx、MySQL active。名为 `nxm-zlck888-queue.service` 的 systemd unit 不存在（inactive），不能据此判断 worker 停止；实际本站 watchdog 与 artisan worker 进程仍运行。
- 六个生产 E2E 账号均通过验证码登录、角色身份查询、logout；凭据保留在服务器 root-only 文件，未写入报告；未通过浏览器登录测试账号，因为当前共享 in-app 标签仍是超管会话。
- 只读生产批次查询显示开放批次为 E2E 测试批次；本轮未使用它们创建或推进有状态项目。正式业务批次的真实年度、时间范围、指南及材料要求仍需业务方提供。

## E2E 批次隔离复测与发布（2026-10-17 04:02）

- 发现：线上开放批次查询曾向公众返回旧式命名的 `E2E-*` 测试批次；生产六个专用 E2E 账号均没有 `metadata.e2e` 标记，直接只按 metadata 放行会阻断这些账号使用测试批次。
- 修复候选：统一开放批次 scope 排除 metadata 标记及名称/编号包含 `E2E-` 的测试批次；项目创建仅允许 `unit` 角色且 username 严格匹配 `e2e_YYYYMMDDops_unit`，或有明确 `metadata.e2e=true` 的账号选择 E2E 批次。普通单位 E2E 批次访问回归测试保留。
- 新增/调整测试：公开开放批次排除旧式命名 E2E 批次、Dashboard 排除 E2E 批次、普通单位拒绝 E2E 批次、metadata 标记测试单位允许、线上现存命名格式测试单位允许。最终全量后端 suite：`OK (211 tests, 947 assertions)`；批次/申报定向回归：`OK (31 tests, 136 assertions)`。
- 最终自动化检查通过：前端 `npm run lint`、`npm run typecheck`、`npm test -- --run`（4/4）、`npm run build`；5 个变更 PHP 文件 Pint `--test` 通过，PHP 语法检查通过，三个部署备份/发布隔离/回滚脚本模拟通过，`git diff --check` 通过。
- 本地曾缺 Composer/vendor；通过临时 bootstrap 只读复用主工作区已安装的 Composer vendor，并将 Laravel 测试环境的 `APP_BASE_PATH` 指向隔离工作区完成测试。临时 bootstrap 已删除，主工作区文件未修改。Docker 不可用，但部署模拟所需 Bash 可用且三项均通过。
- 提交 `c0750b1` 已快进推送到 GitHub `main`，并仅部署本站 release `20261017040227`；部署环境 `RUN_SEED=0`、`RUN_MIGRATIONS=0`，Laravel 登录健康检查成功，健康 token 已撤销。未重载/重启 Nginx、MySQL、服务器或其他站点。
- 部署后验证：`/api/public/application-batches/open` 返回 HTTP 200 和 `[]`；`/` 返回 200；未认证 `/api/auth/me` 返回 401 JSON；`/up` 返回 200。本站 current 指向 `/www/wwwroot/nxm.zlck888.com/releases/20261017040227`；Nginx、MySQL 均 active，本站 queue worker 2 个，`artisan queue:failed` 输出 `INFO No failed jobs found.`；所有当前登记的迁移均显示 `Ran`（本次发布未执行迁移）。
- 生产超管只读页面核验：评分模板显示 `专家评分项当前总分：100 / 100`；评分策略为专家评分开启、随机分配开启、每项目 3 位专家。用户列表有至少 4 个启用专家账号，但全周期“专家认证”页仅显示 2 条 E2E 专家认证已通过，故无法认定已有三位正式认证专家可供分配。
- 生产超管只读配置核验：OSS 开关已开启、Endpoint/Bucket/对象前缀已填写，AccessKey 仅显示遮罩；未执行上传/恢复，凭据有效性和远端对象状态未知。邮件配置页 Mailer 为 `log`，SMTP 主机和发件邮箱为空；未触发测试邮件。
- 批次管理页面保留多条开放 E2E 历史批次及历史默认批次；公网 `/api/public/application-batches/open` 返回 `[]`，符合只开放非 E2E 业务批次的规则。另有“测试 / 001”批次也不对公众开放；不得把测试数据改名冒充正式批次。
- 线上账号角色浏览器验证未完成：新建标签继承了已有超管会话，为保护共享会话未输入其他账号密码，也没有创建或推进项目。服务器专用账号仍保留；线上 E2E 登录及测试草稿访问需在真正隔离的浏览器上下文验证。
- 线上备份日志只读复核：本站计划任务日志记录 2026-10-16 11:19、2026-10-17 00:24、02:10 依次完成数据库/私有文件归档、归档校验和 `Uploaded and verified 2 OSS backup objects.`；2026-10-17 02:10 后按本站 14 天保留策略清理旧归档。日志另有一次 `find: Failed to restore initial working directory: /root: Permission denied`，之后三次备份成功；需在宝塔计划任务页确认失败记录是否仅为已恢复的历史运行。
- 当前 worker 只读检查：1 个 `www` 用户 `artisan queue:work database --queue=default` 进程；`flock` 正持有本站 `nxm_queue_worker.lock`。此前本站队列计数为 2，当前进程数为 1，应以 watchdog 单 worker 的现状为准；尚未核实计划任务面板中的 watchdog 调度项。
- 未对已成功上传的 OSS 对象执行 GET/下载与隔离恢复；终端本轮只读取现存日志和进程状态，没有运行备份脚本或改动服务。
- 运营限制：当前公开开放批次接口为空，故虽该版本与基础服务健康，真实申报尚不能开始。业务负责人需先在后台配置正式批次年度、起止时间、范围、指南和必传材料；不得把 E2E 批次改名冒充正式批次。

## 当前运营判断

批次隔离代码已通过自动化并上线本站，公开端点已不再暴露测试批次，基础服务健康，专家评分模板为 100 分。本站 OSS 本地归档、上传及对象长度校验已有生产日志证据，但隔离恢复未演练；当前 1 个 www 队列 worker 正常持有本站锁。系统仍未完成运营验收：正式开放批次为空；SMTP 尚未启用；仅有两条 E2E 专家认证通过记录，不能证明能为项目分配三位正式认证专家；六角色浏览器闭环、覆盖率数字、历史暴露私钥撤销/轮换仍未闭环。因此当前版本已部署，但正式开放申报前仍须完成业务配置和运营验收。

## 当前提交复测（2026-10-17）

- 隔离 checkout 后端全量：复用主工作区现成 Composer vendor，但 PHPUnit bootstrap 将 `App`、`Tests`、Factories、Seeders 和 Laravel base path 均显式指向当前隔离 checkout；`OK (211 tests, 947 assertions)`，退出码 0。临时 bootstrap 已删除，主工作区和依赖未修改。
- 当前 checkout 前端：`npm run lint`、`npm run typecheck`、`npm test`（4/4）和 `npm run build` 均退出码 0。
- 当前 checkout `git diff --check` 通过；未生成跟踪文件变更。上述为代码自动化证据，不替代生产六角色闭环、真实 SMTP 或 OSS 恢复验收。

## 生产只读复核补充（2026-10-17）

- 宝塔终端只读命令确认 current 仍为 `/www/wwwroot/nxm.zlck888.com/releases/20261017040227`；`/api/public/application-batches/open` 返回 `HTTP 200 []`；Nginx、MySQL 均为 `active`；`artisan queue:failed` 输出 `INFO No failed jobs found.`。
- 本站当前仅观察到 1 个 `www` 队列 worker，由本站 watchdog flock 锁保护。没有改动 watchdog、Supervisor、Nginx、MySQL 或其他站点。
- 备份日志最近成功记录显示 OSS 上传并通过 HEAD 对象长度校验；未读取 `.env`、RAM 密钥或上传文件内容，也未执行恢复。

## 生产邮件投递安全复核（2026-10-17）

- 缺陷 `MAIL-01`：当运行时邮件驱动为 `log` 或 `array` 时，队列邮件任务仍可能调用 Laravel mail facade，并把日志状态更新为 `sent`。这会把“未真实投递”误报为已发送；若 `log` 驱动接收密码重置邮件，还可能把含重置 token 的邮件正文写入应用日志。
- 修复：`SendMailLogJob` 在 `log/array` 驱动下不调用 mailer，将记录标记为失败并提示配置 SMTP；超级管理员测试邮件接口在非 SMTP 驱动下返回 422，不创建邮件记录。SMTP 配置仍由后台管理。
- 新增专项测试 `modernization/backend/tests/Feature/MailDeliverySafetyTest.php`：覆盖非投递驱动不发送且不标记成功、SMTP 驱动调用 mail facade 后标记成功、测试邮件接口拒绝非 SMTP 配置。
- 隔离 checkout 本身没有 `modernization/backend/vendor`。为避免安装/改动依赖，本轮只读复用主工作区现成 Composer vendor，并通过临时 `qa-bootstrap.php` 将 Laravel `APP_BASE_PATH` 及 App/Tests/Factories/Seeders PSR-4 路径绑定到隔离 checkout；脚本在测试后删除，主工作区未修改。
- 专项实际命令：`php <existing-vendor>/bin/phpunit --bootstrap modernization/backend/qa-bootstrap.php --configuration modernization/backend/phpunit.xml modernization/backend/tests/Feature/MailDeliverySafetyTest.php`；输出 `OK (3 tests, 10 assertions)`。
- 全量实际命令：`php <existing-vendor>/bin/phpunit --bootstrap modernization/backend/qa-bootstrap.php --configuration modernization/backend/phpunit.xml`；输出 `OK (214 tests, 957 assertions)`。本次测试实际执行隔离 checkout 代码与测试。
- PHP Pint 对本次 3 个 PHP 文件执行 `--test`，输出 `PASS ... 3 files`；PHP 语法检查和 `git diff --check` 通过。
- 未对生产 SMTP 配置、邮件队列或邮件日志做修改/发送。生产 mailer 仍为 `log`，之前只读 `mail_logs` 汇总为空；SMTP 真实投递仍待业务方配置参数后验证。
- 上述自动化验证通过，但不替代生产 SMTP 实际投递、队列发送及收件确认。生产仍是 `log` 驱动，因此新修复部署后预期行为是清晰标记未发送，而非假报送达。
