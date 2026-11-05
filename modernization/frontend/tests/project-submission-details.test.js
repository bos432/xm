import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { compile, createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { parse } from '@vue/compiler-sfc'

async function render(project) {
  const source = readFileSync(new URL('../src/components/ProjectSubmissionDetails.vue', import.meta.url), 'utf8')
  const { descriptor, errors } = parse(source)
  assert.deepEqual(errors, [])
  const script = descriptor.script.content
  const component = new Function(script.replace('export default', 'return'))()
  component.render = compile(descriptor.template.content)
  return renderToString(createSSRApp(component, { project }))
}

test('review submission renders all submitted sections and safely escapes identity text', async () => {
  const html = await render({ metadata: {
    guide_code: 'GUIDE-42', start_date: '2026-01-01', end_date: '2026-12-31', cooperation_units: 'Partner QA',
    overview: '<p>Research background</p>', objectives: '<p>Research goals</p>', innovation: '<p>Expected impact</p>',
    leader: { name: '<img src=x onerror=alert(1)>', mobile: '13800000001', professional_title: 'QA Researcher', work_unit: 'QA Unit', email: 'lead@example.invalid', phone: '000-111' },
    contact: { name: 'QA Contact', mobile: '13800000002', email: 'contact@example.invalid' },
    members: [{ name: 'QA Member', organization: 'Member Unit', task: 'QA Task', role: 'Research', is_leader: true }],
    budget_items: [{ name: 'QA Budget', expense_type: 'Direct', total: 12.5, special_fund: 5, self_fund: 7.5, remark: 'Budget note' }],
    equipment_items: [{ name: 'QA Device', spec: 'Model QA', quantity: 2, unit_price: 15000, amount: 3, purpose: 'QA purpose' }],
    seal: { legal_representative: 'QA Legal', seal_date: '2026-11-05', commitment: '<p>QA Commitment</p>', remark: '<p>QA Seal note</p>' }
  } })
  for (const expected of ['GUIDE-42', 'Partner QA', 'Research background', 'Research goals', 'Expected impact', 'QA Researcher', 'lead@example.invalid', 'QA Contact', 'QA Member', 'QA Task', 'QA Budget', 'Budget note', 'QA Device', 'Model QA', 'QA Legal', 'QA Commitment', 'QA Seal note']) {
    assert.ok(html.includes(expected), `Missing submitted field: ${expected}`)
  }
  assert.ok(!html.includes('<img src=x'), 'Person text must not become raw HTML')
  assert.ok(html.includes('&lt;img'))
})

test('legacy projects with missing or malformed metadata still render', async () => {
  for (const metadata of [undefined, null, {}, { members: null, budget_items: {}, equipment_items: 'legacy', leader: null }]) {
    const html = await render({ metadata })
    assert.ok(html.includes('负责人'))
    assert.ok(html.includes('暂无预算明细'))
  }
})

test('both reviewer drawer and processing dialog include the shared complete submission', () => {
  const source = readFileSync(new URL('../src/views/ReviewTasksView.vue', import.meta.url), 'utf8')
  assert.match(source, /<ProjectSubmissionDetails :project="currentProject"/)
  assert.match(source, /<ProjectSubmissionDetails :project="detail"/)
})

test('review materials collapse components are registered at application bootstrap', () => {
  const source = readFileSync(new URL('../src/main.js', import.meta.url), 'utf8')
  const imports = source.match(/import\s*\{([\s\S]*?)\}\s*from 'element-plus'/)?.[1] || ''
  const registered = source.match(/const elementComponents = \[([\s\S]*?)\]/)?.[1] || ''
  for (const name of ['ElCollapse', 'ElCollapseItem']) {
    assert.ok(imports.split(',').map(value => value.trim()).includes(name), `Missing import: ${name}`)
    assert.ok(registered.split(',').map(value => value.trim()).includes(name), `Missing registration: ${name}`)
  }
})
