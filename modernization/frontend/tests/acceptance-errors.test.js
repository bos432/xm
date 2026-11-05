import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { runInNewContext } from 'node:vm'

const source = readFileSync(new URL('../src/views/AcceptanceView.vue', import.meta.url), 'utf8')

test('acceptance renders Chinese decisions and business timezone timestamps in history and lists', () => {
  const dateDeclaration = source.match(/function formatDateTime\([^)]*\) \{[\s\S]*?\n\}/)
  assert.ok(dateDeclaration, 'Acceptance must format API timestamps for business display')
  const format = runInNewContext(`(${dateDeclaration[0]})`, { Date, Intl })
  assert.equal(format('2026-11-05T06:04:16.000000Z'), '2026-11-05 14:04:16')
  assert.equal(format('2026-12-31'), '2026-12-31')
  assert.equal(format('2026-11-05 14:04:16'), '2026-11-05 14:04:16')
  for (const value of [null, '', undefined, 'not-a-date', {}, []]) assert.equal(format(value), '-')
  const decisionDeclaration = source.match(/function decisionLabel\([^)]*\) \{[\s\S]*?\n\}/)
  const decision = runInNewContext(`(${decisionDeclaration[0]})`)
  for (const [code, label] of Object.entries({ approve: '通过', return: '退回修改', reject: '驳回', close: '终审关闭' })) {
    assert.equal(decision(code), label)
  }
  assert.match(source, /label="结果"[^>]*>\s*<template #default="\{ row \}">\{\{ decisionLabel\(row.decision\)/)
  for (const expression of ['row.submitted_at', 'row.reviewed_at', 'row.latest_extension?.created_at', 'row.created_at || row.requested_at']) {
    assert.ok(source.includes(`formatDateTime(${expression})`), `Missing readable timestamp: ${expression}`)
  }
  assert.ok(source.includes('extensionStatusLabel(item.status)'), 'Extension selector must use Chinese status')
})

test('completed acceptance hides new unit extension action while admin can resolve historical requests', () => {
  const declaration = source.match(/function canExtend\([^)]*\) \{[\s\S]*?\n\}/)
  for (const [role, expected] of [['unit', false], ['admin', true], ['county', false]]) {
    const handler = runInNewContext(`(${declaration[0]})`, {
      session: { can: permission => role === 'unit' ? permission === 'submit_acceptance' : role === 'admin' && permission === 'manage_acceptance' }
    })
    for (const status of ['approved', 'closed', 'rejected']) assert.equal(handler({ status }), expected)
    if (role === 'unit') for (const status of ['draft', 'submitted', 'reviewing', 'returned']) assert.equal(handler({ status }), true)
  }
})

for (const action of ['createAcceptance', 'submitAcceptance', 'saveReview', 'saveExtension', 'uploadFile']) {
  test(`acceptance ${action} shows rejected API error, preserves form and permits retry`, async () => {
    const declaration = source.match(new RegExp(`async function ${action}\\([^)]*\\) \\{[\\s\\S]*?\\n\\}`))
    assert.ok(declaration, `${action} must exist`)
    const errors = []
    const successes = []
    let attempts = 0
    const context = {
      api: async () => {
        attempts++
        if (attempts === 1) throw new Error('验收材料未齐全，缺少：财务材料')
        return {}
      },
      ElMessage: { error: message => errors.push(message), success: message => successes.push(message) },
      saving: { value: false },
      createVisible: { value: true }, submitVisible: { value: true }, reviewVisible: { value: true },
      extensionVisible: { value: true }, uploadVisible: { value: true },
      createForm: { project_id: 1, summary: 'Retain draft text' },
      submitForm: { summary: 'Retain submission text' }, reviewForm: { decision: 'approve', comment: 'Retain opinion' },
      extensionForm: { reason: 'Retain reason', expected_date: '2026-12-01' },
      currentAcceptance: { value: { id: 1 } }, uploadCategory: { value: 'financial' },
      showReviewScore: { value: false },
      session: { role: 'unit' }, loadAcceptances: async () => {}, FormData, JSON, Object
    }
    const handler = runInNewContext(`(${declaration[0]})`, context)
    const file = new Blob(['%PDF-1.4 synthetic QA file'], { type: 'application/pdf' })
    await assert.doesNotReject(handler({ file }))
    assert.deepEqual(errors, ['验收材料未齐全，缺少：财务材料'])
    assert.equal(successes.length, 0)
    assert.equal(context.saving.value, false)
    for (const key of ['createVisible', 'submitVisible', 'reviewVisible', 'extensionVisible', 'uploadVisible']) {
      assert.equal(context[key].value, true, `${key} should remain open on failure`)
    }
    assert.equal(context.submitForm.summary, 'Retain submission text')
    await assert.doesNotReject(handler({ file }))
    assert.equal(attempts, 2)
    assert.equal(successes.length, 1)
    assert.equal(context.saving.value, false)
  })
}

test('acceptance list failure reports an error and retains existing rows', async () => {
  const declaration = source.match(/async function loadAcceptances\([^)]*\) \{[\s\S]*?\n\}/)
  const errors = []
  const context = {
    api: async () => { throw new Error('加载失败，请重试') },
    ElMessage: { error: message => errors.push(message) },
    loading: { value: false }, keyword: { value: '' }, status: { value: '' }, projectId: { value: '' },
    canFilterE2e: { value: false }, showScopeTabs: { value: false },
    acceptances: { value: [{ id: 1 }] }, URLSearchParams
  }
  await assert.doesNotReject(runInNewContext(`(${declaration[0]})`, context)())
  assert.deepEqual(errors, ['加载失败，请重试'])
  assert.equal(context.acceptances.value[0].id, 1)
  assert.equal(context.loading.value, false)
})

test('acceptance materials expose authorized download and report failures', async () => {
  const declaration = source.match(/async function downloadFile\([^)]*\) \{[\s\S]*?\n\}/)
  assert.ok(declaration, 'Acceptance materials must have a download handler')
  assert.match(source, /aria-label="下载验收材料"[\s\S]*?@click="downloadFile\(row\)"/)
  const calls = []
  const errors = []
  let fail = false
  const handler = runInNewContext(`(${declaration[0]})`, {
    downloadApi: async (...args) => { calls.push(args); if (fail) throw new Error('无权下载该附件') },
    ElMessage: { error: message => errors.push(message) }
  })
  await handler({ id: 42, original_name: 'qa-financial.pdf' })
  assert.deepEqual(calls[0], ['/files/42/download', 'qa-financial.pdf'])
  fail = true
  await assert.doesNotReject(handler({ id: 42, original_name: 'qa-financial.pdf' }))
  assert.deepEqual(errors, ['无权下载该附件'])
})

test('acceptance scoring follows server stage configuration and strips hidden scores', async () => {
  assert.match(source, /<el-form-item v-if="showReviewScore" label="评分"/)
  const declaration = source.match(/async function saveReview\([^)]*\) \{[\s\S]*?\n\}/)
  const computedDeclaration = source.match(/const showReviewScore = computed\([^\n]+/)
  assert.ok(computedDeclaration)
  const currentAcceptance = { value: { id: 1 } }
  const payloads = []
  const showReviewScore = runInNewContext(`${computedDeclaration[0]}; showReviewScore`, {
    currentAcceptance, computed: fn => ({ get value() { return fn() } })
  })
  const handler = runInNewContext(`(${declaration[0]})`, {
    currentAcceptance, showReviewScore, reviewForm: { decision: 'approve', score: 85, comment: 'QA' },
    saving: { value: false }, reviewVisible: { value: true }, ElMessage: { success() {}, error() {} },
    loadAcceptances: async () => {}, api: async (_path, options) => payloads.push(JSON.parse(options.body))
  })
  for (const config of [undefined, { score_enabled: false }, { score_enabled: true }]) {
    currentAcceptance.value.review_config = config
    await handler()
    assert.equal(payloads.at(-1).score, config?.score_enabled === true ? 85 : null)
  }
})
