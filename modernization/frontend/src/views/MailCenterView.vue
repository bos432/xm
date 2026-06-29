<template>
  <section class="page-stack">
    <div class="toolbar">
      <div>
        <h2>邮件中心</h2>
        <span class="muted">维护邮件模板、查看发送日志并重试失败邮件</span>
      </div>
      <el-button :icon="Refresh" :loading="loading" @click="loadAll">刷新</el-button>
    </div>

    <el-tabs v-model="activeTab">
      <el-tab-pane label="邮件模板" name="templates">
        <el-card shadow="never">
          <template #header><el-button type="primary" :icon="Plus" @click="openTemplate()">新增模板</el-button></template>
          <el-table :data="templates" border v-loading="loading">
            <el-table-column prop="key" label="模板键" width="180" />
            <el-table-column prop="name" label="名称" width="160" />
            <el-table-column prop="subject" label="主题" min-width="260" />
            <el-table-column label="状态" width="110">
              <template #default="{ row }"><el-tag :type="row.is_active ? 'success' : 'info'">{{ row.is_active ? '启用' : '停用' }}</el-tag></template>
            </el-table-column>
            <el-table-column label="操作" width="100">
              <template #default="{ row }"><el-button size="small" :icon="Edit" @click="openTemplate(row)">编辑</el-button></template>
            </el-table-column>
          </el-table>
        </el-card>
      </el-tab-pane>
      <el-tab-pane label="发送日志" name="logs">
        <div class="toolbar">
          <el-input v-model="logKeyword" clearable placeholder="收件人/主题/模板" @keyup.enter="loadLogs" />
          <el-select v-model="logStatus" clearable placeholder="状态" @change="loadLogs">
            <el-option label="排队" value="queued" />
            <el-option label="已发送" value="sent" />
            <el-option label="失败" value="failed" />
          </el-select>
          <el-button :icon="Refresh" @click="loadLogs">查询</el-button>
        </div>
        <el-table :data="logs" border v-loading="loading">
          <el-table-column prop="template_key" label="模板" width="170" />
          <el-table-column prop="to_address" label="收件人" min-width="220" />
          <el-table-column prop="subject" label="主题" min-width="260" />
          <el-table-column label="状态" width="100">
            <template #default="{ row }"><el-tag :type="mailStatus(row.status).type">{{ mailStatus(row.status).label }}</el-tag></template>
          </el-table-column>
          <el-table-column prop="retry_count" label="重试" width="80" />
          <el-table-column prop="sent_at" label="发送时间" width="170" />
          <el-table-column prop="error" label="错误" min-width="220" show-overflow-tooltip />
          <el-table-column label="操作" width="100">
            <template #default="{ row }"><el-button size="small" :disabled="row.status !== 'failed'" @click="retry(row)">重试</el-button></template>
          </el-table-column>
        </el-table>
      </el-tab-pane>
    </el-tabs>

    <el-dialog v-model="templateVisible" :title="templateForm.id ? '编辑邮件模板' : '新增邮件模板'" width="720px">
      <el-form :model="templateForm" label-position="top">
        <el-form-item label="模板键"><el-input v-model="templateForm.key" :disabled="templateForm.is_builtin" /></el-form-item>
        <el-form-item label="名称"><el-input v-model="templateForm.name" /></el-form-item>
        <el-form-item label="主题"><el-input v-model="templateForm.subject" /></el-form-item>
        <el-form-item label="正文"><el-input v-model="templateForm.body" type="textarea" :rows="10" /></el-form-item>
        <el-form-item label="启用"><el-switch v-model="templateForm.is_active" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="templateVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="saveTemplate">保存</el-button>
      </template>
    </el-dialog>
  </section>
</template>

<script setup>
import { onMounted, reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { Edit, Plus, Refresh } from '@element-plus/icons-vue'
import { api } from '../api.js'

const activeTab = ref('templates')
const loading = ref(false)
const saving = ref(false)
const templates = ref([])
const logs = ref([])
const logKeyword = ref('')
const logStatus = ref('')
const templateVisible = ref(false)
const templateForm = reactive(emptyTemplate())
const statuses = {
  queued: { label: '排队', type: 'warning' },
  sent: { label: '已发送', type: 'success' },
  failed: { label: '失败', type: 'danger' }
}

function emptyTemplate() {
  return { id: null, key: '', name: '', subject: '', body: '', is_active: true, is_builtin: false, metadata: {} }
}

function mailStatus(value) {
  return statuses[value] || { label: value || '-', type: 'info' }
}

async function loadTemplates() {
  templates.value = await api('/mail/templates')
}

async function loadLogs() {
  const params = new URLSearchParams()
  if (logKeyword.value) params.set('keyword', logKeyword.value)
  if (logStatus.value) params.set('status', logStatus.value)
  const result = await api(`/mail/logs${params.toString() ? `?${params.toString()}` : ''}`)
  logs.value = result.data || result
}

async function loadAll() {
  loading.value = true
  try {
    await Promise.all([loadTemplates(), loadLogs()])
  } finally {
    loading.value = false
  }
}

function openTemplate(row = null) {
  Object.assign(templateForm, emptyTemplate(), row || {})
  templateVisible.value = true
}

async function saveTemplate() {
  saving.value = true
  try {
    await api(templateForm.id ? `/mail/templates/${templateForm.id}` : '/mail/templates', {
      method: templateForm.id ? 'PUT' : 'POST',
      body: JSON.stringify({
        key: templateForm.key,
        name: templateForm.name,
        subject: templateForm.subject,
        body: templateForm.body,
        is_active: templateForm.is_active,
        metadata: templateForm.metadata || {}
      })
    })
    ElMessage.success('模板已保存')
    templateVisible.value = false
    await loadTemplates()
  } finally {
    saving.value = false
  }
}

async function retry(row) {
  await api(`/mail/logs/${row.id}/retry`, { method: 'POST' })
  ElMessage.success('已重新加入发送队列')
  await loadLogs()
}

onMounted(loadAll)
</script>
