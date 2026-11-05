import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { runInNewContext } from 'node:vm'

test('system settings navigation exposes the OSS backup group', () => {
  const app = readFileSync(new URL('../src/App.vue', import.meta.url), 'utf8')
  const declaration = app.match(/const settingsMenuChildren = (\[[\s\S]*?\n\])/)
  assert.ok(declaration, 'Settings menu configuration must exist')
  const children = runInNewContext(declaration[1])
  const backup = children.find((item) => item.group === 'backup')
  assert.ok(backup, 'Backup group must be discoverable in the sidebar')
  assert.equal(backup.label, '备份与 OSS')
  assert.equal(backup.path, '/settings?group=backup')
  assert.equal(children.filter((item) => item.group === 'backup').length, 1)
})

test('system settings constrain nested grids on narrow screens', () => {
  const source = readFileSync(new URL('../src/views/SettingsView.vue', import.meta.url), 'utf8')
  const styles = source.match(/<style scoped>([\s\S]*?)<\/style>/)?.[1]
  assert.ok(styles, 'Settings view scoped styles must exist')
  assert.match(styles, /\.page-stack\s*\{[^}]*grid-template-columns:\s*minmax\(0,\s*1fr\)/)
  assert.match(styles, /\.page-stack\s*>\s*\*\s*\{[^}]*min-width:\s*0/)
  assert.match(styles, /@media\s*\(max-width:\s*900px\)\s*\{[^}]*\.settings-overview-grid\s*\{[^}]*grid-template-columns:\s*minmax\(0,\s*1fr\)/s)
})

test('mobile navigation exposes only the current role menu groups and routes', () => {
  const app = readFileSync(new URL('../src/App.vue', import.meta.url), 'utf8')
  assert.match(app, /data-testid="mobile-menu-button"/)
  assert.match(app, /data-testid="mobile-navigation-drawer"/)
  assert.match(app, /v-for="group in visibleMenuGroups"/)
  assert.match(app, /v-for="item in mobileMenuItems"/)
  assert.match(app, /mobileMenuItems = computed\(\(\) => visibleMenuGroups\.value\.find\(\(group\) => group\.key === mobileGroupKey\.value\)\?\.items \|\| \[\]\)/)
  assert.match(app, /function openMobileMenuGroup\(group\)/)
  assert.match(app, /function openMobileMenuItem\(item, child\)/)
})

test('mobile navigation rejects items and children outside the authorized group', () => {
  const app = readFileSync(new URL('../src/App.vue', import.meta.url), 'utf8')
  const declaration = app.match(/function openMobileMenuItem\(item, child\) \{([\s\S]*?)\n\}/)
  assert.ok(declaration)
  const destinations = []
  const visible = { value: true }
  const navigate = runInNewContext(`(function openMobileMenuItem(item, child) { ${declaration[1]} })`, {
    mobileMenuItems: { value: [{ key: 'projects', path: '/projects', children: [{ path: '/projects?status=closed' }] }] },
    mobileNavigationVisible: visible,
    router: { push: (path) => destinations.push(path) }
  })
  navigate({ key: 'settings', path: '/settings' })
  navigate({ key: 'projects' }, { path: '/settings?group=review' })
  assert.deepEqual(destinations, [])
  assert.equal(visible.value, true)
  navigate({ key: 'projects', path: '/settings' })
  assert.deepEqual(destinations, ['/projects'])
  assert.equal(visible.value, false)
  visible.value = true
  navigate({ key: 'projects' }, { path: '/projects?status=closed' })
  assert.deepEqual(destinations, ['/projects', '/projects?status=closed'])
  assert.equal(visible.value, false)
})

test('application batches explain why open records are not currently applicable', () => {
  const source = readFileSync(new URL('../src/views/ApplicationBatchesView.vue', import.meta.url), 'utf8')
  const declaration = source.match(/function applicationEligibility\(batch, now = new Date\(\)\) \{([\s\S]*?)\n\}/)
  assert.ok(declaration, 'Batch application eligibility helper must exist')
  const applicationEligibility = runInNewContext(`(function applicationEligibility(batch, now) { ${declaration[1]} })`)
  const now = new Date('2026-10-17T00:00:00.000Z')

  assert.equal(applicationEligibility({ code: 'E2E-001', name: 'Test', status: 'open' }, now), '测试批次，不可申报')
  assert.equal(applicationEligibility({ code: 'HISTORY-DEFAULT', name: '历史默认批次', status: 'open' }, now), '历史默认批次，不可申报')
  assert.equal(applicationEligibility({ code: '2026', name: '已结束批次', status: 'open', ends_at: '2026-10-16T23:59:59Z' }, now), '申报时间已结束')
  assert.equal(applicationEligibility({ code: '2026', name: '未开放批次', status: 'open', starts_at: '2026-10-18T00:00:00Z' }, now), '尚未开始申报')
  assert.equal(applicationEligibility({ code: '2026', name: '当前批次', status: 'open', starts_at: '2026-10-16T00:00:00Z', ends_at: '2026-10-18T00:00:00Z' }, now), '当前可申报')
  assert.equal(applicationEligibility({ code: '2026', name: '关闭批次', status: 'closed' }, now), '当前不可申报')
})
