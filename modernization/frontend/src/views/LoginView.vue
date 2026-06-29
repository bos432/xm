<template>
  <main class="auth-page gov-auth-page">
    <section class="auth-card">
      <div class="auth-card-head">
        <RouterLink to="/">返回首页</RouterLink>
        <span>用户登录</span>
      </div>
      <h1>项目管理系统登录</h1>
      <p>申报单位、审核单位、专家和管理员按角色登录办理业务。</p>
      <el-alert
        v-if="route.query.switch"
        title="已退出当前账号，请重新登录"
        type="info"
        show-icon
        :closable="false"
      />
      <el-form :model="form" label-position="top" @submit.prevent="submit">
        <el-form-item label="登录名">
          <el-input v-model="form.username" autocomplete="username" />
        </el-form-item>
        <el-form-item label="密码">
          <el-input v-model="form.password" type="password" autocomplete="current-password" show-password />
        </el-form-item>
        <el-form-item label="验证码">
          <div class="captcha-row">
            <el-input v-model="form.captcha_answer" inputmode="numeric" autocomplete="off" :placeholder="captcha.question || '加载中'" />
            <el-button :icon="Refresh" :loading="captchaLoading" @click="loadCaptcha" />
          </div>
        </el-form-item>
        <el-alert v-if="error" :title="error" type="error" show-icon :closable="false" />
        <el-button type="primary" native-type="submit" :loading="loading" class="full-button">登录</el-button>
      </el-form>
      <div class="auth-links">
        <RouterLink to="/register">单位注册</RouterLink>
        <RouterLink to="/forgot-password">忘记密码</RouterLink>
      </div>
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
const form = reactive({ username: '', password: '', captcha_id: '', captcha_answer: '' })

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

onMounted(loadCaptcha)
</script>
