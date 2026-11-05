import { expect, test } from '@playwright/test'
import { readFile, writeFile } from 'node:fs/promises'
import path from 'node:path'

test.describe.configure({ mode: 'serial' })

test('isolated applicant creates saves submits and resubmits after county return before department dispatch', async ({ browser, request }) => {
  test.setTimeout(180_000)
  test.skip(process.env.QA118_SUBMISSION !== '1', 'Explicit isolated submission fixture required')
  expect(process.env.E2E_BASE_URL).toBe('http://127.0.0.1:18742')
  const manifestPath = process.env.QA105_CREDENTIALS
  expect(manifestPath).toBeTruthy()
  const manifest = JSON.parse(await readFile(manifestPath, 'utf8'))
  expect(manifest.base_url).toBe(process.env.E2E_BASE_URL)
  const fixtureName = process.env.QA105_FIXTURE
  expect(fixtureName).toMatch(/^qa[0-9]+-project\.json$/)
  const fixturePath = path.join(path.dirname(manifestPath), fixtureName)
  const sessions = []
  const errors = []
  const title = `QA118-SUBMISSION-${Date.now()}`
  async function asRole(role) {
    const account = manifest.accounts[role]
    const captcha = await (await request.get('/api/auth/captcha')).json()
    const response = await request.post('/api/auth/login', { data: { username: account.username, password: account.password, captcha_id: captcha.captcha_id, captcha_answer: captcha.question.match(/[0-9]+/g).map(Number).reduce((a, b) => a + b, 0) } })
    expect(response.status()).toBe(200)
    const token = (await response.json()).token
    const context = await browser.newContext({ baseURL: manifest.base_url, viewport: { width: 1440, height: 1000 } })
    await context.addInitScript(value => localStorage.setItem('pas_token', value), token)
    const page = await context.newPage()
    page.setDefaultTimeout(15_000)
    page.on('pageerror', e => errors.push(String(e)))
    const session = { page, context, headers: { Authorization: `Bearer ${token}` } }
    sessions.push(session)
    return session
  }
  const waitWrite = (page, suffix, method = 'POST') => page.waitForResponse(r => r.url().endsWith(suffix) && r.request().method() === method)
  async function submit(page, drawer, id) {
    await drawer.getByRole('button', { name: '提交审核', exact: true }).click()
    const confirm = page.getByRole('dialog', { name: '提交项目', exact: true })
    const response = waitWrite(page, `/api/projects/${id}/submit`)
    await expect(confirm).toBeVisible()
    await confirm.getByRole('button', { name: /^(确定|OK)$/ }).click()
    expect((await response).status()).toBe(200)
    await page.getByRole('button', { name: '我知道了', exact: true }).click()
    await expect(drawer).toBeHidden()
  }
  try {
    const unit = await asRole('unit')
    await unit.page.goto('/projects')
    await unit.page.getByRole('button', { name: '新建项目', exact: true }).click()
    let drawer = unit.page.getByRole('dialog', { name: '新建申报项目', exact: true })
    await expect(drawer).toBeVisible()
    await drawer.getByRole('button', { name: '保存草稿', exact: true }).click()
    await expect(unit.page.getByText('请先填写项目名称', { exact: true })).toBeVisible()
    await drawer.locator('.el-form-item').filter({ hasText: '项目名称' }).getByRole('textbox').fill(title)
    for (const [field, option] of [['项目类别', 'QA Category'], ['项目类型', 'QA Type']]) {
      const select = drawer.locator('.el-form-item').filter({ hasText: field }).getByRole('combobox')
      await select.fill(option)
      await unit.page.getByRole('option', { name: option, exact: true }).click()
    }
    await drawer.locator('.el-form-item').filter({ hasText: '预算金额（万元）' }).getByRole('spinbutton').fill('12.5')
    await drawer.getByRole('tab', { name: '项目概述', exact: true }).click()
    for (const [label, text] of [['项目摘要', 'QA118 submitted research summary'], ['国内外研究进展与产业发展现状', 'QA105 full research overview'], ['研究目标与主要内容', 'QA105 detailed research objectives'], ['创新点与预期成果', 'QA105 innovation evidence']]) {
      await drawer.locator('.el-form-item').filter({ hasText: label }).locator('[contenteditable=true]').fill(text)
    }
    const saved = waitWrite(unit.page, '/api/projects')
    await drawer.getByRole('button', { name: '保存草稿', exact: true }).click()
    const saveResponse = await saved
    expect(saveResponse.status()).toBe(201)
    const created = await saveResponse.json()
    expect(created.status).toBe('draft')
    expect(Number(created.budget_amount)).toBe(125000)
    drawer = unit.page.getByRole('dialog', { name: '编辑申报项目', exact: true })
    await expect(drawer).toBeVisible()
    await unit.page.screenshot({ path: test.info().outputPath('unit-saved-draft.png'), fullPage: true })
    const county = await asRole('county')
    const countyDraft = await request.get(`/api/projects/${created.id}`, { headers: county.headers })
    expect(countyDraft.status()).toBe(403)
    await submit(unit.page, drawer, created.id)
    await county.page.goto(`/reviews?project_id=${created.id}`)
    let review = county.page.getByRole('dialog', { name: '审核处理', exact: true })
    await expect(review).toBeVisible()
    await review.locator('.el-collapse-item__header').click()
    await expect(review.getByText('QA105 detailed research objectives', { exact: true })).toBeVisible()
    await expect(review.getByRole('spinbutton')).toHaveCount(0)
    await review.getByText('退回', { exact: true }).click()
    await review.locator('[contenteditable=true]').fill('QA118 clarify research plan before resubmission')
    let response = waitWrite(county.page, `/api/projects/${created.id}/reviews`)
    await review.getByRole('button', { name: '提交审核', exact: true }).click()
    expect((await response).status()).toBe(201)
    await expect(review).toBeHidden()
    await unit.page.goto(`/projects?keyword=${encodeURIComponent(title)}`)
    const row = unit.page.getByRole('row').filter({ hasText: title }).first()
    await expect(row).toContainText('退回')
    await row.getByRole('button', { name: '更多', exact: true }).click()
    await unit.page.getByRole('menuitem', { name: '编辑', exact: true }).click()
    drawer = unit.page.getByRole('dialog', { name: '编辑申报项目', exact: true })
    await drawer.getByRole('tab', { name: '项目概述', exact: true }).click()
    await drawer.locator('.el-form-item').filter({ hasText: '项目摘要' }).locator('[contenteditable=true]').fill('QA118 revised research summary after county return')
    await submit(unit.page, drawer, created.id)
    for (const actor of [county, await asRole('department')]) {
      await actor.page.goto(`/reviews?project_id=${created.id}`)
      review = actor.page.getByRole('dialog', { name: '审核处理', exact: true })
      await expect(review).toBeVisible()
      await review.locator('.el-collapse-item__header').click()
      await expect(review.getByText('QA118 revised research summary after county return', { exact: true })).toBeVisible()
      await expect(review.getByRole('spinbutton')).toHaveCount(0)
      await review.locator('[contenteditable=true]').fill('QA118 materials checked and approved')
      response = waitWrite(actor.page, `/api/projects/${created.id}/reviews`)
      await review.getByRole('button', { name: '提交审核', exact: true }).click()
      expect((await response).status()).toBe(201)
      await expect(review).toBeHidden()
    }
    const detail = await (await request.get(`/api/projects/${created.id}`, { headers: unit.headers })).json()
    expect(detail.current_reviewer_role).toBe('expert')
    expect(detail.metadata.review_dispatch.assignments.expert.assigned_user_ids).toHaveLength(3)
    const prior = JSON.parse(await readFile(path.join(path.dirname(manifestPath), 'qa117-project.json'), 'utf8'))
    await writeFile(fixturePath, JSON.stringify({ id: created.id, title, criteria: prior.criteria, assigned_count: 3 }), { flag: 'wx' })
    expect(errors).toEqual([])
  } finally {
    for (const session of sessions) {
      try { await session.context.close() }
      catch (error) { await test.info().attach('context-cleanup-error', { body: String(error), contentType: 'text/plain' }) }
      try { await request.post('/api/auth/logout', { headers: session.headers, timeout: 5000 }) }
      catch (error) { await test.info().attach('cleanup-error', { body: String(error), contentType: 'text/plain' }) }
    }
  }
})

test('three assigned experts read full materials and score through the actual UI without early transition', async ({ browser, request }) => {
  test.setTimeout(120_000)
  const credentialsPath = process.env.QA105_CREDENTIALS
  test.skip(!credentialsPath, 'Explicit isolated fixture required')
  expect(process.env.E2E_BASE_URL).toBe('http://127.0.0.1:18742')
  const manifest = JSON.parse(await readFile(credentialsPath, 'utf8'))
  expect(manifest.base_url).toBe(process.env.E2E_BASE_URL)
  const fixtureName = process.env.QA105_FIXTURE || 'qa105-project.json'
  expect(fixtureName).toMatch(/^qa[0-9]+-project\.json$/)
  const fixture = JSON.parse(await readFile(path.join(path.dirname(credentialsPath), fixtureName), 'utf8'))
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

test('isolated admin support and acceptance extension close through the rendered UI', async ({ browser, request }) => {
  test.setTimeout(180_000)
  test.skip(process.env.QA113_CLOSURE !== '1', 'Explicit isolated continuation required')
  expect(process.env.E2E_BASE_URL).toBe('http://127.0.0.1:18742')
  const manifestPath = process.env.QA105_CREDENTIALS
  expect(manifestPath).toBeTruthy()
  const manifest = JSON.parse(await readFile(manifestPath, 'utf8'))
  expect(manifest.base_url).toBe(process.env.E2E_BASE_URL)
  const fixtureName = process.env.QA105_FIXTURE || 'qa105-project.json'
  expect(fixtureName).toMatch(/^qa[0-9]+-project\.json$/)
  const fixture = JSON.parse(await readFile(path.join(path.dirname(manifestPath), fixtureName), 'utf8'))
  const sessions = []
  const errors = []
  async function asRole(role) {
    const account = manifest.accounts[role]
    const captcha = await (await request.get('/api/auth/captcha')).json()
    const login = await request.post('/api/auth/login', { data: {
      username: account.username, password: account.password, captcha_id: captcha.captcha_id,
      captcha_answer: captcha.question.match(/\d+/g).map(Number).reduce((a, b) => a + b, 0)
    } })
    expect(login.status()).toBe(200)
    const token = (await login.json()).token
    const context = await browser.newContext({ baseURL: manifest.base_url, viewport: { width: 1440, height: 1000 } })
    await context.addInitScript(value => localStorage.setItem('pas_token', value), token)
    const page = await context.newPage()
    page.setDefaultTimeout(15_000)
    page.on('pageerror', error => errors.push(String(error)))
    const session = { page, context, headers: { Authorization: `Bearer ${token}` } }
    sessions.push(session)
    return session
  }
  const snap = async (page, name) => {
    const drawer = page.locator('.el-drawer:visible')
    if (await drawer.count()) {
      await expect.poll(async () => {
        const box = await drawer.boundingBox()
        return box && box.x >= 0 && box.x + box.width <= 1441
      }).toBe(true)
    }
    await page.screenshot({ path: test.info().outputPath(`${name}.png`), fullPage: true })
  }
  const editor = dialog => dialog.locator('[contenteditable=true]').first()
  const row = page => page.getByRole('row').filter({ hasText: fixture.title }).first()
  const waitPost = (page, suffix) => page.waitForResponse(r => r.url().endsWith(suffix) && r.request().method() === 'POST')
  try {
    const admin = await asRole('admin')
    const before = await (await request.get(`/api/projects/${fixture.id}`, { headers: admin.headers })).json()
    expect(before.expert_review_summary.reviewed_count).toBe(3)
    const resumeAcceptance = process.env.QA113_ACCEPTANCE_ID
    if (!resumeAcceptance) {
    expect(before.current_reviewer_role).toBe('admin')
    await admin.page.goto(`/reviews?project_id=${fixture.id}`)
    const finalDialog = admin.page.getByRole('dialog', { name: '审核处理', exact: true })
    await expect(finalDialog).toBeVisible()
    for (const [label, amount] of [['补助支持金额（万元）', '10'], ['贴息支持金额（万元）', '2'], ['其他支持金额（万元）', '1']]) {
      await finalDialog.locator('.el-form-item').filter({ hasText: label }).getByRole('spinbutton').fill(amount)
    }
    await finalDialog.locator('.el-form-item').filter({ hasText: '其他支持说明' }).getByRole('textbox').fill('QA113 synthetic other support')
    await editor(finalDialog).fill('QA113 synthetic final approval')
    await snap(admin.page, 'admin-itemized-support')
    const finalResponse = waitPost(admin.page, `/api/projects/${fixture.id}/reviews`)
    await finalDialog.getByRole('button', { name: '提交审核', exact: true }).click()
    expect((await finalResponse).status()).toBe(201)
    await expect(finalDialog).toBeHidden()
    }
    const approved = await (await request.get(`/api/projects/${fixture.id}`, { headers: admin.headers })).json()
    expect(['approved', 'acceptance']).toContain(approved.status)
    expect(Number(approved.metadata.final_support.total_support_amount_wan)).toBe(13)
    const unit = await asRole('unit')
    await unit.page.goto(`/acceptance?project_id=${fixture.id}`)
    let acceptance
    if (resumeAcceptance) {
      const existing = await request.get(`/api/acceptance/${resumeAcceptance}`, { headers: unit.headers })
      expect(existing.status()).toBe(200)
      acceptance = await existing.json()
      expect(acceptance.project.id).toBe(fixture.id)
      expect(acceptance.status).toBe(process.env.QA113_FINAL_ONLY === '1' ? 'reviewing' : 'draft')
    } else {
    await unit.page.getByRole('button', { name: '发起验收', exact: true }).click()
    const create = unit.page.getByRole('dialog', { name: '发起验收', exact: true })
    await create.getByRole('combobox').fill(fixture.title)
    await unit.page.getByRole('option').filter({ hasText: fixture.title }).click()
    await editor(create).fill('QA113 synthetic acceptance application')
    const created = waitPost(unit.page, `/api/projects/${fixture.id}/acceptance`)
    await create.getByRole('button', { name: '保存草稿', exact: true }).click()
    const createdResponse = await created
    expect(createdResponse.status()).toBe(201)
    acceptance = await createdResponse.json()
    await expect(create).toBeHidden()
    }
    if (process.env.QA113_FINAL_ONLY !== '1') {
    for (const [label, filename] of [['验收申请', 'qa-acceptance-application.pdf'], ['财务', 'qa-financial.pdf']]) {
      await row(unit.page).getByRole('button', { name: '材料', exact: true }).click()
      const upload = unit.page.getByRole('dialog', { name: '上传验收材料', exact: true })
      await upload.getByRole('combobox').press('ArrowDown')
      await unit.page.getByRole('option').filter({ hasText: label }).click()
      const uploaded = waitPost(unit.page, `/api/acceptance/${acceptance.id}/files`)
      await upload.locator('input[type=file]').setInputFiles(path.join(path.dirname(manifestPath), '..', 'materials', filename))
      expect((await uploaded).status()).toBe(201)
      await expect(upload).toBeHidden()
    }
    await row(unit.page).getByRole('button', { name: '延期', exact: true }).click()
    const extension = unit.page.getByRole('dialog', { name: '验收延期', exact: true })
    await editor(extension).fill('QA113 laboratory report delayed')
    await extension.getByRole('combobox').fill('2027-03-31')
    await extension.getByRole('combobox').press('Tab')
    const extended = waitPost(unit.page, `/api/acceptance/${acceptance.id}/extensions`)
    await extension.getByRole('button', { name: '保存', exact: true }).click()
    expect((await extended).status()).toBe(201)
    await expect(extension).toBeHidden()
    await admin.page.goto(`/acceptance?project_id=${fixture.id}&scope=visible`)
    await expect(row(admin.page)).toContainText('待处理 1')
    await row(admin.page).getByRole('button', { name: '延期', exact: true }).click()
    const decision = admin.page.getByRole('dialog', { name: '验收延期', exact: true })
    await editor(decision).fill('QA113 extension approved after review')
    const decided = waitPost(admin.page, `/api/acceptance/${acceptance.id}/extensions`)
    await decision.getByRole('button', { name: '保存', exact: true }).click()
    expect((await decided).status()).toBe(200)
    await expect(decision).toBeHidden()
    await unit.page.reload()
    await expect(row(unit.page)).toContainText('已通过')
    await row(unit.page).getByRole('button', { name: '提交', exact: true }).click()
    const submit = unit.page.getByRole('dialog', { name: '提交验收', exact: true })
    const submitted = waitPost(unit.page, `/api/acceptance/${acceptance.id}/submit`)
    await submit.getByRole('button', { name: '提交', exact: true }).click()
    expect((await submitted).status()).toBe(200)
    await expect(submit).toBeHidden()
    }
    for (const role of process.env.QA113_FINAL_ONLY === '1' ? ['admin'] : ['county', 'department', 'expert', 'admin']) {
      const actor = role === 'admin' ? admin : await asRole(role)
      await actor.page.goto(`/acceptance?project_id=${fixture.id}&scope=pending`)
      await row(actor.page).getByRole('button', { name: '详情', exact: true }).click()
      const detail = actor.page.getByRole('dialog', { name: '验收详情', exact: true })
      await expect(detail).toContainText('QA113 synthetic acceptance application')
      await expect(detail.getByRole('button', { name: '下载验收材料' })).toHaveCount(2)
      await snap(actor.page, `${role}-acceptance-materials`)
      await detail.locator('.el-drawer__close-btn').click()
      await expect(detail).toBeHidden()
      await expect(actor.page.locator('.el-overlay:visible')).toHaveCount(0)
      await row(actor.page).getByRole('button', { name: '审核', exact: true }).click()
      const review = actor.page.getByRole('dialog', { name: '验收审核', exact: true })
      await editor(review).fill(`QA113 ${role} acceptance approval`)
      if (role === 'expert') await review.getByRole('spinbutton').fill('92')
      if (role === 'admin') {
        await review.getByRole('combobox').press('ArrowDown')
        await actor.page.getByRole('option', { name: '终审关闭', exact: true }).click()
      }
      const reviewed = waitPost(actor.page, `/api/acceptance/${acceptance.id}/reviews`)
      await review.getByRole('button', { name: '提交审核', exact: true }).click()
      expect((await reviewed).status()).toBe(201)
      await expect(review).toBeHidden()
    }
    await unit.page.reload()
    await row(unit.page).getByRole('button', { name: '详情', exact: true }).click()
    const complete = unit.page.getByRole('dialog', { name: '验收详情', exact: true })
    await expect(complete).toContainText('已关闭')
    await expect(complete).toContainText('QA113 extension approved after review')
    await expect(complete).toContainText('2027-03-31')
    await snap(unit.page, 'unit-closed-acceptance-and-extension')
    const end = await (await request.get(`/api/projects/${fixture.id}`, { headers: unit.headers })).json()
    expect(end.status).toBe('closed')
    expect(errors).toEqual([])
  } finally {
    for (const session of sessions) {
      await session.context.close()
      try { await request.post('/api/auth/logout', { headers: session.headers, timeout: 5000 }) }
      catch (error) { await test.info().attach('cleanup-error', { body: String(error), contentType: 'text/plain' }) }
    }
  }
})
