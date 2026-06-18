# xm.zlck888.com 服务器全盘排查与加固手册

适用对象：
- 已处理过站点木马
- 需要继续排查整台服务器是否还有残留后门
- 需要做服务器级加固

适用时间基线：
- `2026-05-24` 站点业务已恢复正常
- 当前需要做的是“全盘排查 + 持续加固”

---

## 1. 先明确一个结论

像这类木马，**只清站点文件不等于整台服务器已经绝对干净**。

攻击者可能残留的位置通常分 5 类：
- 站点目录内的 PHP 后门、上传木马、模板写文件后门
- 计划任务（crontab）里的回写脚本
- 开机启动项、systemd 服务、rc.local 里的持久化脚本
- 面板、FTP、数据库、后台账号等弱口令入口
- 系统临时目录、`.ssh`、用户家目录、日志目录中的落地脚本

所以排查一定要分层做：
- 第一层：站点目录排查
- 第二层：服务器持久化排查
- 第三层：账户与入口排查
- 第四层：监听端口与服务排查
- 第五层：加固与监控

---

## 2. 排查前原则

### 2.1 不要直接删除
先看、先记、先隔离。

### 2.2 建一个隔离目录

```bash
date_tag=$(date +%F_%H%M%S)
hold=/root/server_audit_$date_tag
mkdir -p "$hold"
```

用途：
- 保存可疑文件
- 保存异常日志输出
- 便于后续回溯

### 2.3 先设置站点变量

```bash
site=/www/wwwroot/xm.zlck888.com
```

---

## 3. 第一层：站点目录排查

目标：确认 `xm.zlck888.com` 站点内没有明显残留后门、异常 PHP、危险副本。

### 3.1 查高风险目录中的 PHP

```bash
find "$site/upload" "$site/uploads" "$site/img" "$site/js" "$site/excel" "$site/ueditor/php/upload" -type f -name "*.php" -print 2>/dev/null
```

正常：
- 没有输出

异常：
- 只要出现 `.php` 就要查

下一步：

```bash
sed -n '1,120p' 可疑文件完整路径
```

### 3.2 查危险函数

```bash
grep -RIn --include='*.php' "file_put_contents|move_uploaded_file|base64_decode|eval[[:space:]]*\(|assert[[:space:]]*\(|system[[:space:]]*\(|shell_exec[[:space:]]*\(" "$site" 2>/dev/null
```

正常：
- 没有输出，或命中的是你已知正常业务库

异常：
- 模板目录、公共目录、js 目录、上传目录里出现这些函数
- 新文件、怪文件名出现这些函数

### 3.3 查可疑文件名

```bash
find "$site" -type f \( -name "zakst.php" -o -name "ad-deny.php" -o -name "cssjs.php" -o -name "jquery-1.10.2.min.php" -o -name "*-1.php" -o -name "*_1.php" -o -name "*.phtml" -o -name "*.phar" \) -print 2>/dev/null
```

正常：
- 不应再出现已确认清理过的高危文件

异常：
- 重新出现即高危

### 3.4 查站点中最近新增/改动文件

```bash
find "$site" -type f -mmin -1440 -printf '%TY-%Tm-%Td %TH:%TM:%TS %p\n' 2>/dev/null | sort
```

说明：
- `-1440` 表示近 24 小时
- 可改成 `-4320` 查近 3 天

正常：
- 基本都是你自己刚修改过的文件

异常：
- 出现陌生 PHP 文件
- 出现模板、js、上传目录里的异常改动

### 3.5 查备份副本和多余文件

```bash
find "$site" -maxdepth 4 \( -name "*.bak" -o -name "*.old" -o -name "*.tmp" -o -name "*.swp" -o -name "*bak*" -o -name "*backup*" -o -name "*-1.php" -o -name "*_1.php" \) -print 2>/dev/null
```

正常：
- 生产站点里这类文件越少越好

异常：
- 备份副本、旧版本、测试副本大量存在

处理建议：
- 能移出 web 根目录的就移出
- 不必在线暴露的就隔离

---

## 4. 第二层：服务器持久化排查

目标：排查有没有计划任务、启动项、systemd、临时目录落地脚本等回写机制。

### 4.1 查 root 和常见用户计划任务

```bash
crontab -l 2>/dev/null
crontab -u root -l 2>/dev/null
crontab -u www -l 2>/dev/null
crontab -u nginx -l 2>/dev/null
crontab -u apache -l 2>/dev/null
```

正常：
- 你认识的证书续签、监控、备份、面板任务

异常：
- 指向陌生脚本
- 指向 `/tmp`、`/dev/shm`、`/var/tmp`
- 使用 `curl|bash`、`wget|sh`
- 频率极高且用途不明

### 4.2 查系统计划任务文件

```bash
find /etc/cron* /var/spool/cron -type f -print 2>/dev/null
```

然后可疑时查看内容：

```bash
sed -n '1,120p' 可疑计划任务文件
```

### 4.3 查 systemd 开机自启服务

```bash
systemctl list-unit-files --type=service --state=enabled 2>/dev/null
```

正常：
- 常见系统服务、Nginx、MySQL、BT 面板等

异常：
- 名字陌生
- 指向脚本型服务
- 明显不是你部署过的服务

查看具体定义：

```bash
systemctl cat 可疑服务名
```

### 4.4 查 rc.local / 开机脚本

```bash
sed -n '1,200p' /etc/rc.local 2>/dev/null
sed -n '1,200p' /etc/rc.d/rc.local 2>/dev/null
```

正常：
- 空白或已知合法命令

异常：
- 自动下载执行
- 指向 `/tmp`、`/dev/shm`、陌生脚本

### 4.5 查临时目录落地脚本

```bash
find /tmp /var/tmp /dev/shm -maxdepth 3 -type f \( -name "*.sh" -o -name "*.php" -o -name "*.py" -o -name "*.pl" -o -perm -111 \) -print 2>/dev/null
```

正常：
- 临时目录里不应长期存在陌生脚本

异常：
- 可执行脚本
- 文件名随机
- 带网络下载、解码、回写逻辑

---

## 5. 第三层：账户与入口排查

目标：确认没有异常账户、异常公钥、弱入口。

### 5.1 查本机用户

```bash
awk -F: '{print $1 ":" $3 ":" $7}' /etc/passwd
```

重点看：
- UID 为 `0` 的账号
- Shell 为可登录 shell 的陌生账号

更聚焦一点：

```bash
awk -F: '$3==0 || $3>=1000 {print $1 ":" $3 ":" $7}' /etc/passwd
```

正常：
- 只有你认识的账号

异常：
- 陌生管理员账号
- 陌生可登录账号

### 5.2 查 root 和用户 SSH 公钥

```bash
ls -al /root/.ssh 2>/dev/null
cat /root/.ssh/authorized_keys 2>/dev/null
find /home -maxdepth 3 -name authorized_keys -print 2>/dev/null
```

正常：
- 只有你自己认可的公钥

异常：
- 陌生公钥
- 你没加过的授权键

### 5.3 查系统认证日志

```bash
grep -E "Accepted|Failed password|Invalid user|authentication failure" /var/log/secure* 2>/dev/null | tail -n 200
```

正常：
- 没有陌生成功登录

异常：
- 大量 `Failed password`
- 陌生 IP 成功登录

### 5.4 查 BT 面板日志

```bash
find /www/server/panel/logs -type f 2>/dev/null | xargs tail -n 50 2>/dev/null
```

正常：
- 你自己能对上的登录和操作

异常：
- 陌生 IP 登录
- 异常时间的敏感操作

### 5.5 FTP 排查

如果已禁用 FTP，可确认：

```bash
ss -lntp | grep ':21'
```

正常：
- 没有输出

异常：
- 还在监听 21 端口

---

## 6. 第四层：监听端口与服务排查

目标：确认没有陌生端口、异常监听进程。

### 6.1 查看监听端口

```bash
ss -lntp
```

重点看：
- `80/443`：Nginx
- `3306`：MySQL
- `8888` 或 BT 自定义端口：面板
- 其他陌生高位端口

正常：
- 都是你认识的服务

异常：
- 进程名陌生
- 高危端口对公网暴露

### 6.2 查看进程

```bash
ps -ef | grep -v grep | grep -E "python|php|perl|bash|sh|curl|wget|nc|socat"
```

正常：
- 你认识的面板、Nginx、PHP、系统服务

异常：
- 进程命令行可疑
- 指向 `/tmp`、`/dev/shm`
- 带下载、反弹、监听特征

---

## 7. 第五层：日志定向排查

目标：找到谁访问过木马、谁在扫你、有没有异常 POST。

### 7.1 木马文件访问痕迹

```bash
grep -Ei "zakst\.php|ad-deny\.php|cssjs\.php|jquery-1\.10\.2\.min\.php|upload.*\.php|js/.*\.php" /www/wwwlogs/xm.zlck888.com.log 2>/dev/null | tail -n 200
```

正常：
- 没有输出
- 或只有你自己排查时的访问

异常：
- 陌生 IP 访问这些路径
- 尤其是 `POST`

### 7.2 最近 POST 请求

```bash
grep '"POST ' /www/wwwlogs/xm.zlck888.com.log 2>/dev/null | tail -n 200
```

正常：
- 正常业务提交

异常：
- POST 到陌生 `.php`
- POST 到 `upload`、`js`、模板目录

### 7.3 活跃来源 IP

```bash
awk '{print $1}' /www/wwwlogs/xm.zlck888.com.log 2>/dev/null | sort | uniq -c | sort -nr | head -20
```

正常：
- 常见业务来源

异常：
- 陌生公网 IP 高频出现

定向看某个 IP：

```bash
grep '可疑IP地址' /www/wwwlogs/xm.zlck888.com.log 2>/dev/null | tail -n 100
```

### 7.4 错误日志

```bash
tail -n 200 /www/wwwlogs/xm.zlck888.com.error.log 2>/dev/null
```

正常：
- 少量普通 403/404

异常：
- 同一异常路径被反复访问
- 同一 IP 高频异常

---

## 8. 加固措施

下面这些不是排查，是必须落实的加固动作。

### 8.1 入口收口
- 禁用 FTP
- SSH 如恢复，只允许密钥登录并限制 IP
- BT 面板限制 IP、开启二次验证
- 关闭不用的服务和插件

### 8.2 权限收口
- 代码目录所有权：`root:root`
- 仅保留必要写目录给 `www:www`
- 关键文件继续使用 `chattr +i`

### 8.3 Web 层收口
- 上传目录禁 PHP 执行
- 静态目录禁 PHP 执行
- 不暴露测试文件、备份副本、旧版本目录

### 8.4 防篡改配置
- 开启企业防篡改
- 白名单只保留真正需要写入的目录：
  - `app/Runtime`
  - `upload`
  - `uploads`
  - `excel`
  - `ueditor/php/upload`

### 8.5 凭据收口
- 立即更换：
  - BT 面板密码
  - 数据库密码
  - 后台管理员密码
  - FTP 历史密码
  - SSH 密钥（若后续恢复）

### 8.6 备份策略
- 已污染备份明确标记 `DIRTY_DO_NOT_RESTORE`
- 保留本次干净备份
- 恢复优先使用：
  - 可信源码
  - 数据库
  - 已核验的上传附件

---

## 9. 异常时统一处理流程

### 9.1 建异常目录

```bash
date_tag=$(date +%F_%H%M%S)
hold=/root/server_incident_$date_tag
mkdir -p "$hold"
```

### 9.2 统一动作
发现异常后，按顺序做：

1. 保存命令输出
2. 查看可疑文件前 120 行
3. 保存相关日志
4. 再隔离文件

### 9.3 隔离可疑文件

```bash
mv 可疑文件完整路径 "$hold/" 2>/dev/null
```

### 9.4 清缓存与重载

```bash
rm -rf "$site/app/Runtime/"*
mkdir -p "$site/app/Runtime"
chown -R www:www "$site/app/Runtime"
nginx -t && nginx -s reload
```

### 9.5 异常后复检

```bash
curl -s "http://xm.zlck888.com/" | grep -E "tdcqt|xk.js|String.fromCharCode|unicodeCodePoints|星空|开云"
curl -s "http://xm.zlck888.com/index.php?m=Country&a=sign_in&role=0" | grep -E "盟本级管理员登录|用户名|验证码|tdcqt|xk.js|String.fromCharCode|星空|开云"
curl -s -D - -o /tmp/country_verify.out "http://xm.zlck888.com/index.php?m=Country&a=verify&t=$(date +%s)" | grep -i content-type
find "$site/upload" "$site/uploads" "$site/img" "$site/js" "$site/excel" "$site/ueditor/php/upload" -type f -name "*.php" -print 2>/dev/null
```

---

## 10. 当前建议的长期策略

### 10.1 短期
- 连续巡检 `7-14` 天
- 每天检查首页、登录页、验证码、高风险目录
- 日志里重点看陌生 POST 和异常 IP

### 10.2 中期
- 做一轮整机账号、服务、启动项清理
- 清掉生产环境中的旧备份、副本、测试文件

### 10.3 长期
- 计划迁移到新机器重建
- 新机器只迁：
  - 干净源码
  - 数据库
  - 已检查过的上传附件

原因：
- 当前机器虽然已恢复稳定，但重建迁移仍然是最彻底的根治方案

