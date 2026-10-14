# 新系统 QA 验收报告（2026-10-14）

## 范围

本报告基于隔离工作区 `codex/oss-backup-runtime-safety` 的实际测试，以及对 `https://nxm.zlck888.com` 的只读探测。本轮未修改应用源码、依赖版本、生产数据库、OSS 对象或 SMTP 配置；没有读取或记录生产凭据/密钥。

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
| A-07 | OSS 上传失败时 fail-closed 并保留本地归档 | 已覆盖测试 | `OssBackupCommandTest` 和隔离 shell 模拟；真实 OSS 未测 |
| A-08 | 部署健康检查失败回滚本站 release 且不 reload Nginx | 已覆盖测试 | `deploy-release-safety-test.sh`、`deploy-rollback-test.sh` 隔离模拟；生产回滚未触发 |
| A-09 | 生产 HTTPS 证书匹配本站域名 | 已覆盖测试 | 公网 SNI 只读核验 `CN=nxm.zlck888.com`，有效期至 `2027-01-12 10:59:59 UTC`；首页/登录/验证码/公开首页 HTTP 200 |
| A-10 | OSS 异地备份及隔离环境恢复 | 仅实现未测 | 生产无 `backup.oss_*` 配置记录，开关关闭；未上传或恢复 |
| A-11 | SMTP 实际投递至批准的测试邮箱 | 仅实现未测 | SMTP username/password 缺失；未发送测试邮件 |
| A-12 | 六角色浏览器完整流程：申报至终审/验收 | 未实现验收证据 | E2E 清单共 10 项，登录/页面与部分权限探测，不执行完整申报、逐级审核和验收链路；缺隔离账号 |
| A-13 | 测试覆盖率数字及未覆盖高风险文件排序 | 未实现验收证据 | 覆盖率驱动不可用，未生成覆盖率或逐文件覆盖数据 |

## 缺陷表

| ID | 严重级 | 模块 | 复现命令/证据 | 实际 vs 预期 | 修复建议 |
| --- | --- | --- | --- | --- | --- |
| QA-01 | P0 阻断 | 异地灾备 | 超管“系统配置 -> 备份与 OSS”；脱敏运行时检查 | OSS 关闭且生产 `backup.oss_*` 记录缺失，尚无站外副本/恢复证据 | 在后台配置专用最小权限 RAM 与目标 Bucket；获准后上传一份备份、核对对象大小，并恢复到隔离 MySQL/存储 |
| QA-02 | P0 阻断 | 邮件通知 | 脱敏 Laravel 运行时检查：SMTP username/password 为 missing | 系统不能证明邮件经 SMTP 发出；预期批准测试收件箱收到邮件 | 配置 SMTP 与专用收件箱，发一封测试邮件并核对收件与队列/日志结果 |
| QA-03 | P1 严重 | 证书密钥管理 | 宝塔本站 SSL 证书详情页显示明文私钥（内容未复制到报告） | 可查看该页的面板用户能看到私钥；预期最小化密钥暴露 | 将旧私钥视为已泄露，撤销/换钥；核查面板访问记录并咨询如何禁用明文回显。不得复用旧密钥 |
| QA-04 | P1 严重 | 浏览器 E2E | `cd modernization/frontend && npm run e2e -- --list`；检查 `modernization/e2e/tests/smoke.spec.js` | 共 10 个用例，角色用例检查登录、页面/权限；不覆盖“提交 -> 区县 -> 部门 -> 多专家评分 -> 终审 -> 验收关闭”全链 | 提供隔离数据库/存储及六角色专用凭据，扩展并实际运行完整 E2E，保留 E2E 数据 |
| QA-05 | P2 一般 | 测试基础设施 | `cd modernization/backend && php artisan test --compact --coverage` | 退出码 1：`Code coverage driver not available. Did you install Xdebug or PCOV?`，覆盖率未知 | 仅在 CI/测试镜像启用 Xdebug 或 PCOV，发布覆盖率报告；不在生产安装 |

## 已执行命令与完整关键输出

### 后端全量测试

命令：`cd modernization/backend && php artisan test --compact`

```text
Tests:    199 passed (899 assertions)
Duration: 5.42s
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
- 未对生产指定 Bucket 执行真实 OSS PUT/HEAD 或 GET/恢复；配置为空，故没有进行任何生产上传。
- 未向批准的测试邮箱发送 SMTP 邮件；没有 SMTP 账号凭据及测试收件确认。
- 未能给出覆盖率百分比或基于实际覆盖数据的高风险未覆盖文件 TOP5；PHP 覆盖率驱动缺失。不能把文件重要性排序伪装成覆盖率结果。
- 未执行生产压力/并发或整机重启恢复测试；没有隔离生产等价环境/维护窗口，不以线上业务承担此类破坏性验证。
- 未验证宝塔证书部署器的文件级影响范围，也未完成旧私钥撤销；线上 TLS 域名和有效期已做公网只读确认。

## 高风险文件候选（静态风险排序，不代表覆盖率排名）

由于覆盖率工具不可用，以下仅是按安全/资金/流程影响挑选的后续优先覆盖候选，不声称它们未覆盖或覆盖比例为零：

1. `modernization/backend/app/Http/Controllers/ReviewController.php`：审核授权、专家评分、终审支持和状态迁移。
2. `modernization/backend/app/Http/Controllers/ProjectController.php`：项目提交、详情访问控制和材料处理。
3. `modernization/backend/app/Http/Controllers/AcceptanceController.php`：验收、延期及完成状态。
4. `modernization/backend/app/Console/Commands/UploadOssBackups.php`：签名上传、远端校验和凭据错误处理。
5. `modernization/deploy/site-backup.sh`：生产备份、留存和故障路径。

## 当前运营判断

源码测试与隔离部署/备份模拟通过；公网 HTTPS 入口当前正常。但这不足以证明系统已达到完整运营状态：OSS 异地恢复、SMTP 实际投递、隔离六角色 E2E、旧私钥轮换仍未闭环。生产开放前必须完成并留存这些证据。
