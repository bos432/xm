# 2026-07-02 线上主流程浏览器回归测试报告

## 1. 测试结论

- 测试时间：2026-07-02 00:16-00:18（Asia/Shanghai）
- 测试环境：https://nxm.zlck888.com
- 测试方式：Playwright Chromium 浏览器自动化回归
- 测试结果：8/8 通过
- 测试数据：继续保留 `E2E-20260630-103223`、`E2E-20260701-094040` 等线上测试数据，未做物理删除

本轮主流程浏览器验证通过：首页、验证码登录、六类角色菜单、Dashboard、项目筛选、全周期回显、验收历史、首页素材管理、安全中心均可正常访问。

## 2. 测试证据

- JSON 结果：`modernization/e2e/reports/results.json`
- HTML 报告：`modernization/e2e/reports/html/index.html`
- 截图目录：`test-results/`
- 回归命令：

```bash
cd modernization/frontend
npm run e2e
```

本次执行输出：

```text
Running 8 tests using 1 worker
8 passed (58.0s)
```

## 3. 健康检查

| 检查项 | 结果 | 说明 |
| --- | --- | --- |
| 首页 `/` | 通过 | HTTP 200 |
| 验证码 `/api/auth/captcha` | 通过 | 返回 `captcha_id` 和算术验证码 |
| 首页内容 `/api/public/homepage` | 通过 | 返回 logo、banner、导航、公告、下载、批次等数据 |
| favicon 配置 | 通过但待运营上传 | 当前 `brand.favicon_url=null`，系统使用 `/favicon.ico` 兜底 |

## 4. 测试账号

密码未写入文档；执行时通过环境变量传入。

| 角色 | 账号 | 验证内容 |
| --- | --- | --- |
| 单位用户 | `e2e_20260630_103223_unit` | 登录、Dashboard、项目筛选、全周期、验收历史 |
| 区县审核 | `e2e_20260630_103223_county` | 登录、菜单、项目筛选、全周期、验收已处理 |
| 部门审核 | `e2e_20260630_103223_department` | 登录、菜单、项目筛选、全周期、验收已处理 |
| 专家评审 | `e2e_20260630_103223_expert` | 登录、菜单、项目筛选、全周期、验收已处理 |
| 管理员 | `e2e_20260630_103223_admin` | 登录、管理菜单、项目筛选、全周期、验收历史 |
| 超级管理员 | `admin` | 登录、首页管理品牌素材、安全中心 |

## 5. 浏览器用例明细

| 序号 | 用例 | 结果 |
| --- | --- | --- |
| 1 | 首页展示公共登录入口，且不再出现重复的旧“单位注册”入口 | 通过 |
| 2 | 单位用户登录并打开 Dashboard、项目筛选、全周期、验收历史 | 通过 |
| 3 | 区县审核登录并打开 Dashboard、项目筛选、全周期、验收历史 | 通过 |
| 4 | 部门审核登录并打开 Dashboard、项目筛选、全周期、验收历史 | 通过 |
| 5 | 专家评审登录并打开 Dashboard、项目筛选、全周期、验收历史 | 通过 |
| 6 | 管理员登录并打开 Dashboard、项目筛选、全周期、验收历史 | 通过 |
| 7 | 超级管理员登录并打开 Dashboard、项目筛选、全周期、验收历史 | 通过 |
| 8 | 超级管理员打开首页管理品牌素材和安全中心 | 通过 |

## 6. 关键页面验证

| 页面 | 验证结果 |
| --- | --- |
| `/` | 首页加载正常，登录框可用，只保留“新单位注册” |
| `/projects?keyword=E2E-20260630-103223` | 筛选生效，能看到匹配项目 |
| `/lifecycle?project_id=5` | 项目选择回显正常，全周期记录可见 |
| `/acceptance?scope=reviewed&keyword=E2E-20260630-103223` | 已处理/历史验收视图可打开 |
| `/public-home` | 品牌素材区可见 Logo、Favicon、Banner 管理项 |
| `/security` | 安全中心可访问，登录风控状态可查看 |

## 7. 截图清单

主要截图位于 `test-results/`：

- `public-home.png`
- `unit-dashboard.png`
- `unit-projects-filter.png`
- `unit-lifecycle.png`
- `unit-acceptance-reviewed.png`
- `county-dashboard.png`
- `department-dashboard.png`
- `expert-dashboard.png`
- `admin-dashboard.png`
- `super_admin-dashboard.png`
- `super-admin-home-assets.png`
- `super-admin-security.png`

## 8. 发现与说明

1. 本轮没有发现阻塞主流程的问题。
2. 正式 favicon 尚未上传，当前公开接口返回 `brand.favicon_url=null`，属于运营配置项，不影响系统访问。
3. 首页当前开放批次中仍包含 `E2E-` 测试批次，这是为了保留测试数据。正式运营前建议配置真实开放批次，或增加“测试数据不展示在公开首页当前批次”的运营策略。
4. 当前会话无法直接接管右侧内置浏览器的自动控制接口，因此本轮用项目内 Playwright Chromium 浏览器完成同站点回归，并保留报告和截图。

