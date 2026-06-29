# 邮箱 SMTP 配置教程

## 可以用 163 或 QQ 个人邮箱吗

可以。系统使用标准 SMTP 发信，163、QQ、腾讯企业邮箱、阿里企业邮箱、网易企业邮箱都能配置。

但生产系统更推荐使用单位域名的企业邮箱，例如 `noreply@your-domain.gov.cn` 或 `service@your-domain.com`。个人邮箱可以先用于测试和试运行，正式对外通知建议换企业邮箱，原因是送达率、可信度、封禁风险和审计归属都更好。

## 通用配置位置

使用超级管理员登录后台，进入：

`系统配置` -> `邮件 SMTP`

填写后保存，再到同页点击“测试发送”。如果系统启用了邮件队列，服务器还需要保持 queue worker 运行。

## 163 个人邮箱配置

1. 登录网页版 163 邮箱。
2. 进入 `设置` -> `POP3/SMTP/IMAP`。
3. 开启 `SMTP 服务`。
4. 按页面提示获取“客户端授权码”。注意不是邮箱登录密码。
5. 后台填写：

| 字段 | 填写 |
| --- | --- |
| Mailer | `smtp` |
| Host | `smtp.163.com` |
| Port | `465` |
| Encryption | `ssl` |
| Username | 完整 163 邮箱，例如 `example@163.com` |
| Password | 163 客户端授权码 |
| From Address | 同 Username |
| From Name | 阿拉善盟科技计划项目管理信息系统 |

如果 465 失败，可尝试 `Port=25` 且 `Encryption` 留空，但很多服务器会拦截 25 端口，不建议作为首选。

## QQ 个人邮箱配置

1. 登录网页版 QQ 邮箱。
2. 进入 `设置` -> `账号`。
3. 找到 `POP3/IMAP/SMTP/Exchange/CardDAV/CalDAV 服务`。
4. 开启 `POP3/SMTP 服务` 或 `IMAP/SMTP 服务`。
5. 按页面提示生成授权码。
6. 后台填写：

| 字段 | 填写 |
| --- | --- |
| Mailer | `smtp` |
| Host | `smtp.qq.com` |
| Port | `465` |
| Encryption | `ssl` |
| Username | 完整 QQ 邮箱，例如 `123456@qq.com` |
| Password | QQ 邮箱授权码 |
| From Address | 同 Username |
| From Name | 阿拉善盟科技计划项目管理信息系统 |

## 企业邮箱建议

正式上线建议使用企业邮箱：

- 腾讯企业邮箱：`smtp.exmail.qq.com`，端口 `465`，加密 `ssl`。
- 阿里企业邮箱：通常为 `smtp.qiye.aliyun.com` 或服务商提供的 SMTP 地址，端口 `465`，加密 `ssl`。
- 网易企业邮箱：通常为 `smtp.qiye.163.com`，端口 `465`，加密 `ssl`。

企业邮箱要让域名管理员配置 SPF、DKIM、DMARC，这三项会明显影响邮件是否进垃圾箱。

## 常见问题

- `535 Authentication failed`：大概率是密码填成邮箱登录密码了，应使用授权码。
- `Connection timed out`：服务器访问 SMTP 端口失败，检查安全组、防火墙、宝塔出站限制。
- 测试发送成功但找回密码收不到：检查邮件中心日志、队列 worker 是否常驻运行、垃圾箱。
- From Address 和 Username 不一致：个人邮箱通常不允许这样配置，企业邮箱按服务商规则决定。
