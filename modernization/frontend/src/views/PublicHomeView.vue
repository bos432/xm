<template>
  <main class="gov-portal">
    <div class="gov-topbar">
      <div class="gov-wrap">
        <span>在线帮助</span>
        <span>全站导航</span>
        <span>本平台为互联网非涉密平台，请勿上传涉密资料</span>
        <div class="gov-topbar-links">
          <RouterLink to="/login">登录</RouterLink>
          <RouterLink to="/register">单位注册</RouterLink>
          <RouterLink to="/forgot-password">忘记密码</RouterLink>
        </div>
      </div>
    </div>

    <header class="gov-header">
      <div class="gov-wrap gov-brand-row">
        <img v-if="home.brand.logo_url" class="gov-logo" :src="home.brand.logo_url" :alt="home.brand.logo_alt || home.nav.title" />
        <div v-else class="gov-emblem">科</div>
        <div>
          <strong>{{ home.nav.title || '阿拉善盟科技计划项目管理信息系统' }}</strong>
          <span>科技计划项目申报、审核、评审与验收公共服务平台</span>
        </div>
      </div>
      <nav class="gov-main-nav">
        <div class="gov-wrap">
          <a v-for="link in home.nav.links" :key="link.label" :href="link.href">{{ link.label }}</a>
          <RouterLink to="/login">项目管理入口</RouterLink>
        </div>
      </nav>
    </header>

    <section v-if="loading" class="public-empty">正在加载首页内容...</section>
    <section v-else-if="loadError" class="public-empty">首页内容暂时无法加载</section>
    <section v-else-if="!hasHomeContent" class="public-empty">首页内容暂未配置</section>

    <template v-else>
      <section class="gov-masthead" :style="bannerStyle">
        <div class="gov-wrap gov-masthead-grid">
          <div class="gov-banner">
            <p>{{ home.hero.eyebrow || '科技计划项目申报服务' }}</p>
            <h1>{{ home.hero.title }}</h1>
            <span>{{ home.hero.description }}</span>
          </div>

          <aside class="gov-login-box">
            <div class="gov-box-title">
              <strong>用户登录</strong>
            </div>
            <el-form :model="loginForm" label-position="top" @submit.prevent="submitLogin">
              <el-form-item label="登录名">
                <el-input v-model="loginForm.username" autocomplete="username" />
              </el-form-item>
              <el-form-item label="密码">
                <el-input v-model="loginForm.password" type="password" autocomplete="current-password" show-password />
              </el-form-item>
              <el-form-item label="验证码">
                <div class="captcha-row">
                  <el-input v-model="loginForm.captcha_answer" inputmode="numeric" :placeholder="captcha.question || '加载中'" />
                  <el-button :icon="Refresh" :loading="captchaLoading" @click="loadCaptcha" />
                </div>
              </el-form-item>
              <el-alert v-if="loginError" :title="loginError" type="error" show-icon :closable="false" />
              <el-button type="primary" native-type="submit" :loading="loginLoading" class="full-button">登录系统</el-button>
            </el-form>
            <div class="gov-login-links">
              <RouterLink to="/forgot-password">忘记密码</RouterLink>
              <RouterLink to="/register">新单位注册</RouterLink>
            </div>
          </aside>
        </div>
      </section>

      <section class="gov-wrap gov-quick-row" aria-label="申报服务入口">
        <RouterLink v-if="isRouterTarget(home.hero.primary_action.href)" class="gov-quick-card primary" :to="home.hero.primary_action.href || '/login'">
          <strong>{{ home.hero.primary_action.label || '项目申报入口' }}</strong>
          <span>项目填报、附件上传、提交审核</span>
        </RouterLink>
        <a v-else class="gov-quick-card primary" :href="actionHref(home.hero.primary_action.href)">
          <strong>{{ home.hero.primary_action.label || '项目申报入口' }}</strong>
          <span>项目填报、附件上传、提交审核</span>
        </a>
        <a class="gov-quick-card" href="#notices">
          <strong>通知公告</strong>
          <span>申报指南、公示公告、工作通知</span>
        </a>
        <a class="gov-quick-card" href="#downloads">
          <strong>资料下载</strong>
          <span>申报书、承诺书、操作手册</span>
        </a>
        <a class="gov-quick-card" href="#services">
          <strong>办事服务</strong>
          <span>审核、评审、验收、延期办理</span>
        </a>
      </section>

      <section class="gov-wrap gov-main-grid">
        <div class="gov-news-panel" id="notices">
          <div class="gov-section-head">
            <strong>通知公告</strong>
            <span>Notice</span>
          </div>
          <ul class="gov-news-list">
            <li v-for="item in home.notices" :key="item.id || item.title">
              <button type="button" @click="selectedNotice = item">{{ item.title }}</button>
              <time>{{ item.date }}</time>
            </li>
            <li v-if="home.notices.length === 0"><span>暂无通知</span></li>
          </ul>
        </div>

        <aside class="gov-side-panel">
          <div class="gov-section-head compact">
            <strong>重要提示</strong>
          </div>
          <template v-if="selectedNotice">
            <b>{{ selectedNotice.title }}</b>
            <p>{{ selectedNotice.summary || selectedNotice.body }}</p>
            <a v-if="selectedNotice.href" :href="selectedNotice.href">查看详情</a>
          </template>
          <template v-else>
            <b>{{ home.hero.status_title || '平台运行正常' }}</b>
            <p>请申报单位按通知要求准备材料，完成注册审核后登录系统办理。</p>
          </template>
          <div class="gov-status-list">
            <span v-if="home.current_batch">当前批次：{{ home.current_batch.name }}</span>
            <span v-for="item in home.hero.status_items" :key="item.label">{{ item.label }}：{{ item.value }}</span>
          </div>
        </aside>
      </section>

      <section class="gov-wrap gov-columns">
        <div class="gov-news-panel" id="downloads">
          <div class="gov-section-head">
            <strong>资料下载</strong>
            <span>Download</span>
          </div>
          <ul class="gov-news-list">
            <li v-for="item in home.downloads" :key="item.id || item.title">
              <a v-if="item.download_url" :href="item.download_url">{{ item.title }}</a>
              <button v-else type="button" @click="selectedDownload = item">{{ item.title }}</button>
              <time>{{ item.date }}</time>
            </li>
            <li v-if="home.downloads.length === 0"><span>暂无资料</span></li>
          </ul>
        </div>

        <div class="gov-news-panel" id="services">
          <div class="gov-section-head">
            <strong>在线服务</strong>
            <span>Service</span>
          </div>
          <div class="gov-service-list">
            <article v-for="service in home.services" :key="service.title">
              <span>{{ service.code }}</span>
              <div>
                <strong>{{ service.title }}</strong>
                <p>{{ service.description }}</p>
              </div>
            </article>
          </div>
        </div>
      </section>

      <section class="gov-wrap gov-data-strip">
        <article v-for="item in home.highlights" :key="item.label">
          <span>{{ item.label }}</span>
          <strong>{{ item.value }}</strong>
          <p>{{ item.description }}</p>
        </article>
      </section>

      <footer class="gov-footer">{{ home.footer }}</footer>
    </template>
  </main>
</template>

<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { Refresh } from '@element-plus/icons-vue'
import { api } from '../api.js'
import { useSessionStore } from '../store.js'

const router = useRouter()
const session = useSessionStore()
const home = ref(emptyHomeContent())
const selectedNotice = ref(null)
const selectedDownload = ref(null)
const loading = ref(false)
const loadError = ref(false)
const loginLoading = ref(false)
const captchaLoading = ref(false)
const loginError = ref('')
const captcha = reactive({ id: '', question: '' })
const loginForm = reactive({ username: '', password: '', captcha_id: '', captcha_answer: '' })
const hasHomeContent = computed(() => Boolean(
  home.value.nav.title ||
  home.value.brand.logo_url ||
  home.value.hero.title ||
  home.value.hero.banner_url ||
  home.value.highlights.length ||
  home.value.notices.length ||
  home.value.downloads.length ||
  home.value.services.length ||
  home.value.footer
))

function emptyHomeContent() {
  return {
    nav: { title: '', links: [] },
    brand: { logo_url: null, logo_alt: '系统标识' },
    hero: {
      eyebrow: '',
      title: '',
      description: '',
      banner_url: null,
      banner_alt: '首页横幅',
      primary_action: { label: '', href: '/login' },
      secondary_action: { label: '', href: '#notices' },
      status_title: '',
      status_items: []
    },
    highlights: [],
    notices: [],
    downloads: [],
    services: [],
    open_batches: [],
    current_batch: null,
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
    brand: {
      logo_url: payload.brand?.logo_url || null,
      logo_alt: payload.brand?.logo_alt || '系统标识'
    },
    hero: {
      eyebrow: payload.hero?.eyebrow || '',
      title: payload.hero?.title || '',
      description: payload.hero?.description || '',
      banner_url: payload.hero?.banner_url || null,
      banner_alt: payload.hero?.banner_alt || '首页横幅',
      primary_action: payload.hero?.primary_action || fallback.hero.primary_action,
      secondary_action: payload.hero?.secondary_action || fallback.hero.secondary_action,
      status_title: payload.hero?.status_title || '',
      status_items: Array.isArray(payload.hero?.status_items) ? payload.hero.status_items : []
    },
    highlights: Array.isArray(payload.highlights) ? payload.highlights : [],
    notices: Array.isArray(payload.notices) ? payload.notices : [],
    downloads: Array.isArray(payload.downloads) ? payload.downloads : [],
    services: Array.isArray(payload.services) ? payload.services : [],
    open_batches: Array.isArray(payload.open_batches) ? payload.open_batches : [],
    current_batch: payload.current_batch || null,
    footer: payload.footer || ''
  }
}

const bannerStyle = computed(() => {
  if (!home.value.hero.banner_url) return {}

  return {
    backgroundImage: `linear-gradient(90deg, rgba(9, 64, 126, 0.9), rgba(15, 92, 162, 0.76)), url("${home.value.hero.banner_url}")`
  }
})

function isRouterTarget(href) {
  return typeof href === 'string' && href.startsWith('/')
}

function actionHref(href) {
  return href || '/login'
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

async function loadCaptcha() {
  captchaLoading.value = true
  try {
    const result = await api('/auth/captcha')
    captcha.id = result.captcha_id
    captcha.question = result.question
    loginForm.captcha_id = result.captcha_id
    loginForm.captcha_answer = ''
  } finally {
    captchaLoading.value = false
  }
}

async function submitLogin() {
  loginLoading.value = true
  loginError.value = ''
  try {
    await session.login(loginForm)
    ElMessage.success('登录成功')
    router.push('/dashboard')
  } catch (err) {
    loginError.value = err.message || '登录失败'
    await loadCaptcha()
  } finally {
    loginLoading.value = false
  }
}

onMounted(() => {
  loadHomeContent()
  loadCaptcha()
})
</script>
