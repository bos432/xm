<template>
  <RouterView v-if="$route.meta.public || $route.meta.guest" />
  <el-container v-else class="shell gov-shell">
    <el-aside width="292px" class="sidebar dual-sidebar">
      <div class="module-rail">
        <button
          v-for="group in visibleMenuGroups"
          :key="group.key"
          type="button"
          class="module-button"
          :class="{ active: group.key === activeGroupKey }"
          @click="openMenuGroup(group)"
        >
          <el-icon><component :is="groupIcon(group.key)" /></el-icon>
          <span>{{ group.label }}</span>
        </button>
      </div>
      <div class="section-sidebar">
        <div class="brand">
          <strong>{{ texts.t('app.brand.title', '科技项目管理') }}</strong>
          <span>{{ texts.t('app.brand.subtitle', '公共服务后台') }}</span>
        </div>
        <div v-if="currentMenuGroup" class="section-title-block">
          <strong>{{ currentMenuGroup.label }}</strong>
        </div>
        <el-menu :default-active="activeMenuPath" :default-openeds="defaultOpeneds" router>
          <template v-for="item in currentMenuItems" :key="item.key">
            <el-sub-menu v-if="item.children?.length" :index="`menu-${item.key}`">
              <template #title>
                <el-icon><component :is="menuIcon(item.key)" /></el-icon>
                <span>{{ menuLabel(item) }}</span>
              </template>
              <el-menu-item :index="item.path">
                <span>{{ menuLabel(item) === '数据字典' ? '全部字典' : '全部配置' }}</span>
              </el-menu-item>
              <el-menu-item v-for="child in item.children" :key="child.path" :index="child.path">
                <span>{{ child.label }}</span>
              </el-menu-item>
            </el-sub-menu>
            <el-menu-item v-else :index="item.path">
              <el-icon><component :is="menuIcon(item.key)" /></el-icon>
              <span>{{ menuLabel(item) }}</span>
            </el-menu-item>
          </template>
        </el-menu>
      </div>
    </el-aside>
    <el-container>
      <el-header class="topbar">
        <div class="topbar-title">
          <strong>{{ title }}</strong>
          <span>{{ texts.t('app.topbar.subtitle', '阿拉善盟科技计划项目管理信息系统') }}</span>
        </div>
        <div class="topbar-actions">
          <el-tooltip :content="texts.t('app.message.tooltip', '站内消息')" placement="bottom">
            <el-badge :value="unreadMessages" :hidden="unreadMessages === 0" :max="99">
              <el-button :icon="Bell" circle @click="router.push('/messages')" />
            </el-badge>
          </el-tooltip>
          <el-dropdown trigger="click" @command="handleAccountCommand">
            <el-button class="account-button">
              <el-icon><User /></el-icon>
              <span class="account-name">{{ session.user?.name || session.user?.username || texts.t('app.account.default_name', '当前账号') }}</span>
              <span class="account-role">{{ roleLabel(session.role) }}</span>
              <el-icon class="el-icon--right"><ArrowDown /></el-icon>
            </el-button>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="profile" :icon="User">{{ texts.t('app.profile', '个人资料') }}</el-dropdown-item>
                <el-dropdown-item command="password" :icon="Lock">{{ texts.t('app.change_password', '修改密码') }}</el-dropdown-item>
                <el-dropdown-item divided command="switch" :icon="SwitchButton">{{ texts.t('app.switch_account', '切换账号') }}</el-dropdown-item>
                <el-dropdown-item command="logout" :icon="SwitchButton">{{ texts.t('app.logout', '退出登录') }}</el-dropdown-item>
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
import { ArrowDown, Bell, Checked, Collection, Connection, DataLine, Document, FolderChecked, FolderOpened, Guide, House, Lock, Message, OfficeBuilding, Operation, Setting, SwitchButton, Tickets, User, Warning } from '@element-plus/icons-vue'
import { api } from './api.js'
import { useSessionStore } from './store.js'
import { useTextStore } from './texts.js'

const route = useRoute()
const router = useRouter()
const session = useSessionStore()
const texts = useTextStore()
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
  dispatch_rules: Guide,
  messages: Bell,
  migration: Connection,
  operation_logs: Tickets,
  public_home: House,
  mail_center: Message,
  roles: Operation,
  security: Warning,
  dictionary_items: Collection,
  system_texts: Document,
  settings: Setting
}
const groupIconMap = {
  business: FolderOpened,
  organization: OfficeBuilding,
  review: Checked,
  portal: House,
  system: Setting,
  default: DataLine
}
const menuGroups = {
  dashboard: 'default',
  projects: 'business',
  application_batches: 'business',
  lifecycle: 'business',
  units: 'organization',
  users: 'organization',
  unit_profile: 'organization',
  reviews: 'review',
  dispatch_rules: 'review',
  acceptance: 'review',
  acceptance_admin: 'review',
  acceptance_review: 'review',
  messages: 'default',
  public_home: 'portal',
  mail_center: 'portal',
  roles: 'system',
  security: 'system',
  dictionary_items: 'system',
  system_texts: 'system',
  settings: 'system',
  migration: 'system',
  operation_logs: 'system'
}
const menuGroupLabels = {
  default: '常用入口',
  business: '项目业务',
  organization: '组织账号',
  review: '审核验收',
  portal: '门户运营',
  system: '系统管理'
}
const menuGroupOrder = ['default', 'business', 'review', 'organization', 'portal', 'system']
const menuItemOrder = {
  default: ['dashboard', 'messages'],
  business: ['projects', 'application_batches', 'lifecycle'],
  review: ['reviews', 'dispatch_rules', 'acceptance', 'acceptance_admin', 'acceptance_review'],
  organization: ['units', 'users', 'unit_profile'],
  portal: ['public_home', 'mail_center'],
  system: ['dictionary_items', 'settings', 'system_texts', 'roles', 'security', 'migration', 'operation_logs']
}
const dictionaryMenuChildren = [
  { label: '专家评分项', path: '/dictionary-items?group=expert_review_criterion', group: 'expert_review_criterion' },
  { label: '项目类别', path: '/dictionary-items?group=project_category', group: 'project_category' },
  { label: '项目类型', path: '/dictionary-items?group=project_type', group: 'project_type' },
  { label: '归口管理单位', path: '/dictionary-items?group=management_unit', group: 'management_unit' },
  { label: '所属领域', path: '/dictionary-items?group=project_field', group: 'project_field' },
  { label: '研究方向', path: '/dictionary-items?group=research_direction', group: 'research_direction' },
  { label: '项目状态', path: '/dictionary-items?group=project_status', group: 'project_status' }
]
const settingsMenuChildren = [
  { label: '站点信息', path: '/settings?group=site', group: 'site' },
  { label: '邮件 SMTP', path: '/settings?group=mail', group: 'mail' },
  { label: '上传策略', path: '/settings?group=upload', group: 'upload' },
  { label: '安全策略', path: '/settings?group=security', group: 'security' },
  { label: '审核与评分', path: '/settings?group=review', group: 'review' }
]
const titleKeys = {
  '/dashboard': ['page.dashboard.title', '运行概览'],
  '/projects': ['page.projects.title', '项目申报'],
  '/application-batches': ['page.application_batches.title', '申报批次'],
  '/acceptance': ['page.acceptance.title', '验收管理'],
  '/lifecycle': ['page.lifecycle.title', '全周期管理'],
  '/units': ['page.units.title', '单位管理'],
  '/users': ['page.users.title', '账号管理'],
  '/unit-profile': ['page.unit_profile.title', '单位资料'],
  '/reviews': ['page.reviews.title', '审核任务'],
  '/review-dispatch-rules': ['page.dispatch_rules.title', '派单规则'],
  '/messages': ['page.messages.title', '站内消息'],
  '/migration': ['page.migration.title', '迁移准备'],
  '/operation-logs': ['page.operation_logs.title', '操作日志'],
  '/public-home': ['page.public_home.title', '首页管理'],
  '/mail-center': ['page.mail_center.title', '邮件中心'],
  '/roles': ['page.roles.title', '角色权限'],
  '/security': ['page.security.title', '安全中心'],
  '/dictionary-items': ['page.dictionary_items.title', '数据字典'],
  '/system-texts': ['page.system_texts.title', '系统文案'],
  '/settings': ['page.settings.title', '系统配置']
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
const visibleMenuGroups = computed(() => {
  const groups = []
  const groupMap = new Map()

  visibleMenus.value.map(expandMenuItem).forEach((item) => {
    const key = menuGroups[item.key] || 'default'
    if (!groupMap.has(key)) {
      const group = { key, label: menuGroupLabels[key] || key, items: [] }
      groupMap.set(key, group)
      groups.push(group)
    }
    groupMap.get(key).items.push(item)
  })

  groups.forEach((group) => {
    const order = menuItemOrder[group.key] || []
    group.items.sort((a, b) => menuOrderIndex(order, a.key) - menuOrderIndex(order, b.key))
  })

  return groups.sort((a, b) => menuGroupOrder.indexOf(a.key) - menuGroupOrder.indexOf(b.key))
})
const activeGroupKey = computed(() => routeMenuMatch.value?.groupKey || visibleMenuGroups.value[0]?.key || '')
const currentMenuGroup = computed(() => visibleMenuGroups.value.find((group) => group.key === activeGroupKey.value) || visibleMenuGroups.value[0] || null)
const currentMenuItems = computed(() => currentMenuGroup.value?.items || [])
const activeMenuPath = computed(() => route.fullPath)
const defaultOpeneds = computed(() => currentMenuItems.value.filter((item) => item.children?.length).map((item) => `menu-${item.key}`))
const routeMenuMatch = computed(() => {
  for (const group of visibleMenuGroups.value) {
    for (const item of group.items) {
      if (routeMatches(item)) return { groupKey: group.key, item, label: menuLabel(item) }
      for (const child of item.children || []) {
        if (route.fullPath === child.path || (route.path === item.path && route.query.group === child.group)) {
          return { groupKey: group.key, item, child, label: `${menuLabel(item)} / ${child.label}` }
        }
      }
    }
  }

  return null
})
const title = computed(() => {
  if (routeMenuMatch.value?.label) {
    const group = visibleMenuGroups.value.find((item) => item.key === routeMenuMatch.value.groupKey)
    return [group?.label, routeMenuMatch.value.label].filter(Boolean).join(' / ')
  }

  const titleConfig = titleKeys[route.path]
  return titleConfig ? texts.t(titleConfig[0], titleConfig[1]) : '项目申报系统'
})

function expandMenuItem(item) {
  if (item.key === 'dictionary_items') {
    return { ...item, children: dictionaryMenuChildren }
  }

  if (item.key === 'settings') {
    return { ...item, children: settingsMenuChildren }
  }

  return item
}

function menuOrderIndex(order, key) {
  const index = order.indexOf(key)
  return index >= 0 ? index : 999
}

function routeMatches(item) {
  return route.path === item.path && !route.query.group
}

function menuIcon(key) {
  return iconMap[key] || DataLine
}

function groupIcon(key) {
  return groupIconMap[key] || DataLine
}

function menuLabel(item) {
  return texts.t(`menu.${item.key}`, item.label)
}

function firstMenuPath(group) {
  const firstItem = group.items[0]
  return firstItem?.children?.[0]?.path || firstItem?.path || '/dashboard'
}

function openMenuGroup(group) {
  router.push(firstMenuPath(group))
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
  texts.loadTexts()
  refreshUnreadMessages()
})

onUnmounted(() => {
  window.removeEventListener('messages:changed', refreshUnreadMessages)
  window.removeEventListener('auth:expired', handleSessionExpired)
})
</script>
