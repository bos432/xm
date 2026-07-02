# 2026-07-02 交付文件索引

## 1. 交付结论

系统已完成本轮整改和线上主流程回归。当前可以进入交付验收。

## 2. 交付文件

| 文件 | 说明 |
| --- | --- |
| `modernization/docs/e2e-test-report-20260702-workflow-upgrade.md` | 本轮工作流升级回归测试报告（最终版） |
| `modernization/docs/deployment-guide-20260702-workflow-upgrade.md` | 本轮工作流升级部署文档（最终版） |
| `modernization/docs/optimization-remediation-plan-20260702-workflow-upgrade.md` | 本轮工作流升级优化整改方案（已执行） |
| `modernization/docs/operation-guide-with-screenshots-20260702.md` | 科技项目管理系统操作流程说明（截图版） |
| `modernization/docs/operation-flow-screenshots-20260702` | 操作流程截图目录 |
| `modernization/docs/e2e-test-report-20260702-delivery.md` | 线上全流程回归测试报告 |
| `modernization/docs/deployment-guide-20260702-delivery.md` | 宝塔/服务器部署与健康检查文档 |
| `modernization/docs/delivery-manual-20260702.md` | 完整使用教程、账号密码、操作说明 |
| `modernization/docs/optimization-remediation-plan-20260702-delivery.md` | 整改结论、已完成项、后续建议 |
| `modernization/e2e/reports/runs/20260702-023234/html/index.html` | Playwright HTML 测试报告 |
| `modernization/e2e/reports/runs/20260702-023234/results.json` | Playwright JSON 测试结果 |
| `modernization/e2e/reports/runs/20260702-023234/artifacts` | 各角色截图和富文本专项截图 |

## 3. 本次关键验证

- 公开首页：通过。
- 单位、区县、部门、专家、普通管理员、超管：全部可登录。
- 项目筛选：通过。
- 全周期项目回显：通过。
- 验收历史：通过。
- 首页素材：通过。
- 通知详情富文本：通过。
- 安全中心：通过。
- 前端 lint/build：通过。
- 后端相关 Feature tests：通过。

## 4. 交付账号

| 角色 | 登录名 | 密码 |
| --- | --- | --- |
| 普通管理员 | `e2e_20260702_delivery_admin` | `Test@2026pass` |
| 超级管理员 | `admin` | `ChangeMe-2026` |
| E2E 超管 | `e2e_20260630_103223_admin` | `Test@2026pass` |
| 单位用户 | `e2e_20260630_103223_unit` | `Test@2026pass` |
| 区县/归口 | `e2e_20260630_103223_county` | `Test@2026pass` |
| 主管部门 | `e2e_20260630_103223_department` | `Test@2026pass` |
| 专家 | `e2e_20260630_103223_expert` | `Test@2026pass` |
| 健康检查 | `health_check_user` | `HealthCheck-2026` |

正式交付后请修改超级管理员密码。

说明：普通管理员测试账号为本次交付回归新增账号，保留不删除。

## 5. 推荐现场验收顺序

1. 打开 `https://nxm.zlck888.com/`。
2. 超管登录，查看首页管理、富文本、安全中心。
3. 单位账号登录，查看项目申报、全周期、验收管理。
4. 区县账号登录，查看审核任务、验收管理。
5. 部门账号登录，查看审核任务、验收管理。
6. 专家账号登录，查看审核任务、验收管理。
7. 打开 `/projects?keyword=E2E-20260630-103223` 验证项目筛选。
8. 打开 `/lifecycle?project_id=5` 验证全周期项目回显。
9. 打开 `/acceptance?scope=reviewed&keyword=E2E-20260630-103223` 验证验收历史。

## 6. 数据保留

所有 `E2E-` 测试数据保留，不物理删除。
