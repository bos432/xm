import { expect, test } from '@playwright/test'
import { e2eRoleCredentials } from '../../frontend/src/e2e-role-config.js'

test.describe.configure({ mode: 'serial' })

const stamp = process.env.E2E_STAMP || 'E2E-20260630-103223'
const sampleProjectId = process.env.E2E_PROJECT_ID || '5'

const roles = [
  {
    role: 'unit',
    ...e2eRoleCredentials.unit,
    menus: ['运行概览', '项目申报', '验收管理', '全周期管理'],
    hiddenTexts: ['专家认证']
  },
  {
    role: 'county',
    ...e2eRoleCredentials.county,
    menus: ['运行概览', '项目申报', '验收管理', '审核任务', '全周期管理'],
    hiddenTexts: ['专家认证']
  },
  {
    role: 'department',
    ...e2eRoleCredentials.department,
    menus: ['运行概览', '项目申报', '验收管理', '审核任务', '全周期管理'],
    hiddenTexts: ['专家认证']
  },
  {
    role: 'expert',
    ...e2eRoleCredentials.expert,
    menus: ['运行概览', '项目申报', '验收管理', '审核任务', '全周期管理']
  },
  {
    role: 'admin',
    ...e2eRoleCredentials.admin,
    menus: ['运行概览', '项目申报', '申报批次', '验收管理', '全周期管理', '单位管理', '账号管理']
  },
  {
    role: 'super_admin',
    ...e2eRoleCredentials.super_admin,
    menus: ['首页管理', '邮件中心', '角色权限', '安全中心', '系统文案', '系统配置']
  }
]

function credentials(account) {
  const username = process.env[account.usernameEnv]
  const password = process.env[account.passwordEnv]
  test.skip(!username || !password, `Missing ${account.usernameEnv} or ${account.passwordEnv}`)

  return { username, password }
}

function answerCaptcha(question) {
  const numbers = (question || '').match(/\d+/g)?.map(Number) || []

  return numbers.reduce((sum, item) => sum + item, 0)
}

async function loginFromHomepage(page, account) {
  const { username, password } = credentials(account)
  await page.goto('/')
  await page.evaluate(() => localStorage.clear())
  await page.getByLabel('登录名').fill(username)
  await page.getByLabel('密码').fill(password)

  const captcha = page.getByLabel('验证码')
  await captcha.fill(String(answerCaptcha(await captcha.getAttribute('placeholder'))))
  await page.getByRole('button', { name: /登录系统|登录/ }).click()
  await expect(page).toHaveURL(/\/dashboard/)
  const profile = await page.evaluate(async () => {
    const token = localStorage.getItem('pas_token')
    const response = await fetch('/api/auth/me', {
      headers: { Authorization: `Bearer ${token}`, Accept: 'application/json' }
    })
    return { ok: response.ok, user: await response.json() }
  })
  expect(profile.ok).toBeTruthy()
  expect(profile.user.role).toBe(account.expectedRole)
}

async function loginByApi(page, account) {
  const { username, password } = credentials(account)
  const captchaResponse = await page.request.get('/api/auth/captcha')
  expect(captchaResponse.ok()).toBeTruthy()
  const captcha = await captchaResponse.json()
  const login = await page.request.post('/api/auth/login', {
    data: {
      username,
      password,
      captcha_id: captcha.captcha_id,
      captcha_answer: answerCaptcha(captcha.question)
    }
  })

  expect(login.ok()).toBeTruthy()
  return login.json()
}

async function saveScreenshot(page, name) {
  await page.screenshot({ path: test.info().outputPath(`${name}.png`), fullPage: true })
}

test('public homepage exposes portal login and no duplicate old registration link', async ({ page }) => {
  await page.goto('/')
  await expect(page.getByRole('link', { name: '新单位注册' })).toBeVisible()
  await expect(page.getByRole('link', { name: /^单位注册$/ })).toHaveCount(0)
  await expect(page.getByText('通知公告').first()).toBeVisible()
  await expect(page.getByText('资料下载').first()).toBeVisible()
  await saveScreenshot(page, 'public-home')
})

test('public and anonymous API probes return safe responses', async ({ request }) => {
  for (const path of ['/api/auth/captcha', '/api/public/homepage']) {
    const response = await request.get(path)
    expect(response.status(), path).toBe(200)
    expect(response.headers()['content-type'], path).toContain('application/json')
  }

  const protectedPaths = [
    '/api/auth/me',
    '/api/projects',
    '/api/reviews/tasks',
    '/api/settings/groups',
    '/api/users',
    '/api/security/events'
  ]

  for (const path of protectedPaths) {
    const response = await request.get(path, { headers: { accept: '' } })
    expect(response.status(), path).toBe(401)
    expect(response.headers()['content-type'], path).toContain('application/json')
    await expect(response.json(), path).resolves.toMatchObject({ message: 'Unauthenticated.' })
  }

  for (const path of ['/.env', '/storage/logs/laravel.log']) {
    const response = await request.get(path)
    expect(response.status(), path).toBe(404)
  }
})

for (const account of roles) {
  test(`${account.role} can log in and open project lifecycle and acceptance history`, async ({ page }) => {
    await loginFromHomepage(page, account)
    await expect(page.getByText('运行概览').first()).toBeVisible()
    await saveScreenshot(page, `${account.role}-dashboard`)

    await page.goto(`/projects?keyword=${encodeURIComponent(stamp)}`)
    await expect(page.getByText(stamp).first()).toBeVisible()
    await expect(page.getByRole('columnheader', { name: '序号' }).first()).toBeVisible()
    await saveScreenshot(page, `${account.role}-projects-filter`)

    if (account.role === 'unit') {
      await page.getByRole('button', { name: '新建项目' }).click()
      await expect(page.getByText('创建项目申报草稿')).toBeVisible()
      await expect(page.getByText('预算金额（万元）')).toBeVisible()
      await expect(page.getByText('系统保存金额')).toBeVisible()
      await saveScreenshot(page, 'unit-project-workbench')
      await page.getByRole('button', { name: '关闭' }).click()
    }

    await page.goto(`/lifecycle?project_id=${encodeURIComponent(sampleProjectId)}`)
    await expect(page.getByText(/全周期管理|合同任务书|实施进展/).first()).toBeVisible()
    for (const text of account.hiddenTexts || []) {
      await expect(page.getByText(text).first()).toHaveCount(0)
    }
    await saveScreenshot(page, `${account.role}-lifecycle`)

    await page.goto(`/acceptance?scope=reviewed&keyword=${encodeURIComponent(stamp)}`)
    await expect(page.getByText(/验收管理|已处理|已关闭|closed/).first()).toBeVisible()
    await saveScreenshot(page, `${account.role}-acceptance-reviewed`)
  })
}

test('lifecycle expert certification permissions match role configuration', async ({ page }) => {
  for (const account of roles.filter((item) => ['unit', 'county', 'department', 'expert'].includes(item.role))) {
    const login = await loginByApi(page, account)
    const response = await page.request.get('/api/lifecycle/expert-certifications', {
      headers: { Authorization: `Bearer ${login.token}` }
    })

    if (account.role === 'expert') {
      expect(response.status(), `${account.role} should be allowed`).toBe(200)
    } else {
      expect(response.status(), `${account.role} should be forbidden`).toBe(403)
    }
  }
})

test('super admin can inspect homepage assets and security center', async ({ page }) => {
  await loginFromHomepage(page, roles.find((item) => item.role === 'super_admin'))

  await page.goto('/public-home')
  await page.getByRole('tab', { name: '品牌素材' }).click()
  await expect(page.getByText('首页 Logo')).toBeVisible()
  await expect(page.getByText('站点图标 Favicon')).toBeVisible()
  await expect(page.getByText('首页 Banner')).toBeVisible()
  await expect(page.getByText('公开首页当前批次')).toBeVisible()
  await saveScreenshot(page, 'super-admin-home-assets')

  await page.goto('/security')
  await expect(page.getByText(/安全中心|登录限流|安全事件/).first()).toBeVisible()
  await saveScreenshot(page, 'super-admin-security')
})
