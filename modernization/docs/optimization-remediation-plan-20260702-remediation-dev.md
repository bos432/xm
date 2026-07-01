# 2026-07-02 整改开发后优化方案

## Summary

本轮已完成正式上线前必须处理的公开首页 E2E 批次展示问题，并增强首页素材运营状态提示。主流程代码验证通过，线上完整 8 用例需要部署后执行。

## 已完成

- 公开首页开放批次过滤：
  - `metadata.e2e=true` 的批次不对公众首页展示。
  - 名称或编号包含 `E2E-` 的早期测试批次也不对公众首页展示。
  - 测试数据只隐藏展示，不物理删除。
- 首页管理品牌素材状态摘要：
  - Logo 已上传/未上传。
  - Favicon 已上传/未上传。
  - Banner 已上传/未上传。
  - 公开首页当前批次状态。
- E2E 产物目录收敛：
  - HTML/JSON 仍在 `modernization/e2e/reports`。
  - 截图/trace/error context 进入 `modernization/e2e/reports/artifacts`。
- 自动化覆盖：
  - 超管首页素材用例校验“公开首页当前批次”状态摘要。

## 部署后 P0 验收

1. `/api/public/homepage` 的 `open_batches/current_batch` 不再出现 `E2E-` 测试批次。
2. 首页管理品牌素材页可见四个状态：
   - Logo
   - Favicon
   - Banner
   - 公开首页当前批次
3. 六角色主流程继续通过。
4. 完整 Playwright E2E `8 passed`。

## 剩余 P1

### 测试数据后台治理

建议下一轮做：

- 项目、验收、批次统一增加 `e2e` 筛选控件。
- 超管支持批量归档测试数据。
- Dashboard 增加是否纳入测试数据统计的开关。

### E2E 报告保留策略

当前报告会覆盖固定目录。建议下一轮：

- 每次运行生成 `runs/YYYYMMDD-HHmmss` 目录。
- 自动清理或归档超过 N 次的报告。
- 部署完成后把报告路径写入部署日志。

## 剩余 P2

### 前端构建 warning 治理

当前 `npm run build` 仍有非阻塞提示：

- 第三方 `@vueuse/core` Rolldown `INVALID_ANNOTATION`
- 主 chunk 超过 500KB

建议：

- 继续拆分低频页面。
- 评估 Vite/Rolldown 配置或版本升级。
- 对全周期详情、验收详情、系统配置等页面做更细粒度懒加载。

### 权限矩阵细化

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

## 风险提示

- 正式 favicon 仍需要运营提供素材并由超管上传。
- 如果生产存在没有 `metadata.e2e=true` 但名称/编号不含 `E2E-` 的测试批次，仍需要后台手动归档或补 metadata 标记。
- 本轮代码未删除任何测试数据，避免影响回归样本。

