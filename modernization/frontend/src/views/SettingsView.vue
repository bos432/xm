<template>
  <section class="page-stack">
    <div class="toolbar">
      <div>
        <span class="eyebrow">System Settings</span>
        <h2>系统配置</h2>
        <p class="muted">业务参数在此维护，运行时密钥和 SMTP 连接信息由生产环境配置文件托管。</p>
      </div>
      <el-button :icon="Refresh" :loading="loading || runtimeLoading" @click="loadAll">刷新</el-button>
    </div>

    <div class="settings-overview-grid">
      <el-card shadow="never" class="settings-card">
        <template #header>首页内容</template>
        <p>公开首页已改为独立内容模型维护，导航、横幅、公告、资料下载和服务事项请进入首页管理。</p>
        <el-button type="primary" plain @click="router.push('/public-home')">进入首页管理</el-button>
      </el-card>

      <el-card shadow="never" class="settings-card">
        <template #header>邮件发送</template>
        <dl class="settings-runtime-list">
          <div>
            <dt>发信驱动</dt>
            <dd><el-tag :type="mail.is_smtp ? 'success' : 'warning'">{{ mail.mailer || 'log' }}</el-tag></dd>
          </div>
          <div>
            <dt>SMTP 主机</dt>
            <dd>{{ mail.host || '未配置' }}<span v-if="mail.port">:{{ mail.port }}</span></dd>
          </div>
          <div>
            <dt>SMTP 账号</dt>
            <dd>{{ mail.username || '未配置' }}</dd>
          </div>
          <div>
            <dt>SMTP 密码</dt>
            <dd>{{ mail.password_configured ? '已配置' : '未配置' }}</dd>
          </div>
          <div>
            <dt>发件地址</dt>
            <dd>{{ mail.from_address || '未配置' }} · {{ sourceLabel(mail.from_source) }}</dd>
          </div>
        </dl>
        <p class="muted">SMTP 主机、端口、账号、密码在 <code>{{ runtime?.paths?.env || '/www/wwwroot/nxm.zlck888.com/shared/.env' }}</code> 配置。</p>
      </el-card>

      <el-card shadow="never" class="settings-card">
        <template #header>安全说明</template>
        <p>敏感配置仅显示脱敏值；留空保存敏感项时保留原值。生产环境修改 .env 后需要重新刷新 Laravel 配置缓存。</p>
        <el-tag type="info">APP_URL：{{ mail.app_url || '-' }}</el-tag>
      </el-card>
    </div>

    <el-alert title="旧 public.homepage_content 仅作为兼容兜底，不再作为主要编辑入口。" type="info" show-icon :closable="false" />

    <el-card shadow="never">
      <template #header>业务配置</template>
      <el-table :data="visibleSettings" border v-loading="loading">
        <el-table-column prop="group" label="分组" width="120" />
        <el-table-column prop="key" label="配置键" width="220" />
        <el-table-column label="配置值" min-width="220">
          <template #default="{ row }">
            <span class="settings-value">{{ row.value || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="description" label="说明" min-width="280" />
        <el-table-column prop="is_secret" label="敏感" width="100">
          <template #default="{ row }"><el-tag :type="row.is_secret ? 'danger' : 'info'">{{ row.is_secret ? '是' : '否' }}</el-tag></template>
        </el-table-column>
        <el-table-column label="操作" width="88" align="center">
          <template #default="{ row }">
            <el-tooltip content="编辑配置" placement="top">
              <el-button :icon="Edit" circle size="small" @click="openEditor(row)" />
            </el-tooltip>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="editorVisible" title="编辑系统配置" width="520px">
      <el-form :model="form" label-position="top">
        <el-form-item label="配置键">
          <el-input v-model="form.key" disabled />
        </el-form-item>
        <el-form-item label="配置值">
          <el-input v-if="form.is_secret" v-model="form.value" type="password" show-password />
          <el-input v-else v-model="form.value" type="textarea" :rows="4" />
          <div v-if="form.is_secret" class="form-tip">留空保存将保留原敏感值。</div>
        </el-form-item>
        <el-form-item label="说明">
          <el-input v-model="form.description" type="textarea" :rows="3" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="editorVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="saveSetting">保存</el-button>
      </template>
    </el-dialog>
  </section>
</template>

<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { Edit, Refresh } from '@element-plus/icons-vue'
import { useRouter } from 'vue-router'
import { api } from '../api.js'

const router = useRouter()
const loading = ref(false)
const runtimeLoading = ref(false)
const saving = ref(false)
const settings = ref([])
const runtime = ref(null)
const editorVisible = ref(false)
const form = reactive({ id: null, key: '', value: '', description: '', is_secret: false })
const visibleSettings = computed(() => settings.value.filter((item) => item.key !== 'public.homepage_content'))
const mail = computed(() => runtime.value?.mail || {})

async function loadSettings() {
  loading.value = true
  try {
    settings.value = await api('/settings')
  } finally {
    loading.value = false
  }
}

async function loadRuntime() {
  runtimeLoading.value = true
  try {
    runtime.value = await api('/settings/runtime')
  } catch {
    runtime.value = null
  } finally {
    runtimeLoading.value = false
  }
}

async function loadAll() {
  await Promise.all([loadSettings(), loadRuntime()])
}

function sourceLabel(source) {
  if (source === 'system_setting') return '系统配置覆盖'
  if (source === 'env') return '.env'
  return '未识别'
}

function openEditor(row) {
  Object.assign(form, {
    id: row.id,
    key: row.key,
    value: row.is_secret ? '' : row.value || '',
    description: row.description || '',
    is_secret: Boolean(row.is_secret)
  })
  editorVisible.value = true
}

async function saveSetting() {
  saving.value = true
  try {
    await api(`/settings/${form.id}`, {
      method: 'PUT',
      body: JSON.stringify({ value: form.value, description: form.description })
    })
    ElMessage.success('配置已保存')
    editorVisible.value = false
    await loadSettings()
  } finally {
    saving.value = false
  }
}

onMounted(loadAll)
</script>
