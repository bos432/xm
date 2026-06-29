<template>
  <section class="page-stack">
    <div class="toolbar">
      <span class="eyebrow">运行概览</span>
      <el-button :icon="Refresh" @click="loadSummary">刷新</el-button>
    </div>

    <div class="metric-grid" v-loading="loading">
      <el-card v-for="item in metrics" :key="item.label" shadow="never" :class="{ 'metric-link': item.to }" @click="goMetric(item)">
        <span>{{ item.label }}</span>
        <strong>{{ item.value }}</strong>
        <small>{{ item.note }}</small>
      </el-card>
    </div>

    <el-card shadow="never" class="workflow-card">
      <template #header>
        <div class="workflow-head">
          <div>
            <strong>科研项目申报与管理全流程</strong>
            <span>按当前系统角色和状态流转整理</span>
          </div>
          <el-tag type="primary" effect="plain">{{ currentRoleLabel }}</el-tag>
        </div>
      </template>

      <el-tabs v-model="workflowTab" class="workflow-tabs">
        <el-tab-pane label="项目申报流程" name="application">
          <div class="workflow-lanes">
            <div v-for="(lane, index) in applicationWorkflow" :key="lane.key" class="workflow-lane-wrap">
              <article :class="laneClass(lane)">
                <div class="workflow-lane-title">
                  <strong>{{ lane.title }}</strong>
                  <span>{{ lane.owner }}</span>
                </div>
                <div class="workflow-step-list">
                  <div v-for="step in lane.steps" :key="step.code" class="workflow-step">
                    <b>{{ step.code }}</b>
                    <strong>{{ step.title }}</strong>
                    <span>{{ step.body }}</span>
                  </div>
                </div>
              </article>
              <span v-if="index < applicationWorkflow.length - 1" class="workflow-arrow">→</span>
            </div>
          </div>

          <div class="workflow-outcomes">
            <span>通过：进入下一审核阶段，管理员终审后变为“已通过”。</span>
            <span>退回：回到申报单位，修改后可再次提交。</span>
            <span>驳回：申报链结束，项目状态为“已驳回”。</span>
          </div>
        </el-tab-pane>

        <el-tab-pane label="项目验收流程" name="acceptance">
          <div class="workflow-lanes">
            <div v-for="(lane, index) in acceptanceWorkflow" :key="lane.key" class="workflow-lane-wrap">
              <article :class="laneClass(lane)">
                <div class="workflow-lane-title">
                  <strong>{{ lane.title }}</strong>
                  <span>{{ lane.owner }}</span>
                </div>
                <div class="workflow-step-list">
                  <div v-for="step in lane.steps" :key="step.code" class="workflow-step">
                    <b>{{ step.code }}</b>
                    <strong>{{ step.title }}</strong>
                    <span>{{ step.body }}</span>
                  </div>
                </div>
              </article>
              <span v-if="index < acceptanceWorkflow.length - 1" class="workflow-arrow">→</span>
            </div>
          </div>

          <div class="workflow-outcomes">
            <span>通过：验收申请继续流转到下一阶段。</span>
            <span>退回：单位补充验收材料后可再次提交。</span>
            <span>终审关闭：项目状态变为“已关闭”，完成归档。</span>
          </div>
        </el-tab-pane>
      </el-tabs>

      <div class="workflow-role-note">
        <strong>当前角色关注点</strong>
        <span>{{ currentRoleTip }}</span>
      </div>
    </el-card>

    <el-card v-if="summary?.migration" shadow="never">
      <template #header>迁移与上线门禁</template>
      <div class="metric-grid compact-grid">
        <div>
          <span>预检状态</span>
          <strong>{{ summary.migration.preflight?.status || '-' }}</strong>
          <small>阻塞 {{ summary.migration.preflight?.blockers?.length || summary.migration.preflight?.summary?.blockers || 0 }}</small>
        </div>
        <div>
          <span>上线门禁</span>
          <strong>{{ summary.migration.go_live_gate?.status || '-' }}</strong>
          <small>仅管理员可见</small>
        </div>
        <div>
          <span>最近批次</span>
          <strong>{{ summary.migration.latest_batch?.status || '-' }}</strong>
          <small>{{ summary.migration.latest_batch?.name || '暂无批次' }}</small>
        </div>
        <div>
          <span>并行策略</span>
          <strong>旧新并行</strong>
          <small>新项目进入新系统</small>
        </div>
      </div>
    </el-card>

    <el-card v-if="summary?.security" shadow="never">
      <template #header>安全概览</template>
      <div class="metric-grid compact-grid security-grid">
        <div>
          <span>24 小时安全事件</span>
          <strong>{{ summary.security.security_events_24h || 0 }}</strong>
          <small>管理员可见</small>
        </div>
        <div>
          <span>最近安全事件</span>
          <strong>{{ summary.security.recent_security_events?.length || 0 }}</strong>
          <small>登录、会话与附件异常</small>
        </div>
      </div>
      <el-table :data="summary.security.recent_security_events || []" border size="small">
        <el-table-column label="事件" width="130">
          <template #default="{ row }">{{ securityEventAction(row.type || row.action) }}</template>
        </el-table-column>
        <el-table-column label="账号" min-width="150">
          <template #default="{ row }">{{ row.user?.username || row.username || row.payload?.username || '-' }}</template>
        </el-table-column>
        <el-table-column label="原因" width="150">
          <template #default="{ row }">{{ failedLoginReason(row.payload?.reason) }}</template>
        </el-table-column>
        <el-table-column prop="ip_address" label="IP" width="140" />
        <el-table-column prop="created_at" label="时间" width="180" />
        <el-table-column label="操作" width="90" align="center">
          <template #default="{ row }">
            <el-tooltip content="查看相关日志" placement="top">
              <el-button :icon="Files" circle size="small" @click="openRelatedLogs(row)" />
            </el-tooltip>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-card shadow="never">
      <template #header>最近操作</template>
      <el-table :data="summary?.operation_logs?.recent || []" border v-loading="loading">
        <el-table-column label="动作" width="190">
          <template #default="{ row }">{{ actionLabel(row.action) }}</template>
        </el-table-column>
        <el-table-column prop="user.username" label="账号" width="140" />
        <el-table-column prop="user.role" label="角色" width="110" />
        <el-table-column prop="target_type" label="对象类型" min-width="220" />
        <el-table-column prop="created_at" label="时间" width="180" />
        <el-table-column label="操作" width="90" align="center">
          <template #default="{ row }">
            <el-tooltip content="查看相关日志" placement="top">
              <el-button :icon="Files" circle size="small" @click="openRelatedLogs(row)" />
            </el-tooltip>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-card shadow="never">
      <template #header>升级基线</template>
      <el-table :data="baseline" border>
        <el-table-column prop="area" label="领域" width="160" />
        <el-table-column prop="current" label="旧系统风险" />
        <el-table-column prop="target" label="新系统处理" />
      </el-table>
    </el-card>
  </section>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { Files, Refresh } from '@element-plus/icons-vue'
import { useRouter } from 'vue-router'
import { api } from '../api.js'
import { useSessionStore } from '../store.js'

const router = useRouter()
const session = useSessionStore()
const loading = ref(false)
const summary = ref(null)
const workflowTab = ref('application')
const metrics = computed(() => {
  const base = [
    {
    label: '项目总数',
    value: summary.value?.projects?.total ?? 0,
    note: `待处理 ${summary.value?.projects?.submitted_or_reviewing ?? 0}`
    },
    {
    label: '待审任务',
    value: summary.value?.reviews?.pending ?? 0,
    note: '按当前角色统计'
    },
    {
    label: '未读消息',
    value: summary.value?.messages?.unread ?? 0,
    note: '当前账号'
    },
    summary.value?.security
    ? {
        label: '待延期',
        value: summary.value?.acceptance?.pending_extensions ?? 0,
        note: '待管理员处理',
        to: '/projects?pending_extension=1'
      }
    : {
        label: '审核中项目',
        value: summary.value?.projects?.by_status?.reviewing ?? 0,
        note: '当前可见范围'
      }
  ]

  if (summary.value?.registrations) {
    base.push({
      label: '注册待审',
      value: summary.value.registrations.pending_units ?? 0,
      note: `待启用账号 ${summary.value.registrations.pending_users ?? 0}`,
      to: '/units?pending_registration=1'
    })
  }

  if (summary.value?.batches) {
    base.push({
      label: '开放批次',
      value: summary.value.batches.open ?? 0,
      note: summary.value.batches.current?.name || '暂无开放批次',
      to: '/application-batches'
    })
  }

  return base
})

const baseline = [
  { area: '框架', current: 'ThinkPHP 3.1.2，旧 API 和大控制器', target: 'Laravel 11 API，按领域拆分控制器和模型' },
  { area: '文件', current: '公开目录存在上传脚本和历史后门风险', target: '统一文件服务、鉴权下载、扩展名和大小限制' },
  { area: '配置', current: '数据库和接口凭据写在 PHP 配置', target: '.env + 配置表，敏感值脱敏展示' },
  { area: '前端', current: '静态模板和旧组件库混杂', target: 'Vue 3 工作台，角色化导航和任务列表' }
]
const workflowRoleLabels = {
  super_admin: '超级管理员',
  admin: '管理员终审',
  unit: '申报单位',
  county: '区县审核',
  department: '部门审核',
  expert: '专家评审'
}
const workflowRoleTips = {
  unit: '重点处理单位资料、项目草稿、附件上传、提交申报、退回补正，以及立项后的验收材料提交。',
  county: '重点处理项目和验收的区县审核任务，审核通过后流转部门，退回则由单位补正。',
  department: '重点处理部门审核任务，确认业务合规性后流转专家评审或后续验收阶段。',
  expert: '重点处理专家评审和验收评审，项目申报阶段以评分推荐为主。',
  admin: '重点处理批次、单位账号、项目终审、进入验收、验收终审关闭和延期审批。',
  super_admin: '除业务终审外，还负责系统配置、权限、安全、邮件和首页素材等高风险配置。'
}
const applicationWorkflow = [
  {
    key: 'unit-apply',
    role: 'unit',
    title: '申报单位',
    owner: '单位账号',
    steps: [
      { code: '01', title: '注册审核通过', body: '单位和账号启用后才可申报。' },
      { code: '02', title: '选择开放批次', body: '填写项目、预算和类别，保存草稿。' },
      { code: '03', title: '上传附件提交', body: '提交后进入区县审核；未审核前可撤回。' },
      { code: '补正', title: '退回修改', body: '任一阶段退回后，单位修改再提交。' }
    ]
  },
  {
    key: 'county-apply',
    role: 'county',
    title: '区县审核',
    owner: '归口/区县',
    steps: [
      { code: '04', title: '属地初审', body: '可通过、退回或驳回项目。' }
    ]
  },
  {
    key: 'department-apply',
    role: 'department',
    title: '部门审核',
    owner: '主管部门',
    steps: [
      { code: '05', title: '业务审核', body: '通过后进入专家评审。' }
    ]
  },
  {
    key: 'expert-apply',
    role: 'expert',
    title: '专家评审',
    owner: '评审专家',
    steps: [
      { code: '06', title: '评分推荐', body: '推荐后流转管理员终审。' }
    ]
  },
  {
    key: 'admin-apply',
    role: 'admin',
    roles: ['admin', 'super_admin'],
    title: '科技局终审',
    owner: '管理员',
    steps: [
      { code: '07', title: '终审立项', body: '终审通过后项目状态为已通过。' },
      { code: '08', title: '转入验收', body: '管理员将已通过项目转入验收阶段。' }
    ]
  }
]
const acceptanceWorkflow = [
  {
    key: 'unit-acceptance',
    role: 'unit',
    title: '申报单位',
    owner: '项目承担单位',
    steps: [
      { code: '01', title: '发起验收', body: '已通过或验收中项目可创建验收草稿。' },
      { code: '02', title: '上传验收材料', body: '补充验收报告、附件和说明。' },
      { code: '03', title: '提交验收', body: '提交后进入区县验收审核。' },
      { code: '延期', title: '延期申请', body: '验收阶段可提交延期说明。' }
    ]
  },
  {
    key: 'county-acceptance',
    role: 'county',
    title: '区县审核',
    owner: '归口/区县',
    steps: [
      { code: '04', title: '验收初审', body: '审核材料完整性和属地意见。' }
    ]
  },
  {
    key: 'department-acceptance',
    role: 'department',
    title: '部门审核',
    owner: '主管部门',
    steps: [
      { code: '05', title: '业务复核', body: '确认任务完成和材料合规。' }
    ]
  },
  {
    key: 'expert-acceptance',
    role: 'expert',
    title: '专家评审',
    owner: '评审专家',
    steps: [
      { code: '06', title: '验收评审', body: '形成评分和评审意见。' }
    ]
  },
  {
    key: 'admin-acceptance',
    role: 'admin',
    roles: ['admin', 'super_admin'],
    title: '科技局终审',
    owner: '管理员',
    steps: [
      { code: '07', title: '终审关闭', body: '终审通过或关闭后项目归档。' },
      { code: '08', title: '延期审批', body: '处理单位提交的延期申请。' }
    ]
  }
]
const failedLoginReasons = {
  unknown_account: '未知账号',
  inactive_account: '账号停用',
  invalid_password: '密码错误',
  invalid_captcha: '验证码错误',
  password_reset: '密码重置',
  user_deactivated: '账号停用',
  unit_deactivated: '单位停用'
}
const securityEventActions = {
  'auth.login_failed': '登录失败',
  'auth.login': '登录成功',
  'auth.captcha_failed': '验证码失败',
  'security.login_blocked': '登录拦截',
  'security.ip_blacklisted': '黑名单拦截',
  'security.ip_not_whitelisted': '白名单拦截',
  'user.tokens_revoked': '账号会话撤销',
  'unit.tokens_revoked': '单位会话撤销',
  'project_file.invalid_disk': '附件磁盘异常',
  'project_file.invalid_path': '附件路径异常'
}
const actionLabels = {
  ...securityEventActions,
  'auth.login': '登录成功',
  'auth.password_updated': '修改密码',
  'auth.profile_updated': '资料修改',
  'user.created': '账号创建',
  'user.updated': '账号修改',
  'unit.created': '单位创建',
  'unit.updated': '单位修改',
  'project.created': '项目创建',
  'project.updated': '项目修改',
  'project.deleted': '项目删除',
  'project.submitted': '项目提交',
  'project.withdrawn': '项目撤回',
  'project.reviewed': '审核处理',
  'project_file.uploaded': '附件上传',
  'project_file.missing': '附件缺失',
  'project_file.invalid_disk': '附件磁盘异常',
  'project_file.invalid_path': '附件路径异常',
  'project_file.downloaded': '附件下载',
  'project_file.deleted': '附件删除',
  'message.read': '消息已读',
  'message.read_all': '全部消息已读',
  'dictionary_item.created': '字典创建',
  'dictionary_item.updated': '字典修改',
  'setting.updated': '配置修改',
  'project.exported': '项目导出',
  'review_tasks.exported': '审核任务导出',
  'review_results.exported': '审核结果导出',
  'unit.exported': '单位导出',
  'user.exported': '账号导出',
  'operation_log.exported': '导出日志'
}
const currentWorkflowRole = computed(() => (session.role === 'super_admin' ? 'admin' : session.role))
const currentRoleLabel = computed(() => workflowRoleLabels[session.role] || session.role || '未登录')
const currentRoleTip = computed(() => workflowRoleTips[session.role] || '登录后可按角色查看当前关注的流程节点。')

function failedLoginReason(value) {
  return failedLoginReasons[value] || value || '-'
}

function securityEventAction(value) {
  return securityEventActions[value] || value || '-'
}

function actionLabel(value) {
  return actionLabels[value] || value || '-'
}

function goMetric(item) {
  if (item.to) router.push(item.to)
}

function laneIsActive(lane) {
  return (lane.roles || [lane.role]).includes(currentWorkflowRole.value)
}

function laneClass(lane) {
  return ['workflow-lane', { 'is-current': laneIsActive(lane) }]
}

function openRelatedLogs(row) {
  const params = new URLSearchParams()
  if (row.action) params.set('action', row.action)
  if (row.type && !row.action) params.set('keyword', row.type)
  if (row.target_type) params.set('target_type', row.target_type)
  if (row.target_id) params.set('target_id', row.target_id)
  if (!row.target_id && row.ip_address) params.set('ip_address', row.ip_address)
  const keyword = row.user?.username || row.username || row.payload?.username
  if (!row.target_id && keyword && !params.has('keyword')) params.set('keyword', keyword)
  router.push(`/operation-logs?${params.toString()}`)
}

async function loadSummary() {
  loading.value = true
  try {
    summary.value = await api('/dashboard/summary')
  } finally {
    loading.value = false
  }
}

onMounted(loadSummary)
</script>

<style scoped>
.metric-link {
  cursor: pointer;
}

.workflow-card :deep(.el-card__header) {
  background: #f8fbff;
}

.workflow-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.workflow-head div {
  display: grid;
  gap: 4px;
}

.workflow-head strong {
  color: var(--gov-blue-dark);
  font-size: 18px;
}

.workflow-head span {
  color: #64748b;
  font-size: 13px;
}

.workflow-tabs :deep(.el-tabs__header) {
  margin-bottom: 14px;
}

.workflow-lanes {
  display: flex;
  gap: 0;
  overflow-x: auto;
  padding: 2px 2px 10px;
}

.workflow-lane-wrap {
  min-width: 218px;
  display: flex;
  align-items: stretch;
}

.workflow-lane {
  width: 218px;
  min-height: 286px;
  border: 1px solid #cfdceb;
  border-top: 4px solid var(--gov-blue);
  background: #ffffff;
  display: grid;
  grid-template-rows: auto 1fr;
}

.workflow-lane.is-current {
  border-color: var(--gov-red);
  border-top-color: var(--gov-red);
  box-shadow: inset 0 0 0 2px rgba(201, 36, 43, 0.08);
}

.workflow-lane-title {
  min-height: 66px;
  padding: 12px 14px;
  border-bottom: 1px solid #e1e8f0;
  background: #f4f8fc;
  display: grid;
  gap: 4px;
}

.workflow-lane-title strong {
  color: #1f2d3d;
  font-size: 16px;
}

.workflow-lane-title span {
  color: #64748b;
  font-size: 13px;
}

.workflow-step-list {
  padding: 12px;
  display: grid;
  align-content: start;
  gap: 10px;
}

.workflow-step {
  min-height: 86px;
  border: 1px solid #dce6f1;
  background: #fbfdff;
  padding: 10px;
  display: grid;
  gap: 4px;
}

.workflow-step b {
  width: fit-content;
  min-width: 30px;
  height: 22px;
  padding: 0 7px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background: var(--gov-blue);
  color: #ffffff;
  font-size: 12px;
  font-weight: 700;
}

.workflow-lane.is-current .workflow-step b {
  background: var(--gov-red);
}

.workflow-step strong {
  color: #24364a;
  line-height: 1.4;
}

.workflow-step span {
  color: #5f6f82;
  font-size: 13px;
  line-height: 1.55;
}

.workflow-arrow {
  width: 34px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  color: var(--gov-blue);
  font-size: 22px;
  font-weight: 800;
}

.workflow-outcomes,
.workflow-role-note {
  margin-top: 12px;
  border: 1px solid #dce6f1;
  background: #f8fbff;
  padding: 12px 14px;
}

.workflow-outcomes {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
}

.workflow-outcomes span,
.workflow-role-note span {
  color: #516276;
  line-height: 1.7;
}

.workflow-role-note {
  display: grid;
  gap: 5px;
}

.workflow-role-note strong {
  color: var(--gov-blue-dark);
}

@media (max-width: 900px) {
  .workflow-outcomes {
    grid-template-columns: 1fr;
  }
}
</style>
