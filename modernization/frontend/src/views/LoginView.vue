<template>
  <main class="login-page">
    <section class="login-panel">
      <div>
        <p class="eyebrow">测试环境</p>
        <h1>项目申报系统</h1>
        <p>新系统承接新增项目，旧系统保留历史查询。</p>
      </div>
      <el-alert
        v-if="route.query.switch"
        title="已退出当前账号，请重新登录"
        type="info"
        show-icon
        :closable="false"
      />
      <el-form :model="form" label-position="top" @submit.prevent="submit">
        <el-form-item label="账号">
          <el-input v-model="form.username" autocomplete="username" />
        </el-form-item>
        <el-form-item label="密码">
          <el-input v-model="form.password" type="password" autocomplete="current-password" show-password />
        </el-form-item>
        <el-form-item label="验证码">
          <div class="captcha-row">
            <el-input v-model="form.captcha_answer" inputmode="numeric" autocomplete="off" :placeholder="captcha.question || '加载中'" />
            <el-button :icon="Refresh" circle :loading="captchaLoading" @click="loadCaptcha" />
          </div>
        </el-form-item>
        <el-alert v-if="error" :title="error" type="error" show-icon :closable="false" />
        <el-button type="primary" native-type="submit" :loading="loading" class="full-button">登录</el-button>
        <el-button class="full-button secondary-action" @click="clearAndReload">切换账号</el-button>
      </el-form>
    </section>
  </main>
</template>

<script setup>
import { onMounted, reactive, ref } from 'vue'
import { Refresh } from '@element-plus/icons-vue'
import { useRoute, useRouter } from 'vue-router'
import { api } from '../api.js'
import { useSessionStore } from '../store.js'

const route = useRoute()
const router = useRouter()
const session = useSessionStore()
const loading = ref(false)
const captchaLoading = ref(false)
const error = ref('')
const captcha = reactive({ id: '', question: '' })
const form = reactive({ username: 'admin', password: 'ChangeMe-2026', captcha_id: '', captcha_answer: '' })

async function loadCaptcha() {
  captchaLoading.value = true
  try {
    const result = await api('/auth/captcha')
    captcha.id = result.captcha_id
    captcha.question = result.question
    form.captcha_id = result.captcha_id
    form.captcha_answer = ''
  } finally {
    captchaLoading.value = false
  }
}

async function submit() {
  loading.value = true
  error.value = ''
  try {
    await session.login(form)
    router.push('/dashboard')
  } catch (err) {
    error.value = err.message
    await loadCaptcha()
  } finally {
    loading.value = false
  }
}

function clearAndReload() {
  session.clearSession()
  error.value = ''
  form.password = ''
  form.captcha_answer = ''
  router.replace('/login?switch=1')
  loadCaptcha()
}

onMounted(loadCaptcha)
</script>
