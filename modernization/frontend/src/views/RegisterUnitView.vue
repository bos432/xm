<template>
  <main class="auth-page gov-auth-page">
    <section class="auth-card register-card">
      <div class="auth-card-head">
        <RouterLink to="/">返回首页</RouterLink>
        <span>单位注册</span>
      </div>
      <h1>申报单位注册申请</h1>
      <p>注册后账号处于待审核状态，管理员启用单位和账号后方可登录申报。</p>

      <el-form :model="form" label-position="top" class="auth-form-grid" @submit.prevent="submit">
        <el-form-item label="单位名称" class="wide-field">
          <el-input v-model="form.unit_name" />
        </el-form-item>
        <el-form-item label="统一社会信用代码">
          <el-input v-model="form.credit_code" />
        </el-form-item>
        <el-form-item label="区域编码">
          <el-input v-model="form.region_code" />
        </el-form-item>
        <el-form-item label="联系人">
          <el-input v-model="form.contact_name" />
        </el-form-item>
        <el-form-item label="联系电话">
          <el-input v-model="form.contact_mobile" />
        </el-form-item>
        <el-form-item label="邮箱">
          <el-input v-model="form.email" autocomplete="email" />
        </el-form-item>
        <el-form-item label="登录账号">
          <el-input v-model="form.username" autocomplete="username" />
        </el-form-item>
        <el-form-item label="密码">
          <el-input v-model="form.password" type="password" show-password autocomplete="new-password" />
        </el-form-item>
        <el-form-item label="确认密码">
          <el-input v-model="form.password_confirmation" type="password" show-password autocomplete="new-password" />
        </el-form-item>
        <el-form-item label="单位地址" class="wide-field">
          <el-input v-model="form.address" type="textarea" :rows="3" />
        </el-form-item>
        <el-form-item label="验证码" class="wide-field">
          <div class="captcha-row">
            <el-input v-model="form.captcha_answer" inputmode="numeric" :placeholder="captcha.question || '加载中'" />
            <el-button :icon="Refresh" :loading="captchaLoading" @click="loadCaptcha" />
          </div>
        </el-form-item>
      </el-form>

      <el-alert v-if="message" :title="message" :type="messageType" show-icon :closable="false" />
      <el-button type="primary" :loading="submitting" class="full-button" @click="submit">提交注册申请</el-button>
      <div class="auth-links">
        <RouterLink to="/login">已有账号，去登录</RouterLink>
        <RouterLink to="/forgot-password">忘记密码</RouterLink>
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
const form = reactive({
  unit_name: '',
  credit_code: '',
  contact_name: '',
  contact_mobile: '',
  email: '',
  address: '',
  region_code: '',
  username: '',
  password: '',
  password_confirmation: '',
  captcha_id: '',
  captcha_answer: ''
})

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
    const result = await api('/auth/register-unit', {
      method: 'POST',
      body: JSON.stringify({
        ...form,
        captcha_answer: Number(form.captcha_answer)
      })
    })
    messageType.value = 'success'
    message.value = result.message || '注册申请已提交，请等待管理员审核启用。'
  } catch (err) {
    messageType.value = 'error'
    message.value = err.message || '注册失败'
    await loadCaptcha()
  } finally {
    submitting.value = false
  }
}

onMounted(loadCaptcha)
</script>
