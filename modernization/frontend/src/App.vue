<template>
  <RouterView v-if="$route.meta.public || $route.meta.guest" />
  <el-container v-else class="shell gov-shell">
    <el-aside width="248px" class="sidebar">
      <div class="brand">
        <strong>科技项目管理</strong>
        <span>公共服务后台</span>
      </div>
      <el-menu :default-active="$route.path" router>
        <el-menu-item v-for="item in visibleMenus" :key="item.path" :index="item.path">
          <el-icon><component :is="menuIcon(item.key)" /></el-icon>
          <span>{{ item.label }}</span>
        </el-menu-item>
      </el-menu>
    </el-aside>
    <el-container>
      <el-header class="topbar">
        <div class="topbar-title">
          <strong>{{ title }}</strong>
          <span>阿拉善盟科技计划项目管理信息系统</span>
        </div>
        <div class="topbar-actions">
          <el-tooltip content="站内消息" placement="bottom">
            <el-badge :value="unreadMessages" :hidden="unreadMessages === 0" :max="99">
              <el-button :icon="Bell" circle @click="router.push('/messages')" />
            </el-badge>
          </el-tooltip>
          <el-dropdown trigger="click" @command="handleAccountCommand">
            <el-button class="account-button">
              <el-icon><User /></el-icon>
              <span class="account-name">{{ session.user?.name || session.user?.username || '当前账号' }}</span>
              <span class="account-role">{{ roleLabel(session.role) }}</span>
              <el-icon class="el-icon--right"><ArrowDown /></el-icon>
            </el-button>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="profile" :icon="User">个人资料</el-dropdown-item>
                <el-dropdown-item command="password" :icon="Lock">修改密码</el-dropdown-item>
                <el-dropdown-item divided command="switch" :icon="SwitchButton">切换账号</el-dropdown-item>
                <el-dropdown-item command="logout" :icon="SwitchButton">退出登录</el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </el-header>
      <el-main>
        <RouterView />
      </el-main>
    </el-container>

    <el-dialog v-model="passwordVisible" title="修改密码" width="460px">
      <el-form :model="passwordForm" label-position="top">
        <el-form-item label="当前密码"><el-input v-model="passwordForm.current_password" type="password" show-password /></el-form-item>
        <el-form-item label="新密码"><el-input v-model="passwordForm.password" type="password" show-password /></el-form-item>
        <el-form-item label="确认新密码"><el-input v-model="passwordForm.password_confirmation" type="password" show-password /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="passwordVisible = false">取消</el-button>
        <el-button type="primary" :loading="savingPassword" @click="updatePassword">保存</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="profileVisible" title="个人资料" width="460px">
      <el-form :model="profileForm" label-position="top">
        <el-form-item label="姓名"><el-input v-model="profileForm.name" /></el-form-item>
        <el-form-item label="手机"><el-input v-model="profileForm.mobile" /></el-form-item>
        <el-form-item label="邮箱"><el-input v-model="profileForm.email" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="profileVisible = false">取消</el-button>
        <el-button type="primary" :loading="savingProfile" @click="updateProfile">保存</el-button>
      </template>
    </el-dialog>
  </el-container>
</template>

<script setup>
import { computed, onMounted, onUnmounted, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { ArrowDown, Bell, Checked, Collection, Connection, DataLine, FolderChecked, FolderOpened, House, Lock, Message, OfficeBuilding, Operation, Setting, SwitchButton, Tickets, User, Warning } from '@element-plus/icons-vue'
import { api } from './api.js'
import { useSessionStore } from './store.js'

const route = useRoute()
const router = useRouter()
const session = useSessionStore()
const passwordVisible = ref(false)
const savingPassword = ref(false)
const profileVisible = ref(false)
const savingProfile = ref(false)
const unreadMessages = ref(0)
const sessionExpiredNotified = ref(false)
const passwordForm = reactive({ current_password: '', password: '', password_confirmation: '' })
const profileForm = reactive({ name: '', mobile: '', email: '' })

const iconMap = {
  dashboard: DataLine,
  projects: FolderOpened,
  application_batches: Collection,
  acceptance: FolderChecked,
  acceptance_admin: FolderChecked,
  lifecycle: Connection,
  units: OfficeBuilding,
  users: User,
  unit_profile: OfficeBuilding,
  reviews: Checked,
  messages: Bell,
  migration: Connection,
  operation_logs: Tickets,
  public_home: House,
  mail_center: Message,
  roles: Operation,
  security: Warning,
  dictionary_items: Collection,
  settings: Setting
}
const titles = {
  '/dashboard': '运行概览',
  '/projects': '项目申报',
  '/application-batches': '申报批次',
  '/acceptance': '验收管理',
  '/lifecycle': '全周期管理',
  '/units': '单位管理',
  '/users': '账号管理',
  '/unit-profile': '单位资料',
  '/reviews': '审核任务',
  '/messages': '站内消息',
  '/migration': '迁移准备',
  '/operation-logs': '操作日志',
  '/public-home': '首页管理',
  '/mail-center': '邮件中心',
  '/roles': '角色权限',
  '/security': '安全中心',
  '/dictionary-items': '数据字典',
  '/settings': '系统配置'
}
const roleLabels = {
  super_admin: '超级管理员',
  admin: '业务管理员',
  unit: '单位用户',
  county: '区县审核',
  department: '部门审核',
  expert: '专家评审'
}

const visibleMenus = computed(() => session.menus.length ? session.menus : [])
const title = computed(() => titles[route.path] || '项目申报系统')

function menuIcon(key) {
  return iconMap[key] || DataLine
}

function roleLabel(role) {
  return roleLabels[role] || role || '-'
}

function openProfile() {
  Object.assign(profileForm, {
    name: session.user?.name || '',
    mobile: session.user?.mobile || '',
    email: session.user?.email || ''
  })
  profileVisible.value = true
}

async function refreshUnreadMessages() {
  if (!session.token || !session.can('view_dashboard')) return

  const summary = await api('/dashboard/summary').catch(() => null)
  unreadMessages.value = Number(summary?.messages?.unread || 0)
}

async function updateProfile() {
  savingProfile.value = true
  try {
    session.user = await api('/auth/profile', { method: 'PUT', body: JSON.stringify(profileForm) })
    ElMessage.success('个人资料已保存')
    profileVisible.value = false
  } finally {
    savingProfile.value = false
  }
}

async function updatePassword() {
  savingPassword.value = true
  try {
    await api('/auth/password', { method: 'PUT', body: JSON.stringify(passwordForm) })
    ElMessage.success('密码已修改，请重新登录')
    passwordVisible.value = false
    Object.assign(passwordForm, { current_password: '', password: '', password_confirmation: '' })
    session.token = ''
    session.user = null
    localStorage.removeItem('pas_token')
    router.push('/login')
  } finally {
    savingPassword.value = false
  }
}

async function logout() {
  session.logout()
  unreadMessages.value = 0
  router.replace('/login')
}

function switchAccount() {
  session.clearSession()
  unreadMessages.value = 0
  passwordVisible.value = false
  profileVisible.value = false
  router.replace('/login?switch=1')
}

function handleAccountCommand(command) {
  if (command === 'profile') {
    openProfile()
    return
  }

  if (command === 'password') {
    passwordVisible.value = true
    return
  }

  if (command === 'switch') {
    switchAccount()
    return
  }

  if (command === 'logout') {
    logout()
  }
}

function handleSessionExpired() {
  session.token = ''
  session.user = null
  unreadMessages.value = 0
  passwordVisible.value = false
  profileVisible.value = false

  if (!sessionExpiredNotified.value && route.path !== '/login') {
    ElMessage.warning('登录状态已过期，请重新登录')
    sessionExpiredNotified.value = true
  }

  if (route.path !== '/login') router.push('/login')
}

watch(() => route.path, () => {
  if (route.path !== '/login') sessionExpiredNotified.value = false
  refreshUnreadMessages()
})

onMounted(() => {
  window.addEventListener('messages:changed', refreshUnreadMessages)
  window.addEventListener('auth:expired', handleSessionExpired)
  refreshUnreadMessages()
})

onUnmounted(() => {
  window.removeEventListener('messages:changed', refreshUnreadMessages)
  window.removeEventListener('auth:expired', handleSessionExpired)
})
</script>
