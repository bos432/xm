import test from 'node:test'
import assert from 'node:assert/strict'
import { e2eRoleCredentials, fetchAuthenticatedRole } from '../src/e2e-role-config.js'

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

test('authenticated role verification reads the API role payload', async () => {
  let request
  const role = await fetchAuthenticatedRole(async (path, options) => {
    request = { path, options }
    return { ok: true, json: async () => ({ id: 7, role: 'admin' }) }
  }, 'test-token')

  assert.equal(role, 'admin')
  assert.equal(request.path, '/api/auth/me')
  assert.equal(request.options.headers.Authorization, 'Bearer test-token')
})

test('authenticated role verification rejects unauthorized profile responses', async () => {
  await assert.rejects(
    fetchAuthenticatedRole(async () => ({ ok: false, json: async () => ({}) }), 'expired-token'),
    /Could not verify the authenticated E2E role/
  )
})
