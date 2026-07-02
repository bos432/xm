# 2026-07-02 工作流升级回归测试报告

## 1. 测试结论

- 测试范围：只验证 `modernization` 新 Laravel/Vue 系统，旧 ThinkPHP 未修改。
- 测试方式：后端 Feature tests、前端 lint/build、Playwright Chromium 浏览器回归。
- 浏览器回归方式：使用本地最新前端连接线上真实 API `https://nxm.zlck888.com/api`，走真实验证码和真实登录链路。
- 测试数据：沿用并保留 `E2E-20260630-103223`，本轮截图验证未提交新业务数据。
- 结论：本轮新增的项目申报体验、列表序号/正序、专家评分入口、终审支持信息、导出字段和 API base 兼容性均验证通过。

## 2. 本轮修复验证点

| 模块 | 验证点 | 结果 |
| --- | --- | --- |
| 项目列表 | 增加序号列，默认按创建时间从早到晚 | 通过 |
| 项目申报 | 预算金额按“万元”录入，同时显示系统保存金额（元） | 通过 |
| 保存草稿 | 保存失败时显示中文错误，保存成功有成功提示 | 通过 |
| 审核任务 | 操作列改为“详情 / 审核处理”文字按钮 | 通过 |
| 专家评分 | 专家进入“审核任务 -> 审核处理”后显示多维评分表 | 通过 |
| 终审支持 | 管理员终审可记录是否推荐、支持方式、支持金额、推荐专家 | 通过 |
| 项目导出 | CSV 补充计划类别、归口管理单位、区域、推荐/支持/金额/专家等统计字段 | 通过 |
| 首页 API base | 首页和 favicon 使用统一 `VITE_API_BASE`，本地/预发连接远程 API 可用 | 通过 |

## 3. 自动化验证

### 3.1 后端 Feature tests

执行目录：

```bash
cd modernization/backend
```

执行结果：

| 命令 | 结果 |
| --- | --- |
| `php artisan test --filter ProjectApplicationWorkflowTest` | 16 passed，73 assertions |
| `php artisan test --filter ProjectExportTest` | 6 passed，31 assertions |
| `php artisan test --filter ReviewWorkflowTest` | 4 passed，31 assertions |
| `php artisan test --filter ReviewExportTest` | 12 passed，44 assertions |

### 3.2 前端工程验证

执行目录：

```bash
cd modernization/frontend
```

执行结果：

| 命令 | 结果 |
| --- | --- |
| `npm run lint` | 通过 |
| `npm run build` | 通过 |

### 3.3 浏览器 E2E

运行方式：

- 本地前端：`http://127.0.0.1:5174`
- API：`https://nxm.zlck888.com/api`
- E2E Run ID：`20260702-workflow-upgrade-local`
- 报告目录：`modernization/e2e/reports/runs/20260702-workflow-upgrade-local`

结果：

```text
8 passed (32.1s)
```

覆盖角色：

| 角色 | 账号 | 结果 |
| --- | --- | --- |
| 单位用户 | `e2e_20260630_103223_unit` | 通过 |
| 区县审核 | `e2e_20260630_103223_county` | 通过 |
| 部门审核 | `e2e_20260630_103223_department` | 通过 |
| 专家评审 | `e2e_20260630_103223_expert` | 通过 |
| 普通管理员 | `e2e_20260702_delivery_admin` | 通过 |
| 超级管理员 | `admin` | 通过 |

## 4. 截图证据

操作流程截图目录：

```text
modernization/docs/operation-flow-screenshots-20260702
```

重点截图：

| 文件 | 说明 |
| --- | --- |
| `01-public-home-login.png` | 首页登录入口 |
| `03-unit-project-list.png` | 单位项目列表，含序号列 |
| `03b-unit-project-workbench.png` | 新建项目工作台，预算金额（万元） |
| `05-county-review-tasks.png` | 区县审核任务，文字操作按钮 |
| `06-county-review-dialog.png` | 区县审核处理弹窗 |
| `09-expert-review-tasks.png` | 专家审核任务 |
| `10-expert-score-dialog.png` | 专家多维评分弹窗 |
| `13-super-admin-home-assets.png` | 首页品牌素材管理 |
| `14-super-admin-security.png` | 安全中心 |

## 5. 本轮发现并已修复的问题

| 问题 | 发现方式 | 处理 |
| --- | --- | --- |
| 本地最新前端连接线上 API 时首页内容加载失败 | Playwright 首轮回归失败 | `PublicHomeView` 和 `favicon.js` 改为使用统一 `api()`，遵守 `VITE_API_BASE` |
| 项目列表仍按最新创建倒序 | 代码审查 + 用户反馈 | 后端 `/api/projects` 和导出改为创建时间正序 |
| 专家评分入口依赖图标理解 | 浏览器截图和用户反馈 | 审核任务操作按钮改为“详情 / 审核处理” |
| 预算录入单位不清楚 | 用户反馈 + 表单检查 | 前台改为“预算金额（万元）”，后端继续保存元 |

## 6. 保留事项

- `E2E-` 测试账号和测试数据继续保留，不物理删除。
- 正式交付后请修改 `admin` 密码。
- 本轮代码完成后仍需推送 GitHub 并在宝塔执行部署命令，线上部署后建议再跑一次 `E2E_BASE_URL=https://nxm.zlck888.com` 的正式线上回归。

