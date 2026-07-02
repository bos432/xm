import { createRouter, createWebHistory } from 'vue-router'
import { useSessionStore } from './store.js'
import PublicHomeView from './views/PublicHomeView.vue'
import LoginView from './views/LoginView.vue'
import RegisterUnitView from './views/RegisterUnitView.vue'
import ForgotPasswordView from './views/ForgotPasswordView.vue'
import ResetPasswordView from './views/ResetPasswordView.vue'

const AcceptanceView = () => import('./views/AcceptanceView.vue')
const ApplicationBatchesView = () => import('./views/ApplicationBatchesView.vue')
const DashboardView = () => import('./views/DashboardView.vue')
const DictionaryItemsView = () => import('./views/DictionaryItemsView.vue')
const LifecycleView = () => import('./views/LifecycleView.vue')
const MailCenterView = () => import('./views/MailCenterView.vue')
const MessagesView = () => import('./views/MessagesView.vue')
const MigrationView = () => import('./views/MigrationView.vue')
const OperationLogsView = () => import('./views/OperationLogsView.vue')
const ProjectsView = () => import('./views/ProjectsView.vue')
const PublicHomeManageView = () => import('./views/PublicHomeManageView.vue')
const ReviewTasksView = () => import('./views/ReviewTasksView.vue')
const ReviewDispatchRulesView = () => import('./views/ReviewDispatchRulesView.vue')
const RolesView = () => import('./views/RolesView.vue')
const SecurityCenterView = () => import('./views/SecurityCenterView.vue')
const SettingsView = () => import('./views/SettingsView.vue')
const SystemTextsView = () => import('./views/SystemTextsView.vue')
const UnitsView = () => import('./views/UnitsView.vue')
const UsersView = () => import('./views/UsersView.vue')
const chunkReloadFlag = 'pas_chunk_reload_attempted'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', component: PublicHomeView, meta: { public: true } },
    { path: '/login', component: LoginView, meta: { guest: true } },
    { path: '/register', component: RegisterUnitView, meta: { guest: true } },
    { path: '/forgot-password', component: ForgotPasswordView, meta: { guest: true } },
    { path: '/reset-password', component: ResetPasswordView, meta: { guest: true } },
    { path: '/dashboard', component: DashboardView, meta: { permission: 'view_dashboard' } },
    { path: '/projects', component: ProjectsView, meta: { permission: 'view_projects' } },
    { path: '/application-batches', component: ApplicationBatchesView, meta: { permission: 'manage_application_batches' } },
    { path: '/acceptance', component: AcceptanceView, meta: { permissionAny: ['submit_acceptance', 'manage_acceptance', 'review_acceptance'] } },
    { path: '/lifecycle', component: LifecycleView, meta: { permission: 'view_lifecycle' } },
    { path: '/units', component: UnitsView, meta: { permission: 'manage_units' } },
    { path: '/users', component: UsersView, meta: { permission: 'manage_users' } },
    { path: '/unit-profile', component: UnitsView, meta: { permission: 'view_own_unit' } },
    { path: '/reviews', component: ReviewTasksView, meta: { permission: 'review_projects' } },
    { path: '/review-dispatch-rules', component: ReviewDispatchRulesView, meta: { permission: 'manage_dispatch_rules' } },
    { path: '/messages', component: MessagesView, meta: { permission: 'view_messages' } },
    { path: '/migration', component: MigrationView, meta: { permission: 'view_migration' } },
    { path: '/operation-logs', component: OperationLogsView, meta: { permission: 'view_operation_logs' } },
    { path: '/public-home', component: PublicHomeManageView, meta: { permission: 'manage_home_content' } },
    { path: '/mail-center', component: MailCenterView, meta: { permission: 'manage_mail' } },
    { path: '/roles', component: RolesView, meta: { permission: 'manage_roles' } },
    { path: '/security', component: SecurityCenterView, meta: { permission: 'manage_security' } },
    { path: '/dictionary-items', component: DictionaryItemsView, meta: { permission: 'manage_dictionaries' } },
    { path: '/system-texts', component: SystemTextsView, meta: { permission: 'manage_system_texts' } },
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
  if (to.meta.permissionAny && !to.meta.permissionAny.some((permission) => session.can(permission))) return '/'
})

router.afterEach(() => {
  window.sessionStorage.removeItem(chunkReloadFlag)
})

router.onError((error) => {
  const message = String(error?.message || error || '')
  const isChunkLoadFailure = /Failed to fetch dynamically imported module|Importing a module script failed|error loading dynamically imported module|Loading chunk/i.test(message)

  if (!isChunkLoadFailure || window.sessionStorage.getItem(chunkReloadFlag)) return
  window.sessionStorage.setItem(chunkReloadFlag, '1')
  window.location.reload()
})

export default router
