<template>
  <main class="public-home">
    <header class="public-nav">
      <strong>{{ home.nav.title }}</strong>
      <nav>
        <a v-for="link in home.nav.links" :key="link.label" :href="link.href">{{ link.label }}</a>
      </nav>
    </header>

    <section v-if="loading" class="public-empty">正在加载首页内容...</section>
    <section v-else-if="loadError" class="public-empty">首页内容暂时无法加载</section>
    <section v-else-if="!hasHomeContent" class="public-empty">首页内容暂未配置</section>
    <template v-else>
      <section class="public-hero">
        <div class="hero-copy">
          <p class="eyebrow">{{ home.hero.eyebrow }}</p>
          <h1>{{ home.hero.title }}</h1>
          <p>{{ home.hero.description }}</p>
          <div class="public-actions">
            <RouterLink v-if="home.hero.primary_action.label && isRouterTarget(home.hero.primary_action.href)" class="primary-link" :to="home.hero.primary_action.href">
              {{ home.hero.primary_action.label }}
            </RouterLink>
            <a v-else-if="home.hero.primary_action.label" class="primary-link" :href="actionHref(home.hero.primary_action)">{{ home.hero.primary_action.label }}</a>
            <RouterLink v-if="home.hero.secondary_action.label && isRouterTarget(home.hero.secondary_action.href)" class="secondary-link" :to="home.hero.secondary_action.href">
              {{ home.hero.secondary_action.label }}
            </RouterLink>
            <a v-else-if="home.hero.secondary_action.label" class="secondary-link" :href="actionHref(home.hero.secondary_action)">{{ home.hero.secondary_action.label }}</a>
          </div>
        </div>

        <div class="hero-panel" aria-label="平台服务状态">
          <span>当前服务</span>
          <strong>{{ home.hero.status_title }}</strong>
          <div v-for="item in home.hero.status_items" :key="item.label">
            <small>{{ item.label }}</small>
            <b>{{ item.value }}</b>
          </div>
        </div>
      </section>

      <section id="notices" class="public-section feature-strip">
        <article v-for="item in home.highlights" :key="item.label">
          <span>{{ item.label }}</span>
          <strong>{{ item.value }}</strong>
          <p>{{ item.description }}</p>
        </article>
      </section>

      <section class="public-section public-two-column">
        <div class="portal-card">
          <div class="portal-card-title">
            <strong>通知公告</strong>
            <a href="#notices">更多</a>
          </div>
          <ul class="portal-list">
            <li v-for="item in home.notices" :key="item.id || item.title">
              <button type="button" @click="selectedNotice = item">{{ item.title }}</button>
              <span>{{ item.date }}</span>
            </li>
            <li v-if="home.notices.length === 0"><span>暂无通知</span></li>
          </ul>
        </div>

        <aside class="notice-detail">
          <template v-if="selectedNotice">
            <span>公告详情</span>
            <strong>{{ selectedNotice.title }}</strong>
            <p>{{ selectedNotice.summary || selectedNotice.body }}</p>
            <a v-if="selectedNotice.href" class="primary-link" :href="selectedNotice.href">查看详情</a>
            <RouterLink v-else-if="isRouterTarget(home.hero.primary_action.href)" class="primary-link" :to="home.hero.primary_action.href">
              {{ home.hero.primary_action.label }}
            </RouterLink>
          </template>
          <template v-else>
            <span>公告详情</span>
            <strong>暂无通知</strong>
          </template>
        </aside>
      </section>

      <section id="services" class="public-section">
        <div class="section-heading">
          <p class="eyebrow">Online Services</p>
          <h2>服务事项</h2>
        </div>
        <div class="service-grid">
          <article v-for="service in home.services" :key="service.title">
            <span>{{ service.code }}</span>
            <strong>{{ service.title }}</strong>
            <p>{{ service.description }}</p>
          </article>
        </div>
      </section>

      <section id="downloads" class="public-section public-two-column public-band">
        <div class="portal-card">
          <div class="portal-card-title">
            <strong>资料下载</strong>
            <a href="#downloads">更多</a>
          </div>
          <ul class="portal-list">
            <li v-for="item in home.downloads" :key="item.id || item.title">
              <button type="button" @click="selectedDownload = item">{{ item.title }}</button>
              <span>{{ item.date }}</span>
            </li>
            <li v-if="home.downloads.length === 0"><span>暂无资料</span></li>
          </ul>
        </div>

        <aside class="notice-detail">
          <template v-if="selectedDownload">
            <span>资料说明</span>
            <strong>{{ selectedDownload.title }}</strong>
            <p>{{ selectedDownload.summary }}</p>
            <small v-if="selectedDownload.original_name">{{ selectedDownload.original_name }} {{ formatSize(selectedDownload.size_bytes) }}</small>
            <a v-if="selectedDownload.download_url" class="secondary-link" :href="selectedDownload.download_url">下载资料</a>
          </template>
          <template v-else>
            <span>资料说明</span>
            <strong>暂无资料</strong>
          </template>
        </aside>
      </section>

      <footer class="public-footer">{{ home.footer }}</footer>
    </template>
  </main>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'

const home = ref(emptyHomeContent())
const selectedNotice = ref(null)
const selectedDownload = ref(null)
const loading = ref(false)
const loadError = ref(false)
const hasHomeContent = computed(() => Boolean(
  home.value.nav.title ||
  home.value.hero.title ||
  home.value.highlights.length ||
  home.value.notices.length ||
  home.value.downloads.length ||
  home.value.services.length ||
  home.value.footer
))

function emptyHomeContent() {
  return {
    nav: { title: '', links: [] },
    hero: {
      eyebrow: '',
      title: '',
      description: '',
      primary_action: { label: '', href: '#' },
      secondary_action: { label: '', href: '#' },
      status_title: '',
      status_items: []
    },
    highlights: [],
    notices: [],
    downloads: [],
    services: [],
    footer: ''
  }
}

function normalizeHomeContent(payload) {
  const fallback = emptyHomeContent()
  if (!payload || typeof payload !== 'object') return fallback

  return {
    nav: {
      title: payload.nav?.title || '',
      links: Array.isArray(payload.nav?.links) ? payload.nav.links : []
    },
    hero: {
      eyebrow: payload.hero?.eyebrow || '',
      title: payload.hero?.title || '',
      description: payload.hero?.description || '',
      primary_action: payload.hero?.primary_action || fallback.hero.primary_action,
      secondary_action: payload.hero?.secondary_action || fallback.hero.secondary_action,
      status_title: payload.hero?.status_title || '',
      status_items: Array.isArray(payload.hero?.status_items) ? payload.hero.status_items : []
    },
    highlights: Array.isArray(payload.highlights) ? payload.highlights : [],
    notices: Array.isArray(payload.notices) ? payload.notices : [],
    downloads: Array.isArray(payload.downloads) ? payload.downloads : [],
    services: Array.isArray(payload.services) ? payload.services : [],
    footer: payload.footer || ''
  }
}

async function loadHomeContent() {
  loading.value = true
  loadError.value = false
  try {
    const response = await fetch('/api/public/homepage', { headers: { Accept: 'application/json' } })
    if (!response.ok) throw new Error('load_failed')
    home.value = normalizeHomeContent(await response.json())
    selectedNotice.value = home.value.notices[0] || null
    selectedDownload.value = home.value.downloads[0] || null
  } catch {
    home.value = emptyHomeContent()
    selectedNotice.value = null
    selectedDownload.value = null
    loadError.value = true
  } finally {
    loading.value = false
  }
}

function isRouterTarget(href) {
  return typeof href === 'string' && href.startsWith('/')
}

function actionHref(action) {
  return action?.href || '#'
}

function formatSize(bytes) {
  const value = Number(bytes || 0)
  if (!value) return ''
  if (value < 1024) return `${value} B`
  if (value < 1024 * 1024) return `${Math.round(value / 1024)} KB`
  return `${(value / 1024 / 1024).toFixed(1)} MB`
}

onMounted(loadHomeContent)
</script>
