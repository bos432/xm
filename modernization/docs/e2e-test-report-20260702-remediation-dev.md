# 2026-07-02 整改开发验证报告

## 1. 测试结论

- 本轮按 `optimization-remediation-plan-20260702-final.md` 完成可开发项。
- 本地后端、前端构建验证通过。
- 当前线上旧版本六角色主流程浏览器回归通过：7/7。
- 新增“首页素材运营状态摘要”和“公开首页当前批次”断言需要部署本轮代码后再跑完整 8 用例。

## 2. 本轮开发项

| 模块 | 内容 | 状态 |
| --- | --- | --- |
| 公开首页 | `metadata.e2e=true` 或名称/编号含 `E2E-` 的批次不再作为公开首页开放批次/当前批次展示 | 完成 |
| 首页管理 | 品牌素材页增加 Logo、Favicon、Banner 上传状态摘要 | 完成 |
| 首页管理 | 品牌素材页增加“公开首页当前批次”状态，若仍为测试批次会显示风险状态 | 完成 |
| E2E | Playwright 产物收敛到 `modernization/e2e/reports/artifacts` | 完成 |
| E2E | 超管首页素材用例增加“公开首页当前批次”断言 | 完成 |

## 3. 本地验证

### 后端

```bash
php -l modernization/backend/app/Http/Controllers/PublicHomeController.php
php -l modernization/backend/tests/Feature/PublicHomeManagementTest.php
cd modernization/backend
php -d extension=zip artisan test --filter PublicHomeManagementTest
```

结果：

```text
No syntax errors detected
Tests: 8 warnings (57 assertions)
```

说明：warning 为 Windows 中文路径下 Laravel 测试环境读取文件的已知提示，断言全部通过。

### 前端

```bash
cd modernization/frontend
npm run lint
npm run build
npm run e2e -- --list
```

结果：

- `npm run lint` 通过
- `npm run build` 通过
- `npm run e2e -- --list` 可列出 8 个用例

构建仍有第三方 `@vueuse/core` Rolldown `INVALID_ANNOTATION` warning 和大 chunk warning，属于非阻塞 P2 治理项。

## 4. 线上当前版本主流程回归

由于本轮代码尚未部署，线上仍是旧页面。已先验证当前线上主流程仍可用：

```bash
cd modernization/frontend
npm run e2e -- --grep=log
```

结果：

```text
7 passed
```

覆盖：

- 首页入口
- 单位用户登录、项目筛选、全周期、验收历史
- 区县审核登录、项目筛选、全周期、验收历史
- 部门审核登录、项目筛选、全周期、验收历史
- 专家评审登录、项目筛选、全周期、验收历史
- 管理员登录、项目筛选、全周期、验收历史
- 超级管理员登录、项目筛选、全周期、验收历史

## 5. 部署后完整验收

部署本轮代码后执行：

```bash
cd modernization/frontend
npm run e2e
```

预期：

```text
8 passed
```

完整 8 用例包括：

1. 首页无重复“单位注册”入口。
2. 单位用户主流程。
3. 区县审核主流程。
4. 部门审核主流程。
5. 专家评审主流程。
6. 管理员主流程。
7. 超级管理员主流程。
8. 超级管理员首页素材状态摘要和安全中心。

## 6. 测试数据

- 继续保留 `E2E-20260630-103223` 主回归样本。
- 继续保留 `E2E-20260701-094040` 等测试数据。
- 本轮未物理删除任何测试数据。

## 7. 交付说明

本轮代码完成并通过本地验证；线上完整 8 用例验收需要先执行生产部署，让右侧浏览器加载最新代码。

