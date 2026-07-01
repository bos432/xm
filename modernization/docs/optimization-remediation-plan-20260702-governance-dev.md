# 2026-07-02 测试数据治理优化整改方案

## Summary

本轮继续按“整改方案”推进上线前治理能力，重点解决测试数据长期保留后对运营和统计造成的干扰。实现策略是“可识别、可筛选、可归档、不删除”：保留 E2E 数据作为回归样本，同时让运营人员能够在后台明确区分测试数据和正式数据。

## 已完成

### 测试数据筛选

- 申报批次支持 `e2e=1/0`：
  - `metadata.e2e=true`
  - 名称包含 `E2E-`
  - 编号包含 `E2E-`
- 项目管理支持 `e2e=1/0`：
  - 项目自身 `metadata.e2e=true`
  - 项目标题包含 `E2E-`
  - 所属批次为测试批次
- 验收管理支持 `e2e=1/0`：
  - 验收自身 `metadata.e2e=true`
  - 关联项目为测试项目
  - 关联批次为测试批次

### 后台操作

- 项目管理增加“测试数据”筛选控件。
- 验收管理增加“测试数据”筛选控件。
- 申报批次增加“测试数据”筛选控件。
- 超管增加“归档测试批次”操作。
- 普通管理员可筛选，但不能批量归档测试批次。

### 数据安全

- 不物理删除任何测试项目、验收、用户、批次和全周期记录。
- 批量归档只处理识别为 E2E 的申报批次。
- 归档操作写入 `operation_logs`，便于审计。

### E2E 报告

- 每次运行自动生成独立 `run-id`。
- 报告目录改为：

```text
modernization/e2e/reports/runs/<run-id>
```

- 同一轮报告下包含 HTML、JSON、截图/trace 等产物。

## 本轮修复要点

### 1. 避免 `metadata` 为空时误排除正式数据

问题：

- 旧写法使用 `whereNot` 或 `NOT LIKE` 排除 E2E。
- 当 `metadata` 为 `NULL` 时，SQL 三值逻辑会让正式数据也被排除。

整改：

- `e2e=0` 改为显式 NULL 友好条件：
  - `metadata is null` 视为非 E2E。
  - `metadata not like ...` 只在非空时判断。
  - 关联批次/项目使用 `whereDoesntHave` 排除测试关系。

### 2. 测试数据归档只作用于批次

原则：

- 项目、验收、全周期记录仍作为回归样本保留。
- 只归档测试申报批次，避免测试批次继续作为开放业务批次干扰运营。

## 部署后 P0 验收

1. 线上 `npm run e2e` 返回 `8 passed`。
2. 超管可在申报批次页面筛选测试数据。
3. 超管点击“归档测试批次”后，只归档 E2E 批次，不影响正式批次。
4. `/projects?e2e=0` 不误排除 metadata 为空的正式项目。
5. `/acceptance?e2e=0` 不误排除关联正式项目的验收记录。
6. E2E 报告写入独立 run 目录，不覆盖上一次报告。

## 仍建议保留的 P1

### Dashboard 测试数据统计开关

建议超管 Dashboard 增加：

- 纳入测试数据
- 排除测试数据

默认排除测试数据，避免运营统计被 E2E 样本影响。

### 测试数据归档范围扩展

当前只归档测试批次。下一轮可增加：

- 测试项目“归档视图”
- 测试验收“归档视图”
- 全周期测试记录筛选

仍建议不做物理删除。

### E2E 报告清理策略

建议增加：

- 保留最近 20 次报告。
- 超过保留范围自动压缩或清理。
- 部署日志写入本次 E2E 报告路径。

## P2 中期治理

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
- `test_data.archive`

### 前端性能治理

当前构建仍有非阻塞 warning：

- `@vueuse/core` Rolldown `INVALID_ANNOTATION`
- 主 chunk 超过 500KB

建议继续拆分低频页面并评估 Vite/Rolldown 配置。

## 风险提示

- 如果历史测试数据没有 `metadata.e2e=true` 且名称/编号不含 `E2E-`，系统无法自动识别，需要人工补标记。
- 如果误把正式批次命名为 `E2E-`，会被测试数据筛选和归档命中。
- 归档测试批次不会删除数据，但会影响公开首页和开放批次选择，需要上线前确认测试批次不再作为业务入口使用。
