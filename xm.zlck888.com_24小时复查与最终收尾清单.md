# xm.zlck888.com 24小时复查与最终收尾清单

适用对象：`xm.zlck888.com` 本次站点木马清理后的 24 小时观察与最终收尾。

当前已知结论：

- 站点目录内已确认的高危木马文件已隔离。
- 首页、登录页、验证码、附件下载已恢复正常。
- `upload/uploads/img/js/excel/ueditor` 等高风险静态目录下未发现残留 `.php`。
- nginx 针对异常 PHP 路径的拦截规则已生效，日志中已有 `403` 命中。
- 目前未发现明确的 `cron`、`systemd`、`/tmp` 持久化后门。
- 这台机器至少从 `2026-03-15` 到 `2026-05-24` 存在持续被利用痕迹，长期仍建议迁移到新机器重建。

---

## 一、10分钟内必须完成

### 1. 立即修改所有关键密码

必须修改：

- 宝塔面板管理员密码
- Linux `root` 密码
- MySQL 用户 `xm_zlck888_com` 密码
- 网站后台管理员密码
- FTP 账号密码
- 阿里云控制台/RAM/API 密钥

如曾开启 SSH，还应同步处理：

- 更换 SSH 密钥
- 检查并清理 `authorized_keys`

### 2. 重新建立“干净基线”

在确认当前站点访问正常、木马文件已隔离后：

- 重新启用宝塔防篡改
- 使用当前状态重建干净基线
- 不要把隔离目录中的文件放回站点

### 3. 保留隔离证据

本次至少保留以下隔离目录，不要立刻删除：

- `/root/xm_postfix_confirmed_2026-05-24_160128`
- `/root/xm_postfix_strange_2026-05-24_161251`

建议保留 7-30 天，用于后续审计或回看。

---

## 二、1小时内完成

### 1. 复查 SSH 持久化

执行：

```bash
ls -lah /root/.ssh 2>/dev/null
sed -n '1,200p' /root/.ssh/authorized_keys 2>/dev/null
find /home -maxdepth 3 -name authorized_keys -type f -print -exec sed -n '1,200p' {} \; 2>/dev/null
```

判断原则：

- 只保留你明确认识的公钥
- 不认识的公钥先备份后删除

### 2. 备份当前“干净状态”

至少备份：

- 网站代码目录
- 数据库
- nginx 站点配置
- 宝塔相关防护配置
- 近 30 天访问日志和错误日志

建议：

- 代码和数据库各保存一份本机备份
- 再同步一份到外部安全位置

### 3. 检查站点是否重新出现异常文件

执行：

```bash
site=/www/wwwroot/xm.zlck888.com

find "$site" -type f -mtime -1 \
-not -path "$site/app/Runtime/*" \
-not -path "$site/upload/*" \
-not -path "$site/uploads/*" \
-not -name "*.log" \
-printf '%TY-%Tm-%Td %TH:%TM:%TS %p\n' 2>/dev/null | sort -r | head -200
```

重点关注：

- 根目录突然出现无扩展名空文件
- `public/`、`lib/`、`app/` 下新增 `.php`
- 图片目录、模板目录、库目录下的伪装 PHP

### 4. 再做一轮木马落点快查

执行：

```bash
site=/www/wwwroot/xm.zlck888.com

find "$site/public" "$site/lib" "$site/app" -type f \( \
-name "*.gif.php" -o \
-name "*.jpg.php" -o \
-name "*.png.php" -o \
-name "*.ico.php" -o \
-name "*.txt.php" \
\) -print 2>/dev/null

grep -REn --include='*.php' "eval[[:space:]]*\(|assert[[:space:]]*\(|base64_decode[[:space:]]*\(|file_put_contents[[:space:]]*\(|create_function[[:space:]]*\(|php://input|system[[:space:]]*\(|shell_exec[[:space:]]*\(" "$site/public" "$site/lib" "$site/app" 2>/dev/null
```

说明：

- 老三方库命中要人工判断
- 不要因为 `tcpdf`、`PHPMailer`、`PCLZip`、`JSON.php` 命中就误删

---

## 三、24小时内持续观察

### 1. 持续观察恶意探测是否仍在打旧后门

执行：

```bash
grep -RinE 'extra_clean_paper|140x140\.gif\.php|taunl\.php|jSignature/libs/index\.php|forun\.php|databasse\.php|cheBase\.php' /www/wwwlogs /var/log/nginx 2>/dev/null | tail -200
```

预期：

- 仍然会看到外部探测请求
- 但应该主要表现为 `403` 或找不到文件
- 不应再出现 `200` 正常执行

### 2. 复查业务是否稳定

执行：

```bash
curl -s "http://xm.zlck888.com/" | grep -E "tdcqt|xk.js|String.fromCharCode|unicodeCodePoints|星空|开云"

curl -s "http://xm.zlck888.com/index.php?m=Country&a=sign_in&role=0" | grep -E "盟本级管理员登录|用户名|验证码|tdcqt|xk.js|String.fromCharCode|unicodeCodePoints|星空|开云"

curl -s -D - -o /tmp/country_verify.out "http://xm.zlck888.com/index.php?m=Country&a=verify&t=$(date +%s)" | grep -i content-type
```

预期：

- 首页不再命中异常关键词
- 登录页正常
- 验证码返回 `Content-Type: image/png`

### 3. 复查高风险静态目录是否重新掉入 `.php`

执行：

```bash
find "$site/upload" "$site/uploads" "$site/img" "$site/js" "$site/excel" "$site/ueditor/php/upload" -type f -name "*.php" -print 2>/dev/null
```

预期：

- 应为空

### 4. 复查计划任务与临时目录

执行：

```bash
crontab -l 2>/dev/null
crontab -u www -l 2>/dev/null

find /tmp /var/tmp /dev/shm -maxdepth 2 -type f \( -name "*.php" -o -name "*.sh" -o -name "*.py" \) -printf '%TY-%Tm-%Td %TH:%TM:%TS %p\n' 2>/dev/null | sort -r | head -200
```

预期：

- 不应突然出现新的临时脚本
- 不应新增可疑计划任务

---

## 四、建议继续保留的防护

不要撤销以下措施：

- nginx 对静态目录下 PHP 的禁止执行规则
- 宝塔防篡改
- 关键代码目录最小写权限策略
- 运行目录与代码目录分离的权限设置

建议代码权限保持：

- 代码目录：`root:root`
- 运行/缓存/上传目录：按业务需要仅给 `www:www`

---

## 五、已确认的攻击时间线

可作为后续内部汇报依据：

- `2026-03-15`：`taunl.php` 被真实利用
- `2026-04-11`：`taunl.php`、`forun.php` 被利用
- `2026-05-22`：`databasse.php`、`cheBase.php` 被持续利用
- `2026-05-23` 至 `2026-05-24`：旧后门路径仍持续被外部探测

这说明：

- 不是单次误报
- 不是单一后门
- 是持续、重复、多入口利用

---

## 六、长期建议

当前站点层已基本恢复，但不建议把“当前机器已暂时恢复可用”理解为“主机已绝对干净”。

长期最稳妥方案：

1. 新建一台全新服务器
2. 新装系统与运行环境
3. 使用新密码、新密钥
4. 只迁移：
   - 干净代码
   - 干净数据库数据
   - 必要上传文件
5. 不迁移：
   - 旧站点运行缓存
   - 隔离目录
   - 不明脚本
   - 历史测试目录

---

## 七、建议后续下线或精简的目录

这些目录不一定是木马，但在生产环境暴露价值不大，后续建议精简：

- `app/Lib/Action/Home/PHPExcel-1.7.7/Tests`
- `app/Lib/Action/Home/PHPMailer_v5.1/test`
- 不再使用的备份目录
- 历史重复 include 文件，如 `*-1.php`

处理原则：

- 先备份
- 再清理
- 每次清理后做业务验证

---

## 八、每日复查最小命令集

如果未来几天只想做最小复查，执行下面这一组即可：

```bash
site=/www/wwwroot/xm.zlck888.com

echo "===== 业务关键词 ====="
curl -s "http://xm.zlck888.com/" | grep -E "tdcqt|xk.js|String.fromCharCode|unicodeCodePoints|星空|开云"

echo "===== 登录页 ====="
curl -s "http://xm.zlck888.com/index.php?m=Country&a=sign_in&role=0" | grep -E "盟本级管理员登录|用户名|验证码|tdcqt|xk.js|String.fromCharCode|unicodeCodePoints|星空|开云"

echo "===== 验证码类型 ====="
curl -s -D - -o /tmp/country_verify.out "http://xm.zlck888.com/index.php?m=Country&a=verify&t=$(date +%s)" | grep -i content-type

echo "===== 静态目录 PHP ====="
find "$site/upload" "$site/uploads" "$site/img" "$site/js" "$site/excel" "$site/ueditor/php/upload" -type f -name "*.php" -print 2>/dev/null

echo "===== 最近新增文件 ====="
find "$site" -type f -mtime -1 \
-not -path "$site/app/Runtime/*" \
-not -path "$site/upload/*" \
-not -path "$site/uploads/*" \
-not -name "*.log" \
-printf '%TY-%Tm-%Td %TH:%TM:%TS %p\n' 2>/dev/null | sort -r | head -100
```

如果这组输出持续正常，说明短期内站点状态相对稳定。
