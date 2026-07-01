# 2026-07-02 测试数据治理开发验证报告

## 1. 测试结论

- 本轮继续只改 `modernization` 新 Laravel/Vue 系统，旧 ThinkPHP 未改动。
- 已完成测试数据治理增强：项目、验收、申报批次支持按 E2E 测试数据筛选；超管可批量归档 E2E 申报批次。
- 已完成 E2E 报告保留增强：每次运行生成独立目录 `modernization/e2e/reports/runs/<run-id>`。
- 本地后端用例、前端 lint/build、线上浏览器主流程回归均通过。
- 线上 E2E 使用保留数据 `E2E-20260630-103223`，未删除任何测试数据。

## 2. 本轮开发项

| 模块 | 内容 | 状态 |
| --- | --- | --- |
| 申报批次 | `GET /api/application-batches?e2e=1/0` 支持只看/排除测试批次 | 完成 |
| 申报批次 | `POST /api/application-batches/archive-e2e` 支持超管批量归档测试批次 | 完成 |
| 项目管理 | `GET /api/projects?e2e=1/0` 支持按项目、批次 metadata/name/code 识别测试数据 | 完成 |
| 验收管理 | `GET /api/acceptance?e2e=1/0` 支持按验收、项目、批次识别测试数据 | 完成 |
| 前端 | 项目、验收、批次页面增加“测试数据”筛选控件 | 完成 |
| 前端 | 超管批次页面增加“归档测试批次”按钮 | 完成 |
| E2E | 报告按运行批次输出到 `reports/runs/<run-id>` | 完成 |

## 3. 本地后端验证

执行命令：

```bash
php -l modernization/backend/app/Http/Controllers/ApplicationBatchController.php
php -l modernization/backend/app/Http/Controllers/ProjectController.php
php -l modernization/backend/app/Http/Controllers/AcceptanceController.php
php -l modernization/backend/routes/api.php
php -l modernization/backend/tests/Feature/ApplicationBatchManagementTest.php
php -l modernization/backend/tests/Feature/ProjectAcceptanceWorkflowTest.php

cd modernization/backend
php -d extension=zip artisan test --filter ApplicationBatchManagementTest
php -d extension=zip artisan test --filter ProjectAcceptanceWorkflowTest
```

结果：

```text
No syntax errors detected
ApplicationBatchManagementTest: 2 warnings, 13 assertions
ProjectAcceptanceWorkflowTest: 12 warnings, 67 assertions
```

说明：warning 为 Windows 中文路径下 Laravel 测试环境读取文件的已知提示；本轮相关断言全部通过。

## 4. 前端验证

执行命令：

```bash
cd modernization/frontend
npm run lint
npm run build
npm run e2e -- --list
```

结果：

- `npm run lint` 通过。
- `npm run build` 通过。
- `npm run e2e -- --list` 成功列出 8 个用例。

已知非阻塞提示：

- 第三方 `@vueuse/core` Rolldown `INVALID_ANNOTATION` warning。
- 主 chunk 超过 500KB warning。

## 5. 线上浏览器主流程回归

执行环境：

- 目标站点：`https://nxm.zlck888.com`
- 浏览器方式：Playwright Chromium 自动化，走真实页面、真实验证码、真实登录接口。
- 测试数据：`E2E-20260630-103223`
- 项目 ID：`5`

执行命令：

```bash
cd modernization/frontend
npm run e2e
```

结果：

```text
8 passed
```

覆盖范围：

1. 公开首页可见登录入口，且不再出现重复旧“单位注册”入口。
2. 单位用户登录后可进入项目、全周期、验收历史。
3. 区县角色登录后可进入项目、全周期、验收历史。
4. 部门角色登录后可进入项目、全周期、验收历史。
5. 专家角色登录后可进入项目、全周期、验收历史。
6. 管理员登录后可进入项目、全周期、验收历史。
7. 超级管理员登录后可进入项目、全周期、验收历史。
8. 超级管理员可检查首页素材状态和安全中心。

本次 E2E 报告目录：

```text
modernization/e2e/reports/runs/20260702-011322
```

## 6. 数据保留说明

- 继续保留 `E2E-20260630-103223` 主回归样本。
- 本轮新增的是筛选和归档能力，不物理删除项目、验收、用户或批次数据。
- “归档测试批次”只会把测试申报批次状态改为 `archived`，不会删除历史项目、验收或全周期记录。

## 7. 验收结论

本轮开发项已完成并通过本地与线上主流程验证。部署后建议再用超管进入项目、验收、批次页面，手工确认“测试数据”筛选控件和“归档测试批次”按钮显示符合权限预期。
