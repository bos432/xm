# 2026-07-02 回归后优化整改方案

## Summary

本轮线上主流程浏览器回归已通过，没有发现阻塞上线的功能缺陷。后续整改重点从“修主流程”转为“正式运营配置、测试数据治理、报告归档和前端构建治理”。

## 当前状态

- 首页、登录、项目、全周期、验收、安全中心、首页素材管理均验证通过。
- 六类角色可登录并访问各自菜单。
- `E2E-20260630-103223` 继续作为主回归样本保留。
- `E2E-20260701-094040` 等测试数据仍在线保留。
- 正式 favicon 尚未上传，当前 `brand.favicon_url=null`。

## P0 正式上线前运营配置

### 1. 上传正式 favicon

- 位置：`首页管理 -> 品牌素材 -> 站点图标 Favicon`
- 角色：仅超级管理员
- 文件：`ico/png/svg`，512KB 内
- 验收：
  - `/api/public/homepage` 返回 `brand.favicon_url`
  - 首页和后台浏览器标签页显示新图标

### 2. 处理公开首页当前批次显示 E2E 数据

现状：公开首页 `current_batch` 当前显示 `E2E-20260701-094040 Batch`，原因是测试批次仍为 open 且需要保留测试数据。

建议二选一：

1. 创建正式业务批次并设置为开放，使首页显示真实批次。
2. 增加公开首页批次筛选规则：`metadata.e2e=true` 的批次不作为公开首页当前批次展示，但数据仍保留在后台。

不建议物理删除 E2E 数据。

## P1 近期体验与运维增强

### 1. E2E 报告目录收敛

现状：HTML/JSON 报告已在 `modernization/e2e/reports`，截图在项目根目录 `test-results/`。

建议：

- 将 Playwright `outputDir` 调整到 `modernization/e2e/reports/artifacts`。
- 每次部署后保留最近 N 次报告。
- 报告目录不提交 Git，只作为验收附件。

### 2. 测试数据后台治理

建议超管增加：

- `metadata.e2e=true` 筛选。
- 批量归档测试项目、测试批次、测试验收。
- Dashboard 统计是否包含测试数据的开关。

### 3. 首页素材运营状态提示

建议在首页管理品牌素材区增加状态摘要：

- Logo：已上传/未上传
- Banner：已上传/未上传
- Favicon：已上传/未上传
- 当前公开首页是否正在展示测试批次

## P2 中期治理

### 1. 前端性能和构建 warning 治理

当前 `npm run build` 通过，但仍有：

- 第三方 `@vueuse/core` 的 Rolldown `INVALID_ANNOTATION` warning
- 主 chunk 超过 500KB warning

建议：

- 继续拆分低频页面。
- 评估 Vite/Rolldown 配置或版本升级。
- 对迁移准备、全周期详情、系统配置等页面做更细粒度懒加载。

### 2. 权限矩阵继续细化

继续推进按钮/接口级权限：

- `project.view_detail`
- `project.view_timeline`
- `project.update`
- `project.delete`
- `acceptance.view_pending`
- `acceptance.view_reviewed`
- `acceptance.review`
- `security.manage_whitelist`
- `settings.manage_smtp`
- `system_text.manage`
- `public_home.manage_assets`

原则：前端按权限显示按钮，后端接口必须同步强校验。

### 3. 监控和备份

建议补齐：

- 每日数据库备份并定期恢复演练。
- 队列失败任务告警。
- 登录风控异常事件告警。
- 部署后自动发送健康检查结果。

## 验收标准

- 正式 favicon 上传并生效。
- 公开首页不再把 E2E 批次作为当前业务批次展示，或已明确这是验收环境保留状态。
- E2E 报告、截图、JSON 结果可稳定生成。
- 测试数据可以筛选、归档，但不物理删除。
- 构建 warning 不影响上线，但进入后续性能治理清单。

