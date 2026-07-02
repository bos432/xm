# 2026-07-02 工作流升级部署文档

## 1. 部署范围

- 只部署 `modernization` 新系统。
- 旧 ThinkPHP 保持只读，不做代码迁移和覆盖。
- 本次包含前端、后端和 E2E 脚本改动。

## 2. 本地提交前检查

在本地仓库执行：

```bash
cd modernization/backend
php artisan test --filter ProjectApplicationWorkflowTest
php artisan test --filter ProjectExportTest
php artisan test --filter ReviewWorkflowTest
php artisan test --filter ReviewExportTest

cd ../frontend
npm run lint
npm run build
```

预期结果：

- 后端 4 组 Feature tests 全部通过。
- 前端 lint/build 全部通过。

## 3. 推送 GitHub

在仓库根目录执行：

```bash
git status
git add modernization/backend/app/Http/Controllers/ProjectController.php \
  modernization/backend/app/Http/Controllers/ProjectExportController.php \
  modernization/backend/app/Http/Controllers/ReviewController.php \
  modernization/backend/tests/Feature/ProjectApplicationWorkflowTest.php \
  modernization/backend/tests/Feature/ProjectExportTest.php \
  modernization/backend/tests/Feature/ReviewWorkflowTest.php \
  modernization/frontend/src/views/ProjectsView.vue \
  modernization/frontend/src/views/ReviewTasksView.vue \
  modernization/frontend/src/views/PublicHomeView.vue \
  modernization/frontend/src/favicon.js \
  modernization/e2e/tests/smoke.spec.js \
  modernization/docs/e2e-test-report-20260702-workflow-upgrade.md \
  modernization/docs/deployment-guide-20260702-workflow-upgrade.md \
  modernization/docs/optimization-remediation-plan-20260702-workflow-upgrade.md \
  modernization/docs/operation-guide-with-screenshots-20260702.md \
  modernization/docs/operation-flow-screenshots-20260702
git commit -m "Improve project workflow and review scoring delivery"
git push origin main
```

说明：

- 不提交 `/tmp/github_token.txt`、本地 token、临时 API token。
- `modernization/e2e/reports` 可作为本地报告保留，通常不需要作为生产代码提交。

## 4. 宝塔终端部署命令

登录服务器后执行：

```bash
cd /www/wwwroot/nxm.zlck888.com

APP_ROOT=/www/wwwroot/nxm.zlck888.com \
REPO_URL=https://github.com/bos432/xm.git \
BRANCH=main \
PHP_BIN=/www/server/php/83/bin/php \
FRONTEND_API_BASE=/api \
RUN_SEED=1 \
bash ./deploy.sh
```

成功标志：

```text
Health login passed for [health_check_user].
Running HTTP login health check
Deployment complete: <release_id>
Website root should be: /www/wwwroot/nxm.zlck888.com/current/public
```

## 5. 部署后健康检查

```bash
curl -I https://nxm.zlck888.com/
curl -s https://nxm.zlck888.com/api/auth/captcha; echo
curl -s https://nxm.zlck888.com/api/public/homepage | head -c 500; echo

cd /www/wwwroot/nxm.zlck888.com/current/backend
/www/server/php/83/bin/php artisan health:login-check \
  --username=health_check_user \
  --password='HealthCheck-2026'
```

预期：

- 首页 HTTP 200。
- 验证码接口返回 `captcha_id` 和数学题。
- 首页配置接口返回 brand/nav/hero 等 JSON。
- 登录健康检查通过。

## 6. 部署后浏览器验收

强刷浏览器后验证：

1. 首页能正常加载，登录框验证码正常。
2. 单位账号登录，进入“项目申报”，列表有“序号”，新建项目中预算显示“预算金额（万元）”。
3. 区县账号登录，进入“审核任务”，操作按钮显示“详情 / 审核处理”。
4. 专家账号登录，进入“审核任务”，点击“审核处理”可看到专家评分维度表。
5. 管理员账号登录，项目导出 CSV 包含推荐/支持/支持金额/推荐专家等字段。
6. 超管登录，首页管理和安全中心可访问。

## 7. 回滚说明

如部署后发现阻塞问题：

1. 不删除测试数据。
2. 在服务器查看当前 releases：

```bash
ls -lt /www/wwwroot/nxm.zlck888.com/releases | head
```

3. 切回上一稳定版本：

```bash
cd /www/wwwroot/nxm.zlck888.com
ln -sfn /www/wwwroot/nxm.zlck888.com/releases/<previous_release>/public current/public
```

实际回滚命令以现有 `deploy.sh` 的 current 链接结构为准，执行前先确认 `current` 指向。

