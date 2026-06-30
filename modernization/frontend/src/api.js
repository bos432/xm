const API_BASE = import.meta.env.VITE_API_BASE || '/api'

function expireSession() {
  localStorage.removeItem('pas_token')
  window.dispatchEvent(new Event('auth:expired'))
}

export async function api(path, options = {}) {
  const token = localStorage.getItem('pas_token')
  const headers = new Headers(options.headers || {})
  headers.set('Accept', 'application/json')

  if (!(options.body instanceof FormData)) {
    headers.set('Content-Type', 'application/json')
  }

  if (token) {
    headers.set('Authorization', `Bearer ${token}`)
  }

  const response = await fetch(`${API_BASE}${path}`, { ...options, headers })
  if (!response.ok) {
    if (response.status === 401) expireSession()
    const error = await response.json().catch(() => ({ message: '请求失败' }))
    const requestError = new Error(error.message || '请求失败')
    requestError.status = response.status
    Object.assign(requestError, error)
    throw requestError
  }

  if (response.status === 204) return null
  return response.json()
}

export async function downloadApi(path, filename) {
  const token = localStorage.getItem('pas_token')
  const headers = new Headers()
  if (token) headers.set('Authorization', `Bearer ${token}`)

  const response = await fetch(`${API_BASE}${path}`, { headers })
  if (!response.ok) {
    if (response.status === 401) expireSession()
    const contentType = response.headers.get('Content-Type') || ''
    if (contentType.includes('application/json')) {
      const error = await response.json().catch(() => ({ message: '下载失败' }))
      throw new Error(error.message || '下载失败')
    }
    const message = await response.text().catch(() => '下载失败')
    throw new Error(message || '下载失败')
  }

  const blob = await response.blob()
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  link.click()
  URL.revokeObjectURL(url)
}
