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
          <template #default="{ row }">{{ securityEventAction(row.action) }}</template>
        </el-table-column>
        <el-table-column label="账号" min-width="150">
          <template #default="{ row }">{{ row.user?.username || row.payload?.username || '-' }}</template>
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

const router = useRouter()
const loading = ref(false)
const summary = ref(null)
const metrics = computed(() => [
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
])

const baseline = [
  { area: '框架', current: 'ThinkPHP 3.1.2，旧 API 和大控制器', target: 'Laravel 11 API，按领域拆分控制器和模型' },
  { area: '文件', current: '公开目录存在上传脚本和历史后门风险', target: '统一文件服务、鉴权下载、扩展名和大小限制' },
  { area: '配置', current: '数据库和接口凭据写在 PHP 配置', target: '.env + 配置表，敏感值脱敏展示' },
  { area: '前端', current: '静态模板和旧组件库混杂', target: 'Vue 3 工作台，角色化导航和任务列表' }
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
  'auth.captcha_failed': '验证码失败',
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

function openRelatedLogs(row) {
  const params = new URLSearchParams()
  if (row.action) params.set('action', row.action)
  if (row.target_type) params.set('target_type', row.target_type)
  if (row.target_id) params.set('target_id', row.target_id)
  if (!row.target_id && row.ip_address) params.set('ip_address', row.ip_address)
  const keyword = row.user?.username || row.payload?.username
  if (!row.target_id && keyword) params.set('keyword', keyword)
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
</style>
