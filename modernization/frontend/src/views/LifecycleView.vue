<template>
  <section class="page-stack">
    <div class="toolbar">
      <div>
        <h2>{{ texts.t('page.lifecycle.title', '全周期管理') }}</h2>
        <span class="muted">{{ texts.t('lifecycle.page.subtitle', '合同任务书、项目实施进展、整改闭环和专家认证') }}</span>
      </div>
      <div class="toolbar-actions">
        <el-input v-model="keyword" clearable :placeholder="texts.t('lifecycle.filter.keyword', '项目/单位/标题')" @keyup.enter="loadActiveTab" />
        <el-select
          v-model="projectId"
          clearable
          filterable
          remote
          reserve-keyword
          :remote-method="searchProjects"
          :loading="projectOptionsLoading"
          :placeholder="texts.t('lifecycle.filter.project', '选择项目')"
          @change="loadActiveTab"
        >
          <el-option v-for="item in projectOptions" :key="item.id" :label="projectOptionLabel(item)" :value="item.id" />
        </el-select>
        <el-select v-model="batchId" clearable :placeholder="texts.t('lifecycle.filter.batch', '申报批次')" @change="loadActiveTab">
          <el-option v-for="batch in batches" :key="batch.id" :label="batch.name" :value="batch.id" />
        </el-select>
        <el-select v-if="session.can('manage_units')" v-model="unitId" clearable filterable remote :remote-method="searchUnits" :placeholder="texts.t('lifecycle.filter.unit', '申报单位')" @change="loadActiveTab">
          <el-option v-for="unit in unitOptions" :key="unit.id" :label="unit.name" :value="unit.id" />
        </el-select>
        <el-select v-model="projectStatus" clearable :placeholder="texts.t('lifecycle.filter.project_status', '项目状态')" @change="loadActiveTab">
          <el-option v-for="item in projectStatusOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
        <el-select v-model="status" clearable :placeholder="texts.t('lifecycle.filter.status', '状态')" @change="loadActiveTab">
          <el-option v-for="item in statusOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
        <el-button :icon="Refresh" :loading="loading" @click="loadActiveTab">{{ texts.t('lifecycle.action.refresh', '刷新') }}</el-button>
      </div>
    </div>

    <el-tabs v-model="activeTab" @tab-change="loadActiveTab">
      <el-tab-pane v-if="canViewTab('task_books')" :label="texts.t('lifecycle.task_books.tab', '合同任务书')" name="task_books">
        <div class="toolbar">
          <span class="muted">{{ texts.t('lifecycle.task_books.tip', '单位填报任务书，管理员审核通过后作为立项后管理依据。') }}</span>
          <el-button v-if="session.can('create_task_books')" type="primary" :icon="Plus" @click="openTaskBook()">{{ texts.t('lifecycle.task_books.create', '新增任务书') }}</el-button>
        </div>
        <el-table :data="taskBooks" border v-loading="loading">
          <el-table-column :label="texts.t('lifecycle.column.project', '项目')" min-width="260">
            <template #default="{ row }">
              <strong>{{ row.project?.title || '-' }}</strong>
              <div class="muted">{{ projectMetaText(row.project) }}</div>
            </template>
          </el-table-column>
          <el-table-column prop="unit.name" :label="texts.t('lifecycle.column.unit', '单位')" min-width="180" />
          <el-table-column prop="title" :label="texts.t('lifecycle.column.task_title', '任务书标题')" min-width="180" />
          <el-table-column :label="texts.t('lifecycle.column.status', '状态')" width="110"><template #default="{ row }"><el-tag :type="statusMeta(row.status).type">{{ statusMeta(row.status).label }}</el-tag></template></el-table-column>
          <el-table-column prop="submitted_at" :label="texts.t('lifecycle.column.submitted_at', '提交时间')" width="170" />
          <el-table-column :label="texts.t('lifecycle.column.actions', '操作')" width="220" fixed="right">
            <template #default="{ row }">
              <div class="table-action-row">
                <el-button size="small" :icon="View" @click="showText(row.title, row.content)">{{ texts.t('lifecycle.action.detail', '详情') }}</el-button>
                <el-button v-if="canEditUnitItem(row, 'update_task_books')" size="small" @click="openTaskBook(row)">{{ texts.t('lifecycle.action.edit', '编辑') }}</el-button>
                <el-button v-if="canEditUnitItem(row, 'submit_task_books')" size="small" type="primary" @click="submitItem('task-books', row)">{{ texts.t('lifecycle.action.submit', '提交') }}</el-button>
                <el-button v-if="session.can('review_task_books') && row.status === 'submitted'" size="small" type="success" @click="reviewItem('task-books', row)">{{ texts.t('lifecycle.action.review', '审核') }}</el-button>
              </div>
            </template>
          </el-table-column>
        </el-table>
      </el-tab-pane>

      <el-tab-pane v-if="canViewTab('progress')" :label="texts.t('lifecycle.progress.tab', '实施进展')" name="progress">
        <div class="toolbar">
          <span class="muted">{{ texts.t('lifecycle.progress.tip', '单位定期提交项目实施情况，管理员确认或退回补正。') }}</span>
          <el-button v-if="session.can('create_project_progress')" type="primary" :icon="Plus" @click="openProgress()">{{ texts.t('lifecycle.progress.create', '新增进展') }}</el-button>
        </div>
        <el-table :data="progressRecords" border v-loading="loading">
          <el-table-column :label="texts.t('lifecycle.column.project', '项目')" min-width="260">
            <template #default="{ row }">
              <strong>{{ row.project?.title || '-' }}</strong>
              <div class="muted">{{ projectMetaText(row.project) }}</div>
            </template>
          </el-table-column>
          <el-table-column prop="unit.name" :label="texts.t('lifecycle.column.unit', '单位')" min-width="180" />
          <el-table-column prop="period" :label="texts.t('lifecycle.column.period', '周期')" width="130" />
          <el-table-column prop="progress_date" :label="texts.t('lifecycle.column.progress_date', '进展日期')" width="130" />
          <el-table-column :label="texts.t('lifecycle.column.status', '状态')" width="110"><template #default="{ row }"><el-tag :type="statusMeta(row.status).type">{{ statusMeta(row.status).label }}</el-tag></template></el-table-column>
          <el-table-column prop="summary" :label="texts.t('lifecycle.column.summary', '进展摘要')" min-width="220" show-overflow-tooltip />
          <el-table-column :label="texts.t('lifecycle.column.actions', '操作')" width="230" fixed="right">
            <template #default="{ row }">
              <div class="table-action-row">
                <el-button size="small" :icon="View" @click="showText(texts.t('lifecycle.progress.tab', '实施进展'), progressText(row))">{{ texts.t('lifecycle.action.detail', '详情') }}</el-button>
                <el-button v-if="canEditUnitItem(row, 'update_project_progress')" size="small" @click="openProgress(row)">{{ texts.t('lifecycle.action.edit', '编辑') }}</el-button>
                <el-button v-if="canEditUnitItem(row, 'submit_project_progress')" size="small" type="primary" @click="submitItem('progress', row)">{{ texts.t('lifecycle.action.submit', '提交') }}</el-button>
                <el-button v-if="session.can('review_project_progress') && row.status === 'submitted'" size="small" type="success" @click="reviewItem('progress', row)">{{ texts.t('lifecycle.action.review', '审核') }}</el-button>
              </div>
            </template>
          </el-table-column>
        </el-table>
      </el-tab-pane>

      <el-tab-pane v-if="canViewTab('rectifications')" :label="texts.t('lifecycle.rectifications.tab', '整改闭环')" name="rectifications">
        <div class="toolbar">
          <span class="muted">{{ texts.t('lifecycle.rectifications.tip', '管理员发起整改要求，单位提交整改说明，管理员审核闭环。') }}</span>
          <el-button v-if="session.can('create_rectifications')" type="primary" :icon="Plus" @click="openRectification()">{{ texts.t('lifecycle.rectifications.create', '发起整改') }}</el-button>
        </div>
        <el-table :data="rectifications" border v-loading="loading">
          <el-table-column :label="texts.t('lifecycle.column.project', '项目')" min-width="260">
            <template #default="{ row }">
              <strong>{{ row.project?.title || '-' }}</strong>
              <div class="muted">{{ projectMetaText(row.project) }}</div>
            </template>
          </el-table-column>
          <el-table-column prop="unit.name" :label="texts.t('lifecycle.column.unit', '单位')" min-width="180" />
          <el-table-column prop="title" :label="texts.t('lifecycle.column.rectification_title', '整改事项')" min-width="180" />
          <el-table-column prop="due_date" :label="texts.t('lifecycle.column.due_date', '截止日期')" width="130" />
          <el-table-column :label="texts.t('lifecycle.column.status', '状态')" width="110"><template #default="{ row }"><el-tag :type="statusMeta(row.status).type">{{ statusMeta(row.status).label }}</el-tag></template></el-table-column>
          <el-table-column :label="texts.t('lifecycle.column.actions', '操作')" width="240" fixed="right">
            <template #default="{ row }">
              <div class="table-action-row">
                <el-button size="small" :icon="View" @click="showText(row.title, rectificationText(row))">{{ texts.t('lifecycle.action.detail', '详情') }}</el-button>
                <el-button v-if="canSubmitRectification(row)" size="small" type="primary" @click="openRectificationResponse(row)">{{ texts.t('lifecycle.rectifications.submit_response', '提交整改') }}</el-button>
                <el-button v-if="session.can('review_rectifications') && row.status === 'submitted'" size="small" type="success" @click="reviewItem('rectifications', row)">{{ texts.t('lifecycle.action.review', '审核') }}</el-button>
              </div>
            </template>
          </el-table-column>
        </el-table>
      </el-tab-pane>

      <el-tab-pane v-if="canViewTab('expert_certifications')" :label="texts.t('lifecycle.certifications.tab', '专家认证')" name="expert_certifications">
        <div class="toolbar">
          <span class="muted">{{ texts.t('lifecycle.certifications.tip', '专家提交专业方向和资质说明，管理员审核后作为专家库基础信息。') }}</span>
          <el-button v-if="session.can('submit_expert_certifications')" type="primary" :icon="Plus" @click="openCertification">{{ texts.t('lifecycle.certifications.create', '提交认证') }}</el-button>
        </div>
        <el-table :data="certifications" border v-loading="loading">
          <el-table-column prop="user.username" :label="texts.t('lifecycle.column.expert_username', '专家账号')" width="140" />
          <el-table-column prop="user.name" :label="texts.t('lifecycle.column.name', '姓名')" width="140" />
          <el-table-column prop="organization" :label="texts.t('lifecycle.column.organization', '单位/机构')" min-width="180" />
          <el-table-column prop="specialty" :label="texts.t('lifecycle.column.specialty', '专业方向')" min-width="180" />
          <el-table-column prop="professional_title" :label="texts.t('lifecycle.column.professional_title', '职称')" width="130" />
          <el-table-column :label="texts.t('lifecycle.column.status', '状态')" width="110"><template #default="{ row }"><el-tag :type="statusMeta(row.status).type">{{ statusMeta(row.status).label }}</el-tag></template></el-table-column>
          <el-table-column :label="texts.t('lifecycle.column.actions', '操作')" width="170" fixed="right">
            <template #default="{ row }">
              <div class="table-action-row">
                <el-button size="small" :icon="View" @click="showText(texts.t('lifecycle.certifications.tab', '专家认证'), certificationText(row))">{{ texts.t('lifecycle.action.detail', '详情') }}</el-button>
                <el-button v-if="session.can('review_expert_certifications') && row.status === 'submitted'" size="small" type="success" @click="reviewItem('expert-certifications', row)">{{ texts.t('lifecycle.action.review', '审核') }}</el-button>
              </div>
            </template>
          </el-table-column>
        </el-table>
      </el-tab-pane>
    </el-tabs>

    <el-dialog v-model="taskBookVisible" :title="taskBookForm.id ? '编辑任务书' : '新增任务书'" width="620px">
      <el-form :model="taskBookForm" label-position="top">
        <el-form-item label="项目">
          <el-select
            v-model="taskBookForm.project_id"
            clearable
            filterable
            remote
            reserve-keyword
            :disabled="Boolean(taskBookForm.id)"
            :remote-method="searchProjects"
            :loading="projectOptionsLoading"
            placeholder="搜索项目名称、单位或批次"
          >
            <el-option v-for="item in projectOptions" :key="item.id" :label="projectOptionLabel(item)" :value="item.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="任务书标题"><el-input v-model="taskBookForm.title" /></el-form-item>
        <el-form-item label="任务书内容"><RichTextEditor v-model="taskBookForm.content" min-height="220px" placeholder="填写任务书内容，可插入图片、列表和链接" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="taskBookVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="saveTaskBook">保存</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="progressVisible" :title="progressForm.id ? '编辑实施进展' : '新增实施进展'" width="620px">
      <el-form :model="progressForm" label-position="top">
        <el-form-item label="项目">
          <el-select
            v-model="progressForm.project_id"
            clearable
            filterable
            remote
            reserve-keyword
            :disabled="Boolean(progressForm.id)"
            :remote-method="searchProjects"
            :loading="projectOptionsLoading"
            placeholder="搜索项目名称、单位或批次"
          >
            <el-option v-for="item in projectOptions" :key="item.id" :label="projectOptionLabel(item)" :value="item.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="周期"><el-input v-model="progressForm.period" placeholder="例如 2026 年第二季度" /></el-form-item>
        <el-form-item label="进展日期"><el-date-picker v-model="progressForm.progress_date" type="date" value-format="YYYY-MM-DD" /></el-form-item>
        <el-form-item label="进展摘要"><RichTextEditor v-model="progressForm.summary" min-height="170px" placeholder="填写阶段进展摘要" /></el-form-item>
        <el-form-item label="存在问题"><RichTextEditor v-model="progressForm.issues" min-height="130px" placeholder="填写存在问题，可留空" /></el-form-item>
        <el-form-item label="下一步计划"><RichTextEditor v-model="progressForm.next_plan" min-height="130px" placeholder="填写下一步计划，可留空" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="progressVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="saveProgress">保存</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="rectificationVisible" title="发起整改要求" width="620px">
      <el-form :model="rectificationForm" label-position="top">
        <el-form-item label="项目">
          <el-select
            v-model="rectificationForm.project_id"
            clearable
            filterable
            remote
            reserve-keyword
            :remote-method="(keyword) => searchProjects(keyword, 'rectification')"
            :loading="projectOptionsLoading"
            placeholder="搜索已通过或验收中项目"
          >
            <el-option v-for="item in projectOptions" :key="item.id" :label="projectOptionLabel(item)" :value="item.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="整改事项"><el-input v-model="rectificationForm.title" /></el-form-item>
        <el-form-item label="整改要求"><RichTextEditor v-model="rectificationForm.requirement" min-height="190px" placeholder="填写整改要求、截止标准和附件要求" /></el-form-item>
        <el-form-item label="截止日期"><el-date-picker v-model="rectificationForm.due_date" type="date" value-format="YYYY-MM-DD" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="rectificationVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="saveRectification">保存</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="rectificationResponseVisible" title="提交整改材料" width="620px">
      <el-form :model="rectificationResponseForm" label-position="top">
        <el-form-item label="整改说明"><RichTextEditor v-model="rectificationResponseForm.response" min-height="220px" placeholder="填写整改完成情况和证明说明" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="rectificationResponseVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="submitRectificationResponse">提交</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="certificationVisible" title="提交专家认证" width="620px">
      <el-form :model="certificationForm" label-position="top">
        <el-form-item label="单位/机构"><el-input v-model="certificationForm.organization" /></el-form-item>
        <el-form-item label="专业方向"><el-input v-model="certificationForm.specialty" /></el-form-item>
        <el-form-item label="职称"><el-input v-model="certificationForm.professional_title" /></el-form-item>
        <el-form-item label="证书编号"><el-input v-model="certificationForm.certificate_no" /></el-form-item>
        <el-form-item label="资质说明"><RichTextEditor v-model="certificationForm.summary" min-height="190px" placeholder="填写专家资质说明和相关经历" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="certificationVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="saveCertification">提交</el-button>
      </template>
    </el-dialog>

    <el-drawer v-model="detailVisible" :title="detailTitle" size="560px">
      <div class="rich-content detail-rich-content" v-html="detailText || '-'" />
    </el-drawer>

    <el-dialog v-model="reviewVisible" title="审核处理" width="520px">
      <el-form :model="reviewForm" label-position="top">
        <el-form-item label="审核结果">
          <el-radio-group v-model="reviewForm.decision">
            <el-radio-button label="approve">通过</el-radio-button>
            <el-radio-button label="return">退回修改</el-radio-button>
            <el-radio-button label="reject">驳回</el-radio-button>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="审核意见">
          <RichTextEditor v-model="reviewForm.comment" min-height="160px" placeholder="请填写审核意见，退回或驳回时建议写明原因" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="reviewVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="saveReview">提交审核</el-button>
      </template>
    </el-dialog>
  </section>
</template>

<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { ElMessage } from 'element-plus'
import { Plus, Refresh, View } from '@element-plus/icons-vue'
import { useRoute } from 'vue-router'
import { api } from '../api.js'
import { useSessionStore } from '../store.js'
import { useTextStore } from '../texts.js'
import RichTextEditor from '../components/RichTextEditor.vue'

const route = useRoute()
const session = useSessionStore()
const texts = useTextStore()
const activeTab = ref('task_books')
const keyword = ref('')
const status = ref('')
const projectId = ref('')
const batchId = ref('')
const unitId = ref('')
const projectStatus = ref('')
const loading = ref(false)
const saving = ref(false)
const projectOptionsLoading = ref(false)
const taskBooks = ref([])
const progressRecords = ref([])
const rectifications = ref([])
const certifications = ref([])
const projectOptions = ref([])
const batches = ref([])
const unitOptions = ref([])
const taskBookVisible = ref(false)
const progressVisible = ref(false)
const rectificationVisible = ref(false)
const rectificationResponseVisible = ref(false)
const certificationVisible = ref(false)
const detailVisible = ref(false)
const reviewVisible = ref(false)
const detailTitle = ref('')
const detailText = ref('')
const currentRectification = ref(null)
const reviewTarget = ref({ resource: '', id: null })
const taskBookForm = reactive({ id: null, project_id: '', title: '', content: '' })
const progressForm = reactive({ id: null, project_id: '', period: '', progress_date: '', summary: '', issues: '', next_plan: '' })
const rectificationForm = reactive({ project_id: '', title: '', requirement: '', due_date: '' })
const rectificationResponseForm = reactive({ response: '' })
const certificationForm = reactive({ organization: '', specialty: '', professional_title: '', certificate_no: '', summary: '' })
const reviewForm = reactive({ decision: 'approve', comment: '' })
const statusOptions = [
  { label: '草稿', value: 'draft' },
  { label: '待提交', value: 'pending' },
  { label: '已提交', value: 'submitted' },
  { label: '退回修改', value: 'returned' },
  { label: '已通过', value: 'approved' },
  { label: '已驳回', value: 'rejected' }
]
const projectStatusOptions = [
  { label: '草稿', value: 'draft' },
  { label: '已提交', value: 'submitted' },
  { label: '退回修改', value: 'returned' },
  { label: '审核中', value: 'reviewing' },
  { label: '已通过', value: 'approved' },
  { label: '验收中', value: 'acceptance' },
  { label: '已关闭', value: 'closed' },
  { label: '已驳回', value: 'rejected' }
]
const statusLabels = {
  draft: { label: '草稿', type: 'info' },
  pending: { label: '待提交', type: 'warning' },
  submitted: { label: '已提交', type: 'primary' },
  returned: { label: '退回修改', type: 'danger' },
  approved: { label: '已通过', type: 'success' },
  rejected: { label: '已驳回', type: 'danger' }
}
const tabPermissions = {
  task_books: 'view_task_books',
  progress: 'view_project_progress',
  rectifications: 'view_rectifications',
  expert_certifications: 'view_expert_certifications'
}
const availableTabs = computed(() => Object.keys(tabPermissions).filter(canViewTab))

function statusMeta(value) {
  return statusLabels[value] || { label: value || '-', type: 'info' }
}

function canViewTab(tab) {
  return session.can(tabPermissions[tab])
}

function query() {
  const params = new URLSearchParams()
  if (keyword.value) params.set('keyword', keyword.value)
  if (status.value) params.set('status', status.value)
  if (projectId.value) params.set('project_id', projectId.value)
  if (batchId.value) params.set('batch_id', batchId.value)
  if (unitId.value) params.set('unit_id', unitId.value)
  if (projectStatus.value) params.set('project_status', projectStatus.value)
  return params.toString() ? `?${params.toString()}` : ''
}

function projectOptionLabel(item) {
  const parts = [item.title || `项目 ${item.id}`]
  if (item.unit?.name) parts.push(item.unit.name)
  if (item.batch?.name) parts.push(item.batch.name)
  parts.push(statusMeta(item.status).label)
  return parts.filter(Boolean).join(' / ')
}

function projectMetaText(project) {
  const parts = []
  if (project?.application_batch?.name) parts.push(`批次：${project.application_batch.name}`)
  if (project?.status) parts.push(`状态：${statusMeta(project.status).label}`)
  return parts.join('；') || '-'
}

async function searchProjects(keyword = '', context = '') {
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

async function ensureProjectOption(id) {
  if (!id || projectOptions.value.some((item) => String(item.id) === String(id))) return
  const params = new URLSearchParams({ keyword: String(id), limit: '1' })
  const options = await api(`/projects/options?${params.toString()}`)
  projectOptions.value = [...options, ...projectOptions.value].filter((item, index, arr) => arr.findIndex((other) => String(other.id) === String(item.id)) === index)
}

async function loadBatches() {
  try {
    const result = await api('/application-batches')
    batches.value = result.data || result
  } catch {
    batches.value = await api('/public/application-batches/open')
  }
}

async function searchUnits(keyword = '') {
  if (!session.can('manage_units')) return
  const params = new URLSearchParams()
  if (keyword) params.set('keyword', keyword)
  const result = await api(`/units${params.toString() ? `?${params.toString()}` : ''}`)
  unitOptions.value = result.data || result
}

async function applyRouteQuery() {
  const routeProjectId = Array.isArray(route.query.project_id) ? route.query.project_id[0] : route.query.project_id
  projectId.value = routeProjectId ? Number(routeProjectId) : ''
  if (projectId.value) await ensureProjectOption(projectId.value)
}

async function loadActiveTab() {
  if (!canViewTab(activeTab.value)) {
    activeTab.value = availableTabs.value[0] || 'task_books'
  }

  if (!canViewTab(activeTab.value)) return null

  if (activeTab.value === 'task_books') return loadTaskBooks()
  if (activeTab.value === 'progress') return loadProgress()
  if (activeTab.value === 'rectifications') return loadRectifications()
  return loadCertifications()
}

async function loadTaskBooks() {
  loading.value = true
  try {
    const result = await api(`/lifecycle/task-books${query()}`)
    taskBooks.value = result.data || result
  } finally {
    loading.value = false
  }
}

async function loadProgress() {
  loading.value = true
  try {
    const result = await api(`/lifecycle/progress${query()}`)
    progressRecords.value = result.data || result
  } finally {
    loading.value = false
  }
}

async function loadRectifications() {
  loading.value = true
  try {
    const result = await api(`/lifecycle/rectifications${query()}`)
    rectifications.value = result.data || result
  } finally {
    loading.value = false
  }
}

async function loadCertifications() {
  loading.value = true
  try {
    const result = await api(`/lifecycle/expert-certifications${query()}`)
    certifications.value = result.data || result
  } finally {
    loading.value = false
  }
}

function canEditUnitItem(row, permission) {
  return session.can(permission) && ['draft', 'returned'].includes(row.status)
}

function canSubmitRectification(row) {
  return session.can('submit_rectifications') && ['pending', 'returned'].includes(row.status)
}

function openTaskBook(row = null) {
  Object.assign(taskBookForm, row
    ? { id: row.id, project_id: row.project_id, title: row.title || '', content: row.content || '' }
    : { id: null, project_id: '', title: '', content: '' })
  if (row?.project) {
    projectOptions.value = [row.project, ...projectOptions.value].filter((item, index, arr) => arr.findIndex((other) => other.id === item.id) === index)
  } else {
    searchProjects()
  }
  taskBookVisible.value = true
}

async function saveTaskBook() {
  saving.value = true
  try {
    const path = taskBookForm.id ? `/lifecycle/task-books/${taskBookForm.id}` : `/projects/${taskBookForm.project_id}/task-books`
    const method = taskBookForm.id ? 'PUT' : 'POST'
    await api(path, { method, body: JSON.stringify({ title: taskBookForm.title, content: taskBookForm.content }) })
    ElMessage.success('任务书已保存')
    taskBookVisible.value = false
    await loadTaskBooks()
  } finally {
    saving.value = false
  }
}

function openProgress(row = null) {
  Object.assign(progressForm, row
    ? { id: row.id, project_id: row.project_id, period: row.period || '', progress_date: row.progress_date || '', summary: row.summary || '', issues: row.issues || '', next_plan: row.next_plan || '' }
    : { id: null, project_id: '', period: '', progress_date: '', summary: '', issues: '', next_plan: '' })
  if (row?.project) {
    projectOptions.value = [row.project, ...projectOptions.value].filter((item, index, arr) => arr.findIndex((other) => other.id === item.id) === index)
  } else {
    searchProjects()
  }
  progressVisible.value = true
}

async function saveProgress() {
  saving.value = true
  try {
    const path = progressForm.id ? `/lifecycle/progress/${progressForm.id}` : `/projects/${progressForm.project_id}/progress`
    const method = progressForm.id ? 'PUT' : 'POST'
    await api(path, {
      method,
      body: JSON.stringify({
        period: progressForm.period,
        progress_date: progressForm.progress_date || null,
        summary: progressForm.summary,
        issues: progressForm.issues,
        next_plan: progressForm.next_plan
      })
    })
    ElMessage.success('实施进展已保存')
    progressVisible.value = false
    await loadProgress()
  } finally {
    saving.value = false
  }
}

function openRectification() {
  Object.assign(rectificationForm, { project_id: '', title: '', requirement: '', due_date: '' })
  searchProjects('', 'rectification')
  rectificationVisible.value = true
}

async function saveRectification() {
  saving.value = true
  try {
    await api(`/projects/${rectificationForm.project_id}/rectifications`, {
      method: 'POST',
      body: JSON.stringify({
        title: rectificationForm.title,
        requirement: rectificationForm.requirement,
        due_date: rectificationForm.due_date || null
      })
    })
    ElMessage.success('整改要求已创建')
    rectificationVisible.value = false
    await loadRectifications()
  } finally {
    saving.value = false
  }
}

function openRectificationResponse(row) {
  currentRectification.value = row
  rectificationResponseForm.response = row.response || ''
  rectificationResponseVisible.value = true
}

async function submitRectificationResponse() {
  if (!currentRectification.value) return
  saving.value = true
  try {
    await api(`/lifecycle/rectifications/${currentRectification.value.id}/submit`, {
      method: 'POST',
      body: JSON.stringify(rectificationResponseForm)
    })
    ElMessage.success('整改材料已提交')
    rectificationResponseVisible.value = false
    await loadRectifications()
  } finally {
    saving.value = false
  }
}

function openCertification() {
  Object.assign(certificationForm, { organization: '', specialty: '', professional_title: '', certificate_no: '', summary: '' })
  certificationVisible.value = true
}

async function saveCertification() {
  saving.value = true
  try {
    await api('/lifecycle/expert-certifications', { method: 'POST', body: JSON.stringify(certificationForm) })
    ElMessage.success('专家认证已提交')
    certificationVisible.value = false
    await loadCertifications()
  } finally {
    saving.value = false
  }
}

async function submitItem(resource, row) {
  await api(`/lifecycle/${resource}/${row.id}/submit`, { method: 'POST' })
  ElMessage.success('已提交')
  await loadActiveTab()
}

async function reviewItem(resource, row) {
  reviewTarget.value = { resource, id: row.id }
  Object.assign(reviewForm, { decision: 'approve', comment: row.review_comment || '' })
  reviewVisible.value = true
}

async function saveReview() {
  if (!reviewTarget.value.id) return

  await api(`/lifecycle/${reviewTarget.value.resource}/${reviewTarget.value.id}/review`, {
    method: 'POST',
    body: JSON.stringify(reviewForm)
  })
  ElMessage.success('审核已提交')
  reviewVisible.value = false
  await loadActiveTab()
}

function showText(title, text) {
  detailTitle.value = title
  detailText.value = text || '-'
  detailVisible.value = true
}

function progressText(row) {
  return [
    plainLine('周期', row.period),
    plainLine('进展日期', row.progress_date),
    richSection('进展摘要', row.summary),
    richSection('存在问题', row.issues),
    richSection('下一步计划', row.next_plan),
    richSection('审核意见', row.review_comment)
  ].join('')
}

function rectificationText(row) {
  return [
    richSection('整改要求', row.requirement),
    richSection('整改说明', row.response),
    richSection('审核意见', row.review_comment)
  ].join('')
}

function certificationText(row) {
  return [
    plainLine('机构', row.organization),
    plainLine('专业方向', row.specialty),
    plainLine('职称', row.professional_title),
    plainLine('证书编号', row.certificate_no),
    richSection('资质说明', row.summary),
    richSection('审核意见', row.review_comment)
  ].join('')
}

function plainLine(label, value) {
  return `<p><strong>${escapeHtml(label)}：</strong>${escapeHtml(value || '-')}</p>`
}

function richSection(label, value) {
  return `<section class="detail-rich-section"><h4>${escapeHtml(label)}</h4>${value || '<p>-</p>'}</section>`
}

function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;')
}

onMounted(async () => {
  activeTab.value = availableTabs.value[0] || activeTab.value
  await Promise.all([loadBatches(), searchProjects(), searchUnits()])
  await applyRouteQuery()
  loadActiveTab()
})

watch(() => route.query.project_id, async () => {
  await applyRouteQuery()
  loadActiveTab()
})
</script>
