# 旧系统迁移准备说明

## “迁移准备”是什么

后台的“迁移准备”不是日常业务菜单，它是上线前后给管理员核对旧 ThinkPHP 系统数据迁移状态用的。

新系统可以先独立运行；旧系统保持只读。迁移准备主要回答三件事：

1. 旧库、旧附件、旧字段能不能被识别。
2. 有哪些旧数据能导入到新系统，哪些需要人工处理。
3. 真正执行迁移后，管理员怎么抽样验收数据。

## 什么时候需要迁移

需要把旧系统历史数据带到新系统时才需要迁移，例如历史项目、历史附件、通知下载资料、单位账号等。

如果只是新系统从今天开始使用，可以暂时不执行历史迁移，只保留旧系统只读查询。

## 推荐迁移步骤

1. 备份旧系统数据库。
   - 导出旧 ThinkPHP 数据库 SQL。
   - 记录数据库字符集，优先保持 `utf8` 或 `utf8mb4`。

2. 备份旧系统附件。
   - 通常是旧站点 `/upload` 目录。
   - 保持原目录结构，不要只拷贝单个文件。

3. 上传迁移材料到服务器临时目录。
   - 建议 SQL 放到 `/www/backup/nxm-legacy/legacy.sql`。
   - 附件放到 `/www/backup/nxm-legacy/upload`。

4. 先执行 dry-run。
   - dry-run 只生成统计和问题清单，不写入正式业务表。
   - 核对单位、项目、附件、下载文件、缺失文件、无法映射字段。

5. 处理异常。
   - 缺文件：从旧服务器补齐，或确认不迁附件。
   - 单位重名：确认合并规则。
   - 账号冲突：确认使用旧账号、改名，还是只迁项目不迁账号。
   - 字段无法映射：确认放入备注/metadata，还是放弃。

6. 执行正式迁移。
   - 迁移前再次备份新系统数据库。
   - 迁移期间建议暂停新系统写入，避免同一批数据重复处理。

7. 抽样验收。
   - 抽查项目基础信息。
   - 抽查附件能否下载。
   - 抽查通知公告、资料下载是否正确展示。
   - 抽查单位和账号状态是否符合预期。

8. 旧系统归档。
   - 迁移完成后旧系统继续只读保留一段时间。
   - 确认无问题后再做归档备份。

## 首页资料下载迁移

旧库 `pro_cms.kind=1` 会映射为通知公告。

旧库 `pro_cms.kind=3` 会映射为资料下载，并尝试复制 `/upload/{content}` 文件。

如果旧文件不存在，新系统会把这条下载导入为 inactive，并记录 warning，避免首页出现无法下载的公开链接。

## 常用命令示例

以下命令在服务器项目根目录执行：

```bash
cd /www/wwwroot/nxm.zlck888.com/current/backend

/www/server/php/83/bin/php artisan legacy:import-public-home \
  /www/backup/nxm-legacy/legacy.sql \
  --upload-root=/www/backup/nxm-legacy/upload
```

确认 dry-run 输出无严重问题后，再执行：

```bash
cd /www/wwwroot/nxm.zlck888.com/current/backend

/www/server/php/83/bin/php artisan legacy:import-public-home \
  /www/backup/nxm-legacy/legacy.sql \
  --upload-root=/www/backup/nxm-legacy/upload \
  --execute
```

如果要迁移更完整的历史项目数据，先在后台“迁移准备”查看 readiness 报告，再按报告逐项处理。
