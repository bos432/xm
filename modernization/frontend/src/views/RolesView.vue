<template>
  <section class="page-stack">
    <div class="toolbar">
      <div>
        <h2>角色权限</h2>
        <span class="muted">维护自定义角色、权限矩阵和用户附加角色</span>
      </div>
      <div class="toolbar-actions">
        <el-button :icon="Refresh" :loading="loading" @click="loadAll">刷新</el-button>
        <el-button type="primary" :icon="Plus" @click="openRole()">新增角色</el-button>
      </div>
    </div>

    <el-row :gutter="16">
      <el-col :xs="24" :lg="10">
        <el-card shadow="never">
          <template #header>角色列表</template>
          <el-table :data="roles" border v-loading="loading" highlight-current-row @current-change="selectRole">
            <el-table-column prop="name" label="角色" min-width="140" />
            <el-table-column prop="code" label="编码" min-width="150" />
            <el-table-column label="内置" width="80">
              <template #default="{ row }"><el-tag :type="row.is_builtin ? 'warning' : 'info'">{{ row.is_builtin ? '是' : '否' }}</el-tag></template>
            </el-table-column>
            <el-table-column label="操作" width="90">
              <template #default="{ row }"><el-button size="small" :icon="Edit" @click.stop="openRole(row)">编辑</el-button></template>
            </el-table-column>
          </el-table>
        </el-card>
      </el-col>
      <el-col :xs="24" :lg="14">
        <el-card shadow="never">
          <template #header>
            <div class="toolbar">
              <strong>{{ selectedRole?.name || '请选择角色' }} 权限矩阵</strong>
              <el-button type="primary" :disabled="!selectedRole || selectedRole.code === 'super_admin'" :loading="savingPermissions" @click="savePermissions">保存权限</el-button>
            </div>
          </template>
          <el-checkbox-group v-model="selectedPermissionIds" class="permission-grid">
            <el-checkbox v-for="permission in permissions" :key="permission.id" :label="permission.id" :disabled="selectedRole?.code === 'super_admin'">
              <b>{{ permission.name }}</b>
              <span>{{ permission.group }} · {{ permission.code }}</span>
            </el-checkbox>
          </el-checkbox-group>
        </el-card>
      </el-col>
    </el-row>

    <el-card shadow="never">
      <template #header>
        <div class="toolbar">
          <strong>用户附加角色</strong>
          <el-input v-model="userKeyword" clearable placeholder="账号/姓名/邮箱" @keyup.enter="loadUsers" />
        </div>
      </template>
      <el-table :data="users" border>
        <el-table-column prop="username" label="账号" width="150" />
        <el-table-column prop="name" label="姓名" width="140" />
        <el-table-column prop="role" label="主角色" width="130" />
        <el-table-column label="附加角色" min-width="240">
          <template #default="{ row }">{{ (row.additional_roles || []).map((role) => role.name).join('，') || '-' }}</template>
        </el-table-column>
        <el-table-column label="操作" width="120">
          <template #default="{ row }"><el-button size="small" @click="openUserRoles(row)">分配角色</el-button></template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="roleVisible" :title="roleForm.id ? '编辑角色' : '新增角色'" width="520px">
      <el-form :model="roleForm" label-position="top">
        <el-form-item label="角色编码"><el-input v-model="roleForm.code" :disabled="roleForm.is_builtin" /></el-form-item>
        <el-form-item label="角色名称"><el-input v-model="roleForm.name" /></el-form-item>
        <el-form-item label="说明"><el-input v-model="roleForm.description" type="textarea" :rows="3" /></el-form-item>
        <el-form-item label="启用"><el-switch v-model="roleForm.is_active" :disabled="roleForm.code === 'super_admin'" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="roleVisible = false">取消</el-button>
        <el-button type="primary" :loading="savingRole" @click="saveRole">保存</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="userRoleVisible" title="分配附加角色" width="520px">
      <el-checkbox-group v-model="userRoleIds" class="role-checkbox-list">
        <el-checkbox v-for="role in roles.filter((item) => item.code !== 'super_admin')" :key="role.id" :label="role.id">{{ role.name }}（{{ role.code }}）</el-checkbox>
      </el-checkbox-group>
      <template #footer>
        <el-button @click="userRoleVisible = false">取消</el-button>
        <el-button type="primary" :loading="savingUserRoles" @click="saveUserRoles">保存</el-button>
      </template>
    </el-dialog>
  </section>
</template>

<script setup>
import { onMounted, reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { Edit, Plus, Refresh } from '@element-plus/icons-vue'
import { api } from '../api.js'

const loading = ref(false)
const roles = ref([])
const permissions = ref([])
const users = ref([])
const selectedRole = ref(null)
const selectedPermissionIds = ref([])
const roleVisible = ref(false)
const userRoleVisible = ref(false)
const savingRole = ref(false)
const savingPermissions = ref(false)
const savingUserRoles = ref(false)
const userKeyword = ref('')
const editingUser = ref(null)
const userRoleIds = ref([])
const roleForm = reactive(emptyRole())

function emptyRole() {
  return { id: null, code: '', name: '', description: '', is_active: true, is_builtin: false }
}

async function loadAll() {
  loading.value = true
  try {
    const [roleResult, permissionResult] = await Promise.all([api('/roles'), api('/permissions')])
    roles.value = roleResult
    permissions.value = permissionResult
    if (!selectedRole.value && roles.value.length) selectRole(roles.value[0])
    await loadUsers()
  } finally {
    loading.value = false
  }
}

async function loadUsers() {
  const params = new URLSearchParams()
  if (userKeyword.value) params.set('keyword', userKeyword.value)
  const result = await api(`/users${params.toString() ? `?${params.toString()}` : ''}`)
  users.value = result.data || result
}

function selectRole(row) {
  if (!row) return
  selectedRole.value = row
  selectedPermissionIds.value = (row.permissions || []).map((item) => item.id)
}

function openRole(row = null) {
  Object.assign(roleForm, emptyRole(), row || {})
  roleVisible.value = true
}

async function saveRole() {
  savingRole.value = true
  try {
    await api(roleForm.id ? `/roles/${roleForm.id}` : '/roles', {
      method: roleForm.id ? 'PUT' : 'POST',
      body: JSON.stringify({
        code: roleForm.code,
        name: roleForm.name,
        description: roleForm.description,
        is_active: roleForm.is_active
      })
    })
    ElMessage.success('角色已保存')
    roleVisible.value = false
    await loadAll()
  } finally {
    savingRole.value = false
  }
}

async function savePermissions() {
  savingPermissions.value = true
  try {
    const updated = await api(`/roles/${selectedRole.value.id}/permissions`, {
      method: 'PUT',
      body: JSON.stringify({ permission_ids: selectedPermissionIds.value })
    })
    ElMessage.success('权限矩阵已保存')
    selectedRole.value = updated
    await loadAll()
  } finally {
    savingPermissions.value = false
  }
}

function openUserRoles(row) {
  editingUser.value = row
  userRoleIds.value = (row.additional_roles || []).map((role) => role.id)
  userRoleVisible.value = true
}

async function saveUserRoles() {
  savingUserRoles.value = true
  try {
    await api(`/users/${editingUser.value.id}/roles`, {
      method: 'PUT',
      body: JSON.stringify({ role_ids: userRoleIds.value })
    })
    ElMessage.success('用户附加角色已保存')
    userRoleVisible.value = false
    await loadUsers()
  } finally {
    savingUserRoles.value = false
  }
}

onMounted(loadAll)
</script>
