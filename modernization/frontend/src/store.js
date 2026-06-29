import { defineStore } from 'pinia'
import { api } from './api.js'

export const useSessionStore = defineStore('session', {
  state: () => ({
    user: null,
    token: localStorage.getItem('pas_token') || ''
  }),
  getters: {
    permissions: (state) => state.user?.permissions || [],
    menus: (state) => state.user?.menus || [],
    role: (state) => state.user?.role || '',
    can: (state) => (permission) => (state.user?.permissions || []).includes(permission)
  },
  actions: {
    async login(credentials) {
      const result = await api('/auth/login', {
        method: 'POST',
        body: JSON.stringify(credentials)
      })
      this.token = result.token
      this.user = result.user
      localStorage.setItem('pas_token', result.token)
    },
    async loadMe() {
      if (!this.token) return
      this.user = await api('/auth/me')
    },
    logout() {
      const token = this.token
      this.clearSession()
      if (!token) return

      void fetch('/api/auth/logout', {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          Authorization: `Bearer ${token}`
        }
      }).catch(() => null)
    },
    clearSession() {
      this.token = ''
      this.user = null
      localStorage.removeItem('pas_token')
    }
  }
})
