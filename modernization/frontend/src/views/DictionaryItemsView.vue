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
      <el-table-column type="index" label="序号" width="72" align="center" :index="tableIndex" fixed="left" />
      <el-table-column label="分组" width="180">
        <template #default="{ row }">
          <div class="dictionary-group-cell">
            <strong>{{ groupLabel(row.group) }}</strong>
            <span>{{ row.group }}</span>
          </div>
        </template>
      </el-table-column>
      <el-table-column label="字典项" min-width="260">
        <template #default="{ row }">
          <div class="dictionary-item-cell">
            <strong>{{ row.label }}</strong>
            <span>编码：{{ row.code }}</span>
          </div>
        </template>
      </el-table-column>
      <el-table-column label="评分配置" min-width="220">
        <template #default="{ row }">
          <template v-if="row.group === reviewCriterionGroup">
            <div class="dictionary-item-cell">
              <strong>{{ row.metadata?.section || '未设置大类' }}</strong>
              <span>满分：{{ formatMaxScore(row) }}</span>
            </div>
          </template>
          <span v-else class="muted">-</span>
        </template>
      </el-table-column>
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
        <template v-if="form.group === reviewCriterionGroup">
          <el-alert type="info" :closable="false" show-icon title="专家评分项会显示在专家审核弹窗中，满分用于校验并自动汇总总分。" />
          <el-form-item label="评分大类"><el-input v-model="form.metadata.section" placeholder="例如：政策符合性评价" /></el-form-item>
          <el-form-item label="满分"><el-input-number v-model="form.metadata.max_score" :min="0" :max="100" :precision="1" /></el-form-item>
          <el-form-item label="说明"><el-input v-model="form.metadata.description" type="textarea" :rows="3" placeholder="可选，给专家看的评分说明" /></el-form-item>
        </template>
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
const reviewCriterionGroup = 'expert_review_criterion'
const groupLabels = {
  project_category: '项目类别',
  project_type: '项目类型',
  project_status: '项目状态',
  expert_review_criterion: '专家评分项'
}

function emptyForm() {
  return { group: '', code: '', label: '', sort_order: 0, is_active: true, metadata: emptyMetadata() }
}

function emptyMetadata() {
  return { section: '', max_score: 5, description: '' }
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
    is_active: Boolean(row.is_active),
    metadata: { ...emptyMetadata(), ...(row.metadata || {}) }
  })
  dialogVisible.value = true
}

function openItemLogs(row) {
  router.push(`/operation-logs?target_type=${encodeURIComponent('App\\Models\\DictionaryItem')}&target_id=${row.id}`)
}

function tableIndex(index) {
  const currentPage = Number(items.value?.current_page || 1)
  const perPage = Number(items.value?.per_page || 50)
  return (currentPage - 1) * perPage + index + 1
}

function groupLabel(value) {
  return groupLabels[value] || value || '-'
}

async function saveItem() {
  saving.value = true
  try {
    const path = editingItem.value ? `/dictionary-items/${editingItem.value.id}` : '/dictionary-items'
    const method = editingItem.value ? 'PUT' : 'POST'
    await api(path, { method, body: JSON.stringify(buildPayload()) })
    ElMessage.success('字典已保存')
    dialogVisible.value = false
    window.dispatchEvent(new Event('dictionaries:changed'))
    await loadItems()
  } finally {
    saving.value = false
  }
}

function buildPayload() {
  return {
    group: form.group,
    code: form.code,
    label: form.label,
    sort_order: form.sort_order,
    is_active: form.is_active,
    metadata: {
      ...(form.metadata || {}),
      max_score: Number(form.metadata?.max_score || 0)
    }
  }
}

function formatMaxScore(row) {
  const score = Number(row.metadata?.max_score || 0)
  return Number.isFinite(score) && score > 0 ? score : '-'
}

onMounted(loadItems)
</script>

<style scoped>
.dictionary-group-cell,
.dictionary-item-cell {
  display: grid;
  gap: 4px;
  line-height: 1.35;
}

.dictionary-group-cell strong,
.dictionary-item-cell strong {
  color: #0f172a;
  font-weight: 600;
}

.dictionary-group-cell span,
.dictionary-item-cell span {
  color: #64748b;
  font-size: 12px;
}
</style>
