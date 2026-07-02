<template>
  <section class="page-stack">
    <el-tabs v-model="activeTab" @tab-change="handleTabChange">
      <el-tab-pane label="待审核" name="tasks">
        <div class="page-stack">
          <div class="toolbar">
            <el-input v-model="keyword" clearable placeholder="按项目、单位、账号搜索" @keyup.enter="reloadTasks" />
            <div class="toolbar-actions">
              <el-select v-model="category" clearable placeholder="类别" @change="reloadTasks">
                <el-option v-for="item in projectCategoryOptions" :key="item.code" :label="item.label" :value="item.label" />
              </el-select>
              <el-select v-model="projectType" clearable placeholder="类型" @change="reloadTasks">
                <el-option v-for="item in projectTypeOptions" :key="item.code" :label="item.label" :value="item.label" />
              </el-select>
              <el-tooltip content="查询审核任务" placement="top">
                <el-button type="primary" :icon="Search" circle @click="reloadTasks" />
              </el-tooltip>
              <el-button v-if="route.query.project_id" :icon="Close" @click="clearRouteProjectFilter()">清除项目筛选</el-button>
              <el-tooltip content="导出当前审核任务" placement="top">
                <el-button :icon="Download" @click="exportTasks">导出</el-button>
              </el-tooltip>
              <el-tooltip content="刷新审核任务" placement="top">
                <el-button :icon="Refresh" circle @click="loadTasks" />
              </el-tooltip>
            </div>
          </div>

          <el-table :data="tasks" border v-loading="loading">
            <el-table-column type="index" label="序号" width="72" align="center" :index="tableIndex" fixed="left" />
            <el-table-column prop="title" label="项目名称" min-width="220" />
            <el-table-column prop="unit.name" label="申报单位" min-width="180" />
            <el-table-column label="当前阶段" width="130">
              <template #default="{ row }">{{ roleLabel(row.current_reviewer_role) }}</template>
            </el-table-column>
            <el-table-column label="派单提示" min-width="220">
              <template #default="{ row }">
                <template v-if="row.dispatch_assignment">
                  <el-tag :type="row.dispatch_assignment.auto_assign ? 'warning' : 'info'">
                    {{ row.dispatch_assignment.auto_assign ? '自动派单' : '推荐派单' }}
                  </el-tag>
                  <span class="dispatch-users">{{ dispatchUserNames(row.dispatch_assignment) }}</span>
                </template>
                <span v-else>-</span>
              </template>
            </el-table-column>
            <el-table-column label="状态" width="120">
              <template #default="{ row }">
                <el-tag :type="statusMeta(row.status).type">{{ statusMeta(row.status).label }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="submitted_at" label="提交时间" width="180" />
            <el-table-column label="操作" width="190" fixed="right">
              <template #default="{ row }">
                <div class="table-action-row">
                  <el-button size="small" :icon="View" @click="openDetail(row)">详情</el-button>
                  <el-button size="small" type="primary" :icon="Checked" @click="openReview(row)">审核处理</el-button>
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
        </div>
      </el-tab-pane>

      <el-tab-pane label="审核结果" name="results">
        <div class="page-stack">
          <div class="toolbar">
            <el-input v-model="resultKeyword" clearable placeholder="按项目、单位、账号、意见搜索" @keyup.enter="reloadResults" />
            <div class="toolbar-actions">
              <el-select v-if="isAdminRole" v-model="resultStage" clearable placeholder="阶段" @change="reloadResults">
                <el-option v-for="item in stageOptions" :key="item.value" :label="item.label" :value="item.value" />
              </el-select>
              <el-select v-model="resultDecision" clearable placeholder="结果" @change="reloadResults">
                <el-option v-for="item in allDecisionOptions" :key="item.value" :label="item.label" :value="item.value" />
              </el-select>
              <el-select v-model="resultCategory" clearable placeholder="类别" @change="reloadResults">
                <el-option v-for="item in projectCategoryOptions" :key="item.code" :label="item.label" :value="item.label" />
              </el-select>
              <el-select v-model="resultProjectType" clearable placeholder="类型" @change="reloadResults">
                <el-option v-for="item in projectTypeOptions" :key="item.code" :label="item.label" :value="item.label" />
              </el-select>
              <el-input-number v-model="resultScoreMin" :min="0" :max="100" :precision="1" controls-position="right" placeholder="最低分" class="score-filter" @change="reloadResults" />
              <el-input-number v-model="resultScoreMax" :min="0" :max="100" :precision="1" controls-position="right" placeholder="最高分" class="score-filter" @change="reloadResults" />
              <el-tooltip content="查询审核结果" placement="top">
                <el-button type="primary" :icon="Search" circle @click="reloadResults" />
              </el-tooltip>
              <el-button v-if="route.query.project_id" :icon="Close" @click="clearRouteProjectFilter()">清除项目筛选</el-button>
              <el-tooltip content="导出审核结果" placement="top">
                <el-button :icon="Download" @click="exportResults">导出</el-button>
              </el-tooltip>
              <el-tooltip content="刷新审核结果" placement="top">
                <el-button :icon="Refresh" circle @click="loadResults" />
              </el-tooltip>
            </div>
          </div>

          <el-table :data="results" border v-loading="resultsLoading">
            <el-table-column type="index" label="序号" width="72" align="center" :index="resultTableIndex" fixed="left" />
            <el-table-column prop="project.title" label="项目名称" min-width="220" />
            <el-table-column prop="project.unit.name" label="申报单位" min-width="180" />
            <el-table-column label="阶段" width="120">
              <template #default="{ row }">{{ roleLabel(row.stage) }}</template>
            </el-table-column>
            <el-table-column label="结果" width="110">
              <template #default="{ row }">{{ decisionLabel(row.decision) }}</template>
            </el-table-column>
            <el-table-column prop="reviewer.username" label="审核人" width="130" />
            <el-table-column prop="score" label="评分" width="90" />
            <el-table-column label="评分明细" min-width="240">
              <template #default="{ row }">{{ formatCriteriaScores(row) }}</template>
            </el-table-column>
            <el-table-column prop="comment" label="意见" min-width="220" />
            <el-table-column prop="reviewed_at" label="审核时间" width="180" />
            <el-table-column label="操作" width="100" fixed="right">
              <template #default="{ row }">
                <el-button size="small" :icon="View" @click="openDetail(row.project)">详情</el-button>
              </template>
            </el-table-column>
          </el-table>

          <el-pagination
            v-if="resultPagination.total > resultPagination.per_page"
            background
            layout="prev, pager, next, total"
            :current-page="resultPagination.current_page"
            :page-size="resultPagination.per_page"
            :total="resultPagination.total"
            @current-change="changeResultPage"
          />
        </div>
      </el-tab-pane>
    </el-tabs>

    <el-dialog v-model="reviewVisible" title="审核处理" :width="useCriteriaScoring ? '920px' : '720px'">
      <el-alert
        v-if="currentProject?.next_step"
        type="info"
        :closable="false"
        show-icon
        :title="currentProject.next_step.title"
        :description="currentProject.next_step.body"
        class="dialog-alert"
      />
      <el-collapse class="dialog-project-detail">
        <el-collapse-item title="项目详情和申报材料" name="project">
          <el-descriptions v-if="currentProject" :column="2" border size="small">
            <el-descriptions-item label="项目名称" :span="2">{{ currentProject.title }}</el-descriptions-item>
            <el-descriptions-item label="申报单位">{{ currentProject.unit?.name || '-' }}</el-descriptions-item>
            <el-descriptions-item label="申报批次">{{ currentProject.application_batch?.name || '-' }}</el-descriptions-item>
            <el-descriptions-item label="项目类别">{{ currentProject.category || '-' }}</el-descriptions-item>
            <el-descriptions-item label="项目类型">{{ currentProject.project_type || '-' }}</el-descriptions-item>
            <el-descriptions-item label="预算金额">{{ formatCurrency(currentProject.budget_amount) }}</el-descriptions-item>
            <el-descriptions-item label="归口管理单位">{{ currentProject.metadata?.management_unit || '-' }}</el-descriptions-item>
            <el-descriptions-item label="所属领域">{{ currentProject.metadata?.field || '-' }}</el-descriptions-item>
            <el-descriptions-item label="研究方向">{{ currentProject.metadata?.research_direction || '-' }}</el-descriptions-item>
            <el-descriptions-item label="项目摘要" :span="2"><div class="rich-content detail-rich-content" v-html="currentProject.summary || '-'" /></el-descriptions-item>
            <el-descriptions-item v-if="currentProject.metadata?.overview" label="项目概述" :span="2"><div class="rich-content detail-rich-content" v-html="currentProject.metadata.overview" /></el-descriptions-item>
            <el-descriptions-item v-if="currentProject.metadata?.objectives" label="目标任务" :span="2"><div class="rich-content detail-rich-content" v-html="currentProject.metadata.objectives" /></el-descriptions-item>
            <el-descriptions-item v-if="currentProject.metadata?.innovation" label="创新点" :span="2"><div class="rich-content detail-rich-content" v-html="currentProject.metadata.innovation" /></el-descriptions-item>
          </el-descriptions>
          <el-table :data="currentProject?.files || []" border size="small" class="dialog-files-table">
            <el-table-column prop="original_name" label="附件" min-width="220" />
            <el-table-column prop="extension" label="类型" width="80" />
            <el-table-column label="操作" width="80" align="center">
              <template #default="{ row }">
                <el-button size="small" :icon="Download" circle @click="downloadFile(row)" />
              </template>
            </el-table-column>
          </el-table>
        </el-collapse-item>
      </el-collapse>
      <el-form :model="reviewForm" label-position="top">
        <el-form-item label="审核结果">
          <el-radio-group v-model="reviewForm.decision">
            <el-radio-button v-for="item in decisionOptions" :key="item.value" :label="item.value">{{ item.label }}</el-radio-button>
          </el-radio-group>
        </el-form-item>
        <template v-if="useCriteriaScoring">
          <el-form-item label="专家评分">
            <div class="criteria-panel">
              <div v-for="group in groupedReviewCriteria" :key="group.section" class="criteria-group">
                <div class="criteria-group-title">
                  <strong>{{ group.section }}</strong>
                  <span>满分 {{ group.maxScore }} 分</span>
                </div>
                <el-table :data="group.items" border size="small">
                  <el-table-column prop="label" label="评分项" min-width="260">
                    <template #default="{ row }">
                      <div>{{ row.label }}</div>
                      <small v-if="row.description">{{ row.description }}</small>
                    </template>
                  </el-table-column>
                  <el-table-column prop="max_score" label="满分" width="80" />
                  <el-table-column label="得分" width="150">
                    <template #default="{ row }">
                      <el-input-number
                        v-model="reviewForm.criteria_scores[row.code]"
                        :min="0"
                        :max="Number(row.max_score || 0)"
                        :precision="1"
                        controls-position="right"
                        @change="syncCriteriaScore"
                      />
                    </template>
                  </el-table-column>
                </el-table>
              </div>
              <div class="criteria-total">合计：{{ reviewCriteriaScoreTotal }} / {{ reviewCriteriaMaxTotal }} 分</div>
            </div>
          </el-form-item>
        </template>
        <el-form-item v-else-if="showNumericScore" label="评分">
          <el-input-number v-model="reviewForm.score" :min="0" :max="100" :precision="1" />
        </el-form-item>
        <div v-if="useFinalSupportForm" class="final-support-panel">
          <div class="section-title">终审支持信息</div>
          <el-form-item label="是否推荐">
            <el-switch v-model="reviewForm.final_support.is_recommended" active-text="推荐" inactive-text="不推荐" />
          </el-form-item>
          <el-form-item label="是否支持">
            <el-switch v-model="reviewForm.final_support.is_supported" active-text="支持" inactive-text="不支持" @change="syncFinalSupportState" />
          </el-form-item>
          <div v-if="reviewForm.final_support.is_supported" class="support-amount-grid">
            <el-form-item label="补助支持金额（万元）">
              <el-input-number v-model="reviewForm.final_support.subsidy_amount_wan" :min="0" :precision="2" controls-position="right" />
            </el-form-item>
            <el-form-item label="贴息支持金额（万元）">
              <el-input-number v-model="reviewForm.final_support.interest_amount_wan" :min="0" :precision="2" controls-position="right" />
            </el-form-item>
            <el-form-item label="其他支持金额（万元）">
              <el-input-number v-model="reviewForm.final_support.other_amount_wan" :min="0" :precision="2" controls-position="right" />
            </el-form-item>
            <el-form-item label="其他支持说明">
              <el-input v-model="reviewForm.final_support.other_support_note" />
            </el-form-item>
          </div>
          <el-form-item label="专家评分汇总">
            <el-input :model-value="expertSummaryText(currentProject)" readonly />
          </el-form-item>
        </div>
        <el-form-item label="审核意见">
          <RichTextEditor v-model="reviewForm.comment" min-height="170px" placeholder="填写审核意见，可插入图片、列表和链接" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="reviewVisible = false">取消</el-button>
        <el-button type="primary" :loading="submitting" @click="submitReview">提交审核</el-button>
      </template>
    </el-dialog>

    <el-drawer v-model="detailVisible" title="审核项目详情" size="860px">
      <div v-if="detail" class="detail-stack">
        <el-alert
          v-if="detail.next_step"
          type="info"
          :closable="false"
          show-icon
          :title="detail.next_step.title"
          :description="detail.next_step.body"
        />
        <el-descriptions :column="2" border>
          <el-descriptions-item label="项目名称" :span="2">{{ detail.title }}</el-descriptions-item>
          <el-descriptions-item label="申报单位">{{ detail.unit?.name || '-' }}</el-descriptions-item>
          <el-descriptions-item label="申报批次">{{ detail.application_batch?.name || '-' }}</el-descriptions-item>
          <el-descriptions-item label="当前阶段">{{ roleLabel(detail.current_reviewer_role) }}</el-descriptions-item>
          <el-descriptions-item label="项目类别">{{ detail.category || '-' }}</el-descriptions-item>
          <el-descriptions-item label="项目类型">{{ detail.project_type || '-' }}</el-descriptions-item>
          <el-descriptions-item label="预算金额">{{ formatCurrency(detail.budget_amount) }}</el-descriptions-item>
          <el-descriptions-item label="归口管理单位">{{ detail.metadata?.management_unit || '-' }}</el-descriptions-item>
          <el-descriptions-item label="所属领域">{{ detail.metadata?.field || '-' }}</el-descriptions-item>
          <el-descriptions-item label="研究方向">{{ detail.metadata?.research_direction || '-' }}</el-descriptions-item>
          <el-descriptions-item label="是否支持">{{ finalSupportText(detail).isSupported }}</el-descriptions-item>
          <el-descriptions-item label="支持资金">{{ finalSupportText(detail).supportAmount }}</el-descriptions-item>
          <el-descriptions-item label="推荐专家" :span="2">{{ finalSupportText(detail).recommendedExperts }}</el-descriptions-item>
          <el-descriptions-item label="摘要" :span="2"><div class="rich-content detail-rich-content" v-html="detail.summary || '-'" /></el-descriptions-item>
          <el-descriptions-item v-if="detail.metadata?.overview" label="项目概述" :span="2"><div class="rich-content detail-rich-content" v-html="detail.metadata.overview" /></el-descriptions-item>
          <el-descriptions-item v-if="detail.metadata?.objectives" label="目标任务" :span="2"><div class="rich-content detail-rich-content" v-html="detail.metadata.objectives" /></el-descriptions-item>
          <el-descriptions-item v-if="detail.metadata?.innovation" label="创新点" :span="2"><div class="rich-content detail-rich-content" v-html="detail.metadata.innovation" /></el-descriptions-item>
        </el-descriptions>

        <section v-if="detail.expert_review_summary">
          <div class="section-title">专家评分汇总</div>
          <el-descriptions :column="4" border size="small">
            <el-descriptions-item label="分配专家">{{ detail.expert_review_summary.assigned_count || 0 }}</el-descriptions-item>
            <el-descriptions-item label="已评分">{{ detail.expert_review_summary.reviewed_count || 0 }}</el-descriptions-item>
            <el-descriptions-item label="平均分">{{ detail.expert_review_summary.average_score ?? '-' }}</el-descriptions-item>
            <el-descriptions-item label="最高/最低">{{ detail.expert_review_summary.max_score ?? '-' }} / {{ detail.expert_review_summary.min_score ?? '-' }}</el-descriptions-item>
          </el-descriptions>
        </section>

        <section>
          <div class="section-title">附件</div>
          <el-table :data="detail.files || []" border size="small">
            <el-table-column prop="original_name" label="文件名" min-width="220" />
            <el-table-column prop="extension" label="类型" width="80" />
            <el-table-column prop="size_bytes" label="大小" width="110">
              <template #default="{ row }">{{ formatBytes(row.size_bytes) }}</template>
            </el-table-column>
            <el-table-column label="操作" width="112" align="center">
              <template #default="{ row }">
                <el-tooltip content="下载" placement="top">
                  <el-button size="small" :icon="Download" circle @click="downloadFile(row)" />
                </el-tooltip>
                <el-tooltip v-if="session.can('view_operation_logs')" content="查看附件日志" placement="top">
                  <el-button size="small" :icon="Files" circle @click="openFileLogs(row)" />
                </el-tooltip>
              </template>
            </el-table-column>
          </el-table>
        </section>

        <section>
          <div class="section-title">审核记录</div>
          <el-table :data="detail.reviews || []" border size="small">
            <el-table-column label="阶段" width="110">
              <template #default="{ row }">{{ roleLabel(row.stage) }}</template>
            </el-table-column>
            <el-table-column label="结果" width="110">
              <template #default="{ row }">{{ decisionLabel(row.decision) }}</template>
            </el-table-column>
            <el-table-column prop="score" label="评分" width="90" />
            <el-table-column label="评分明细" min-width="240">
              <template #default="{ row }">{{ formatCriteriaScores(row) }}</template>
            </el-table-column>
            <el-table-column label="意见" min-width="220">
              <template #default="{ row }"><div class="rich-content detail-rich-content" v-html="row.comment || '-'" /></template>
            </el-table-column>
            <el-table-column prop="reviewed_at" label="时间" width="170" />
          </el-table>
        </section>

        <section v-if="detail.extension_records?.length">
          <div class="section-title">延期记录</div>
          <el-table :data="detail.extension_records" border size="small">
            <el-table-column label="来源" width="90">
              <template #default="{ row }">{{ row.source === 'acceptance' ? '验收' : '项目' }}</template>
            </el-table-column>
            <el-table-column prop="status" label="状态" width="100" />
            <el-table-column prop="reason" label="原因" min-width="220">
              <template #default="{ row }"><div class="rich-content detail-rich-content" v-html="row.reason || '-'" /></template>
            </el-table-column>
            <el-table-column prop="expected_date" label="计划完成" width="120" />
            <el-table-column prop="requested_at" label="申请时间" width="170" />
            <el-table-column prop="review_comment" label="处理意见" min-width="180">
              <template #default="{ row }"><div class="rich-content detail-rich-content" v-html="row.review_comment || '-'" /></template>
            </el-table-column>
          </el-table>
        </section>
      </div>
    </el-drawer>
  </section>
</template>

<script setup>
import { computed, onMounted, onUnmounted, reactive, ref, watch } from 'vue'
import { ElMessage } from 'element-plus'
import { Checked, Close, Download, Files, Refresh, Search, View } from '@element-plus/icons-vue'
import { useRoute, useRouter } from 'vue-router'
import { api, downloadApi } from '../api.js'
import { useSessionStore } from '../store.js'
import RichTextEditor from '../components/RichTextEditor.vue'

const route = useRoute()
const router = useRouter()
const session = useSessionStore()
const activeTab = ref('tasks')
const loading = ref(false)
const resultsLoading = ref(false)
const submitting = ref(false)
const tasks = ref([])
const results = ref([])
const projectTypeOptions = ref([])
const projectCategoryOptions = ref([])
const reviewCriteriaOptions = ref([])
const keyword = ref('')
const category = ref('')
const projectType = ref('')
const resultKeyword = ref('')
const resultStage = ref('')
const resultDecision = ref('')
const resultCategory = ref('')
const resultProjectType = ref('')
const resultScoreMin = ref(null)
const resultScoreMax = ref(null)
const isAdminRole = computed(() => ['admin', 'super_admin'].includes(session.role))
const detailVisible = ref(false)
const reviewVisible = ref(false)
const detail = ref(null)
const currentProject = ref(null)
const reviewForm = reactive({
  decision: 'approve',
  score: null,
  comment: '',
  criteria_scores: {},
  final_support: emptyFinalSupport()
})
const pagination = reactive({ current_page: 1, per_page: 20, total: 0 })
const resultPagination = reactive({ current_page: 1, per_page: 20, total: 0 })
let skipNextRouteProjectReload = false

const roleLabels = {
  county: '区县审核',
  department: '部门审核',
  expert: '专家评审',
  admin: '管理员终审'
}
const statusLabels = {
  submitted: { label: '已提交', type: 'warning' },
  reviewing: { label: '审核中', type: 'primary' },
  approved: { label: '已通过', type: 'success' },
  returned: { label: '退回修改', type: 'danger' },
  rejected: { label: '已驳回', type: 'danger' }
}
const decisionLabels = {
  approve: '通过',
  recommend: '推荐',
  accept: '通过',
  return: '退回',
  reject: '驳回'
}
const stageOptions = [
  { label: '区县审核', value: 'county' },
  { label: '部门审核', value: 'department' },
  { label: '专家评审', value: 'expert' },
  { label: '管理员终审', value: 'admin' }
]
const allDecisionOptions = [
  { label: '通过', value: 'approve' },
  { label: '推荐', value: 'recommend' },
  { label: '终审通过', value: 'accept' },
  { label: '退回', value: 'return' },
  { label: '驳回', value: 'reject' }
]
const decisionOptions = computed(() => {
  if (session.role === 'expert') {
    return [
      { label: '推荐', value: 'recommend' },
      { label: '退回', value: 'return' },
      { label: '驳回', value: 'reject' }
    ]
  }

  if (isAdminRole.value) {
    return [
      { label: '通过', value: 'accept' },
      { label: '退回', value: 'return' },
      { label: '驳回', value: 'reject' }
    ]
  }

  return [
    { label: '通过', value: 'approve' },
    { label: '退回', value: 'return' },
    { label: '驳回', value: 'reject' }
  ]
})
const useCriteriaScoring = computed(() => currentProject.value?.current_reviewer_role === 'expert' && reviewCriteriaOptions.value.length > 0)
const useFinalSupportForm = computed(() => currentProject.value?.current_reviewer_role === 'admin' && reviewForm.decision === 'accept')
const showNumericScore = computed(() => Boolean(currentProject.value?.review_config?.score_enabled) && !useCriteriaScoring.value)
const groupedReviewCriteria = computed(() => {
  const groups = new Map()
  for (const item of reviewCriteriaOptions.value) {
    const section = item.metadata?.section || '专家评分'
    if (!groups.has(section)) groups.set(section, { section, maxScore: 0, items: [] })
    const group = groups.get(section)
    const normalized = {
      code: item.code,
      label: item.label,
      sort_order: Number(item.sort_order || 0),
      description: item.metadata?.description || '',
      max_score: Number(item.metadata?.max_score || 0)
    }
    group.maxScore += normalized.max_score
    group.items.push(normalized)
  }

  return Array.from(groups.values()).map((group) => ({
    ...group,
    maxScore: Number(group.maxScore.toFixed(1)),
    items: group.items.sort((a, b) => a.sort_order - b.sort_order)
  }))
})
const reviewCriteriaMaxTotal = computed(() => Number(reviewCriteriaOptions.value.reduce((sum, item) => sum + Number(item.metadata?.max_score || 0), 0).toFixed(1)))
const reviewCriteriaScoreTotal = computed(() => {
  const total = reviewCriteriaOptions.value.reduce((sum, item) => sum + Number(reviewForm.criteria_scores[item.code] || 0), 0)
  return Number(total.toFixed(1))
})

function roleLabel(role) {
  return roleLabels[role] || role || '-'
}

function statusMeta(value) {
  return statusLabels[value] || { label: value || '-', type: 'info' }
}

function decisionLabel(value) {
  return decisionLabels[value] || value || '-'
}

function tableIndex(index) {
  return (pagination.current_page - 1) * pagination.per_page + index + 1
}

function resultTableIndex(index) {
  return (resultPagination.current_page - 1) * resultPagination.per_page + index + 1
}

function emptyFinalSupport() {
  return {
    is_recommended: true,
    is_supported: true,
    subsidy_amount_wan: 0,
    interest_amount_wan: 0,
    other_amount_wan: 0,
    other_support_note: ''
  }
}

async function loadDictionaries() {
  const [types, categories, criteria] = await Promise.all([
    api('/dictionaries?group=project_type'),
    api('/dictionaries?group=project_category'),
    api('/dictionaries?group=expert_review_criterion')
  ])
  projectTypeOptions.value = types
  projectCategoryOptions.value = categories
  reviewCriteriaOptions.value = criteria
}

function buildTaskQuery(includePage = true) {
  const params = new URLSearchParams()
  if (keyword.value) params.set('keyword', keyword.value)
  if (category.value) params.set('category', category.value)
  if (projectType.value) params.set('project_type', projectType.value)
  if (route.query.project_id) params.set('project_id', route.query.project_id)
  if (includePage && pagination.current_page > 1) params.set('page', pagination.current_page)
  return params.toString() ? `?${params.toString()}` : ''
}

function buildResultQuery(includePage = true) {
  const params = new URLSearchParams()
  if (resultKeyword.value) params.set('keyword', resultKeyword.value)
  if (route.query.project_id) params.set('project_id', route.query.project_id)
  if (isAdminRole.value && resultStage.value) params.set('stage', resultStage.value)
  if (resultDecision.value) params.set('decision', resultDecision.value)
  if (resultCategory.value) params.set('category', resultCategory.value)
  if (resultProjectType.value) params.set('project_type', resultProjectType.value)
  if (resultScoreMin.value !== null && resultScoreMin.value !== '') params.set('score_min', resultScoreMin.value)
  if (resultScoreMax.value !== null && resultScoreMax.value !== '') params.set('score_max', resultScoreMax.value)
  if (includePage && resultPagination.current_page > 1) params.set('page', resultPagination.current_page)
  return params.toString() ? `?${params.toString()}` : ''
}

async function loadTasks() {
  loading.value = true
  try {
    const result = await api(`/reviews/tasks${buildTaskQuery()}`)
    tasks.value = result.data || result
    pagination.current_page = result.current_page || 1
    pagination.per_page = result.per_page || 20
    pagination.total = result.total || tasks.value.length
    openRouteReview()
  } finally {
    loading.value = false
  }
}

function reloadTasks() {
  pagination.current_page = 1
  loadTasks()
}

function changePage(page) {
  pagination.current_page = page
  loadTasks()
}

async function loadResults() {
  resultsLoading.value = true
  try {
    const result = await api(`/reviews/results${buildResultQuery()}`)
    results.value = result.data || result
    resultPagination.current_page = result.current_page || 1
    resultPagination.per_page = result.per_page || 20
    resultPagination.total = result.total || results.value.length
  } finally {
    resultsLoading.value = false
  }
}

function reloadResults() {
  resultPagination.current_page = 1
  loadResults()
}

function changeResultPage(page) {
  resultPagination.current_page = page
  loadResults()
}

function handleTabChange(name) {
  if (name === 'tasks' && tasks.value.length === 0) loadTasks()
  if (name === 'results' && results.value.length === 0) loadResults()
}

function applyRouteTab() {
  activeTab.value = route.query.tab === 'results' ? 'results' : 'tasks'
}

function applyRouteFilters() {
  if (typeof route.query.keyword === 'string') {
    keyword.value = route.query.keyword
    resultKeyword.value = route.query.keyword
  }
  if (typeof route.query.stage === 'string') resultStage.value = route.query.stage
  if (typeof route.query.decision === 'string') resultDecision.value = route.query.decision
  if (typeof route.query.category === 'string') {
    category.value = route.query.category
    resultCategory.value = route.query.category
  }
  if (typeof route.query.project_type === 'string') {
    projectType.value = route.query.project_type
    resultProjectType.value = route.query.project_type
  }
}

async function openDetail(row) {
  detail.value = await api(`/projects/${row.id}`)
  detailVisible.value = true
}

async function openReview(row) {
  currentProject.value = await api(`/projects/${row.id}`)
  Object.assign(reviewForm, {
    decision: decisionOptions.value[0]?.value || 'approve',
    score: null,
    comment: '',
    criteria_scores: defaultCriteriaScores(),
    final_support: emptyFinalSupport()
  })
  syncCriteriaScore()
  reviewVisible.value = true
}

function openRouteReview() {
  if (!route.query.project_id || reviewVisible.value) return
  const project = tasks.value.find((item) => String(item.id) === String(route.query.project_id))
  if (project) void openReview(project)
}

async function clearRouteProjectFilter({ reload = true } = {}) {
  if (!route.query.project_id) return
  skipNextRouteProjectReload = !reload
  const query = { ...route.query }
  delete query.project_id
  await router.replace({ path: route.path, query })
}

async function submitReview() {
  submitting.value = true
  try {
    syncCriteriaScore()
    const shouldSubmitCriteria = useCriteriaScoring.value && shouldSubmitCriteriaScores()
    const payload = {
      decision: reviewForm.decision,
      score: useCriteriaScoring.value && !shouldSubmitCriteria ? null : reviewForm.score,
      comment: reviewForm.comment
    }
    if (shouldSubmitCriteria) {
      payload.metadata = { score_criteria: { ...reviewForm.criteria_scores } }
    }
    if (useFinalSupportForm.value) {
      payload.metadata = {
        ...(payload.metadata || {}),
        final_support: normalizedFinalSupport()
      }
    }

    await api(`/projects/${currentProject.value.id}/reviews`, {
      method: 'POST',
      body: JSON.stringify(payload)
    })
    ElMessage.success('审核已提交')
    reviewVisible.value = false
    if (detail.value?.id === currentProject.value.id) await openDetail(currentProject.value)
    await clearRouteProjectFilter({ reload: false })
    await loadTasks()
    if (activeTab.value === 'results') await loadResults()
  } finally {
    submitting.value = false
  }
}

function defaultCriteriaScores() {
  return Object.fromEntries(reviewCriteriaOptions.value.map((item) => [item.code, null]))
}

function syncCriteriaScore() {
  if (!useCriteriaScoring.value) return
  reviewForm.score = reviewCriteriaScoreTotal.value
}

function syncFinalSupportState() {
  if (reviewForm.final_support.is_supported) return
  reviewForm.final_support.subsidy_amount_wan = 0
  reviewForm.final_support.interest_amount_wan = 0
  reviewForm.final_support.other_amount_wan = 0
  reviewForm.final_support.other_support_note = ''
}

function normalizedFinalSupport() {
  const isSupported = Boolean(reviewForm.final_support.is_supported)
  return {
    is_recommended: Boolean(reviewForm.final_support.is_recommended),
    is_supported: isSupported,
    subsidy_amount_wan: isSupported ? Number(reviewForm.final_support.subsidy_amount_wan || 0) : 0,
    interest_amount_wan: isSupported ? Number(reviewForm.final_support.interest_amount_wan || 0) : 0,
    other_amount_wan: isSupported ? Number(reviewForm.final_support.other_amount_wan || 0) : 0,
    other_support_note: isSupported ? (reviewForm.final_support.other_support_note || '') : ''
  }
}

function shouldSubmitCriteriaScores() {
  if (!['return', 'reject'].includes(reviewForm.decision)) return true
  return Object.values(reviewForm.criteria_scores || {}).some((value) => value !== null && value !== '')
}

function formatCriteriaScores(row) {
  const items = row?.metadata?.score_criteria
  if (!Array.isArray(items) || items.length === 0) return '-'
  return items
    .map((item) => `${item.label || item.code}：${item.score ?? '-'} / ${item.max_score ?? '-'}`)
    .join('；')
}

function dispatchUserNames(assignment) {
  return (assignment?.recommended_users || [])
    .map((user) => user.name || user.username)
    .filter(Boolean)
    .join('、') || '-'
}

async function exportTasks() {
  try {
    await downloadApi(`/reviews/tasks/export.csv${buildTaskQuery(false)}`, `review-tasks-${new Date().toISOString().slice(0, 10)}.csv`)
  } catch (err) {
    ElMessage.error(err.message || '审核任务导出失败')
  }
}

async function exportResults() {
  try {
    await downloadApi(`/reviews/results/export.csv${buildResultQuery(false)}`, `review-results-${new Date().toISOString().slice(0, 10)}.csv`)
  } catch (err) {
    ElMessage.error(err.message || '审核结果导出失败')
  }
}

async function downloadFile(row) {
  try {
    await downloadApi(`/files/${row.id}/download`, row.original_name || 'download')
  } catch (err) {
    ElMessage.error(err.message || '附件下载失败')
  }
}

function openFileLogs(row) {
  router.push(`/operation-logs?target_type=${encodeURIComponent('App\\Models\\ProjectFile')}&target_id=${row.id}`)
}

function formatBytes(value) {
  const size = Number(value || 0)
  if (size < 1024) return `${size} B`
  if (size < 1024 * 1024) return `${(size / 1024).toFixed(1)} KB`
  return `${(size / 1024 / 1024).toFixed(1)} MB`
}

function formatCurrency(value) {
  if (value === null || value === undefined || value === '') return '-'
  const amount = Number(value)
  if (Number.isNaN(amount)) return `${value} 元`
  return `${amount.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} 元`
}

function finalSupportText(project) {
  const support = project?.final_support || project?.metadata?.final_support || {}
  const isSupported = support.is_supported === undefined || support.is_supported === null
    ? '-'
    : (support.is_supported ? '支持' : '不支持')
  const total = support.total_support_amount_wan ?? support.support_amount_wan
  const supportAmount = total === undefined || total === null || total === ''
    ? '-'
    : `合计 ${Number(total || 0).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} 万元（补助 ${Number(support.subsidy_amount_wan || 0)}，贴息 ${Number(support.interest_amount_wan || 0)}，其他 ${Number(support.other_amount_wan || 0)}）`
  return {
    isSupported,
    supportAmount,
    recommendedExperts: support.recommended_experts || '-'
  }
}

function expertSummaryText(project) {
  const summary = project?.expert_review_summary
  if (!summary) return '暂无专家评分'
  const score = summary.average_score === null || summary.average_score === undefined ? '-' : summary.average_score
  return `已评分 ${summary.reviewed_count || 0}/${summary.assigned_count || 0}，平均分 ${score}`
}

onMounted(async () => {
  applyRouteTab()
  applyRouteFilters()
  await Promise.all([
    activeTab.value === 'results' ? loadResults() : loadTasks(),
    loadDictionaries()
  ])
  window.addEventListener('dictionaries:changed', loadDictionaries)
})

watch(() => route.query.project_id, () => {
  if (skipNextRouteProjectReload) {
    skipNextRouteProjectReload = false
    return
  }
  applyRouteTab()
  if (activeTab.value === 'results') {
    reloadResults()
  } else {
    reloadTasks()
  }
})

watch(() => route.query.tab, () => {
  applyRouteTab()
  applyRouteFilters()
  if (activeTab.value === 'tasks' && tasks.value.length === 0) loadTasks()
  if (activeTab.value === 'results' && results.value.length === 0) loadResults()
})

watch(() => [route.query.keyword, route.query.stage, route.query.decision, route.query.category, route.query.project_type], () => {
  applyRouteFilters()
  if (activeTab.value === 'results') reloadResults()
  else reloadTasks()
})

onUnmounted(() => {
  window.removeEventListener('dictionaries:changed', loadDictionaries)
})
</script>

<style scoped>
.score-filter {
  width: 116px;
}

.table-action-row {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.table-action-row :deep(.el-button + .el-button) {
  margin-left: 0;
}

.dispatch-users {
  margin-left: 8px;
  color: #334155;
}

.criteria-panel {
  display: grid;
  gap: 12px;
}

.criteria-group {
  display: grid;
  gap: 6px;
}

.criteria-group-title,
.criteria-total {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 13px;
}

.criteria-group-title span,
.criteria-total {
  color: #606266;
}

.criteria-total {
  justify-content: flex-end;
  font-weight: 600;
}

.dialog-alert,
.dialog-project-detail,
.dialog-files-table {
  margin-bottom: 14px;
}

.support-amount-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0 14px;
}

.detail-stack {
  display: grid;
  gap: 16px;
}

.detail-rich-content {
  max-height: 220px;
  overflow: auto;
}
</style>
