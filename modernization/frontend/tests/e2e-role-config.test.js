import test from 'node:test'
import assert from 'node:assert/strict'
import { e2eRoleCredentials } from '../src/e2e-role-config.js'

test('E2E role credentials map business admin and super admin to distinct role accounts', () => {
  assert.deepEqual(e2eRoleCredentials.admin, {
    usernameEnv: 'E2E_ADMIN_USERNAME',
    passwordEnv: 'E2E_ADMIN_PASSWORD',
    expectedRole: 'admin'
  })
  assert.deepEqual(e2eRoleCredentials.super_admin, {
    usernameEnv: 'E2E_SUPER_ADMIN_USERNAME',
    passwordEnv: 'E2E_SUPER_ADMIN_PASSWORD',
    expectedRole: 'super_admin'
  })
  assert.notEqual(e2eRoleCredentials.admin.expectedRole, e2eRoleCredentials.super_admin.expectedRole)
})
