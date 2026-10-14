# OSS 备份运行安全整改与核验（2026-10-14）

## 发布范围与真实状态

本轮修改仅限 modernization 的 OSS 上传命令及专项测试，不修改生产配置、数据库、共享服务或其他站点。不触发生产备份、对象上传或本地保留清理。

候选分支：`codex/oss-backup-runtime-safety`，基线 `60d4088`（同步后的 origin/main）。实际命令类为 `UploadOssBackups`，配置键为 `backup.oss_enabled`、`backup.oss_endpoint`、`backup.oss_bucket`、`backup.oss_prefix`、`backup.oss_access_key_id`、`backup.oss_access_key_secret`。

原始工作区 main 仍在 `5b6194d`，与远端分叉，并有未提交的 `BackupSiteToOss` 及 `backup.oss.*` 配置实现。它不是本轮发布源，不能与当前实现并行注册同名 `site:backup:oss` 命令。没有删除、重置或发布原始工作区文件。

首次在原工作区取得的 175 passed / 815 assertions 和前端构建结果只适用于旧工作区，不作为本候选分支的验收证据。后续测试已在上述隔离工作区重新执行。

## 缺陷与修复

| ID | 严重级 | 模块 | 复现命令 | 实际 vs 预期 | 修复 |
| --- | --- | --- | --- | --- | --- |
| OSS-01 | P1 | 上传 HTTP 客户端 | `php artisan test --compact --filter=OssBackupCommandTest` | 默认允许重定向；预期已签名 PUT/HEAD 只访问配置目标，不跟随跳转 | 设置 `withoutRedirecting()`，在实际请求选项上断言 `allow_redirects=false` |
| OSS-02 | P1 | 归档预检 | 同上 | 空附件归档可返回 Uploaded and verified；预期任一空归档都在发送任何请求前失败 | 两份归档均进行长度预检；空归档返回非零 |
| RELEASE-01 | P0 发布阻断 | 发布源 | `git status --short --branch`、`git log --oneline HEAD..origin/main` | 原始 main 与远端分叉且存在另一套实现；预期从当前发布基线整合 | 使用已有隔离工作区，在同步后的 origin/main 创建候选分支；不强推原始 main |

## 测试命令与输出

工作目录为隔离工作区 `modernization/backend`，环境来自 phpunit.xml（测试 SQLite，不是生产 MySQL）。

### 测试先失败

添加空归档回归测试后：

```text
php artisan test --compact --filter=OssBackupCommandTest
FAILED Tests\Feature\OssBackupCommandTest > empty archive is rejected before either archive is uploaded
Uploaded and verified 2 OSS backup objects.
Failed asserting that 0 is identical to 1.
Tests: 1 failed, 7 passed (35 assertions)
Duration: 0.68s
```

### 修复后的专项测试

```text
php artisan test --compact --filter=OssBackupCommandTest
........
Tests: 8 passed (36 assertions)
Duration: 0.63s
```

覆盖：OSS 未启用、启用后两份上传/HEAD、PUT 失败保留本地文件、非阿里云 endpoint 拒绝、前缀穿越拒绝、远端长度不符、空归档、缺失归档。成功用例同时断言 Authorization 完整签名、HEAD Content-Type、文件流来源和禁止重定向。网络由 Laravel HTTP fake 替代，不能证明阿里云实际接受请求。

### 全量后端测试

```text
php artisan test --compact
....................................................................................................................
...................................................................................
Tests: 199 passed (899 assertions)
Duration: 5.41s
```

### 前端

工作目录为隔离工作区 `modernization/frontend`。

```text
npm run lint
> project-application-modern-frontend@0.1.0 lint
> eslint src tests --ext .js,.vue
exit code: 0

npm run test
> node --test tests/timeline.test.js tests/settings-navigation.test.js
✔ system settings navigation exposes the OSS backup group
✔ uses the explicitly current stage
✔ chooses the stage after the last completed stage when none is current
✔ returns zero for missing, malformed, and pending-only timelines
tests 4
pass 4
fail 0
skipped 0
exit code: 0

npm run typecheck
> node scripts/typecheck-utilities.mjs
exit code: 0

npm run build
> vite build
vite v8.0.16 building client environment for production...
transforming...✓ 1628 modules transformed.
rendering chunks...
computing gzip size...
✓ built in 590ms
exit code: 0
```

typecheck 仅验证既有脚本所覆盖的 JS 工具代码，不代表所有 Vue 页面有静态类型覆盖。构建并不等于浏览器全流程验收。

## 签名参考

核对官方文档：[Authorization Header V1 签名](https://help.aliyun.com/zh/oss/developer-reference/include-signatures-in-the-authorization-header)。实际候选实现使用 Date-only 签名，测试构造完整 method、Content-MD5、Content-Type、Date、CanonicalizedResource。没有根据先前猜测修改签名算法。

## 部署与验收步骤

### Git 发布证据

修复提交 `bacb1db` 已推送至候选分支，再以非强制方式快进远端 main：

```text
git -c http.sslBackend=schannel -c http.lowSpeedLimit=100 -c http.lowSpeedTime=20 push origin HEAD:main
To https://github.com/bos432/xm.git
   60d4088..bacb1db  HEAD -> main
```

这是代码发布，不是生产部署。尝试读取该提交的 CI 状态：

```text
gh run list --repo bos432/xm --branch main --limit 3 --json databaseId,headSha,status,conclusion,url,workflowName
To get started with GitHub CLI, please run: gh auth login
Alternatively, populate the GH_TOKEN environment variable with a GitHub API authentication token.
exit code: 1
```

当前 GitHub CLI 没有认证，未能验证 Actions 状态。不读取浏览器 token，也不自动登录或创建密钥。不能把本地测试通过写成 CI 已通过。

1. 合并候选修复到 main，核对 main 新提交已包含这两项修改，才可部署。不可从原始脏工作区直接 push main，也不可强推。
2. 使用本站既有 deploy.sh，显式 `RUN_SEED=0 RUN_MIGRATIONS=0`；无需迁移。不重启服务器、Nginx、MySQL，不修改其他站点配置。
3. 发布后只读核对 release 的 source SHA、Artisan 命令注册、公开首页/验证码，以及超管“备份与 OSS”入口。
4. OSS 未配置时，维持关闭。由管理员在后台填写专用 Bucket、对应地域 HTTPS Endpoint 和最小权限 RAM 凭据；不要在聊天、命令行或报告里传递密钥。
5. 在实际目标已配置且获准上传后，再执行本站备份，记录退出码、对象 HEAD 大小并从 OSS 恢复到隔离环境。严禁在生产数据库做恢复。
6. 以实际调度脚本和任务日志为准，确认定时任务失败时不会虚报 Successful；失败保留本地归档。

## 未完成与不能宣称的结论

- 本轮没有生产部署或真实对象上传。不能宣称 OSS 已可运营。
- 没有真实 OSS GET/恢复演练，也没有 MySQL 5.7.40 同版本恢复。
- 没有 SMTP 参数和批准收件邮箱，因此不能证明真实邮件投递；用户要求 SMTP 以后在后台填写，需保留这一验收边界。
- 没有六角色生产浏览器业务流转验收，本轮未改变已有 E2E 数据。
- 本站证书私钥曾意外出现在面板快照，应仅针对本站换钥/重签；本轮未处理，不能记为已修复。
- 本轮未运行 coverage，覆盖率数值未知，不能用断言数替代覆盖率。高风险仍包括 OSS 网络/重定向、定时保留、实际恢复、专家组流转和权限隔离。

因此本轮只证明候选代码的上述测试通过，不证明全系统达到上线运营终态。
