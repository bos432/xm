<template>
  <section class="page-stack">
    <div class="toolbar">
      <div>
        <span class="eyebrow">System Settings</span>
        <h2>系统配置</h2>
        <p class="muted">仅超级管理员可维护运行时业务配置；数据库、APP_KEY、队列驱动等启动级配置仍保留在 .env。</p>
      </div>
      <el-button :icon="Refresh" :loading="loading" @click="loadGroups">刷新</el-button>
    </div>

    <el-alert
      v-if="reviewGroupMissing"
      type="warning"
      show-icon
      :closable="false"
      title="未加载到“审核与评分”配置分组"
      description="请确认后端 /api/settings/groups 已返回 review 分组，并检查当前账号是否为超级管理员。"
    />

    <div class="settings-overview-grid">
      <el-card shadow="never" class="settings-card">
        <template #header>队列状态</template>
        <dl class="settings-runtime-list">
          <div><dt>队列驱动</dt><dd>{{ runtime.queue_driver || '-' }}</dd></div>
          <div><dt>待处理任务</dt><dd>{{ runtime.pending_jobs ?? 0 }}</dd></div>
          <div><dt>失败任务</dt><dd>{{ runtime.failed_jobs ?? 0 }}</dd></div>
        </dl>
      </el-card>
      <el-card shadow="never" class="settings-card">
        <template #header>{{ texts.t('settings.public_home.card_title', '首页内容') }}</template>
        <p>{{ texts.t('settings.public_home.card_body', '导航、公告、下载、服务事项和 logo/banner 请进入首页管理维护。') }}</p>
        <el-button type="primary" plain @click="router.push('/public-home')">{{ texts.t('settings.public_home.button', '进入首页管理') }}</el-button>
      </el-card>
      <el-card shadow="never" class="settings-card">
        <template #header>测试邮件</template>
        <el-input v-model="testMailTo" placeholder="收件邮箱" />
        <el-button type="primary" :loading="testingMail" @click="sendTestMail">发送测试邮件</el-button>
      </el-card>
    </div>

    <div class="settings-group-shortcuts">
      <el-button
        v-for="group in groups"
        :key="group.key"
        :type="activeGroup === group.key ? 'primary' : 'default'"
        plain
        @click="switchGroup(group.key)"
      >
        {{ group.title }}
      </el-button>
    </div>

    <el-tabs v-model="activeGroup" @tab-change="switchGroup">
      <el-tab-pane v-for="group in groups" :key="group.key" :label="group.title" :name="group.key">
        <el-card shadow="never">
          <template #header>
            <div>
              <strong>{{ group.title }}</strong>
              <p class="muted">{{ group.description }}</p>
            </div>
          </template>
          <el-form label-position="top" class="home-manager-grid">
            <el-form-item v-for="field in group.fields" :key="field.key" :label="field.label" :class="{ 'wide-field': field.type === 'textarea' }">
              <el-switch v-if="field.type === 'boolean'" v-model="forms[group.key][field.key]" />
              <el-select v-else-if="field.type === 'select'" v-model="forms[group.key][field.key]" clearable>
                <el-option v-for="option in field.options || []" :key="String(option)" :label="option || '空'" :value="option" />
              </el-select>
              <el-input-number v-else-if="field.type === 'number'" v-model="forms[group.key][field.key]" :min="0" />
              <el-input v-else-if="field.type === 'password'" v-model="forms[group.key][field.key]" type="password" show-password :placeholder="field.configured ? field.value + '（留空保留原值）' : ''" />
              <el-input v-else-if="field.type === 'textarea'" v-model="forms[group.key][field.key]" type="textarea" :rows="4" />
              <el-input v-else v-model="forms[group.key][field.key]" />
            </el-form-item>
          </el-form>
          <el-button type="primary" :loading="savingGroup === group.key" @click="saveGroup(group)">保存 {{ group.title }}</el-button>
        </el-card>
      </el-tab-pane>
    </el-tabs>
  </section>
</template>

<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { ElMessage } from 'element-plus'
import { Refresh } from '@element-plus/icons-vue'
import { useRoute, useRouter } from 'vue-router'
import { api } from '../api.js'
import { useTextStore } from '../texts.js'

const router = useRouter()
const route = useRoute()
const texts = useTextStore()
const loading = ref(false)
const testingMail = ref(false)
const groups = ref([])
const activeGroup = ref('')
const runtime = ref({})
const forms = reactive({})
const savingGroup = ref('')
const testMailTo = ref('')
const reviewGroupMissing = computed(() => !loading.value && groups.value.length > 0 && !groups.value.some((group) => group.key === 'review'))

function fieldInitialValue(field) {
  if (field.type === 'boolean') return ['1', 'true', true].includes(field.value)
  if (field.type === 'number') return Number(field.value || field.default || 0)
  if (field.type === 'password') return ''
  return field.value ?? field.default ?? ''
}

async function loadGroups() {
  loading.value = true
  try {
    const result = await api('/settings/groups')
    groups.value = result.groups || []
    runtime.value = result.runtime || {}
    groups.value.forEach((group) => {
      forms[group.key] = {}
      group.fields.forEach((field) => {
        forms[group.key][field.key] = fieldInitialValue(field)
      })
    })
    applyRouteGroup()
  } finally {
    loading.value = false
  }
}

function applyRouteGroup() {
  const queryGroup = typeof route.query.group === 'string' ? route.query.group : ''
  const exists = groups.value.some((group) => group.key === queryGroup)
  activeGroup.value = exists ? queryGroup : (activeGroup.value || groups.value[0]?.key || '')
}

function switchGroup(groupKey) {
  if (!groupKey) return
  activeGroup.value = groupKey
  router.replace({ path: route.path, query: { ...route.query, group: groupKey } })
}

async function saveGroup(group) {
  savingGroup.value = group.key
  try {
    await api(`/settings/groups/${group.key}`, {
      method: 'PUT',
      body: JSON.stringify({ values: forms[group.key] })
    })
    ElMessage.success('配置已保存')
    await loadGroups()
  } finally {
    savingGroup.value = ''
  }
}

async function sendTestMail() {
  testingMail.value = true
  try {
    await api('/settings/mail/test', { method: 'POST', body: JSON.stringify({ to: testMailTo.value }) })
    ElMessage.success('测试邮件已加入发送队列')
  } finally {
    testingMail.value = false
  }
}

watch(() => route.query.group, applyRouteGroup)

onMounted(loadGroups)
</script>

<style scoped>
.settings-group-shortcuts {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
</style>
