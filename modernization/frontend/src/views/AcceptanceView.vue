<template>
  <section class="page-stack">
    <div class="toolbar">
      <div>
        <h2>验收管理</h2>
        <span class="muted">单位提交验收材料，区县、部门、专家和管理员分阶段处理</span>
      </div>
      <div class="toolbar-actions">
        <el-input v-model="keyword" clearable placeholder="项目/单位" @keyup.enter="reloadAcceptances" @clear="reloadAcceptances" />
        <el-select v-model="status" clearable placeholder="状态" @change="reloadAcceptances" @clear="reloadAcceptances">
          <el-option label="草稿" value="draft" />
          <el-option label="已提交" value="submitted" />
          <el-option label="审核中" value="reviewing" />
          <el-option label="退回修改" value="returned" />
          <el-option label="已驳回" value="rejected" />
          <el-option label="已通过" value="approved" />
          <el-option label="已关闭" value="closed" />
        </el-select>
        <el-select v-if="canFilterE2e" v-model="e2eFilter" clearable placeholder="测试数据" @change="reloadAcceptances" @clear="reloadAcceptances">
          <el-option label="只看测试数据" value="1" />
          <el-option label="排除测试数据" value="0" />
        </el-select>
        <el-button :icon="Refresh" :loading="loading" @click="loadAcceptances">刷新</el-button>
        <el-button v-if="session.can('submit_acceptance')" type="primary" :icon="Plus" @click="createVisible = true">发起验收</el-button>
      </div>
    </div>

    <el-tabs v-if="showScopeTabs" v-model="scope" @tab-change="handleScopeChange">
      <el-tab-pane :label="texts.t('acceptance.tab.pending', '待处理')" name="pending" />
      <el-tab-pane :label="texts.t('acceptance.tab.reviewed', '已处理')" name="reviewed" />
      <el-tab-pane :label="texts.t('acceptance.tab.visible', '全部可见')" name="visible" />
    </el-tabs>

    <el-table :data="acceptances" border v-loading="loading">
      <el-table-column label="项目" min-width="240">
        <template #default="{ row }">
          <strong>{{ row.project?.title || '-' }}</strong>
          <div class="muted">{{ row.unit?.name || row.project?.unit?.name || '-' }}</div>
        </template>
      </el-table-column>
      <el-table-column label="状态" width="110">
        <template #default="{ row }"><el-tag :type="statusMeta(row.status).type">{{ statusMeta(row.status).label }}</el-tag></template>
      </el-table-column>
      <el-table-column label="当前阶段" width="130">
        <template #default="{ row }">{{ roleLabel(row.current_reviewer_role) }}</template>
      </el-table-column>
      <el-table-column prop="submitted_at" label="提交时间" width="170" />
      <el-table-column prop="summary" label="验收说明" min-width="220" show-overflow-tooltip />
      <el-table-column label="操作" width="310" fixed="right">
        <template #default="{ row }">
          <div class="table-action-row">
            <el-button size="small" :icon="View" @click="openDetail(row)">详情</el-button>
            <el-button v-if="canSubmit(row)" size="small" type="primary" @click="openSubmit(row)">提交</el-button>
            <el-button v-if="canUpload(row)" size="small" :icon="Upload" @click="openUpload(row)">材料</el-button>
            <el-button v-if="canReview(row)" size="small" type="success" @click="openReview(row)">审核</el-button>
            <el-button v-if="canExtend(row)" size="small" @click="openExtension(row)">延期</el-button>
          </div>
        </template>
      </el-table-column>
    </el-table>

    <el-dialog v-model="createVisible" title="发起验收" width="520px">
      <el-form :model="createForm" label-position="top">
        <el-form-item label="项目">
          <el-select
            v-model="createForm.project_id"
            clearable
            filterable
            remote
            reserve-keyword
            :remote-method="(keyword) => searchProjects(keyword, 'acceptance')"
            :loading="projectOptionsLoading"
            placeholder="搜索已通过或验收中项目"
          >
            <el-option v-for="item in projectOptions" :key="item.id" :label="projectOptionLabel(item)" :value="item.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="验收说明"><RichTextEditor v-model="createForm.summary" min-height="150px" placeholder="填写验收背景、完成情况和申请说明" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="createVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="createAcceptance">保存草稿</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="submitVisible" title="提交验收" width="560px">
      <el-form :model="submitForm" label-position="top">
        <el-alert
          v-if="submitRequiredMaterialLabels.length"
          class="mb-12"
          type="warning"
          show-icon
          :closable="false"
          :title="`提交前需上传：${submitRequiredMaterialLabels.join('、')}`"
        />
        <el-form-item label="验收说明"><RichTextEditor v-model="submitForm.summary" min-height="170px" placeholder="补充验收说明，可插入图片、列表和链接" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="submitVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="submitAcceptance">提交</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="reviewVisible" title="验收审核" width="560px">
      <el-form :model="reviewForm" label-position="top">
        <el-form-item label="处理结果">
          <el-select v-model="reviewForm.decision">
            <el-option label="通过" value="approve" />
            <el-option label="退回修改" value="return" />
            <el-option label="驳回" value="reject" />
            <el-option v-if="currentAcceptance?.current_reviewer_role === 'admin'" label="终审关闭" value="close" />
          </el-select>
        </el-form-item>
        <el-form-item label="评分"><el-input-number v-model="reviewForm.score" :min="0" :max="100" /></el-form-item>
        <el-form-item label="审核意见"><RichTextEditor v-model="reviewForm.comment" min-height="150px" placeholder="填写验收审核意见" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="reviewVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="saveReview">提交审核</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="extensionVisible" title="验收延期" width="560px">
      <el-form :model="extensionForm" label-position="top">
        <template v-if="session.role === 'unit'">
          <el-form-item label="延期原因"><RichTextEditor v-model="extensionForm.reason" min-height="150px" placeholder="填写延期原因和后续计划" /></el-form-item>
          <el-form-item label="计划完成日期"><el-date-picker v-model="extensionForm.expected_date" type="date" value-format="YYYY-MM-DD" /></el-form-item>
        </template>
        <template v-else>
          <el-form-item label="延期记录">
            <el-select v-model="extensionForm.extension_id">
              <el-option v-for="item in detail?.extensions || []" :key="item.id" :label="`${item.reason}（${item.status}）`" :value="item.id" />
            </el-select>
          </el-form-item>
          <el-form-item label="处理结果">
            <el-select v-model="extensionForm.decision">
              <el-option label="通过" value="approved" />
              <el-option label="驳回" value="rejected" />
            </el-select>
          </el-form-item>
          <el-form-item label="处理意见"><RichTextEditor v-model="extensionForm.comment" min-height="150px" placeholder="填写延期处理意见" /></el-form-item>
        </template>
      </el-form>
      <template #footer>
        <el-button @click="extensionVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="saveExtension">保存</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="uploadVisible" title="上传验收材料" width="520px">
      <el-form label-position="top">
        <el-form-item label="材料分类">
          <el-select v-model="uploadCategory" placeholder="请选择材料分类">
            <el-option v-for="item in materialCategories" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
      </el-form>
      <el-upload drag :show-file-list="false" :http-request="uploadFile">
        <el-icon><Upload /></el-icon>
        <div>拖拽文件到这里或点击选择</div>
      </el-upload>
    </el-dialog>

    <el-drawer v-model="detailVisible" title="验收详情" size="680px">
      <div v-if="detail" class="detail-stack">
        <el-descriptions :column="2" border>
          <el-descriptions-item label="项目" :span="2">{{ detail.project?.title }}</el-descriptions-item>
          <el-descriptions-item label="单位">{{ detail.unit?.name }}</el-descriptions-item>
          <el-descriptions-item label="状态">{{ statusMeta(detail.status).label }}</el-descriptions-item>
          <el-descriptions-item label="说明" :span="2"><div class="rich-content detail-rich-content" v-html="detail.summary || '-'" /></el-descriptions-item>
        </el-descriptions>
        <section v-if="detail.timeline?.length">
          <div class="section-title">验收阶段</div>
          <el-steps :active="timelineActiveIndex(detail.timeline)" finish-status="success" process-status="process" align-center>
            <el-step
              v-for="item in detail.timeline"
              :key="item.key"
              :title="item.label"
              :description="timelineDescription(item)"
              :status="timelineStepStatus(item)"
              @click="selectedTimelineKey = item.key"
            />
          </el-steps>
          <el-descriptions v-if="selectedTimelineItem" :column="2" border class="mt-16">
            <el-descriptions-item label="阶段">{{ selectedTimelineItem.label }}</el-descriptions-item>
            <el-descriptions-item label="状态">{{ timelineStatusLabel(selectedTimelineItem.status) }}</el-descriptions-item>
            <el-descriptions-item label="处理人">{{ selectedTimelineItem.handler || '-' }}</el-descriptions-item>
            <el-descriptions-item label="处理时间">{{ selectedTimelineItem.handled_at || '-' }}</el-descriptions-item>
            <el-descriptions-item label="处理结果">{{ decisionLabel(selectedTimelineItem.decision) }}</el-descriptions-item>
            <el-descriptions-item label="评分">{{ selectedTimelineItem.score ?? '-' }}</el-descriptions-item>
            <el-descriptions-item label="意见" :span="2"><div class="rich-content detail-rich-content" v-html="selectedTimelineItem.comment || '-'" /></el-descriptions-item>
          </el-descriptions>
        </section>
        <section>
          <div class="section-title">
            <span>验收材料</span>
            <el-tag v-if="requiredMaterialLabels.length" type="warning" effect="plain">必传：{{ requiredMaterialLabels.join('、') }}</el-tag>
          </div>
          <el-table :data="detail.project?.files || []" border size="small">
            <el-table-column prop="original_name" label="文件名" min-width="220" />
            <el-table-column label="材料分类" min-width="130">
              <template #default="{ row }">{{ materialCategoryLabel(row.metadata?.material_category) }}</template>
            </el-table-column>
            <el-table-column prop="extension" label="类型" width="80" />
          </el-table>
        </section>
        <section>
          <div class="section-title">审核记录</div>
          <el-table :data="detail.reviews || []" border size="small">
            <el-table-column label="阶段" width="110"><template #default="{ row }">{{ roleLabel(row.stage) }}</template></el-table-column>
            <el-table-column prop="decision" label="结果" width="100" />
            <el-table-column prop="score" label="评分" width="80" />
            <el-table-column label="意见" min-width="220">
              <template #default="{ row }"><div class="rich-content detail-rich-content" v-html="row.comment || '-'" /></template>
            </el-table-column>
            <el-table-column prop="reviewed_at" label="时间" width="170" />
          </el-table>
        </section>
        <section>
          <div class="section-title">延期记录</div>
          <el-table :data="detail.extensions || []" border size="small">
            <el-table-column label="原因" min-width="220">
              <template #default="{ row }"><div class="rich-content detail-rich-content" v-html="row.reason || '-'" /></template>
            </el-table-column>
            <el-table-column prop="expected_date" label="计划日期" width="120" />
            <el-table-column prop="status" label="状态" width="100" />
            <el-table-column label="处理意见" min-width="160">
              <template #default="{ row }"><div class="rich-content detail-rich-content" v-html="row.review_comment || '-'" /></template>
            </el-table-column>
          </el-table>
        </section>
      </div>
    </el-drawer>
  </section>
</template>

<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { ElMessage } from 'element-plus'
import { Plus, Refresh, Upload, View } from '@element-plus/icons-vue'
import { useRoute, useRouter } from 'vue-router'
import { api } from '../api.js'
import { useSessionStore } from '../store.js'
import { useTextStore } from '../texts.js'
import RichTextEditor from '../components/RichTextEditor.vue'

const route = useRoute()
const router = useRouter()
const session = useSessionStore()
const texts = useTextStore()
const loading = ref(false)
const saving = ref(false)
const projectOptionsLoading = ref(false)
const acceptances = ref([])
const projectOptions = ref([])
const keyword = ref('')
const status = ref('')
const scope = ref(defaultScope())
const createVisible = ref(false)
const submitVisible = ref(false)
const reviewVisible = ref(false)
const extensionVisible = ref(false)
const uploadVisible = ref(false)
const detailVisible = ref(false)
const currentAcceptance = ref(null)
const detail = ref(null)
const selectedTimelineKey = ref('')
const createForm = reactive({ project_id: '', summary: '' })
const submitForm = reactive({ summary: '' })
const reviewForm = reactive({ decision: 'approve', score: null, comment: '' })
const extensionForm = reactive({ reason: '', expected_date: '', extension_id: null, decision: 'approved', comment: '' })
const uploadCategory = ref('acceptance_application')
const projectId = ref('')
const e2eFilter = ref('')
const statusLabels = {
  draft: { label: '草稿', type: 'info' },
  submitted: { label: '已提交', type: 'warning' },
  reviewing: { label: '审核中', type: 'primary' },
  returned: { label: '退回修改', type: 'danger' },
  rejected: { label: '已驳回', type: 'danger' },
  approved: { label: '已通过', type: 'success' },
  closed: { label: '已关闭', type: 'info' }
}
const roleLabels = { county: '区县审核', department: '部门审核', expert: '专家评审', admin: '管理员终审' }
const materialCategories = [
  { label: '验收申请书', value: 'acceptance_application' },
  { label: '项目总结', value: 'project_summary' },
  { label: '财务材料', value: 'financial' },
  { label: '成果证明', value: 'achievement' },
  { label: '其他', value: 'other' }
]
const materialCategoryMap = Object.fromEntries(materialCategories.map((item) => [item.value, item.label]))
const showScopeTabs = computed(() => session.can('review_acceptance') || session.can('manage_acceptance'))
const canFilterE2e = computed(() => ['admin', 'super_admin'].includes(session.role))
const selectedTimelineItem = computed(() => detail.value?.timeline?.find((item) => item.key === selectedTimelineKey.value) || detail.value?.timeline?.[0] || null)
const submitRequiredMaterialLabels = computed(() => currentAcceptance.value?.project?.application_batch?.metadata?.acceptance_required_materials?.map((item) => materialCategoryLabel(item)).filter(Boolean) || [])
const requiredMaterialLabels = computed(() => {
  const required = detail.value?.project?.application_batch?.metadata?.acceptance_required_materials || []
  return required.map((item) => materialCategoryLabel(item)).filter(Boolean)
})

function defaultScope() {
  return ['admin', 'super_admin'].includes(session.role) ? 'visible' : 'pending'
}

function statusMeta(value) {
  return statusLabels[value] || { label: value || '-', type: 'info' }
}

function roleLabel(value) {
  return roleLabels[value] || value || '-'
}

function materialCategoryLabel(value) {
  return materialCategoryMap[value] || value || '未分类'
}

function decisionLabel(value) {
  const labels = { submitted: '已提交', approve: '通过', return: '退回修改', reject: '驳回', close: '终审关闭' }
  return labels[value] || value || '-'
}

function timelineStatusLabel(value) {
  return { done: '已完成', current: '当前待处理', pending: '待流转', error: '异常' }[value] || value || '-'
}

function projectOptionLabel(item) {
  const parts = [item.title || `项目 ${item.id}`]
  if (item.unit?.name) parts.push(item.unit.name)
  if (item.batch?.name) parts.push(item.batch.name)
  parts.push(statusMeta(item.status).label)
  return parts.filter(Boolean).join(' / ')
}

async function searchProjects(keyword = '', context = 'acceptance') {
  projectOptionsLoading.value = true
  try {
    const params = new URLSearchParams()
    if (keyword) params.set('keyword', keyword)
    if (context) params.set('context', context)
    params.set('limit', '30')
    projectOptions.value = await api(`/projects/options?${params.toString()}`)
  } finally {
    projectOptionsLoading.value = false
  }
}

function reviewerStage() {
  return session.role === 'super_admin' ? 'admin' : session.role
}

function canSubmit(row) {
  return session.can('submit_acceptance') && ['draft', 'returned'].includes(row.status)
}

function canUpload(row) {
  return session.can('submit_acceptance') && ['draft', 'returned'].includes(row.status)
}

function canReview(row) {
  return (session.can('review_acceptance') || session.can('manage_acceptance')) && row.current_reviewer_role === reviewerStage()
}

function canExtend(row) {
  return session.can('submit_acceptance') || session.can('manage_acceptance')
}

async function loadAcceptances() {
  loading.value = true
  try {
    const params = new URLSearchParams()
    if (keyword.value) params.set('keyword', keyword.value)
    if (status.value) params.set('status', status.value)
    if (projectId.value) params.set('project_id', projectId.value)
    if (canFilterE2e.value && e2eFilter.value !== '') params.set('e2e', e2eFilter.value)
    if (showScopeTabs.value && scope.value) params.set('scope', scope.value)
    const result = await api(`/acceptance${params.toString() ? `?${params.toString()}` : ''}`)
    acceptances.value = result.data || result
  } finally {
    loading.value = false
  }
}

function applyRouteQuery() {
  keyword.value = typeof route.query.keyword === 'string' ? route.query.keyword : ''
  status.value = typeof route.query.status === 'string' ? route.query.status : ''
  projectId.value = typeof route.query.project_id === 'string' ? route.query.project_id : ''
  e2eFilter.value = canFilterE2e.value && typeof route.query.e2e === 'string' ? route.query.e2e : ''
  scope.value = typeof route.query.scope === 'string' ? route.query.scope : defaultScope()
}

async function syncRouteQuery() {
  const query = { ...route.query }
  const setOrDelete = (key, value) => {
    if (value === '' || value === null || value === undefined) delete query[key]
    else query[key] = String(value)
  }

  setOrDelete('keyword', keyword.value)
  setOrDelete('status', status.value)
  setOrDelete('project_id', projectId.value)
  if (canFilterE2e.value) setOrDelete('e2e', e2eFilter.value)
  else delete query.e2e
  if (showScopeTabs.value) setOrDelete('scope', scope.value)
  else delete query.scope

  const current = JSON.stringify(route.query)
  const next = JSON.stringify(query)
  if (current === next) return false

  await router.replace({ path: route.path, query })
  return true
}

async function reloadAcceptances() {
  const routeChanged = await syncRouteQuery()
  if (routeChanged) return
  await loadAcceptances()
}

async function handleScopeChange() {
  await reloadAcceptances()
}

async function createAcceptance() {
  saving.value = true
  try {
    await api(`/projects/${createForm.project_id}/acceptance`, {
      method: 'POST',
      body: JSON.stringify({ summary: createForm.summary, metadata: {} })
    })
    ElMessage.success('验收草稿已创建')
    createVisible.value = false
    Object.assign(createForm, { project_id: '', summary: '' })
    await loadAcceptances()
  } finally {
    saving.value = false
  }
}

function openSubmit(row) {
  currentAcceptance.value = row
  submitForm.summary = row.summary || ''
  submitVisible.value = true
}

async function submitAcceptance() {
  saving.value = true
  try {
    await api(`/acceptance/${currentAcceptance.value.id}/submit`, { method: 'POST', body: JSON.stringify(submitForm) })
    ElMessage.success('验收已提交')
    submitVisible.value = false
    await loadAcceptances()
  } finally {
    saving.value = false
  }
}

function openReview(row) {
  currentAcceptance.value = row
  Object.assign(reviewForm, { decision: 'approve', score: null, comment: '' })
  reviewVisible.value = true
}

async function saveReview() {
  saving.value = true
  try {
    await api(`/acceptance/${currentAcceptance.value.id}/reviews`, { method: 'POST', body: JSON.stringify(reviewForm) })
    ElMessage.success('验收审核已提交')
    reviewVisible.value = false
    await loadAcceptances()
  } finally {
    saving.value = false
  }
}

async function openExtension(row) {
  currentAcceptance.value = row
  detail.value = await api(`/acceptance/${row.id}`)
  Object.assign(extensionForm, { reason: '', expected_date: '', extension_id: detail.value.extensions?.find((item) => item.status === 'pending')?.id || null, decision: 'approved', comment: '' })
  extensionVisible.value = true
}

async function saveExtension() {
  saving.value = true
  try {
    const payload = session.role === 'unit'
      ? { reason: extensionForm.reason, expected_date: extensionForm.expected_date || null }
      : { extension_id: extensionForm.extension_id, decision: extensionForm.decision, comment: extensionForm.comment }
    await api(`/acceptance/${currentAcceptance.value.id}/extensions`, { method: 'POST', body: JSON.stringify(payload) })
    ElMessage.success('延期记录已保存')
    extensionVisible.value = false
    await loadAcceptances()
  } finally {
    saving.value = false
  }
}

function openUpload(row) {
  currentAcceptance.value = row
  uploadCategory.value = 'acceptance_application'
  uploadVisible.value = true
}

async function uploadFile({ file }) {
  const body = new FormData()
  body.append('file', file)
  body.append('purpose', 'acceptance')
  body.append('metadata[material_category]', uploadCategory.value)
  await api(`/acceptance/${currentAcceptance.value.id}/files`, { method: 'POST', body })
  ElMessage.success('验收材料已上传')
  uploadVisible.value = false
}

async function openDetail(row) {
  detail.value = await api(`/acceptance/${row.id}`)
  selectedTimelineKey.value = detail.value.timeline?.find((item) => item.status === 'current')?.key || detail.value.timeline?.find((item) => item.status === 'done')?.key || detail.value.timeline?.[0]?.key || ''
  detailVisible.value = true
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

function timelineStepStatus(item) {
  if (['return', 'reject'].includes(item.decision)) return 'error'
  if (item.status === 'done') return 'success'
  if (item.status === 'current') return 'process'
  return 'wait'
}

onMounted(() => {
  applyRouteQuery()
  loadAcceptances()
  searchProjects()
})

watch(() => route.query, () => {
  applyRouteQuery()
  loadAcceptances()
}, { deep: true })
</script>
