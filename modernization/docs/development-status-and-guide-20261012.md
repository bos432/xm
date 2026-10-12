# 科技项目管理系统开发现状与开发文档

> 文档核对日期：2026-10-12
>
> 本次评估的实现代码基线：`4401767`（2026-10-13，生产部署后最终文档修订）
> 范围：仅 `modernization` 下的 Laravel/Vue 新系统。旧 ThinkPHP 系统作为历史系统，不在本项目开发范围内。

## 1. 当前结论

系统已从早期骨架发展为可运行的项目申报与管理系统，覆盖单位申报、分级审核、专家评分、管理员终审、验收、项目全周期、运营配置、角色权限、安全管理和部署健康检查等主要能力。当前代码仓库位于 `main` 分支，检查时与 `origin/main` 同步。

本机已重新执行前端 lint、前端生产构建和 Laravel 后端 Feature 测试，结果均通过。2026-10-13 已通过宝塔终端完成生产发布，首页、验证码、公开首页 API、真实健康账号登录/退出和公开首页浏览器冒烟均通过；六角色业务冒烟以 2026-07-02 的线上回归报告为依据，健康检查兼容修复已在本次发布中再次验证。

## 2. 能力状态一览

| 能力域 | 当前代码状态 | 主要入口 |
| --- | --- | --- |
| 登录与账号安全 | 验证码、登录限流、密码重置/更新、用户启停、登录健康检查 | `backend/app/Http/Controllers/AuthController.php`、`SecurityController.php` |
| 项目申报 | 草稿、项目字段与字典选项、附件、提交/撤回、权限范围过滤 | `ProjectsView.vue`、`ProjectController.php` |
| 申报批次 | 批次创建、开放/关闭、批次材料配置、E2E 筛选与批次归档 | `ApplicationBatchesView.vue`、`ApplicationBatchController.php` |
| 审核与评分 | 区县/部门/专家/管理员阶段审核、专家多维评分、终审支持信息、派单规则 | `ReviewTasksView.vue`、`ReviewController.php`、`ReviewDispatchRuleController.php` |
| 验收与延期 | 验收申请、材料上传、审核、延期申请与处理 | `AcceptanceView.vue`、`AcceptanceController.php` |
| 项目全周期 | 合同任务书、实施进展、整改闭环、专家认证及其权限校验 | `LifecycleView.vue`、`ProjectLifecycleController.php` |
| 组织管理 | 单位和用户管理、导出、账号角色分配 | `UnitsView.vue`、`UsersView.vue`、`RbacController.php` |
| 系统运营 | 首页与品牌素材、富文本、系统文案、邮件模板/发送日志、站内消息 | `PublicHomeManageView.vue`、`SystemTextsView.vue`、`MailCenterView.vue`、`MessagesView.vue` |
| 系统治理 | 数据字典、分组配置、安全中心、操作日志、迁移准备视图 | `DictionaryItemsView.vue`、`SettingsView.vue`、`SecurityCenterView.vue` |
| 部署与健康检查 | Git 发布目录、数据库迁移、前端构建、首页/API/真实登录检查 | `deploy/deploy.sh`、`backend/app/Console/Commands/HealthCheckLogin.php` |

### 角色

内置角色为：申报单位 `unit`、区县审核 `county`、部门审核 `department`、专家评审 `expert`、业务管理员 `admin`、超级管理员 `super_admin`。菜单显示和 API 授权由后端角色/权限共同约束；前端隐藏菜单不是安全边界，服务端接口仍会做权限校验。系统配置、风险策略、角色权限等敏感操作受超管权限约束。

### 当前主流程

```text
公开首页/注册
  -> 单位完善资料、选择开放批次
  -> 创建项目草稿、填写申报内容并上传附件
  -> 单位提交
  -> 区县审核 -> 部门审核 -> 专家评审 -> 管理员终审
  -> 项目立项/实施
  -> 合同任务书、实施进展、整改闭环等全周期记录
  -> 单位发起验收并提交材料
  -> 验收审核流转 -> 管理员关闭/完成
```

具体项目状态、批次规则、阶段处理人和权限以线上配置及项目记录为准；部署前后应使用测试账号实际验收，不能只依赖此示意图。

## 3. 技术架构与代码地图

| 路径 | 内容 |
| --- | --- |
| `modernization/backend` | Laravel 11、PHP 8.3 API、权限、业务逻辑、迁移、Seeder、Feature tests |
| `modernization/frontend` | Vue 3、Vue Router、Pinia、Element Plus、Vite 前端 |
| `modernization/e2e` | Playwright Chromium 冒烟脚本与运行配置 |
| `modernization/deploy` | 生产发布脚本及部署说明 |
| `modernization/docs` | 测试、运维、迁移、交付和操作文档 |

前端路由页面采用动态导入；`frontend/src/api.js` 封装 API 请求，`store.js` 保存会话，`router.js` 执行登录态和路由权限检查，`App.vue` 组织模块导航。主要页面位于 `frontend/src/views`，共用富文本编辑器位于 `frontend/src/components/RichTextEditor.vue`。

后端入口为 `backend/routes/api.php`。认证后 API 使用 Laravel Sanctum bearer token；业务逻辑主要位于 `backend/app/Http/Controllers`，共享角色/权限、风控、富文本清洗、评分和派单逻辑位于 `backend/app/Support`。数据库结构通过 `backend/database/migrations` 演进，初始化数据位于 `backend/database/seeders`。

主要数据实体包括 `users`、`units`、`projects`、`project_files`、`project_reviews`、`application_batches`、`acceptance_applications`、`acceptance_reviews`、`acceptance_extensions`、`project_task_books`、`project_progress_records`、`project_rectifications`、`expert_certifications`、`roles`、`permissions`、`messages`、`operation_logs`、`system_settings`、`dictionary_items`、`review_dispatch_rules`、邮件和安全事件相关表。

## 4. API 与主要接口域

API 基础路径为 `/api`。公开 API 包括登录验证码、登录/注册/找回密码、公开首页配置和素材、开放申报批次及公开系统文案。认证 API 覆盖：

- `/auth/me`、`/auth/logout`、个人资料与密码。
- `/projects`、项目提交/撤回/延期/关闭、项目附件下载及导出。
- `/application-batches`、开放/关闭/归档及测试批次归档。
- `/reviews/tasks`、`/reviews/results`、项目评审提交及派单规则。
- `/acceptance`、验收申请/提交/审核/附件/延期。
- `/lifecycle/*`：任务书、实施进展、整改与专家认证。
- `/settings`、`/dictionary-items`、`/roles`、`/permissions`、`/security/*`、`/public-home`、`/mail/*`、`/operation-logs`。

请求字段、状态码和角色范围请以 `modernization/backend/routes/api.php`、对应 Controller 和 Feature tests 为准。本指南不是逐字段 OpenAPI 规格。

## 5. 本地开发

### 环境要求

- PHP `^8.3`，Composer；Laravel 11 所需 PHP 扩展。
- Node.js 满足当前 Vite 8 工具链要求，npm。
- 本地开发优先使用 `.env.example` 和 SQLite/本机数据库；不要复制生产 `.env`、生产数据库或真实密码到仓库。

### 安装与启动

在仓库根目录执行：

```powershell
cd modernization/backend
composer install
Copy-Item .env.example .env
php artisan key:generate
php artisan migrate --seed
php artisan serve
```

另开终端启动前端：

```powershell
cd modernization/frontend
npm ci
npm run dev
```

如果本机使用前后端分离的远端 API，请按 `frontend/vite.config.js` 与 `.env` 中实际 API base 配置；不要将生产密钥写进前端环境变量。

## 6. 自动化检查与测试

### 前端

```powershell
cd modernization/frontend
npm run lint
npm run build
```

### 后端

```powershell
cd modernization/backend
php artisan test
```

### 浏览器 E2E 冒烟

在 `modernization/frontend` 设置测试站点、项目样本及各角色测试账号环境变量后执行：

```powershell
npm run e2e
```

账号密码通过环境变量读取，禁止把凭据直接写入脚本或提交到 Git。E2E 会访问真实站点并可能读取业务数据；需要先确认目标环境和样本账号。当前 Playwright suite 主要覆盖首页、六角色登录/页面访问、项目筛选、全周期、验收历史、首页素材/安全中心及专家认证权限边界；它属于冒烟回归，不会自动替代每个阶段的人工业务审批，也不会因为页面打开成功就证明完整事务链路成功。报告按 run ID 写入 `modernization/e2e/reports/runs/<run-id>`，测试数据按现有约定保留，不执行物理删除。

### 本次本机验证记录

| 检查 | 结果 | 证据时间 |
| --- | --- | --- |
| `npm run lint` | 通过 | 2026-10-12，本机 |
| `npm run build` | 通过，生成路由分块 | 2026-10-12，本机 |
| `php artisan test` | 186 passed，825 assertions | 2026-10-13，本机 |
| `npm ci --include=optional --no-audit --no-fund` | 通过 | 2026-10-13，本机 |
| 生产部署健康检查 | 通过：首页、验证码、公开首页、真实登录/退出 | 2026-10-13，宝塔终端 |
| 生产公开首页浏览器冒烟 | 通过，首页内容和登录入口正常渲染 | 2026-10-13，浏览器 |
| 生产浏览器六角色 E2E | 通过，报告已保留 | 报告日期 2026-07-02 |

## 7. 部署和运行

生产部署采用 release 目录与 `current` 软链，环境文件和持久化存储位于 `shared`。完整命令、变量、健康检查和回滚方式见[部署指南](deployment-guide-20260702-delivery.md)及[部署脚本说明](../deploy/README.md)。常规发布应先推送 Git，再在服务器运行已审核的 `deploy.sh`；部署后依次检查首页、验证码 API、公开首页 API、真实登录健康检查和角色页面。

生产至少需要保护好 `shared/.env`、数据库备份、Laravel `storage`、邮件凭据和健康检查凭据。对外提供交付文档时，不要把默认账号密码作为长期凭据；交付后修改密码并核对健康检查脚本配置。

## 8. 迁移边界、待办与风险

1. **旧数据正式迁移尚未完成。** 旧系统映射和迁移报告/预览工具已存在，但 `LegacyRecordImportService::import()` 当前返回 `not_implemented`。生产数据导入仍需独立设计、数据校验、备份及演练，不能将干跑报告视作完成迁移。
2. **六角色事务回归仍应按业务周期复跑。** 当前线上已完成健康检查和公开页面验收，六角色浏览器回归报告已保留；涉及真实审批、评分和验收的事务数据仍应按每次正式业务周期使用新的 `E2E-YYYYMMDD-HHmmss` 数据复跑，并保留数据。
3. **专家评分和验收事务建议持续做线上演练。** 自动化后端测试覆盖权限、评分、验收和延期规则，浏览器冒烟覆盖主要页面；正式切换业务批次前，建议用标记为测试的数据完成一次区县、部门、专家、终审、验收全链路演练。
4. **测试数据与统计口径需持续维护。** 系统提供按 `E2E-`/metadata 筛选和测试批次归档机制；新测试数据仍应统一命名、打标并避免进入正式业务统计。
5. **前端包体仍有治理空间。** 构建已使用路由懒加载，但 Element Plus 相关 bundle 仍是主要体积来源；应结合真实访问与构建报告评估按需引入和进一步拆分。
6. **部署后的安全交付检查。** 修改初始管理密码、健康检查密码及 SMTP 密钥；确认限流策略、白名单、HTTPS、备份恢复与队列 worker 监控。

## 9. 关联文档

- [交付版部署指南](deployment-guide-20260702-delivery.md)
- [测试与验证说明](testing.md)
- [2026-07-02 线上最终回归报告](e2e-test-report-20260702-final-visible.md)
- [2026-07-02 交付版全流程回归报告](e2e-test-report-20260702-delivery.md)
- [操作流程截图版手册](operation-guide-with-screenshots-20260702.md)
- [旧系统数据迁移指南](legacy-migration-guide.md)
- [旧系统表映射](legacy-table-map.md)
