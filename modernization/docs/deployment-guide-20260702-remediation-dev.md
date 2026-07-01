# 2026-07-02 整改开发部署文档

## 1. 部署范围

- 只部署 `modernization` 新 Laravel/Vue 系统。
- 旧 ThinkPHP 系统保持只读。
- 本轮部署后公开首页将不再展示 E2E 测试批次作为当前业务批次。

## 2. 标准部署命令

```bash
cd /www/wwwroot/nxm.zlck888.com

APP_ROOT=/www/wwwroot/nxm.zlck888.com \
REPO_URL=https://github.com/bos432/xm.git \
BRANCH=main \
PHP_BIN=/www/server/php/83/bin/php \
RUN_SEED=1 \
bash ./deploy.sh
```

## 3. 必备环境变量

确认 `/www/wwwroot/nxm.zlck888.com/shared/.env` 存在：

```env
APP_URL=https://nxm.zlck888.com
HEALTH_CHECK_USERNAME=health_check_user
HEALTH_CHECK_PASSWORD=<生产实际密码>
```

正常生产部署不要设置 `SKIP_LOGIN_HEALTH=1`。只有人工救急时才允许临时跳过登录健康检查。

## 4. 部署后健康检查

```bash
curl -s https://nxm.zlck888.com/api/auth/captcha
curl -s https://nxm.zlck888.com/api/public/homepage | head -c 500
curl -I https://nxm.zlck888.com/
```

重点确认：

- `/api/auth/captcha` 返回 `captcha_id` 和题目。
- `/api/public/homepage` 返回 200。
- `open_batches/current_batch` 不再包含 `E2E-` 测试批次。
- 首页 HTTP 200。

## 5. 部署后浏览器验收

在本地运行：

```bash
cd modernization/frontend

E2E_BASE_URL=https://nxm.zlck888.com \
E2E_STAMP=E2E-20260630-103223 \
E2E_PROJECT_ID=5 \
E2E_UNIT_USERNAME=... E2E_UNIT_PASSWORD=... \
E2E_COUNTY_USERNAME=... E2E_COUNTY_PASSWORD=... \
E2E_DEPARTMENT_USERNAME=... E2E_DEPARTMENT_PASSWORD=... \
E2E_EXPERT_USERNAME=... E2E_EXPERT_PASSWORD=... \
E2E_ADMIN_USERNAME=... E2E_ADMIN_PASSWORD=... \
E2E_SUPER_ADMIN_USERNAME=... E2E_SUPER_ADMIN_PASSWORD=... \
npm run e2e
```

报告输出：

- HTML：`modernization/e2e/reports/html/index.html`
- JSON：`modernization/e2e/reports/results.json`
- 截图/trace：`modernization/e2e/reports/artifacts`

## 6. 人工验收点

1. 首页可打开。
2. 首页只保留“新单位注册”。
3. 首页“当前批次”不显示 `E2E-` 测试批次。
4. 单位、区县、部门、专家、管理员、超管可登录。
5. `/projects?keyword=E2E-20260630-103223` 筛选正常。
6. `/lifecycle?project_id=5` 项目回显正常。
7. `/acceptance?scope=reviewed&keyword=E2E-20260630-103223` 验收历史正常。
8. 超管进入 `首页管理 -> 品牌素材`，可见 Logo、Favicon、Banner 状态摘要和公开首页当前批次状态。
9. 超管进入 `安全中心`，可见登录风控状态。

## 7. 回滚

```bash
cd /www/wwwroot/nxm.zlck888.com
ls -lt releases
ln -sfn releases/<previous-release-id> current
nginx -t && /etc/init.d/nginx reload
```

数据库迁移不随代码回滚自动撤回，涉及数据问题时需要使用已验证备份。

