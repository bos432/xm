# 本站 OSS 隔离恢复演练 Runbook

适用范围：`nxm.zlck888.com` 的 MySQL 与私有上传备份。目标是在验证 OSS 归档可下载、可解压、可导入的同时，绝不覆盖生产数据库或生产上传目录。

## 不可违反的边界

- 禁止把 dump 导入生产数据库，禁止覆盖 `current` 或 `shared/storage/app/private`。
- 禁止为生产应用数据库用户授予全局 `CREATE`、`DROP`、`FILE`、`SUPER` 或任意建库权限。
- 使用单独临时 MySQL 实例，或 DBA 预先创建的唯一临时库，例如 `nxm_restore_verify_YYYYMMDD`；权限仅授予该库。
- 临时文件放在本站目录之外、权限 `0700` 的临时目录；凭据通过交互式安全提示或 MySQL login-path 提供，不放命令行参数/历史记录/报告。
- 执行窗口由 DBA/运维协调。确认 CPU、磁盘 I/O 和可用空间后再下载；达到资源阈值立即停止，不影响生产服务。
- 只恢复到隔离目标。完成抽查后由 DBA 撤销临时账号权限并销毁临时库/实例；临时目录中的恢复数据按组织保留策略安全清除。

## 预检

1. 在后台确认 OSS 已配置有效；只核对遮罩状态，不导出 AccessKey。
2. 从本站备份日志确认最近存在 `Uploaded and verified 2 OSS backup objects.`，记录时间戳与对象键（对象键不含密钥）。
3. DBA 提供隔离目标地址、临时库名、短期账号和有效期。账号只允许连接隔离实例/库。
4. 检查隔离目标版本兼容性、剩余空间和网络访问。预计空间至少为压缩归档及其解压后数据的 2 倍；只读取压缩文件大小，不打印内容。
5. 记录变更单、执行人、审批人、开始/结束时间和清理负责人。

## 下载与文件校验

1. 使用后台认可的 OSS 客户端或临时 RAM 身份，仅下载对应本站前缀下的一组数据库与私有文件归档；禁止列出/下载其他 bucket 或前缀。
2. 在临时目录设置 `umask 077`，下载后核对对象长度/ETag 与 OSS 元数据。
3. 执行 `gzip -t <database.sql.gz>` 与 `gzip -t <private-files.tar.gz>`。
4. 仅列出私有归档成员名：`tar -tzf <private-files.tar.gz>`；拒绝绝对路径、`..` 路径、符号链接逃逸及本站目录以外路径。不要把文件名清单或文件内容放入公开报告。
5. 解压到空的隔离目录，禁止使用 tar 的绝对路径恢复选项。统计文件数和总字节数，与归档元数据做合理性核对。

## 数据库恢复

1. 将 gzip SQL 流导入隔离库，先校验 dump 中的 `CREATE TABLE` 目标仅指向预期 schema；若 dump 包含生产 schema 名或 `CREATE/DROP DATABASE`，停止并由 DBA 生成针对隔离库的安全转换副本。
2. 若合法外键的被引用表创建顺序与 dump 顺序不同，只能在本次隔离连接/导入会话关闭外键检查（如 MySQL/MariaDB session `FOREIGN_KEY_CHECKS=0`）后导入；导入完成后必须在新的校验会话重新开启检查，并核对 `information_schema` 外键约束数量/目标完整。不得用关闭外键检查掩盖非法或缺失引用。
3. 导入前后记录表数量；确认 Laravel migrations 表存在且能只读查询。
4. 执行只读抽查：核心表存在、行数非零/合理、关键外键引用可关联、抽样记录时间范围合理。不要导出人员身份、密码哈希、token、附件内容或业务敏感字段。
5. 不在隔离副本运行 Seeder、队列、邮件、OSS 写入、定时任务或外部回调。必要时关闭网络出口或使用只读应用配置。

## 验收与清理

- 通过标准：两对象均下载完整；gzip/tar 校验通过；私有归档安全解压；隔离库导入成功；核心表/迁移状态与基础关系抽查通过；无连接生产数据库或生产目录的证据。
- 失败时：保留错误码/脱敏日志和校验阶段，不保留 SQL、归档内容或密钥；修复隔离环境后重新执行。
- 完成后：销毁临时库/实例、撤销短期权限、删除临时下载/解压副本，确认没有后台进程或挂载残留。
- 在 QA 记录中只记对象数量/时间、压缩长度、校验结果、表数量、抽查结果、临时目标销毁证明及执行人，不记录 Secret、用户 PII 或 SQL 内容。

当前已知阻断：生产 MySQL 账号没有建隔离数据库的权限；未取得 DBA 隔离实例/临时库与限时授权前，不运行数据库恢复演练。

## QA46 只读归档检查工具

新增 `backend/tests/Operations/restore_archive_safety.py`，仅依赖 Python 标准库；不连接数据库、不解压、不输出成员名称或内容。运行前确认服务器已有 Python3，不为此安装或升级共享运行时。

```sh
python3 backend/tests/Operations/restore_archive_safety.py /approved/private/path/nxm-private-files-TIMESTAMP.tar.gz
```

成功输出 JSON 数量统计并退出0；拒绝时退出2。默认上限：压缩32MiB、全部解压字节256MiB、单文件64MiB、成员10000、路径深度64。完整读取 gzip 校验 CRC，再验证 tar 成员；拒绝路径穿越、绝对路径、链接、设备、FIFO、稀疏文件、重复路径和文件/父目录冲突。超过默认上限须单独评估资源，禁止为通过检查盲目放宽。

本地验证：`python -B -m unittest discover -s modernization/backend/tests/Operations -p test_restore_archive_safety.py -v`，12项通过，完整输出见 `qa46-archive-safety-20261105.json`。仅证明合成归档检查行为；未读取真实备份，未完成 SQL 检查、导入、安全解压、资源隔离或清理验证。执行恢复时仍必须遵循前述隔离边界。

## QA47 SQL 转储只读扫描

扫描同一备份组的数据库对象时：

```sh
python3 backend/tests/Operations/restore_archive_safety.py --kind database /approved/private/path/nxm-database-TIMESTAMP.sql.gz
```

读取采用64KiB gzip分块；默认限制压缩32MiB、展开256MiB、单行1MiB、单语句256KiB。拒绝 `USE`、建删库/账号/角色/事件、权限授予撤销、全局/持久配置、server plugin、文件系统导入导出、存储过程调用、mysql client 命令、跨库对象引用和坏 gzip；MySQL `/*!...*/` 执行注释按可执行 SQL 检查。只输出语句数及展开字节数，不输出 SQL、表名或业务值。生产 `mysqldump` 使用 `--routines --triggers`，所以扫描器也必须允许合法 `DEFINER` routine/trigger 语法，而不允许调用或启用 scheduled event。

这是针对本站 `mysqldump` 输出形状的静态拒绝扫描，不是完整 MySQL 解析器，也不证明 SQL 语义、导入兼容性或业务一致性。扫描通过后仍需在唯一隔离实例导入并检查；任何拒绝、超过默认限制、非预期语法都应停止并由 DBA 审查，不要跳过或直接执行。合成测试21项全绿，完整证据 `qa47-restore-input-safety-20261105.json`；真实 SQL 备份尚未扫描。

QA47b 使用现存 loopback-only MySQL QA 容器的 migration-test schema，命令为 `docker exec -e MYSQL_PWD nxm-qa-mysql57-20261105 mysqldump --user=root --no-data --routines --triggers modernization_migration_test`。容器 label 必须是 `nxm.qa.scope=isolated-concurrency`，3306 仅映射 `127.0.0.1:13371`。实际输出退出0、223 statements、57737 expanded bytes，扫描通过；压缩临时文件立即删除。不导出数据行，不执行导出 SQL，不读生产数据库。此证明只覆盖小型 QA schema 的 dump 语法，不代表生产归档大小、内容或恢复成功。

QA45资源预检只确认 systemd-run 二进制存在；较早现场记录明确该主机的 transient unit 执行本站程序失败（SIGSEGV/203:EXEC）。不得把“命令可用”当成资源限制有效。需重新验证可用的隔离机制（例如已安装、已运行且已具备 MySQL 镜像的 Docker，需检查 daemon、镜像和实际 cgroup 限制）；不得拉取镜像、启动容器或创建数据库直到只读检查证明CPU/内存/时间上限有效。若没有可证明的资源隔离方案，本次服务器恢复演练停止，不在共享主机裸跑额外 mysqld。
