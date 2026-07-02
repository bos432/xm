import { api } from './api.js'

export function setFavicon(href) {
  if (!href || typeof document === 'undefined') return

  let link = document.querySelector('link[rel="icon"]')
  if (!link) {
    link = document.createElement('link')
    link.rel = 'icon'
    document.head.appendChild(link)
  }

  link.href = href
}

export async function loadConfiguredFavicon() {
  try {
    const payload = await api('/public/homepage')
    setFavicon(payload?.brand?.favicon_url)
  } catch {
    // Favicon is cosmetic; the app should still load if the public config request fails.
  }
}
