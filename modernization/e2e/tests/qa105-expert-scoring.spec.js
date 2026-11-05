import { expect, test } from '@playwright/test'
import { readFile } from 'node:fs/promises'
import path from 'node:path'

test('three assigned experts read full materials and score through the actual UI without early transition', async ({ browser, request }) => {
  test.setTimeout(120_000)
  const credentialsPath = process.env.QA105_CREDENTIALS
  test.skip(!credentialsPath, 'Explicit isolated fixture required')
  expect(process.env.E2E_BASE_URL).toBe('http://127.0.0.1:18742')
  const manifest = JSON.parse(await readFile(credentialsPath, 'utf8'))
  expect(manifest.base_url).toBe(process.env.E2E_BASE_URL)
  const fixture = JSON.parse(await readFile(path.join(path.dirname(credentialsPath), 'qa105-project.json'), 'utf8'))
  const tokens = []
  const errors = []
  async function login(account) {
    const captcha = await (await request.get('/api/auth/captcha')).json()
    const response = await request.post('/api/auth/login', { data: {
      username: account.username, password: account.password, captcha_id: captcha.captcha_id,
      captcha_answer: captcha.question.match(/\d+/g).map(Number).reduce((sum, value) => sum + value, 0)
    } })
    expect(response.status()).toBe(200)
    const token = (await response.json()).token
    tokens.push(token)
    return token
  }
  try {
    const owner = await login(manifest.accounts.unit)
    for (const [index, label] of ['expert', 'expert_2', 'expert_3'].entries()) {
      const token = await login(manifest.accounts[label])
      const context = await browser.newContext({ baseURL: manifest.base_url, viewport: { width: 1440, height: 1000 } })
      try {
        await context.addInitScript(value => localStorage.setItem('pas_token', value), token)
        const page = await context.newPage()
        page.setDefaultTimeout(15_000)
        page.on('pageerror', error => errors.push(String(error)))
        await page.goto('/reviews')
        await expect(page.getByText(fixture.title).first()).toBeVisible()
        const row = page.getByRole('row').filter({ hasText: fixture.title }).first()
        await row.getByRole('button', { name: '详情', exact: true }).click()
        const drawer = page.locator('.el-drawer').filter({ hasText: '审核项目详情' })
        await expect(drawer.getByText('QA105 full research overview', { exact: true })).toBeVisible()
        await expect(drawer.getByText('QA105 detailed research objectives', { exact: true })).toBeVisible()
        await page.screenshot({ path: test.info().outputPath(`${label}-full-detail.png`), fullPage: true })
        await drawer.locator('.el-drawer__close-btn').click()
        await expect(drawer).toBeHidden()
        await expect(page.locator('.el-overlay:visible')).toHaveCount(0)
        await row.getByRole('button', { name: '审核处理', exact: true }).click()
        const dialog = page.getByRole('dialog', { name: '审核处理', exact: true })
        await expect(dialog).toBeVisible()
        await dialog.locator('.el-collapse-item__header').filter({ hasText: '项目详情和申报材料' }).click()
        await expect(dialog.getByText('QA105 innovation evidence', { exact: true })).toBeVisible()
        for (const criterion of fixture.criteria) {
          await dialog.getByRole('row').filter({ hasText: criterion.label }).getByRole('spinbutton').fill(String(criterion.max_score))
        }
        await dialog.getByRole('button', { name: '提交审核', exact: true }).focus()
        await expect(dialog.locator('.criteria-total')).toHaveText('合计：100 / 100 分')
        await page.screenshot({ path: test.info().outputPath(`${label}-scoring-100.png`), fullPage: true })
        const submitted = page.waitForResponse(response => response.url().endsWith(`/api/projects/${fixture.id}/reviews`) && response.request().method() === 'POST')
        await dialog.getByRole('button', { name: '提交审核', exact: true }).click()
        expect((await submitted).status()).toBe(201)
        await expect(dialog).toBeHidden()
        const auth = { Authorization: `Bearer ${token}` }
        const pending = await request.get(`/api/reviews/tasks?project_id=${fixture.id}`, { headers: auth })
        expect(pending.status()).toBe(200)
        expect((await pending.json()).data).toHaveLength(0)
        const detail = await request.get(`/api/projects/${fixture.id}`, { headers: { Authorization: `Bearer ${owner}` } })
        expect(detail.status()).toBe(200)
        const project = await detail.json()
        expect(project.expert_review_summary.reviewed_count).toBe(index + 1)
        expect(project.expert_review_summary.pending_count).toBe(2 - index)
        expect(project.current_reviewer_role).toBe(index === 2 ? 'admin' : 'expert')
      } finally {
        await context.close()
      }
    }
    expect(errors).toEqual([])
  } finally {
    for (const token of tokens) {
      try {
        const response = await request.post('/api/auth/logout', { headers: { Authorization: `Bearer ${token}` }, timeout: 5000 })
        expect(response.status()).toBe(204)
      } catch (error) {
        if (test.info().status === 'passed') throw error
        await test.info().attach('logout-cleanup-error', { body: String(error), contentType: 'text/plain' })
      }
    }
  }
})
