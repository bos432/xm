# 2026-07-02 测试数据治理部署文档

## 1. 部署范围

- 只部署 `modernization` 新 Laravel/Vue 系统。
- 旧 ThinkPHP 系统保持只读。
- 本轮没有新增数据库迁移。
- 本轮不删除任何测试数据。

## 2. 标准部署命令

生产仓库已公开，部署时不再拼接 GitHub Token：

```bash
cd /www/wwwroot/nxm.zlck888.com

APP_ROOT=/www/wwwroot/nxm.zlck888.com \
REPO_URL=https://github.com/bos432/xm.git \
BRANCH=main \
PHP_BIN=/www/server/php/83/bin/php \
RUN_SEED=1 \
bash ./deploy.sh
```

## 3. 部署前检查

确认共享环境文件存在：

```bash
cd /www/wwwroot/nxm.zlck888.com
grep -E '^(APP_URL|HEALTH_CHECK_USERNAME|HEALTH_CHECK_PASSWORD)=' shared/.env
```

推荐配置：

```env
APP_URL=https://nxm.zlck888.com
HEALTH_CHECK_USERNAME=health_check_user
HEALTH_CHECK_PASSWORD=<生产实际密码>
```

正常生产部署不要设置 `SKIP_LOGIN_HEALTH=1`。只有紧急救援时才允许临时跳过登录健康检查。

## 4. 部署后健康检查

```bash
curl -s https://nxm.zlck888.com/api/auth/captcha
curl -s https://nxm.zlck888.com/api/public/homepage | head -c 500
curl -I https://nxm.zlck888.com/
```

重点确认：

- `/api/auth/captcha` 返回 `captcha_id` 和验证码题目。
- `/api/public/homepage` 返回 200。
- 首页 HTTP 200。
- 部署日志不出现 `Health login skipped`，除非明确设置了 `SKIP_LOGIN_HEALTH=1`。

## 5. 部署后功能验收

用超管登录后台后检查：

1. `申报批次` 页面可见“测试数据”筛选。
2. 超管可见“归档测试批次”按钮。
3. `项目管理` 页面可见“测试数据”筛选。
4. `验收管理` 页面可见“测试数据”筛选。
5. 普通管理员可筛选测试数据，但不能批量归档测试批次。
6. 单位、区县、部门、专家不扩大测试数据治理权限。

接口抽查：

```bash
curl -H "Authorization: Bearer <token>" "https://nxm.zlck888.com/api/projects?e2e=1&keyword=E2E-20260630-103223"
curl -H "Authorization: Bearer <token>" "https://nxm.zlck888.com/api/acceptance?scope=visible&e2e=1&keyword=E2E-20260630-103223"
curl -H "Authorization: Bearer <token>" "https://nxm.zlck888.com/api/application-batches?e2e=1"
```

## 6. 浏览器自动化验收

本地执行：

```bash
cd modernization/frontend

E2E_BASE_URL=https://nxm.zlck888.com \
E2E_STAMP=E2E-20260630-103223 \
E2E_PROJECT_ID=5 \
E2E_UNIT_USERNAME=e2e_20260630_103223_unit \
E2E_UNIT_PASSWORD=Test@2026pass \
E2E_COUNTY_USERNAME=e2e_20260630_103223_county \
E2E_COUNTY_PASSWORD=Test@2026pass \
E2E_DEPARTMENT_USERNAME=e2e_20260630_103223_department \
E2E_DEPARTMENT_PASSWORD=Test@2026pass \
E2E_EXPERT_USERNAME=e2e_20260630_103223_expert \
E2E_EXPERT_PASSWORD=Test@2026pass \
E2E_ADMIN_USERNAME=e2e_20260630_103223_admin \
E2E_ADMIN_PASSWORD=Test@2026pass \
E2E_SUPER_ADMIN_USERNAME=admin \
E2E_SUPER_ADMIN_PASSWORD=ChangeMe-2026 \
npm run e2e
```

预期结果：

```text
8 passed
```

报告输出：

```text
modernization/e2e/reports/runs/<run-id>/html/index.html
modernization/e2e/reports/runs/<run-id>/results.json
modernization/e2e/reports/runs/<run-id>/artifacts
```

## 7. 回滚方式

代码回滚：

```bash
cd /www/wwwroot/nxm.zlck888.com
ls -lt releases
ln -sfn releases/<previous-release-id> current
nginx -t && /etc/init.d/nginx reload
```

说明：

- 本轮无新增迁移，常规代码回滚即可恢复页面和接口行为。
- 如果已经执行过“归档测试批次”，回滚代码不会自动把批次状态改回 `open`；需要超管在后台手动调整或通过数据库审计后处理。

## 8. 常见问题

- 如果项目/验收 `e2e=0` 查不到正式数据，优先确认已部署本轮修复；旧版 `NOT LIKE` 遇到空 metadata 可能误排除正式数据。
- 如果 E2E 登录被风控拦截，先在安全中心检查账号/IP 锁定状态，必要时由超管解锁或临时加入测试白名单。
- 如果浏览器标签页 favicon 不更新，刷新或重新打开标签页；favicon 有浏览器缓存。
