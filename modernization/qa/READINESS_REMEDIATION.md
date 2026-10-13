# 运营就绪整改记录

基线：`origin/main` `84da667`。本次只在隔离工作树实施；生产服务器、数据库、账号、配置与业务数据均未写入。

## 已落实

- 后端 Feature 测试使用显式 testing 环境变量与 SQLite 内存库运行：`vendor/bin/phpunit --display-warnings --display-deprecations --display-notices`，结果 `OK (186 tests, 825 assertions)`，退出码 0。
- 前端把项目时间轴活动序号逻辑提取为纯 JS 工具函数，并新增 3 个 Node 内置测试；未增加 npm 依赖。新增 `npm test`、工具模块语法/JSDoc 检查 `npm run typecheck`，并将测试目录纳入 lint。
- GitHub Actions 已增加前端测试/typecheck、PHP PCOV 覆盖率文本输出，以及在线 E2E 所需六角色账号密钥的 fail-fast 检查。Workflow 语法和实际 Ubuntu runner 结果仍需远端 CI 验证。
- 只读核查生产站点：`current` 当时指向 release `20261013074937`；根分区使用率 53%、`/www` 66%；10 个迁移均为 Ran；首页、验证码 API、公开首页 API 均返回 HTTP 200。未读取密钥值或数据库业务内容。

## 本地验证记录

- 前端：`npm test` 3/3；`npm run typecheck`、`npm run lint`、`npm run build` 退出码均为 0；Playwright 列出 9 项 E2E 场景。
- 后端：186 tests、825 assertions 全通过。PHPUnit 缓存与前端 coverage HTML 是本地测试生成物，不纳入版本控制。
- Pint 全库试跑结果 `138 files, 138 style issues`。这是现存格式问题，本轮未执行全库自动格式化；当前 workflow 不运行 Pint，因此不冒充运营阻断门禁。
- 前端仅有 3 个纯逻辑测试，没有前端 coverage provider；没有可报告的前端覆盖率数字。UI 角色权限和完整流程仍需端到端回归。

## 尚未验证/完成

- 远端 GitHub Actions 尚未运行，PCOV 实际覆盖率和完整 Ubuntu CI 结果未知；GitHub CLI 未认证，不能读取运行记录或检查在线 secrets 是否存在。
- 六角色 E2E 未运行：不能确认专用账号凭据已配置；也未执行生产审批、评分、验收等业务写操作。
- 生产未部署本分支；本地 WSL/Bash 部署模拟环境启动失败。因此，不能称本次整改已经上线或系统已通过运营验收。
- 生产 PHP CLI 曾输出 `Module "mbstring" is already loaded` 警告。本轮未改 PHP 全局配置或重启服务，需另行查明重复扩展配置来源。
- CAPTCHA 至 HTTP 服务的用户端网络链路、邮件 SMTP 实际投递、备份恢复演练、并发/压力测试、完整权限矩阵和真实六角色完整业务流均未验证。

## 发布安全边界

只有候选提交通过远端 CI、生产备份/健康账号确认后，才发布到 `nxm.zlck888.com`。使用仓库 `modernization/deploy/deploy.sh`，默认只切换该站点的 `current` 符号链接；不重启 Nginx、PHP-FPM、整机或其他站点。当前数据库迁移均已应用，除非逐项审阅发现新迁移，否则发布必须使用 `RUN_MIGRATIONS=0 RUN_SEED=0`。部署失败只允许回切该站点旧 release；不对生产数据库执行自动回滚。
