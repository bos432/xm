<template>
  <section class="page-stack">
    <div class="toolbar">
      <el-segmented v-model="status" :options="statusOptions" @change="reloadMessages" />
      <el-select v-model="type" clearable placeholder="消息类型" @change="reloadMessages">
        <el-option v-for="item in typeOptions" :key="item.value" :label="item.label" :value="item.value" />
      </el-select>
      <div class="toolbar-actions">
        <el-tooltip content="刷新消息" placement="top">
          <el-button :icon="Refresh" circle @click="loadMessages" />
        </el-tooltip>
        <el-button type="primary" :icon="Check" :disabled="unreadCount === 0" @click="markAllRead">全部已读</el-button>
      </div>
    </div>

    <el-table
      :data="messages"
      border
      v-loading="loading"
      :default-sort="{ prop: sortBy, order: sortOrder }"
      @sort-change="handleSortChange"
    >
      <el-table-column type="index" label="序号" width="72" align="center" :index="tableIndex" fixed="left" />
      <el-table-column prop="title" label="标题" min-width="220" sortable="custom" />
      <el-table-column prop="type" label="类型" width="120" sortable="custom">
        <template #default="{ row }">{{ typeLabel(row.type) }}</template>
      </el-table-column>
      <el-table-column prop="body" label="内容" min-width="280" />
      <el-table-column prop="created_at" label="时间" width="170" sortable="custom">
        <template #default="{ row }">{{ formatDateTime(row.created_at) }}</template>
      </el-table-column>
      <el-table-column label="状态" width="120">
        <template #default="{ row }">
          <el-tag :type="row.read_at ? 'info' : 'success'">{{ row.read_at ? '已读' : '未读' }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="操作" width="120">
        <template #default="{ row }">
          <el-tooltip content="标记已读" placement="top">
            <el-button size="small" :icon="Check" circle :disabled="Boolean(row.read_at)" @click="markRead(row)" />
          </el-tooltip>
          <el-tooltip v-if="row.project_id" :content="projectActionLabel(row)" placement="top">
            <el-button size="small" :icon="View" circle @click="openProject(row)" />
          </el-tooltip>
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
  </section>
</template>

<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { Check, Refresh, View } from '@element-plus/icons-vue'
import { useRouter } from 'vue-router'
import { api } from '../api.js'
import { useSessionStore } from '../store.js'

const router = useRouter()
const session = useSessionStore()
const loading = ref(false)
const messages = ref([])
const status = ref('')
const type = ref('')
const sortBy = ref('created_at')
const sortDirection = ref('asc')
const pagination = reactive({ current_page: 1, per_page: 20, total: 0 })

const statusOptions = [
  { label: '全部', value: '' },
  { label: '未读', value: 'unread' },
  { label: '已读', value: 'read' }
]
const typeOptions = [
  { label: '项目', value: 'project' },
  { label: '审核', value: 'review' },
  { label: '系统', value: 'system' }
]
const typeLabels = Object.fromEntries(typeOptions.map((item) => [item.value, item.label]))
const unreadCount = computed(() => messages.value.filter((item) => !item.read_at).length)
const sortOrder = computed(() => (sortDirection.value === 'asc' ? 'ascending' : 'descending'))

function buildQuery() {
  const params = new URLSearchParams()
  if (status.value) params.set('status', status.value)
  if (type.value) params.set('type', type.value)
  params.set('sort_by', sortBy.value)
  params.set('sort_direction', sortDirection.value)
  if (pagination.current_page > 1) params.set('page', pagination.current_page)
  return params.toString() ? `?${params.toString()}` : ''
}

function typeLabel(value) {
  return typeLabels[value] || value || '-'
}

function tableIndex(index) {
  return (pagination.current_page - 1) * pagination.per_page + index + 1
}

function formatDateTime(value) {
  if (!value) return '-'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value
  const parts = [
    date.getFullYear(),
    String(date.getMonth() + 1).padStart(2, '0'),
    String(date.getDate()).padStart(2, '0')
  ]
  const time = [
    String(date.getHours()).padStart(2, '0'),
    String(date.getMinutes()).padStart(2, '0')
  ]
  return `${parts.join('-')} ${time.join(':')}`
}

function shouldOpenReview(row) {
  return row.type === 'review' && session.can('review_projects')
}

function projectActionLabel(row) {
  return shouldOpenReview(row) ? '处理审核' : '查看项目'
}

async function loadMessages() {
  loading.value = true
  try {
    const result = await api(`/messages${buildQuery()}`)
    messages.value = result.data || result
    pagination.current_page = result.current_page || 1
    pagination.per_page = result.per_page || 20
    pagination.total = result.total || messages.value.length
  } finally {
    loading.value = false
  }
}

function reloadMessages() {
  pagination.current_page = 1
  loadMessages()
}

function changePage(page) {
  pagination.current_page = page
  loadMessages()
}

function handleSortChange({ prop, order }) {
  sortBy.value = prop || 'created_at'
  sortDirection.value = order === 'ascending' ? 'asc' : 'desc'
  reloadMessages()
}

async function markRead(row) {
  await api(`/messages/${row.id}/read`, { method: 'POST' })
  ElMessage.success('已标记为已读')
  window.dispatchEvent(new Event('messages:changed'))
  loadMessages()
}

async function openProject(row) {
  if (!row.read_at) {
    await api(`/messages/${row.id}/read`, { method: 'POST' })
    window.dispatchEvent(new Event('messages:changed'))
  }
  const path = shouldOpenReview(row)
    ? `/reviews?project_id=${row.project_id}`
    : `/projects?project_id=${row.project_id}`
  router.push(path)
}

async function markAllRead() {
  const result = await api('/messages/read-all', { method: 'POST' })
  ElMessage.success(result.updated > 0 ? `已标记 ${result.updated} 条消息` : '暂无未读消息')
  window.dispatchEvent(new Event('messages:changed'))
  loadMessages()
}

onMounted(loadMessages)
</script>
