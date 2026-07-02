import { defineStore } from 'pinia'
import { api } from './api.js'

export const defaultTexts = {
  'app.brand.title': '科技项目管理',
  'app.brand.subtitle': '公共服务后台',
  'app.topbar.subtitle': '阿拉善盟科技计划项目管理信息系统',
  'app.account.default_name': '当前账号',
  'app.message.tooltip': '站内消息',
  'app.profile': '个人资料',
  'app.change_password': '修改密码',
  'app.switch_account': '切换账号',
  'app.logout': '退出登录',
  'menu.dashboard': '运行概览',
  'menu.projects': '项目申报',
  'menu.application_batches': '申报批次',
  'menu.acceptance': '验收管理',
  'menu.acceptance_admin': '验收管理',
  'menu.lifecycle': '全周期管理',
  'menu.units': '单位管理',
  'menu.users': '账号管理',
  'menu.unit_profile': '单位资料',
  'menu.reviews': '审核任务',
  'menu.dispatch_rules': '派单规则',
  'menu.messages': '站内消息',
  'menu.public_home': '首页管理',
  'menu.mail_center': '邮件中心',
  'menu.roles': '角色权限',
  'menu.security': '安全中心',
  'menu.dictionary_items': '数据字典',
  'menu.system_texts': '系统文案',
  'menu.settings': '系统配置',
  'menu.migration': '迁移准备',
  'menu.operation_logs': '操作日志',
  'page.dashboard.title': '运行概览',
  'page.projects.title': '项目申报',
  'page.application_batches.title': '申报批次',
  'page.acceptance.title': '验收管理',
  'page.lifecycle.title': '全周期管理',
  'page.units.title': '单位管理',
  'page.users.title': '账号管理',
  'page.unit_profile.title': '单位资料',
  'page.reviews.title': '审核任务',
  'page.dispatch_rules.title': '派单规则',
  'page.messages.title': '站内消息',
  'page.public_home.title': '首页管理',
  'page.mail_center.title': '邮件中心',
  'page.roles.title': '角色权限',
  'page.security.title': '安全中心',
  'page.dictionary_items.title': '数据字典',
  'page.system_texts.title': '系统文案',
  'page.settings.title': '系统配置',
  'page.migration.title': '迁移准备',
  'page.operation_logs.title': '操作日志',
  'dashboard.workflow.title': '科研项目申报与管理全流程',
  'dashboard.workflow.description': '按业务全生命周期展示，并标明系统内办理和线下办理节点',
  'dashboard.workflow.system': '系统内办理',
  'dashboard.workflow.offline': '线下办理/人工决策',
  'dashboard.workflow.online_note': '已上线：注册审核、批次申报、附件、分级审核、合同任务书、实施进展、整改闭环、专家认证、验收和延期。',
  'dashboard.workflow.offline_note': '线下：局领导办公会、经费拨付、部分立项决策仍按现实业务办理。',
  'dashboard.workflow.tab.lifecycle': '业务全生命周期',
  'dashboard.workflow.tab.application': '系统申报审核',
  'dashboard.workflow.tab.acceptance': '系统验收审核',
  'lifecycle.page.subtitle': '合同任务书、项目实施进展、整改闭环和专家认证',
  'lifecycle.filter.keyword': '项目/单位/标题',
  'lifecycle.filter.status': '状态',
  'lifecycle.action.refresh': '刷新',
  'lifecycle.task_books.tab': '合同任务书',
  'lifecycle.task_books.tip': '单位填报任务书，管理员审核通过后作为立项后管理依据。',
  'lifecycle.task_books.create': '新增任务书',
  'lifecycle.progress.tab': '实施进展',
  'lifecycle.progress.tip': '单位定期提交项目实施情况，管理员确认或退回补正。',
  'lifecycle.progress.create': '新增进展',
  'lifecycle.rectifications.tab': '整改闭环',
  'lifecycle.rectifications.tip': '管理员发起整改要求，单位提交整改说明，管理员审核闭环。',
  'lifecycle.rectifications.create': '发起整改',
  'lifecycle.rectifications.submit_response': '提交整改',
  'lifecycle.certifications.tab': '专家认证',
  'lifecycle.certifications.tip': '专家提交专业方向和资质说明，管理员审核后作为专家库基础信息。',
  'lifecycle.certifications.create': '提交认证',
  'lifecycle.action.detail': '详情',
  'lifecycle.action.edit': '编辑',
  'lifecycle.action.submit': '提交',
  'lifecycle.action.review': '审核',
  'lifecycle.column.project': '项目',
  'lifecycle.column.unit': '单位',
  'lifecycle.column.task_title': '任务书标题',
  'lifecycle.column.status': '状态',
  'lifecycle.column.submitted_at': '提交时间',
  'lifecycle.column.actions': '操作',
  'lifecycle.column.period': '周期',
  'lifecycle.column.progress_date': '进展日期',
  'lifecycle.column.summary': '进展摘要',
  'lifecycle.column.rectification_title': '整改事项',
  'lifecycle.column.due_date': '截止日期',
  'lifecycle.column.expert_username': '专家账号',
  'lifecycle.column.name': '姓名',
  'lifecycle.column.organization': '单位/机构',
  'lifecycle.column.specialty': '专业方向',
  'lifecycle.column.professional_title': '职称',
  'migration.intro': '迁移准备用于旧系统历史数据导入前体检：先备份旧库和 upload 附件，生成 dry-run 报告，处理缺失文件/字段映射/账号冲突后，再执行正式迁移。新系统日常使用不依赖这里。',
  'settings.public_home.card_title': '首页内容',
  'settings.public_home.card_body': '导航、公告、下载、服务事项和 logo/banner 请进入首页管理维护。',
  'settings.public_home.button': '进入首页管理',
  'public.toolbar.help': '在线帮助',
  'public.toolbar.sitemap': '全站导航',
  'public.toolbar.warning': '本平台为互联网非涉密平台，请勿上传涉密资料',
  'auth.login': '登录',
  'auth.forgot_password': '忘记密码',
  'auth.register_unit': '新单位注册',
  'project.action.detail': '详情',
  'project.action.lifecycle': '全周期',
  'project.action.more': '更多',
  'project.action.edit': '编辑',
  'project.action.files': '附件',
  'project.action.submit': '提交',
  'project.action.withdraw': '撤回',
  'project.action.extension': '申请延期',
  'project.action.enter_acceptance': '进入验收',
  'project.action.close': '关闭验收',
  'project.action.review_logs': '审核记录',
  'project.action.operation_logs': '操作日志',
  'project.action.delete': '删除',
  'acceptance.tab.pending': '待处理',
  'acceptance.tab.reviewed': '已处理',
  'acceptance.tab.visible': '全部可见'
}

export const useTextStore = defineStore('texts', {
  state: () => ({
    items: { ...defaultTexts },
    loaded: false
  }),
  getters: {
    t: (state) => (key, fallback = '') => {
      if (Object.prototype.hasOwnProperty.call(state.items, key)) {
        return state.items[key]
      }

      return fallback
    }
  },
  actions: {
    async loadTexts(force = false) {
      if (this.loaded && !force) return

      try {
        const result = await api('/public/system-texts')
        this.items = { ...defaultTexts, ...(result.texts || {}) }
      } catch {
        this.items = { ...defaultTexts }
      } finally {
        this.loaded = true
      }
    }
  }
})
