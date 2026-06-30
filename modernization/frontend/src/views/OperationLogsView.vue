<template>
  <section class="page-stack">
    <div class="toolbar">
      <el-input v-model="keyword" clearable placeholder="按动作、账号、载荷搜索" @keyup.enter="reloadLogs" />
      <el-select v-model="action" clearable filterable allow-create placeholder="动作" @change="reloadLogs">
        <el-option v-for="item in actionOptions" :key="item.value" :label="item.label" :value="item.value" />
      </el-select>
      <el-input v-model="ipAddress" clearable placeholder="按 IP 过滤" @keyup.enter="reloadLogs" />
      <el-input v-model="targetType" clearable placeholder="按对象类型过滤，例如 App\\Models\\Project" @keyup.enter="reloadLogs" />
      <el-input v-model="targetId" clearable placeholder="对象 ID" class="target-id-filter" @keyup.enter="reloadLogs" />
      <el-date-picker
        v-model="dateRange"
        type="daterange"
        value-format="YYYY-MM-DD"
        start-placeholder="开始日期"
        end-placeholder="结束日期"
        @change="reloadLogs"
      />
      <div class="toolbar-actions">
        <el-tooltip content="查询日志" placement="top">
          <el-button type="primary" :icon="Search" circle @click="reloadLogs" />
        </el-tooltip>
        <el-tooltip content="导出当前筛选日志" placement="top">
          <el-button :icon="Download" @click="exportLogs">导出</el-button>
        </el-tooltip>
        <el-tooltip content="刷新日志" placement="top">
          <el-button :icon="Refresh" circle @click="loadLogs" />
        </el-tooltip>
      </div>
    </div>

    <el-table :data="logs" border v-loading="loading">
      <el-table-column label="动作" width="190">
        <template #default="{ row }">{{ actionLabel(row.action) }}</template>
      </el-table-column>
      <el-table-column prop="user.username" label="账号" width="140" />
      <el-table-column prop="user.role" label="角色" width="110" />
      <el-table-column prop="target_type" label="对象类型" min-width="220" />
      <el-table-column prop="target_id" label="对象 ID" width="100" />
      <el-table-column prop="ip_address" label="IP" width="140" />
      <el-table-column prop="created_at" label="时间" width="180" />
      <el-table-column label="操作" width="90" fixed="right">
        <template #default="{ row }">
          <el-tooltip content="查看详情" placement="top">
            <el-button size="small" :icon="View" circle @click="openDetail(row)" />
          </el-tooltip>
        </template>
      </el-table-column>
    </el-table>

    <el-pagination
      v-if="pagination.total > pagination.per_page"
      background
      layout="prev, pager, next, total"
      :current-page="pagination.current_page"
      :page-size="pagination.per_page"
      :total="pagination.total"
      @current-change="changePage"
    />

    <el-drawer v-model="detailVisible" title="日志详情" size="520px">
      <div v-if="selectedLog" class="detail-stack">
        <section>
          <div class="section-title">基础信息</div>
          <el-descriptions :column="1" border>
            <el-descriptions-item label="动作">{{ actionLabel(selectedLog.action) }}</el-descriptions-item>
            <el-descriptions-item label="账号">{{ selectedLog.user?.username || '-' }}</el-descriptions-item>
            <el-descriptions-item label="角色">{{ selectedLog.user?.role || '-' }}</el-descriptions-item>
            <el-descriptions-item label="对象类型">{{ selectedLog.target_type || '-' }}</el-descriptions-item>
            <el-descriptions-item label="对象 ID">{{ selectedLog.target_id || '-' }}</el-descriptions-item>
            <el-descriptions-item label="IP">{{ selectedLog.ip_address || '-' }}</el-descriptions-item>
            <el-descriptions-item label="时间">{{ selectedLog.created_at }}</el-descriptions-item>
          </el-descriptions>
        </section>
        <section>
          <div class="section-title">载荷</div>
          <pre class="json-cell">{{ formatPayload(selectedLog.payload) }}</pre>
        </section>
        <section>
          <div class="section-title">User Agent</div>
          <pre class="json-cell">{{ selectedLog.user_agent || '-' }}</pre>
        </section>
      </div>
    </el-drawer>
  </section>
</template>

<script setup>
import { onMounted, reactive, ref, watch } from 'vue'
import { ElMessage } from 'element-plus'
import { Download, Refresh, Search, View } from '@element-plus/icons-vue'
import { useRoute } from 'vue-router'
import { api, downloadApi } from '../api.js'

const route = useRoute()
const loading = ref(false)
const keyword = ref('')
const action = ref('')
const ipAddress = ref('')
const targetType = ref('')
const targetId = ref('')
const dateRange = ref([])
const logs = ref([])
const detailVisible = ref(false)
const selectedLog = ref(null)
const pagination = reactive({ current_page: 1, per_page: 30, total: 0 })
const actionOptions = [
  { label: '登录成功', value: 'auth.login' },
  { label: '登录失败', value: 'auth.login_failed' },
  { label: '登录限流', value: 'auth.throttled' },
  { label: '验证码失败', value: 'auth.captcha_failed' },
  { label: '修改密码', value: 'auth.password_updated' },
  { label: '资料修改', value: 'auth.profile_updated' },
  { label: '账号创建', value: 'user.created' },
  { label: '账号修改', value: 'user.updated' },
  { label: '超管重置密码', value: 'user.password_reset' },
  { label: '账号会话撤销', value: 'user.tokens_revoked' },
  { label: '单位创建', value: 'unit.created' },
  { label: '单位修改', value: 'unit.updated' },
  { label: '单位会话撤销', value: 'unit.tokens_revoked' },
  { label: '项目创建', value: 'project.created' },
  { label: '项目修改', value: 'project.updated' },
  { label: '项目删除', value: 'project.deleted' },
  { label: '项目提交', value: 'project.submitted' },
  { label: '项目撤回', value: 'project.withdrawn' },
  { label: '进入验收', value: 'project.acceptance_started' },
  { label: '关闭验收', value: 'project.closed' },
  { label: '申请延期', value: 'project.extension_requested' },
  { label: '处理延期', value: 'project.extension_reviewed' },
  { label: '审核处理', value: 'project.reviewed' },
  { label: '附件上传', value: 'project_file.uploaded' },
  { label: '附件缺失', value: 'project_file.missing' },
  { label: '附件磁盘异常', value: 'project_file.invalid_disk' },
  { label: '附件路径异常', value: 'project_file.invalid_path' },
  { label: '附件下载', value: 'project_file.downloaded' },
  { label: '附件删除', value: 'project_file.deleted' },
  { label: '任务书创建', value: 'task_book.created' },
  { label: '任务书修改', value: 'task_book.updated' },
  { label: '任务书提交', value: 'task_book.submitted' },
  { label: '任务书审核', value: 'task_book.reviewed' },
  { label: '实施进展创建', value: 'project_progress.created' },
  { label: '实施进展修改', value: 'project_progress.updated' },
  { label: '实施进展提交', value: 'project_progress.submitted' },
  { label: '实施进展审核', value: 'project_progress.reviewed' },
  { label: '整改要求创建', value: 'rectification.created' },
  { label: '整改材料提交', value: 'rectification.submitted' },
  { label: '整改审核', value: 'rectification.reviewed' },
  { label: '专家认证提交', value: 'expert_certification.submitted' },
  { label: '专家认证审核', value: 'expert_certification.reviewed' },
  { label: '消息已读', value: 'message.read' },
  { label: '全部消息已读', value: 'message.read_all' },
  { label: '字典创建', value: 'dictionary_item.created' },
  { label: '字典修改', value: 'dictionary_item.updated' },
  { label: '文案创建', value: 'system_text.created' },
  { label: '文案修改', value: 'system_text.updated' },
  { label: '文案回滚', value: 'system_text.reset' },
  { label: '文案删除', value: 'system_text.deleted' },
  { label: '文案导出', value: 'system_text.exported' },
  { label: '配置修改', value: 'setting.updated' },
  { label: '项目导出', value: 'project.exported' },
  { label: '审核任务导出', value: 'review_tasks.exported' },
  { label: '审核结果导出', value: 'review_results.exported' },
  { label: '单位导出', value: 'unit.exported' },
  { label: '账号导出', value: 'user.exported' },
  { label: '导出日志', value: 'operation_log.exported' }
]
const actionLabelMap = Object.fromEntries(actionOptions.map((item) => [item.value, item.label]))

function actionLabel(value) {
  return actionLabelMap[value] || value || '-'
}

function routeValue(key) {
  const value = route.query[key]
  return Array.isArray(value) ? value[0] || '' : value || ''
}

function applyRouteQuery() {
  keyword.value = routeValue('keyword')
  action.value = routeValue('action')
  ipAddress.value = routeValue('ip_address')
  targetType.value = routeValue('target_type')
  targetId.value = routeValue('target_id')
  const dateFrom = routeValue('date_from')
  const dateTo = routeValue('date_to')
  dateRange.value = dateFrom || dateTo ? [dateFrom, dateTo] : []
}

function buildQuery() {
  const params = new URLSearchParams()
  if (keyword.value) params.set('keyword', keyword.value)
  if (action.value) params.set('action', action.value)
  if (ipAddress.value) params.set('ip_address', ipAddress.value)
  if (targetType.value) params.set('target_type', targetType.value)
  if (targetId.value) params.set('target_id', targetId.value)
  if (dateRange.value?.[0]) params.set('date_from', dateRange.value[0])
  if (dateRange.value?.[1]) params.set('date_to', dateRange.value[1])
  if (pagination.current_page > 1) params.set('page', pagination.current_page)
  return params.toString() ? `?${params.toString()}` : ''
}

async function loadLogs() {
  loading.value = true
  try {
    const result = await api(`/operation-logs${buildQuery()}`)
    logs.value = result.data || result
    pagination.current_page = result.current_page || 1
    pagination.per_page = result.per_page || 30
    pagination.total = result.total || logs.value.length
  } finally {
    loading.value = false
  }
}

function reloadLogs() {
  pagination.current_page = 1
  loadLogs()
}

function changePage(page) {
  pagination.current_page = page
  loadLogs()
}

function openDetail(row) {
  selectedLog.value = row
  detailVisible.value = true
}

function formatPayload(payload) {
  if (!payload) return '-'
  return JSON.stringify(payload, null, 2)
}

async function exportLogs() {
  const params = new URLSearchParams()
  if (keyword.value) params.set('keyword', keyword.value)
  if (action.value) params.set('action', action.value)
  if (ipAddress.value) params.set('ip_address', ipAddress.value)
  if (targetType.value) params.set('target_type', targetType.value)
  if (targetId.value) params.set('target_id', targetId.value)
  if (dateRange.value?.[0]) params.set('date_from', dateRange.value[0])
  if (dateRange.value?.[1]) params.set('date_to', dateRange.value[1])
  const query = params.toString() ? `?${params.toString()}` : ''
  try {
    await downloadApi(`/operation-logs/export.csv${query}`, `operation-logs-${new Date().toISOString().slice(0, 10)}.csv`)
  } catch (err) {
    ElMessage.error(err.message || '操作日志导出失败')
  }
}

onMounted(() => {
  applyRouteQuery()
  loadLogs()
})

watch(() => route.query, () => {
  applyRouteQuery()
  reloadLogs()
})
</script>

<style scoped>
.target-id-filter {
  width: 120px;
}
</style>
