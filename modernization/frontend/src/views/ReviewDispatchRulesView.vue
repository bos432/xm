<template>
  <section class="page-stack">
    <div class="toolbar">
      <div>
        <h2>派单规则</h2>
        <span class="muted">按项目字段推荐或自动指定部门审核人、专家评审人</span>
      </div>
      <div class="toolbar-actions">
        <el-input v-model="keyword" clearable placeholder="规则名称/备注" @keyup.enter="loadRules" />
        <el-select v-model="targetStage" clearable placeholder="目标阶段" @change="loadRules">
          <el-option label="部门审核" value="department" />
          <el-option label="专家评审" value="expert" />
        </el-select>
        <el-select v-model="activeFilter" clearable placeholder="状态" @change="loadRules">
          <el-option label="启用" value="1" />
          <el-option label="停用" value="0" />
        </el-select>
        <el-button :icon="Search" @click="loadRules">查询</el-button>
        <el-button type="primary" :icon="Plus" @click="openEditor()">新增规则</el-button>
      </div>
    </div>

    <el-table :data="rules" border v-loading="loading">
      <el-table-column type="index" label="序号" width="72" align="center" :index="tableIndex" fixed="left" />
      <el-table-column prop="name" label="规则名称" min-width="180" />
      <el-table-column label="目标阶段" width="110">
        <template #default="{ row }">{{ stageLabel(row.target_stage) }}</template>
      </el-table-column>
      <el-table-column label="匹配条件" min-width="320">
        <template #default="{ row }">{{ conditionText(row) }}</template>
      </el-table-column>
      <el-table-column label="推荐/指定人员" min-width="220">
        <template #default="{ row }">{{ userNames(row.recommended_users) || '-' }}</template>
      </el-table-column>
      <el-table-column label="专家人数" width="100">
        <template #default="{ row }">{{ row.target_stage === 'expert' ? (row.expert_count || '系统默认') : '-' }}</template>
      </el-table-column>
      <el-table-column label="派单方式" width="120">
        <template #default="{ row }">
          <el-tag :type="row.auto_assign ? 'warning' : 'info'">{{ row.auto_assign ? '自动派单' : '推荐派单' }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="priority" label="优先级" width="90" />
      <el-table-column label="状态" width="90">
        <template #default="{ row }"><el-tag :type="row.is_active ? 'success' : 'info'">{{ row.is_active ? '启用' : '停用' }}</el-tag></template>
      </el-table-column>
      <el-table-column label="操作" width="150" fixed="right">
        <template #default="{ row }">
          <el-button size="small" :icon="Edit" @click="openEditor(row)">编辑</el-button>
          <el-button size="small" type="danger" :icon="Delete" circle @click="deleteRule(row)" />
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

    <el-dialog v-model="editorVisible" :title="form.id ? '编辑派单规则' : '新增派单规则'" width="820px">
      <el-alert
        type="info"
        :closable="false"
        show-icon
        title="推荐派单只提示处理人；自动派单开启后，仅指定账号能看到并处理该阶段任务。条件留空表示不限。"
        class="dialog-alert"
      />
      <el-form :model="form" label-position="top" class="home-manager-grid">
        <el-form-item label="规则名称"><el-input v-model="form.name" /></el-form-item>
        <el-form-item label="目标阶段">
          <el-select v-model="form.target_stage" @change="syncTargetUsers">
            <el-option label="部门审核" value="department" />
            <el-option label="专家评审" value="expert" />
          </el-select>
        </el-form-item>
        <el-form-item label="项目类别">
          <el-select v-model="form.project_category" clearable filterable>
            <el-option v-for="item in projectCategoryOptions" :key="item.code" :label="dictionaryOptionLabel(item)" :value="dictionaryOptionValue(item)" />
          </el-select>
        </el-form-item>
        <el-form-item label="项目类型">
          <el-select v-model="form.project_type" clearable filterable>
            <el-option v-for="item in projectTypeOptions" :key="item.code" :label="dictionaryOptionLabel(item)" :value="dictionaryOptionValue(item)" />
          </el-select>
        </el-form-item>
        <el-form-item label="归口管理单位">
          <el-select v-model="form.management_unit" clearable filterable>
            <el-option v-for="item in managementUnitOptions" :key="item.code" :label="dictionaryOptionLabel(item)" :value="dictionaryOptionValue(item)" />
          </el-select>
        </el-form-item>
        <el-form-item label="所属领域">
          <el-select v-model="form.project_field" clearable filterable>
            <el-option v-for="item in projectFieldOptions" :key="item.code" :label="dictionaryOptionLabel(item)" :value="dictionaryOptionValue(item)" />
          </el-select>
        </el-form-item>
        <el-form-item label="研究方向">
          <el-select v-model="form.research_direction" clearable filterable>
            <el-option v-for="item in researchDirectionOptions" :key="item.code" :label="dictionaryOptionLabel(item)" :value="dictionaryOptionValue(item)" />
          </el-select>
        </el-form-item>
        <el-form-item label="推荐/指定账号">
          <el-select v-model="form.recommended_user_ids" multiple filterable placeholder="选择目标阶段下的审核账号">
            <el-option v-for="user in targetUsers" :key="user.id" :label="`${user.name || user.username}（${user.username}）`" :value="user.id" />
          </el-select>
        </el-form-item>
        <el-form-item v-if="form.target_stage === 'expert'" label="随机专家人数">
          <el-input-number v-model="form.expert_count" :min="1" :max="20" />
          <span class="field-help">留空时使用“系统配置 -> 审核与评分”中的默认专家人数。</span>
        </el-form-item>
        <el-form-item label="优先级"><el-input-number v-model="form.priority" :min="0" :max="9999" /></el-form-item>
        <el-form-item label="状态"><el-switch v-model="form.is_active" active-text="启用" inactive-text="停用" /></el-form-item>
        <el-form-item label="自动派单">
          <el-switch v-model="form.auto_assign" active-text="开启" inactive-text="仅推荐" />
          <span class="field-help">开启后，只有上方指定账号能看到并处理命中的审核任务。</span>
        </el-form-item>
        <el-form-item label="备注" class="wide-field"><el-input v-model="form.remark" type="textarea" :rows="3" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="editorVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="saveRule">保存</el-button>
      </template>
    </el-dialog>
  </section>
</template>

<script setup>
import { onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Delete, Edit, Plus, Search } from '@element-plus/icons-vue'
import { api } from '../api.js'

const loading = ref(false)
const saving = ref(false)
const rules = ref([])
const keyword = ref('')
const targetStage = ref('')
const activeFilter = ref('')
const editorVisible = ref(false)
const pagination = reactive({ current_page: 1, per_page: 20, total: 0 })
const form = reactive(emptyForm())
const projectCategoryOptions = ref([])
const projectTypeOptions = ref([])
const managementUnitOptions = ref([])
const projectFieldOptions = ref([])
const researchDirectionOptions = ref([])
const targetUsers = ref([])

function emptyForm() {
  return {
    id: null,
    name: '',
    target_stage: 'department',
    management_unit: '',
    project_field: '',
    research_direction: '',
    project_category: '',
    project_type: '',
    recommended_user_ids: [],
    expert_count: null,
    auto_assign: false,
    is_active: true,
    priority: 100,
    remark: ''
  }
}

async function loadRules() {
  loading.value = true
  try {
    const params = new URLSearchParams()
    if (keyword.value) params.set('keyword', keyword.value)
    if (targetStage.value) params.set('target_stage', targetStage.value)
    if (activeFilter.value !== '') params.set('is_active', activeFilter.value)
    if (pagination.current_page > 1) params.set('page', pagination.current_page)
    const result = await api(`/review-dispatch-rules${params.toString() ? `?${params.toString()}` : ''}`)
    rules.value = result.data || result
    pagination.current_page = result.current_page || 1
    pagination.per_page = result.per_page || 20
    pagination.total = result.total || rules.value.length
  } finally {
    loading.value = false
  }
}

async function loadDictionaries() {
  const [categories, types, managementUnits, fields, directions] = await Promise.all([
    api('/dictionaries?group=project_category'),
    api('/dictionaries?group=project_type'),
    api('/dictionaries?group=management_unit'),
    api('/dictionaries?group=project_field'),
    api('/dictionaries?group=research_direction')
  ])
  projectCategoryOptions.value = categories
  projectTypeOptions.value = types
  managementUnitOptions.value = managementUnits
  projectFieldOptions.value = fields
  researchDirectionOptions.value = directions
}

async function loadTargetUsers() {
  const users = await api(`/review-dispatch-rules/users?roles=${form.target_stage}`)
  targetUsers.value = users
}

async function openEditor(row = null) {
  Object.assign(form, emptyForm(), row || {})
  form.recommended_user_ids = [...(row?.recommended_user_ids || [])].map(Number)
  editorVisible.value = true
  await loadTargetUsers()
}

async function syncTargetUsers() {
  form.recommended_user_ids = []
  await loadTargetUsers()
}

async function saveRule() {
  saving.value = true
  try {
    const path = form.id ? `/review-dispatch-rules/${form.id}` : '/review-dispatch-rules'
    await api(path, { method: form.id ? 'PUT' : 'POST', body: JSON.stringify({ ...form }) })
    ElMessage.success('派单规则已保存')
    editorVisible.value = false
    await loadRules()
  } finally {
    saving.value = false
  }
}

async function deleteRule(row) {
  await ElMessageBox.confirm(`确认删除派单规则“${row.name}”？`, '删除派单规则', { type: 'warning' })
  await api(`/review-dispatch-rules/${row.id}`, { method: 'DELETE' })
  ElMessage.success('派单规则已删除')
  await loadRules()
}

function changePage(page) {
  pagination.current_page = page
  loadRules()
}

function tableIndex(index) {
  return (pagination.current_page - 1) * pagination.per_page + index + 1
}

function stageLabel(value) {
  return value === 'expert' ? '专家评审' : '部门审核'
}

function dictionaryOptionValue(item) {
  return item?.code || item?.label || ''
}

function dictionaryOptionLabel(item) {
  if (!item) return '-'
  if (!item.code || item.code === item.label) return item.label || item.code || '-'
  return `${item.label}（${item.code}）`
}

function labelFromOptions(options, value) {
  const item = options.find((option) => option.code === value || option.label === value)
  return item?.label || value || ''
}

function conditionText(row) {
  const parts = [
    ['类别', labelFromOptions(projectCategoryOptions.value, row.project_category)],
    ['类型', labelFromOptions(projectTypeOptions.value, row.project_type)],
    ['归口', labelFromOptions(managementUnitOptions.value, row.management_unit)],
    ['领域', labelFromOptions(projectFieldOptions.value, row.project_field)],
    ['方向', labelFromOptions(researchDirectionOptions.value, row.research_direction)]
  ].filter(([, value]) => value)

  return parts.length ? parts.map(([key, value]) => `${key}：${value}`).join('；') : '不限条件'
}

function userNames(users = []) {
  return users.map((user) => user.name || user.username).filter(Boolean).join('、')
}

onMounted(async () => {
  await Promise.all([loadDictionaries(), loadRules()])
})
</script>

<style scoped>
.dialog-alert {
  margin-bottom: 14px;
}
</style>
