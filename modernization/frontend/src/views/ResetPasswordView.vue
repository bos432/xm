<template>
  <main class="auth-page gov-auth-page">
    <section class="auth-card">
      <div class="auth-card-head">
        <RouterLink to="/">返回首页</RouterLink>
        <span>重置密码</span>
      </div>
      <h1>设置新密码</h1>
      <p>密码重置链接 60 分钟内有效。新密码保存后，请使用新密码重新登录。</p>

      <el-form :model="form" label-position="top" @submit.prevent="submit">
        <el-form-item label="邮箱">
          <el-input v-model="form.email" autocomplete="email" />
        </el-form-item>
        <el-form-item label="重置令牌">
          <el-input v-model="form.token" />
        </el-form-item>
        <el-form-item label="新密码">
          <el-input v-model="form.password" type="password" show-password autocomplete="new-password" />
        </el-form-item>
        <el-form-item label="确认新密码">
          <el-input v-model="form.password_confirmation" type="password" show-password autocomplete="new-password" />
        </el-form-item>
      </el-form>

      <el-alert v-if="message" :title="message" :type="messageType" show-icon :closable="false" />
      <el-button type="primary" :loading="submitting" class="full-button" @click="submit">保存新密码</el-button>
      <div class="auth-links">
        <RouterLink to="/login">返回登录</RouterLink>
        <RouterLink to="/forgot-password">重新发送邮件</RouterLink>
      </div>
    </section>
  </main>
</template>

<script setup>
import { onMounted, reactive, ref } from 'vue'
import { useRoute } from 'vue-router'
import { api } from '../api.js'

const route = useRoute()
const submitting = ref(false)
const message = ref('')
const messageType = ref('success')
const form = reactive({
  email: '',
  token: '',
  password: '',
  password_confirmation: ''
})

async function submit() {
  submitting.value = true
  message.value = ''
  try {
    const result = await api('/auth/reset-password', {
      method: 'POST',
      body: JSON.stringify(form)
    })
    messageType.value = 'success'
    message.value = result.message || '密码已重置，请重新登录。'
  } catch (err) {
    messageType.value = 'error'
    message.value = err.message || '重置失败'
  } finally {
    submitting.value = false
  }
}

onMounted(() => {
  form.email = route.query.email || ''
  form.token = route.query.token || ''
})
</script>
