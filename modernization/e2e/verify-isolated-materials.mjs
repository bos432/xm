import assert from 'node:assert/strict'
import { readFile, writeFile } from 'node:fs/promises'
import { createHash } from 'node:crypto'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const runId = process.argv[2]
assert.match(runId || '', /^qa[0-9]+-[a-zA-Z0-9-]+$/)
const root = path.join(path.dirname(fileURLToPath(import.meta.url)), 'reports', 'runs', runId)
const manifest = JSON.parse(await readFile(path.join(root, 'sandbox', 'credentials.json'), 'utf8'))
const base = 'http://127.0.0.1:18742'
assert.equal(manifest.base_url, base)
const evidence = { phase: 'QA-11', base_url: base, transport: 'HTTP API, not browser filechooser', production_changed: false, requests: [], files: [], result: 'running' }
const tokens = new Map()
const digest = bytes => createHash('sha256').update(bytes).digest('hex')

async function request(endpoint, { token, body, method = 'GET', expected = 200, raw = false } = {}) {
  assert.ok(endpoint.startsWith('/api/') && !endpoint.includes('..'))
  const headers = { Accept: 'application/json' }
  if (token) headers.Authorization = `Bearer ${token}`
  if (body && !(body instanceof FormData)) {
    headers['Content-Type'] = 'application/json'
    body = JSON.stringify(body)
  }
  const response = await fetch(base + endpoint, { method, headers, body, redirect: 'error', signal: AbortSignal.timeout(15000) })
  evidence.requests.push({ method, endpoint, expected, actual: response.status })
  const bytes = Buffer.from(await response.arrayBuffer())
  assert.equal(response.status, expected, `${method} ${endpoint}: ${bytes.toString('utf8').slice(0, 500)}`)
  return raw ? bytes : bytes.length ? JSON.parse(bytes.toString('utf8')) : null
}

async function login(role) {
  const account = manifest.accounts[role]
  const captcha = await request('/api/auth/captcha')
  const match = captcha.question.match(/^(\d+)\s*\+\s*(\d+)\s*=\s*\?$/)
  assert.ok(match, 'Only known isolated arithmetic challenge supported')
  const result = await request('/api/auth/login', { method: 'POST', body: {
    username: account.username, password: account.password,
    captcha_id: captcha.captcha_id, captcha_answer: Number(match[1]) + Number(match[2])
  } })
  assert.equal(result.user.role, account.role)
  tokens.set(role, result.token)
  return result.token
}

try {
  const unit = await login('unit')
  const list = await request('/api/acceptance', { token: unit })
  const acceptance = list.data.find(row => row.project?.title === 'QA-20261105-BROWSER-项目全流程')
  assert.ok(acceptance, 'Expected retained synthetic acceptance')
  assert.ok(['draft', 'returned'].includes(acceptance.status), 'Do not modify submitted/completed acceptance')
  evidence.acceptance_id = acceptance.id
  const detailPath = `/api/acceptance/${acceptance.id}`
  let detail = await request(detailPath, { token: unit })
  for (const [category, name] of [['acceptance_application', 'qa-acceptance-application.pdf'], ['financial', 'qa-financial.pdf']]) {
    const bytes = await readFile(path.join(root, 'materials', name))
    assert.ok(bytes.subarray(0, 5).equals(Buffer.from('%PDF-')))
    const sha256 = digest(bytes)
    let file = detail.project.files.find(file => file.sha256 === sha256 && file.metadata?.material_category === category)
    if (!file) {
      const body = new FormData()
      body.append('file', new Blob([bytes], { type: 'application/pdf' }), name)
      body.append('purpose', 'acceptance')
      body.append('metadata[material_category]', category)
      file = await request(`${detailPath}/files`, { method: 'POST', token: unit, body, expected: 201 })
    }
    assert.equal(file.sha256, sha256)
    assert.equal(file.metadata.material_category, category)
    assert.equal(file.purpose, 'acceptance')
    const download = `/api/files/${file.id}/download`
    assert.equal(digest(await request(download, { token: unit, raw: true })), sha256)
    await request(download, { expected: 401 })
    evidence.files.push({ id: file.id, category, name, bytes: bytes.length, sha256, owner_download: 'pass', anonymous_denied: 'pass' })
    detail = await request(detailPath, { token: unit })
  }
  const county = await login('county')
  const countyDetail = await request(detailPath, { token: county })
  for (const file of evidence.files) {
    assert.ok(countyDetail.project.files.some(item => item.id === file.id))
    assert.equal(digest(await request(`/api/files/${file.id}/download`, { token: county, raw: true })), file.sha256)
    file.prior_reviewer_download = 'pass'
  }
  evidence.result = 'pass'
} catch (error) {
  evidence.result = 'fail'
  evidence.error = String(error.message)
  process.exitCode = 1
} finally {
  for (const token of tokens.values()) {
    try { await request('/api/auth/logout', { method: 'POST', token, expected: 204 }) }
    catch { evidence.logout_failed = true; evidence.result = 'fail'; process.exitCode = 1 }
  }
  await writeFile(path.join(root, 'qa11-materials-http.json'), JSON.stringify(evidence, null, 2) + '\n')
  console.log(JSON.stringify(evidence, null, 2))
}
