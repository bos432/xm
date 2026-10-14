export const e2eRoleCredentials = {
  unit: { usernameEnv: 'E2E_UNIT_USERNAME', passwordEnv: 'E2E_UNIT_PASSWORD', expectedRole: 'unit' },
  county: { usernameEnv: 'E2E_COUNTY_USERNAME', passwordEnv: 'E2E_COUNTY_PASSWORD', expectedRole: 'county' },
  department: { usernameEnv: 'E2E_DEPARTMENT_USERNAME', passwordEnv: 'E2E_DEPARTMENT_PASSWORD', expectedRole: 'department' },
  expert: { usernameEnv: 'E2E_EXPERT_USERNAME', passwordEnv: 'E2E_EXPERT_PASSWORD', expectedRole: 'expert' },
  admin: { usernameEnv: 'E2E_ADMIN_USERNAME', passwordEnv: 'E2E_ADMIN_PASSWORD', expectedRole: 'admin' },
  super_admin: { usernameEnv: 'E2E_SUPER_ADMIN_USERNAME', passwordEnv: 'E2E_SUPER_ADMIN_PASSWORD', expectedRole: 'super_admin' }
}

export async function fetchAuthenticatedRole(fetcher, token) {
  const response = await fetcher('/api/auth/me', {
    headers: { Authorization: `Bearer ${token}`, Accept: 'application/json' }
  })
  if (!response.ok) throw new Error('Could not verify the authenticated E2E role')

  return (await response.json()).role
}
