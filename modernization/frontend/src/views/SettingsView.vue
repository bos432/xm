<template>
  <section class="page-stack">
    <el-alert title="敏感配置只显示脱敏值，正式环境应通过 .env 或密钥管理系统注入。" type="warning" show-icon :closable="false" />
    <el-table :data="settings" border v-loading="loading">
      <el-table-column prop="group" label="分组" width="120" />
      <el-table-column prop="key" label="配置键" width="220" />
      <el-table-column prop="value" label="配置值" min-width="180" />
      <el-table-column prop="description" label="说明" min-width="240" />
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
import { onMounted, reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { Edit } from '@element-plus/icons-vue'
import { api } from '../api.js'

const loading = ref(false)
const saving = ref(false)
const settings = ref([])
const editorVisible = ref(false)
const form = reactive({ id: null, key: '', value: '', description: '', is_secret: false })

async function loadSettings() {
  loading.value = true
  try {
    settings.value = await api('/settings')
  } finally {
    loading.value = false
  }
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

onMounted(loadSettings)
</script>
