<template>
  <section class="page-stack">
    <div class="toolbar">
      <el-segmented v-model="status" :options="statusOptions" @change="reloadProjects" />
      <div class="toolbar-actions">
        <el-input v-model="keyword" clearable placeholder="按项目、单位、账号搜索" @keyup.enter="reloadProjects" @clear="reloadProjects" />
        <el-select v-model="category" clearable placeholder="类别" @change="reloadProjects" @clear="reloadProjects">
          <el-option v-for="item in projectCategoryOptions" :key="item.code" :label="item.label" :value="item.label" />
        </el-select>
        <el-select v-model="projectType" clearable placeholder="类型" @change="reloadProjects" @clear="reloadProjects">
          <el-option v-for="item in projectTypeOptions" :key="item.code" :label="item.label" :value="item.label" />
        </el-select>
        <el-select v-model="applicationBatchId" clearable placeholder="申报批次" @change="reloadProjects" @clear="reloadProjects">
          <el-option v-for="batch in openBatches" :key="batch.id" :label="batch.name" :value="batch.id" />
        </el-select>
        <el-switch v-if="session.can('manage_acceptance')" v-model="pendingExtensionOnly" active-text="待延期" @change="reloadProjects" />
        <el-tooltip content="查询项目" placement="top">
          <el-button type="primary" :icon="Search" circle @click="reloadProjects" />
        </el-tooltip>
        <el-tooltip content="导出当前筛选项目" placement="top">
          <el-button :icon="Download" @click="exportProjects">导出</el-button>
        </el-tooltip>
        <el-button v-if="canCreate" type="primary" :icon="Plus" @click="openCreate">新建项目</el-button>
      </div>
    </div>

    <el-table :data="projects" border v-loading="loading">
      <el-table-column prop="title" label="项目名称" min-width="220" />
      <el-table-column prop="unit.name" label="申报单位" min-width="180" />
      <el-table-column prop="application_batch.name" label="申报批次" min-width="160" />
      <el-table-column prop="project_type" label="项目类型" width="140" />
      <el-table-column label="状态" width="120">
        <template #default="{ row }">
          <el-tag :type="statusMeta(row.status).type">{{ statusMeta(row.status).label }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column v-if="session.can('manage_acceptance')" label="待延期" width="90" align="center">
        <template #default="{ row }">
          <el-tag v-if="row.pending_extension_requests_count" type="warning">{{ row.pending_extension_requests_count }}</el-tag>
          <span v-else>-</span>
        </template>
      </el-table-column>
      <el-table-column prop="submitted_at" label="提交时间" width="180" />
      <el-table-column label="操作" width="260" fixed="right">
        <template #default="{ row }">
          <div class="table-action-row">
            <el-button size="small" :icon="View" @click="openDetail(row)">详情</el-button>
            <el-button size="small" :icon="Connection" @click="openLifecycle(row)">全周期</el-button>
            <el-dropdown v-if="moreActions(row).length" trigger="click" @command="(command) => runMoreAction(command, row)">
              <el-button size="small">更多</el-button>
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item v-for="action in moreActions(row)" :key="action.command" :command="action.command" :disabled="action.disabled">
                    {{ action.label }}
                  </el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>
          </div>
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

    <el-dialog v-model="dialogVisible" :title="editingProject ? '编辑申报项目' : '新建申报项目'" width="560px">
      <el-form :model="form" label-position="top">
        <el-form-item label="项目名称"><el-input v-model="form.title" /></el-form-item>
        <el-form-item label="申报批次">
          <el-select v-model="form.application_batch_id" placeholder="请选择开放批次">
            <el-option v-for="batch in openBatches" :key="batch.id" :label="batch.name" :value="batch.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="项目类型">
          <el-select v-model="form.project_type" filterable allow-create clearable>
            <el-option v-for="item in projectTypeOptions" :key="item.code" :label="item.label" :value="item.label" />
          </el-select>
        </el-form-item>
        <el-form-item label="项目类别">
          <el-select v-model="form.category" filterable allow-create clearable>
            <el-option v-for="item in projectCategoryOptions" :key="item.code" :label="item.label" :value="item.label" />
          </el-select>
        </el-form-item>
        <el-form-item label="项目摘要"><el-input v-model="form.summary" type="textarea" :rows="4" /></el-form-item>
        <el-form-item label="预算金额"><el-input-number v-model="form.budget_amount" :min="0" :precision="2" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="saveProject">保存草稿</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="extensionVisible" title="申请延期" width="520px">
      <el-form :model="extensionForm" label-position="top">
        <el-form-item label="延期原因"><el-input v-model="extensionForm.reason" type="textarea" :rows="4" /></el-form-item>
        <el-form-item label="计划完成日期"><el-date-picker v-model="extensionForm.expected_date" value-format="YYYY-MM-DD" type="date" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="extensionVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="requestExtension">提交申请</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="closeVisible" title="关闭验收" width="520px">
      <el-form :model="closeForm" label-position="top">
        <el-form-item label="验收意见"><el-input v-model="closeForm.comment" type="textarea" :rows="4" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="closeVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="closeProject">确认关闭</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="uploadVisible" title="上传附件" width="520px">
      <el-alert title="仅允许 jpg、png、pdf、doc、docx、xls、xlsx、zip，脚本文件会被拒绝。" type="info" show-icon :closable="false" />
      <el-upload class="upload-box" drag :http-request="uploadFile" :show-file-list="false">
        <el-icon><UploadFilled /></el-icon>
        <div>拖拽文件到这里或点击选择</div>
      </el-upload>
    </el-dialog>

    <el-drawer v-model="detailVisible" title="项目详情" size="640px">
      <div v-if="detail" class="detail-stack">
        <el-descriptions :column="2" border>
          <el-descriptions-item label="项目名称" :span="2">{{ detail.title }}</el-descriptions-item>
          <el-descriptions-item label="申报单位">{{ detail.unit?.name || '-' }}</el-descriptions-item>
          <el-descriptions-item label="状态">{{ statusMeta(detail.status).label }}</el-descriptions-item>
          <el-descriptions-item label="项目类型">{{ detail.project_type || '-' }}</el-descriptions-item>
          <el-descriptions-item label="预算金额">{{ detail.budget_amount || '-' }}</el-descriptions-item>
          <el-descriptions-item label="摘要" :span="2">{{ detail.summary || '-' }}</el-descriptions-item>
        </el-descriptions>

        <section v-if="detail.timeline?.length">
          <div class="section-title">项目阶段</div>
          <el-steps :active="timelineActiveIndex(detail.timeline)" finish-status="success" process-status="process" align-center>
            <el-step v-for="item in detail.timeline" :key="item.key" :title="item.label" :description="timelineDescription(item)" />
          </el-steps>
        </section>

        <section v-if="detail.metadata?.extension_requests?.length">
          <div class="section-title">延期记录</div>
          <el-table :data="detail.metadata.extension_requests" border size="small">
            <el-table-column prop="reason" label="原因" min-width="220" />
            <el-table-column prop="expected_date" label="计划日期" width="120" />
            <el-table-column label="状态" width="100">
              <template #default="{ row }">
                <el-tag :type="extensionStatusMeta(row.status).type">{{ extensionStatusMeta(row.status).label }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="review_comment" label="处理意见" min-width="160" />
            <el-table-column prop="requested_at" label="申请时间" width="170" />
            <el-table-column v-if="session.can('manage_acceptance')" label="操作" width="130">
              <template #default="{ row, $index }">
                <el-tooltip v-if="canReviewExtension(row)" content="通过延期" placement="top"><el-button size="small" type="success" :icon="Checked" circle @click="reviewExtension($index, 'approved')" /></el-tooltip>
                <el-tooltip v-if="canReviewExtension(row)" content="驳回延期" placement="top"><el-button size="small" type="danger" :icon="CloseBold" circle @click="reviewExtension($index, 'rejected')" /></el-tooltip>
              </template>
            </el-table-column>
          </el-table>
        </section>

        <section>
          <div class="section-title">附件</div>
          <el-table :data="detail.files || []" border size="small">
            <el-table-column prop="original_name" label="文件名" min-width="220" />
            <el-table-column prop="extension" label="类型" width="80" />
            <el-table-column prop="size_bytes" label="大小" width="110"><template #default="{ row }">{{ formatBytes(row.size_bytes) }}</template></el-table-column>
            <el-table-column label="操作" width="150">
              <template #default="{ row }">
                <el-tooltip content="下载" placement="top"><el-button size="small" :icon="Download" circle @click="downloadFile(row)" /></el-tooltip>
                <el-tooltip v-if="canEdit(detail)" content="删除附件" placement="top"><el-button size="small" type="danger" :icon="Delete" circle @click="deleteFile(row)" /></el-tooltip>
                <el-tooltip v-if="session.can('view_operation_logs')" content="查看附件日志" placement="top"><el-button size="small" :icon="Files" circle @click="openFileLogs(row)" /></el-tooltip>
              </template>
            </el-table-column>
          </el-table>
        </section>

        <section>
          <div class="section-title">
            <span>审核记录</span>
            <el-tooltip v-if="session.can('review_projects')" content="查看审核结果" placement="top">
              <el-button size="small" :icon="View" circle @click="openReviewResults(detail)" />
            </el-tooltip>
            <el-tooltip v-if="session.can('view_operation_logs')" content="查看操作日志" placement="top">
              <el-button size="small" :icon="Files" circle @click="openProjectLogs(detail)" />
            </el-tooltip>
          </div>
          <el-table :data="detail.reviews || []" border size="small">
            <el-table-column label="阶段" width="110">
              <template #default="{ row }">{{ roleLabel(row.stage) }}</template>
            </el-table-column>
            <el-table-column label="结果" width="110">
              <template #default="{ row }">{{ decisionLabel(row.decision) }}</template>
            </el-table-column>
            <el-table-column prop="reviewer.username" label="审核人" width="130" />
            <el-table-column prop="score" label="评分" width="90" />
            <el-table-column prop="comment" label="意见" min-width="220" />
            <el-table-column prop="reviewed_at" label="时间" width="170" />
          </el-table>
        </section>
      </div>
    </el-drawer>
  </section>
</template>

<script setup>
import { computed, onMounted, onUnmounted, reactive, ref, watch } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Checked, CloseBold, Connection, Delete, Download, Files, Plus, Refresh, Search, UploadFilled, View } from '@element-plus/icons-vue'
import { useRoute, useRouter } from 'vue-router'
import { api, downloadApi } from '../api.js'
import { useSessionStore } from '../store.js'

const route = useRoute()
const router = useRouter()
const session = useSessionStore()
const statusOptions = [
  { label: '全部', value: '' },
  { label: '草稿', value: 'draft' },
  { label: '已提交', value: 'submitted' },
  { label: '退回修改', value: 'returned' },
  { label: '审核中', value: 'reviewing' },
  { label: '已通过', value: 'approved' },
  { label: '验收中', value: 'acceptance' },
  { label: '已关闭', value: 'closed' }
]
const statusLabels = {
  draft: { label: '草稿', type: 'info' },
  submitted: { label: '已提交', type: 'warning' },
  returned: { label: '退回修改', type: 'danger' },
  reviewing: { label: '审核中', type: 'primary' },
  approved: { label: '已通过', type: 'success' },
  acceptance: { label: '验收中', type: 'primary' },
  closed: { label: '已关闭', type: 'info' },
  rejected: { label: '已拒绝', type: 'danger' }
}
const roleLabels = {
  county: '区县审核',
  department: '部门审核',
  expert: '专家评审',
  admin: '管理员终审'
}
const decisionLabels = {
  approve: '通过',
  recommend: '推荐',
  accept: '通过',
  return: '退回',
  reject: '驳回'
}
const extensionStatusLabels = {
  pending: { label: '待处理', type: 'warning' },
  approved: { label: '已通过', type: 'success' },
  rejected: { label: '已驳回', type: 'danger' }
}

const status = ref('')
const keyword = ref('')
const loading = ref(false)
const saving = ref(false)
const projects = ref([])
const projectTypeOptions = ref([])
const projectCategoryOptions = ref([])
const openBatches = ref([])
const category = ref('')
const projectType = ref('')
const applicationBatchId = ref('')
const pendingExtensionOnly = ref(false)
const dialogVisible = ref(false)
const uploadVisible = ref(false)
const extensionVisible = ref(false)
const closeVisible = ref(false)
const detailVisible = ref(false)
const detail = ref(null)
const currentProject = ref(null)
const editingProject = ref(null)
const actionProject = ref(null)
const form = reactive({ title: '', application_batch_id: null, category: '', project_type: '', summary: '', budget_amount: 0 })
const extensionForm = reactive({ reason: '', expected_date: '' })
const closeForm = reactive({ comment: '' })
const pagination = reactive({ current_page: 1, per_page: 20, total: 0 })
const unitCanWriteProjects = computed(() => session.role !== 'unit' || session.user?.unit?.status === 'active')
const canCreate = computed(() => session.can('create_projects') && unitCanWriteProjects.value)

function statusMeta(value) {
  return statusLabels[value] || { label: value || '-', type: 'info' }
}

function roleLabel(role) {
  return roleLabels[role] || role || '-'
}

function decisionLabel(value) {
  return decisionLabels[value] || value || '-'
}

function extensionStatusMeta(value) {
  return extensionStatusLabels[value || 'pending'] || { label: value || '-', type: 'info' }
}

function canEdit(row) {
  return unitCanWriteProjects.value && session.can('create_projects') && ['draft', 'returned'].includes(row.status)
}

function canSubmit(row) {
  return unitCanWriteProjects.value && session.can('submit_projects') && ['draft', 'returned'].includes(row.status)
}

function canWithdraw(row) {
  return unitCanWriteProjects.value && session.can('submit_projects') && row.status === 'submitted'
}

function canDelete(row) {
  return unitCanWriteProjects.value && session.can('create_projects') && row.status === 'draft'
}

function canRequestExtension(row) {
  return unitCanWriteProjects.value && session.can('submit_projects') && ['approved', 'acceptance'].includes(row.status)
}

function canEnterAcceptance(row) {
  return session.can('manage_acceptance') && row.status === 'approved'
}

function canClose(row) {
  return session.can('manage_acceptance') && row.status === 'acceptance' && pendingExtensionCount(row) === 0
}

function canReviewExtension(row) {
  return session.can('manage_acceptance') && (row.status || 'pending') === 'pending'
}

function pendingExtensionCount(row) {
  if (row.pending_extension_requests_count !== undefined) return Number(row.pending_extension_requests_count || 0)
  return (row.metadata?.extension_requests || []).filter((item) => (item.status || 'pending') === 'pending').length
}

function moreActions(row) {
  const actions = []
  if (canEdit(row)) {
    actions.push({ command: 'edit', label: '编辑' })
    actions.push({ command: 'upload', label: '附件' })
  }
  if (canSubmit(row)) actions.push({ command: 'submit', label: '提交' })
  if (canWithdraw(row)) actions.push({ command: 'withdraw', label: '撤回' })
  if (canRequestExtension(row)) actions.push({ command: 'extension', label: '申请延期' })
  if (canEnterAcceptance(row)) actions.push({ command: 'enterAcceptance', label: '进入验收' })
  if (canClose(row)) actions.push({ command: 'close', label: '关闭验收' })
  if (session.can('review_projects')) actions.push({ command: 'reviews', label: '审核记录' })
  if (session.can('view_operation_logs')) actions.push({ command: 'logs', label: '操作日志' })
  if (canDelete(row)) actions.push({ command: 'delete', label: '删除' })
  return actions
}

function runMoreAction(command, row) {
  const handlers = {
    edit: () => openEdit(row),
    upload: () => openUpload(row),
    submit: () => submitProject(row),
    withdraw: () => withdrawProject(row),
    extension: () => openExtension(row),
    enterAcceptance: () => enterAcceptance(row),
    close: () => openClose(row),
    reviews: () => openReviewResults(row),
    logs: () => openProjectLogs(row),
    delete: () => deleteProject(row)
  }
  handlers[command]?.()
}

function resetForm() {
  Object.assign(form, { title: '', application_batch_id: openBatches.value[0]?.id || null, category: '', project_type: '', summary: '', budget_amount: 0 })
}

async function loadDictionaries() {
  const [types, categories, batches] = await Promise.all([
    api('/dictionaries?group=project_type'),
    api('/dictionaries?group=project_category'),
    api('/public/application-batches/open')
  ])
  projectTypeOptions.value = types
  projectCategoryOptions.value = categories
  openBatches.value = batches
}

async function loadProjects() {
  loading.value = true
  try {
    const query = buildProjectQuery()
    const result = await api(`/projects${query}`)
    projects.value = result.data || result
    pagination.current_page = result.current_page || 1
    pagination.per_page = result.per_page || 20
    pagination.total = result.total || projects.value.length
  } finally {
    loading.value = false
  }
}

function buildProjectQuery() {
  const params = new URLSearchParams()
  if (status.value) params.set('status', status.value)
  if (keyword.value) params.set('keyword', keyword.value)
  if (category.value) params.set('category', category.value)
  if (projectType.value) params.set('project_type', projectType.value)
  if (applicationBatchId.value) params.set('application_batch_id', applicationBatchId.value)
  if (route.query.unit_id) params.set('unit_id', route.query.unit_id)
  if (pendingExtensionOnly.value) params.set('pending_extension', '1')
  if (pagination.current_page > 1) params.set('page', pagination.current_page)
  return params.toString() ? `?${params.toString()}` : ''
}

function applyRouteQuery() {
  status.value = typeof route.query.status === 'string' ? route.query.status : ''
  keyword.value = typeof route.query.keyword === 'string' ? route.query.keyword : ''
  category.value = typeof route.query.category === 'string' ? route.query.category : ''
  projectType.value = typeof route.query.project_type === 'string' ? route.query.project_type : ''
  const batchId = route.query.application_batch_id || route.query.batch_id
  applicationBatchId.value = batchId ? Number(batchId) : ''
  pendingExtensionOnly.value = route.query.pending_extension === '1'
  pagination.current_page = route.query.page ? Number(route.query.page) || 1 : 1
}

async function syncRouteQuery() {
  const query = { ...route.query }
  const setOrDelete = (key, value) => {
    if (value === '' || value === null || value === undefined || value === false) delete query[key]
    else query[key] = String(value)
  }

  setOrDelete('status', status.value)
  setOrDelete('keyword', keyword.value)
  setOrDelete('category', category.value)
  setOrDelete('project_type', projectType.value)
  setOrDelete('application_batch_id', applicationBatchId.value)
  setOrDelete('pending_extension', pendingExtensionOnly.value ? '1' : '')
  setOrDelete('page', pagination.current_page > 1 ? pagination.current_page : '')
  delete query.project_id

  const current = JSON.stringify(route.query)
  const next = JSON.stringify(query)
  if (current === next) return false

  await router.replace({ path: route.path, query })
  return true
}

async function openRouteProject() {
  if (route.query.project_id) {
    await openDetail({ id: route.query.project_id })
  }
}

async function reloadProjects() {
  pagination.current_page = 1
  const routeChanged = await syncRouteQuery()
  if (routeChanged) return
  await loadProjects()
}

async function changePage(page) {
  pagination.current_page = page
  const routeChanged = await syncRouteQuery()
  if (routeChanged) return
  await loadProjects()
}

async function openCreate() {
  if (!projectTypeOptions.value.length && !projectCategoryOptions.value.length) await loadDictionaries()
  editingProject.value = null
  resetForm()
  dialogVisible.value = true
}

async function openEdit(row) {
  if (!projectTypeOptions.value.length && !projectCategoryOptions.value.length) await loadDictionaries()
  editingProject.value = row
  Object.assign(form, {
    title: row.title || '',
    category: row.category || '',
    project_type: row.project_type || '',
    application_batch_id: row.application_batch_id || row.application_batch?.id || null,
    summary: row.summary || '',
    budget_amount: Number(row.budget_amount || 0)
  })
  dialogVisible.value = true
}

async function saveProject() {
  if (!unitCanWriteProjects.value) {
    ElMessage.error('单位已停用，无法维护申报项目')
    return
  }

  saving.value = true
  try {
    const path = editingProject.value ? `/projects/${editingProject.value.id}` : '/projects'
    const method = editingProject.value ? 'PUT' : 'POST'
    await api(path, { method, body: JSON.stringify(form) })
    ElMessage.success(editingProject.value ? '项目已保存' : '项目草稿已创建')
    dialogVisible.value = false
    resetForm()
    await loadProjects()
  } finally {
    saving.value = false
  }
}

async function submitProject(row) {
  if (!unitCanWriteProjects.value) {
    ElMessage.error('单位已停用，无法提交项目')
    return
  }

  await ElMessageBox.confirm('提交后将进入区县审核，确认提交？', '提交项目', { type: 'warning' })
  await api(`/projects/${row.id}/submit`, { method: 'POST' })
  ElMessage.success('项目已提交审核')
  await loadProjects()
}

async function withdrawProject(row) {
  if (!unitCanWriteProjects.value) {
    ElMessage.error('单位已停用，无法撤回项目')
    return
  }

  await ElMessageBox.confirm('确认撤回该项目？', '撤回项目', { type: 'warning' })
  await api(`/projects/${row.id}/withdraw`, { method: 'POST' })
  ElMessage.success('项目已撤回')
  await loadProjects()
}

async function deleteProject(row) {
  if (!unitCanWriteProjects.value) {
    ElMessage.error('单位已停用，无法删除项目')
    return
  }

  await ElMessageBox.confirm('草稿删除后不可恢复，确认删除？', '删除项目', { type: 'warning' })
  await api(`/projects/${row.id}`, { method: 'DELETE' })
  ElMessage.success('项目已删除')
  await loadProjects()
}

async function enterAcceptance(row) {
  await ElMessageBox.confirm('确认将项目转入验收阶段？', '进入验收', { type: 'warning' })
  await api(`/projects/${row.id}/enter-acceptance`, { method: 'POST' })
  ElMessage.success('项目已进入验收')
  await loadProjects()
}

function openExtension(row) {
  if (!unitCanWriteProjects.value) {
    ElMessage.error('单位已停用，无法申请延期')
    return
  }

  actionProject.value = row
  Object.assign(extensionForm, { reason: '', expected_date: '' })
  extensionVisible.value = true
}

async function requestExtension() {
  saving.value = true
  try {
    await api(`/projects/${actionProject.value.id}/extension`, { method: 'POST', body: JSON.stringify(extensionForm) })
    ElMessage.success('延期申请已提交')
    extensionVisible.value = false
    await loadProjects()
  } finally {
    saving.value = false
  }
}

async function reviewExtension(index, decision) {
  const label = decision === 'approved' ? '通过' : '驳回'
  const { value: comment } = await ElMessageBox.prompt('请输入处理意见', `${label}延期申请`, {
    inputType: 'textarea',
    inputPlaceholder: '处理意见',
    confirmButtonText: label,
    cancelButtonText: '取消'
  })

  await api(`/projects/${detail.value.id}/extension/${index}/review`, {
    method: 'POST',
    body: JSON.stringify({ decision, comment })
  })
  ElMessage.success(`延期申请已${label}`)
  await openDetail(detail.value)
  await loadProjects()
}

function openClose(row) {
  actionProject.value = row
  Object.assign(closeForm, { comment: '' })
  closeVisible.value = true
}

async function closeProject() {
  saving.value = true
  try {
    await api(`/projects/${actionProject.value.id}/close`, { method: 'POST', body: JSON.stringify(closeForm) })
    ElMessage.success('项目验收已关闭')
    closeVisible.value = false
    await loadProjects()
  } finally {
    saving.value = false
  }
}

async function openDetail(row) {
  detail.value = await api(`/projects/${row.id}`)
  detailVisible.value = true
}

function openReviewResults(row) {
  router.push(`/reviews?tab=results&project_id=${row.id}`)
}

function openLifecycle(row) {
  router.push(`/lifecycle?project_id=${row.id}`)
}

function openProjectLogs(row) {
  router.push(`/operation-logs?target_type=${encodeURIComponent('App\\Models\\Project')}&target_id=${row.id}`)
}

function openFileLogs(row) {
  router.push(`/operation-logs?target_type=${encodeURIComponent('App\\Models\\ProjectFile')}&target_id=${row.id}`)
}

function openUpload(row) {
  currentProject.value = row
  uploadVisible.value = true
}

async function uploadFile({ file }) {
  if (!unitCanWriteProjects.value) {
    ElMessage.error('单位已停用，无法上传附件')
    return
  }

  const body = new FormData()
  body.append('file', file)
  await api(`/projects/${currentProject.value.id}/files`, { method: 'POST', body })
  ElMessage.success('附件已上传')
  uploadVisible.value = false
  if (detail.value?.id === currentProject.value.id) await openDetail(currentProject.value)
}

async function exportProjects() {
  const params = new URLSearchParams()
  if (status.value) params.set('status', status.value)
  if (keyword.value) params.set('keyword', keyword.value)
  if (category.value) params.set('category', category.value)
  if (projectType.value) params.set('project_type', projectType.value)
  if (applicationBatchId.value) params.set('application_batch_id', applicationBatchId.value)
  if (pendingExtensionOnly.value) params.set('pending_extension', '1')
  const query = params.toString() ? `?${params.toString()}` : ''
  try {
    await downloadApi(`/projects/export.csv${query}`, `projects-${new Date().toISOString().slice(0, 10)}.csv`)
  } catch (err) {
    ElMessage.error(err.message || '项目导出失败')
  }
}

async function downloadFile(row) {
  try {
    await downloadApi(`/files/${row.id}/download`, row.original_name || 'download')
  } catch (err) {
    ElMessage.error(err.message || '附件下载失败')
  }
}

async function deleteFile(row) {
  if (!unitCanWriteProjects.value) {
    ElMessage.error('单位已停用，无法删除附件')
    return
  }

  await ElMessageBox.confirm('确认删除该附件？', '删除附件', { type: 'warning' })
  await api(`/files/${row.id}`, { method: 'DELETE' })
  ElMessage.success('附件已删除')
  if (detail.value) await openDetail(detail.value)
}

function formatBytes(value) {
  const size = Number(value || 0)
  if (size < 1024) return `${size} B`
  if (size < 1024 * 1024) return `${(size / 1024).toFixed(1)} KB`
  return `${(size / 1024 / 1024).toFixed(1)} MB`
}

function timelineActiveIndex(items) {
  const currentIndex = items.findIndex((item) => item.status === 'current')
  if (currentIndex >= 0) return currentIndex
  const doneIndexes = items.map((item, index) => (item.status === 'done' ? index : -1)).filter((index) => index >= 0)
  return doneIndexes.length ? Math.max(...doneIndexes) + 1 : 0
}

function timelineDescription(item) {
  const parts = []
  if (item.handler) parts.push(item.handler)
  if (item.handled_at) parts.push(item.handled_at)
  if (item.decision) parts.push(decisionLabel(item.decision))
  return parts.join(' / ') || (item.status === 'current' ? '当前待处理' : '待流转')
}

watch(() => route.query, () => {
  applyRouteQuery()
  loadProjects()
}, { deep: true })
watch(() => route.query.project_id, openRouteProject)
onMounted(async () => {
  applyRouteQuery()
  await Promise.all([loadProjects(), loadDictionaries()])
  await openRouteProject()
  window.addEventListener('dictionaries:changed', loadDictionaries)
})

onUnmounted(() => {
  window.removeEventListener('dictionaries:changed', loadDictionaries)
})
</script>
