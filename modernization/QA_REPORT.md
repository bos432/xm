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

## 2026-10-17 18:02 功能复测

本轮遵守只读线上检查原则：未提交表单、未创建/删除业务数据、未修改生产配置，未触碰其他站点或共享服务。

### 本地工具链结果

- 后端 PHPUnit：`php vendor/bin/phpunit -c phpunit.xml`，通过 `216 tests, 965 assertions`。
- 前端安装：首次 `npm ci` 因现有 `node_modules` 的 Element Plus 目录清理失败；随后使用 `npm install --include=dev --no-audit --no-fund --force` 恢复依赖，仅修改本地未跟踪依赖目录。
- 前端 lint：`npm run lint`，通过，退出码 0。
- 前端类型检查：`npm run typecheck`，通过，退出码 0。
- 前端单元测试：`npm test`，`5 tests; pass 5; fail 0`。
- 前端构建：`npm run build`，Vite `1628 modules transformed`，构建成功，退出码 0。
- 线上公开 E2E：`E2E_BASE_URL=https://nxm.zlck888.com npm run e2e -- --grep public`，`2 passed (3.6s)`。

### 线上只读页面复测

当前超管会话打开 `https://nxm.zlck888.com/application-batches`，并依次检查：

- 申报批次：页面正常，测试/历史批次显示“不可申报”；当前没有正式可申报批次。
- 系统管理：数据字典分类子菜单正常；专家评分项显示“当前总分：100 / 100”。
- 系统配置：审核与评分入口正常；区县/部门/管理员评分关闭，专家评分和专家组随机分配开启，默认专家人数为 3。
- 审核验收：审核任务、派单规则、验收管理及各自子菜单均正常显示。
- 验收管理：历史 E2E 验收记录可以显示状态、延期状态、最近延期、提交时间和详情入口。
- 当前页面 `https://nxm.zlck888.com/acceptance` 的浏览器错误日志：`[]`。

### 本轮结论

已证实：代码级回归、前端构建、公开访问、匿名保护接口、超管只读菜单与配置页面当前正常。

仍不能声称全系统流程验收完成：

1. 正式开放批次为空，无法验证真实单位提交入口。
2. 本轮没有使用隔离六角色账号执行创建项目、提交、区县审核、部门审核、多专家评分、管理员终审、延期和验收关闭等有状态操作。
3. SMTP 实际投递、OSS 下载及隔离恢复仍没有本轮证据。
4. 生产压力、并发和整机重启恢复未执行。

以上未验证项继续保持原报告中的运营阻断级别，不以页面可打开替代业务闭环证据。

### 生产六角色只读 API 复核（2026-10-17 追加）

通过本站服务器本机读取 `/root/nxm-e2e-ops-20261016.credentials.json`（文件权限 `600`），向本站 API 发起登录和 GET 请求。登录/矩阵脚本未输出密码；但此前的凭据结构检查误打印了账号对象，包含密码，属于测试操作安全事件，不能描述为全程无明文暴露。本节阶段未创建项目、提交审核或修改配置；后续生产测试写入另见追加记录。

六角色登录结果：

```text
unit         200 login_ok
county       200 login_ok
department   200 login_ok
expert       200 login_ok
admin        200 login_ok
super_admin  200 login_ok
```

权限矩阵关键结果（`auth/me; projects; reviews/tasks; acceptance; lifecycle/expert-certifications; settings/groups`）：

```text
unit        200;200;403;200;403;403
county      200;200;200;200;403;403
department  200;200;200;200;403;403
expert      200;200;200;200;200;403
admin       200;200;200;200;200;403
super_admin 200;200;200;200;200;200
```

生产运行只读结果：

```text
current: /www/wwwroot/nxm.zlck888.com/releases/20261017173454
queue: INFO No failed jobs found.
migrations: all registered migrations Ran
```

矩阵只证明这些账号在采样时各接口返回上述状态，不证明返回数据范围正确，也不等于所有授权符合设计。单位可访问自己的项目接口；业务管理员的专家认证接口返回 200，需对照预期角色权限核验是否授权过宽。该阶段未写业务数据，后续已使用 E2E 批次新增项目和审核记录，不能将本段理解为整轮均只读。

## E2E 提交缺陷修复与后续验证（2026-10-17）

### 生产状态与范围

- 保留测试项目 ID `11`，名称 `E2E-20261017-194934-FULL-FLOW`，批次 ID `2`，不删除。
- 修复前：创建 201，提交 422，错误为“申报批次未开放，不能提交”。当时区县、部门返回 403，因为项目尚为草稿，不能将其计为审核成功。
- 根因：创建的批次解析允许专用 E2E 单位，而提交调用 `ApplicationBatch::isOpenNow()`，后者排除了所有 E2E 批次。
- 修复提交 `5f30408` 已推送 main，并仅部署本站 release `20261017211540`。发布输出明确跳过迁移、未 reload 共享服务，健康 HTTP 登录通过。
- 修复后的生产调用输出如下；接口路径依次是 `POST /api/projects/11/submit`、`POST /api/projects/11/reviews`（区县、部门分别独立登录）：

```text
SUBMIT 200 submitted county None
COUNTY 201 reviewing department None
DEPARTMENT 201 reviewing expert expert_count 3 assigned_ids [38, 27, 32] None
```

- 浏览器点击项目业务 -> 全部项目 -> 本轮 E2E 行的详情，实际可见：

```text
当前：专家评审中
下一步：等待 3 位专家全部评分后，系统自动流转到管理员终审。已完成 0 位。
分配专家 3；已评分 0；平均分 -；最高/最低 - / -
区县审核：通过；部门审核：通过
终审支持：不支持
```

截图：`qa/evidence/20261017/project-11-expert-pending.png`。这是超管只读详情证据，不是专家本人评分页面证据。当前尚未提交任何专家评分、终审或验收，完整闭环依然未完成。

### 新增边界回归

新增 `tests/Feature/E2eBatchSubmissionBoundaryTest.php`，只使用 SQLite 测试库。覆盖普通单位不能提交 E2E 批次、两种专用 E2E 身份可提交、过期/未来/关闭/归档批次被拒、带 E2E 标记的历史归集批次仍被拒；拒绝后不得改变草稿状态/提交时间或生成成功提交日志。

命令（工作目录 `modernization/backend`）：

```powershell
php vendor/bin/phpunit -c phpunit.xml --filter E2eBatchSubmissionBoundaryTest
php vendor/bin/phpunit -c phpunit.xml
php vendor/bin/pint --test tests/Feature/E2eBatchSubmissionBoundaryTest.php
php vendor/bin/phpunit -c phpunit.xml --coverage-text
```

关键输出：

```text
Boundary suite: OK (8 tests, 44 assertions), exit 0
Full suite: OK (225 tests, 1012 assertions), exit 0
Pint: PASS 1 file, exit 0
Coverage:
There was 1 PHPUnit test runner warning:
1) No code coverage driver available
WARNINGS!
Tests: 225, Assertions: 1012, Warnings: 1.
exit 1
```

覆盖率不可得；按本轮硬性验收要求，此项仍为 P0 测试门禁阻断，不能跳过或用单测通过数代替百分比。高风险文件 TOP5 仍只是静态候选，非实际未覆盖排名。

### 追加缺陷与缺失证据

| ID | 严重级 | 模块 | 复现命令/动作 | 实际 vs 预期 | 修复建议 |
| --- | --- | --- | --- | --- | --- |
| QA-08 | P1（修复已上线） | E2E 申报 | 专用 E2E 单位 `POST /api/projects` 后 `POST /api/projects/{id}/submit` | 创建成功但提交被批次资格校验拒绝；预期同一授权规则 | `5f30408` 已修复并生产复测提交成功；8 项边界回归通过 |
| QA-09 | P2 | 详情/终审展示 | 超管打开项目 11 详情 | 尚在专家阶段、无终审记录，却显示“终审支持：不支持”；预期“尚未终审/待确定” | 按终审记录是否存在区分未决定与决定不支持；未修改源码 |
| QA-10 | P1 安全事件 | 测试操作/凭据 | 凭据结构检查曾把整个账号对象打印到终端 | 六个 E2E 账号密码出现在终端和工具截图；root:600 不能消除历史泄露 | 按可能暴露处理；通过受控渠道轮换六个测试密码、撤销测试 token 并更新 root-only 文件；未经执行不能声称已处置。报告不记录密码 |
| QA-11 | 待核验 | 专家认证授权 | 业务管理员 `GET /api/lifecycle/expert-certifications` | 实际 200，旧报告误写为 403；预期须对照正式角色权限确认 | 复核角色权限及数据范围，不能仅凭 200 判定安全 |

后续阻断：专家分配为 38、27、32，当前受控文件仅含专家 38，尚缺专家 27/32 的现有登录凭据；不能冒充专家、重置未知账号或降低专家人数制造闭环。正式批次、SMTP 真实投递、OSS 下载/隔离恢复、六角色 UI 闭环和截图版完整交付仍未完成。公开正式批次为空不妨碍已授权 E2E 批次验收，但不得把 E2E API 流程当作正式业务或完整 UI 验收。

## QA-09 修复验证（2026-10-17，发布状态单独记录）

代码提交 `630b345` 修复无终审支持记录被默认显示为“不支持”的问题：详情 API 在无支持记录时返回 null 结论/总金额；项目详情和审核详情两处显示“待确定”。明确不支持、分项支持和旧版补助支持记录仍按原值展示；不改数据库数据、不改审批状态。

新增 `FinalSupportPresentationTest` 的六个案例覆盖缺失/空记录、明确不支持、三类金额合计、旧版补助和旧版无支持。首跑因测试夹具缺少 `unit_id` 产生 6 errors，已补齐单位/所有人关联后重跑；不将首跑算作通过。

命令与输出（后端目录）：

```text
php vendor/bin/phpunit -c phpunit.xml --filter FinalSupportPresentationTest
OK (6 tests, 38 assertions)
exit 0

php vendor/bin/phpunit -c phpunit.xml
OK (231 tests, 1050 assertions)
exit 0

php vendor/bin/pint --test app/Http/Controllers/ProjectController.php tests/Feature/FinalSupportPresentationTest.php
PASS 2 files
exit 0
```

前端目录命令：`npm run lint`、`npm run typecheck`、`npm test`、`npm run build`；均退出 0，单测 5/5，Vite 1628 modules transformed，built in 439ms。

注意：现有 `scripts/typecheck-utilities.mjs` 仅对 `src/utils/timeline.js` 做注释检查及 `node --check`，不是 Vue/整个前端的 TypeScript 语义检查。以前的“类型检查通过”只能指这个脚本；项目级类型安全证据仍缺失，不能用该输出代替。

发布状态：提交 `630b345` 已在本地生成，前两次 GitHub 推送均报 `Recv failure: Connection was reset`。此时未执行生产部署，QA-09 仍为“本地已修复，线上未复验”，不能标为已上线关闭。下一步仅在远端确认提交存在后部署本站，再打开项目 11 的详情复验；不得把本地测试等同于生产已修复。

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

## 邮件安全修复本站发布（2026-10-17 04:44 UTC+8）

- 提交 `bd31d2708c7cda00099dc950680beb61ce0531f8` 已推送至 GitHub `main`，随后仅部署本站 release `20261017044409`。
- 线上命令使用 `APP_ROOT=/www/wwwroot/nxm.zlck888.com`、`REPO_URL=https://github.com/bos432/xm.git`、`BRANCH=main`、`RUN_SEED=0`、`RUN_MIGRATIONS=0`；没有执行数据库迁移或 Seeder。
- deploy 输出：`Health HTTP login passed for [health_check_user]; token revoked via logout.`、`Local credential validation and HTTPS captcha/login/logout health check passed`、`Deployment complete: 20261017044409`、`Activated the release through the site current symlink; no shared services were reloaded`。
- 部署后宝塔只读核验：`current=/www/wwwroot/nxm.zlck888.com/releases/20261017044409`；开放批次 API 为 `[]`；`artisan queue:failed` 输出 `INFO No failed jobs found.`；`systemctl is-active nginx mysql mariadb` 输出 `active / active / inactive`（本站连接的服务名为 mysql，未触碰 MariaDB unit）；本站 flock watchdog 下观察到 2 个 `artisan queue:work` 进程；首页与 `/up` 均 `HTTP/2 200`。
- SMTP 设置仍未配置/投递。本次发布修复了非 SMTP 驱动的错误状态与敏感邮件正文风险，但不代表 SMTP 已运营验收。公开批次为空，系统尚未开放正式申报。

## 运营门槛复核（2026-10-17 04:50 UTC+8）

- 本站 release 仍为 `20261017044409`；只读复核输出：`HOME_HTTP=200`、`HEALTH_HTTP=200`、`OPEN_BATCHES=[]`、`INFO No failed jobs found.`；`systemctl is-active nginx mysql mysqld mariadb` 依次为 `active / active / active / inactive`。Nginx、MySQL 均正常；MariaDB 是未使用的 unit，本轮未操作。
- 通过 Laravel bootstrap 和只读 SQL `select status, count(*) ... from expert_certifications group by status` 获取汇总：线上认证表仅有 `approved: 2`，少于当前每项目随机分配人数 3。未读取专家姓名、用户字段、认证附件或任何凭据，也未修改数据库。
- 只读查询 `system_settings` 的非 secret 键确认：专家评分开关开启、随机分配开启、`review.expert_assignment.count=3`、`mail.mailer=log`；没有读取 SMTP/OSS 凭据值。
- 尝试通过 `php artisan tinker` 统计生产配置时发现该发行环境没有 Tinker 命令；该尝试未执行查询。后续只读查询在正确 Composer bootstrap 后成功。另一次初始 bootstrap 顺序错误产生 PHP 异常但未写入数据。
- 当前生产正式运营阻断项：公开正式批次为 0；approved 专家数不足当前随机派单人数；SMTP 尚未配置和实际投递；OSS 下载/隔离恢复演练缺失；六角色浏览器业务闭环仍未用独立 cookie 环境完成。除正式批次业务参数与 SMTP 运维参数外，其他验收仍需取得真正隔离的浏览器/恢复目标和审计证据。

## 线上公开与角色 Smoke 复测（2026-10-17）

- 本地执行 `E2E_BASE_URL=https://nxm.zlck888.com E2E_RUN_ID=20261017-readonly-public npm run e2e -- --grep public`（PowerShell 分别设置环境变量后执行）：`2 passed (4.2s)`。覆盖公开首页登录入口/内容，以及验证码和公开 API 状态、未认证受保护 API 的 401 JSON、敏感路径 404。
- 完整 smoke 命令 `E2E_BASE_URL=https://nxm.zlck888.com E2E_RUN_ID=20261017-role-smoke-audit npm run e2e`：`2 passed, 8 skipped (3.9s)`。通过项与公开筛选相同；六个角色页面/登录、专家认证权限 API 和超管首页/安全中心因本机缺少 `E2E_*` 凭据而 skip。skip 不能作为角色验证通过。
- 原始报告目录：`modernization/e2e/reports/runs/20261017-readonly-public/`、`modernization/e2e/reports/runs/20261017-role-smoke-audit/`。
- 既有 GitHub Actions 在线 E2E workflow 需要 GitHub Secrets 中六角色凭据并手动 dispatch；本机 `gh auth status` 为 `You are not logged into any GitHub hosts`，不能触发该 workflow。本轮未从服务器读取/复制 root-only 密码，也未在继承超管 cookie 的共享浏览器输入测试账号。
- 生产未产生项目、审核、评分、验收或其他业务写入；只读测试没有解决正式批次、专家数量、SMTP 实投、OSS 隔离恢复等运营门槛。

## 公网安全头与前端门禁复核（2026-10-17）

- 对本站 `/`、`/login`、`/dashboard`、`/projects` 执行 HTTPS GET：全部 HTTP 200，均返回 `X-Content-Type-Options: nosniff`、`X-Frame-Options: SAMEORIGIN`、`Referrer-Policy: strict-origin-when-cross-origin`、`Permissions-Policy: camera=(), microphone=(), geolocation=()`。这与 2026-10-14 记录的“静态 HTML 缺这些头”不同，当前已实际观察到静态响应头存在。
- 公共 API `/api/auth/captcha`、`/api/public/homepage`、`/api/public/application-batches/open` 为 200；未认证 `/api/auth/me`、`/api/projects`、`/api/reviews/tasks` 为 401；`/.env` 和 `/storage/logs/laravel.log` 为 404。
- API 响应出现重复的同值安全头（Nginx 与 Laravel 都设置），以及 `Access-Control-Allow-Origin: *`。目前 API 采用 Bearer token，未验证带 credentials 的跨域请求；CORS 通配项疑似来自服务器层，因同机其他站点共用 Nginx，本轮没有改共享服务器配置。建议由运维确认本站 location 是否可独立收敛，不能贸然全局更改。
- TLS SNI 证书 Subject 为 `CN=nxm.zlck888.com`，有效至 `2027-01-12 10:59:59 UTC`。
- 当前前端门禁：`npm run lint`、`npm run typecheck`、`npm test`（4/4）和 `npm run build` 均退出码 0。

## CORS 只读预检补充（2026-10-17）

- 从非本站 Origin `https://example.invalid` 对 `/api/auth/me` 发只读 OPTIONS：HTTP 204，`Access-Control-Allow-Origin: *`、仅允许 GET、允许 `authorization,content-type`，未返回 `Access-Control-Allow-Credentials`。随后带同一 Origin 的匿名 GET `/api/auth/me` 返回 `401 application/json` 和 `{"message":"Unauthenticated."}`；匿名公开首页 API 返回 200。没有发送 Authorization token、Cookie 或业务写请求。
- 结论：证据未显示浏览器可跨站携带会话凭据读取受保护 API；wildcard 仍扩大匿名公开 API 的跨站可读面。配置来源不在应用源码，推测位于站点服务器层，尚未证明具体配置文件。建议运维评估仅本站级 CORS allowlist；不得直接编辑共享 Nginx 全局配置。
- 本轮未尝试撤销历史暴露私钥：现有浏览器仅在 ECS 详情页，无法验证证书/CA 状态；文件权限收紧不能代替证书密钥轮换或撤销。

## 生产追加复核（2026-10-17 07:30 UTC+8）

- 当前验收 checkout `9bb2acf` 与 `origin/main` 相同；本轮无生产应用代码发布。
- 前端再次运行 `npm run lint`、`npm run typecheck`、`npm test`、`npm run build`：均通过；单测 `4/4`。
- 线上公开 Playwright `npm run e2e -- --grep=public`：`2 passed`。线上只读 GET `/`、`/login`、`/api/auth/captcha`、`/api/public/homepage`、`/api/public/application-batches/open`、`/up` 均 HTTP 200；开放批次响应仍为 `[]`。未认证 `/api/auth/me`、`/api/projects`、`/api/reviews/tasks` 均为 401 JSON。
- 本地后端使用已有主工作区依赖执行 `php artisan test --compact`：`176 passed (819 assertions)`。该依赖工作区含未提交修改且与验收 checkout 提交历史不一致，故只能证明该工作树的测试结果，不能代替当前 checkout 的后端套件证据。隔离 checkout 无 `vendor`，临时 bootstrap 写入被执行环境策略拒绝；未尝试绕过限制或安装依赖。
- HSTS 缺失根因已查明：本站 `/www/server/panel/vhost/nginx/extension/nxm.zlck888.com/nxm-tls.conf` 原来只有本站 TLS listener/certificate，没有 HSTS；公共安全头由本站 vhost 单独配置，不需要编辑共享 nginx.conf。已先备份为 `nxm-tls.conf.codex-backup-20261017`，再在该本站专属 TLS include 追加 `add_header Strict-Transport-Security "max-age=31536000" always;`。`nginx -t` 输出 `syntax is ok`、`test is successful` 后才执行 `nginx -s reload`；`systemctl is-active nginx` 返回 `active`。
- HSTS 公网复验：`/`、`/login`、`/api/auth/captcha`、`/up` 均 HTTP 200 且 `Strict-Transport-Security: max-age=31536000`；对应的 `X-Content-Type-Options`、`X-Frame-Options` 仍存在。此变更仅属于本站 TLS 扩展配置，不改 Nginx 全局配置、其他站点、MySQL 或应用代码；宝塔若重建站点 TLS 配置，须再次核验。
- 运营阻断仍在：正式开放批次为 0；已有证据仅显示 2 个 approved 专家认证记录，少于派单人数 3；SMTP 尚未配置并实投；OSS GET/隔离恢复未验；六角色浏览器业务闭环未完成。没有创建、审批、评分、验收任何生产业务记录。

## 2026-10-17 后续复测（隔离 checkout）

- 前端 `npm run lint`、`npm run typecheck`、`npm test`、`npm run build` 均通过，单测 4/4。
- `bash -n` 检查本站备份、部署安全、回滚脚本通过；依次运行 `site-backup-test.sh`、`deploy-release-safety-test.sh`、`deploy-rollback-test.sh` 均通过，最终输出 `Deployment isolation and rollback checks passed.`
- 线上只读 Chromium 命令 `$env:E2E_BASE_URL='https://nxm.zlck888.com'; npm run e2e -- --grep public`：`2 passed (3.5s)`。
- PowerShell `Invoke-WebRequest` 只读探测：`/`、`/login`、`/api/auth/captcha`、`/api/public/homepage`、`/up` 均 HTTP 200；未认证 `/api/auth/me` 为 HTTP 401；所有响应含 `Strict-Transport-Security: max-age=31536000`；`/api/public/application-batches/open` 为 HTTP 200 且响应 `[]`。
- 本轮先安装缺少的测试依赖：官方 Composer PHAR、`php -d extension=zip composer.phar install --no-interaction --prefer-dist --no-progress --no-scripts --working-dir=modernization/backend`，按已锁定版本安装 110 个包；未修改 composer.json/lock，临时 PHAR 已删除，vendor 为 gitignored 本地目录。普通 `php artisan test --compact` 不可用（项目未注册 Laravel test 命令），改用官方 `php -d extension=zip vendor/bin/phpunit -c phpunit.xml`：`OK (216 tests, 965 assertions)`。Dashboard 定向测试：`OK (7 tests, 35 assertions)`。Pint 修正 DashboardController 后，三个文件 Pint 检查通过，PHP lint 无语法错误。
- 覆盖率命令 `php -d extension=zip vendor/bin/phpunit -c phpunit.xml --coverage-text` 完成 216 tests/965 assertions，但 PHPUnit 警告 `No code coverage driver available`，所以没有可报告的覆盖率百分比。
- 本地 `gh auth status` 显示未登录；Git Credential Manager 仅显示账户名 `bos432`，远端 `git ls-remote origin refs/heads/main` 连接超时。未读取凭据。本地 dashboard 权限修复 `5e870b24bf1bbad687239dfdbc956149668c71cf` 仍未推送/部署。
- `git diff --check` 通过。当前本地存在 QA 报告更新及 DashboardController 格式化改动，尚未提交。没有生产写操作、没有登录/切换角色、没有创建或推进项目。

**运营结论仍为未就绪：**公开正式批次为空，单位无法开始正式申报；SMTP 实投、OSS 隔离恢复、六角色完整闭环和覆盖率数字仍未验收。基础公开入口健康不等于业务流程全部正常。

## Dashboard 权限修复部署复核（2026-10-17 17:00 UTC+8）

- `193cd17de3fbc7f9692802317236e49cb0386e7d` 已位于 GitHub `main`；通过本站 `modernization/deploy/deploy.sh` 部署，`RUN_SEED=0`、`RUN_MIGRATIONS=0`。release 为 `20261017165958`，current 已切到 `/www/wwwroot/nxm.zlck888.com/releases/20261017165958`。
- 部署脚本完成依赖安装、Laravel 配置/路由缓存、current 原子切换和站点健康检查；日志关键行：`Health HTTP login passed for [health_check_user]; token revoked via logout.`、`Local credential validation and HTTPS captcha/login/logout health check passed`、`Deployment complete: 20261017165958`、`no shared services were reloaded`。
- 发布后本站只读核验：`FAILED_JOBS=0`、`NGINX=active`、`MYSQL=active`、首页 `200`、未认证 `/api/auth/me=401`、公开开放批次 `[]`。未触碰其他站点，也没有重载/重启共享服务。
- 发布后浏览器共享超管会话可访问批次管理页面，页面仍列出多条历史及测试批次状态“开放”，其时间范围包含已过期记录；这与公开开放批次 API 返回 `[]` 并不矛盾，但不应把这些测试/历史记录当作正式申报批次。没有关闭、删除或改名任何批次。
- 本次上线仅证明 Dashboard 系统运行数据权限修复已部署，以及发布健康门禁通过；不能代表整套业务达到正式运营条件。正式批次仍未配置；认证专家数是否满足实际派单需求、SMTP 实投、OSS 隔离恢复、六角色真实业务全流程仍需单独验收。

## 六角色生产认证与 API 权限复核（2026-10-17）

- 服务器 `/root/nxm-e2e-ops-20261016.credentials.json` 权限为 `0600`。凭据仅由服务器 Node 进程读入内存；没有打印或传输用户名、密码、token，也没有写入仓库/报告。六个专用账号分别登录后调用 `/api/auth/me` 核验角色，再退出；6/6 登录 HTTP 200、身份匹配、logout HTTP 204。
- 六角色只读 API 矩阵按固定顺序为：`dashboard summary, projects, review tasks, review results, acceptance, lifecycle task-books, lifecycle progress, lifecycle rectifications, expert certifications, settings groups`。逐角色状态码：

| 角色 | HTTP 状态码（按上述接口顺序） |
| --- | --- |
| unit | `200, 200, 403, 403, 200, 200, 200, 200, 403, 403` |
| county | `200, 200, 200, 200, 200, 200, 200, 200, 403, 403` |
| department | `200, 200, 200, 200, 200, 200, 200, 200, 403, 403` |
| expert | `200, 200, 200, 200, 200, 200, 200, 200, 200, 403` |
| admin | `200, 200, 200, 200, 200, 200, 200, 200, 200, 403` |
| super_admin | `200, 200, 200, 200, 200, 200, 200, 200, 200, 200` |

- 权限边界符合预期：单位不能查看审核任务/结果、专家认证和系统配置；普通审核/业务角色不能访问系统配置；专家认证接口只向专家及更高管理角色开放。矩阵只记录响应状态，不读取或保存项目详情响应。
- 生产 Chromium UI E2E 仍未能启动：Playwright Chromium 缺少系统库 `libasound.so.2`。没有在生产机安装系统包；失败后确认临时凭据环境文件已删除、没有残留 Playwright 进程。现有控制台浏览器继续保留共享超管会话，没有切换账号。
- 以上是认证、身份及只读 API 权限验证，**不等于**六角色 UI 工作流或申报→区县→部门→多专家评分→终审→验收闭环。未创建、修改、提交、审核、评分、关闭任何生产业务记录。
- 运营门槛不变：公开开放批次为 `[]`；认证专家页面仅两条 E2E 已通过记录且派单数设置为 3；SMTP 为 `log` 未实投；OSS 下载及隔离恢复未执行。正式运营仍未就绪。

## 生产浏览器 E2E 环境复核补充（2026-10-17）

- 重新尝试在生产服务器执行现有 Playwright 六角色用例。服务器 OpenAnolis 3 已有 Playwright Chromium 文件，但系统共享库不齐：首次启动缺 `libasound.so.2`；从服务器自身 DNF 仓库把 `alsa-lib` RPM 解到 `/tmp` 并仅通过临时 `LD_LIBRARY_PATH` 加载后，进一步缺 `libatspi.so.0`（`chrome-headless-shell: error while loading shared libraries: libatspi.so.0`）。这表明还缺桌面运行时依赖；未继续下载/安装系统包，避免扩大生产服务器变更面。
- 临时 `alsa-lib` RPM/解包目录已删除；确认没有残留 Playwright/Chromium 测试进程。未安装软件包、未改系统配置或服务。服务器 E2E 结果为 1 个公共首页用例失败于浏览器启动、9 个未运行，不能标记通过。
- 改在隔离的 Windows 验收工作区执行 `$env:E2E_BASE_URL='https://nxm.zlck888.com'; $env:E2E_RUN_ID='20261017-public-final'; npm run e2e -- --grep public`：`2 passed (3.8s)`。该结果只覆盖公开首页与匿名 API，不替代六角色 UI 工作流。
- 六角色认证、角色身份匹配及只读 API 权限矩阵已通过上一节记录的服务器端 HTTP 测试；完整页面交互路径仍未完成。

## 生产灾备条件只读复核（2026-10-17）

- 只读检查本站 `shared/storage/logs/site-backup.log` 和 `shared/backups/daily`：最近记录 `2026-10-17 02:10:01` 显示本地数据库/私有文件归档校验通过，`Uploaded and verified 2 OSS backup objects.`；本地能看到对应 `nxm-database-20261017-021001.sql.gz`（80,345 bytes）及 `nxm-private-files-20261017-021001.tar.gz`（1,639,960 bytes）。该记录仅证明 PUT 成功且 HEAD `Content-Length` 匹配，未证明 OSS GET 或恢复成功。未输出/读取 AccessKey。
- 当前 release 的上传命令 `site:backup:oss` 只实现 PUT+HEAD，没有对象下载/恢复功能；本轮没有通过额外命令修改或扩展生产代码。
- 只读检查恢复准备：生产主机为 Alibaba Cloud Linux 3，具备 mysql/mysqldump/gzip/tar；未发现可查询的隔离数据库管理连接。尝试 Artisan `tinker` 查询配置时命令不存在；未尝试读取 `.env` 或数据库密码。既有部署手册明确生产 DB 用户没有创建隔离数据库权限。故未执行 OSS 对象 GET、解压或数据库恢复，避免触碰生产库。
- Chromium UI E2E 生产重试：自发行版 DNF 仓库将 `alsa-lib` RPM 解包到 `/tmp`、只用临时 `LD_LIBRARY_PATH`，没有安装包；Chromium 随后仍因 `libatspi.so.0` 缺失启动失败。临时目录已删除、无测试进程残留。没有改变服务器软件包、服务或其他站点。
- 两个仍需外部运维条件的验收项：提供最小权限的隔离 MySQL 恢复目标/临时授权；在隔离测试镜像或维护流程内准备 Chromium 所需的完整运行时依赖。正式批次业务参数、真实认证专家以及 SMTP 测试邮箱仍需业务/邮件管理员提供，不能由技术侧伪造。

## Dashboard 系统运行数据角色隔离线上复验（2026-10-17）

- 使用六个专用 E2E 账号分别登录，GET `/api/dashboard/summary` 后只检查 `security`、`migration`、`operation_logs` 三个字段的 null/present 状态，不读取内部统计、日志或安全事件内容；每个账号均登出。
- `unit/county/department/expert/admin`：Dashboard HTTP 200，三个敏感字段均为 `null`。
- `super_admin`：Dashboard HTTP 200，三个字段均为非空（内容未读取）。总体 `DASHBOARD_ROLE_ISOLATION=PASS`。
- 该结果验证本地修复 `5e870b2` 已在生产生效；没有写入业务数据。

## OSS GET 验证尝试（2026-10-17）

- 尝试在服务器通过应用运行时读取加密 OSS 配置，并下载最新数据库/私有文件对象到随机名临时目录，仅比较长度和 SHA-256，不解压、不恢复。临时 PHP 脚本因 shell/base64 转义错误，在 PHP 第 6 行解析失败；错误发生在 Laravel bootstrap、配置读取和发起网络请求之前，因此**没有执行 OSS GET，也没有验证对象读取权限**。
- `/tmp/nxm-oss-verify.php` 后续只读确认不存在；没有创建或保留下载归档，没有变更 OSS 配置/权限或生产数据。该项仍为未验证，不能据此判定 OSS 成功或失败。

## 本轮功能复测（2026-10-17）

### 自动化命令

前端命令：`npm run lint`、`npm run typecheck`、`npm test`、`npm run build`（工作目录 `modernization/frontend`）。

```text
lint: exit code 0
typecheck: exit code 0
tests 4; pass 4; fail 0
vite v8.0.16; 1628 modules transformed
✓ built in 6.10s
exit code: 0
```

后端命令：`php -d extension=zip vendor/bin/phpunit -c phpunit.xml`（工作目录 `modernization/backend`）。

```text
OK (216 tests, 965 assertions)
exit code: 0
```

部署/备份隔离验证命令：`bash -n ../deploy/site-backup.sh ../deploy/tests/site-backup-test.sh ../deploy/tests/deploy-release-safety-test.sh ../deploy/tests/deploy-rollback-test.sh && bash ../deploy/tests/site-backup-test.sh && bash ../deploy/tests/deploy-release-safety-test.sh && bash ../deploy/tests/deploy-rollback-test.sh`。

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

### 生产只读检查

线上公开浏览器命令：`$env:E2E_BASE_URL='https://nxm.zlck888.com'; $env:E2E_RUN_ID='20261017-functional-smoke'; npm run e2e -- --grep public`。

```text
ok 1 public homepage exposes portal login and no duplicate old registration link
ok 2 public and anonymous API probes return safe responses
2 passed (3.4s)
exit code: 0
```

PowerShell 对 `/`、`/login`、`/api/auth/captcha`、`/api/public/homepage`、`/api/public/application-batches/open`、`/up`、`/api/auth/me`、`/api/projects`、`/api/reviews/tasks` 执行只读 GET：

```text
/ HTTP=200
/login HTTP=200
/api/auth/captcha HTTP=200
/api/public/homepage HTTP=200
/api/public/application-batches/open HTTP=200 []
/up HTTP=200
/api/auth/me HTTP=401
/api/projects HTTP=401
/api/reviews/tasks HTTP=401
```

浏览器当前后台 `/settings?group=backup` 可正常渲染；展示队列驱动 `database`、待处理任务 `0`、失败任务 `0`。OSS 启用开关及 endpoint/bucket/前缀字段正常显示，密钥仅显示掩码占位，本轮未读取/编辑密钥、未点保存。该页面浏览器控制台错误条目为 `[]`。

### 仍未验证 / 运营阻断

- 页面/自动化冒烟不等于每个菜单的端到端业务验证；六角色申报、逐级审核、多专家评分、延期和验收完整 UI 链仍未完成。
- 正式开放批次仍为 `[]`，单位当前不能开始正式申报；不擅自创建正式业务批次。
- SMTP 尚未配置且未实投；OSS 对象 GET/隔离恢复仍未完成；不能把已有上传/HEAD 或 shell 模拟当成恢复成功。
- 覆盖率驱动不可用，覆盖率百分比未知。
- 本轮没有生产写操作，没有修改应用/系统配置、数据库或其他站点服务。

## 生产运营数据复核补充（2026-10-17）

使用当前已登录的超级管理员后台只读检查：

- `/settings?group=review` 正常渲染。区县/部门/管理员评分开关关闭，专家评分开启，专家组随机分配开启，默认专家人数为 `3`；队列待处理 `0`、失败 `0`。未点击保存。
- `/lifecycle?tab=expert_certifications` 显示 2 条已通过的专家认证，两个账号均为 E2E 测试专家。先前从 `/lifecycle` 默认任务书标签误把“无数据”当成专家认证空表；带正确 `tab` 参数复验后已纠正该判断。生产可用于正式业务的认证专家仍为 0 条可确认，少于默认派单人数 3。
- `/application-batches` 当前显示“测试 001”、多条 `E2E-*` 批次及“历史默认批次”状态为“开放”，部分批次开始/结束日期已过；此前公网 `/api/public/application-batches/open` 返回 `[]`。没有关闭/归档这些历史数据。管理页面状态可能是存储状态，公开接口还按业务可申报条件过滤；需由批次管理页面明确区分“状态开放但时间已过/测试批次不可申报”，避免管理员误以为可以正式申报。
- 宝塔本站只读检查输出：`CURRENT=/www/wwwroot/nxm.zlck888.com/releases/20261017165958`、`NGINX=active`、`MYSQL=active`；本站 watchdog 与锁保护下可见两个 `artisan queue:work database --queue=default --tries=3 --timeout=90 --sleep=3` 进程。`queue:failed` 未发现失败任务。最新可见备份日志为 `2026-10-17 02:10:01`，记载本地归档校验和 `Uploaded and verified 2 OSS backup objects.`；这仍只是 PUT/HEAD 证据，不是 GET/恢复证据。
- 宝塔终端曾显示前次 OSS PHP 验证尝试因脚本解析错误退出，随后 `VERIFY_SCRIPT_ABSENT`；本轮没有再尝试传输/下载 OSS 对象，也没有在生产机运行新脚本。

### 新增/更新验收问题

| ID | 严重级 | 模块 | 复现命令/证据 | 实际 vs 预期 | 修复/验收建议 |
| --- | --- | --- | --- | --- | --- |
| QA-08 | P1 严重（运营就绪阻断） | 专家认证/随机派单 | 超管打开 `/lifecycle?tab=expert_certifications`；两条已通过记录均为 E2E 专家；规则默认派单 3 人 | 认证条目存在但都是测试账号，且数量少于派单人数；正式项目无法证明有足够合格专家 | 由业务管理员录入并审核真实专家认证，数量满足启用的派单规则后，在隔离项目上验收随机派单；不伪造认证记录 |
| QA-09 | 已修复，待部署 | 申报批次状态提示 | 超管打开 `/application-batches`；线上当前可见过期 E2E/历史批次状态仍为“开放”，公网开放批次 API 为 `[]` | 管理页面“开放”字面状态与当前不可申报结果容易混淆 | 前端已增加“申报资格”派生提示并通过测试；待 GitHub 网络恢复后推送、部署本站并验证历史/E2E/有效时间窗标签 |

当前是否适合正式开放申报：**否**。可观察到的硬阻断仍包括无正式公开批次、正式认证专家不足（已见 2 条记录均为 E2E 专家，少于 3 人派单配置）、SMTP 未实投、OSS 下载/隔离恢复未验证，以及六角色完整浏览器业务闭环未验收。

## 申报批次资格提示修复（2026-10-17）

- 缺陷：批次管理页只显示持久化状态“开放”，对过期、尚未开始、E2E 测试批次和历史默认批次没有说明当前能否申报；管理员可能把状态误读为公众可申报。
- 修改：列表新增“申报资格”说明，分别提示测试批次不可申报、历史默认批次不可申报、当前状态不可申报、尚未开始、已结束或当前可申报。只读派生显示，不改批次数据、状态或公开 API。
- 新增 6 个纯函数断言，覆盖 E2E、历史默认、已过期、未开始、有效时间窗和关闭批次。
- 前端验证：`npm run lint`、`npm run typecheck`、`npm test`（5/5）及 `npm run build` 全部通过，Vite 8.0.16 构建 1628 个模块成功。
- 提交 `71b3ad4 fix: clarify application batch eligibility` 已在本地创建。两次 `git push origin HEAD:main` 均失败：`Failed to connect to github.com port 443 after 210xx ms: Could not connect to server`；已尝试 Git `http.sslBackend=schannel` 仍失败。故该修复**尚未推送或部署**，不能声称线上已生效；待网络恢复后推送，再按本站 release 流程以 `RUN_SEED=0`、`RUN_MIGRATIONS=0` 发布并回归。
- 后续网络复核：`Resolve-DnsName github.com -Type A` 返回 `20.205.243.166`；`Test-NetConnection github.com -Port 443 -InformationLevel Quiet` 返回 `TCP connect ... failed`、`False`。目前本地 `main` 基点 `cdc993a` 后有修复提交 `71b3ad4` 和报告提交 `7c6fc66`、`5851af5`；远端 `main` 未更新。推送失败期间没有尝试绕过 GitHub 或直接上传服务器。
- 本次修复从 `origin/main` 文档提交 `cdc993a` 直接创建单独提交，未夹带隔离分支上其他领先提交。`modernization/frontend/dist` 为构建产物且被忽略，不进入提交。
- 最新运营门槛仍为：公网正式开放批次 `[]`；可确认的认证记录只有 2 条 E2E 专家；SMTP 未实投；OSS GET/隔离恢复、六角色业务闭环未验收。当前不能开放正式申报。

## 批次资格提示发布及线上复验（2026-10-17 17:35 UTC+8）

- GitHub 网络恢复后，`git fetch origin main` 确认远端仍为 `cdc993a`，本地提交以其为祖先快进推送：`cdc993a..0966098 HEAD -> main`；`git ls-remote origin refs/heads/main` 返回 `0966098d15374fd25e09713c54904aa65b29308a`。
- 仅对 `/www/wwwroot/nxm.zlck888.com` 执行 `deploy.sh`，配置 `BRANCH=main`、`RUN_SEED=0`、`RUN_MIGRATIONS=0`。部署日志：`Database migrations skipped`、`Activated the release through the site current symlink; no shared services were reloaded`、`Health HTTP login passed for [health_check_user]; token revoked via logout.`、`Deployment complete: 20261017173454`。Composer 镜像部分包返回 404 后脚本回退并成功完成依赖安装；没有改锁文件或迁移数据库。
- 线上超管 `/application-batches` 实测：普通过期批次显示“申报时间已结束”；E2E 批次显示“测试批次，不可申报”；`HISTORY-DEFAULT` 显示“历史默认批次，不可申报”。浏览器控制台错误 `[]`。没有保存表单或改动批次。
- 公网只读 GET：`/`、`/login`、`/api/auth/captcha`、`/api/public/homepage`、`/api/public/application-batches/open`、`/up` 均 HTTP 200；开放批次正文仍是 `[]`；匿名 `/api/auth/me`、`/api/projects` 均 HTTP 401。
- 宝塔发布后本站检查：`CURRENT=/www/wwwroot/nxm.zlck888.com/releases/20261017173454`、`NGINX=active`、`MYSQL=active`、`FAILED_JOBS=0`、本站 `artisan queue:work database --queue=default` worker 数 `2`、`OPEN_BATCHES=[]`。部署脚本未重载共享服务；其他站点未改动。
- 此次只解决批次状态“开放”与实际申报资格不一致造成的后台误读，不会创建正式批次。当前正式运营仍不就绪：无正式公开批次；两条已通过认证均是 E2E 专家且少于 3 人派单配置；SMTP 未配置实投；OSS GET/隔离恢复未验证；六角色完整真实业务浏览器闭环未验收。

## 当前线上状态复核（2026-10-17 17:45 UTC+8）

- 当前源码发布仍是本站 release `20261017173454`（main 代码提交 `0966098`），`nginx`、`mysql` 均为 active；本站队列 worker 观察到 2 个，`queue:failed` 为 0。部署命令明确跳过 migration/seeder、没有重载共享服务。
- 批次资格 UI 发布后复验通过：普通过期批次显示“申报时间已结束”；E2E 名称批次显示“测试批次，不可申报”；历史默认批次显示“历史默认批次，不可申报”。公网 `/api/public/application-batches/open` 仍 HTTP 200 且为 `[]`，匿名 `/api/auth/me` 和 `/api/projects` 为 401。
- 本机再次运行前端 `npm run lint`、`npm run typecheck`、`npm test`（5/5）及 `npm run build`，均退出码 0；线上 Chromium 公开 E2E `E2E_RUN_ID=20261017-post-deploy-final npm run e2e -- --grep public` 为 `2 passed (4.1s)`。不代表六角色流程通过。
- 尝试以应用运行时配置对 OSS 最新数据库/私有文件归档执行只读 GET+SHA-256 校验，但宝塔终端传输 Base64 脚本失败，未达到 PHP lint、Laravel bootstrap 或 OSS 请求；另一次压缩传输未得到脚本输出且终端重连。之后经同一终端确认 `/tmp/nxm-oss-read-check.php` 为 `SCRIPT_ABSENT`，没有残留校验进程。没有发起 OSS GET、没有下载/解压/恢复归档。OSS 对象读取和隔离恢复继续标记为未验证。
- 本地临时校验脚本已删除，Git 工作区未留下源码或未跟踪临时文件。此处不把脚本传输尝试记作 OSS 验收成功，也没有修改生产数据、OSS 权限、站点配置或其他服务。
- 正式运营仍不就绪：公开正式批次为 0；仅有 2 条 E2E 专家认证通过记录而派单人数为 3；SMTP 未配置并未实投；OSS GET/隔离恢复无证据；六角色完整 UI 业务闭环未完成。需要业务方提供正式批次参数、足量真实认证专家及 SMTP 测试收件箱；需要运维提供隔离恢复目标/授权。当前不得开放正式申报。

## 本轮线上功能复核（2026-10-17 22:00 UTC+8）

本轮仅对本站 `nxm.zlck888.com` 做发布后的只读检查和页面浏览，没有修改其他站点、生产业务数据或系统级服务。

### 发布与基础健康

部署命令使用 `RUN_SEED=0 RUN_MIGRATIONS=0`，部署输出包含：

```text
Database migrations skipped; set RUN_MIGRATIONS=1 only after reviewing pending migrations and backing up the app database
Activated the release through the site current symlink; no shared services were reloaded
Health HTTP login passed for [health_check_user]; token revoked via logout.
Local credential validation and HTTPS captcha/login/logout health check passed
Deployment complete: 20261017215647
```

部署后本站只读命令及完整关键输出：

```text
readlink -f /www/wwwroot/nxm.zlck888.com/current
/www/wwwroot/nxm.zlck888.com/releases/20261017215647
HOME_HTTP=200
ANON_PROJECTS_HTTP=401
OPEN_BATCHES=[]
```

结论：本站发布切换成功，匿名项目接口未泄露数据；当前没有正式公开申报批次，因此不能从公网完整走新增正式申报流程。

### 超级管理员页面复核

- `系统管理 -> 数据字典 -> 专家评分项` 可直达，页面显示 `专家评分项当前总分：100 / 100`，并提示评分模板正常。
- `系统管理 -> 系统配置 -> 审核与评分` 可直达，页面显示：区县审核评分关闭、部门审核评分关闭、专家评审评分开启、管理员终审评分关闭、专家组随机分配开启、默认专家人数 `3`。
- `审核验收` 菜单可展开为审核任务、派单规则、验收管理；验收管理可展开全部验收、待处理验收、已处理验收、全部可见、草稿验收、审核中验收、已关闭验收。
- 项目 11 详情显示完整基础信息、申报摘要、项目概述、预算/设备/承诺、阶段记录、审核记录和专家评分汇总；当前显示“专家评审中”，分配专家 `3`、已评分 `0`，下一步提示等待 3 位专家全部评分。
- 同一项目未完成终审时，详情显示 `终审支持：待确定`、`支持资金：待确定`，不再把缺失终审记录误显示为“不支持/0 元”。
- 上述页面浏览未发现浏览器控制台错误；本轮未点击保存、未改变评分开关、未改变专家人数、未改变字典数据。

### 未完成或不能宣称通过的检查

- 六角色真实浏览器闭环仍未完成：当前项目虽已完成单位提交、区县审核、部门审核并生成 3 人专家组，但 3 位专家的现有登录凭据不完整，不能冒充、重置未知账号或降低专家人数，因此未代替专家提交评分。
- 专家评分保存后自动流转管理员终审、终审支持分项保存、验收线上闭环、延期申请处理和完成关闭，尚未取得真实页面操作证据。
- 正式批次为 `[]`，不能验证正式申报入口、正式批次边界和单位新增项目提交。
- SMTP 仍未配置实投；OSS 仍只有上传/HEAD 证据，GET 和隔离恢复未验证。
- PHPUnit 覆盖率驱动仍不可用，因此没有覆盖率百分比；`npm run typecheck` 仍只是项目现有的工具文件检查，不等同于完整 Vue/TypeScript 类型检查。

### 当前结论

已验证的页面、权限、菜单、评分模板、本站发布健康检查均通过；但系统不能标记为“所有功能已验收”或“已具备正式运营条件”。正式开放前至少还需要正式申报批次、足量已认证专家、六角色评分/终审/验收闭环、SMTP 实投验证及 OSS 恢复演练。

## 线上审核结果与验收页补充复核（2026-10-17 22:20 UTC+8）

- 超管进入 `审核验收 -> 审核任务 -> 审核结果`，等待接口完成后显示 `Total 29` 条审核结果；其中包含项目 11 的部门审核、区县审核记录，以及已有 E2E 项目的专家评分明细。结果列表按审核时间倒序，并可切换第 2 页查看历史记录。
- 超管进入 `审核验收 -> 验收管理 -> 待处理验收`，页面显示 `No Data`；切换到 `全部可见` 后能看到 2 条已关闭验收记录，包含项目、状态、当前阶段、延期状态、提交时间、验收说明和详情/延期入口。
- 当前项目 11 仍处于专家评审中，尚未生成验收申请；因此“待处理验收为空”不能证明验收闭环通过，也不能认定为页面缺陷。单位实际操作仍应由有权限账号点击“发起验收”，上传批次要求的材料，再提交验收审核。

### 本地回归命令与完整输出

```text
cd modernization/backend
php vendor/bin/phpunit -c phpunit.xml
PHPUnit 11.2.6
OK (231 tests, 1050 assertions)
exit 0

cd ../frontend
npm run lint
exit 0

npm test
5 tests, 5 pass, 0 fail
exit 0

npm run build
vite v8.0.16
1628 modules transformed
built in 464ms
exit 0
```

覆盖率仍无法执行：当前 PHP 环境没有可用 code coverage driver；项目现有 `npm run typecheck` 也只是工具文件检查，不是完整 Vue/TypeScript 类型检查。这两项不能宣称通过。

## 验收专项自动化复核（2026-10-17 22:35 UTC+8）

```text
cd modernization/backend
php vendor/bin/phpunit -c phpunit.xml --filter ProjectAcceptanceWorkflowTest
OK (13 tests, 71 assertions)
exit 0

cd ../frontend
npm run typecheck
exit 0

cd ../backend
php vendor/bin/phpunit -c phpunit.xml --coverage-text
Tests: 231, Assertions: 1050, Warnings: 1
Warning: No code coverage driver available
exit 1
```

验收专项自动化覆盖：管理员 E2E/非 E2E 范围筛选、审核人待处理/已处理/全部可见隔离、单位不能查看其他单位验收、批次配置的必传验收材料校验。线上仍没有对项目 11 伪造或跳过验收申请；真实单位提交材料后的多角色验收尚未完成。

## 上线前依赖与部署隔离复核（2026-10-17 23:00 UTC+8）

```text
npm audit --omit=dev --audit-level=moderate
found 0 vulnerabilities

bash -n deploy/deploy.sh deploy/site-backup.sh \
  deploy/tests/site-backup-test.sh \
  deploy/tests/deploy-release-safety-test.sh \
  deploy/tests/deploy-rollback-test.sh
exit 0

bash deploy/tests/site-backup-test.sh
PASS database and private uploads are archived and verified without exposing credentials
PASS dump failure preserves existing backups and removes partial files
PASS OSS failure preserves the newly verified local archives and skips retention cleanup
PASS retention removes only expired archives owned by this site

bash deploy/tests/deploy-release-safety-test.sh
PASS successful deploy backs up database, switches current, and does not reload nginx
PASS failed HTTP login health check restores the previous release
PASS missing health credentials fail before switching releases
PASS failed database backup stops before release switch and migration
PASS empty database backup stops before release switch and migration
PASS SQLite database backup is made before migration
PASS relative SQLite path is rejected before migration

bash deploy/tests/deploy-rollback-test.sh
Deployment isolation and rollback checks passed.
exit 0
```

### 质量门记录

- 当前 Windows checkout 的 `core.autocrlf=true`。直接执行全量 `php vendor/bin/pint --test` 返回失败，报告 `146 files, 131 style issues`，主要是 checkout 换行和既有格式规则差异；本轮未对 146 个文件做大范围格式化，避免无关代码变更。此前针对本轮修改文件的 Pint 检查仍通过。
- 本节所述首次 `composer audit` 尝试因本机未安装 Composer CLI 未能执行；2026-10-18 隔离复验后来通过 Composer 官方 SHA-384 校验的临时 PHAR 对候选 lockfile 完成审计，结果 `No security vulnerability advisories found.`。这只证明候选 lockfile，不代表生产当前 release 已更新。
- 本轮没有修改源码、依赖、生产配置或其他站点，仅追加 QA 报告。上述质量门缺口不影响已运行的 PHP/前端测试，但在正式运营验收记录中保留为未完全验证项。

服务器端补充：本站当前 release 上执行 `/www/server/php/83/bin/php composer.phar audit --no-interaction --format=summary`，完整摘要输出 `Found 50 security vulnerability advisories affecting 13 packages.`。详细输出确认锁定包 `symfony/routing v7.3.0` 有 medium 级 URL Generator 路径遍历 / Host 注入类公告；其他 12 个受影响包尚未逐项导出核对。命令只读，未改 lock/vendor 或运行中服务。该项为生产安全阻断；需在隔离 checkout 用 Composer 漏洞数据库核对 13 包、做最小兼容升级并跑完整测试后，只部署本站。

## 隔离候选分支复验（2026-10-18）

范围：仅在 worktree `codex/composer-security-fix`、候选提交 `ac2b358c95afca6242b91186ff9c5f20a61db560` 运行；没有源码/配置/依赖版本修改、生产访问写入或线上 E2E。`npm ci` 仅还原 lockfile 依赖，`node_modules` 被 Git 忽略。

### 验收清单增量

| 编号 | 能力/门禁 | 状态 | 证据 |
| --- | --- | --- | --- |
| A-14 | 前端依赖锁定安装、lint、单测、工具类型检查、生产构建、npm 漏洞审计 | 已覆盖测试 | 下方原始输出：lint通过、5/5单测、typecheck/build通过、npm audit 0漏洞 |
| A-15 | 后端 PHPUnit 全量测试 | 已覆盖测试 | 231 tests、1050 assertions 全通过；未产生覆盖率 |
| A-16 | Composer manifest/lock 审计 | 本机无法验证 | 当前 Windows 环境无 Composer CLI/PHAR；报告中已有候选 CI 成功记录，但本轮无法独立重取 workflow 日志 |
| A-17 | 站点备份、发布隔离、健康失败回滚模拟 | 已覆盖测试 | 三组 Bash 模拟全部通过 |
| A-18 | 六角色真实业务闭环、邮件投递、OSS 隔离恢复 | 未验证 | 按本轮边界不运行有写入性的线上 E2E；保持为运营验收缺口 |

### 本轮命令与输出

前端：`npm ci --include=dev --include=optional --no-audit --no-fund && npm run lint && npm test && npm run typecheck && npm run build && npm audit --audit-level=moderate`

```text
added 167 packages in 17s
eslint src tests --ext .js,.vue: exit 0
tests 5; pass 5; fail 0
typecheck: exit 0
vite v8.0.16; 1628 modules transformed; built in 605ms; exit 0
found 0 vulnerabilities
```

后端：`php vendor/bin/phpunit --no-coverage`

```text
PHPUnit 11.5.57
Runtime: PHP 8.3.30
OK (231 tests, 1050 assertions)
exit code: 0
```

Composer CLI 探测与尝试：`composer validate --no-check-publish; composer audit --locked; php vendor/bin/phpunit --no-coverage`

```text
composer: 术语 'composer' 不会被识别为 cmdlet、函数、脚本文件或可执行程序的名称。
composer: 术语 'composer' 不会被识别为 cmdlet、函数、脚本文件或可执行程序的名称。
PHPUnit 11.5.57 ... OK (231 tests, 1050 assertions)
```

说明：PowerShell 使用分号继续后续命令，故 PHPUnit 通过不能算作 Composer 两项通过。Composer 本轮状态是未能运行；既有 CI 记录不替代本机复核。

部署安全模拟：`bash -n modernization/deploy/deploy.sh modernization/deploy/site-backup.sh modernization/deploy/tests/site-backup-test.sh modernization/deploy/tests/deploy-release-safety-test.sh modernization/deploy/tests/deploy-rollback-test.sh modernization/deploy/tests/mock-command.sh && bash modernization/deploy/tests/site-backup-test.sh && bash modernization/deploy/tests/deploy-release-safety-test.sh && bash modernization/deploy/tests/deploy-rollback-test.sh`

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

工作区：`git diff --check` 通过（仅有 CRLF 提示）；`git status --short` 仅显示本报告和 `modernization/docs/security-upgrade-20261018.md` 两个预期文档修改。依赖安装目录为忽略项。未生成覆盖率：本机无 `pcov`/`xdebug`；报告不提供虚构百分比或 TOP5 覆盖排名。

### 当前遗留与发布结论

- 生产 Composer 审计曾报 50 条 advisory / 13 个包；候选分支 CI 记录显示 Composer audit 成功，但本轮没有本机 Composer 可复跑，也无法用未登录的 GitHub CLI 重新核对日志，因此本地复验只能记为“无法验证”。
- `gh run list --branch codex/composer-security-fix --limit 5 --json databaseId,name,status,conclusion,headSha` 输出要求先运行 `gh auth login`，当前没有 GitHub CLI 登录态。
- 不部署候选。通过 CI 和隔离自动化不等于完成生产等价 staging 恢复演练；六角色写入闭环、SMTP 实投、OSS 下载恢复、容量及灾备恢复仍未完成。生产版本保持不变。

### 最终本地门禁（含部署回滚补丁）

命令：`cd modernization/frontend && npm run lint && npm test && npm run typecheck && npm run build && npm audit --audit-level=low`

```text
tests 5; pass 5; fail 0
typecheck: exit 0
vite v8.0.16; 1628 modules transformed; built in 541ms
found 0 vulnerabilities
exit code: 0
```

命令：`cd modernization/backend && php vendor/bin/phpunit --no-coverage && php "$env:TEMP\codex-composer-qa\composer.phar" audit --locked --no-interaction --format=summary`

```text
OK (231 tests, 1050 assertions)
No security vulnerability advisories found.
exit code: 0
```

Composer 工具本身由 `https://getcomposer.org/installer` 与 `https://composer.github.io/installer.sig` 获取，校验安装器 SHA-384 后安装在系统临时目录；没有改动仓库依赖或全局 Composer 配置。`composer validate --no-check-publish` 输出 `./composer.json is valid, but with a few warnings`，唯一警告未声明 license；命令退出 0。

命令：`bash -n modernization/deploy/deploy.sh modernization/deploy/site-backup.sh modernization/deploy/tests/site-backup-test.sh modernization/deploy/tests/deploy-release-safety-test.sh modernization/deploy/tests/deploy-rollback-test.sh modernization/deploy/tests/mock-command.sh && bash modernization/deploy/tests/site-backup-test.sh && bash modernization/deploy/tests/deploy-release-safety-test.sh && bash modernization/deploy/tests/deploy-rollback-test.sh`

```text
PASS database and private uploads are archived and verified without exposing credentials
PASS dump failure preserves existing backups and removes partial files
PASS OSS failure preserves the newly verified local archives and skips retention cleanup
PASS retention removes only expired archives owned by this site
PASS successful deploy backs up database, switches current, and does not reload nginx
PASS failed HTTP login health check restores the previous release
PASS failed pre-switch health check preserves previous shared runtime scripts
PASS missing health credentials fail before switching releases
PASS failed database backup stops before release switch and migration
PASS empty database backup stops before release switch and migration
PASS SQLite database backup is made before migration
PASS relative SQLite path is rejected before migration
Deployment isolation and rollback checks passed.
exit code: 0
```

## 候选发布回滚安全补强（2026-10-18）

隔离代码复查发现：部署脚本在候选依赖安装、发布切换及 HTTP/login 健康检查之前，就将两个运行脚本直接覆盖至本站 `shared/bin`。如候选健康检查失败，`current` 可回滚，但共享 watchdog/备份工具仍停留在候选版本。此为本站发布原子性/回滚一致性缺陷（P1）。

已在隔离候选中将共享脚本安装延后到新 release 的健康检查全部通过之后；先写入唯一临时文件、设置执行权限和属主，再用同目录 `mv` 原子替换。新增测试确保健康检查失败后 current 和旧共享脚本内容均保持不变，且不留临时文件。没有触碰线上文件或服务。

命令：`bash -n modernization/deploy/deploy.sh modernization/deploy/tests/deploy-release-safety-test.sh modernization/deploy/tests/mock-command.sh && bash modernization/deploy/tests/deploy-release-safety-test.sh`

```text
PASS successful deploy backs up database, switches current, and does not reload nginx
PASS failed HTTP login health check restores the previous release
PASS failed pre-switch health check preserves previous shared runtime scripts
PASS missing health credentials fail before switching releases
PASS failed database backup stops before release switch and migration
PASS empty database backup stops before release switch and migration
PASS SQLite database backup is made before migration
PASS relative SQLite path is rejected before migration
exit code: 0
```

该修复尚未提交/推送，故不属于已通过 GitHub CI 的 `ac2b358`，不得部署。需在隔离分支完成全量门禁、推送后等待该新 SHA 的 CI，再部署前重新完成 staging 恢复/业务验收。
