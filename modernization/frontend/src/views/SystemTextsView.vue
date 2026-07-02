<template>
  <section class="page-stack">
    <div class="toolbar">
      <div>
        <h2>系统文案</h2>
        <span class="muted">维护后台菜单、按钮、流程说明和业务提示文案；内置文案可隐藏或回滚默认值。</span>
      </div>
      <div class="toolbar-actions">
        <el-input v-model="keyword" clearable placeholder="键名/名称/内容" @keyup.enter="searchTexts" />
        <el-select v-model="group" clearable placeholder="分组" @change="searchTexts">
          <el-option v-for="item in groups" :key="item" :label="item" :value="item" />
        </el-select>
        <el-button :icon="Refresh" :loading="loading" @click="loadTexts">刷新</el-button>
        <el-button :icon="Download" @click="exportTexts">导出文案</el-button>
        <el-button type="primary" :icon="Plus" @click="openText()">新增文案</el-button>
      </div>
    </div>

    <el-alert
      title="核心文案建议只修改覆盖值。隐藏会让前端收到空字符串；内置文案不能删除，可随时回滚默认值。"
      type="info"
      show-icon
      :closable="false"
    />

    <el-table :data="items" border v-loading="loading">
      <el-table-column prop="group" label="分组" width="120" />
      <el-table-column prop="key" label="键名" min-width="220" show-overflow-tooltip />
      <el-table-column prop="label" label="名称" min-width="160" />
      <el-table-column label="当前覆盖值" min-width="240" show-overflow-tooltip>
        <template #default="{ row }">{{ row.value ?? '使用默认值' }}</template>
      </el-table-column>
      <el-table-column prop="default_value" label="默认值" min-width="240" show-overflow-tooltip />
      <el-table-column label="状态" width="110">
        <template #default="{ row }">
          <el-tag :type="row.is_active ? 'success' : 'info'">{{ row.is_active ? '启用' : '隐藏' }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="类型" width="90">
        <template #default="{ row }">
          <el-tag :type="row.is_builtin ? 'warning' : 'primary'">{{ row.is_builtin ? '内置' : '自定义' }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="操作" width="240" fixed="right">
        <template #default="{ row }">
          <div class="table-action-row">
            <el-button size="small" :icon="Edit" @click="openText(row)">编辑</el-button>
            <el-button size="small" :icon="RefreshLeft" @click="resetText(row)">回滚</el-button>
            <el-button v-if="!row.is_builtin" size="small" type="danger" :icon="Delete" @click="deleteText(row)">删除</el-button>
          </div>
        </template>
      </el-table-column>
    </el-table>

    <el-pagination
      v-model:current-page="pagination.current_page"
      v-model:page-size="pagination.per_page"
      layout="total, prev, pager, next"
      :total="pagination.total"
      @current-change="loadTexts"
    />

    <el-dialog v-model="dialogVisible" :title="form.id ? '编辑文案' : '新增文案'" width="680px">
      <el-form :model="form" label-position="top">
        <el-form-item label="键名">
          <el-input v-model="form.key" :disabled="form.is_builtin" placeholder="例如 workflow.custom.tip" />
        </el-form-item>
        <el-form-item label="分组"><el-input v-model="form.group" /></el-form-item>
        <el-form-item label="名称"><el-input v-model="form.label" /></el-form-item>
        <el-form-item label="默认值">
          <el-input v-model="form.default_value" type="textarea" :rows="3" :disabled="form.is_builtin" />
        </el-form-item>
        <el-form-item label="当前覆盖值">
          <el-input v-model="form.value" type="textarea" :rows="4" placeholder="留空表示使用默认值；如需隐藏请关闭启用开关" />
        </el-form-item>
        <el-form-item label="说明"><el-input v-model="form.description" type="textarea" :rows="2" /></el-form-item>
        <el-form-item label="排序"><el-input-number v-model="form.sort_order" :min="0" /></el-form-item>
        <el-form-item label="启用"><el-switch v-model="form.is_active" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="saveText">保存</el-button>
      </template>
    </el-dialog>
  </section>
</template>

<script setup>
import { onMounted, reactive, ref, watch } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Delete, Download, Edit, Plus, Refresh, RefreshLeft } from '@element-plus/icons-vue'
import { useRoute, useRouter } from 'vue-router'
import { api, downloadApi } from '../api.js'
import { useTextStore } from '../texts.js'

const route = useRoute()
const router = useRouter()
const textStore = useTextStore()
const loading = ref(false)
const saving = ref(false)
const dialogVisible = ref(false)
const keyword = ref('')
const group = ref('')
const groups = ref([])
const items = ref([])
const pagination = reactive({ current_page: 1, per_page: 100, total: 0 })
const form = reactive(emptyForm())

function emptyForm() {
  return {
    id: null,
    key: '',
    group: '自定义',
    label: '',
    default_value: '',
    value: '',
    description: '',
    is_active: true,
    is_builtin: false,
    sort_order: 1000
  }
}

async function loadTexts() {
  loading.value = true
  try {
    const params = new URLSearchParams()
    params.set('page', pagination.current_page)
    if (keyword.value) params.set('keyword', keyword.value)
    if (group.value) params.set('group', group.value)

    const result = await api(`/system-texts?${params.toString()}`)
    const page = result.data || {}
    items.value = page.data || []
    pagination.current_page = page.current_page || 1
    pagination.per_page = page.per_page || 100
    pagination.total = page.total || 0
    groups.value = result.groups || []
  } finally {
    loading.value = false
  }
}

function applyRouteFilters() {
  keyword.value = typeof route.query.keyword === 'string' ? route.query.keyword : ''
  group.value = typeof route.query.group === 'string' ? route.query.group : ''
  pagination.current_page = route.query.page ? Number(route.query.page) || 1 : 1
}

function searchTexts() {
  pagination.current_page = 1
  const query = { ...route.query }
  if (keyword.value) query.keyword = keyword.value
  else delete query.keyword
  if (group.value) query.group = group.value
  else delete query.group
  delete query.page
  router.replace({ path: route.path, query })
  loadTexts()
}

function openText(row = null) {
  Object.assign(form, emptyForm(), row || {})
  dialogVisible.value = true
}

async function saveText() {
  saving.value = true
  try {
    const payload = {
      key: form.key,
      group: form.group,
      label: form.label,
      default_value: form.default_value,
      value: form.value === '' ? null : form.value,
      description: form.description,
      is_active: form.is_active,
      sort_order: form.sort_order
    }
    await api(form.id ? `/system-texts/${form.id}` : '/system-texts', {
      method: form.id ? 'PUT' : 'POST',
      body: JSON.stringify(payload)
    })
    ElMessage.success('文案已保存')
    dialogVisible.value = false
    await loadTexts()
    await textStore.loadTexts(true)
  } finally {
    saving.value = false
  }
}

async function resetText(row) {
  await api(`/system-texts/${row.id}/reset`, { method: 'POST' })
  ElMessage.success('已回滚默认值')
  await loadTexts()
  await textStore.loadTexts(true)
}

async function deleteText(row) {
  await ElMessageBox.confirm(`确定删除自定义文案“${row.label}”？`, '删除确认', { type: 'warning' })
  await api(`/system-texts/${row.id}`, { method: 'DELETE' })
  ElMessage.success('文案已删除')
  await loadTexts()
  await textStore.loadTexts(true)
}

async function exportTexts() {
  const params = new URLSearchParams()
  if (keyword.value) params.set('keyword', keyword.value)
  if (group.value) params.set('group', group.value)
  const query = params.toString() ? `?${params.toString()}` : ''
  await downloadApi(`/system-texts/export.csv${query}`, `system-texts-${new Date().toISOString().slice(0, 10)}.csv`)
}

onMounted(() => {
  applyRouteFilters()
  loadTexts()
})

watch(() => route.query, () => {
  applyRouteFilters()
  loadTexts()
})
</script>
