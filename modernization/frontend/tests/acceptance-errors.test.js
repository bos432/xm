import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { runInNewContext } from 'node:vm'

const source = readFileSync(new URL('../src/views/AcceptanceView.vue', import.meta.url), 'utf8')

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
