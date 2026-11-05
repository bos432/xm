import { createHash, randomUUID } from 'node:crypto'
import { expect, test } from '@playwright/test'
import { mkdir, readFile, writeFile } from 'node:fs/promises'
import path from 'node:path'

const baseURL = process.env.E2E_BASE_URL || ''
const evidenceDir = path.resolve(process.env.QA40_EVIDENCE_DIR || 'reports/qa40')
const credentialsPath = process.env.QA40_CREDENTIALS
const stamp = `QA40-${new Date().toISOString().replace(/[-:.TZ]/g, '').slice(0, 14)}-${randomUUID().slice(0, 8)}`

test('unit uploads a PDF in Chromium and file access remains role-scoped', async ({ page, request }) => {
  expect(baseURL).toMatch(/^http:\/\/127\.0\.0\.1:18742$/)
  expect(credentialsPath, 'Set QA40_CREDENTIALS to the isolated QA manifest').toBeTruthy()
  const manifest = JSON.parse(await readFile(credentialsPath, 'utf8'))
  const unit = manifest.accounts.unit
  const admin = manifest.accounts.admin
  expect(unit?.username).toBeTruthy()
  expect(admin?.username).toBeTruthy()

  const evidence = {
    stage: 'QA-40',
    base_url: baseURL,
    browser: 'Chromium',
    synthetic_data_only: true,
    title: stamp,
    actions: [],
    production_modified: false,
    result: 'running'
  }
  let unitToken
  let adminToken

  async function login(account) {
    const captchaResponse = await request.get('/api/auth/captcha')
    expect(captchaResponse.ok()).toBeTruthy()
    const captcha = await captchaResponse.json()
    const numbers = captcha.question.match(/\d+/g).map(Number)
    const response = await request.post('/api/auth/login', {
      data: {
        username: account.username,
        password: account.password,
        captcha_id: captcha.captcha_id,
        captcha_answer: numbers.reduce((sum, value) => sum + value, 0)
      }
    })
    expect(response.ok()).toBeTruthy()
    return (await response.json()).token
  }

  try {
    unitToken = await login(unit)
    const auth = { Authorization: `Bearer ${unitToken}` }
    const openBatches = await request.get('/api/public/application-batches/open')
    expect(openBatches.ok()).toBeTruthy()
    const batch = (await openBatches.json()).find(item => item.code === 'QA-ISOLATED-BROWSER')
    expect(batch, 'isolated fixture must provide its QA-only open batch').toBeTruthy()

    const projectResponse = await request.post('/api/projects', {
      headers: auth,
      data: {
        title: stamp,
        application_batch_id: batch.id,
        summary: 'Synthetic browser upload regression; not a business application.',
        budget_amount: 0
      }
    })
    expect(projectResponse.status()).toBe(201)
    const project = await projectResponse.json()
    evidence.project_id = project.id
    evidence.batch_id = batch.id
    evidence.actions.push({ action: 'unit_create_isolated_draft', status: projectResponse.status() })

    await page.addInitScript(token => localStorage.setItem('pas_token', token), unitToken)
    await page.goto(`/projects?keyword=${encodeURIComponent(stamp)}`)
    await expect(page.getByText(stamp).first()).toBeVisible()
    await page.getByRole('button', { name: '更多' }).click()
    await page.getByRole('menuitem', { name: '编辑' }).click()
    await expect(page.getByText('创建项目申报草稿')).toHaveCount(0)
    await expect(page.getByRole('tab', { name: '附件材料' })).toBeVisible()
    await page.getByRole('tab', { name: '附件材料' }).click()
    await expect(page.locator('.material-upload-panel .el-select')).toBeVisible()
    await expect(page.locator('.material-upload-panel')).toContainText('项目申报书（选传；pdf、doc、docx）')

    const pdf = Buffer.from('%PDF-1.4\n% synthetic QA40 upload\n%%EOF\n')
    const pdfPath = path.join(evidenceDir, `${stamp}.pdf`)
    await mkdir(evidenceDir, { recursive: true })
    await writeFile(pdfPath, pdf, { flag: 'wx' })
    await page.locator('.compact-upload input[type="file"]').setInputFiles(pdfPath)

    await expect(page.getByText(`${stamp}.pdf`)).toBeVisible({ timeout: 20_000 })
    const detailResponse = await request.get(`/api/projects/${project.id}`, { headers: auth })
    expect(detailResponse.ok()).toBeTruthy()
    const detail = await detailResponse.json()
    const uploaded = detail.files.find(file => file.original_name === `${stamp}.pdf`)
    expect(uploaded).toBeTruthy()
    const expectedHash = createHash('sha256').update(pdf).digest('hex')
    expect(uploaded.sha256).toBe(expectedHash)
    expect(uploaded.purpose).toBe('application')
    evidence.file = { id: uploaded.id, name: uploaded.original_name, bytes: uploaded.size_bytes, sha256: uploaded.sha256 }
    evidence.actions.push({ action: 'chromium_filechooser_upload_and_project_list', status: 'pass' })

    const ownerDownload = await request.get(`/api/files/${uploaded.id}/download`, { headers: auth })
    expect(ownerDownload.status()).toBe(200)
    expect(createHash('sha256').update(await ownerDownload.body()).digest('hex')).toBe(expectedHash)
    evidence.actions.push({ action: 'owner_download_sha256_match', status: ownerDownload.status() })

    adminToken = await login(admin)
    const adminDraftRead = await request.get(`/api/projects/${project.id}`, {
      headers: { Authorization: `Bearer ${adminToken}` }
    })
    expect([403, 404]).toContain(adminDraftRead.status())
    const anonymousDownload = await request.get(`/api/files/${uploaded.id}/download`)
    expect(anonymousDownload.status()).toBe(401)
    evidence.actions.push(
      { action: 'business_admin_draft_read_denied', status: adminDraftRead.status() },
      { action: 'anonymous_download_denied', status: anonymousDownload.status() }
    )
    evidence.result = 'pass'
  } catch (error) {
    evidence.result = 'fail'
    evidence.error = String(error?.stack || error)
    throw error
  } finally {
    for (const token of [unitToken, adminToken].filter(Boolean)) {
      const response = await request.post('/api/auth/logout', { headers: { Authorization: `Bearer ${token}` } }).catch(() => null)
      evidence.actions.push({ action: 'logout', status: response?.status() ?? 'failed' })
    }
    await mkdir(evidenceDir, { recursive: true })
    await writeFile(path.join(evidenceDir, 'qa40-browser-upload.json'), `${JSON.stringify(evidence, null, 2)}\n`)
  }
})
