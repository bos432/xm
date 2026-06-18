# xm.zlck888.com 巡检与日志排查手册

适用站点：`xm.zlck888.com`

适用场景：
- 每日巡检
- 值班排查
- 木马复发初判
- 日志追踪

基线状态：
- 首页无木马特征关键词
- 后台登录页可正常显示 `盟本级管理员登录`、`用户名`、`验证码`
- 验证码接口返回 `image/png`
- `upload/uploads/img/js/excel/ueditor/php/upload` 目录下无残留 `.php`
- `http://xm.zlck888.com/js/test.php` 返回 `403 Forbidden`
- `http://xm.zlck888.com/upload/pdf/down.zip` 返回 `200 OK`

---

## 1. 使用前说明

### 1.1 巡检原则
- 先执行命令，再对照“正常结果/异常结果”判断。
- 发现异常时，不要急着直接删除文件，先保留证据。
- 如果发现可疑文件，先看内容，再隔离。
- 如果发现日志异常，先记下时间、IP、访问路径。

### 1.2 先设置变量
每次登录服务器后，先执行：

```bash
site=/www/wwwroot/xm.zlck888.com
```

---

## 2. 每日最小巡检

这 4 条是每天必须执行的最小巡检。

### 2.1 首页木马特征巡检

```bash
curl -s "http://xm.zlck888.com/" | grep -E "tdcqt|xk.js|String.fromCharCode|unicodeCodePoints|星空|开云"
```

正常结果：
- 没有任何输出

异常结果：
- 只要有任意输出，就不正常

处理动作：
- 立刻继续执行“2.2 后台登录页巡检”
- 再执行“2.3 验证码接口巡检”
- 再执行“2.4 高风险目录 PHP 巡检”
- 保留输出结果，不要清屏

### 2.2 后台登录页巡检

```bash
curl -s "http://xm.zlck888.com/index.php?m=Country&a=sign_in&role=0" | grep -E "盟本级管理员登录|用户名|验证码|tdcqt|xk.js|String.fromCharCode|星空|开云"
```

正常结果：
- 能看到下面 3 项
- `盟本级管理员登录`
- `用户名`
- `验证码`

异常结果：
- 看不到上面 3 项
- 或出现 `tdcqt`、`xk.js`、`String.fromCharCode`、`星空`、`开云`

处理动作：
- 视为高优先级异常
- 立即执行“8.1 异常留证”
- 再执行“4. 高风险文件排查”
- 再执行“5. 日志排查”

### 2.3 验证码接口巡检

```bash
curl -s -D - -o /tmp/country_verify.out "http://xm.zlck888.com/index.php?m=Country&a=verify&t=$(date +%s)" | grep -i content-type
file /tmp/country_verify.out
```

正常结果：
- 第一条输出：`Content-Type: image/png`
- 第二条输出包含：`PNG image data`

异常结果：
- 返回 `text/html`
- 返回 `403`
- 返回 `500`
- 文件不是 PNG

处理动作：
- 记录输出
- 继续执行“5.2 Nginx 木马访问痕迹排查”
- 继续执行“5.3 最近 POST 请求排查”

### 2.4 高风险目录 PHP 残留巡检

```bash
find "$site/upload" "$site/uploads" "$site/img" "$site/js" "$site/excel" "$site/ueditor/php/upload" -type f -name "*.php" -print 2>/dev/null
```

正常结果：
- 没有任何输出

异常结果：
- 只要出现任意 `.php` 文件，都不正常

处理动作：
- 不要立即删除
- 先查看文件前 120 行：

```bash
sed -n '1,120p' 可疑文件完整路径
```

- 再执行“8.1 异常留证”
- 再隔离该文件

---

## 3. 每周补充巡检

### 3.1 上传目录禁执行巡检

```bash
curl -I "http://xm.zlck888.com/js/test.php"
```

正常结果：
- `403 Forbidden`

异常结果：
- `200 OK`
- `302`
- `500`

处理动作：
- 说明 Nginx 禁执行规则可能失效
- 立即检查站点 Nginx 配置

### 3.2 附件下载误伤巡检

```bash
curl -I "http://xm.zlck888.com/upload/pdf/down.zip"
```

正常结果：
- `200 OK`
- 或 `206 Partial Content`

异常结果：
- `403 Forbidden`

处理动作：
- 说明 Nginx 限制规则误伤业务附件下载
- 检查是否存在“全局禁止 zip/tar.gz 下载”的规则

### 3.3 高危文件名巡检

```bash
find "$site" -type f \( -name "zakst.php" -o -name "ad-deny.php" -o -name "cssjs.php" -o -name "jquery-1.10.2.min.php" -o -name "*-1.php" \) -print 2>/dev/null
```

正常结果：
- 不应再出现这些已清理过的高危文件名

异常结果：
- 重新出现上述文件

处理动作：
- 视为高危复发
- 先查看文件内容
- 再隔离，不要直接删除

---

## 4. 高风险文件排查

### 4.1 查看可疑文件内容

```bash
sed -n '1,120p' 可疑文件完整路径
```

重点关注以下特征：
- `file_put_contents`
- `move_uploaded_file`
- `base64_decode`
- `eval(`
- `assert(`
- `system(`
- `shell_exec(`
- 接收 `$_POST`、`$_REQUEST` 后直接写文件或执行

如果命中上述特征，优先视为高风险。

### 4.2 定向危险函数扫描

```bash
grep -RIn --include='*.php' "file_put_contents|move_uploaded_file|base64_decode|eval[[:space:]]*\(|assert[[:space:]]*\(|system[[:space:]]*\(|shell_exec[[:space:]]*\(" "$site/app/Tpl" "$site/public" "$site/app/Lib/Action/Home" 2>/dev/null
```

正常结果：
- 没有输出，或都是已知正常业务代码

异常结果：
- 出现陌生文件
- 出现模板目录、公共目录里的写文件/执行类代码

处理动作：
- 单独查看对应文件
- 不要批量删除
- 先隔离再确认

---

## 5. 日志排查

日志排查的目标不是“看起来多不多”，而是找到：
- 陌生 IP
- 可疑路径
- 异常 POST
- 成功登录痕迹

### 5.1 系统登录日志

```bash
grep -E "Accepted|Failed password|Invalid user|authentication failure" /var/log/secure* 2>/dev/null | tail -n 200
```

正常结果：
- 没有明显陌生成功登录
- 没有大量爆破痕迹

异常结果：
- 大量 `Failed password`
- 大量 `Invalid user`
- 出现你不认识的公网 IP 成功登录

处理动作：
- 记录 IP 和时间
- 结合阿里云安全组、面板、账户情况继续排查

### 5.2 SSH 爆破来源统计

```bash
grep "Failed password" /var/log/secure* 2>/dev/null | grep -oE 'from [0-9.]+' | awk '{print $2}' | sort | uniq -c | sort -nr | head
```

正常结果：
- 少量零星扫描

异常结果：
- 某个 IP 次数特别高

处理动作：
- 记录 IP
- 后续可考虑封禁或安全组限制

### 5.3 Nginx 木马访问痕迹排查

```bash
grep -Ei "zakst\.php|ad-deny\.php|cssjs\.php|jquery-1\.10\.2\.min\.php|upload.*\.php|js/.*\.php" /www/wwwlogs/xm.zlck888.com.log 2>/dev/null | tail -n 200
```

正常结果：
- 没有输出
- 或只有你自己巡检时的访问

异常结果：
- 有人访问这些危险路径
- 尤其是 `POST`

处理动作：
- 记录来源 IP、时间、路径
- 继续查最近 POST 和错误日志

### 5.4 最近 POST 请求排查

```bash
grep '"POST ' /www/wwwlogs/xm.zlck888.com.log 2>/dev/null | tail -n 200
```

正常结果：
- 正常业务登录、表单、接口提交

异常结果：
- POST 到 `upload`
- POST 到 `js`
- POST 到模板目录
- POST 到陌生 `.php`

处理动作：
- 记录对应路径和来源 IP
- 联合“5.3 木马访问痕迹”一起判断

### 5.5 站点最活跃来源 IP

```bash
awk '{print $1}' /www/wwwlogs/xm.zlck888.com.log 2>/dev/null | sort | uniq -c | sort -nr | head -20
```

正常结果：
- 主要是已知业务来源

异常结果：
- 陌生公网 IP 高频出现

处理动作：
- 再去访问日志里按该 IP 检索

按 IP 定向查看：

```bash
grep '可疑IP地址' /www/wwwlogs/xm.zlck888.com.log 2>/dev/null | tail -n 100
```

### 5.6 Nginx 错误日志

```bash
tail -n 200 /www/wwwlogs/xm.zlck888.com.error.log 2>/dev/null
```

正常结果：
- 少量普通 403/404

异常结果：
- 同一危险路径被频繁访问
- 某个陌生 IP 高频异常
- 出现异常 PHP 错误

处理动作：
- 记录时间、IP、路径
- 联合访问日志判断

### 5.7 BT 面板日志

```bash
find /www/server/panel/logs -type f 2>/dev/null | xargs tail -n 50 2>/dev/null
```

正常结果：
- 自己熟悉的登录和任务

异常结果：
- 陌生 IP 登录
- 异常时间点登录
- 未知操作记录

处理动作：
- 立即改 BT 面板密码
- 检查是否限制了登录 IP

---

## 6. 关键文件基线留档

### 6.1 记录关键文件哈希

```bash
md5sum "$site/index.php" "$site/ThinkPHP/ThinkPHP.php" "$site/app/Conf/config.php"
```

用途：
- 先记下当前正常状态的哈希
- 以后如果站点异常，再跑一次对比

判断：
- 如果哈希变化，而你没有主动修改，说明文件可能被改过

---

## 7. 异常时怎么处理

### 7.1 先留证，不要急删

```bash
date_tag=$(date +%F_%H%M%S)
hold=/root/xm_incident_$date_tag
mkdir -p "$hold"
```

### 7.2 处理顺序

发现异常后，按这个顺序：

1. 保留异常命令输出
2. 查看可疑文件前 120 行
3. 复制相关日志片段
4. 再隔离文件

### 7.3 隔离可疑文件

```bash
mv 可疑文件完整路径 "$hold/" 2>/dev/null
```

说明：
- 不建议第一时间 `rm -f`
- 优先 `mv` 到隔离目录

### 7.4 清理运行缓存

```bash
rm -rf "$site/app/Runtime/"*
mkdir -p "$site/app/Runtime"
chown -R www:www "$site/app/Runtime"
```

### 7.5 重载 Nginx

```bash
nginx -t && nginx -s reload
```

### 7.6 异常后复查

```bash
curl -s "http://xm.zlck888.com/" | grep -E "tdcqt|xk.js|String.fromCharCode|unicodeCodePoints|星空|开云"
curl -s "http://xm.zlck888.com/index.php?m=Country&a=sign_in&role=0" | grep -E "盟本级管理员登录|用户名|验证码|tdcqt|xk.js|String.fromCharCode|星空|开云"
curl -s -D - -o /tmp/country_verify.out "http://xm.zlck888.com/index.php?m=Country&a=verify&t=$(date +%s)" | grep -i content-type
find "$site/upload" "$site/uploads" "$site/img" "$site/js" "$site/excel" "$site/ueditor/php/upload" -type f -name "*.php" -print 2>/dev/null
```

---

## 8. 当前已确认的高危文件名

以下文件此前已确认为恶意或高风险：

- `ThinkPHP/ThinkPHP.php` 曾被篡改
- `deploy/ad-deny.php`
- `inc/cssjs.php`
- `js/jquery-1.10.2.min.php`
- `app/Tpl/Home/zakst.php`
- `app/Tpl.bak_20260519/Home/zakst.php`

如果这些文件重新出现，应直接按高危事件处理。

---

## 9. 值班最短版

如果时间紧，只执行这 4 条：

```bash
site=/www/wwwroot/xm.zlck888.com
curl -s "http://xm.zlck888.com/" | grep -E "tdcqt|xk.js|String.fromCharCode|unicodeCodePoints|星空|开云"
curl -s "http://xm.zlck888.com/index.php?m=Country&a=sign_in&role=0" | grep -E "盟本级管理员登录|用户名|验证码|tdcqt|xk.js|String.fromCharCode|星空|开云"
curl -s -D - -o /tmp/country_verify.out "http://xm.zlck888.com/index.php?m=Country&a=verify&t=$(date +%s)" | grep -i content-type
find "$site/upload" "$site/uploads" "$site/img" "$site/js" "$site/excel" "$site/ueditor/php/upload" -type f -name "*.php" -print 2>/dev/null
```

最短判定标准：
- 第 1 条：必须无输出
- 第 2 条：必须看到 `盟本级管理员登录`、`用户名`、`验证码`
- 第 3 条：必须是 `image/png`
- 第 4 条：必须无输出

只要有一条不满足，就进入异常处理流程。

---

## 10. 建议保留的应急资产

不要急着删：
- `/root/xm_postfix_*`
- `/root/xm_incident_*`
- 本次干净备份包
- 已标记的脏备份目录

这些内容可以用于：
- 回溯
- 对比
- 后续安全分析

