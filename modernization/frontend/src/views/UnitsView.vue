<template>
  <section class="page-stack">
    <template v-if="isAdmin">
      <div class="toolbar">
        <el-input v-model="keyword" clearable placeholder="按单位名称、统一信用代码、联系人搜索" @keyup.enter="reloadUnits" />
        <div class="toolbar-actions">
          <el-button :type="pendingRegistration ? 'primary' : 'default'" @click="togglePendingRegistration">待审核注册</el-button>
          <el-select v-model="status" clearable placeholder="状态" @change="handleStatusChange">
            <el-option label="正常" value="active" />
            <el-option label="暂停" value="suspended" />
            <el-option label="归档" value="archived" />
          </el-select>
          <el-button :icon="Search" @click="reloadUnits">查询</el-button>
          <el-tooltip content="导出当前筛选单位" placement="top">
            <el-button :icon="Download" @click="exportUnits">导出</el-button>
          </el-tooltip>
          <el-button type="primary" :icon="Plus" @click="openCreate">新增单位</el-button>
        </div>
      </div>

      <el-table :data="units" border v-loading="loading">
        <el-table-column prop="name" label="单位名称" min-width="220" />
        <el-table-column prop="credit_code" label="统一信用代码" width="180" />
        <el-table-column prop="contact_name" label="联系人" width="120" />
        <el-table-column prop="contact_mobile" label="联系电话" width="150" />
        <el-table-column prop="region_code" label="区域" width="110" />
        <el-table-column label="状态" width="130">
          <template #default="{ row }"><el-tag :type="statusMeta(row.status).type">{{ statusMeta(row.status).label }}</el-tag></template>
        </el-table-column>
        <el-table-column label="注册来源" width="120">
          <template #default="{ row }">
            <el-tag v-if="row.metadata?.registration_status === 'pending' && row.status === 'suspended'" type="warning">待审核注册</el-tag>
            <el-tag v-else-if="row.metadata?.registration_status === 'approved'" type="success">公开注册</el-tag>
            <span v-else>-</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="128" align="center">
          <template #default="{ row }">
            <el-tooltip content="编辑单位" placement="top">
              <el-button :icon="Edit" circle size="small" @click="openEdit(row)" />
            </el-tooltip>
            <el-tooltip v-if="session.can('view_operation_logs')" content="查看单位日志" placement="top">
              <el-button :icon="Files" circle size="small" @click="openUnitLogs(row)" />
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
    </template>

    <template v-else>
      <el-descriptions v-if="profile" title="单位资料" :column="2" border v-loading="loading">
        <el-descriptions-item label="单位名称" :span="2">{{ profile.name }}</el-descriptions-item>
        <el-descriptions-item label="统一信用代码">{{ profile.credit_code || '-' }}</el-descriptions-item>
        <el-descriptions-item label="状态">{{ statusMeta(profile.status).label }}</el-descriptions-item>
        <el-descriptions-item label="联系人">{{ profile.contact_name || '-' }}</el-descriptions-item>
        <el-descriptions-item label="联系电话">{{ profile.contact_mobile || '-' }}</el-descriptions-item>
        <el-descriptions-item label="邮箱">{{ profile.email || '-' }}</el-descriptions-item>
        <el-descriptions-item label="区域">{{ profile.region_code || '-' }}</el-descriptions-item>
        <el-descriptions-item label="地址" :span="2">{{ profile.address || '-' }}</el-descriptions-item>
      </el-descriptions>
    </template>

    <el-dialog v-model="dialogVisible" :title="editingUnit ? '编辑单位' : '新增单位'" width="620px">
      <el-form :model="form" label-position="top">
        <el-form-item label="单位名称"><el-input v-model="form.name" /></el-form-item>
        <el-form-item label="统一信用代码"><el-input v-model="form.credit_code" /></el-form-item>
        <el-form-item label="联系人"><el-input v-model="form.contact_name" /></el-form-item>
        <el-form-item label="联系电话"><el-input v-model="form.contact_mobile" /></el-form-item>
        <el-form-item label="邮箱"><el-input v-model="form.email" /></el-form-item>
        <el-form-item label="区域编码"><el-input v-model="form.region_code" /></el-form-item>
        <el-form-item label="状态">
          <el-select v-model="form.status">
            <el-option label="正常" value="active" />
            <el-option label="暂停" value="suspended" />
            <el-option label="归档" value="archived" />
          </el-select>
        </el-form-item>
        <el-form-item label="地址"><el-input v-model="form.address" type="textarea" :rows="3" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="saveUnit">保存</el-button>
      </template>
    </el-dialog>
  </section>
</template>

<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { Download, Edit, Files, Plus, Search } from '@element-plus/icons-vue'
import { useRoute, useRouter } from 'vue-router'
import { api, downloadApi } from '../api.js'
import { useSessionStore } from '../store.js'

const router = useRouter()
const route = useRoute()
const session = useSessionStore()
const isAdmin = computed(() => session.can('manage_units'))
const loading = ref(false)
const saving = ref(false)
const keyword = ref('')
const status = ref('')
const pendingRegistration = ref(false)
const units = ref([])
const profile = ref(null)
const dialogVisible = ref(false)
const editingUnit = ref(null)
const form = reactive(emptyForm())
const pagination = reactive({ current_page: 1, per_page: 20, total: 0 })

function emptyForm() {
  return { name: '', credit_code: '', contact_name: '', contact_mobile: '', email: '', address: '', region_code: '', status: 'active' }
}

function statusMeta(status) {
  const map = {
    active: { label: '正常', type: 'success' },
    suspended: { label: '暂停', type: 'warning' },
    archived: { label: '归档', type: 'info' }
  }
  return map[status] || { label: status || '-', type: 'info' }
}

async function loadUnits() {
  loading.value = true
  try {
    if (isAdmin.value) {
      const query = buildUnitQuery()
      const result = await api(`/units${query}`)
      units.value = result.data || result
      pagination.current_page = result.current_page || 1
      pagination.per_page = result.per_page || 20
      pagination.total = result.total || units.value.length
    } else {
      profile.value = await api('/units/me')
    }
  } finally {
    loading.value = false
  }
}

function buildUnitQuery() {
  const params = new URLSearchParams()
  if (keyword.value) params.set('keyword', keyword.value)
  if (status.value) params.set('status', status.value)
  if (pendingRegistration.value) params.set('pending_registration', '1')
  if (pagination.current_page > 1) params.set('page', pagination.current_page)
  return params.toString() ? `?${params.toString()}` : ''
}

function reloadUnits() {
  pagination.current_page = 1
  loadUnits()
}

function changePage(page) {
  pagination.current_page = page
  loadUnits()
}

function togglePendingRegistration() {
  pendingRegistration.value = !pendingRegistration.value
  if (pendingRegistration.value) status.value = ''
  reloadUnits()
}

function handleStatusChange() {
  if (status.value) pendingRegistration.value = false
  reloadUnits()
}

function openCreate() {
  editingUnit.value = null
  Object.assign(form, emptyForm())
  dialogVisible.value = true
}

function openEdit(row) {
  editingUnit.value = row
  Object.assign(form, {
    name: row.name || '',
    credit_code: row.credit_code || '',
    contact_name: row.contact_name || '',
    contact_mobile: row.contact_mobile || '',
    email: row.email || '',
    address: row.address || '',
    region_code: row.region_code || '',
    status: row.status || 'active'
  })
  dialogVisible.value = true
}

function openUnitLogs(row) {
  router.push(`/operation-logs?target_type=${encodeURIComponent('App\\Models\\Unit')}&target_id=${row.id}`)
}

async function saveUnit() {
  saving.value = true
  try {
    const path = editingUnit.value ? `/units/${editingUnit.value.id}` : '/units'
    const method = editingUnit.value ? 'PUT' : 'POST'
    await api(path, { method, body: JSON.stringify(form) })
    ElMessage.success('单位资料已保存')
    dialogVisible.value = false
    await loadUnits()
  } finally {
    saving.value = false
  }
}

async function exportUnits() {
  const params = new URLSearchParams()
  if (keyword.value) params.set('keyword', keyword.value)
  if (status.value) params.set('status', status.value)
  if (pendingRegistration.value) params.set('pending_registration', '1')
  const query = params.toString() ? `?${params.toString()}` : ''
  try {
    await downloadApi(`/units/export.csv${query}`, `units-${new Date().toISOString().slice(0, 10)}.csv`)
  } catch (err) {
    ElMessage.error(err.message || '单位导出失败')
  }
}

onMounted(() => {
  pendingRegistration.value = route.query.pending_registration === '1'
  loadUnits()
})
</script>
