<template>
  <RouterView v-if="$route.path === '/login'" />
  <el-container v-else class="shell">
    <el-aside width="248px" class="sidebar">
      <div class="brand">
        <strong>项目申报系统</strong>
        <span>Modern Workspace</span>
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
        <div>
          <strong>{{ title }}</strong>
          <span>旧新并行测试环境</span>
        </div>
        <div class="toolbar-actions">
          <el-tooltip content="站内消息" placement="bottom">
            <el-badge :value="unreadMessages" :hidden="unreadMessages === 0" :max="99">
              <el-button :icon="Bell" circle @click="router.push('/messages')" />
            </el-badge>
          </el-tooltip>
          <el-tooltip content="个人资料" placement="bottom">
            <el-button :icon="User" circle @click="openProfile" />
          </el-tooltip>
          <el-tooltip content="修改密码" placement="bottom">
            <el-button :icon="Lock" circle @click="passwordVisible = true" />
          </el-tooltip>
          <el-button :icon="SwitchButton" @click="logout">退出</el-button>
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
import { Bell, Checked, Collection, Connection, DataLine, FolderOpened, Lock, OfficeBuilding, Setting, SwitchButton, Tickets, User } from '@element-plus/icons-vue'
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
  units: OfficeBuilding,
  users: User,
  unit_profile: OfficeBuilding,
  reviews: Checked,
  messages: Bell,
  migration: Connection,
  operation_logs: Tickets,
  dictionary_items: Collection,
  settings: Setting
}
const titles = {
  '/': '运行概览',
  '/projects': '项目申报',
  '/units': '单位管理',
  '/users': '账号管理',
  '/unit-profile': '单位资料',
  '/reviews': '审核任务',
  '/messages': '站内消息',
  '/migration': '迁移准备',
  '/operation-logs': '操作日志',
  '/dictionary-items': '数据字典',
  '/settings': '系统配置'
}

const visibleMenus = computed(() => session.menus.length ? session.menus : [])
const title = computed(() => titles[route.path] || '项目申报系统')

function menuIcon(key) {
  return iconMap[key] || DataLine
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
  await session.logout()
  unreadMessages.value = 0
  router.push('/login')
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
