<template>
  <section class="page-stack">
    <el-alert
      :title="texts.t('migration.intro', '迁移准备用于旧系统历史数据导入前体检：先备份旧库和 upload 附件，生成 dry-run 报告，处理缺失文件/字段映射/账号冲突后，再执行正式迁移。新系统日常使用不依赖这里。')"
      type="info"
      show-icon
      :closable="false"
    />

    <el-card shadow="never">
      <template #header>旧新并行状态</template>
      <div class="migration-summary">
        <el-tag type="warning">{{ readiness.mode || 'legacy_new_parallel' }}</el-tag>
        <el-tag :type="readiness.write_cutover_ready ? 'success' : 'danger'">
          写入切换：{{ readiness.write_cutover_ready ? '可切换' : '未就绪' }}
        </el-tag>
        <el-tag v-if="readiness.migration_go_live_gate" :type="readinessStatusType(readiness.migration_go_live_gate.overall_status)">
          总闸门 {{ readiness.migration_go_live_gate.overall_status }}
        </el-tag>
        <el-tag v-if="readiness.migration_go_live_gate" :type="readiness.migration_go_live_gate.summary?.blockers ? 'danger' : 'info'">
          {{ readiness.migration_go_live_gate.summary?.blockers || 0 }} 个 blocker
        </el-tag>
        <span v-if="readiness.migration_go_live_gate">下一步：{{ nextStepTitle(readiness.migration_go_live_gate.next_step) }}</span>
      </div>
    </el-card>

    <el-card shadow="never">
      <template #header>报告文件</template>
      <el-table :data="readiness.items || []" border v-loading="loading">
        <el-table-column prop="key" label="项目" width="220" />
        <el-table-column prop="path" label="路径" min-width="360" />
        <el-table-column label="状态" width="120">
          <template #default="{ row }">
            <el-tag :type="row.exists ? 'success' : 'danger'">{{ row.exists ? '存在' : '缺失' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="updated_at" label="更新时间" width="220" />
      </el-table>
    </el-card>

    <el-card shadow="never">
      <template #header>迁移就绪总览</template>
      <el-alert v-if="!readiness.migration_readiness_summary" title="尚未生成 legacy-migration-readiness-summary.json，请先运行 scripts/New-LegacyMigrationReadinessSummary.ps1。" type="info" show-icon :closable="false" />
      <template v-else>
        <div class="preview-summary">
          <el-tag :type="readinessStatusType(readiness.migration_readiness_summary.overall_status)">
            {{ readiness.migration_readiness_summary.overall_status }}
          </el-tag>
          <el-tag type="success">{{ readiness.migration_readiness_summary.summary?.pass || 0 }} 项通过</el-tag>
          <el-tag type="warning">{{ readiness.migration_readiness_summary.summary?.waiting || 0 }} 项等待</el-tag>
          <el-tag type="danger">{{ readiness.migration_readiness_summary.summary?.blocked || 0 }} 项阻断</el-tag>
          <el-tag type="info">{{ readiness.migration_readiness_summary.summary?.missing || 0 }} 项缺失</el-tag>
        </div>
        <el-table :data="readiness.migration_readiness_summary.gates || []" border>
          <el-table-column prop="label" label="检查项" min-width="180" />
          <el-table-column label="状态" width="120">
            <template #default="{ row }">
              <el-tag :type="readinessStatusType(row.status)">{{ row.status }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column label="告警" min-width="260">
            <template #default="{ row }">{{ (row.warnings || []).join(', ') || '-' }}</template>
          </el-table-column>
        </el-table>
      </template>
    </el-card>

    <el-card shadow="never">
      <template #header>批次导入计划</template>
      <el-alert v-if="!readiness.migration_batch_plan" title="尚未生成 legacy-migration-batch-plan.json，请先运行 scripts/New-LegacyMigrationBatchPlan.ps1。" type="info" show-icon :closable="false" />
      <template v-else>
        <div class="preview-summary">
          <el-tag :type="readinessStatusType(readiness.migration_batch_plan.overall_status)">
            {{ readiness.migration_batch_plan.overall_status }}
          </el-tag>
          <el-tag type="success">{{ readiness.migration_batch_plan.summary?.ready_stages || 0 }} 阶段 ready</el-tag>
          <el-tag type="warning">{{ readiness.migration_batch_plan.summary?.waiting_stages || 0 }} 阶段等待</el-tag>
          <el-tag type="danger">{{ readiness.migration_batch_plan.summary?.blocked_stages || 0 }} 阶段阻断</el-tag>
        </div>
        <el-table :data="readiness.migration_batch_plan.stages || []" border>
          <el-table-column prop="order" label="#" width="60" />
          <el-table-column prop="label" label="阶段" min-width="150" />
          <el-table-column prop="target" label="目标" min-width="150" />
          <el-table-column label="状态" width="110">
            <template #default="{ row }">
              <el-tag :type="readinessStatusType(row.status)">{{ row.status }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="planned_count" label="计划" width="90" />
          <el-table-column prop="ready_count" label="可执行" width="90" />
          <el-table-column prop="waiting_count" label="等待" width="90" />
          <el-table-column prop="blocked_count" label="阻断" width="90" />
          <el-table-column label="前置依赖" min-width="180">
            <template #default="{ row }">{{ (row.dependencies || []).join(', ') || '-' }}</template>
          </el-table-column>
          <el-table-column label="告警" min-width="220">
            <template #default="{ row }">{{ (row.warnings || []).join(', ') || '-' }}</template>
          </el-table-column>
        </el-table>
        <el-divider content-position="left">批次表记录预览</el-divider>
        <el-alert v-if="!readiness.migration_batch_db_dry_run" title="尚未生成 legacy-migration-batch-db-dry-run.json，请先运行 scripts/New-LegacyMigrationBatchDbDryRun.ps1。" type="info" show-icon :closable="false" />
        <template v-else>
          <div class="preview-summary">
            <el-tag type="info">{{ readiness.migration_batch_db_dry_run.summary?.batch_count || 0 }} 个批次</el-tag>
            <el-tag type="success">{{ readiness.migration_batch_db_dry_run.summary?.ready_items || 0 }} 项 ready</el-tag>
            <el-tag type="warning">{{ readiness.migration_batch_db_dry_run.summary?.pending_items || 0 }} 项 pending</el-tag>
            <el-tag type="danger">{{ readiness.migration_batch_db_dry_run.summary?.blocked_items || 0 }} 项 blocked</el-tag>
          </div>
          <el-table :data="readiness.migration_batch_db_dry_run.items || []" border class="preview-section-table">
            <el-table-column prop="legacy_table" label="阶段键" min-width="150" />
            <el-table-column prop="target_table" label="目标" min-width="160" />
            <el-table-column prop="status" label="状态" width="110" />
            <el-table-column prop="estimated_row_count" label="预计行数" width="110" />
            <el-table-column prop="warning_count" label="告警数" width="90" />
          </el-table>
        </template>
        <el-divider content-position="left">记录导入计划</el-divider>
        <el-alert v-if="!readiness.record_import_plan" title="尚未生成 legacy-record-import-plan.json，请先运行 scripts/New-LegacyRecordImportPlan.ps1。" type="info" show-icon :closable="false" />
        <template v-else>
          <div class="preview-summary">
            <el-tag type="info">{{ readiness.record_import_plan.summary?.planned_records || 0 }} 条计划</el-tag>
            <el-tag type="success">{{ readiness.record_import_plan.summary?.ready_records || 0 }} 条 ready</el-tag>
            <el-tag :type="readiness.record_import_plan.summary?.blocked_records ? 'danger' : 'info'">
              {{ readiness.record_import_plan.summary?.blocked_records || 0 }} 条 blocked
            </el-tag>
            <el-tag type="warning">{{ readiness.record_import_plan.summary?.waiting_records || 0 }} 条 waiting</el-tag>
          </div>
          <div v-if="recordImportBlockerRows.length" class="preview-summary">
            <el-tag v-for="item in recordImportBlockerRows" :key="item.reason" type="danger">
              {{ blockerLabel(item.reason) }} {{ item.count }}
            </el-tag>
          </div>
          <el-table :data="readiness.record_import_plan.targets || []" border class="preview-section-table">
            <el-table-column prop="target" label="目标" min-width="150" />
            <el-table-column label="计划" width="90">
              <template #default="{ row }">{{ row.summary?.planned_records || 0 }}</template>
            </el-table-column>
            <el-table-column label="Ready" width="90">
              <template #default="{ row }">{{ row.summary?.ready_records || 0 }}</template>
            </el-table-column>
            <el-table-column label="Blocked" width="90">
              <template #default="{ row }">{{ row.summary?.blocked_records || 0 }}</template>
            </el-table-column>
            <el-table-column label="状态分布" min-width="260">
              <template #default="{ row }">{{ formatCounts(row.summary?.status_counts) }}</template>
            </el-table-column>
            <el-table-column label="阻断原因" min-width="320">
              <template #default="{ row }">{{ formatBlockerCounts(row.summary?.blocker_counts) }}</template>
            </el-table-column>
          </el-table>
          <el-table v-if="recordImportBlockedSamples.length" :data="recordImportBlockedSamples" border class="preview-section-table">
            <el-table-column prop="target" label="目标" width="140" />
            <el-table-column prop="target_table" label="表" width="150" />
            <el-table-column prop="status" label="状态" width="170" />
            <el-table-column label="定位" min-width="180">
              <template #default="{ row }">{{ formatLookup(row.lookup) }}</template>
            </el-table-column>
            <el-table-column label="磁盘/路径" min-width="260">
              <template #default="{ row }">{{ formatStorageSummary(row) }}</template>
            </el-table-column>
            <el-table-column label="阻断原因" min-width="280">
              <template #default="{ row }">{{ formatBlockers(row) }}</template>
            </el-table-column>
          </el-table>
        </template>
        <el-divider content-position="left">阻断处理清单</el-divider>
        <el-alert v-if="!readiness.migration_blocker_action_sheet" title="尚未生成 legacy-migration-blocker-action-sheet.json，请先运行 scripts/New-LegacyMigrationBlockerActionSheet.ps1。" type="info" show-icon :closable="false" />
        <template v-else>
          <div class="preview-summary">
            <el-tag :type="readinessStatusType(readiness.migration_blocker_action_sheet.overall_status)">
              {{ readiness.migration_blocker_action_sheet.overall_status }}
            </el-tag>
            <el-tag type="danger">{{ readiness.migration_blocker_action_sheet.summary?.blockers || 0 }} 个 blocker</el-tag>
            <el-tag type="warning">{{ readiness.migration_blocker_action_sheet.summary?.warnings || 0 }} 个 warning</el-tag>
            <el-tag type="info">{{ readiness.migration_blocker_action_sheet.summary?.affected_records || 0 }} 条受影响</el-tag>
            <el-tag :type="readinessStatusType(readiness.migration_blocker_action_sheet_validation?.overall_status)">
              校验 {{ readiness.migration_blocker_action_sheet_validation?.overall_status || 'missing' }}
            </el-tag>
            <el-tag :type="readiness.migration_blocker_action_sheet_validation?.summary?.missing_required_fields ? 'danger' : 'info'">
              缺字段 {{ readiness.migration_blocker_action_sheet_validation?.summary?.missing_required_fields || 0 }}
            </el-tag>
          </div>
          <el-table :data="readiness.migration_blocker_action_sheet.items || []" border class="preview-section-table">
            <el-table-column prop="key" label="事项" min-width="180" />
            <el-table-column label="级别" width="110">
              <template #default="{ row }">
                <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="owner" label="负责人" min-width="160" />
            <el-table-column prop="affected_count" label="影响数" width="90" />
            <el-table-column prop="action" label="处理动作" min-width="360" />
            <el-table-column prop="acceptance" label="验收标准" min-width="360" />
          </el-table>
          <el-table
            v-if="readiness.migration_blocker_action_sheet_validation?.issues?.length"
            :data="readiness.migration_blocker_action_sheet_validation.issues.slice(0, 10)"
            border
            class="preview-section-table"
          >
            <el-table-column prop="severity" label="级别" width="100">
              <template #default="{ row }">
                <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="field" label="字段" min-width="220" />
            <el-table-column prop="code" label="规则" min-width="220" />
            <el-table-column prop="message" label="说明" min-width="420" />
          </el-table>
        </template>
        <el-divider content-position="left">阻断处置包</el-divider>
        <el-alert v-if="!readiness.migration_blocker_resolution_pack" title="尚未生成 legacy-migration-blocker-resolution-pack.json，请先运行 scripts/New-LegacyMigrationBlockerResolutionPack.ps1。" type="info" show-icon :closable="false" />
        <template v-else>
          <div class="preview-summary">
            <el-tag :type="readinessStatusType(readiness.migration_blocker_resolution_pack.overall_status)">
              {{ readiness.migration_blocker_resolution_pack.overall_status }}
            </el-tag>
            <el-tag type="danger">{{ readiness.migration_blocker_resolution_pack.summary?.blocked_stages || 0 }} 个阻断阶段</el-tag>
            <el-tag type="info">{{ readiness.migration_blocker_resolution_pack.summary?.total_items || 0 }} 个处置项</el-tag>
            <el-tag :type="readinessStatusType(readiness.migration_blocker_resolution_pack_validation?.overall_status)">
              校验 {{ readiness.migration_blocker_resolution_pack_validation?.overall_status || 'missing' }}
            </el-tag>
            <el-tag :type="readiness.migration_blocker_resolution_pack_validation?.summary?.missing_required_fields ? 'danger' : 'info'">
              缺字段 {{ readiness.migration_blocker_resolution_pack_validation?.summary?.missing_required_fields || 0 }}
            </el-tag>
          </div>
          <el-table :data="readiness.migration_blocker_resolution_pack.items || []" border class="preview-section-table">
            <el-table-column prop="stage" label="阶段" min-width="150" />
            <el-table-column prop="owner" label="负责人" min-width="180" />
            <el-table-column prop="planned_count" label="计划" width="80" />
            <el-table-column prop="ready_count" label="可执行" width="90" />
            <el-table-column prop="waiting_count" label="等待" width="80" />
            <el-table-column prop="blocked_count" label="阻断" width="80" />
            <el-table-column label="允许动作" min-width="360">
              <template #default="{ row }">{{ (row.allowed_actions || []).join('；') || '-' }}</template>
            </el-table-column>
            <el-table-column label="禁止动作" min-width="360">
              <template #default="{ row }">{{ (row.forbidden_actions || []).join('；') || '-' }}</template>
            </el-table-column>
            <el-table-column label="验收检查" min-width="360">
              <template #default="{ row }">{{ (row.validation_checks || []).join('；') || '-' }}</template>
            </el-table-column>
            <el-table-column label="命令" min-width="420">
              <template #default="{ row }">{{ (row.manual_commands || []).join('；') || '-' }}</template>
            </el-table-column>
          </el-table>
          <el-table
            v-if="readiness.migration_blocker_resolution_pack_validation?.issues?.length"
            :data="readiness.migration_blocker_resolution_pack_validation.issues.slice(0, 10)"
            border
            class="preview-section-table"
          >
            <el-table-column prop="severity" label="级别" width="100">
              <template #default="{ row }">
                <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="field" label="字段" min-width="220" />
            <el-table-column prop="code" label="规则" min-width="220" />
            <el-table-column prop="message" label="说明" min-width="420" />
          </el-table>
          <div class="preview-summary">
            <el-tag :type="readinessStatusType(readiness.migration_blocker_resolution_operator_pack?.overall_status)">
              操作包 {{ readiness.migration_blocker_resolution_operator_pack?.overall_status || 'missing' }}
            </el-tag>
            <el-tag type="danger">{{ readiness.migration_blocker_resolution_operator_pack?.summary?.blocked_stages || 0 }} 个阻断阶段</el-tag>
            <el-tag type="warning">{{ readiness.migration_blocker_resolution_operator_pack?.summary?.pending_items || 0 }} 个 pending</el-tag>
            <el-tag type="info">{{ readiness.migration_blocker_resolution_operator_pack?.summary?.approved_items || 0 }} 个 approved</el-tag>
            <el-tag type="info">{{ readiness.migration_blocker_resolution_operator_pack?.summary?.executed_items || 0 }} 个 executed</el-tag>
            <el-tag type="success">{{ readiness.migration_blocker_resolution_operator_pack?.summary?.verified_items || 0 }} 个 verified</el-tag>
            <el-tag :type="readinessStatusType(readiness.migration_blocker_resolution_operator_pack_validation?.overall_status)">
              操作包校验 {{ readiness.migration_blocker_resolution_operator_pack_validation?.overall_status || 'missing' }}
            </el-tag>
          </div>
          <el-table :data="readiness.migration_blocker_resolution_operator_pack?.stages || []" border class="preview-section-table">
            <el-table-column prop="stage" label="阶段" min-width="150" />
            <el-table-column prop="signoff_status" label="签收状态" width="120">
              <template #default="{ row }">
                <el-tag :type="readinessStatusType(row.signoff_status)">{{ row.signoff_status }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="owner" label="负责人" min-width="180" />
            <el-table-column prop="blocked_count" label="阻断" width="80" />
            <el-table-column prop="approved_by" label="批准人" min-width="120" />
            <el-table-column prop="executed_by" label="执行人" min-width="120" />
            <el-table-column prop="verified_by" label="验证人" min-width="120" />
            <el-table-column prop="evidence_reports" label="证据报告" min-width="260">
              <template #default="{ row }">{{ formatList(row.evidence_reports) }}</template>
            </el-table-column>
            <el-table-column prop="validation_checks" label="验证要求" min-width="420">
              <template #default="{ row }">{{ formatList(row.validation_checks) }}</template>
            </el-table-column>
          </el-table>
          <el-table
            v-if="readiness.migration_blocker_resolution_operator_pack_validation?.issues?.length"
            :data="readiness.migration_blocker_resolution_operator_pack_validation.issues.slice(0, 10)"
            border
            class="preview-section-table"
          >
            <el-table-column prop="severity" label="级别" width="100">
              <template #default="{ row }">
                <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="field" label="字段" min-width="180" />
            <el-table-column prop="code" label="规则" min-width="220" />
            <el-table-column prop="message" label="说明" min-width="420" />
          </el-table>
          <div class="preview-summary">
            <el-tag :type="readinessStatusType(readiness.migration_blocker_resolution_signoff?.overall_status)">
              签收 {{ readiness.migration_blocker_resolution_signoff?.overall_status || 'missing' }}
            </el-tag>
            <el-tag type="warning">{{ readiness.migration_blocker_resolution_signoff?.summary?.pending_items || 0 }} 个 pending</el-tag>
            <el-tag type="info">{{ readiness.migration_blocker_resolution_signoff?.summary?.approved_items || 0 }} 个 approved</el-tag>
            <el-tag type="info">{{ readiness.migration_blocker_resolution_signoff?.summary?.executed_items || 0 }} 个 executed</el-tag>
            <el-tag type="success">{{ readiness.migration_blocker_resolution_signoff?.summary?.verified_items || 0 }} 个 verified</el-tag>
          </div>
          <el-table :data="readiness.migration_blocker_resolution_signoff?.items || []" border class="preview-section-table">
            <el-table-column prop="status" label="状态" width="110">
              <template #default="{ row }">
                <el-tag :type="readinessStatusType(row.status)">{{ row.status }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="stage" label="阶段" min-width="150" />
            <el-table-column prop="owner" label="负责人" min-width="180" />
            <el-table-column prop="blocked_count" label="阻断" width="80" />
            <el-table-column prop="approved_by" label="批准人" min-width="130" />
            <el-table-column prop="approved_at" label="批准时间" min-width="160" />
            <el-table-column prop="executed_by" label="执行人" min-width="130" />
            <el-table-column prop="executed_at" label="执行时间" min-width="160" />
            <el-table-column prop="verified_by" label="验证人" min-width="130" />
            <el-table-column prop="verified_at" label="验证时间" min-width="160" />
            <el-table-column prop="notes" label="备注" min-width="220" />
          </el-table>
          <div class="preview-summary">
            <el-tag :type="readinessStatusType(readiness.migration_blocker_resolution_signoff_validation?.overall_status)">
              校验 {{ readiness.migration_blocker_resolution_signoff_validation?.overall_status || 'missing' }}
            </el-tag>
            <el-tag :type="readiness.migration_blocker_resolution_signoff_validation?.summary?.blockers ? 'danger' : 'info'">
              {{ readiness.migration_blocker_resolution_signoff_validation?.summary?.blockers || 0 }} 个 blocker
            </el-tag>
            <el-tag :type="readiness.migration_blocker_resolution_signoff_validation?.summary?.warnings ? 'warning' : 'info'">
              {{ readiness.migration_blocker_resolution_signoff_validation?.summary?.warnings || 0 }} 个 warning
            </el-tag>
          </div>
          <el-table :data="readiness.migration_blocker_resolution_signoff_validation?.issues || []" border class="preview-section-table">
            <el-table-column prop="severity" label="级别" width="100">
              <template #default="{ row }">
                <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="row_number" label="行号" width="90" />
            <el-table-column prop="stage" label="阶段" min-width="150" />
            <el-table-column prop="field" label="字段" min-width="130" />
            <el-table-column prop="code" label="规则" min-width="190" />
            <el-table-column prop="message" label="说明" min-width="320" />
          </el-table>
        </template>
        <el-divider content-position="left">映射处理模板</el-divider>
        <el-alert v-if="!readiness.migration_resolution_templates" title="尚未生成 legacy-migration-resolution-templates.json，请先运行 scripts/New-LegacyMigrationResolutionTemplates.ps1。" type="info" show-icon :closable="false" />
        <template v-else>
          <div class="preview-summary">
            <el-tag type="info">{{ readiness.migration_resolution_templates.summary?.template_count || 0 }} 个模板</el-tag>
            <el-tag type="warning">{{ readiness.migration_resolution_templates.summary?.unit_user_rows || 0 }} 个单位映射</el-tag>
            <el-tag type="warning">{{ readiness.migration_resolution_templates.summary?.project_rows || 0 }} 个项目映射</el-tag>
            <el-tag type="danger">{{ readiness.migration_resolution_templates.summary?.attachment_exception_rows || 0 }} 个附件例外</el-tag>
          </div>
          <el-table :data="readiness.migration_resolution_templates.templates || []" border class="preview-section-table">
            <el-table-column prop="key" label="模板" min-width="220" />
            <el-table-column prop="rows" label="行数" width="90" />
            <el-table-column label="状态" width="100">
              <template #default="{ row }">
                <el-tag :type="row.exists ? 'success' : 'danger'">{{ row.exists ? '存在' : '缺失' }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column label="必填列" min-width="260">
              <template #default="{ row }">{{ (row.required_columns || []).join(', ') || '-' }}</template>
            </el-table-column>
            <el-table-column prop="path" label="路径" min-width="360" />
          </el-table>
          <el-divider content-position="left">映射操作员工作包</el-divider>
          <el-alert v-if="!readiness.migration_resolution_operator_pack" title="尚未生成 legacy-migration-resolution-operator-pack.json，请先运行 scripts/New-LegacyMigrationResolutionOperatorPack.ps1。" type="info" show-icon :closable="false" />
          <template v-else>
            <div class="preview-summary">
              <el-tag :type="readinessStatusType(readiness.migration_resolution_operator_pack.overall_status)">
                {{ readiness.migration_resolution_operator_pack.overall_status }}
              </el-tag>
              <el-tag type="info">完成 {{ readiness.migration_resolution_operator_pack.summary?.completion_percent || 0 }}%</el-tag>
              <el-tag type="warning">{{ readiness.migration_resolution_operator_pack.summary?.pending_rows || 0 }} 行 pending</el-tag>
              <el-tag :type="readiness.migration_resolution_operator_pack.summary?.p1_items ? 'danger' : 'info'">
                {{ readiness.migration_resolution_operator_pack.summary?.p1_items || 0 }} 个 P1
              </el-tag>
              <el-tag :type="readinessStatusType(readiness.migration_resolution_operator_pack_validation?.overall_status)">
                操作包校验 {{ readiness.migration_resolution_operator_pack_validation?.overall_status || 'missing' }}
              </el-tag>
              <span>{{ nextStepTitle(readiness.migration_resolution_operator_pack.next_step) }}</span>
            </div>
            <el-table :data="readiness.migration_resolution_operator_pack.steps || []" border class="preview-section-table">
              <el-table-column prop="order" label="#" width="60" />
              <el-table-column prop="title" label="步骤" min-width="220" />
              <el-table-column label="状态" width="110">
                <template #default="{ row }">
                  <el-tag :type="readinessStatusType(row.status)">{{ row.status }}</el-tag>
                </template>
              </el-table-column>
              <el-table-column prop="action" label="处理动作" min-width="360" />
              <el-table-column prop="acceptance" label="验收标准" min-width="360" />
            </el-table>
            <el-table :data="readiness.migration_resolution_operator_pack.operator_files || []" border class="preview-section-table">
              <el-table-column prop="key" label="文件" min-width="180" />
              <el-table-column prop="purpose" label="用途" min-width="260" />
              <el-table-column prop="path" label="路径" min-width="420" />
            </el-table>
            <el-table :data="readiness.migration_resolution_operator_pack.owner_worklists || []" border class="preview-section-table">
              <el-table-column prop="owner" label="负责人" min-width="160" />
              <el-table-column prop="work_items" label="任务" width="90" />
              <el-table-column prop="row_count" label="影响行" width="90" />
              <el-table-column prop="p1_items" label="P1" width="80" />
              <el-table-column prop="blocked_items" label="阻断" width="90" />
              <el-table-column prop="path" label="CSV 路径" min-width="420" />
            </el-table>
            <el-table :data="readiness.migration_resolution_operator_pack.acceptance_gates || []" border class="preview-section-table">
              <el-table-column prop="title" label="签收项" min-width="240" />
              <el-table-column label="状态" width="110">
                <template #default="{ row }">
                  <el-tag :type="readinessStatusType(row.status)">{{ row.status }}</el-tag>
                </template>
              </el-table-column>
              <el-table-column prop="evidence" label="证据" min-width="320" />
              <el-table-column prop="action" label="处理动作" min-width="360" />
            </el-table>
            <el-table :data="readiness.migration_resolution_operator_pack.template_progress || []" border class="preview-section-table">
              <el-table-column prop="template" label="模板" min-width="230" />
              <el-table-column prop="target" label="目标" min-width="160" />
              <el-table-column prop="total_rows" label="总数" width="90" />
              <el-table-column prop="ready_rows" label="Ready" width="90" />
              <el-table-column prop="pending_rows" label="Pending" width="100" />
              <el-table-column prop="blocked_rows" label="Blocked" width="100" />
              <el-table-column prop="completion_percent" label="完成度" width="100" />
            </el-table>
            <el-table :data="readiness.migration_resolution_operator_pack.top_work_items || []" border class="preview-section-table">
              <el-table-column prop="priority" label="优先级" width="90" />
              <el-table-column prop="owner" label="负责人" min-width="140" />
              <el-table-column prop="template" label="模板" min-width="230" />
              <el-table-column prop="field_group" label="字段组" min-width="170" />
              <el-table-column prop="row_count" label="影响行" width="90" />
              <el-table-column prop="action" label="处理动作" min-width="360" />
            </el-table>
            <el-table
              v-if="readiness.migration_resolution_operator_pack_validation?.issues?.length"
              :data="readiness.migration_resolution_operator_pack_validation.issues.slice(0, 10)"
              border
              class="preview-section-table"
            >
              <el-table-column prop="severity" label="级别" width="100">
                <template #default="{ row }">
                  <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
                </template>
              </el-table-column>
              <el-table-column prop="field" label="字段" min-width="180" />
              <el-table-column prop="code" label="规则" min-width="220" />
              <el-table-column prop="message" label="说明" min-width="420" />
            </el-table>
          </template>
          <el-divider content-position="left">模板校验结果</el-divider>
          <div class="preview-summary">
              <el-tag :type="readinessStatusType(readiness.migration_resolution_validation?.overall_status)">
                {{ readiness.migration_resolution_validation?.overall_status || 'missing' }}
              </el-tag>
              <el-tag :type="readiness.migration_resolution_validation?.summary?.blockers ? 'danger' : 'info'">
                {{ readiness.migration_resolution_validation?.summary?.blockers || 0 }} 个 blocker
              </el-tag>
              <el-tag type="warning">{{ readiness.migration_resolution_validation?.summary?.warnings || 0 }} 个 warning</el-tag>
              <el-tag type="info">{{ readiness.migration_resolution_validation?.summary?.unit_user_rows || 0 }} 个单位映射</el-tag>
              <el-tag type="info">{{ readiness.migration_resolution_validation?.summary?.project_rows || 0 }} 个项目映射</el-tag>
              <el-tag type="info">{{ readiness.migration_resolution_validation?.summary?.attachment_exception_rows || 0 }} 个附件例外</el-tag>
            </div>
            <el-table :data="readiness.migration_resolution_validation?.by_template || []" border class="preview-section-table">
              <el-table-column prop="template" label="模板" min-width="220" />
              <el-table-column prop="blockers" label="Blocker" width="100" />
              <el-table-column prop="warnings" label="Warning" width="100" />
            </el-table>
            <el-table :data="readiness.migration_resolution_validation?.sample_issues || []" border class="preview-section-table">
              <el-table-column prop="template" label="模板" min-width="200" />
              <el-table-column label="级别" width="110">
                <template #default="{ row }">
                  <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
                </template>
              </el-table-column>
              <el-table-column prop="row_number" label="行号" width="90" />
              <el-table-column prop="field" label="字段" min-width="140" />
              <el-table-column prop="code" label="代码" min-width="160" />
              <el-table-column prop="message" label="说明" min-width="360" />
            </el-table>
          <el-divider content-position="left">模板填写进度</el-divider>
          <div class="preview-summary">
            <el-tag :type="readinessStatusType(readiness.migration_resolution_progress?.overall_status)">
              {{ readiness.migration_resolution_progress?.overall_status || 'missing' }}
            </el-tag>
            <el-tag type="success">{{ readiness.migration_resolution_progress?.summary?.ready_rows || 0 }} 条 ready</el-tag>
            <el-tag type="warning">{{ readiness.migration_resolution_progress?.summary?.pending_rows || 0 }} 条 pending</el-tag>
            <el-tag :type="readiness.migration_resolution_progress?.summary?.blocked_rows ? 'danger' : 'info'">
              {{ readiness.migration_resolution_progress?.summary?.blocked_rows || 0 }} 条 blocked
            </el-tag>
            <el-tag type="info">完成 {{ readiness.migration_resolution_progress?.summary?.completion_percent || 0 }}%</el-tag>
          </div>
          <el-table :data="readiness.migration_resolution_progress?.by_template || []" border class="preview-section-table">
            <el-table-column prop="template" label="模板" min-width="230" />
            <el-table-column prop="target" label="目标" min-width="160" />
            <el-table-column prop="total_rows" label="总数" width="90" />
            <el-table-column prop="ready_rows" label="Ready" width="90" />
            <el-table-column prop="pending_rows" label="Pending" width="100" />
            <el-table-column prop="blocked_rows" label="Blocked" width="100" />
            <el-table-column label="完成度" width="150">
              <template #default="{ row }">
                <el-progress :percentage="row.completion_percent || 0" :status="row.blocked_rows ? 'exception' : row.completion_percent === 100 ? 'success' : undefined" />
              </template>
            </el-table-column>
            <el-table-column label="缺失字段" min-width="260">
              <template #default="{ row }">{{ formatMissingFields(row.most_missing_fields) }}</template>
            </el-table-column>
            <el-table-column prop="action" label="处理建议" min-width="320" />
          </el-table>
          <el-table :data="readiness.migration_resolution_progress?.sample_open_rows || []" border class="preview-section-table">
            <el-table-column prop="template" label="模板" min-width="220" />
            <el-table-column prop="row_number" label="行号" width="90" />
            <el-table-column prop="legacy_id" label="旧ID" width="100" />
            <el-table-column label="状态" width="110">
              <template #default="{ row }">
                <el-tag :type="readinessStatusType(row.status)">{{ row.status }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column label="缺失字段" min-width="220">
              <template #default="{ row }">{{ (row.missing_fields || []).join(', ') || '-' }}</template>
            </el-table-column>
            <el-table-column label="无效字段" min-width="180">
              <template #default="{ row }">{{ (row.invalid_fields || []).join(', ') || '-' }}</template>
            </el-table-column>
            <el-table-column prop="action" label="处理动作" min-width="320" />
          </el-table>
          <el-divider content-position="left">模板任务清单</el-divider>
          <div class="preview-summary">
            <el-tag :type="readinessStatusType(readiness.migration_resolution_worklist?.overall_status)">
              {{ readiness.migration_resolution_worklist?.overall_status || 'missing' }}
            </el-tag>
            <el-tag type="warning">{{ readiness.migration_resolution_worklist?.summary?.work_items || 0 }} 个任务</el-tag>
            <el-tag type="warning">{{ readiness.migration_resolution_row_worklist?.summary?.row_work_items || 0 }} 行待处理</el-tag>
            <el-tag type="info">{{ readiness.migration_resolution_owner_row_worklists?.summary?.owner_count || 0 }} 个逐行负责人文件</el-tag>
            <el-tag :type="readiness.migration_resolution_worklist?.summary?.p1_items ? 'danger' : 'info'">
              {{ readiness.migration_resolution_worklist?.summary?.p1_items || 0 }} 个 P1
            </el-tag>
            <el-tag :type="readiness.migration_resolution_row_worklist?.summary?.p1_rows ? 'danger' : 'info'">
              {{ readiness.migration_resolution_row_worklist?.summary?.p1_rows || 0 }} 行 P1
            </el-tag>
            <el-tag :type="readiness.migration_resolution_worklist?.summary?.blocked_items ? 'danger' : 'info'">
              {{ readiness.migration_resolution_worklist?.summary?.blocked_items || 0 }} 个阻断
            </el-tag>
          </div>
          <el-table :data="readiness.migration_resolution_worklist?.items || []" border class="preview-section-table">
            <el-table-column prop="priority" label="优先级" width="90">
              <template #default="{ row }">
                <el-tag :type="row.priority === 'P1' ? 'danger' : row.priority === 'P2' ? 'warning' : 'info'">{{ row.priority }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="owner" label="负责人" min-width="140" />
            <el-table-column prop="template" label="模板" min-width="230" />
            <el-table-column prop="field_group" label="字段组" min-width="170" />
            <el-table-column prop="row_count" label="影响行" width="90" />
            <el-table-column label="样例行" min-width="260">
              <template #default="{ row }">{{ formatSampleRows(row.sample_rows) }}</template>
            </el-table-column>
            <el-table-column prop="action" label="处理动作" min-width="360" />
            <el-table-column prop="acceptance" label="验收标准" min-width="360" />
          </el-table>
          <el-table :data="readiness.migration_resolution_row_worklist?.by_owner || []" border class="preview-section-table">
            <el-table-column prop="owner" label="负责人" min-width="160" />
            <el-table-column prop="rows" label="行数" width="90" />
            <el-table-column prop="p1_rows" label="P1 行" width="90" />
            <el-table-column prop="blocked_rows" label="阻断行" width="100" />
          </el-table>
          <el-table :data="readiness.migration_resolution_row_worklist?.by_template || []" border class="preview-section-table">
            <el-table-column prop="template" label="模板" min-width="260" />
            <el-table-column prop="rows" label="行数" width="90" />
            <el-table-column prop="p1_rows" label="P1 行" width="90" />
            <el-table-column prop="blocked_rows" label="阻断行" width="100" />
          </el-table>
          <el-table :data="readiness.migration_resolution_row_worklist?.sample_rows || []" border class="preview-section-table">
            <el-table-column prop="priority" label="优先级" width="90">
              <template #default="{ row }">
                <el-tag :type="row.priority === 'P1' ? 'danger' : row.priority === 'P2' ? 'warning' : 'info'">{{ row.priority }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="owner" label="负责人" min-width="140" />
            <el-table-column prop="template" label="模板" min-width="230" />
            <el-table-column prop="row_number" label="行号" width="90" />
            <el-table-column prop="legacy_id" label="旧ID" width="100" />
            <el-table-column label="缺失字段" min-width="220">
              <template #default="{ row }">{{ (row.missing_fields || []).join(', ') || '-' }}</template>
            </el-table-column>
            <el-table-column prop="action" label="处理动作" min-width="360" />
            <el-table-column prop="context" label="上下文" min-width="420" />
          </el-table>
          <el-table :data="readiness.migration_resolution_owner_row_worklists?.files || []" border class="preview-section-table">
            <el-table-column prop="owner" label="负责人" min-width="160" />
            <el-table-column prop="rows" label="行数" width="90" />
            <el-table-column prop="p1_rows" label="P1 行" width="90" />
            <el-table-column prop="blocked_rows" label="阻断行" width="100" />
            <el-table-column prop="path" label="逐行 CSV 路径" min-width="420" />
          </el-table>
          <el-table :data="readiness.migration_resolution_owner_template_row_worklists?.files || []" border class="preview-section-table">
            <el-table-column prop="owner" label="负责人" min-width="160" />
            <el-table-column prop="template" label="模板" min-width="260" />
            <el-table-column prop="rows" label="行数" width="90" />
            <el-table-column prop="p1_rows" label="P1 行" width="90" />
            <el-table-column prop="blocked_rows" label="阻断行" width="100" />
            <el-table-column prop="path" label="负责人+模板 CSV 路径" min-width="420" />
          </el-table>
          <el-table :data="readiness.migration_resolution_distribution_pack?.items || []" border class="preview-section-table">
            <el-table-column prop="owner" label="负责人" min-width="160" />
            <el-table-column prop="template" label="模板" min-width="260" />
            <el-table-column prop="rows" label="行数" width="90" />
            <el-table-column prop="p1_rows" label="P1 行" width="90" />
            <el-table-column prop="blocked_rows" label="阻断行" width="100" />
            <el-table-column prop="assignment" label="分发说明" min-width="280" />
            <el-table-column prop="csv_path" label="CSV 路径" min-width="420" />
          </el-table>
          <el-table :data="distributionPackFiles" border class="preview-section-table">
            <el-table-column prop="key" label="文件" min-width="180" />
            <el-table-column prop="path" label="路径" min-width="420" />
          </el-table>
          <div class="preview-summary">
            <el-tag :type="readinessStatusType(readiness.migration_resolution_distribution_signoff?.overall_status)">
              {{ readiness.migration_resolution_distribution_signoff?.overall_status || 'missing' }}
            </el-tag>
            <el-tag type="warning">{{ readiness.migration_resolution_distribution_signoff?.summary?.pending_items || 0 }} 个 pending</el-tag>
            <el-tag type="info">{{ readiness.migration_resolution_distribution_signoff?.summary?.sent_items || 0 }} 个 sent</el-tag>
            <el-tag type="info">{{ readiness.migration_resolution_distribution_signoff?.summary?.accepted_items || 0 }} 个 accepted</el-tag>
            <el-tag type="success">{{ readiness.migration_resolution_distribution_signoff?.summary?.completed_items || 0 }} 个 completed</el-tag>
            <el-tag :type="readiness.migration_resolution_distribution_signoff?.summary?.invalid_items ? 'danger' : 'info'">
              {{ readiness.migration_resolution_distribution_signoff?.summary?.invalid_items || 0 }} 个 invalid
            </el-tag>
          </div>
          <el-table :data="readiness.migration_resolution_distribution_signoff?.items || []" border class="preview-section-table">
            <el-table-column prop="status" label="签收状态" width="110">
              <template #default="{ row }">
                <el-tag :type="readinessStatusType(row.status)">{{ row.status }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="owner" label="负责人" min-width="150" />
            <el-table-column prop="recipient" label="接收人" min-width="140" />
            <el-table-column prop="template" label="模板" min-width="260" />
            <el-table-column prop="rows" label="行数" width="90" />
            <el-table-column prop="sent_at" label="发送时间" min-width="160" />
            <el-table-column prop="accepted_by" label="签收人" min-width="140" />
            <el-table-column prop="completed_at" label="完成时间" min-width="160" />
            <el-table-column prop="notes" label="备注" min-width="220" />
          </el-table>
          <div class="preview-summary">
            <el-tag :type="readinessStatusType(readiness.migration_resolution_distribution_signoff_validation?.overall_status)">
              校验 {{ readiness.migration_resolution_distribution_signoff_validation?.overall_status || 'missing' }}
            </el-tag>
            <el-tag :type="readiness.migration_resolution_distribution_signoff_validation?.summary?.blockers ? 'danger' : 'info'">
              {{ readiness.migration_resolution_distribution_signoff_validation?.summary?.blockers || 0 }} 个 blocker
            </el-tag>
            <el-tag :type="readiness.migration_resolution_distribution_signoff_validation?.summary?.warnings ? 'warning' : 'info'">
              {{ readiness.migration_resolution_distribution_signoff_validation?.summary?.warnings || 0 }} 个 warning
            </el-tag>
          </div>
          <el-table :data="readiness.migration_resolution_distribution_signoff_validation?.issues || []" border class="preview-section-table">
            <el-table-column prop="severity" label="级别" width="100">
              <template #default="{ row }">
                <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="row_number" label="行号" width="90" />
            <el-table-column prop="owner" label="负责人" min-width="140" />
            <el-table-column prop="template" label="模板" min-width="220" />
            <el-table-column prop="field" label="字段" min-width="130" />
            <el-table-column prop="code" label="规则" min-width="190" />
            <el-table-column prop="message" label="说明" min-width="320" />
          </el-table>
          <el-table :data="readiness.migration_resolution_owner_worklists?.files || []" border class="preview-section-table">
            <el-table-column prop="owner" label="负责人" min-width="160" />
            <el-table-column prop="work_items" label="任务" width="90" />
            <el-table-column prop="row_count" label="影响行" width="90" />
            <el-table-column prop="p1_items" label="P1" width="80" />
            <el-table-column prop="blocked_items" label="阻断" width="90" />
            <el-table-column prop="path" label="汇总 CSV 路径" min-width="420" />
          </el-table>
          <el-divider content-position="left">模板导入预览</el-divider>
          <div class="preview-summary">
            <el-tag type="success">{{ readiness.migration_resolution_import_preview?.summary?.ready_items || 0 }} 条 ready</el-tag>
            <el-tag type="warning">{{ readiness.migration_resolution_import_preview?.summary?.pending_items || 0 }} 条 pending</el-tag>
            <el-tag :type="readiness.migration_resolution_import_preview?.summary?.blocked_items ? 'danger' : 'info'">
              {{ readiness.migration_resolution_import_preview?.summary?.blocked_items || 0 }} 条 blocked
            </el-tag>
          </div>
          <el-table :data="readiness.migration_resolution_import_preview?.by_target || []" border class="preview-section-table">
            <el-table-column prop="target" label="目标" min-width="180" />
            <el-table-column prop="total" label="总数" width="90" />
            <el-table-column prop="ready" label="Ready" width="90" />
            <el-table-column prop="pending" label="Pending" width="100" />
            <el-table-column prop="blocked" label="Blocked" width="100" />
          </el-table>
          <el-table :data="readiness.migration_resolution_import_preview?.samples?.blocked || []" border class="preview-section-table">
            <el-table-column prop="target" label="目标" min-width="160" />
            <el-table-column prop="legacy_id" label="旧ID" width="100" />
            <el-table-column label="告警" min-width="260">
              <template #default="{ row }">{{ (row.warnings || []).join(', ') || '-' }}</template>
            </el-table-column>
            <el-table-column prop="approved_by" label="审批人" min-width="140" />
          </el-table>
          <el-divider content-position="left">映射签收闸门</el-divider>
          <div class="preview-summary">
            <el-tag :type="readinessStatusType(readiness.migration_resolution_acceptance_gate?.overall_status)">
              {{ readiness.migration_resolution_acceptance_gate?.overall_status || 'missing' }}
            </el-tag>
            <el-tag type="success">{{ readiness.migration_resolution_acceptance_gate?.summary?.passed_gates || 0 }} 项通过</el-tag>
            <el-tag type="warning">{{ readiness.migration_resolution_acceptance_gate?.summary?.open_gates || 0 }} 项待处理</el-tag>
            <el-tag :type="readiness.migration_resolution_acceptance_gate?.summary?.blockers ? 'danger' : 'info'">
              {{ readiness.migration_resolution_acceptance_gate?.summary?.blockers || 0 }} 个 blocker
            </el-tag>
            <el-tag type="info">完成 {{ readiness.migration_resolution_acceptance_gate?.summary?.completion_percent || 0 }}%</el-tag>
            <span>{{ nextStepTitle(readiness.migration_resolution_acceptance_gate?.next_step) }}</span>
          </div>
          <el-table :data="readiness.migration_resolution_acceptance_gate?.gates || []" border class="preview-section-table">
            <el-table-column prop="title" label="签收项" min-width="240" />
            <el-table-column label="状态" width="110">
              <template #default="{ row }">
                <el-tag :type="readinessStatusType(row.status)">{{ row.status }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="severity" label="级别" width="100" />
            <el-table-column prop="evidence" label="证据" min-width="320" />
            <el-table-column prop="action" label="处理动作" min-width="360" />
            <el-table-column prop="acceptance" label="验收标准" min-width="360" />
          </el-table>
          <el-divider content-position="left">Resolved 映射预览</el-divider>
          <div class="preview-summary">
            <el-tag type="success">{{ readiness.unit_user_id_map_resolved?.summary?.mapped_units || 0 }} 个单位 resolved</el-tag>
            <el-tag type="success">{{ readiness.project_id_map_resolved?.summary?.mapped_projects || 0 }} 个项目 resolved</el-tag>
            <el-tag type="success">{{ readiness.attachment_exceptions_resolved?.summary?.ready_exceptions || 0 }} 个附件例外 resolved</el-tag>
            <el-tag :type="(readiness.unit_user_id_map_resolved?.summary?.blocked_units || readiness.project_id_map_resolved?.summary?.blocked_projects || readiness.attachment_exceptions_resolved?.summary?.blocked_exceptions) ? 'danger' : 'info'">
              {{ (readiness.unit_user_id_map_resolved?.summary?.blocked_units || 0) + (readiness.project_id_map_resolved?.summary?.blocked_projects || 0) + (readiness.attachment_exceptions_resolved?.summary?.blocked_exceptions || 0) }} 条 blocked
            </el-tag>
          </div>
          <el-table :data="resolvedMappingRows" border class="preview-section-table">
            <el-table-column prop="target" label="目标" min-width="180" />
            <el-table-column prop="total" label="总数" width="90" />
            <el-table-column prop="resolved" label="Resolved" width="110" />
            <el-table-column prop="pending" label="Pending" width="100" />
            <el-table-column prop="blocked" label="Blocked" width="100" />
          </el-table>
          <el-divider content-position="left">Resolved Dry Run</el-divider>
          <el-table :data="resolvedDryRunRows" border class="preview-section-table">
            <el-table-column prop="target" label="目标" min-width="180" />
            <el-table-column prop="total" label="总数" width="90" />
            <el-table-column prop="ready" label="Ready" width="90" />
            <el-table-column prop="waiting" label="Waiting" width="100" />
            <el-table-column prop="blocked" label="Blocked" width="100" />
          </el-table>
          <el-divider content-position="left">Dry Run 对比</el-divider>
          <div class="preview-summary">
            <el-tag :type="readinessStatusType(readiness.migration_dry_run_comparison?.overall_status)">
              {{ readiness.migration_dry_run_comparison?.overall_status || 'missing' }}
            </el-tag>
            <el-tag type="info">默认 ready {{ readiness.migration_dry_run_comparison?.summary?.total_default_ready || 0 }}</el-tag>
            <el-tag type="success">Resolved ready {{ readiness.migration_dry_run_comparison?.summary?.total_resolved_ready || 0 }}</el-tag>
            <el-tag type="success">Mock ready {{ readiness.migration_dry_run_comparison?.summary?.total_mock_ready || 0 }}</el-tag>
          </div>
          <el-table :data="dryRunComparisonRows" border class="preview-section-table">
            <el-table-column prop="target" label="目标" min-width="160" />
            <el-table-column prop="defaultReady" label="默认 Ready" width="110" />
            <el-table-column prop="resolvedReady" label="Resolved Ready" width="130" />
            <el-table-column prop="mockReady" label="Mock Ready" width="110" />
            <el-table-column prop="resolvedDelta" label="Resolved 增量" width="130" />
            <el-table-column prop="resolvedWaiting" label="Resolved Waiting" width="150" />
            <el-table-column prop="resolvedBlocked" label="Resolved Blocked" width="150" />
          </el-table>
        </template>
      </template>
    </el-card>

    <el-card shadow="never">
      <template #header>旧库 Dry Run 明细</template>
      <div v-if="readiness.dry_run" class="dry-run-summary">
        <el-tag type="success">{{ readiness.dry_run.ready_count }} 张表就绪</el-tag>
        <el-tag :type="readiness.dry_run.warning_count ? 'warning' : 'info'">
          {{ readiness.dry_run.warning_count }} 张表有警告
        </el-tag>
        <span>估算记录：{{ readiness.dry_run.estimated_row_count || 0 }}</span>
      </div>
      <el-alert v-else title="尚未生成 legacy-import-dry-run.json，请先运行 scripts/Invoke-LegacyImportDryRun.ps1。" type="info" show-icon :closable="false" />
      <el-table v-if="readiness.dry_run" :data="readiness.dry_run.items" border>
        <el-table-column prop="legacy_table" label="旧表" width="150" />
        <el-table-column prop="target_table" label="新表" width="150" />
        <el-table-column prop="insert_statement_count" label="INSERT 数" width="120" />
        <el-table-column prop="estimated_row_count" label="估算行数" width="120" />
        <el-table-column label="状态" width="120">
          <template #default="{ row }">
            <el-tag :type="row.status === 'ready' ? 'success' : 'warning'">{{ row.status }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="警告" min-width="220">
          <template #default="{ row }">{{ (row.warnings || []).join(', ') || '-' }}</template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-card shadow="never">
      <template #header>迁移批次</template>
      <el-table :data="batches" border v-loading="batchLoading">
        <el-table-column prop="name" label="批次" min-width="220" />
        <el-table-column prop="mode" label="模式" width="110" />
        <el-table-column prop="status" label="状态" width="120" />
        <el-table-column prop="source_path" label="来源" min-width="320" />
        <el-table-column prop="finished_at" label="完成时间" width="180" />
      </el-table>
    </el-card>

    <el-card shadow="never">
      <template #header>历史附件质量</template>
      <el-alert v-if="!readiness.attachment_quality" title="尚未生成 legacy-attachment-quality.json，请先运行 scripts/New-LegacyAttachmentQualityReport.ps1。" type="info" show-icon :closable="false" />
      <template v-else>
        <div class="preview-summary">
          <el-tag type="success">{{ readiness.attachment_quality.summary?.total_references || 0 }} 个附件引用</el-tag>
          <el-tag :type="readiness.attachment_quality.summary?.missing_files ? 'warning' : 'success'">
            {{ readiness.attachment_quality.summary?.missing_files || 0 }} 个缺失
          </el-tag>
          <el-tag :type="readiness.attachment_quality.summary?.dangerous_extensions ? 'danger' : 'info'">
            {{ readiness.attachment_quality.summary?.dangerous_extensions || 0 }} 个危险扩展名
          </el-tag>
          <el-tag :type="readiness.attachment_quality.summary?.zero_byte_files ? 'warning' : 'info'">
            {{ readiness.attachment_quality.summary?.zero_byte_files || 0 }} 个 0 字节
          </el-tag>
        </div>
        <el-row :gutter="12">
          <el-col :span="10">
            <el-table :data="readiness.attachment_quality.by_source || []" border>
              <el-table-column prop="source_table" label="来源" min-width="140" />
              <el-table-column prop="count" label="数量" width="100" />
            </el-table>
          </el-col>
          <el-col :span="14">
            <el-table :data="(readiness.attachment_quality.by_extension || []).slice(0, 10)" border>
              <el-table-column prop="extension" label="扩展名" min-width="120" />
              <el-table-column prop="count" label="数量" width="100" />
            </el-table>
          </el-col>
        </el-row>
        <el-table :data="readiness.attachment_quality.samples?.warnings || []" border class="preview-section-table">
          <el-table-column prop="source_table" label="来源" width="110" />
          <el-table-column prop="legacy_project_id" label="项目ID" width="100" />
          <el-table-column prop="field" label="字段" width="100" />
          <el-table-column prop="path" label="存储路径" min-width="220" />
          <el-table-column prop="original_name" label="原文件名" min-width="220" />
          <el-table-column label="告警" min-width="220">
            <template #default="{ row }">{{ (row.warnings || []).join(', ') || '-' }}</template>
          </el-table-column>
        </el-table>
        <el-divider content-position="left">导入索引</el-divider>
        <el-alert v-if="!readiness.attachment_import_index" title="尚未生成 legacy-attachment-import-index.json，请先运行 scripts/New-LegacyAttachmentImportIndex.ps1。" type="info" show-icon :closable="false" />
        <template v-else>
          <div class="preview-summary">
            <el-tag type="success">{{ readiness.attachment_import_index.summary?.ready_items || 0 }} 个可导入</el-tag>
            <el-tag :type="readiness.attachment_import_index.summary?.blocked_items ? 'danger' : 'info'">
              {{ readiness.attachment_import_index.summary?.blocked_items || 0 }} 个阻断
            </el-tag>
            <el-tag type="info">目标磁盘：{{ readiness.attachment_import_index.target_disk }}</el-tag>
          </div>
          <el-table :data="readiness.attachment_import_index.by_purpose || []" border>
            <el-table-column prop="purpose" label="用途" min-width="220" />
            <el-table-column prop="count" label="数量" width="100" />
          </el-table>
          <el-table :data="readiness.attachment_import_index.samples?.blocked || []" border class="preview-section-table">
            <el-table-column prop="legacy_project_id" label="项目ID" width="100" />
            <el-table-column prop="source_path" label="旧路径" min-width="220" />
            <el-table-column prop="target_path" label="新路径" min-width="260" />
            <el-table-column label="告警" min-width="220">
              <template #default="{ row }">{{ (row.warnings || []).join(', ') || '-' }}</template>
            </el-table-column>
          </el-table>
          <el-divider content-position="left">Dry Run</el-divider>
          <el-alert v-if="!readiness.attachment_import_dry_run" title="尚未生成 legacy-attachment-import-dry-run.json，请先运行 scripts/Invoke-LegacyAttachmentImportDryRun.ps1。" type="info" show-icon :closable="false" />
          <template v-else>
            <div class="preview-summary">
              <el-tag type="success">{{ readiness.attachment_import_dry_run.summary?.ready_items || 0 }} 个可复制</el-tag>
              <el-tag :type="readiness.attachment_import_dry_run.summary?.blocked_items ? 'danger' : 'info'">
                {{ readiness.attachment_import_dry_run.summary?.blocked_items || 0 }} 个阻断
              </el-tag>
              <el-tag :type="readiness.attachment_import_dry_run.summary?.duplicate_target_paths ? 'warning' : 'info'">
                {{ readiness.attachment_import_dry_run.summary?.duplicate_target_paths || 0 }} 个目标冲突
              </el-tag>
              <el-tag :type="readiness.attachment_import_dry_run.summary?.target_path_escapes_root ? 'danger' : 'info'">
                {{ readiness.attachment_import_dry_run.summary?.target_path_escapes_root || 0 }} 个越界路径
              </el-tag>
              <span>预计复制：{{ formatBytes(readiness.attachment_import_dry_run.summary?.would_copy_bytes || 0) }}</span>
            </div>
            <el-table :data="readiness.attachment_import_dry_run.samples?.blocked || []" border class="preview-section-table">
              <el-table-column prop="legacy_project_id" label="项目ID" width="100" />
              <el-table-column prop="source_path" label="旧路径" min-width="220" />
              <el-table-column prop="target_path" label="新路径" min-width="260" />
              <el-table-column label="Dry Run 告警" min-width="240">
                <template #default="{ row }">{{ (row.warnings || []).join(', ') || '-' }}</template>
              </el-table-column>
            </el-table>
            <el-divider content-position="left">缺失附件确认</el-divider>
            <el-alert v-if="!readiness.attachment_exception_confirmation" title="尚未生成 legacy-attachment-exception-confirmation.json，请先运行 scripts/New-LegacyAttachmentExceptionConfirmation.ps1。" type="info" show-icon :closable="false" />
            <template v-else>
              <el-divider content-position="left">操作员工作包</el-divider>
              <el-alert v-if="!readiness.attachment_exception_operator_pack" title="尚未生成 legacy-attachment-exception-operator-pack.json，请先运行 scripts/New-LegacyAttachmentExceptionOperatorPack.ps1。" type="info" show-icon :closable="false" />
              <template v-else>
                <div class="preview-summary">
                  <el-tag :type="readinessStatusType(readiness.attachment_exception_operator_pack.overall_status)">
                    {{ readiness.attachment_exception_operator_pack.overall_status }}
                  </el-tag>
                  <el-tag type="info">{{ readiness.attachment_exception_operator_pack.summary?.missing_attachments || 0 }} 个缺失附件</el-tag>
                  <el-tag type="warning">{{ readiness.attachment_exception_operator_pack.summary?.pending_decisions || 0 }} 个待决策</el-tag>
                  <el-tag type="success">{{ readiness.attachment_exception_operator_pack.summary?.patch_rows || 0 }} 行 patch</el-tag>
                  <el-tag :type="readinessStatusType(readiness.attachment_exception_operator_pack_validation?.overall_status)">
                    操作包校验 {{ readiness.attachment_exception_operator_pack_validation?.overall_status || 'missing' }}
                  </el-tag>
                  <span>{{ nextStepTitle(readiness.attachment_exception_operator_pack.next_step) }}</span>
                </div>
                <el-table :data="readiness.attachment_exception_operator_pack.steps || []" border class="preview-section-table">
                  <el-table-column prop="order" label="#" width="60" />
                  <el-table-column prop="title" label="步骤" min-width="220" />
                  <el-table-column label="状态" width="110">
                    <template #default="{ row }">
                      <el-tag :type="readinessStatusType(row.status)">{{ row.status }}</el-tag>
                    </template>
                  </el-table-column>
                  <el-table-column prop="action" label="处理动作" min-width="360" />
                  <el-table-column prop="acceptance" label="验收标准" min-width="360" />
                </el-table>
                <el-table :data="operatorPackFiles" border class="preview-section-table">
                  <el-table-column prop="key" label="文件" min-width="180" />
                  <el-table-column prop="path" label="路径" min-width="420" />
                </el-table>
                <el-table
                  v-if="readiness.attachment_exception_operator_pack_validation?.issues?.length"
                  :data="readiness.attachment_exception_operator_pack_validation.issues.slice(0, 10)"
                  border
                  class="preview-section-table"
                >
                  <el-table-column prop="severity" label="级别" width="100">
                    <template #default="{ row }">
                      <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
                    </template>
                  </el-table-column>
                  <el-table-column prop="field" label="字段" min-width="180" />
                  <el-table-column prop="code" label="规则" min-width="220" />
                  <el-table-column prop="message" label="说明" min-width="420" />
                </el-table>
              </template>
              <div class="preview-summary">
                <el-tag :type="readinessStatusType(readiness.attachment_exception_confirmation.overall_status)">
                  {{ readiness.attachment_exception_confirmation.overall_status }}
                </el-tag>
                <el-tag type="info">{{ readiness.attachment_exception_confirmation.summary?.total_blocked_attachments || 0 }} 个缺失附件</el-tag>
                <el-tag type="success">{{ readiness.attachment_exception_confirmation.summary?.ready_decisions || 0 }} 个已确认</el-tag>
                <el-tag type="warning">{{ readiness.attachment_exception_confirmation.summary?.pending_decisions || 0 }} 个待确认</el-tag>
                <el-tag :type="readiness.attachment_exception_confirmation.summary?.blocked_decisions ? 'danger' : 'info'">
                  {{ readiness.attachment_exception_confirmation.summary?.blocked_decisions || 0 }} 个阻断决策
                </el-tag>
              </div>
              <el-table :data="readiness.attachment_exception_confirmation.items || []" border class="preview-section-table">
                <el-table-column prop="legacy_project_id" label="项目ID" width="100" />
                <el-table-column prop="field" label="字段" width="90" />
                <el-table-column label="状态" width="110">
                  <template #default="{ row }">
                    <el-tag :type="readinessStatusType(row.status)">{{ row.status }}</el-tag>
                  </template>
                </el-table-column>
                <el-table-column prop="source_path" label="旧路径" min-width="280" />
                <el-table-column label="决策" min-width="180">
                  <template #default="{ row }">{{ row.decision || '待选择 recover / exception' }}</template>
                </el-table-column>
                <el-table-column label="缺失项" min-width="220">
                  <template #default="{ row }">{{ (row.warnings || []).join(', ') || '-' }}</template>
                </el-table-column>
                <el-table-column prop="replacement_path" label="替换路径" min-width="220" />
                <el-table-column prop="exception_reason" label="例外原因" min-width="220" />
                <el-table-column prop="approved_by" label="审批人" min-width="140" />
                <el-table-column prop="action" label="处理动作" min-width="340" />
              </el-table>
              <el-divider content-position="left">业务确认 Worksheet</el-divider>
              <el-alert v-if="!readiness.attachment_exception_worksheet" title="尚未生成 legacy-attachment-exception-worksheet.json，请先运行 scripts/New-LegacyAttachmentExceptionWorksheet.ps1。" type="info" show-icon :closable="false" />
              <template v-else>
                <div class="preview-summary">
                  <el-tag :type="readinessStatusType(readiness.attachment_exception_worksheet.overall_status)">
                    {{ readiness.attachment_exception_worksheet.overall_status }}
                  </el-tag>
                  <el-tag type="info">{{ readiness.attachment_exception_worksheet.summary?.worksheet_rows || 0 }} 行</el-tag>
                  <el-tag type="warning">{{ readiness.attachment_exception_worksheet.summary?.pending_rows || 0 }} 行待处理</el-tag>
                  <span>{{ readiness.attachment_exception_worksheet.csv_path }}</span>
                </div>
                <el-table :data="readiness.attachment_exception_worksheet.rows || []" border class="preview-section-table">
                  <el-table-column prop="legacy_project_id" label="项目ID" width="100" />
                  <el-table-column prop="field" label="字段" width="90" />
                  <el-table-column prop="current_status" label="状态" width="110" />
                  <el-table-column prop="source_path" label="旧路径" min-width="260" />
                  <el-table-column prop="missing_fields" label="缺失项" min-width="220" />
                  <el-table-column prop="suggested_decision" label="建议决策" width="110" />
                  <el-table-column prop="decision" label="回填决策" width="110" />
                  <el-table-column prop="replacement_path" label="替换路径" min-width="220" />
                  <el-table-column prop="exception_reason" label="例外原因" min-width="240" />
                  <el-table-column prop="approved_by" label="审批人" min-width="140" />
                  <el-table-column prop="acceptance" label="验收标准" min-width="360" />
                </el-table>
                <el-divider content-position="left">Worksheet 回填预览</el-divider>
                <el-alert v-if="!readiness.attachment_exception_worksheet_import_preview" title="尚未生成 legacy-attachment-exception-worksheet-import-preview.json，请先运行 scripts/New-LegacyAttachmentExceptionWorksheetImportPreview.ps1。" type="info" show-icon :closable="false" />
                <template v-else>
                  <div class="preview-summary">
                    <el-tag :type="readinessStatusType(readiness.attachment_exception_worksheet_import_preview.overall_status)">
                      {{ readiness.attachment_exception_worksheet_import_preview.overall_status }}
                    </el-tag>
                    <el-tag type="success">{{ readiness.attachment_exception_worksheet_import_preview.summary?.ready_rows || 0 }} 条 ready</el-tag>
                    <el-tag type="warning">{{ readiness.attachment_exception_worksheet_import_preview.summary?.pending_rows || 0 }} 条 pending</el-tag>
                    <el-tag :type="readiness.attachment_exception_worksheet_import_preview.summary?.blocked_rows ? 'danger' : 'info'">
                      {{ readiness.attachment_exception_worksheet_import_preview.summary?.blocked_rows || 0 }} 条 blocked
                    </el-tag>
                  </div>
                  <el-table :data="readiness.attachment_exception_worksheet_import_preview.items || []" border class="preview-section-table">
                    <el-table-column prop="legacy_project_id" label="项目ID" width="100" />
                    <el-table-column prop="field" label="字段" width="90" />
                    <el-table-column label="状态" width="110">
                      <template #default="{ row }">
                        <el-tag :type="readinessStatusType(row.status)">{{ row.status }}</el-tag>
                      </template>
                    </el-table-column>
                    <el-table-column prop="decision" label="决策" width="110" />
                    <el-table-column label="告警" min-width="220">
                      <template #default="{ row }">{{ (row.warnings || []).join(', ') || '-' }}</template>
                    </el-table-column>
                    <el-table-column label="预览变更" min-width="360">
                      <template #default="{ row }">{{ formatPreviewChanges(row.preview_changes) }}</template>
                    </el-table-column>
                    <el-table-column prop="action" label="处理动作" min-width="340" />
                  </el-table>
                  <el-divider content-position="left">模板 Patch 预览</el-divider>
                  <el-alert v-if="!readiness.attachment_exception_template_patch_preview" title="尚未生成 legacy-attachment-exception-template-patch-preview.json，请先运行 scripts/New-LegacyAttachmentExceptionTemplatePatchPreview.ps1。" type="info" show-icon :closable="false" />
                  <template v-else>
                    <div class="preview-summary">
                      <el-tag :type="readinessStatusType(readiness.attachment_exception_template_patch_preview.overall_status)">
                        {{ readiness.attachment_exception_template_patch_preview.overall_status }}
                      </el-tag>
                      <el-tag :type="readiness.attachment_exception_template_patch_preview.summary?.ready_patch_rows ? 'success' : 'warning'">
                        {{ readiness.attachment_exception_template_patch_preview.summary?.ready_patch_rows || 0 }} 行 patch
                      </el-tag>
                      <el-tag type="warning">{{ readiness.attachment_exception_template_patch_preview.summary?.source_pending_rows || 0 }} 行来源待处理</el-tag>
                      <span>{{ readiness.attachment_exception_template_patch_preview.patch_csv_path }}</span>
                    </div>
                    <el-table :data="readiness.attachment_exception_template_patch_preview.rows || []" border class="preview-section-table">
                      <el-table-column prop="legacy_project_id" label="项目ID" width="100" />
                      <el-table-column prop="field" label="字段" width="90" />
                      <el-table-column prop="decision" label="决策" width="110" />
                      <el-table-column prop="replacement_path" label="替换路径" min-width="220" />
                      <el-table-column prop="exception_reason" label="例外原因" min-width="240" />
                      <el-table-column prop="approved_by" label="审批人" min-width="140" />
                    </el-table>
                  </template>
                </template>
              </template>
            </template>
            <el-divider content-position="left">执行结果</el-divider>
            <el-alert v-if="!readiness.attachment_import_execute" title="尚未执行附件复制。确认 dry-run 后，可手动运行 scripts/Invoke-LegacyAttachmentImportDryRun.ps1 -Execute。" type="info" show-icon :closable="false" />
            <template v-else>
              <div class="preview-summary">
                <el-tag type="success">{{ readiness.attachment_import_execute.summary?.copied_items || 0 }} 个已复制</el-tag>
                <el-tag :type="readiness.attachment_import_execute.summary?.copy_failed_items ? 'danger' : 'info'">
                  {{ readiness.attachment_import_execute.summary?.copy_failed_items || 0 }} 个失败
                </el-tag>
                <el-tag type="info">已复制：{{ formatBytes(readiness.attachment_import_execute.summary?.copied_bytes || 0) }}</el-tag>
                <el-tag :type="readiness.attachment_import_execute.summary?.skipped_items ? 'warning' : 'info'">
                  {{ readiness.attachment_import_execute.summary?.skipped_items || 0 }} 个跳过
                </el-tag>
              </div>
              <el-table :data="readiness.attachment_import_execute.samples?.blocked || []" border class="preview-section-table">
                <el-table-column prop="legacy_project_id" label="项目ID" width="100" />
                <el-table-column prop="copy_status" label="复制状态" width="110" />
                <el-table-column prop="source_path" label="旧路径" min-width="220" />
                <el-table-column prop="target_path" label="新路径" min-width="260" />
                <el-table-column label="告警" min-width="240">
                  <template #default="{ row }">{{ (row.warnings || []).join(', ') || '-' }}</template>
                </el-table-column>
              </el-table>
            </template>
            <el-divider content-position="left">项目 ID 映射</el-divider>
            <el-alert v-if="!readiness.project_id_map" title="尚未生成 legacy-project-id-map.json，请先运行 scripts/New-LegacyProjectIdMap.ps1。" type="info" show-icon :closable="false" />
            <template v-else>
              <div class="preview-summary">
                <el-tag type="info">{{ readiness.project_id_map.summary?.total_projects || 0 }} 个旧项目</el-tag>
                <el-tag type="success">{{ readiness.project_id_map.summary?.mapped_projects || 0 }} 个已映射</el-tag>
                <el-tag :type="readiness.project_id_map.summary?.pending_projects ? 'warning' : 'info'">
                  {{ readiness.project_id_map.summary?.pending_projects || 0 }} 个待映射
                </el-tag>
                <el-tag v-if="readiness.project_id_map_mock" type="success">
                  Mock 已映射 {{ readiness.project_id_map_mock.summary?.mapped_projects || 0 }} 个
                </el-tag>
              </div>
              <el-table :data="readiness.project_id_map.samples?.pending || []" border class="preview-section-table">
                <el-table-column prop="legacy_project_id" label="旧项目ID" width="110" />
                <el-table-column prop="new_project_id" label="新项目ID" width="110" />
                <el-table-column prop="status" label="状态" width="180" />
                <el-table-column prop="attachment_count" label="附件数" width="90" />
                <el-table-column prop="ready_attachment_count" label="可用附件" width="100" />
                <el-table-column prop="blocked_attachment_count" label="阻断附件" width="100" />
                <el-table-column label="告警" min-width="220">
                  <template #default="{ row }">{{ (row.warnings || []).join(', ') || '-' }}</template>
                </el-table-column>
              </el-table>
            </template>
            <el-divider content-position="left">数据库记录预览</el-divider>
            <el-alert v-if="!readiness.project_file_db_dry_run" title="尚未生成 legacy-project-file-db-dry-run.json，请先运行 scripts/New-LegacyProjectFileDbDryRun.ps1。" type="info" show-icon :closable="false" />
            <template v-else>
              <div class="preview-summary">
                <el-tag type="success">{{ readiness.project_file_db_dry_run.summary?.ready_for_import || 0 }} 条可入库</el-tag>
                <el-tag type="success">{{ readiness.project_file_db_dry_run.summary?.ready_for_project_mapping || 0 }} 条等待项目映射</el-tag>
                <el-tag :type="readiness.project_file_db_dry_run.summary?.blocked_records ? 'danger' : 'info'">
                  {{ readiness.project_file_db_dry_run.summary?.blocked_records || 0 }} 条阻断
                </el-tag>
                <el-tag type="info">目标表：{{ readiness.project_file_db_dry_run.target_table }}</el-tag>
                <el-tag v-if="readiness.project_file_db_dry_run_mock" type="success">
                  Mock 可入库 {{ readiness.project_file_db_dry_run_mock.summary?.ready_for_import || 0 }} 条
                </el-tag>
              </div>
              <el-table :data="readiness.project_file_db_dry_run.by_purpose || []" border>
                <el-table-column prop="purpose" label="用途" min-width="220" />
                <el-table-column prop="count" label="数量" width="100" />
              </el-table>
              <div v-if="projectFileDbBlockerRows.length" class="preview-summary">
                <el-tag v-for="item in projectFileDbBlockerRows" :key="item.reason" type="danger">
                  {{ blockerLabel(item.reason) }} {{ item.count }}
                </el-tag>
              </div>
              <el-table v-if="readiness.project_file_db_dry_run.samples?.blocked?.length" :data="readiness.project_file_db_dry_run.samples.blocked" border class="preview-section-table">
                <el-table-column prop="legacy_project_id" label="旧项目ID" width="100" />
                <el-table-column prop="legacy_id" label="旧附件ID" width="160" />
                <el-table-column prop="disk" label="磁盘" width="100" />
                <el-table-column prop="path" label="存储路径" min-width="260" />
                <el-table-column prop="original_name" label="原文件名" min-width="220" />
                <el-table-column label="阻断原因" min-width="260">
                  <template #default="{ row }">{{ formatBlockers(row) }}</template>
                </el-table-column>
              </el-table>
              <el-table :data="readiness.project_file_db_dry_run.samples?.ready || []" border class="preview-section-table">
                <el-table-column prop="legacy_project_id" label="旧项目ID" width="100" />
                <el-table-column prop="legacy_id" label="旧附件ID" width="160" />
                <el-table-column prop="path" label="存储路径" min-width="260" />
                <el-table-column prop="original_name" label="原文件名" min-width="220" />
                <el-table-column label="告警" min-width="220">
                  <template #default="{ row }">{{ (row.warnings || []).join(', ') || '-' }}</template>
                </el-table-column>
              </el-table>
            </template>
          </template>
        </template>
      </template>
    </el-card>

    <el-card shadow="never">
      <template #header>项目核心数据</template>
      <el-alert v-if="!readiness.project_db_dry_run" title="尚未生成 legacy-project-db-dry-run.json，请先运行 scripts/New-LegacyProjectDbDryRun.ps1。" type="info" show-icon :closable="false" />
      <template v-else>
        <div class="preview-summary">
          <el-tag type="info">{{ readiness.project_db_dry_run.summary?.total_records || 0 }} 个旧项目</el-tag>
          <el-tag type="success">{{ readiness.project_db_dry_run.summary?.ready_for_import || 0 }} 个可入库</el-tag>
          <el-tag :type="readiness.project_db_dry_run.summary?.ready_for_unit_user_mapping ? 'warning' : 'info'">
            {{ readiness.project_db_dry_run.summary?.ready_for_unit_user_mapping || 0 }} 个等待单位/用户映射
          </el-tag>
          <el-tag v-if="readiness.project_db_dry_run_mock" type="success">
            Mock 可入库 {{ readiness.project_db_dry_run_mock.summary?.ready_for_import || 0 }} 个
          </el-tag>
        </div>
        <el-divider content-position="left">单位/用户 ID 映射</el-divider>
        <el-alert v-if="!readiness.unit_user_id_map" title="尚未生成 legacy-unit-user-id-map.json，请先运行 scripts/New-LegacyUnitUserIdMap.ps1。" type="info" show-icon :closable="false" />
        <template v-else>
          <div class="preview-summary">
            <el-tag type="info">{{ readiness.unit_user_id_map.summary?.total_units || 0 }} 个旧单位</el-tag>
            <el-tag type="success">{{ readiness.unit_user_id_map.summary?.mapped_units || 0 }} 个已映射</el-tag>
            <el-tag :type="readiness.unit_user_id_map.summary?.pending_units ? 'warning' : 'info'">
              {{ readiness.unit_user_id_map.summary?.pending_units || 0 }} 个待映射
            </el-tag>
            <el-tag v-if="readiness.unit_user_id_map_mock" type="success">
              Mock 已映射 {{ readiness.unit_user_id_map_mock.summary?.mapped_units || 0 }} 个
            </el-tag>
          </div>
          <el-table :data="readiness.unit_user_id_map.samples?.pending || []" border class="preview-section-table">
            <el-table-column prop="legacy_unit_id" label="旧单位ID" width="100" />
            <el-table-column prop="unit_id" label="新单位ID" width="110" />
            <el-table-column prop="owner_id" label="负责人ID" width="110" />
            <el-table-column prop="status" label="状态" width="180" />
            <el-table-column prop="project_count" label="项目数" width="90" />
            <el-table-column label="告警" min-width="220">
              <template #default="{ row }">{{ (row.warnings || []).join(', ') || '-' }}</template>
            </el-table-column>
          </el-table>
        </template>
        <el-row :gutter="12">
          <el-col :span="12">
            <el-table :data="readiness.project_db_dry_run.by_status || []" border>
              <el-table-column prop="status" label="项目状态" min-width="120" />
              <el-table-column prop="count" label="数量" width="100" />
            </el-table>
          </el-col>
          <el-col :span="12">
            <el-table :data="(readiness.project_db_dry_run.by_category || []).slice(0, 8)" border>
              <el-table-column prop="category" label="类别" min-width="120" />
              <el-table-column prop="count" label="数量" width="100" />
            </el-table>
          </el-col>
        </el-row>
        <el-table :data="readiness.project_db_dry_run.samples?.records || []" border class="preview-section-table">
          <el-table-column prop="legacy_id" label="旧项目ID" width="100" />
          <el-table-column prop="legacy_unit_id" label="旧单位ID" width="100" />
          <el-table-column prop="title" label="项目名称" min-width="260" />
          <el-table-column prop="status" label="状态" width="110" />
          <el-table-column label="告警" min-width="220">
            <template #default="{ row }">{{ (row.warnings || []).join(', ') || '-' }}</template>
          </el-table-column>
        </el-table>
      </template>
    </el-card>

    <el-card shadow="never">
      <template #header>单位/用户核心数据</template>
      <el-alert v-if="!readiness.unit_user_db_dry_run" title="尚未生成 legacy-unit-user-db-dry-run.json，请先运行 scripts/New-LegacyUnitUserDbDryRun.ps1。" type="info" show-icon :closable="false" />
      <template v-else>
        <div class="preview-summary">
          <el-tag type="success">{{ readiness.unit_user_db_dry_run.summary?.ready_units || 0 }} 个单位可入库</el-tag>
          <el-tag type="success">{{ readiness.unit_user_db_dry_run.summary?.ready_users || 0 }} 个后台用户可入库</el-tag>
          <el-tag type="warning">{{ readiness.unit_user_db_dry_run.summary?.users_waiting_unit_mapping || 0 }} 个单位账号等待单位映射</el-tag>
          <el-tag type="info">{{ readiness.unit_user_db_dry_run.summary?.password_reset_required || 0 }} 个账号需重置密码</el-tag>
          <el-tag v-if="readiness.unit_user_db_dry_run_mock" type="success">
            Mock 用户可入库 {{ readiness.unit_user_db_dry_run_mock.summary?.ready_users || 0 }} 个
          </el-tag>
        </div>
        <el-row :gutter="12">
          <el-col :span="12">
            <el-table :data="readiness.unit_user_db_dry_run.user_by_role || []" border>
              <el-table-column prop="role" label="角色" min-width="120" />
              <el-table-column prop="count" label="数量" width="100" />
            </el-table>
          </el-col>
          <el-col :span="12">
            <el-table :data="readiness.unit_user_db_dry_run.user_by_status || []" border>
              <el-table-column prop="status" label="状态" min-width="180" />
              <el-table-column prop="count" label="数量" width="100" />
            </el-table>
          </el-col>
        </el-row>
        <el-table :data="readiness.unit_user_db_dry_run.samples?.units || []" border class="preview-section-table">
          <el-table-column prop="legacy_id" label="旧单位ID" width="100" />
          <el-table-column prop="name" label="单位名称" min-width="260" />
          <el-table-column prop="credit_code" label="信用代码" min-width="180" />
          <el-table-column prop="status" label="状态" width="100" />
        </el-table>
      </template>
    </el-card>

    <el-card shadow="never">
      <template #header>字段映射预览</template>
      <el-alert v-if="!readiness.preview" title="尚未生成 legacy-migration-preview.json，请先运行 scripts/New-LegacyMigrationPreview.ps1。" type="info" show-icon :closable="false" />
      <template v-else>
        <div class="preview-summary">
          <el-tag :type="readiness.preview.summary?.empty_sections ? 'warning' : 'success'">
            {{ readiness.preview.summary?.total_sections || readiness.preview.section_count || 0 }} 个映射段
          </el-tag>
          <el-tag :type="readiness.preview.summary?.warning_sections ? 'warning' : 'info'">
            {{ readiness.preview.summary?.warning_sections || 0 }} 个段有告警
          </el-tag>
          <span>样本量：{{ readiness.preview.sample_size || 0 }}</span>
        </div>
        <el-alert
          v-if="(readiness.preview.warnings || []).length"
          :title="`预览质量告警：${readiness.preview.warnings.join(', ')}`"
          type="warning"
          show-icon
          :closable="false"
        />
        <el-table :data="readiness.preview.sections || []" border class="preview-section-table">
          <el-table-column prop="source_table" label="旧表" width="150" />
          <el-table-column prop="target_table" label="新表" width="160" />
          <el-table-column prop="row_count" label="预览行数" width="110" />
          <el-table-column label="告警" min-width="260">
            <template #default="{ row }">{{ (row.warnings || []).join(', ') || '-' }}</template>
          </el-table-column>
        </el-table>
      </template>
      <el-tabs v-if="readiness.preview">
        <el-tab-pane v-for="section in readiness.preview.sections" :key="`${section.source_table}-${section.target_table}`" :label="sectionTabLabel(section)">
          <el-alert
            v-if="(section.warnings || []).length"
            :title="`当前映射段告警：${section.warnings.join(', ')}`"
            type="warning"
            show-icon
            :closable="false"
          />
          <el-table :data="section.rows" border>
            <el-table-column prop="target_table" label="新表" width="140" />
            <el-table-column label="核心字段" min-width="360">
              <template #default="{ row }">
                <pre class="json-cell">{{ compactRow(row) }}</pre>
              </template>
            </el-table-column>
            <el-table-column label="元数据" min-width="300">
              <template #default="{ row }">
                <pre class="json-cell">{{ JSON.stringify(row.metadata || {}, null, 2) }}</pre>
              </template>
            </el-table-column>
          </el-table>
        </el-tab-pane>
      </el-tabs>
    </el-card>

    <el-card shadow="never">
      <template #header>报告流水线</template>
      <div class="preview-summary">
        <el-tag type="info">默认只生成报告</el-tag>
        <el-tag type="warning">Mock 仅用于链路验证</el-tag>
      </div>
      <el-table :data="pipelineSteps" border>
        <el-table-column prop="step" label="步骤" width="90" />
        <el-table-column prop="name" label="报告" min-width="220" />
        <el-table-column prop="command" label="脚本" min-width="360" />
      </el-table>
    </el-card>

    <el-card shadow="never">
      <template #header>报告归档清单</template>
      <el-alert v-if="!readiness.migration_artifact_manifest" title="尚未生成 legacy-migration-artifact-manifest.json，请先运行 scripts/New-LegacyMigrationArtifactManifest.ps1。" type="info" show-icon :closable="false" />
      <template v-else>
        <div class="preview-summary">
          <el-tag type="info">{{ readiness.migration_artifact_manifest.summary?.total_artifacts || 0 }} 个归档项</el-tag>
          <el-tag type="success">{{ readiness.migration_artifact_manifest.summary?.existing_artifacts || 0 }} 个已生成</el-tag>
          <el-tag :type="readiness.migration_artifact_manifest.summary?.missing_required ? 'danger' : 'info'">
            {{ readiness.migration_artifact_manifest.summary?.missing_required || 0 }} 个必需项缺失
          </el-tag>
          <el-tag type="warning">{{ readiness.migration_artifact_manifest.summary?.missing_optional || 0 }} 个可选项缺失</el-tag>
          <el-tag :type="readinessStatusType(readiness.migration_artifact_manifest_validation?.overall_status)">
            校验 {{ readiness.migration_artifact_manifest_validation?.overall_status || 'missing' }}
          </el-tag>
          <el-tag :type="readiness.migration_artifact_manifest_validation?.summary?.unknown_dependencies ? 'warning' : 'info'">
            未知依赖 {{ readiness.migration_artifact_manifest_validation?.summary?.unknown_dependencies || 0 }}
          </el-tag>
        </div>
        <el-table :data="readiness.migration_artifact_manifest.artifacts || []" border>
          <el-table-column prop="key" label="键" min-width="220" />
          <el-table-column prop="type" label="类型" width="120" />
          <el-table-column label="状态" width="110">
            <template #default="{ row }">
              <el-tag :type="row.exists ? 'success' : (row.required ? 'danger' : 'warning')">
                {{ row.exists ? '存在' : '缺失' }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="purpose" label="用途" min-width="260" />
          <el-table-column prop="updated_at" label="更新时间" width="220" />
        </el-table>
        <el-table
          v-if="readiness.migration_artifact_manifest_validation?.issues?.length"
          :data="readiness.migration_artifact_manifest_validation.issues.slice(0, 10)"
          border
          class="preview-section-table"
        >
          <el-table-column prop="severity" label="级别" width="100">
            <template #default="{ row }">
              <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="field" label="字段" min-width="220" />
          <el-table-column prop="code" label="规则" min-width="220" />
          <el-table-column prop="message" label="说明" min-width="420" />
        </el-table>
      </template>
    </el-card>

    <el-card shadow="never">
      <template #header>执行前置条件</template>
      <el-alert v-if="!readiness.migration_preflight_checklist" title="尚未生成 legacy-migration-preflight-checklist.json，请先运行 scripts/New-LegacyMigrationPreflightChecklist.ps1。" type="info" show-icon :closable="false" />
      <template v-else>
        <div class="preview-summary">
          <el-tag :type="readinessStatusType(readiness.migration_preflight_checklist.overall_status)">
            {{ readiness.migration_preflight_checklist.overall_status }}
          </el-tag>
          <el-tag type="danger">{{ readiness.migration_preflight_checklist.summary?.blockers || 0 }} 个阻断</el-tag>
          <el-tag type="warning">{{ readiness.migration_preflight_checklist.summary?.warnings || 0 }} 个警告</el-tag>
          <el-tag type="info">{{ readiness.migration_preflight_checklist.summary?.info || 0 }} 个提示</el-tag>
          <el-tag type="success">{{ readiness.migration_preflight_checklist.summary?.done || 0 }} 个完成</el-tag>
          <el-tag :type="readinessStatusType(readiness.migration_preflight_checklist_validation?.overall_status)">
            校验 {{ readiness.migration_preflight_checklist_validation?.overall_status || 'missing' }}
          </el-tag>
          <el-tag :type="readiness.migration_preflight_checklist_validation?.summary?.summary_mismatches ? 'danger' : 'info'">
            汇总偏差 {{ readiness.migration_preflight_checklist_validation?.summary?.summary_mismatches || 0 }}
          </el-tag>
        </div>
        <el-table :data="readiness.migration_preflight_checklist.items || []" border>
          <el-table-column prop="category" label="类别" width="140" />
          <el-table-column label="级别" width="110">
            <template #default="{ row }">
              <el-tag :type="row.severity === 'blocker' ? 'danger' : row.severity === 'warning' ? 'warning' : 'info'">{{ row.severity }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="title" label="事项" min-width="240" />
          <el-table-column prop="source" label="来源" min-width="180" />
          <el-table-column prop="status" label="状态" width="100" />
          <el-table-column prop="action" label="处理建议" min-width="320" />
        </el-table>
        <el-table
          v-if="readiness.migration_preflight_checklist_validation?.issues?.length"
          :data="readiness.migration_preflight_checklist_validation.issues.slice(0, 10)"
          border
          class="preview-section-table"
        >
          <el-table-column prop="severity" label="级别" width="100">
            <template #default="{ row }">
              <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="field" label="字段" min-width="220" />
          <el-table-column prop="code" label="规则" min-width="220" />
          <el-table-column prop="message" label="说明" min-width="420" />
        </el-table>
      </template>
    </el-card>

    <el-card shadow="never">
      <template #header>Preflight 阻断处置</template>
      <el-alert v-if="!readiness.migration_preflight_blocker_operator_pack" title="尚未生成 legacy-migration-preflight-blocker-operator-pack.json，请先运行 scripts/New-LegacyMigrationPreflightBlockerOperatorPack.ps1。" type="info" show-icon :closable="false" />
      <template v-else>
        <div class="preview-summary">
          <el-tag :type="readinessStatusType(readiness.migration_preflight_blocker_operator_pack.overall_status)">
            {{ readiness.migration_preflight_blocker_operator_pack.overall_status }}
          </el-tag>
          <el-tag :type="readiness.migration_preflight_blocker_operator_pack.summary?.blockers ? 'danger' : 'info'">
            {{ readiness.migration_preflight_blocker_operator_pack.summary?.blockers || 0 }} 个 blocker
          </el-tag>
          <el-tag :type="readiness.migration_preflight_blocker_operator_pack.summary?.warnings ? 'warning' : 'info'">
            {{ readiness.migration_preflight_blocker_operator_pack.summary?.warnings || 0 }} 个 warning
          </el-tag>
          <el-tag type="info">{{ readiness.migration_preflight_blocker_operator_pack.summary?.owner_count || 0 }} 个负责人</el-tag>
          <el-tag :type="readinessStatusType(readiness.migration_preflight_blocker_operator_pack_validation?.overall_status)">
            操作包校验 {{ readiness.migration_preflight_blocker_operator_pack_validation?.overall_status || 'missing' }}
          </el-tag>
          <span>{{ readiness.migration_preflight_blocker_operator_pack.next_action?.title || '-' }}</span>
        </div>
        <el-table :data="readiness.migration_preflight_blocker_operator_pack.owners || []" border class="preview-section-table">
          <el-table-column prop="owner" label="负责人" min-width="160" />
          <el-table-column prop="total_actions" label="行动项" width="100" />
          <el-table-column prop="blockers" label="blocker" width="100" />
          <el-table-column prop="warnings" label="warning" width="100" />
          <el-table-column prop="categories" label="类别" min-width="300">
            <template #default="{ row }">{{ formatList(row.categories) }}</template>
          </el-table-column>
        </el-table>
        <el-table :data="readiness.migration_preflight_blocker_operator_pack.top_actions || []" border class="preview-section-table">
          <el-table-column prop="priority" label="优先级" width="90" />
          <el-table-column prop="severity" label="级别" width="110">
            <template #default="{ row }">
              <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="owner" label="负责人" min-width="150" />
          <el-table-column prop="category" label="类别" min-width="180" />
          <el-table-column prop="title" label="事项" min-width="320" />
          <el-table-column prop="action" label="处理动作" min-width="360" />
          <el-table-column prop="acceptance" label="验收标准" min-width="360" />
        </el-table>
        <el-table
          v-if="readiness.migration_preflight_blocker_operator_pack_validation?.issues?.length"
          :data="readiness.migration_preflight_blocker_operator_pack_validation.issues.slice(0, 10)"
          border
          class="preview-section-table"
        >
          <el-table-column prop="severity" label="级别" width="100">
            <template #default="{ row }">
              <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="field" label="字段" min-width="180" />
          <el-table-column prop="code" label="规则" min-width="220" />
          <el-table-column prop="message" label="说明" min-width="420" />
        </el-table>
      </template>
    </el-card>
    <el-card shadow="never">
      <template #header>上线总闸门</template>
      <el-alert v-if="!readiness.migration_go_live_gate" title="尚未生成 legacy-migration-go-live-gate.json，请先运行 scripts/New-LegacyMigrationGoLiveGate.ps1。" type="info" show-icon :closable="false" />
      <template v-else>
        <div class="preview-summary">
          <el-tag :type="readinessStatusType(readiness.migration_go_live_gate.overall_status)">
            {{ readiness.migration_go_live_gate.overall_status }}
          </el-tag>
          <el-tag :type="readiness.migration_go_live_gate.write_cutover_ready ? 'success' : 'danger'">
            {{ readiness.migration_go_live_gate.write_cutover_ready ? '可进入写入窗口' : '禁止写入切换' }}
          </el-tag>
          <el-tag type="success">{{ readiness.migration_go_live_gate.summary?.passed_gates || 0 }} 项通过</el-tag>
          <el-tag type="warning">{{ readiness.migration_go_live_gate.summary?.open_gates || 0 }} 项待处理</el-tag>
          <el-tag :type="readiness.migration_go_live_gate.summary?.blockers ? 'danger' : 'info'">
            {{ readiness.migration_go_live_gate.summary?.blockers || 0 }} 个 blocker
          </el-tag>
          <el-tag type="info">完成 {{ readiness.migration_go_live_gate.summary?.completion_percent || 0 }}%</el-tag>
          <el-tag :type="readinessStatusType(readiness.migration_go_live_gate_validation?.overall_status)">
            校验 {{ readiness.migration_go_live_gate_validation?.overall_status || 'missing' }}
          </el-tag>
          <el-tag :type="readiness.migration_go_live_gate_validation?.summary?.summary_mismatches ? 'danger' : 'info'">
            汇总偏差 {{ readiness.migration_go_live_gate_validation?.summary?.summary_mismatches || 0 }}
          </el-tag>
          <span>{{ nextStepTitle(readiness.migration_go_live_gate.next_step) }}</span>
        </div>
        <el-table :data="readiness.migration_go_live_gate.gates || []" border>
          <el-table-column prop="title" label="闸门" min-width="240" />
          <el-table-column label="状态" width="110">
            <template #default="{ row }">
              <el-tag :type="readinessStatusType(row.status)">{{ row.status }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="severity" label="级别" width="100" />
          <el-table-column prop="evidence" label="证据" min-width="300" />
          <el-table-column prop="action" label="处理动作" min-width="320" />
          <el-table-column prop="acceptance" label="验收标准" min-width="320" />
        </el-table>
        <el-table
          v-if="readiness.migration_go_live_gate_validation?.issues?.length"
          :data="readiness.migration_go_live_gate_validation.issues.slice(0, 10)"
          border
          class="preview-section-table"
        >
          <el-table-column prop="severity" label="级别" width="100">
            <template #default="{ row }">
              <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="field" label="字段" min-width="220" />
          <el-table-column prop="code" label="规则" min-width="220" />
          <el-table-column prop="message" label="说明" min-width="420" />
        </el-table>
        <div class="preview-summary">
          <el-tag :type="readinessStatusType(readiness.migration_go_live_signoff_operator_pack?.overall_status)">
            角色操作包 {{ readiness.migration_go_live_signoff_operator_pack?.overall_status || 'missing' }}
          </el-tag>
          <el-tag type="info">{{ readiness.migration_go_live_signoff_operator_pack?.summary?.signoff_items || 0 }} 个角色</el-tag>
          <el-tag type="warning">{{ readiness.migration_go_live_signoff_operator_pack?.summary?.pending_items || 0 }} 个 pending</el-tag>
          <el-tag type="success">{{ readiness.migration_go_live_signoff_operator_pack?.summary?.signed_items || 0 }} 个 signed</el-tag>
          <el-tag type="info">{{ readiness.migration_go_live_signoff_operator_pack?.summary?.accepted_with_risk_items || 0 }} 个 risk accepted</el-tag>
          <el-tag :type="readiness.migration_go_live_signoff_operator_pack?.summary?.validation_blockers ? 'danger' : 'info'">
            {{ readiness.migration_go_live_signoff_operator_pack?.summary?.validation_blockers || 0 }} 个校验 blocker
          </el-tag>
          <el-tag :type="readinessStatusType(readiness.migration_go_live_signoff_operator_pack_validation?.overall_status)">
            操作包校验 {{ readiness.migration_go_live_signoff_operator_pack_validation?.overall_status || 'missing' }}
          </el-tag>
        </div>
        <el-table :data="readiness.migration_go_live_signoff_operator_pack?.roles || []" border class="preview-section-table">
          <el-table-column prop="role_name" label="角色" min-width="160" />
          <el-table-column prop="status" label="状态" width="120">
            <template #default="{ row }">
              <el-tag :type="readinessStatusType(row.status)">{{ row.status }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="owner" label="负责人" min-width="140" />
          <el-table-column prop="confirmation" label="确认内容" min-width="360" />
          <el-table-column prop="evidence" label="证据" min-width="320" />
          <el-table-column prop="signed_by" label="签署人" min-width="130" />
          <el-table-column prop="signed_at" label="签署时间" min-width="160" />
          <el-table-column prop="notes" label="备注" min-width="220" />
        </el-table>
        <el-table
          v-if="readiness.migration_go_live_signoff_operator_pack_validation?.issues?.length"
          :data="readiness.migration_go_live_signoff_operator_pack_validation.issues.slice(0, 10)"
          border
          class="preview-section-table"
        >
          <el-table-column prop="severity" label="级别" width="100">
            <template #default="{ row }">
              <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="field" label="字段" min-width="180" />
          <el-table-column prop="code" label="规则" min-width="220" />
          <el-table-column prop="message" label="说明" min-width="420" />
        </el-table>
        <div class="preview-summary">
          <el-tag :type="readinessStatusType(readiness.migration_go_live_signoff?.overall_status)">
            角色签收 {{ readiness.migration_go_live_signoff?.overall_status || 'missing' }}
          </el-tag>
          <el-tag type="warning">{{ readiness.migration_go_live_signoff?.summary?.pending_items || 0 }} 个 pending</el-tag>
          <el-tag type="success">{{ readiness.migration_go_live_signoff?.summary?.signed_items || 0 }} 个 signed</el-tag>
          <el-tag type="info">{{ readiness.migration_go_live_signoff?.summary?.accepted_with_risk_items || 0 }} 个 risk accepted</el-tag>
          <el-tag :type="readiness.migration_go_live_signoff?.summary?.rejected_items ? 'danger' : 'info'">
            {{ readiness.migration_go_live_signoff?.summary?.rejected_items || 0 }} 个 rejected
          </el-tag>
        </div>
        <el-table :data="readiness.migration_go_live_signoff?.items || []" border class="preview-section-table">
          <el-table-column prop="status" label="状态" width="140">
            <template #default="{ row }">
              <el-tag :type="readinessStatusType(row.status)">{{ row.status }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="role_name" label="角色" min-width="170" />
          <el-table-column prop="owner" label="负责人" min-width="140" />
          <el-table-column prop="confirmation" label="确认内容" min-width="360" />
          <el-table-column prop="evidence" label="证据" min-width="320" />
          <el-table-column prop="signed_by" label="签署人" min-width="130" />
          <el-table-column prop="signed_at" label="签署时间" min-width="160" />
          <el-table-column prop="notes" label="备注" min-width="240" />
        </el-table>
        <div class="preview-summary">
          <el-tag :type="readinessStatusType(readiness.migration_go_live_signoff_validation?.overall_status)">
            签收校验 {{ readiness.migration_go_live_signoff_validation?.overall_status || 'missing' }}
          </el-tag>
          <el-tag :type="readiness.migration_go_live_signoff_validation?.summary?.blockers ? 'danger' : 'info'">
            {{ readiness.migration_go_live_signoff_validation?.summary?.blockers || 0 }} 个 blocker
          </el-tag>
          <el-tag :type="readiness.migration_go_live_signoff_validation?.summary?.warnings ? 'warning' : 'info'">
            {{ readiness.migration_go_live_signoff_validation?.summary?.warnings || 0 }} 个 warning
          </el-tag>
        </div>
        <el-table :data="readiness.migration_go_live_signoff_validation?.issues || []" border class="preview-section-table">
          <el-table-column prop="severity" label="级别" width="100">
            <template #default="{ row }">
              <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="row_number" label="行号" width="90" />
          <el-table-column prop="role_key" label="角色" min-width="170" />
          <el-table-column prop="field" label="字段" min-width="130" />
          <el-table-column prop="code" label="规则" min-width="200" />
          <el-table-column prop="message" label="说明" min-width="340" />
        </el-table>
        <div class="preview-summary">
          <el-tag :type="readiness.workflow_db_dry_run ? 'success' : 'danger'">
            流程预览 {{ readiness.workflow_db_dry_run ? '已生成' : '缺失' }}
          </el-tag>
          <el-tag type="info">{{ readiness.workflow_db_dry_run?.summary?.review_records || 0 }} 条审核记录</el-tag>
          <el-tag type="info">{{ readiness.workflow_db_dry_run?.summary?.operation_log_records || 0 }} 条操作日志</el-tag>
          <el-tag :type="readiness.workflow_db_dry_run?.summary?.project_id_mapping_required ? 'warning' : 'info'">
            {{ readiness.workflow_db_dry_run?.summary?.project_id_mapping_required || 0 }} 条需项目映射
          </el-tag>
          <el-tag :type="readiness.workflow_db_dry_run?.summary?.orphan_project_references ? 'warning' : 'info'">
            {{ readiness.workflow_db_dry_run?.summary?.orphan_project_references || 0 }} 条孤立项目引用
          </el-tag>
          <el-tag :type="readiness.workflow_db_dry_run?.summary?.reviewer_id_mapping_required ? 'warning' : 'info'">
            {{ readiness.workflow_db_dry_run?.summary?.reviewer_id_mapping_required || 0 }} 条需审核人映射
          </el-tag>
        </div>
        <el-table :data="readiness.workflow_db_dry_run?.samples?.reviews || []" border class="preview-section-table">
          <el-table-column prop="db_status" label="状态" min-width="190" />
          <el-table-column prop="legacy_id" label="旧记录" min-width="160" />
          <el-table-column prop="legacy_project_id" label="旧项目" width="100" />
          <el-table-column prop="source_table" label="来源表" min-width="130" />
          <el-table-column prop="stage" label="阶段" min-width="130" />
          <el-table-column prop="decision" label="结论" min-width="180" />
          <el-table-column prop="comment_excerpt" label="意见摘要" min-width="360" />
          <el-table-column prop="reviewed_at" label="时间" min-width="160" />
        </el-table>
        <el-table :data="readiness.workflow_db_dry_run?.samples?.operation_logs || []" border class="preview-section-table">
          <el-table-column prop="legacy_id" label="旧日志" min-width="150" />
          <el-table-column prop="legacy_actor_id" label="旧用户" width="100" />
          <el-table-column prop="actor_kind" label="用户类型" min-width="120" />
          <el-table-column prop="action" label="动作" min-width="320" />
          <el-table-column prop="ip" label="IP" min-width="150" />
          <el-table-column prop="occurred_at" label="时间" min-width="160" />
        </el-table>
        <div class="preview-summary">
          <el-tag :type="readinessStatusType(readiness.workflow_orphan_operator_pack?.overall_status)">
            孤儿流程操作包 {{ readiness.workflow_orphan_operator_pack?.overall_status || 'missing' }}
          </el-tag>
          <el-tag type="info">{{ readiness.workflow_orphan_operator_pack?.summary?.legacy_project_count || 0 }} 个旧项目</el-tag>
          <el-tag type="info">{{ readiness.workflow_orphan_operator_pack?.summary?.orphan_items || 0 }} 条孤儿记录</el-tag>
          <el-tag type="warning">{{ readiness.workflow_orphan_operator_pack?.summary?.pending_items || 0 }} 个待处理</el-tag>
          <el-tag :type="readiness.workflow_orphan_operator_pack?.summary?.validation_blockers ? 'danger' : 'info'">
            {{ readiness.workflow_orphan_operator_pack?.summary?.validation_blockers || 0 }} 个校验 blocker
          </el-tag>
          <el-tag :type="readiness.workflow_orphan_operator_pack?.summary?.validation_warnings ? 'warning' : 'info'">
            {{ readiness.workflow_orphan_operator_pack?.summary?.validation_warnings || 0 }} 个校验 warning
          </el-tag>
          <el-tag :type="readinessStatusType(readiness.workflow_orphan_operator_pack_validation?.overall_status)">
            操作包校验 {{ readiness.workflow_orphan_operator_pack_validation?.overall_status || 'missing' }}
          </el-tag>
        </div>
        <el-table :data="readiness.workflow_orphan_operator_pack?.by_legacy_project || []" border class="preview-section-table">
          <el-table-column prop="legacy_project_id" label="旧项目" width="100" />
          <el-table-column prop="orphan_rows" label="孤儿行" width="100" />
          <el-table-column prop="pending_items" label="pending" width="100" />
          <el-table-column prop="archive_items" label="archive" width="100" />
          <el-table-column prop="link_items" label="link" width="100" />
          <el-table-column prop="exclude_items" label="exclude" width="100" />
          <el-table-column prop="blocked_items" label="blocked" width="100" />
          <el-table-column prop="stages" label="阶段" min-width="220">
            <template #default="{ row }">{{ formatList(row.stages) }}</template>
          </el-table-column>
          <el-table-column prop="sample_legacy_ids" label="样例记录" min-width="240">
            <template #default="{ row }">{{ formatList(row.sample_legacy_ids) }}</template>
          </el-table-column>
        </el-table>
        <el-table
          v-if="readiness.workflow_orphan_operator_pack_validation?.issues?.length"
          :data="readiness.workflow_orphan_operator_pack_validation.issues.slice(0, 10)"
          border
          class="preview-section-table"
        >
          <el-table-column prop="severity" label="级别" width="100">
            <template #default="{ row }">
              <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="field" label="字段" min-width="180" />
          <el-table-column prop="code" label="规则" min-width="220" />
          <el-table-column prop="message" label="说明" min-width="420" />
        </el-table>
        <div class="preview-summary">
          <el-tag :type="readinessStatusType(readiness.workflow_orphan_resolution_signoff?.overall_status)">
            孤儿流程处理 {{ readiness.workflow_orphan_resolution_signoff?.overall_status || 'missing' }}
          </el-tag>
          <el-tag type="info">{{ readiness.workflow_orphan_resolution_signoff?.summary?.orphan_items || 0 }} 条孤儿记录</el-tag>
          <el-tag type="warning">{{ readiness.workflow_orphan_resolution_signoff?.summary?.pending_items || 0 }} 个 pending</el-tag>
          <el-tag type="info">{{ readiness.workflow_orphan_resolution_signoff?.summary?.archive_items || 0 }} 个 archive</el-tag>
          <el-tag type="info">{{ readiness.workflow_orphan_resolution_signoff?.summary?.link_items || 0 }} 个 link</el-tag>
          <el-tag type="info">{{ readiness.workflow_orphan_resolution_signoff?.summary?.exclude_items || 0 }} 个 exclude</el-tag>
          <el-tag :type="readiness.workflow_orphan_resolution_signoff?.summary?.blocked_items ? 'danger' : 'info'">
            {{ readiness.workflow_orphan_resolution_signoff?.summary?.blocked_items || 0 }} 个 blocked
          </el-tag>
        </div>
        <el-table :data="readiness.workflow_orphan_resolution_signoff?.items || []" border class="preview-section-table">
          <el-table-column prop="decision" label="处理决定" width="130">
            <template #default="{ row }">
              <el-tag :type="readinessStatusType(row.decision)">{{ row.decision }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="legacy_id" label="旧记录" min-width="150" />
          <el-table-column prop="legacy_project_id" label="旧项目" width="100" />
          <el-table-column prop="source_table" label="来源表" min-width="130" />
          <el-table-column prop="stage" label="阶段" min-width="130" />
          <el-table-column prop="decision_text" label="原结论" min-width="220" />
          <el-table-column prop="reviewed_at" label="原时间" min-width="160" />
          <el-table-column prop="target_project_id" label="目标项目" min-width="120" />
          <el-table-column prop="approved_by" label="批准人" min-width="130" />
          <el-table-column prop="evidence_ref" label="证据" min-width="220" />
          <el-table-column prop="notes" label="备注" min-width="260" />
        </el-table>
        <div class="preview-summary">
          <el-tag :type="readinessStatusType(readiness.workflow_orphan_resolution_signoff_validation?.overall_status)">
            孤儿处理校验 {{ readiness.workflow_orphan_resolution_signoff_validation?.overall_status || 'missing' }}
          </el-tag>
          <el-tag :type="readiness.workflow_orphan_resolution_signoff_validation?.summary?.blockers ? 'danger' : 'info'">
            {{ readiness.workflow_orphan_resolution_signoff_validation?.summary?.blockers || 0 }} 个 blocker
          </el-tag>
          <el-tag :type="readiness.workflow_orphan_resolution_signoff_validation?.summary?.warnings ? 'warning' : 'info'">
            {{ readiness.workflow_orphan_resolution_signoff_validation?.summary?.warnings || 0 }} 个 warning
          </el-tag>
        </div>
        <el-table :data="readiness.workflow_orphan_resolution_signoff_validation?.issues || []" border class="preview-section-table">
          <el-table-column prop="severity" label="级别" width="100">
            <template #default="{ row }">
              <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="row_number" label="行号" width="90" />
          <el-table-column prop="legacy_id" label="旧记录" min-width="150" />
          <el-table-column prop="field" label="字段" min-width="130" />
          <el-table-column prop="code" label="规则" min-width="200" />
          <el-table-column prop="message" label="说明" min-width="340" />
        </el-table>
        <div class="preview-summary">
          <el-tag :type="readinessStatusType(readiness.migration_sampling_acceptance_operator_pack?.overall_status)">
            抽样操作包 {{ readiness.migration_sampling_acceptance_operator_pack?.overall_status || 'missing' }}
          </el-tag>
          <el-tag type="info">{{ readiness.migration_sampling_acceptance_operator_pack?.summary?.category_count || 0 }} 个类别</el-tag>
          <el-tag type="info">{{ readiness.migration_sampling_acceptance_operator_pack?.summary?.sample_items || 0 }} 个样本</el-tag>
          <el-tag type="warning">{{ readiness.migration_sampling_acceptance_operator_pack?.summary?.pending_items || 0 }} 个待验收</el-tag>
          <el-tag :type="readiness.migration_sampling_acceptance_operator_pack?.summary?.validation_blockers ? 'danger' : 'info'">
            {{ readiness.migration_sampling_acceptance_operator_pack?.summary?.validation_blockers || 0 }} 个校验 blocker
          </el-tag>
          <el-tag :type="readinessStatusType(readiness.migration_sampling_acceptance_operator_pack_validation?.overall_status)">
            操作包校验 {{ readiness.migration_sampling_acceptance_operator_pack_validation?.overall_status || 'missing' }}
          </el-tag>
        </div>
        <el-table :data="readiness.migration_sampling_acceptance_operator_pack?.by_category || []" border class="preview-section-table">
          <el-table-column prop="category" label="类别" min-width="150" />
          <el-table-column prop="sample_items" label="样本" width="90" />
          <el-table-column prop="pending_items" label="pending" width="100" />
          <el-table-column prop="passed_items" label="pass" width="90" />
          <el-table-column prop="accepted_with_risk_items" label="risk" width="90" />
          <el-table-column prop="failed_items" label="fail" width="90" />
          <el-table-column prop="blocked_items" label="blocked" width="100" />
          <el-table-column prop="sources" label="来源报告" min-width="260">
            <template #default="{ row }">{{ formatList(row.sources) }}</template>
          </el-table-column>
          <el-table-column prop="sample_keys" label="样例" min-width="320">
            <template #default="{ row }">{{ formatList(row.sample_keys) }}</template>
          </el-table-column>
        </el-table>
        <el-table
          v-if="readiness.migration_sampling_acceptance_operator_pack_validation?.issues?.length"
          :data="readiness.migration_sampling_acceptance_operator_pack_validation.issues.slice(0, 10)"
          border
          class="preview-section-table"
        >
          <el-table-column prop="severity" label="级别" width="100">
            <template #default="{ row }">
              <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="field" label="字段" min-width="180" />
          <el-table-column prop="code" label="规则" min-width="220" />
          <el-table-column prop="message" label="说明" min-width="420" />
        </el-table>
        <div class="preview-summary">
          <el-tag :type="readinessStatusType(readiness.migration_sampling_acceptance_signoff?.overall_status)">
            抽样验收 {{ readiness.migration_sampling_acceptance_signoff?.overall_status || 'missing' }}
          </el-tag>
          <el-tag type="warning">{{ readiness.migration_sampling_acceptance_signoff?.summary?.pending_items || 0 }} 个 pending</el-tag>
          <el-tag type="success">{{ readiness.migration_sampling_acceptance_signoff?.summary?.passed_items || 0 }} 个 pass</el-tag>
          <el-tag type="info">{{ readiness.migration_sampling_acceptance_signoff?.summary?.accepted_with_risk_items || 0 }} 个 risk accepted</el-tag>
          <el-tag :type="readiness.migration_sampling_acceptance_signoff?.summary?.failed_items ? 'danger' : 'info'">
            {{ readiness.migration_sampling_acceptance_signoff?.summary?.failed_items || 0 }} 个 fail
          </el-tag>
          <el-tag :type="readiness.migration_sampling_acceptance_signoff?.summary?.blocked_items ? 'danger' : 'info'">
            {{ readiness.migration_sampling_acceptance_signoff?.summary?.blocked_items || 0 }} 个 blocked
          </el-tag>
        </div>
        <el-table :data="readiness.migration_sampling_acceptance_signoff?.items || []" border class="preview-section-table">
          <el-table-column prop="status" label="状态" width="130">
            <template #default="{ row }">
              <el-tag :type="readinessStatusType(row.status)">{{ row.status }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="category" label="类别" width="130" />
          <el-table-column prop="sample_key" label="样本" min-width="220" />
          <el-table-column prop="legacy_id" label="旧 ID" min-width="120" />
          <el-table-column prop="title" label="标题" min-width="260" />
          <el-table-column prop="expected_checks" label="验收点" min-width="420" />
          <el-table-column prop="risk_notes" label="风险说明" min-width="260" />
          <el-table-column prop="sampled_by" label="验收人" min-width="130" />
          <el-table-column prop="sampled_at" label="验收时间" min-width="160" />
          <el-table-column prop="evidence_ref" label="证据" min-width="220" />
          <el-table-column prop="notes" label="备注" min-width="240" />
        </el-table>
        <div class="preview-summary">
          <el-tag :type="readinessStatusType(readiness.migration_sampling_acceptance_signoff_validation?.overall_status)">
            抽样校验 {{ readiness.migration_sampling_acceptance_signoff_validation?.overall_status || 'missing' }}
          </el-tag>
          <el-tag :type="readiness.migration_sampling_acceptance_signoff_validation?.summary?.blockers ? 'danger' : 'info'">
            {{ readiness.migration_sampling_acceptance_signoff_validation?.summary?.blockers || 0 }} 个 blocker
          </el-tag>
          <el-tag :type="readiness.migration_sampling_acceptance_signoff_validation?.summary?.warnings ? 'warning' : 'info'">
            {{ readiness.migration_sampling_acceptance_signoff_validation?.summary?.warnings || 0 }} 个 warning
          </el-tag>
        </div>
        <el-table :data="readiness.migration_sampling_acceptance_signoff_validation?.issues || []" border class="preview-section-table">
          <el-table-column prop="severity" label="级别" width="100">
            <template #default="{ row }">
              <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="row_number" label="行号" width="90" />
          <el-table-column prop="sample_key" label="样本" min-width="220" />
          <el-table-column prop="field" label="字段" min-width="130" />
          <el-table-column prop="code" label="规则" min-width="200" />
          <el-table-column prop="message" label="说明" min-width="340" />
        </el-table>
        <div class="preview-summary">
          <el-tag :type="readinessStatusType(readiness.migration_go_live_drill_operator_pack?.overall_status)">
            演练操作包 {{ readiness.migration_go_live_drill_operator_pack?.overall_status || 'missing' }}
          </el-tag>
          <el-tag type="success">{{ readiness.migration_go_live_drill_operator_pack?.summary?.ready_steps || 0 }} 项 ready</el-tag>
          <el-tag :type="readiness.migration_go_live_drill_operator_pack?.summary?.blocked_steps ? 'danger' : 'info'">
            {{ readiness.migration_go_live_drill_operator_pack?.summary?.blocked_steps || 0 }} 项 blocked
          </el-tag>
          <el-tag :type="readiness.migration_go_live_drill_operator_pack?.summary?.pending_steps ? 'warning' : 'info'">
            {{ readiness.migration_go_live_drill_operator_pack?.summary?.pending_steps || 0 }} 项 pending
          </el-tag>
          <el-tag :type="readinessStatusType(readiness.migration_go_live_drill_operator_pack_validation?.overall_status)">
            演练操作包校验 {{ readiness.migration_go_live_drill_operator_pack_validation?.overall_status || 'missing' }}
          </el-tag>
          <span>{{ nextStepTitle(readiness.migration_go_live_drill_operator_pack?.next_step) }}</span>
        </div>
        <el-table :data="readiness.migration_go_live_drill_operator_pack?.steps || []" border class="preview-section-table">
          <el-table-column prop="order" label="顺序" width="80" />
          <el-table-column prop="title" label="演练步骤" min-width="240" />
          <el-table-column prop="owner" label="负责人" min-width="150" />
          <el-table-column label="状态" width="120">
            <template #default="{ row }">
              <el-tag :type="readinessStatusType(row.status)">{{ row.status }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="action" label="处理动作" min-width="360" />
          <el-table-column prop="acceptance" label="验收标准" min-width="360" />
        </el-table>
        <el-table
          v-if="readiness.migration_go_live_drill_operator_pack_validation?.issues?.length"
          :data="readiness.migration_go_live_drill_operator_pack_validation.issues.slice(0, 10)"
          border
          class="preview-section-table"
        >
          <el-table-column prop="severity" label="级别" width="100">
            <template #default="{ row }">
              <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="field" label="字段" min-width="180" />
          <el-table-column prop="code" label="规则" min-width="220" />
          <el-table-column prop="message" label="说明" min-width="420" />
        </el-table>
        <div class="preview-summary">
          <el-tag :type="readinessStatusType(readiness.migration_go_live_evidence_pack?.overall_status)">
            证据包 {{ readiness.migration_go_live_evidence_pack?.overall_status || 'missing' }}
          </el-tag>
          <el-tag :type="readiness.migration_go_live_evidence_pack?.summary?.zip_exists ? 'success' : 'danger'">
            ZIP {{ readiness.migration_go_live_evidence_pack?.summary?.zip_exists ? '已生成' : '缺失' }}
          </el-tag>
          <el-tag type="info">{{ readiness.migration_go_live_evidence_pack?.summary?.evidence_files || 0 }} 个文件</el-tag>
          <el-tag :type="readiness.migration_go_live_evidence_pack?.summary?.missing_required ? 'danger' : 'info'">
            {{ readiness.migration_go_live_evidence_pack?.summary?.missing_required || 0 }} 个必需缺失
          </el-tag>
          <el-tag :type="readinessStatusType(readiness.migration_go_live_evidence_pack_validation?.overall_status)">
            校验 {{ readiness.migration_go_live_evidence_pack_validation?.overall_status || 'missing' }}
          </el-tag>
          <el-tag :type="readiness.migration_go_live_evidence_pack_validation?.summary?.missing_zip_entries ? 'danger' : 'info'">
            缺 ZIP 条目 {{ readiness.migration_go_live_evidence_pack_validation?.summary?.missing_zip_entries || 0 }}
          </el-tag>
        </div>
        <el-table :data="readiness.migration_go_live_evidence_pack?.items || []" border class="preview-section-table">
          <el-table-column prop="key" label="证据" min-width="220" />
          <el-table-column label="状态" width="100">
            <template #default="{ row }">
              <el-tag :type="row.exists ? 'success' : 'danger'">{{ row.exists ? '存在' : '缺失' }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="required" label="必需" width="80" />
          <el-table-column prop="size_bytes" label="大小" width="110" />
          <el-table-column prop="purpose" label="用途" min-width="300" />
          <el-table-column prop="path" label="路径" min-width="420" />
        </el-table>
        <el-table
          v-if="readiness.migration_go_live_evidence_pack_validation?.issues?.length"
          :data="readiness.migration_go_live_evidence_pack_validation.issues.slice(0, 10)"
          border
          class="preview-section-table"
        >
          <el-table-column prop="severity" label="级别" width="100">
            <template #default="{ row }">
              <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="code" label="规则" min-width="220" />
          <el-table-column prop="file" label="文件" min-width="360" />
          <el-table-column prop="message" label="说明" min-width="420" />
        </el-table>
        <div class="preview-summary">
          <el-tag :type="readinessStatusType(readiness.migration_next_actions?.overall_status)">
            下一步 {{ readiness.migration_next_actions?.overall_status || 'missing' }}
          </el-tag>
          <el-tag :type="readiness.migration_next_actions?.summary?.blockers ? 'danger' : 'info'">
            {{ readiness.migration_next_actions?.summary?.blockers || 0 }} 个 blocker
          </el-tag>
          <el-tag :type="readiness.migration_next_actions?.summary?.warnings ? 'warning' : 'info'">
            {{ readiness.migration_next_actions?.summary?.warnings || 0 }} 个 warning
          </el-tag>
          <el-tag type="info">{{ readiness.migration_next_actions?.summary?.total_actions || 0 }} 个行动项</el-tag>
          <el-tag :type="readiness.migration_next_actions?.files?.owner_zip_exists ? 'success' : 'danger'">
            负责人包 {{ readiness.migration_next_actions?.files?.owner_zip_exists ? '已生成' : '缺失' }}
          </el-tag>
          <el-tag :type="readinessStatusType(readiness.migration_next_actions_validation?.overall_status)">
            总清单校验 {{ readiness.migration_next_actions_validation?.overall_status || 'missing' }}
          </el-tag>
          <el-tag :type="readiness.migration_next_actions_validation?.summary?.summary_mismatches ? 'danger' : 'info'">
            计数偏差 {{ readiness.migration_next_actions_validation?.summary?.summary_mismatches || 0 }}
          </el-tag>
          <el-tag :type="readiness.migration_next_actions_validation?.summary?.breakdown_mismatches ? 'danger' : 'info'">
            拆分偏差 {{ readiness.migration_next_actions_validation?.summary?.breakdown_mismatches || 0 }}
          </el-tag>
          <el-tag :type="readinessStatusType(readiness.migration_next_actions_owner_files_validation?.overall_status)">
            分发校验 {{ readiness.migration_next_actions_owner_files_validation?.overall_status || 'missing' }}
          </el-tag>
          <el-tag :type="readiness.migration_next_actions_owner_files_validation?.summary?.missing_zip_entries ? 'danger' : 'info'">
            缺 ZIP 条目 {{ readiness.migration_next_actions_owner_files_validation?.summary?.missing_zip_entries || 0 }}
          </el-tag>
          <el-tag :type="readiness.migration_next_actions_owner_files_validation?.summary?.csv_count_mismatches ? 'warning' : 'info'">
            行数不一致 {{ readiness.migration_next_actions_owner_files_validation?.summary?.csv_count_mismatches || 0 }}
          </el-tag>
          <el-tag :type="readinessStatusType(readiness.migration_next_actions_owner_signoff?.overall_status)">
            签收 {{ readiness.migration_next_actions_owner_signoff?.overall_status || 'missing' }}
          </el-tag>
          <el-tag :type="readiness.migration_next_actions_owner_signoff?.summary?.pending_items ? 'warning' : 'info'">
            待签收 {{ readiness.migration_next_actions_owner_signoff?.summary?.pending_items || 0 }}
          </el-tag>
          <el-tag :type="readiness.migration_next_actions_owner_signoff?.summary?.blocked_items ? 'danger' : 'info'">
            签收阻断 {{ readiness.migration_next_actions_owner_signoff?.summary?.blocked_items || 0 }}
          </el-tag>
          <el-tag :type="readinessStatusType(readiness.migration_next_actions_owner_signoff_validation?.overall_status)">
            签收校验 {{ readiness.migration_next_actions_owner_signoff_validation?.overall_status || 'missing' }}
          </el-tag>
          <el-tag :type="readinessStatusType(readiness.migration_next_actions_owner_signoff_operator_pack?.overall_status)">
            签收操作包 {{ readiness.migration_next_actions_owner_signoff_operator_pack?.overall_status || 'missing' }}
          </el-tag>
          <el-tag :type="readiness.migration_next_actions_owner_signoff_operator_pack?.summary?.pending_steps ? 'warning' : 'info'">
            操作包待办 {{ readiness.migration_next_actions_owner_signoff_operator_pack?.summary?.pending_steps || 0 }}
          </el-tag>
          <el-tag type="info">
            操作包负责人 {{ readiness.migration_next_actions_owner_signoff_operator_pack?.summary?.owner_items || 0 }}
          </el-tag>
          <el-tag :type="readinessStatusType(readiness.migration_next_actions_owner_signoff_operator_pack_validation?.overall_status)">
            操作包校验 {{ readiness.migration_next_actions_owner_signoff_operator_pack_validation?.overall_status || 'missing' }}
          </el-tag>
          <el-tag :type="readiness.migration_next_actions_owner_signoff_operator_pack_validation?.summary?.blockers ? 'danger' : 'info'">
            操作包校验 blocker {{ readiness.migration_next_actions_owner_signoff_operator_pack_validation?.summary?.blockers || 0 }}
          </el-tag>
          <el-tag :type="readiness.migration_next_actions_owner_signoff_operator_pack_validation?.summary?.warnings ? 'warning' : 'info'">
            操作包校验 warning {{ readiness.migration_next_actions_owner_signoff_operator_pack_validation?.summary?.warnings || 0 }}
          </el-tag>
          <span>{{ readiness.migration_next_actions?.next_action?.title || '-' }}</span>
          <span>{{ readiness.migration_next_actions?.files?.blocker_csv || '-' }}</span>
          <span>{{ readiness.migration_next_actions?.files?.blocker_markdown || '-' }}</span>
          <span>{{ readiness.migration_next_actions?.files?.owner_zip || '-' }}</span>
        </div>
        <el-table
          v-if="readiness.migration_next_actions_validation?.issues?.length"
          :data="readiness.migration_next_actions_validation.issues.slice(0, 10)"
          border
          class="preview-section-table"
        >
          <el-table-column label="级别" width="110">
            <template #default="{ row }">
              <el-tag :type="row.severity === 'blocker' ? 'danger' : row.severity === 'warning' ? 'warning' : 'info'">{{ row.severity }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="field" label="字段" min-width="220" />
          <el-table-column prop="code" label="规则" min-width="200" />
          <el-table-column prop="message" label="说明" min-width="420" />
        </el-table>
        <el-table
          v-if="readiness.migration_next_actions_owner_files_validation?.issues?.length"
          :data="readiness.migration_next_actions_owner_files_validation.issues.slice(0, 10)"
          border
          class="preview-section-table"
        >
          <el-table-column label="级别" width="110">
            <template #default="{ row }">
              <el-tag :type="row.severity === 'blocker' ? 'danger' : row.severity === 'warning' ? 'warning' : 'info'">{{ row.severity }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="owner" label="负责人" min-width="150" />
          <el-table-column prop="code" label="问题" min-width="180" />
          <el-table-column prop="message" label="说明" min-width="320" />
          <el-table-column prop="file" label="文件" min-width="360" />
        </el-table>
        <el-table
          v-if="readiness.migration_next_actions_owner_signoff_validation?.issues?.length"
          :data="readiness.migration_next_actions_owner_signoff_validation.issues.slice(0, 10)"
          border
          class="preview-section-table"
        >
          <el-table-column label="级别" width="110">
            <template #default="{ row }">
              <el-tag :type="row.severity === 'blocker' ? 'danger' : row.severity === 'warning' ? 'warning' : 'info'">{{ row.severity }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="owner" label="负责人" min-width="150" />
          <el-table-column prop="field" label="字段" min-width="160" />
          <el-table-column prop="code" label="问题" min-width="180" />
          <el-table-column prop="message" label="说明" min-width="320" />
        </el-table>
        <el-table :data="readiness.migration_next_actions?.blocker_owner_breakdown || []" border class="preview-section-table">
          <el-table-column prop="owner" label="Blocker 负责人" min-width="180" />
          <el-table-column prop="blockers" label="Blocker" width="100" />
          <el-table-column label="类别" min-width="320">
            <template #default="{ row }">{{ formatList(row.categories) }}</template>
          </el-table-column>
        </el-table>
        <el-table :data="readiness.migration_next_actions?.blocker_actions || []" border class="preview-section-table">
          <el-table-column prop="priority" label="优先级" width="90" />
          <el-table-column prop="owner" label="负责人" min-width="150" />
          <el-table-column prop="category" label="类别" min-width="220" />
          <el-table-column prop="status" label="状态" width="120" />
          <el-table-column prop="title" label="Blocker" min-width="280" />
          <el-table-column prop="action" label="处理动作" min-width="360" />
          <el-table-column prop="acceptance" label="验收标准" min-width="360" />
        </el-table>
        <el-table :data="(readiness.migration_next_actions?.owner_breakdown || []).slice(0, 8)" border class="preview-section-table">
          <el-table-column prop="owner" label="负责人" min-width="180" />
          <el-table-column prop="count" label="行动项" width="100" />
          <el-table-column prop="blockers" label="Blocker" width="100" />
          <el-table-column prop="warnings" label="Warning" width="100" />
        </el-table>
        <el-table :data="(readiness.migration_next_actions?.category_breakdown || []).slice(0, 8)" border class="preview-section-table">
          <el-table-column prop="category" label="类别" min-width="260" />
          <el-table-column prop="count" label="行动项" width="100" />
          <el-table-column prop="blockers" label="Blocker" width="100" />
          <el-table-column prop="warnings" label="Warning" width="100" />
        </el-table>
        <el-table :data="(readiness.migration_next_actions?.files?.owner_files || []).slice(0, 8)" border class="preview-section-table">
          <el-table-column prop="owner" label="负责人文件" min-width="180" />
          <el-table-column prop="count" label="行动项" width="100" />
          <el-table-column prop="blockers" label="Blocker" width="100" />
          <el-table-column prop="csv" label="CSV" min-width="360" />
          <el-table-column prop="markdown" label="Markdown" min-width="360" />
          <el-table-column prop="blocker_csv" label="Blocker CSV" min-width="360" />
          <el-table-column prop="blocker_markdown" label="Blocker Markdown" min-width="360" />
        </el-table>
        <el-table :data="readiness.migration_next_actions_owner_signoff?.items || []" border class="preview-section-table">
          <el-table-column prop="owner" label="签收负责人" min-width="180" />
          <el-table-column prop="status" label="状态" width="110">
            <template #default="{ row }">
              <el-tag :type="readinessStatusType(row.status)">{{ row.status }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="recipient" label="接收人" min-width="140" />
          <el-table-column prop="action_count" label="行动项" width="90" />
          <el-table-column prop="blockers" label="Blocker" width="90" />
          <el-table-column prop="sent_at" label="发送时间" min-width="180" />
          <el-table-column prop="accepted_by" label="签收人" min-width="140" />
          <el-table-column prop="accepted_at" label="签收时间" min-width="180" />
          <el-table-column prop="evidence_ref" label="证据" min-width="220" />
        </el-table>
        <el-table :data="readiness.migration_next_actions_owner_signoff_operator_pack?.owners || []" border class="preview-section-table">
          <el-table-column prop="owner" label="操作包负责人" min-width="180" />
          <el-table-column prop="status" label="状态" width="110">
            <template #default="{ row }">
              <el-tag :type="readinessStatusType(row.status)">{{ row.status }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="action_count" label="行动项" width="90" />
          <el-table-column prop="blockers" label="Blocker" width="90" />
          <el-table-column prop="warnings" label="Warning" width="90" />
          <el-table-column prop="recipient" label="接收人" min-width="140" />
          <el-table-column prop="sent_at" label="发送时间" min-width="180" />
          <el-table-column prop="accepted_by" label="签收人" min-width="140" />
          <el-table-column prop="completed_by" label="完成人" min-width="140" />
          <el-table-column prop="blocker_csv_path" label="Blocker CSV" min-width="360" />
          <el-table-column prop="blocker_markdown_path" label="Blocker Markdown" min-width="360" />
        </el-table>
        <el-table :data="readiness.migration_next_actions_owner_signoff_operator_pack?.steps || []" border class="preview-section-table">
          <el-table-column prop="order" label="#" width="70" />
          <el-table-column prop="title" label="签收操作步骤" min-width="220" />
          <el-table-column prop="status" label="状态" width="120">
            <template #default="{ row }">
              <el-tag :type="readinessStatusType(row.status)">{{ row.status }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="action" label="处理动作" min-width="360" />
          <el-table-column prop="acceptance" label="验收标准" min-width="360" />
        </el-table>
        <el-table
          v-if="readiness.migration_next_actions_owner_signoff_operator_pack_validation?.issues?.length"
          :data="readiness.migration_next_actions_owner_signoff_operator_pack_validation.issues.slice(0, 10)"
          border
          class="preview-section-table"
        >
          <el-table-column label="级别" width="110">
            <template #default="{ row }">
              <el-tag :type="row.severity === 'blocker' ? 'danger' : row.severity === 'warning' ? 'warning' : 'info'">{{ row.severity }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="field" label="字段" min-width="180" />
          <el-table-column prop="code" label="问题" min-width="220" />
          <el-table-column prop="message" label="说明" min-width="360" />
        </el-table>
        <el-table :data="readiness.migration_next_actions?.top_actions || []" border class="preview-section-table">
          <el-table-column prop="priority" label="优先级" width="90" />
          <el-table-column label="级别" width="110">
            <template #default="{ row }">
              <el-tag :type="row.severity === 'blocker' ? 'danger' : row.severity === 'warning' ? 'warning' : 'info'">{{ row.severity }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="category" label="类别" min-width="160" />
          <el-table-column prop="status" label="状态" width="110" />
          <el-table-column prop="owner" label="负责人" min-width="150" />
          <el-table-column prop="title" label="事项" min-width="300" />
          <el-table-column prop="action" label="处理动作" min-width="360" />
          <el-table-column prop="acceptance" label="验收标准" min-width="320" />
        </el-table>
      </template>
    </el-card>

        <el-card shadow="never">
      <template #header>安全基线操作包</template>
      <el-alert v-if="!readiness.legacy_security_baseline_operator_pack" title="尚未生成 legacy-security-baseline-operator-pack.json，请先运行 scripts/New-LegacySecurityBaselineOperatorPack.ps1。" type="info" show-icon :closable="false" />
      <template v-else>
        <div class="preview-summary">
          <el-tag :type="readinessStatusType(readiness.legacy_security_baseline_operator_pack.overall_status)">
            {{ readiness.legacy_security_baseline_operator_pack.overall_status }}
          </el-tag>
          <el-tag type="success">{{ readiness.legacy_security_baseline_operator_pack.summary?.ready_steps || 0 }} 项 ready</el-tag>
          <el-tag :type="readiness.legacy_security_baseline_operator_pack.summary?.blocked_steps ? 'danger' : 'info'">
            {{ readiness.legacy_security_baseline_operator_pack.summary?.blocked_steps || 0 }} 项 blocked
          </el-tag>
          <el-tag :type="readiness.legacy_security_baseline_operator_pack.summary?.pending_steps ? 'warning' : 'info'">
            {{ readiness.legacy_security_baseline_operator_pack.summary?.pending_steps || 0 }} 项 pending
          </el-tag>
          <el-tag :type="readiness.legacy_security_baseline_operator_pack.summary?.executable_public_files ? 'danger' : 'info'">
            公开可执行文件 {{ readiness.legacy_security_baseline_operator_pack.summary?.executable_public_files || 0 }}
          </el-tag>
          <el-tag :type="readiness.legacy_security_baseline_operator_pack.summary?.infected_or_backup_leftovers ? 'danger' : 'info'">
            感染/备份遗留 {{ readiness.legacy_security_baseline_operator_pack.summary?.infected_or_backup_leftovers || 0 }}
          </el-tag>
          <el-tag :type="readiness.legacy_security_baseline_operator_pack.summary?.dangerous_php_patterns ? 'warning' : 'info'">
            危险 PHP 模式 {{ readiness.legacy_security_baseline_operator_pack.summary?.dangerous_php_patterns || 0 }}
          </el-tag>
          <el-tag :type="readiness.legacy_security_baseline_operator_pack.summary?.attachment_dangerous_extensions ? 'danger' : 'info'">
            附件危险扩展名 {{ readiness.legacy_security_baseline_operator_pack.summary?.attachment_dangerous_extensions || 0 }}
          </el-tag>
          <el-tag :type="readiness.legacy_security_baseline_operator_pack.summary?.attachment_missing_files ? 'warning' : 'info'">
            附件缺失文件 {{ readiness.legacy_security_baseline_operator_pack.summary?.attachment_missing_files || 0 }}
          </el-tag>
          <el-tag :type="readinessStatusType(readiness.legacy_security_baseline_operator_pack_validation?.overall_status)">
            操作包校验 {{ readiness.legacy_security_baseline_operator_pack_validation?.overall_status || 'missing' }}
          </el-tag>
          <span>{{ nextStepTitle(readiness.legacy_security_baseline_operator_pack.next_step) }}</span>
        </div>
        <el-table :data="readiness.legacy_security_baseline_operator_pack.steps || []" border class="preview-section-table">
          <el-table-column prop="order" label="顺序" width="70" />
          <el-table-column prop="category" label="类别" min-width="140" />
          <el-table-column prop="title" label="步骤" min-width="280" />
          <el-table-column label="状态" width="110">
            <template #default="{ row }">
              <el-tag :type="readinessStatusType(row.status)">{{ row.status }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="severity" label="级别" width="100" />
          <el-table-column prop="action" label="处理动作" min-width="360" />
          <el-table-column prop="acceptance" label="验收标准" min-width="360" />
          <el-table-column prop="source" label="来源" min-width="180" />
        </el-table>
        <el-table
          v-if="readiness.legacy_security_baseline_operator_pack_validation?.issues?.length"
          :data="readiness.legacy_security_baseline_operator_pack_validation.issues.slice(0, 10)"
          border
          class="preview-section-table"
        >
          <el-table-column prop="severity" label="级别" width="100">
            <template #default="{ row }">
              <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="field" label="字段" min-width="180" />
          <el-table-column prop="code" label="规则" min-width="220" />
          <el-table-column prop="message" label="说明" min-width="420" />
        </el-table>
        <el-divider content-position="left">公开可执行文件处置清单</el-divider>
        <el-alert v-if="!readiness.legacy_security_public_executable_worklist" title="尚未生成 legacy-security-public-executable-worklist.json，请先运行 scripts/New-LegacySecurityPublicExecutableWorklist.ps1。" type="info" show-icon :closable="false" />
        <template v-else>
          <div class="preview-summary">
            <el-tag :type="readinessStatusType(readiness.legacy_security_public_executable_worklist.overall_status)">
              {{ readiness.legacy_security_public_executable_worklist.overall_status }}
            </el-tag>
            <el-tag type="info">{{ readiness.legacy_security_public_executable_worklist.summary?.total_files || 0 }} 个文件</el-tag>
            <el-tag :type="readiness.legacy_security_public_executable_worklist.summary?.blocker_files ? 'danger' : 'info'">
              {{ readiness.legacy_security_public_executable_worklist.summary?.blocker_files || 0 }} 个 blocker
            </el-tag>
            <el-tag :type="readiness.legacy_security_public_executable_worklist.summary?.warning_files ? 'warning' : 'info'">
              {{ readiness.legacy_security_public_executable_worklist.summary?.warning_files || 0 }} 个 warning
            </el-tag>
            <el-tag :type="readinessStatusType(readiness.legacy_security_public_executable_worklist_validation?.overall_status)">
              校验 {{ readiness.legacy_security_public_executable_worklist_validation?.overall_status || 'missing' }}
            </el-tag>
            <el-tag :type="readiness.legacy_security_public_executable_worklist_validation?.summary?.pending_files ? 'warning' : 'info'">
              {{ readiness.legacy_security_public_executable_worklist_validation?.summary?.pending_files || 0 }} 个 pending
            </el-tag>
            <el-tag :type="readiness.legacy_security_public_executable_worklist_validation?.summary?.blockers ? 'danger' : 'info'">
              校验 blocker {{ readiness.legacy_security_public_executable_worklist_validation?.summary?.blockers || 0 }}
            </el-tag>
            <el-tag :type="readinessStatusType(readiness.legacy_security_public_executable_remediation_plan?.overall_status)">
              处置计划 {{ readiness.legacy_security_public_executable_remediation_plan?.overall_status || 'missing' }}
            </el-tag>
            <el-tag :type="readiness.legacy_security_public_executable_remediation_plan?.summary?.pending_waves ? 'warning' : 'info'">
              待处理波次 {{ readiness.legacy_security_public_executable_remediation_plan?.summary?.pending_waves || 0 }}
            </el-tag>
            <el-tag type="info">
              下一波 {{ readiness.legacy_security_public_executable_remediation_plan?.summary?.next_wave || '-' }}
            </el-tag>
            <el-tag :type="readinessStatusType(readiness.legacy_security_public_executable_remediation_plan_validation?.overall_status)">
              计划校验 {{ readiness.legacy_security_public_executable_remediation_plan_validation?.overall_status || 'missing' }}
            </el-tag>
            <el-tag :type="readiness.legacy_security_public_executable_remediation_plan_validation?.summary?.blockers ? 'danger' : 'info'">
              计划校验 blocker {{ readiness.legacy_security_public_executable_remediation_plan_validation?.summary?.blockers || 0 }}
            </el-tag>
            <el-tag :type="readinessStatusType(readiness.legacy_security_public_executable_remediation_wave_files?.overall_status)">
              波次分发 {{ readiness.legacy_security_public_executable_remediation_wave_files?.overall_status || 'missing' }}
            </el-tag>
            <el-tag :type="readiness.legacy_security_public_executable_remediation_wave_files?.summary?.zip_exists ? 'success' : 'danger'">
              波次 ZIP {{ readiness.legacy_security_public_executable_remediation_wave_files?.summary?.zip_exists ? '已生成' : '缺失' }}
            </el-tag>
            <el-tag :type="readinessStatusType(readiness.legacy_security_public_executable_remediation_wave_files_validation?.overall_status)">
              波次包校验 {{ readiness.legacy_security_public_executable_remediation_wave_files_validation?.overall_status || 'missing' }}
            </el-tag>
            <el-tag :type="readiness.legacy_security_public_executable_remediation_wave_files_validation?.summary?.missing_zip_entries ? 'danger' : 'info'">
              缺 ZIP 条目 {{ readiness.legacy_security_public_executable_remediation_wave_files_validation?.summary?.missing_zip_entries || 0 }}
            </el-tag>
            <el-tag :type="readinessStatusType(readiness.legacy_security_public_executable_remediation_wave_signoff?.overall_status)">
              波次签收 {{ readiness.legacy_security_public_executable_remediation_wave_signoff?.overall_status || 'missing' }}
            </el-tag>
            <el-tag :type="readiness.legacy_security_public_executable_remediation_wave_signoff?.summary?.pending_items ? 'warning' : 'info'">
              签收 pending {{ readiness.legacy_security_public_executable_remediation_wave_signoff?.summary?.pending_items || 0 }}
            </el-tag>
            <el-tag :type="readinessStatusType(readiness.legacy_security_public_executable_remediation_wave_signoff_validation?.overall_status)">
              签收校验 {{ readiness.legacy_security_public_executable_remediation_wave_signoff_validation?.overall_status || 'missing' }}
            </el-tag>
            <el-tag :type="readinessStatusType(readiness.legacy_security_public_executable_remediation_wave_signoff_operator_pack?.overall_status)">
              签收操作包 {{ readiness.legacy_security_public_executable_remediation_wave_signoff_operator_pack?.overall_status || 'missing' }}
            </el-tag>
            <el-tag :type="readiness.legacy_security_public_executable_remediation_wave_signoff_operator_pack?.summary?.blocked_steps ? 'danger' : 'info'">
              操作包 blocked {{ readiness.legacy_security_public_executable_remediation_wave_signoff_operator_pack?.summary?.blocked_steps || 0 }}
            </el-tag>
            <el-tag :type="readinessStatusType(readiness.legacy_security_public_executable_remediation_wave_signoff_operator_pack_validation?.overall_status)">
              操作包校验 {{ readiness.legacy_security_public_executable_remediation_wave_signoff_operator_pack_validation?.overall_status || 'missing' }}
            </el-tag>
            <el-tag :type="readinessStatusType(readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_pack?.overall_status)">
              交接包 {{ readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_pack?.overall_status || 'missing' }}
            </el-tag>
            <el-tag :type="readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_pack?.summary?.zip_exists ? 'success' : 'danger'">
              交接 ZIP {{ readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_pack?.summary?.zip_exists ? '已生成' : '缺失' }}
            </el-tag>
            <el-tag :type="readinessStatusType(readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_pack_validation?.overall_status)">
              交接包校验 {{ readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_pack_validation?.overall_status || 'missing' }}
            </el-tag>
            <el-tag :type="readinessStatusType(readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff?.overall_status)">
              交接签收 {{ readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff?.overall_status || 'missing' }}
            </el-tag>
            <el-tag :type="readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff?.summary?.pending_items ? 'warning' : 'info'">
              交接 pending {{ readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff?.summary?.pending_items || 0 }}
            </el-tag>
            <el-tag :type="readinessStatusType(readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack?.overall_status)">
              交接签收操作包 {{ readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack?.overall_status || 'missing' }}
            </el-tag>
            <el-tag :type="readinessStatusType(readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack_validation?.overall_status)">
              交接签收操作包校验 {{ readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack_validation?.overall_status || 'missing' }}
            </el-tag>
          </div>
          <div v-if="securityPublicExecutableCategoryRows.length" class="preview-summary">
            <el-tag v-for="item in securityPublicExecutableCategoryRows" :key="item.reason" type="warning">
              {{ securityCategoryLabel(item.reason) }} {{ item.count }}
            </el-tag>
          </div>
          <el-table :data="readiness.legacy_security_public_executable_remediation_plan?.waves || []" border class="preview-section-table">
            <el-table-column prop="wave" label="波次" width="70" />
            <el-table-column prop="title" label="处置批次" min-width="260" />
            <el-table-column label="状态" width="110">
              <template #default="{ row }">
                <el-tag :type="readinessStatusType(row.status)">{{ row.status }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="total_files" label="文件" width="80" />
            <el-table-column prop="pending_files" label="Pending" width="90" />
            <el-table-column prop="blocker_files" label="Blocker" width="90" />
            <el-table-column prop="warning_files" label="Warning" width="90" />
            <el-table-column prop="acceptance" label="验收标准" min-width="360" />
          </el-table>
          <el-table
            v-if="readiness.legacy_security_public_executable_remediation_plan_validation?.issues?.length"
            :data="readiness.legacy_security_public_executable_remediation_plan_validation.issues.slice(0, 10)"
            border
            class="preview-section-table"
          >
            <el-table-column prop="severity" label="级别" width="100">
              <template #default="{ row }">
                <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="code" label="规则" min-width="180" />
            <el-table-column prop="item_id" label="#" width="80" />
            <el-table-column prop="wave" label="波次" width="80" />
            <el-table-column prop="field" label="字段" min-width="160" />
            <el-table-column prop="message" label="说明" min-width="360" />
          </el-table>
          <el-table :data="readiness.legacy_security_public_executable_remediation_wave_files?.files?.waves || []" border class="preview-section-table">
            <el-table-column prop="wave" label="波次" width="70" />
            <el-table-column prop="title" label="分发文件" min-width="260" />
            <el-table-column label="状态" width="110">
              <template #default="{ row }">
                <el-tag :type="readinessStatusType(row.status)">{{ row.status }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="total_files" label="文件" width="80" />
            <el-table-column prop="pending_files" label="Pending" width="90" />
            <el-table-column prop="csv" label="CSV" min-width="360" />
            <el-table-column prop="markdown" label="Markdown" min-width="360" />
          </el-table>
          <el-table
            v-if="readiness.legacy_security_public_executable_remediation_wave_files_validation?.issues?.length"
            :data="readiness.legacy_security_public_executable_remediation_wave_files_validation.issues.slice(0, 10)"
            border
            class="preview-section-table"
          >
            <el-table-column prop="severity" label="级别" width="100">
              <template #default="{ row }">
                <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="wave" label="波次" width="80" />
            <el-table-column prop="code" label="规则" min-width="180" />
            <el-table-column prop="message" label="说明" min-width="360" />
            <el-table-column prop="file" label="文件" min-width="360" />
          </el-table>
          <el-table :data="readiness.legacy_security_public_executable_remediation_wave_signoff?.items || []" border class="preview-section-table">
            <el-table-column label="状态" width="110">
              <template #default="{ row }">
                <el-tag :type="readinessStatusType(row.status)">{{ row.status }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="wave" label="波次" width="70" />
            <el-table-column prop="title" label="签收批次" min-width="260" />
            <el-table-column prop="total_files" label="文件" width="80" />
            <el-table-column prop="pending_files" label="Pending" width="90" />
            <el-table-column prop="owner" label="负责人" min-width="130" />
            <el-table-column prop="resolved_by" label="处理人" min-width="130" />
            <el-table-column prop="evidence_ref" label="证据" min-width="220" />
            <el-table-column prop="notes" label="备注" min-width="220" />
          </el-table>
          <el-table
            v-if="readiness.legacy_security_public_executable_remediation_wave_signoff_validation?.issues?.length"
            :data="readiness.legacy_security_public_executable_remediation_wave_signoff_validation.issues.slice(0, 10)"
            border
            class="preview-section-table"
          >
            <el-table-column prop="severity" label="级别" width="100">
              <template #default="{ row }">
                <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="row_number" label="行号" width="80" />
            <el-table-column prop="wave" label="波次" width="80" />
            <el-table-column prop="field" label="字段" min-width="140" />
            <el-table-column prop="code" label="规则" min-width="180" />
            <el-table-column prop="message" label="说明" min-width="360" />
          </el-table>
          <el-alert v-if="!readiness.legacy_security_public_executable_remediation_wave_signoff_operator_pack" title="尚未生成 legacy-security-public-executable-remediation-wave-signoff-operator-pack.json，请先运行 scripts/New-LegacySecurityPublicExecutableRemediationWaveSignoffOperatorPack.ps1。" type="info" show-icon :closable="false" />
          <template v-else>
            <div class="preview-summary">
              <el-tag :type="readinessStatusType(readiness.legacy_security_public_executable_remediation_wave_signoff_operator_pack.overall_status)">
                {{ readiness.legacy_security_public_executable_remediation_wave_signoff_operator_pack.overall_status }}
              </el-tag>
              <el-tag type="success">{{ readiness.legacy_security_public_executable_remediation_wave_signoff_operator_pack.summary?.ready_steps || 0 }} 项 ready</el-tag>
              <el-tag :type="readiness.legacy_security_public_executable_remediation_wave_signoff_operator_pack.summary?.pending_steps ? 'warning' : 'info'">
                {{ readiness.legacy_security_public_executable_remediation_wave_signoff_operator_pack.summary?.pending_steps || 0 }} 项 pending
              </el-tag>
              <el-tag :type="readiness.legacy_security_public_executable_remediation_wave_signoff_operator_pack.summary?.validation_blockers ? 'danger' : 'info'">
                校验 blocker {{ readiness.legacy_security_public_executable_remediation_wave_signoff_operator_pack.summary?.validation_blockers || 0 }}
              </el-tag>
              <span>{{ nextStepTitle(readiness.legacy_security_public_executable_remediation_wave_signoff_operator_pack.next_step) }}</span>
            </div>
            <el-table :data="readiness.legacy_security_public_executable_remediation_wave_signoff_operator_pack.steps || []" border class="preview-section-table">
              <el-table-column prop="order" label="顺序" width="70" />
              <el-table-column prop="title" label="步骤" min-width="300" />
              <el-table-column label="状态" width="110">
                <template #default="{ row }">
                  <el-tag :type="readinessStatusType(row.status)">{{ row.status }}</el-tag>
                </template>
              </el-table-column>
              <el-table-column prop="action" label="处理动作" min-width="360" />
              <el-table-column prop="acceptance" label="验收标准" min-width="360" />
              <el-table-column prop="source" label="来源" min-width="260" />
            </el-table>
            <el-table
              v-if="readiness.legacy_security_public_executable_remediation_wave_signoff_operator_pack_validation?.issues?.length"
              :data="readiness.legacy_security_public_executable_remediation_wave_signoff_operator_pack_validation.issues.slice(0, 10)"
              border
              class="preview-section-table"
            >
              <el-table-column prop="severity" label="级别" width="100">
                <template #default="{ row }">
                  <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
                </template>
              </el-table-column>
              <el-table-column prop="field" label="字段" min-width="180" />
              <el-table-column prop="code" label="规则" min-width="220" />
              <el-table-column prop="message" label="说明" min-width="420" />
            </el-table>
          </template>
          <el-alert v-if="!readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_pack" title="尚未生成 legacy-security-public-executable-remediation-wave-signoff-handoff-pack.json，请先运行 scripts/New-LegacySecurityPublicExecutableRemediationWaveSignoffHandoffPack.ps1。" type="info" show-icon :closable="false" />
          <template v-else>
            <div class="preview-summary">
              <el-tag :type="readinessStatusType(readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_pack.overall_status)">
                {{ readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_pack.overall_status }}
              </el-tag>
              <el-tag type="info">{{ readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_pack.summary?.handoff_files || 0 }} 个文件</el-tag>
              <el-tag :type="readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_pack.summary?.missing_required ? 'danger' : 'info'">
                缺必需文件 {{ readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_pack.summary?.missing_required || 0 }}
              </el-tag>
              <el-tag :type="readinessStatusType(readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_pack_validation?.overall_status)">
                校验 {{ readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_pack_validation?.overall_status || 'missing' }}
              </el-tag>
              <el-tag :type="readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_pack_validation?.summary?.missing_zip_entries ? 'danger' : 'info'">
                缺 ZIP 条目 {{ readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_pack_validation?.summary?.missing_zip_entries || 0 }}
              </el-tag>
            </div>
            <el-table :data="readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_pack.items || []" border class="preview-section-table">
              <el-table-column prop="key" label="文件" min-width="220" />
              <el-table-column prop="required" label="必需" width="90" />
              <el-table-column prop="exists" label="存在" width="90" />
              <el-table-column prop="size_bytes" label="大小" width="110" />
              <el-table-column prop="file_name" label="文件名" min-width="320" />
              <el-table-column prop="purpose" label="用途" min-width="360" />
            </el-table>
            <el-table
              v-if="readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_pack_validation?.issues?.length"
              :data="readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_pack_validation.issues.slice(0, 10)"
              border
              class="preview-section-table"
            >
              <el-table-column prop="severity" label="级别" width="100">
                <template #default="{ row }">
                  <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
                </template>
              </el-table-column>
              <el-table-column prop="code" label="规则" min-width="220" />
              <el-table-column prop="message" label="说明" min-width="420" />
              <el-table-column prop="file" label="文件" min-width="360" />
            </el-table>
          </template>
          <el-alert v-if="!readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff" title="尚未生成 legacy-security-public-executable-remediation-wave-signoff-handoff-signoff.json，请先运行 scripts/New-LegacySecurityPublicExecutableRemediationWaveSignoffHandoffSignoff.ps1。" type="info" show-icon :closable="false" />
          <template v-else>
            <div class="preview-summary">
              <el-tag :type="readinessStatusType(readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff.overall_status)">
                {{ readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff.overall_status }}
              </el-tag>
              <el-tag type="warning">{{ readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff.summary?.pending_items || 0 }} 个 pending</el-tag>
              <el-tag type="info">{{ readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff.summary?.delivered_items || 0 }} 个 delivered</el-tag>
              <el-tag type="success">{{ readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff.summary?.accepted_items || 0 }} 个 accepted</el-tag>
              <el-tag :type="readinessStatusType(readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_validation?.overall_status)">
                校验 {{ readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_validation?.overall_status || 'missing' }}
              </el-tag>
              <el-tag :type="readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_validation?.summary?.warnings ? 'warning' : 'info'">
                warning {{ readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_validation?.summary?.warnings || 0 }}
              </el-tag>
            </div>
            <el-table :data="readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff.items || []" border class="preview-section-table">
              <el-table-column label="状态" width="130">
                <template #default="{ row }">
                  <el-tag :type="readinessStatusType(row.status)">{{ row.status }}</el-tag>
                </template>
              </el-table-column>
              <el-table-column prop="owner" label="负责人" min-width="130" />
              <el-table-column prop="recipient" label="接收人" min-width="130" />
              <el-table-column prop="package_file" label="交接 ZIP" min-width="360" />
              <el-table-column prop="sent_at" label="发送时间" min-width="160" />
              <el-table-column prop="accepted_by" label="签收人" min-width="130" />
              <el-table-column prop="accepted_at" label="签收时间" min-width="160" />
              <el-table-column prop="evidence_ref" label="证据" min-width="220" />
              <el-table-column prop="notes" label="备注" min-width="220" />
            </el-table>
            <el-table
              v-if="readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_validation?.issues?.length"
              :data="readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_validation.issues.slice(0, 10)"
              border
              class="preview-section-table"
            >
              <el-table-column prop="severity" label="级别" width="100">
                <template #default="{ row }">
                  <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
                </template>
              </el-table-column>
              <el-table-column prop="row_number" label="行号" width="80" />
              <el-table-column prop="field" label="字段" min-width="140" />
              <el-table-column prop="code" label="规则" min-width="220" />
              <el-table-column prop="message" label="说明" min-width="420" />
            </el-table>
            <el-alert v-if="!readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack" title="尚未生成 legacy-security-public-executable-remediation-wave-signoff-handoff-signoff-operator-pack.json，请先运行 scripts/New-LegacySecurityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack.ps1。" type="info" show-icon :closable="false" />
            <template v-else>
              <div class="preview-summary">
                <el-tag :type="readinessStatusType(readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack.overall_status)">
                  {{ readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack.overall_status }}
                </el-tag>
                <el-tag type="success">{{ readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack.summary?.ready_steps || 0 }} 项 ready</el-tag>
                <el-tag :type="readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack.summary?.pending_steps ? 'warning' : 'info'">
                  {{ readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack.summary?.pending_steps || 0 }} 项 pending
                </el-tag>
                <el-tag :type="readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack.summary?.validation_blockers ? 'danger' : 'info'">
                  校验 blocker {{ readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack.summary?.validation_blockers || 0 }}
                </el-tag>
                <span>{{ nextStepTitle(readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack.next_step) }}</span>
              </div>
              <el-table :data="readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack.steps || []" border class="preview-section-table">
                <el-table-column prop="order" label="顺序" width="70" />
                <el-table-column prop="title" label="步骤" min-width="300" />
                <el-table-column label="状态" width="110">
                  <template #default="{ row }">
                    <el-tag :type="readinessStatusType(row.status)">{{ row.status }}</el-tag>
                  </template>
                </el-table-column>
                <el-table-column prop="action" label="处理动作" min-width="360" />
                <el-table-column prop="acceptance" label="验收标准" min-width="360" />
                <el-table-column prop="source" label="来源" min-width="260" />
              </el-table>
              <el-table
                v-if="readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack_validation?.issues?.length"
                :data="readiness.legacy_security_public_executable_remediation_wave_signoff_handoff_signoff_operator_pack_validation.issues.slice(0, 10)"
                border
                class="preview-section-table"
              >
                <el-table-column prop="severity" label="级别" width="100">
                  <template #default="{ row }">
                    <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
                  </template>
                </el-table-column>
                <el-table-column prop="field" label="字段" min-width="180" />
                <el-table-column prop="code" label="规则" min-width="220" />
                <el-table-column prop="message" label="说明" min-width="420" />
              </el-table>
            </template>
          </template>
          <el-table :data="securityPublicExecutableValidationIssues" border class="preview-section-table">
            <el-table-column prop="severity" label="级别" width="100">
              <template #default="{ row }">
                <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="row_number" label="行号" width="90" />
            <el-table-column prop="item_id" label="#" width="70" />
            <el-table-column prop="relative_path" label="路径" min-width="300" />
            <el-table-column prop="field" label="字段" min-width="130" />
            <el-table-column prop="code" label="规则" min-width="200" />
            <el-table-column prop="message" label="说明" min-width="340" />
          </el-table>
          <el-table :data="securityPublicExecutableSamples" border class="preview-section-table">
            <el-table-column prop="item_id" label="#" width="70" />
            <el-table-column label="级别" width="100">
              <template #default="{ row }">
                <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column label="类别" min-width="170">
              <template #default="{ row }">{{ securityCategoryLabel(row.category) }}</template>
            </el-table-column>
            <el-table-column prop="relative_path" label="路径" min-width="360" />
            <el-table-column prop="recommended_action" label="建议动作" min-width="360" />
            <el-table-column prop="acceptance" label="验收标准" min-width="360" />
          </el-table>
        </template>
        <div class="preview-summary">
          <el-tag :type="readinessStatusType(readiness.legacy_security_baseline_signoff?.overall_status)">
            签收 {{ readiness.legacy_security_baseline_signoff?.overall_status || 'missing' }}
          </el-tag>
          <el-tag type="warning">{{ readiness.legacy_security_baseline_signoff?.summary?.pending_items || 0 }} 个 pending</el-tag>
          <el-tag type="success">{{ readiness.legacy_security_baseline_signoff?.summary?.mitigated_items || 0 }} 个 mitigated</el-tag>
          <el-tag type="info">{{ readiness.legacy_security_baseline_signoff?.summary?.accepted_with_risk_items || 0 }} 个 risk accepted</el-tag>
          <el-tag :type="readiness.legacy_security_baseline_signoff?.summary?.blocked_items ? 'danger' : 'info'">
            {{ readiness.legacy_security_baseline_signoff?.summary?.blocked_items || 0 }} 个 blocked
          </el-tag>
          <el-tag :type="readiness.legacy_security_baseline_signoff_validation?.summary?.warnings ? 'warning' : 'info'">
            校验 warning {{ readiness.legacy_security_baseline_signoff_validation?.summary?.warnings || 0 }}
          </el-tag>
        </div>
        <el-table :data="readiness.legacy_security_baseline_signoff?.items || []" border class="preview-section-table">
          <el-table-column prop="status" label="状态" width="130">
            <template #default="{ row }">
              <el-tag :type="readinessStatusType(row.status)">{{ row.status }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="step_key" label="步骤" min-width="120" />
          <el-table-column prop="category" label="类别" min-width="150" />
          <el-table-column prop="title" label="事项" min-width="280" />
          <el-table-column prop="required_action" label="要求动作" min-width="360" />
          <el-table-column prop="owner" label="负责人" min-width="130" />
          <el-table-column prop="resolved_by" label="确认人" min-width="130" />
          <el-table-column prop="resolved_at" label="确认时间" min-width="160" />
          <el-table-column prop="evidence_ref" label="证据" min-width="220" />
          <el-table-column prop="notes" label="备注" min-width="260" />
        </el-table>
        <el-table :data="readiness.legacy_security_baseline_signoff_validation?.issues || []" border class="preview-section-table">
          <el-table-column prop="severity" label="级别" width="100">
            <template #default="{ row }">
              <el-tag :type="row.severity === 'blocker' ? 'danger' : 'warning'">{{ row.severity }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="row_number" label="行号" width="90" />
          <el-table-column prop="step_key" label="步骤" min-width="120" />
          <el-table-column prop="field" label="字段" min-width="130" />
          <el-table-column prop="code" label="规则" min-width="200" />
          <el-table-column prop="message" label="说明" min-width="340" />
        </el-table>
      </template>
    </el-card>

    <el-card shadow="never">
      <template #header>上线演练报告</template>
      <div class="preview-summary">
        <el-tag type="info">Markdown 模板</el-tag>
        <el-tag type="warning">需人工补充确认记录</el-tag>
        <el-tag :type="readinessStatusType(readiness.migration_operational_docs_validation?.overall_status)">
          文档校验 {{ readiness.migration_operational_docs_validation?.overall_status || 'missing' }}
        </el-tag>
        <el-tag :type="readiness.migration_operational_docs_validation?.summary?.missing_sections ? 'danger' : 'info'">
          缺章节 {{ readiness.migration_operational_docs_validation?.summary?.missing_sections || 0 }}
        </el-tag>
        <el-tag :type="readiness.migration_operational_docs_validation?.summary?.missing_safety_phrases ? 'danger' : 'info'">
          缺安全语句 {{ readiness.migration_operational_docs_validation?.summary?.missing_safety_phrases || 0 }}
        </el-tag>
      </div>
      <el-table
        v-if="readiness.migration_operational_docs_validation?.issues?.length"
        :data="readiness.migration_operational_docs_validation.issues.slice(0, 10)"
        border
        class="preview-section-table"
      >
        <el-table-column label="级别" width="110">
          <template #default="{ row }">
            <el-tag :type="row.severity === 'blocker' ? 'danger' : row.severity === 'warning' ? 'warning' : 'info'">{{ row.severity }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="document" label="文档" min-width="180" />
        <el-table-column prop="field" label="字段" min-width="160" />
        <el-table-column prop="code" label="规则" min-width="200" />
        <el-table-column prop="message" label="说明" min-width="420" />
      </el-table>
      <el-table :data="goLiveReportRows" border>
        <el-table-column prop="section" label="章节" width="180" />
        <el-table-column prop="content" label="内容" min-width="320" />
      </el-table>
    </el-card>

    <el-card shadow="never">
      <template #header>回滚方案</template>
      <div class="preview-summary">
        <el-tag type="danger">禁止回写旧库</el-tag>
        <el-tag type="warning">真实执行前必须确认备份</el-tag>
        <el-tag type="info">Markdown 模板</el-tag>
      </div>
      <el-table :data="rollbackPlanRows" border>
        <el-table-column prop="section" label="章节" width="180" />
        <el-table-column prop="content" label="内容" min-width="360" />
      </el-table>
    </el-card>

    <el-card shadow="never">
      <template #header>操作手册</template>
      <div class="preview-summary">
        <el-tag type="info">Runbook</el-tag>
        <el-tag type="success">默认 dry-run</el-tag>
        <el-tag type="danger">真实执行需人工确认</el-tag>
      </div>
      <el-table :data="operatorRunbookRows" border>
        <el-table-column prop="step" label="步骤" width="80" />
        <el-table-column prop="name" label="操作" min-width="180" />
        <el-table-column prop="detail" label="说明" min-width="360" />
      </el-table>
    </el-card>

    <el-card shadow="never">
      <template #header>数据库导入 dry-run 命令</template>
      <div class="preview-summary">
        <el-tag type="success">dry-run only</el-tag>
        <el-tag type="danger">--execute 尚未实现</el-tag>
      </div>
      <el-table :data="importCommandRows" border>
        <el-table-column prop="target" label="目标" width="160" />
        <el-table-column prop="command" label="命令" min-width="360" />
        <el-table-column prop="report" label="读取报告" min-width="260" />
      </el-table>
    </el-card>

    <el-card shadow="never">
      <template #header>下一步执行顺序</template>
      <el-steps :active="1" finish-status="success" align-center>
        <el-step title="报告生成" description="核心表和风险扫描已产出" />
        <el-step title="字段映射" description="确认旧字段到新模型的映射" />
        <el-step title="Dry Run" description="运行 legacy:import-records all --output" />
        <el-step title="抽样验收" description="核对单位、项目、附件、审核记录" />
      </el-steps>
    </el-card>
  </section>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { api } from '../api.js'
import { useTextStore } from '../texts.js'

const texts = useTextStore()
const loading = ref(false)
const batchLoading = ref(false)
const readiness = ref({ items: [] })
const batches = ref([])
const pipelineSteps = [
  { step: '1', name: '附件质量', command: 'New-LegacyAttachmentQualityReport.ps1' },
  { step: '2', name: '附件索引与 dry-run', command: 'New-LegacyAttachmentImportIndex.ps1 / Invoke-LegacyAttachmentImportDryRun.ps1' },
  { step: '2a', name: '附件异常操作包校验', command: 'Test-LegacyAttachmentExceptionOperatorPack.ps1' },
  { step: '3', name: '项目核心数据', command: 'New-LegacyProjectDbDryRun.ps1' },
  { step: '4', name: '单位/用户映射', command: 'New-LegacyUnitUserIdMap.ps1' },
  { step: '5', name: '附件数据库记录', command: 'New-LegacyProjectFileDbDryRun.ps1' },
  { step: '5a', name: '阻断处理清单', command: 'New-LegacyMigrationBlockerActionSheet.ps1' },
  { step: '5b', name: '阻断处理清单校验', command: 'Test-LegacyMigrationBlockerActionSheet.ps1' },
  { step: '6', name: '阻断处置包', command: 'New-LegacyMigrationBlockerResolutionPack.ps1' },
  { step: '6a', name: '阻断处置包校验', command: 'Test-LegacyMigrationBlockerResolutionPack.ps1' },
  { step: '7', name: '阻断处置签收', command: 'New-LegacyMigrationBlockerResolutionSignoff.ps1' },
  { step: '8', name: '阻断签收校验', command: 'Test-LegacyMigrationBlockerResolutionSignoff.ps1' },
  { step: '9', name: '阻断处置操作包', command: 'New-LegacyMigrationBlockerResolutionOperatorPack.ps1' },
  { step: '9a', name: '阻断处置操作包校验', command: 'Test-LegacyMigrationBlockerResolutionOperatorPack.ps1' },
  { step: '10', name: '映射模板保护', command: 'New-LegacyMigrationResolutionTemplates.ps1，默认保留已存在 CSV；重建需 -ForceResolutionTemplates' },
  { step: '11', name: '映射模板校验', command: 'Test-LegacyMigrationResolutionTemplates.ps1' },
  { step: '12', name: '模板填写进度', command: 'New-LegacyMigrationResolutionProgress.ps1' },
  { step: '13', name: '模板任务清单', command: 'New-LegacyMigrationResolutionWorklist.ps1' },
  { step: '14', name: '逐行任务 CSV', command: 'New-LegacyMigrationResolutionRowWorklist.ps1' },
  { step: '15', name: '负责人逐行 CSV', command: 'New-LegacyMigrationResolutionOwnerRowWorklists.ps1' },
  { step: '16', name: '负责人模板 CSV', command: 'New-LegacyMigrationResolutionOwnerTemplateRowWorklists.ps1' },
  { step: '17', name: '映射分发包', command: 'New-LegacyMigrationResolutionDistributionPack.ps1' },
  { step: '18', name: '分发签收表', command: 'New-LegacyMigrationResolutionDistributionSignoff.ps1' },
  { step: '19', name: '签收表校验', command: 'Test-LegacyMigrationResolutionDistributionSignoff.ps1' },
  { step: '20', name: '负责人任务 CSV', command: 'New-LegacyMigrationResolutionOwnerWorklists.ps1' },
  { step: '21', name: '模板导入预览', command: 'New-LegacyMigrationResolutionImportPreview.ps1' },
  { step: '22', name: 'Resolved 映射预览', command: 'New-LegacyResolvedMappingReports.ps1' },
  { step: '23', name: 'Resolved Dry Run', command: 'Invoke-LegacyResolvedMappingDryRun.ps1' },
  { step: '24', name: 'Dry Run 对比', command: 'New-LegacyMigrationDryRunComparison.ps1' },
  { step: '25', name: '映射签收闸门', command: 'New-LegacyMigrationResolutionAcceptanceGate.ps1' },
  { step: '25a', name: '映射操作包校验', command: 'Test-LegacyMigrationResolutionOperatorPack.ps1' },
  { step: '25b', name: '上线演练报告', command: 'New-LegacyMigrationGoLiveDrillReport.ps1' },
  { step: '25c', name: '回滚方案', command: 'New-LegacyMigrationRollbackPlan.ps1' },
  { step: '25d', name: '操作手册', command: 'New-LegacyMigrationOperatorRunbook.ps1' },
  { step: '25e', name: '运维文档校验', command: 'Test-LegacyMigrationOperationalDocs.ps1' },
  { step: '26', name: '上线角色签收', command: 'New-LegacyMigrationGoLiveSignoff.ps1' },
  { step: '27', name: '角色签收校验', command: 'Test-LegacyMigrationGoLiveSignoff.ps1' },
  { step: '28', name: '角色签收操作包', command: 'New-LegacyMigrationGoLiveSignoffOperatorPack.ps1' },
  { step: '28a', name: '角色签收操作包校验', command: 'Test-LegacyMigrationGoLiveSignoffOperatorPack.ps1' },
  { step: '29', name: '流程行级预览', command: 'New-LegacyWorkflowDbDryRun.ps1' },
  { step: '30', name: '孤儿流程处理签收', command: 'New-LegacyWorkflowOrphanResolutionSignoff.ps1' },
  { step: '31', name: '孤儿流程处理校验', command: 'Test-LegacyWorkflowOrphanResolutionSignoff.ps1' },
  { step: '32', name: '孤儿流程操作包', command: 'New-LegacyWorkflowOrphanOperatorPack.ps1' },
  { step: '32a', name: '孤儿流程操作包校验', command: 'Test-LegacyWorkflowOrphanOperatorPack.ps1' },
  { step: '33', name: '抽样验收签收', command: 'New-LegacyMigrationSamplingAcceptanceSignoff.ps1' },
  { step: '34', name: '抽样验收校验', command: 'Test-LegacyMigrationSamplingAcceptanceSignoff.ps1' },
  { step: '35', name: '抽样验收操作包', command: 'New-LegacyMigrationSamplingAcceptanceOperatorPack.ps1' },
  { step: '35a', name: '抽样验收操作包校验', command: 'Test-LegacyMigrationSamplingAcceptanceOperatorPack.ps1' },
  { step: '36', name: '上线总闸门', command: 'New-LegacyMigrationGoLiveGate.ps1' },
  { step: '36a', name: '上线总闸门校验', command: 'Test-LegacyMigrationGoLiveGate.ps1' },
  { step: '36b', name: '执行前置条件校验', command: 'Test-LegacyMigrationPreflightChecklist.ps1' },
  { step: '37', name: '公开可执行清单校验', command: 'Test-LegacySecurityPublicExecutableWorklist.ps1' },
  { step: '38', name: '公开可执行处置计划', command: 'New-LegacySecurityPublicExecutableRemediationPlan.ps1' },
  { step: '39', name: '公开可执行处置计划校验', command: 'Test-LegacySecurityPublicExecutableRemediationPlan.ps1' },
  { step: '40', name: '公开可执行波次分发包', command: 'New-LegacySecurityPublicExecutableRemediationWaveFiles.ps1' },
  { step: '41', name: '公开可执行波次包校验', command: 'Test-LegacySecurityPublicExecutableRemediationWaveFiles.ps1' },
  { step: '42', name: '公开可执行波次签收', command: 'New-LegacySecurityPublicExecutableRemediationWaveSignoff.ps1' },
  { step: '43', name: '公开可执行波次签收校验', command: 'Test-LegacySecurityPublicExecutableRemediationWaveSignoff.ps1' },
  { step: '44', name: '公开可执行波次签收操作包', command: 'New-LegacySecurityPublicExecutableRemediationWaveSignoffOperatorPack.ps1' },
  { step: '45', name: '公开可执行波次签收操作包校验', command: 'Test-LegacySecurityPublicExecutableRemediationWaveSignoffOperatorPack.ps1' },
  { step: '46', name: '公开可执行波次签收交接包', command: 'New-LegacySecurityPublicExecutableRemediationWaveSignoffHandoffPack.ps1' },
  { step: '47', name: '公开可执行波次签收交接包校验', command: 'Test-LegacySecurityPublicExecutableRemediationWaveSignoffHandoffPack.ps1' },
  { step: '48', name: '公开可执行波次签收交接签收', command: 'New-LegacySecurityPublicExecutableRemediationWaveSignoffHandoffSignoff.ps1' },
  { step: '49', name: '公开可执行波次签收交接签收校验', command: 'Test-LegacySecurityPublicExecutableRemediationWaveSignoffHandoffSignoff.ps1' },
  { step: '50', name: '公开可执行波次签收交接签收操作包', command: 'New-LegacySecurityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack.ps1' },
  { step: '51', name: '公开可执行波次签收交接签收操作包校验', command: 'Test-LegacySecurityPublicExecutableRemediationWaveSignoffHandoffSignoffOperatorPack.ps1' },
  { step: '52', name: '安全基线操作包', command: 'New-LegacySecurityBaselineOperatorPack.ps1' },
  { step: '53', name: '安全基线操作包校验', command: 'Test-LegacySecurityBaselineOperatorPack.ps1' },
  { step: '54', name: '上线证据包', command: 'New-LegacyMigrationGoLiveEvidencePack.ps1' },
  { step: '54a', name: '上线证据包校验', command: 'Test-LegacyMigrationGoLiveEvidencePack.ps1' },
  { step: '54b', name: '归档清单校验', command: 'Test-LegacyMigrationArtifactManifest.ps1' },
  { step: '55', name: '上线演练操作包', command: 'New-LegacyMigrationGoLiveDrillOperatorPack.ps1' },
  { step: '56', name: '上线演练操作包校验', command: 'Test-LegacyMigrationGoLiveDrillOperatorPack.ps1' },
  { step: '57', name: '下一步行动清单', command: 'New-LegacyMigrationNextActionsReport.ps1' },
  { step: '57a', name: '下一步行动清单校验', command: 'Test-LegacyMigrationNextActions.ps1' },
  { step: '58', name: '负责人分发包校验', command: 'Test-LegacyMigrationNextActionsOwnerFiles.ps1' },
  { step: '59', name: '负责人签收表', command: 'New-LegacyMigrationNextActionsOwnerSignoff.ps1' },
  { step: '60', name: '负责人签收表校验', command: 'Test-LegacyMigrationNextActionsOwnerSignoff.ps1' },
  { step: '61', name: '负责人签收操作包', command: 'New-LegacyMigrationNextActionsOwnerSignoffOperatorPack.ps1' },
  { step: '62', name: '负责人签收操作包校验', command: 'Test-LegacyMigrationNextActionsOwnerSignoffOperatorPack.ps1' },
  { step: '63', name: '前置阻断操作包校验', command: 'Test-LegacyMigrationPreflightBlockerOperatorPack.ps1' },
]
const goLiveReportRows = [
  { section: '总体结论', content: '迁移就绪、前置条件、批次计划总体状态。' },
  { section: '核心数据范围', content: '单位、用户、项目、附件记录和附件复制项。' },
  { section: '附件 dry-run', content: '可复制、阻断、路径冲突、越界和预计复制体积。' },
  { section: '批次导入计划', content: '按 units/users/projects/attachment_copy/project_files 展示。' },
  { section: '前置条件', content: 'blocker/warning/info/done 清单。' },
  { section: '验收记录', content: '运维、业务、回滚、上线窗口和遗留风险人工填写。' },
]
const rollbackPlanRows = [
  { section: '回滚目标', content: '旧系统只读查询可恢复，新系统写入可暂停，证据可保留。' },
  { section: '触发条件', content: '核心流程不可用、数据系统性错误、附件错绑、错误率超阈值。' },
  { section: '备份确认', content: '旧库只读副本、新库快照、附件目录、配置文件和入口配置。' },
  { section: '入口切换', content: '暂停新系统写入，恢复旧系统历史查询只读入口。' },
  { section: '数据库回滚', content: '优先恢复新库快照；不回写旧库。' },
  { section: '附件回滚', content: '只删除本次复制到新系统私有目录的目标文件。' },
]
const operatorRunbookRows = [
  { step: '1', name: '生成报告流水线', detail: '运行 Invoke-LegacyMigrationReportPipeline.ps1 -WithMock。' },
  { step: '2', name: '检查前置条件', detail: '确认 preflight checklist 无 blocker。' },
  { step: '3', name: '业务抽样验收', detail: '核对单位、项目、附件、审核记录。' },
  { step: '4', name: '确认备份回滚', detail: '确认新库快照、附件目录、入口配置和回滚方案。' },
  { step: '5', name: '附件真实复制', detail: '仅 dry-run 通过后显式运行附件复制 -Execute。' },
  { step: '6', name: '数据库真实导入', detail: '确认 batch plan ready 后按依赖顺序执行。' },
]
const resolvedMappingRows = computed(() => [
  { target: 'unit_user_mapping', total: readiness.value.unit_user_id_map_resolved?.summary?.total_units || 0, resolved: readiness.value.unit_user_id_map_resolved?.summary?.mapped_units || 0, pending: readiness.value.unit_user_id_map_resolved?.summary?.pending_units || 0, blocked: readiness.value.unit_user_id_map_resolved?.summary?.blocked_units || 0 },
  { target: 'project_mapping', total: readiness.value.project_id_map_resolved?.summary?.total_projects || 0, resolved: readiness.value.project_id_map_resolved?.summary?.mapped_projects || 0, pending: readiness.value.project_id_map_resolved?.summary?.pending_projects || 0, blocked: readiness.value.project_id_map_resolved?.summary?.blocked_projects || 0 },
  { target: 'attachment_exception', total: readiness.value.attachment_exceptions_resolved?.summary?.total_exceptions || 0, resolved: readiness.value.attachment_exceptions_resolved?.summary?.ready_exceptions || 0, pending: readiness.value.attachment_exceptions_resolved?.summary?.pending_exceptions || 0, blocked: readiness.value.attachment_exceptions_resolved?.summary?.blocked_exceptions || 0 },
])

const resolvedDryRunRows = computed(() => [
  { target: 'unit_users', total: readiness.value.unit_user_db_dry_run_resolved?.summary?.total_users || 0, ready: readiness.value.unit_user_db_dry_run_resolved?.summary?.ready_users || 0, waiting: readiness.value.unit_user_db_dry_run_resolved?.summary?.users_waiting_unit_mapping || 0, blocked: 0 },
  { target: 'projects', total: readiness.value.project_db_dry_run_resolved?.summary?.total_records || 0, ready: readiness.value.project_db_dry_run_resolved?.summary?.ready_for_import || 0, waiting: readiness.value.project_db_dry_run_resolved?.summary?.ready_for_unit_user_mapping || 0, blocked: 0 },
  { target: 'project_files', total: readiness.value.project_file_db_dry_run_resolved?.summary?.total_records || 0, ready: readiness.value.project_file_db_dry_run_resolved?.summary?.ready_for_import || 0, waiting: readiness.value.project_file_db_dry_run_resolved?.summary?.ready_for_project_mapping || 0, blocked: readiness.value.project_file_db_dry_run_resolved?.summary?.blocked_records || 0 },
])

const dryRunComparisonRows = computed(() => (readiness.value.migration_dry_run_comparison?.rows || []).map((row) => ({
  target: row.target,
  defaultReady: row.default?.ready || 0,
  resolvedReady: row.resolved?.ready || 0,
  mockReady: row.mock?.ready || 0,
  resolvedDelta: row.delta?.resolved_ready_vs_default || 0,
  resolvedWaiting: row.resolved?.waiting || 0,
  resolvedBlocked: row.resolved?.blocked || 0,
})))

const recordImportBlockerRows = computed(() => countObjectRows(readiness.value.record_import_plan?.summary?.blocker_counts || {}))
const recordImportBlockedSamples = computed(() => {
  const targets = readiness.value.record_import_plan?.targets || []
  return targets.flatMap((target) => (target.sample_records || [])
    .filter((record) => (record.blockers || []).length)
    .map((record) => ({ ...record, target: target.target })))
    .slice(0, 20)
})
const projectFileDbBlockerRows = computed(() => issueCountRows(readiness.value.project_file_db_dry_run?.samples?.blocked || []))
const securityPublicExecutableCategoryRows = computed(() => countObjectRows(readiness.value.legacy_security_public_executable_worklist?.summary?.category_counts || {}))
const securityPublicExecutableSamples = computed(() => (readiness.value.legacy_security_public_executable_worklist?.items || []).slice(0, 20))
const securityPublicExecutableValidationIssues = computed(() => (readiness.value.legacy_security_public_executable_worklist_validation?.issues || []).slice(0, 20))

const operatorPackFiles = computed(() => {
  const files = readiness.value.attachment_exception_operator_pack?.operator_files || {}
  return Object.entries(files).map(([key, path]) => ({ key, path }))
})

const distributionPackFiles = computed(() => {
  const files = readiness.value.migration_resolution_distribution_pack?.files || {}
  return Object.entries(files).map(([key, path]) => ({ key, path }))
})

const importCommandRows = [
  { target: 'units', command: 'php artisan legacy:import-records units', report: 'legacy-unit-user-db-dry-run.json' },
  { target: 'users', command: 'php artisan legacy:import-records users', report: 'legacy-unit-user-db-dry-run.json' },
  { target: 'projects', command: 'php artisan legacy:import-records projects', report: 'legacy-project-db-dry-run.json' },
  { target: 'project_files', command: 'php artisan legacy:import-records project_files', report: 'legacy-project-file-db-dry-run.json' },
  { target: 'migration_batches', command: 'php artisan legacy:import-records migration_batches', report: 'legacy-migration-batch-db-dry-run.json' },
  { target: 'all', command: 'php artisan legacy:import-records all --output=../scripts/legacy-record-import-plan.json', report: '全部 dry-run 报告摘要和前端就绪页 JSON' },
]

async function loadReadiness() {
  loading.value = true
  try {
    readiness.value = await api('/migration/readiness')
  } finally {
    loading.value = false
  }
}

async function loadBatches() {
  batchLoading.value = true
  try {
    const result = await api('/migration/batches')
    batches.value = result.data || result
  } catch {
    batches.value = []
  } finally {
    batchLoading.value = false
  }
}

function compactRow(row) {
  const copy = { ...row }
  delete copy.metadata
  return JSON.stringify(copy, null, 2)
}

function sectionTabLabel(section) {
  const count = section.row_count ?? (section.rows || []).length
  const warning = (section.warnings || []).length ? ' !' : ''
  return `${section.source_table} -> ${section.target_table} (${count})${warning}`
}

function formatBytes(bytes) {
  const value = Number(bytes || 0)
  if (value < 1024) return `${value} B`
  if (value < 1024 * 1024) return `${(value / 1024).toFixed(1)} KB`
  if (value < 1024 * 1024 * 1024) return `${(value / 1024 / 1024).toFixed(1)} MB`
  return `${(value / 1024 / 1024 / 1024).toFixed(2)} GB`
}

function formatCounts(counts) {
  if (!counts || typeof counts !== 'object') return '-'
  const entries = Object.entries(counts).filter(([, value]) => value !== null && value !== undefined)
  if (!entries.length) return '-'
  return entries.map(([key, value]) => `${key}: ${value}`).join(', ')
}

function formatBlockerCounts(counts) {
  if (!counts || typeof counts !== 'object') return '-'
  const entries = Object.entries(counts).filter(([, value]) => value !== null && value !== undefined)
  if (!entries.length) return '-'
  return entries.map(([key, value]) => `${blockerLabel(key)}: ${value}`).join(', ')
}

function countObjectRows(counts) {
  if (!counts || typeof counts !== 'object') return []
  return Object.entries(counts)
    .filter(([, value]) => Number(value || 0) > 0)
    .sort((a, b) => Number(b[1] || 0) - Number(a[1] || 0))
    .map(([reason, count]) => ({ reason, count }))
}

function issueCountRows(rows) {
  if (!Array.isArray(rows)) return []
  const counts = {}
  rows.forEach((row) => {
    ;[...(row.blockers || []), ...(row.warnings || [])].filter(Boolean).forEach((reason) => {
      counts[reason] = (counts[reason] || 0) + 1
    })
  })
  return Object.entries(counts)
    .sort((a, b) => b[1] - a[1])
    .map(([reason, count]) => ({ reason, count }))
}

function blockerLabel(value) {
  const labels = {
    'project_file.invalid_disk': '附件磁盘异常',
    'project_file.invalid_path': '附件路径异常',
    missing_file: '源文件缺失',
    source_missing_at_dry_run: '预演源文件缺失',
    attachment_not_ready: '附件未就绪',
    project_id_mapping_required: '项目映射缺失',
    unit_id_mapping_required: '单位映射缺失',
    owner_id_mapping_required: '负责人映射缺失',
    blocked_by_attachment: '附件复制阻断'
  }
  return labels[value] || value || '-'
}

function securityCategoryLabel(value) {
  const labels = {
    uploaded_payload: '上传载荷',
    double_extension_payload: '双扩展伪装',
    editor_or_demo_handler: '编辑器/示例入口',
    cross_language_sample: '跨语言样例',
    legacy_public_admin: '旧后台公开脚本',
    static_path_script: '静态目录脚本',
    legacy_public_script: '旧公开脚本',
  }
  return labels[value] || value || '-'
}

function formatBlockers(row) {
  const values = [...(row.blockers || []), ...(row.warnings || [])].filter(Boolean)
  if (!values.length) return '-'
  return values.map(blockerLabel).join(', ')
}

function formatLookup(lookup) {
  if (!lookup || typeof lookup !== 'object') return '-'
  const entries = Object.entries(lookup).filter(([, value]) => value !== null && value !== undefined)
  if (!entries.length) return '-'
  return entries.map(([key, value]) => `${key}: ${value}`).join(', ')
}

function formatStorageSummary(row) {
  const attrs = row.attributes || {}
  const values = []
  if (attrs.disk) values.push(`disk: ${attrs.disk}`)
  if (attrs.path) values.push(`path: ${attrs.path}`)
  return values.join(' / ') || '-'
}

function formatMissingFields(fields) {
  if (!Array.isArray(fields) || !fields.length) return '-'
  return fields.map((item) => `${item.field}: ${item.count}`).join(', ')
}

function formatSampleRows(rows) {
  if (!Array.isArray(rows) || !rows.length) return '-'
  return rows.map((row) => `#${row.row_number}(${row.legacy_id || '-'})`).join(', ')
}

function formatPreviewChanges(changes) {
  if (!Array.isArray(changes) || !changes.length) return '-'
  return changes
    .filter((item) => item.preview_value)
    .map((item) => `${item.field}: ${item.preview_value}`)
    .join(', ') || '-'
}

function formatList(values) {
  if (!Array.isArray(values) || !values.length) return '-'
  return values.filter(Boolean).join(', ') || '-'
}

function nextStepTitle(step) {
  const value = Array.isArray(step) ? step[0] : step
  return value?.title || '-'
}

function readinessStatusType(status) {
  if (status === 'ready' || status === 'pass' || status === 'signed' || status === 'completed' || status === 'accepted') return 'success'
  if (status === 'blocked' || status === 'missing' || status === 'fail' || status === 'rejected') return 'danger'
  if (status === 'warning' || status === 'waiting' || status === 'not_ready' || status === 'accepted_with_risk' || status === 'pending' || status === 'sent') return 'warning'
  return 'info'
}

onMounted(() => {
  loadReadiness()
  loadBatches()
})
</script>






