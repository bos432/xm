<template>
  <main class="auth-page gov-auth-page">
    <section class="auth-card">
      <div class="auth-card-head">
        <RouterLink to="/">返回首页</RouterLink>
        <span>找回密码</span>
      </div>
      <h1>邮箱找回密码</h1>
      <p>输入注册时绑定的邮箱。若邮箱存在，系统会发送一次性密码重置链接。</p>

      <el-form :model="form" label-position="top" @submit.prevent="submit">
        <el-form-item label="绑定邮箱">
          <el-input v-model="form.email" autocomplete="email" />
        </el-form-item>
        <el-form-item label="验证码">
          <div class="captcha-row">
            <el-input v-model="form.captcha_answer" inputmode="numeric" :placeholder="captcha.question || '加载中'" />
            <el-button :icon="Refresh" :loading="captchaLoading" @click="loadCaptcha" />
          </div>
        </el-form-item>
      </el-form>

      <el-alert v-if="message" :title="message" :type="messageType" show-icon :closable="false" />
      <el-button type="primary" :loading="submitting" class="full-button" @click="submit">发送重置邮件</el-button>
      <div class="auth-links">
        <RouterLink to="/login">返回登录</RouterLink>
        <RouterLink to="/register">单位注册</RouterLink>
      </div>
    </section>
  </main>
</template>

<script setup>
import { onMounted, reactive, ref } from 'vue'
import { Refresh } from '@element-plus/icons-vue'
import { api } from '../api.js'

const submitting = ref(false)
const captchaLoading = ref(false)
const message = ref('')
const messageType = ref('success')
const captcha = reactive({ id: '', question: '' })
const form = reactive({ email: '', captcha_id: '', captcha_answer: '' })

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
  submitting.value = true
  message.value = ''
  try {
    const result = await api('/auth/forgot-password', {
      method: 'POST',
      body: JSON.stringify({
        email: form.email,
        captcha_id: form.captcha_id,
        captcha_answer: Number(form.captcha_answer)
      })
    })
    messageType.value = 'success'
    message.value = result.message || '如果邮箱已绑定账号，系统将发送密码重置邮件。'
  } catch (err) {
    messageType.value = 'error'
    message.value = err.message || '提交失败'
    await loadCaptcha()
  } finally {
    submitting.value = false
  }
}

onMounted(loadCaptcha)
</script>
