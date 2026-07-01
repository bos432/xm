<template>
  <section class="page-stack">
    <div class="toolbar">
      <div>
        <h2>安全中心</h2>
        <span class="muted">查看安全事件、账号/IP 锁定和登录风控策略</span>
      </div>
      <el-button :icon="Refresh" :loading="loading" @click="loadAll">刷新</el-button>
    </div>

    <el-card shadow="never">
      <template #header>安全策略</template>
      <el-alert
        style="margin-bottom: 16px"
        :title="throttleStatusText"
        type="info"
        show-icon
        :closable="false"
      />
      <el-form :model="policies" label-position="top" class="home-manager-grid">
        <el-form-item label="登录失败阈值"><el-input-number v-model="policies.login_failure_threshold" :min="1" :max="100" /></el-form-item>
        <el-form-item label="锁定分钟数"><el-input-number v-model="policies.lock_minutes" :min="1" :max="1440" /></el-form-item>
        <el-form-item label="登录限流/分钟"><el-input-number v-model="policies.login_throttle_per_minute" :min="1" :max="300" /></el-form-item>
        <el-form-item label="临时放宽登录限流"><el-switch v-model="policies.login_throttle_relaxed" /></el-form-item>
        <el-form-item label="放宽后限流/分钟"><el-input-number v-model="policies.login_throttle_relaxed_per_minute" :min="1" :max="1000" /></el-form-item>
        <el-form-item label="启用 IP 白名单"><el-switch v-model="policies.ip_whitelist_enabled" /></el-form-item>
        <el-form-item label="启用 IP 黑名单"><el-switch v-model="policies.ip_blacklist_enabled" /></el-form-item>
        <el-form-item label="测试白名单 IP" class="wide-field">
          <el-input v-model="policies.login_throttle_whitelist_ips" type="textarea" :rows="3" placeholder="多个 IP 用英文逗号分隔，仅用于登录限流验收放宽" />
        </el-form-item>
      </el-form>
      <el-button type="primary" :loading="savingPolicy" @click="savePolicies">保存策略</el-button>
    </el-card>

    <el-tabs v-model="activeTab">
      <el-tab-pane label="安全事件" name="events">
        <div class="toolbar">
          <el-input v-model="eventKeyword" clearable placeholder="账号/IP/事件" @keyup.enter="loadEvents" />
          <el-button @click="loadEvents">查询</el-button>
        </div>
        <el-table :data="events" border v-loading="loading">
          <el-table-column prop="type" label="事件" min-width="190" />
          <el-table-column label="级别" width="100">
            <template #default="{ row }"><el-tag :type="severityType(row.severity)">{{ row.severity }}</el-tag></template>
          </el-table-column>
          <el-table-column prop="username" label="账号" width="150" />
          <el-table-column prop="ip_address" label="IP" width="150" />
          <el-table-column prop="created_at" label="时间" width="180" />
          <el-table-column label="详情" min-width="240">
            <template #default="{ row }">{{ JSON.stringify(row.payload || {}) }}</template>
          </el-table-column>
        </el-table>
      </el-tab-pane>
      <el-tab-pane label="锁定与名单" name="locks">
        <div class="toolbar">
          <el-button type="primary" :icon="Plus" @click="openLock">手动锁定</el-button>
          <el-button :icon="Plus" @click="openRule">添加 IP 规则</el-button>
        </div>
        <el-table :data="locks" border>
          <el-table-column prop="identity_type" label="类型" width="110" />
          <el-table-column prop="identity_value" label="对象" min-width="180" />
          <el-table-column prop="failed_count" label="失败次数" width="100" />
          <el-table-column label="状态" width="100">
            <template #default="{ row }"><el-tag :type="row.is_active ? 'danger' : 'info'">{{ row.is_active ? '锁定' : '已释放' }}</el-tag></template>
          </el-table-column>
          <el-table-column prop="locked_until" label="锁定至" width="170" />
          <el-table-column label="操作" width="100">
            <template #default="{ row }"><el-button size="small" :disabled="!row.is_active" @click="release(row)">解锁</el-button></template>
          </el-table-column>
        </el-table>

        <el-table :data="ipRules" border class="mt-16">
          <el-table-column prop="type" label="名单类型" width="120" />
          <el-table-column prop="cidr" label="IP/CIDR" min-width="180" />
          <el-table-column prop="description" label="说明" min-width="240" />
          <el-table-column label="操作" width="100">
            <template #default="{ row }"><el-button size="small" type="danger" @click="deleteRule(row)">删除</el-button></template>
          </el-table-column>
        </el-table>
      </el-tab-pane>
    </el-tabs>

    <el-dialog v-model="blockVisible" :title="blockForm.kind === 'lock' ? '手动锁定' : '添加 IP 规则'" width="520px">
      <el-form :model="blockForm" label-position="top">
        <template v-if="blockForm.kind === 'lock'">
          <el-form-item label="锁定类型">
            <el-select v-model="blockForm.identity_type">
              <el-option label="账号" value="username" />
              <el-option label="IP" value="ip" />
            </el-select>
          </el-form-item>
          <el-form-item label="锁定对象"><el-input v-model="blockForm.identity_value" /></el-form-item>
        </template>
        <template v-else>
          <el-form-item label="名单类型">
            <el-select v-model="blockForm.rule_type">
              <el-option label="黑名单" value="blacklist" />
              <el-option label="白名单" value="whitelist" />
            </el-select>
          </el-form-item>
          <el-form-item label="IP/CIDR"><el-input v-model="blockForm.cidr" placeholder="例如 192.168.1.10 或 192.168.1.0/24" /></el-form-item>
        </template>
        <el-form-item label="说明"><el-input v-model="blockForm.description" type="textarea" :rows="3" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="blockVisible = false">取消</el-button>
        <el-button type="primary" @click="saveBlock">保存</el-button>
      </template>
    </el-dialog>
  </section>
</template>

<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { ElMessage } from 'element-plus'
import { Plus, Refresh } from '@element-plus/icons-vue'
import { useRoute } from 'vue-router'
import { api } from '../api.js'

const route = useRoute()
const activeTab = ref('events')
const loading = ref(false)
const savingPolicy = ref(false)
const eventKeyword = ref('')
const events = ref([])
const locks = ref([])
const ipRules = ref([])
const blockVisible = ref(false)
const policies = reactive({
  login_failure_threshold: 5,
  lock_minutes: 30,
  login_throttle_per_minute: 5,
  login_throttle_relaxed: false,
  login_throttle_relaxed_per_minute: 60,
  login_throttle_whitelist_ips: '',
  ip_whitelist_enabled: false,
  ip_blacklist_enabled: true
})
const blockForm = reactive({ kind: 'lock', identity_type: 'username', identity_value: '', rule_type: 'blacklist', cidr: '', description: '' })
const throttleStatusText = computed(() => {
  const parts = [
    `普通限流 ${policies.login_throttle_per_minute} 次/分钟`,
    policies.login_throttle_relaxed
      ? `临时放宽中：${policies.login_throttle_relaxed_per_minute} 次/分钟`
      : '未开启临时放宽',
  ]
  const whitelist = String(policies.login_throttle_whitelist_ips || '').trim()
  if (whitelist) parts.push(`测试白名单：${whitelist}`)
  return parts.join('；')
})

function severityType(value) {
  return value === 'high' ? 'danger' : value === 'medium' ? 'warning' : 'info'
}

async function loadEvents() {
  const params = new URLSearchParams()
  if (eventKeyword.value) params.set('keyword', eventKeyword.value)
  const result = await api(`/security/events${params.toString() ? `?${params.toString()}` : ''}`)
  events.value = result.data || result
}

async function loadLocks() {
  const result = await api('/security/blocked-identities')
  locks.value = result.locks?.data || result.locks || []
  ipRules.value = result.ip_rules || []
}

async function loadPolicies() {
  Object.assign(policies, await api('/security/policies'))
}

async function loadAll() {
  loading.value = true
  try {
    await Promise.all([loadEvents(), loadLocks(), loadPolicies()])
  } finally {
    loading.value = false
  }
}

async function savePolicies() {
  savingPolicy.value = true
  try {
    await api('/security/policies', { method: 'PUT', body: JSON.stringify(policies) })
    ElMessage.success('安全策略已保存')
  } finally {
    savingPolicy.value = false
  }
}

function openLock() {
  Object.assign(blockForm, { kind: 'lock', identity_type: 'username', identity_value: '', description: '' })
  blockVisible.value = true
}

function openRule() {
  Object.assign(blockForm, { kind: 'ip_rule', rule_type: 'blacklist', cidr: '', description: '' })
  blockVisible.value = true
}

async function saveBlock() {
  await api('/security/blocked-identities', { method: 'POST', body: JSON.stringify(blockForm) })
  ElMessage.success('安全限制已保存')
  blockVisible.value = false
  await loadLocks()
}

async function release(row) {
  await api(`/security/locks/${row.id}/release`, { method: 'POST' })
  ElMessage.success('已解锁')
  await loadLocks()
}

async function deleteRule(row) {
  await api(`/security/blocked-identities/rule:${row.id}`, { method: 'DELETE' })
  ElMessage.success('IP 规则已删除')
  await loadLocks()
}

onMounted(() => {
  eventKeyword.value = route.query.keyword || ''
  loadAll()
})

watch(() => route.query.keyword, () => {
  eventKeyword.value = route.query.keyword || ''
  loadEvents()
})
</script>
