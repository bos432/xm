import { createRouter, createWebHistory } from 'vue-router'
import { useSessionStore } from './store.js'
import PublicHomeView from './views/PublicHomeView.vue'
import LoginView from './views/LoginView.vue'
import DashboardView from './views/DashboardView.vue'
import ProjectsView from './views/ProjectsView.vue'
import ReviewTasksView from './views/ReviewTasksView.vue'
import SettingsView from './views/SettingsView.vue'
import PublicHomeManageView from './views/PublicHomeManageView.vue'
import MessagesView from './views/MessagesView.vue'
import MigrationView from './views/MigrationView.vue'
import OperationLogsView from './views/OperationLogsView.vue'
import UnitsView from './views/UnitsView.vue'
import DictionaryItemsView from './views/DictionaryItemsView.vue'
import UsersView from './views/UsersView.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', component: PublicHomeView, meta: { public: true } },
    { path: '/login', component: LoginView, meta: { guest: true } },
    { path: '/dashboard', component: DashboardView, meta: { permission: 'view_dashboard' } },
    { path: '/projects', component: ProjectsView, meta: { permission: 'view_projects' } },
    { path: '/units', component: UnitsView, meta: { permission: 'manage_units' } },
    { path: '/users', component: UsersView, meta: { permission: 'manage_users' } },
    { path: '/unit-profile', component: UnitsView, meta: { permission: 'view_own_unit' } },
    { path: '/reviews', component: ReviewTasksView, meta: { permission: 'review_projects' } },
    { path: '/messages', component: MessagesView, meta: { permission: 'view_messages' } },
    { path: '/migration', component: MigrationView, meta: { permission: 'view_migration' } },
    { path: '/operation-logs', component: OperationLogsView, meta: { permission: 'view_operation_logs' } },
    { path: '/public-home', component: PublicHomeManageView, meta: { permission: 'manage_settings' } },
    { path: '/dictionary-items', component: DictionaryItemsView, meta: { permission: 'manage_settings' } },
    { path: '/settings', component: SettingsView, meta: { permission: 'manage_settings' } }
  ]
})

router.beforeEach(async (to) => {
  const session = useSessionStore()
  if (to.meta.public) return true
  if (session.token && !session.user) await session.loadMe().catch(() => {
    session.token = ''
    session.user = null
    localStorage.removeItem('pas_token')
  })
  if (!to.meta.guest && !session.token) return '/login'
  if (to.meta.guest && session.token) return '/dashboard'
  if (to.meta.permission && !session.can(to.meta.permission)) return '/'
})

export default router
