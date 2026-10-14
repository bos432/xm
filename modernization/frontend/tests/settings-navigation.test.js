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
