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
    const response = await fetch('/api/public/homepage', { headers: { Accept: 'application/json' } })
    if (!response.ok) return

    const payload = await response.json()
    setFavicon(payload?.brand?.favicon_url)
  } catch {
    // Favicon is cosmetic; the app should still load if the public config request fails.
  }
}
