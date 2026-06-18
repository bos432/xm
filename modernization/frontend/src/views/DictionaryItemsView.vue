<template>
  <section class="page-stack">
    <div class="toolbar">
      <el-input v-model="keyword" clearable placeholder="按编码或名称搜索" @keyup.enter="loadItems" />
      <div class="toolbar-actions">
        <el-input v-model="group" clearable placeholder="分组，例如 project_type" @keyup.enter="loadItems" />
        <el-button :icon="Search" @click="loadItems">查询</el-button>
        <el-button type="primary" :icon="Plus" @click="openCreate">新增字典</el-button>
      </div>
    </div>

    <el-table :data="items" border v-loading="loading">
      <el-table-column prop="group" label="分组" width="150" />
      <el-table-column prop="code" label="编码" width="160" />
      <el-table-column prop="label" label="名称" min-width="200" />
      <el-table-column prop="sort_order" label="排序" width="90" />
      <el-table-column label="状态" width="100">
        <template #default="{ row }"><el-tag :type="row.is_active ? 'success' : 'info'">{{ row.is_active ? '启用' : '停用' }}</el-tag></template>
      </el-table-column>
      <el-table-column label="操作" width="128" align="center">
        <template #default="{ row }">
          <el-tooltip content="编辑字典" placement="top">
            <el-button :icon="Edit" circle size="small" @click="openEdit(row)" />
          </el-tooltip>
          <el-tooltip v-if="session.can('view_operation_logs')" content="查看字典日志" placement="top">
            <el-button :icon="Files" circle size="small" @click="openItemLogs(row)" />
          </el-tooltip>
        </template>
      </el-table-column>
    </el-table>

    <el-dialog v-model="dialogVisible" :title="editingItem ? '编辑字典' : '新增字典'" width="520px">
      <el-form :model="form" label-position="top">
        <el-form-item label="分组"><el-input v-model="form.group" /></el-form-item>
        <el-form-item label="编码"><el-input v-model="form.code" /></el-form-item>
        <el-form-item label="名称"><el-input v-model="form.label" /></el-form-item>
        <el-form-item label="排序"><el-input-number v-model="form.sort_order" :min="0" /></el-form-item>
        <el-form-item label="状态"><el-switch v-model="form.is_active" active-text="启用" inactive-text="停用" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="saveItem">保存</el-button>
      </template>
    </el-dialog>
  </section>
</template>

<script setup>
import { onMounted, reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { Edit, Files, Plus, Search } from '@element-plus/icons-vue'
import { useRouter } from 'vue-router'
import { api } from '../api.js'
import { useSessionStore } from '../store.js'

const router = useRouter()
const session = useSessionStore()
const loading = ref(false)
const saving = ref(false)
const keyword = ref('')
const group = ref('')
const items = ref([])
const dialogVisible = ref(false)
const editingItem = ref(null)
const form = reactive(emptyForm())

function emptyForm() {
  return { group: '', code: '', label: '', sort_order: 0, is_active: true }
}

async function loadItems() {
  loading.value = true
  try {
    const params = new URLSearchParams()
    if (keyword.value) params.set('keyword', keyword.value)
    if (group.value) params.set('group', group.value)
    const query = params.toString() ? `?${params.toString()}` : ''
    const result = await api(`/dictionary-items${query}`)
    items.value = result.data || result
  } finally {
    loading.value = false
  }
}

function openCreate() {
  editingItem.value = null
  Object.assign(form, emptyForm())
  dialogVisible.value = true
}

function openEdit(row) {
  editingItem.value = row
  Object.assign(form, {
    group: row.group || '',
    code: row.code || '',
    label: row.label || '',
    sort_order: Number(row.sort_order || 0),
    is_active: Boolean(row.is_active)
  })
  dialogVisible.value = true
}

function openItemLogs(row) {
  router.push(`/operation-logs?target_type=${encodeURIComponent('App\\Models\\DictionaryItem')}&target_id=${row.id}`)
}

async function saveItem() {
  saving.value = true
  try {
    const path = editingItem.value ? `/dictionary-items/${editingItem.value.id}` : '/dictionary-items'
    const method = editingItem.value ? 'PUT' : 'POST'
    await api(path, { method, body: JSON.stringify(form) })
    ElMessage.success('字典已保存')
    dialogVisible.value = false
    window.dispatchEvent(new Event('dictionaries:changed'))
    await loadItems()
  } finally {
    saving.value = false
  }
}

onMounted(loadItems)
</script>
