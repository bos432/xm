# 交付文件索引（文档基线 2026-07-02，生产复核 2026-10-17）

## 1. 交付结论

当前版本已部署且基础服务健康，但正式业务运营验收未完成。本站 release 为 `20261017040227`，应用代码提交 `c0750b1`；最新 `main` 提交 `5eb989e` 仅更新 QA 文档，不含运行代码。本索引不代表正式申报已开放。

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
- 公开首页/API、部署登录健康检查：通过。
- 本地自动化：后端 211 tests/947 assertions；前端 lint/typecheck、4 项测试、build；部署隔离模拟均通过。
- 自动化结果不代表本轮生产六角色浏览器闭环已验收。
- 公众开放批次 API 返回 `[]`，尚无正式申报批次。
- SMTP Mailer 当前为 `log`；OSS 目标已配置但未验证真实上传/恢复。
- 专家评分模板为 100/100；仅核实 2 条 E2E 专家认证已通过记录，不能证明满足 3 位正式专家分配要求。

## 4. 交付账号

| 角色 | 登录名 | 密码 |
| --- | --- | --- |
| 超级管理员验收账号 | `e2e_20261016ops_super_admin` | root-only 凭据文件/受控渠道；本轮浏览器未验证 |
| 单位用户 | `e2e_20261016ops_unit` | 受控渠道；本轮浏览器未验证 |
| 区县/归口 | `e2e_20261016ops_county` | 受控渠道；本轮浏览器未验证 |
| 主管部门 | `e2e_20261016ops_department` | 受控渠道；本轮浏览器未验证 |
| 专家 | `e2e_20261016ops_expert` | 受控渠道；本轮浏览器未验证 |
| 业务管理员 | `e2e_20261016ops_admin` | 受控渠道；本轮浏览器未验证 |
| 健康检查 | `health_check_user` | 生产密码单独安全交付，不写入此仓库 |

历史文档中的固定密码均视为已公开，不得作为有效凭据交付。密码不保存在 Git 或本交付包。

## 5. 推荐现场验收顺序

1. 打开 `https://nxm.zlck888.com/`。
2. 超管登录，查看首页管理、富文本、安全中心。
3. 单位账号登录，查看项目申报、全周期、验收管理。
4. 区县账号登录，查看审核任务、验收管理。
5. 部门账号登录，查看审核任务、验收管理。
6. 专家账号登录，查看审核任务、验收管理。
7. 仅在隔离验收环境中，从后台测试数据筛选复制当前 E2E 关键字后验证项目/验收筛选。
8. 不使用历史固定项目 ID；在隔离环境选取本轮创建的测试项目核验全周期回显。

## 6. 数据保留

所有 `E2E-` 测试数据保留，不物理删除。正式开放批次与六角色闭环尚待完成。
