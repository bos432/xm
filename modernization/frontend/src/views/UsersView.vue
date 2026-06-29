<template>
  <section class="page-stack">
    <div class="toolbar">
      <el-input v-model="keyword" clearable placeholder="按姓名、账号、手机、邮箱搜索" @keyup.enter="reloadUsers" />
      <div class="toolbar-actions">
        <el-button :type="pendingRegistration ? 'primary' : 'default'" @click="togglePendingRegistration">待审核注册</el-button>
        <el-select v-model="role" clearable placeholder="角色" @change="handleStandardFilterChange">
          <el-option v-for="item in roleOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
        <el-select v-model="isActive" clearable placeholder="状态" @change="handleStandardFilterChange">
          <el-option label="启用" value="1" />
          <el-option label="停用" value="0" />
        </el-select>
        <el-button :icon="Search" @click="reloadUsers">查询</el-button>
        <el-tooltip content="导出当前筛选账号" placement="top">
          <el-button :icon="Download" @click="exportUsers">导出</el-button>
        </el-tooltip>
        <el-button type="primary" :icon="Plus" @click="openCreate">新增账号</el-button>
      </div>
    </div>

    <el-table :data="users" border v-loading="loading">
      <el-table-column prop="username" label="账号" width="150" />
      <el-table-column prop="name" label="姓名" width="140" />
      <el-table-column label="角色" width="120">
        <template #default="{ row }">{{ roleLabel(row.role) }}</template>
      </el-table-column>
      <el-table-column prop="unit.name" label="所属单位" min-width="200" />
      <el-table-column prop="mobile" label="手机" width="140" />
      <el-table-column prop="email" label="邮箱" min-width="190" />
      <el-table-column prop="last_login_at" label="最后登录" width="180" />
      <el-table-column prop="last_login_ip" label="登录IP" width="140" />
      <el-table-column label="状态" width="100">
        <template #default="{ row }"><el-tag :type="row.is_active ? 'success' : 'info'">{{ row.is_active ? '启用' : '停用' }}</el-tag></template>
      </el-table-column>
      <el-table-column label="注册来源" width="120">
        <template #default="{ row }">
          <el-tag v-if="row.unit?.metadata?.registration_status === 'pending' && !row.is_active" type="warning">待审核注册</el-tag>
          <el-tag v-else-if="row.unit?.metadata?.registration_status === 'approved'" type="success">公开注册</el-tag>
          <span v-else>-</span>
        </template>
      </el-table-column>
      <el-table-column label="操作" width="168" align="center">
        <template #default="{ row }">
          <el-tooltip content="编辑账号" placement="top">
            <el-button :icon="Edit" circle size="small" @click="openEdit(row)" />
          </el-tooltip>
          <el-tooltip v-if="canResetPassword" content="重置密码" placement="top">
            <el-button :icon="Lock" circle size="small" @click="openPasswordReset(row)" />
          </el-tooltip>
          <el-tooltip v-if="session.can('view_operation_logs')" content="查看账号日志" placement="top">
            <el-button :icon="Files" circle size="small" @click="openUserLogs(row)" />
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

    <el-dialog v-model="dialogVisible" :title="editingUser ? '编辑账号' : '新增账号'" width="620px">
      <el-form :model="form" label-position="top">
        <el-form-item label="账号"><el-input v-model="form.username" /></el-form-item>
        <el-form-item label="姓名"><el-input v-model="form.name" /></el-form-item>
        <el-form-item label="角色">
          <el-select v-model="form.role">
            <el-option v-for="item in roleOptions" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="所属单位">
          <el-select v-model="form.unit_id" clearable filterable>
            <el-option v-for="item in units" :key="item.id" :label="item.name" :value="item.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="手机"><el-input v-model="form.mobile" /></el-form-item>
        <el-form-item label="邮箱"><el-input v-model="form.email" /></el-form-item>
        <el-form-item v-if="!editingUser" label="初始密码">
          <el-input v-model="form.password" type="password" show-password />
        </el-form-item>
        <el-form-item label="状态"><el-switch v-model="form.is_active" active-text="启用" inactive-text="停用" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="saveUser">保存</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="passwordVisible" title="超级管理员重置密码" width="460px">
      <el-alert title="重置后该账号当前登录会话将被撤销，需要使用新密码重新登录。" type="warning" show-icon :closable="false" />
      <el-form :model="passwordForm" label-position="top" class="mt-16">
        <el-form-item label="账号">
          <el-input :model-value="passwordUser?.username || ''" disabled />
        </el-form-item>
        <el-form-item label="新密码">
          <el-input v-model="passwordForm.password" type="password" show-password />
        </el-form-item>
        <el-form-item label="确认新密码">
          <el-input v-model="passwordForm.password_confirmation" type="password" show-password />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="passwordVisible = false">取消</el-button>
        <el-button type="primary" :loading="savingPassword" @click="resetPassword">确认重置</el-button>
      </template>
    </el-dialog>
  </section>
</template>

<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { Download, Edit, Files, Lock, Plus, Search } from '@element-plus/icons-vue'
import { useRoute, useRouter } from 'vue-router'
import { api, downloadApi } from '../api.js'
import { useSessionStore } from '../store.js'

const router = useRouter()
const route = useRoute()
const session = useSessionStore()
const roleOptions = [
  { label: '超级管理员', value: 'super_admin' },
  { label: '业务管理员', value: 'admin' },
  { label: '单位用户', value: 'unit' },
  { label: '区县审核', value: 'county' },
  { label: '部门审核', value: 'department' },
  { label: '专家评审', value: 'expert' }
]
const loading = ref(false)
const saving = ref(false)
const savingPassword = ref(false)
const keyword = ref('')
const role = ref('')
const isActive = ref('')
const pendingRegistration = ref(false)
const users = ref([])
const units = ref([])
const dialogVisible = ref(false)
const passwordVisible = ref(false)
const editingUser = ref(null)
const passwordUser = ref(null)
const form = reactive(emptyForm())
const passwordForm = reactive({ password: '', password_confirmation: '' })
const pagination = reactive({ current_page: 1, per_page: 20, total: 0 })
const canResetPassword = computed(() => session.role === 'super_admin')

function emptyForm() {
  return { username: '', name: '', role: 'unit', unit_id: null, mobile: '', email: '', password: '', is_active: true }
}

function roleLabel(value) {
  return roleOptions.find((item) => item.value === value)?.label || value || '-'
}

async function loadUsers() {
  loading.value = true
  try {
    const query = buildUserQuery()
    const result = await api(`/users${query}`)
    users.value = result.data || result
    pagination.current_page = result.current_page || 1
    pagination.per_page = result.per_page || 20
    pagination.total = result.total || users.value.length
  } finally {
    loading.value = false
  }
}

function buildUserQuery() {
  const params = new URLSearchParams()
  if (keyword.value) params.set('keyword', keyword.value)
  if (role.value) params.set('role', role.value)
  if (isActive.value) params.set('is_active', isActive.value)
  if (pendingRegistration.value) params.set('pending_registration', '1')
  if (pagination.current_page > 1) params.set('page', pagination.current_page)
  return params.toString() ? `?${params.toString()}` : ''
}

function reloadUsers() {
  pagination.current_page = 1
  loadUsers()
}

function changePage(page) {
  pagination.current_page = page
  loadUsers()
}

function togglePendingRegistration() {
  pendingRegistration.value = !pendingRegistration.value
  if (pendingRegistration.value) {
    role.value = ''
    isActive.value = ''
  }
  reloadUsers()
}

function handleStandardFilterChange() {
  if (role.value || isActive.value) pendingRegistration.value = false
  reloadUsers()
}

async function loadUnits() {
  const result = await api('/units')
  units.value = result.data || result
}

function openCreate() {
  editingUser.value = null
  Object.assign(form, emptyForm())
  dialogVisible.value = true
}

function openEdit(row) {
  editingUser.value = row
  Object.assign(form, {
    username: row.username || '',
    name: row.name || '',
    role: row.role || 'unit',
    unit_id: row.unit_id || null,
    mobile: row.mobile || '',
    email: row.email || '',
    password: '',
    is_active: Boolean(row.is_active)
  })
  dialogVisible.value = true
}

function openPasswordReset(row) {
  passwordUser.value = row
  Object.assign(passwordForm, { password: '', password_confirmation: '' })
  passwordVisible.value = true
}

function openUserLogs(row) {
  router.push(`/operation-logs?target_type=${encodeURIComponent('App\\Models\\User')}&target_id=${row.id}`)
}

async function saveUser() {
  saving.value = true
  try {
    const path = editingUser.value ? `/users/${editingUser.value.id}` : '/users'
    const method = editingUser.value ? 'PUT' : 'POST'
    const body = { ...form }
    if (editingUser.value) delete body.password
    await api(path, { method, body: JSON.stringify(body) })
    ElMessage.success('账号已保存')
    dialogVisible.value = false
    await loadUsers()
  } finally {
    saving.value = false
  }
}

async function resetPassword() {
  if (!passwordUser.value) return

  savingPassword.value = true
  try {
    await api(`/users/${passwordUser.value.id}/password`, {
      method: 'PUT',
      body: JSON.stringify(passwordForm)
    })
    ElMessage.success('密码已重置，该账号需重新登录')
    passwordVisible.value = false
    await loadUsers()
  } finally {
    savingPassword.value = false
  }
}

async function exportUsers() {
  const params = new URLSearchParams()
  if (keyword.value) params.set('keyword', keyword.value)
  if (role.value) params.set('role', role.value)
  if (isActive.value) params.set('is_active', isActive.value)
  if (pendingRegistration.value) params.set('pending_registration', '1')
  const query = params.toString() ? `?${params.toString()}` : ''
  try {
    await downloadApi(`/users/export.csv${query}`, `users-${new Date().toISOString().slice(0, 10)}.csv`)
  } catch (err) {
    ElMessage.error(err.message || '账号导出失败')
  }
}

onMounted(async () => {
  pendingRegistration.value = route.query.pending_registration === '1'
  await Promise.all([loadUsers(), loadUnits()])
})
</script>
