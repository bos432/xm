import { expect, test } from '@playwright/test'

const roles = [
  ['unit', 'E2E_UNIT_USERNAME', 'E2E_UNIT_PASSWORD'],
  ['county', 'E2E_COUNTY_USERNAME', 'E2E_COUNTY_PASSWORD'],
  ['department', 'E2E_DEPARTMENT_USERNAME', 'E2E_DEPARTMENT_PASSWORD'],
  ['expert', 'E2E_EXPERT_USERNAME', 'E2E_EXPERT_PASSWORD'],
  ['admin', 'E2E_ADMIN_USERNAME', 'E2E_ADMIN_PASSWORD'],
  ['super_admin', 'E2E_SUPER_ADMIN_USERNAME', 'E2E_SUPER_ADMIN_PASSWORD']
]

function required(name) {
  const value = process.env[name]
  test.skip(!value, `Missing ${name}`)
  return value
}

async function answerCaptcha(page) {
  const placeholder = page.getByPlaceholder(/加载中|\d+\s*\+\s*\d+\s*=/).first()
  const text = await placeholder.getAttribute('placeholder')
  const nums = (text || '').match(/\d+/g)?.map(Number) || []
  return nums.reduce((sum, item) => sum + item, 0)
}

test('public homepage exposes portal login and content sections', async ({ page }) => {
  await page.goto('/')
  await expect(page.getByText('新单位注册').first()).toBeVisible()
  await expect(page.getByText('通知公告').first()).toBeVisible()
  await expect(page.getByText('资料下载').first()).toBeVisible()
})

for (const [role, usernameEnv, passwordEnv] of roles) {
  test(`${role} can log in and see dashboard`, async ({ page }) => {
    const username = required(usernameEnv)
    const password = required(passwordEnv)

    await page.goto('/')
    await page.getByLabel('登录名').fill(username)
    await page.getByLabel('密码').fill(password)
    await page.getByLabel('验证码').fill(String(await answerCaptcha(page)))
    await page.getByRole('button', { name: /登录系统|登录/ }).click()

    await expect(page).toHaveURL(/\/dashboard/)
    await expect(page.getByText('运行概览').first()).toBeVisible()
  })
}

test('project and acceptance regression filters can be opened', async ({ page }) => {
  const username = required('E2E_SUPER_ADMIN_USERNAME')
  const password = required('E2E_SUPER_ADMIN_PASSWORD')
  const stamp = process.env.E2E_STAMP || 'E2E-20260630-103223'

  await page.goto('/')
  await page.getByLabel('登录名').fill(username)
  await page.getByLabel('密码').fill(password)
  await page.getByLabel('验证码').fill(String(await answerCaptcha(page)))
  await page.getByRole('button', { name: /登录系统|登录/ }).click()

  await page.goto(`/projects?keyword=${encodeURIComponent(stamp)}`)
  await expect(page.getByPlaceholder('按项目、单位、账号搜索')).toHaveValue(stamp)

  await page.goto(`/acceptance?scope=reviewed&keyword=${encodeURIComponent(stamp)}`)
  await expect(page.getByPlaceholder('项目/单位')).toHaveValue(stamp)
})
