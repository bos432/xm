<template>
  <section class="page-stack">
    <div class="toolbar">
      <div>
        <h2>申报批次</h2>
        <span class="muted">维护项目申报开放时间、类别范围、指南和附件要求</span>
      </div>
      <div class="toolbar-actions">
        <el-input v-model="keyword" clearable placeholder="批次名称/编号" @keyup.enter="loadBatches" />
        <el-select v-model="status" clearable placeholder="状态" @change="loadBatches">
          <el-option label="草稿" value="draft" />
          <el-option label="开放" value="open" />
          <el-option label="关闭" value="closed" />
          <el-option label="归档" value="archived" />
        </el-select>
        <el-select v-model="e2eFilter" clearable placeholder="测试数据" @change="loadBatches">
          <el-option label="只看测试数据" value="1" />
          <el-option label="排除测试数据" value="0" />
        </el-select>
        <el-button :icon="Refresh" :loading="loading" @click="loadBatches">刷新</el-button>
        <el-button v-if="session.role === 'super_admin'" type="warning" @click="archiveE2eBatches">归档测试批次</el-button>
        <el-button type="primary" :icon="Plus" @click="openEditor()">新增批次</el-button>
      </div>
    </div>

    <el-table :data="batches" border v-loading="loading">
      <el-table-column prop="name" label="批次名称" min-width="220" />
      <el-table-column prop="code" label="编号" width="150" />
      <el-table-column label="状态" width="100">
        <template #default="{ row }"><el-tag :type="statusMeta(row.status).type">{{ statusMeta(row.status).label }}</el-tag></template>
      </el-table-column>
      <el-table-column prop="starts_at" label="开始时间" width="170" />
      <el-table-column prop="ends_at" label="结束时间" width="170" />
      <el-table-column prop="guide" label="指南说明" min-width="220" show-overflow-tooltip />
      <el-table-column label="操作" width="270" fixed="right">
        <template #default="{ row }">
          <div class="table-action-row">
            <el-button size="small" :icon="Edit" @click="openEditor(row)">编辑</el-button>
            <el-button size="small" type="success" @click="changeStatus(row, 'open')">开放</el-button>
            <el-button size="small" @click="changeStatus(row, 'close')">关闭</el-button>
            <el-button size="small" type="warning" @click="changeStatus(row, 'archive')">归档</el-button>
          </div>
        </template>
      </el-table-column>
    </el-table>

    <el-dialog v-model="editorVisible" :title="form.id ? '编辑批次' : '新增批次'" width="720px">
      <el-form :model="form" label-position="top" class="home-manager-grid">
        <el-form-item label="批次名称"><el-input v-model="form.name" /></el-form-item>
        <el-form-item label="批次编号"><el-input v-model="form.code" /></el-form-item>
        <el-form-item label="状态">
          <el-select v-model="form.status">
            <el-option label="草稿" value="draft" />
            <el-option label="开放" value="open" />
            <el-option label="关闭" value="closed" />
            <el-option label="归档" value="archived" />
          </el-select>
        </el-form-item>
        <el-form-item label="申报时间">
          <el-date-picker v-model="dateRange" type="datetimerange" value-format="YYYY-MM-DD HH:mm:ss" start-placeholder="开始" end-placeholder="结束" />
        </el-form-item>
        <el-form-item label="允许项目类别">
          <el-select v-model="form.allowed_categories" multiple filterable allow-create default-first-option placeholder="从项目类别字典选择；留空表示不限">
            <el-option v-for="item in projectCategoryOptions" :key="item.code" :label="dictionaryOptionLabel(item)" :value="dictionaryOptionValue(item)" />
          </el-select>
          <span class="field-help">建议从字典选择；系统保存稳定编码，申报端显示中文名称。</span>
        </el-form-item>
        <el-form-item label="允许项目类型">
          <el-select v-model="form.allowed_project_types" multiple filterable allow-create default-first-option placeholder="从项目类型字典选择；留空表示不限">
            <el-option v-for="item in projectTypeOptions" :key="item.code" :label="dictionaryOptionLabel(item)" :value="dictionaryOptionValue(item)" />
          </el-select>
          <span class="field-help">留空表示该批次不限制项目类型。</span>
        </el-form-item>
        <el-form-item label="指南说明" class="wide-field"><RichTextEditor v-model="form.guide" min-height="150px" placeholder="填写申报指南说明，可插入图片、列表和链接" /></el-form-item>
        <el-form-item label="附件要求" class="wide-field"><RichTextEditor v-model="form.attachment_requirements" min-height="150px" placeholder="填写附件总体要求" /></el-form-item>
        <el-form-item label="申报材料要求" class="wide-field">
          <div class="material-rule-editor">
            <div class="table-section-title">
              <span>指定单位提交项及允许格式</span>
              <el-button size="small" type="primary" :icon="Plus" @click="addProjectMaterialRule">新增材料</el-button>
            </div>
            <el-table :data="form.project_required_materials" border size="small">
              <el-table-column label="材料名称" min-width="160">
                <template #default="{ row }"><el-input v-model="row.label" placeholder="如 承诺书" /></template>
              </el-table-column>
              <el-table-column label="材料标识" min-width="150">
                <template #default="{ row }"><el-input v-model="row.purpose" placeholder="如 commitment" /></template>
              </el-table-column>
              <el-table-column label="必传" width="90" align="center">
                <template #default="{ row }"><el-switch v-model="row.required" /></template>
              </el-table-column>
              <el-table-column label="允许格式" min-width="220">
                <template #default="{ row }">
                  <el-select v-model="row.allowed_extensions" multiple filterable allow-create default-first-option placeholder="选择或填写扩展名">
                    <el-option v-for="item in extensionOptions" :key="item" :label="item" :value="item" />
                  </el-select>
                </template>
              </el-table-column>
              <el-table-column label="操作" width="90" align="center">
                <template #default="{ $index }"><el-button size="small" type="danger" @click="removeProjectMaterialRule($index)">删除</el-button></template>
              </el-table-column>
            </el-table>
          </div>
        </el-form-item>
        <el-form-item label="验收必传材料" class="wide-field">
          <el-checkbox-group v-model="form.acceptance_required_materials">
            <el-checkbox v-for="item in materialCategories" :key="item.value" :label="item.value">{{ item.label }}</el-checkbox>
          </el-checkbox-group>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="editorVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="saveBatch">保存</el-button>
      </template>
    </el-dialog>
  </section>
</template>

<script setup>
import { onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Edit, Plus, Refresh } from '@element-plus/icons-vue'
import { api } from '../api.js'
import { useSessionStore } from '../store.js'
import RichTextEditor from '../components/RichTextEditor.vue'

const session = useSessionStore()
const loading = ref(false)
const saving = ref(false)
const batches = ref([])
const keyword = ref('')
const status = ref('')
const e2eFilter = ref('')
const editorVisible = ref(false)
const dateRange = ref([])
const projectCategoryOptions = ref([])
const projectTypeOptions = ref([])
const statusLabels = {
  draft: { label: '草稿', type: 'info' },
  open: { label: '开放', type: 'success' },
  closed: { label: '关闭', type: 'warning' },
  archived: { label: '归档', type: 'info' }
}
const materialCategories = [
  { label: '验收申请书', value: 'acceptance_application' },
  { label: '项目总结', value: 'project_summary' },
  { label: '财务材料', value: 'financial' },
  { label: '成果证明', value: 'achievement' },
  { label: '其他', value: 'other' }
]
const extensionOptions = ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx', 'xls', 'xlsx']
const defaultProjectMaterialRules = [
  { purpose: 'application', label: '项目申报书', required: true, allowed_extensions: ['pdf', 'doc', 'docx'] },
  { purpose: 'commitment', label: '承诺书', required: true, allowed_extensions: ['pdf', 'jpg', 'jpeg', 'png'] },
  { purpose: 'seal_scan', label: '盖章扫描件', required: true, allowed_extensions: ['pdf', 'jpg', 'jpeg', 'png'] },
  { purpose: 'budget', label: '预算说明', required: false, allowed_extensions: ['pdf', 'xls', 'xlsx', 'doc', 'docx'] },
  { purpose: 'cooperation', label: '合作协议', required: false, allowed_extensions: ['pdf', 'doc', 'docx'] },
  { purpose: 'other', label: '其他材料', required: false, allowed_extensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx', 'xls', 'xlsx'] }
]
const form = reactive(emptyForm())

function emptyForm() {
  return {
    id: null,
    name: '',
    code: '',
    status: 'draft',
    allowed_categories: [],
    allowed_project_types: [],
    guide: '',
    attachment_requirements: '',
    acceptance_required_materials: [],
    project_required_materials: defaultProjectMaterialRules.map((item) => ({ ...item, allowed_extensions: [...item.allowed_extensions] })),
    metadata: {}
  }
}

function statusMeta(value) {
  return statusLabels[value] || { label: value || '-', type: 'info' }
}

function dictionaryOptionValue(item) {
  return item?.code || item?.label || ''
}

function dictionaryOptionLabel(item) {
  if (!item) return '-'
  if (!item.code || item.code === item.label) return item.label || item.code || '-'
  return `${item.label}（${item.code}）`
}

function dictionaryOptions(group) {
  return group === 'project_category' ? projectCategoryOptions.value : projectTypeOptions.value
}

function findDictionaryItem(group, value) {
  const text = String(value || '').trim()
  if (!text) return null
  return dictionaryOptions(group).find((item) => item.code === text || item.label === text) || null
}

function normalizeAllowedValues(group, values) {
  const known = []
  const custom = []
  const seen = new Set()

  ;(Array.isArray(values) ? values : []).forEach((value) => {
    const text = String(value || '').trim()
    if (!text) return

    const item = findDictionaryItem(group, text)
    const normalized = item ? dictionaryOptionValue(item) : text
    const canonical = item?.code || item?.label || `custom:${text}`
    if (seen.has(canonical)) return

    seen.add(canonical)
    ;(item ? known : custom).push(normalized)
  })

  return [...known, ...custom]
}

async function loadBatches() {
  loading.value = true
  try {
    const params = new URLSearchParams()
    if (keyword.value) params.set('keyword', keyword.value)
    if (status.value) params.set('status', status.value)
    if (e2eFilter.value !== '') params.set('e2e', e2eFilter.value)
    const result = await api(`/application-batches${params.toString() ? `?${params.toString()}` : ''}`)
    batches.value = result.data || result
  } finally {
    loading.value = false
  }
}

async function loadDictionaries() {
  const [categories, types] = await Promise.all([
    api('/dictionaries?group=project_category'),
    api('/dictionaries?group=project_type')
  ])
  projectCategoryOptions.value = categories
  projectTypeOptions.value = types
}

function openEditor(row = null) {
  Object.assign(form, emptyForm(), row || {})
  form.allowed_categories = normalizeAllowedValues('project_category', row?.allowed_categories || [])
  form.allowed_project_types = normalizeAllowedValues('project_type', row?.allowed_project_types || [])
  form.acceptance_required_materials = [...(row?.metadata?.acceptance_required_materials || [])]
  form.project_required_materials = normalizeProjectMaterialRules(row?.metadata?.project_required_materials, true)
  dateRange.value = row ? [row.starts_at, row.ends_at].filter(Boolean) : []
  editorVisible.value = true
}

function normalizeProjectMaterialRules(value, useDefaultWhenEmpty = false) {
  const source = Array.isArray(value) && value.length
    ? value
    : (useDefaultWhenEmpty ? defaultProjectMaterialRules : [])
  return source.map((item) => ({
    purpose: item.purpose || '',
    label: item.label || '',
    required: item.required !== false,
    allowed_extensions: Array.isArray(item.allowed_extensions) ? [...item.allowed_extensions] : []
  }))
}

function addProjectMaterialRule() {
  form.project_required_materials.push({
    purpose: `material_${form.project_required_materials.length + 1}`,
    label: '新增材料',
    required: false,
    allowed_extensions: ['pdf']
  })
}

function removeProjectMaterialRule(index) {
  form.project_required_materials.splice(index, 1)
}

async function saveBatch() {
  saving.value = true
  try {
    const payload = {
      name: form.name,
      code: form.code,
      status: form.status,
      starts_at: dateRange.value?.[0] || null,
      ends_at: dateRange.value?.[1] || null,
      allowed_categories: form.allowed_categories || [],
      allowed_project_types: form.allowed_project_types || [],
      guide: form.guide || null,
      attachment_requirements: form.attachment_requirements || null,
      metadata: {
        ...(form.metadata || {}),
        acceptance_required_materials: form.acceptance_required_materials || [],
        project_required_materials: normalizeProjectMaterialRules(form.project_required_materials)
      }
    }
    await api(form.id ? `/application-batches/${form.id}` : '/application-batches', {
      method: form.id ? 'PUT' : 'POST',
      body: JSON.stringify(payload)
    })
    ElMessage.success('批次已保存')
    editorVisible.value = false
    await loadBatches()
  } catch (err) {
    ElMessage.error(err?.message || '批次保存失败')
  } finally {
    saving.value = false
  }
}

async function changeStatus(row, action) {
  await api(`/application-batches/${row.id}/${action}`, { method: 'POST' })
  ElMessage.success('批次状态已更新')
  await loadBatches()
}

async function archiveE2eBatches() {
  await ElMessageBox.confirm('归档后测试批次不再作为开放批次使用，但数据不会删除。确认归档全部测试批次？', '归档测试批次', { type: 'warning' })
  const result = await api('/application-batches/archive-e2e', { method: 'POST' })
  ElMessage.success(`已归档 ${result.archived_count || 0} 个测试批次`)
  await loadBatches()
}

onMounted(() => {
  loadBatches()
  loadDictionaries()
})
</script>
