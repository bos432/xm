import { expect, test } from '@playwright/test'

test.describe.configure({ mode: 'serial' })

const stamp = process.env.E2E_STAMP || 'E2E-20260630-103223'
const sampleProjectId = process.env.E2E_PROJECT_ID || '5'

const roles = [
  {
    role: 'unit',
    usernameEnv: 'E2E_UNIT_USERNAME',
    passwordEnv: 'E2E_UNIT_PASSWORD',
    menus: ['运行概览', '项目申报', '验收管理', '全周期管理']
  },
  {
    role: 'county',
    usernameEnv: 'E2E_COUNTY_USERNAME',
    passwordEnv: 'E2E_COUNTY_PASSWORD',
    menus: ['运行概览', '项目申报', '验收管理', '审核任务', '全周期管理']
  },
  {
    role: 'department',
    usernameEnv: 'E2E_DEPARTMENT_USERNAME',
    passwordEnv: 'E2E_DEPARTMENT_PASSWORD',
    menus: ['运行概览', '项目申报', '验收管理', '审核任务', '全周期管理']
  },
  {
    role: 'expert',
    usernameEnv: 'E2E_EXPERT_USERNAME',
    passwordEnv: 'E2E_EXPERT_PASSWORD',
    menus: ['运行概览', '项目申报', '验收管理', '审核任务', '全周期管理']
  },
  {
    role: 'admin',
    usernameEnv: 'E2E_ADMIN_USERNAME',
    passwordEnv: 'E2E_ADMIN_PASSWORD',
    menus: ['运行概览', '项目申报', '申报批次', '验收管理', '全周期管理', '单位管理', '账号管理']
  },
  {
    role: 'super_admin',
    usernameEnv: 'E2E_SUPER_ADMIN_USERNAME',
    passwordEnv: 'E2E_SUPER_ADMIN_PASSWORD',
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

for (const account of roles) {
  test(`${account.role} can log in and open project lifecycle and acceptance history`, async ({ page }) => {
    await loginFromHomepage(page, account)
    await expect(page.getByText('运行概览').first()).toBeVisible()
    for (const menu of account.menus) {
      await expect(page.getByText(menu).first()).toBeVisible()
    }
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
    await saveScreenshot(page, `${account.role}-lifecycle`)

    await page.goto(`/acceptance?scope=reviewed&keyword=${encodeURIComponent(stamp)}`)
    await expect(page.getByText(/验收管理|已处理|已关闭|closed/).first()).toBeVisible()
    await saveScreenshot(page, `${account.role}-acceptance-reviewed`)
  })
}

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
