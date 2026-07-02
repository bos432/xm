<template>
  <section class="page-stack">
    <div class="toolbar">
      <div>
        <h2>首页管理</h2>
        <span class="muted">维护前台首页导航、横幅、通知、下载和服务事项</span>
      </div>
      <el-button :icon="Refresh" :loading="loading" @click="loadContent">刷新</el-button>
    </div>

    <el-card shadow="never">
      <template #header><strong>基础区域</strong></template>
      <el-tabs v-model="activeSection" @tab-change="handleSectionTabChange">
        <el-tab-pane label="品牌素材" name="brand">
          <el-alert
            v-if="!canManageHomeAssets"
            title="只有超级管理员可以上传或删除首页 logo、banner 和站点图标。"
            type="info"
            show-icon
            :closable="false"
          />
          <div class="asset-status-panel">
            <div v-for="item in assetStatusItems" :key="item.key" class="asset-status-item">
              <span>{{ item.label }}</span>
              <el-tag :type="item.uploaded ? 'success' : 'warning'">{{ item.uploaded ? '已上传' : '未上传' }}</el-tag>
            </div>
            <div class="asset-status-item wide">
              <span>公开首页当前批次</span>
              <el-tag :type="currentBatchTagType">{{ currentBatchLabel }}</el-tag>
            </div>
          </div>
          <div class="asset-grid">
            <div class="asset-box">
              <strong>首页 Logo</strong>
              <img v-if="assetFor('nav', 'logo')" :src="`/api/public/homepage/assets/nav/logo?t=${assetVersion}`" alt="首页 Logo" />
              <span v-else class="muted">未上传，前台显示文字徽标</span>
              <div v-if="assetFor('nav', 'logo')" class="asset-meta">
                <span v-for="line in assetMetaLines('nav', 'logo')" :key="line">{{ line }}</span>
              </div>
              <el-input v-model="assetForms.logo_alt" placeholder="Logo 替代文本" :disabled="!canManageHomeAssets" />
              <div class="table-action-row">
                <el-upload :show-file-list="false" :disabled="!canManageHomeAssets" :http-request="(options) => uploadAsset('nav', 'logo', options)">
                  <el-button :icon="Upload" :disabled="!canManageHomeAssets">替换 Logo</el-button>
                </el-upload>
                <el-button :icon="Delete" type="danger" :disabled="!assetFor('nav', 'logo') || !canManageHomeAssets" @click="deleteAsset('nav', 'logo')">删除</el-button>
              </div>
            </div>
            <div class="asset-box">
              <strong>站点图标 Favicon</strong>
              <img v-if="assetFor('nav', 'favicon')" class="favicon-preview" :src="`/api/public/homepage/assets/nav/favicon?t=${assetVersion}`" alt="站点图标" />
              <span v-else class="muted">未上传，浏览器使用默认图标</span>
              <div v-if="assetFor('nav', 'favicon')" class="asset-meta">
                <span v-for="line in assetMetaLines('nav', 'favicon')" :key="line">{{ line }}</span>
              </div>
              <span class="muted">建议上传 ico、png 或 svg，大小不超过 512KB。</span>
              <div class="table-action-row">
                <el-upload :show-file-list="false" :disabled="!canManageHomeAssets" :http-request="(options) => uploadAsset('nav', 'favicon', options)">
                  <el-button :icon="Upload" :disabled="!canManageHomeAssets">替换图标</el-button>
                </el-upload>
                <el-button :icon="Delete" type="danger" :disabled="!assetFor('nav', 'favicon') || !canManageHomeAssets" @click="deleteAsset('nav', 'favicon')">删除</el-button>
              </div>
            </div>
            <div class="asset-box">
              <strong>首页 Banner</strong>
              <img v-if="assetFor('hero', 'banner')" :src="`/api/public/homepage/assets/hero/banner?t=${assetVersion}`" alt="首页 Banner" />
              <span v-else class="muted">未上传，前台显示蓝色政务背景</span>
              <div v-if="assetFor('hero', 'banner')" class="asset-meta">
                <span v-for="line in assetMetaLines('hero', 'banner')" :key="line">{{ line }}</span>
              </div>
              <el-input v-model="assetForms.banner_alt" placeholder="Banner 替代文本" :disabled="!canManageHomeAssets" />
              <div class="table-action-row">
                <el-upload :show-file-list="false" :disabled="!canManageHomeAssets" :http-request="(options) => uploadAsset('hero', 'banner', options)">
                  <el-button :icon="Upload" :disabled="!canManageHomeAssets">替换 Banner</el-button>
                </el-upload>
                <el-button :icon="Delete" type="danger" :disabled="!assetFor('hero', 'banner') || !canManageHomeAssets" @click="deleteAsset('hero', 'banner')">删除</el-button>
              </div>
            </div>
          </div>
        </el-tab-pane>
        <el-tab-pane label="导航" name="nav">
          <el-form :model="sectionForms.nav" label-position="top" class="home-manager-grid">
            <el-form-item label="系统名称">
              <el-input v-model="sectionForms.nav.title" />
            </el-form-item>
            <el-form-item label="启用">
              <el-switch v-model="sectionForms.nav.is_active" />
            </el-form-item>
          </el-form>
          <el-button type="primary" :loading="savingSection" @click="saveSection('nav')">保存导航</el-button>
        </el-tab-pane>
        <el-tab-pane label="横幅" name="hero">
          <el-form :model="sectionForms.hero" label-position="top" class="home-manager-grid">
            <el-form-item label="眉标">
              <el-input v-model="sectionForms.hero.eyebrow" />
            </el-form-item>
            <el-form-item label="标题">
              <el-input v-model="sectionForms.hero.title" />
            </el-form-item>
            <el-form-item label="说明" class="wide-field">
              <el-input v-model="sectionForms.hero.body" type="textarea" :rows="3" />
            </el-form-item>
            <el-form-item label="主按钮文字">
              <el-input v-model="sectionForms.hero.primary_label" />
            </el-form-item>
            <el-form-item label="主按钮链接">
              <el-input v-model="sectionForms.hero.primary_href" />
            </el-form-item>
            <el-form-item label="次按钮文字">
              <el-input v-model="sectionForms.hero.secondary_label" />
            </el-form-item>
            <el-form-item label="次按钮链接">
              <el-input v-model="sectionForms.hero.secondary_href" />
            </el-form-item>
            <el-form-item label="状态标题">
              <el-input v-model="sectionForms.hero.status_title" />
            </el-form-item>
            <el-form-item label="启用">
              <el-switch v-model="sectionForms.hero.is_active" />
            </el-form-item>
          </el-form>
          <el-button type="primary" :loading="savingSection" @click="saveSection('hero')">保存横幅</el-button>
        </el-tab-pane>
        <el-tab-pane label="页脚" name="footer">
          <el-form :model="sectionForms.footer" label-position="top">
            <el-form-item label="页脚文字">
              <el-input v-model="sectionForms.footer.body" type="textarea" :rows="3" />
            </el-form-item>
            <el-form-item label="启用">
              <el-switch v-model="sectionForms.footer.is_active" />
            </el-form-item>
          </el-form>
          <el-button type="primary" :loading="savingSection" @click="saveSection('footer')">保存页脚</el-button>
        </el-tab-pane>
      </el-tabs>
    </el-card>

    <el-card shadow="never">
      <template #header>
        <div class="toolbar">
          <strong>列表内容</strong>
          <el-button type="primary" :icon="Plus" @click="openCreate(activeItemSection)">新增</el-button>
        </div>
      </template>
      <el-tabs v-model="activeItemSection" @tab-change="handleItemTabChange">
        <el-tab-pane v-for="tab in itemTabs" :key="tab.name" :label="tab.label" :name="tab.name">
          <el-table :data="itemsFor(tab.name)" border v-loading="loading">
            <el-table-column prop="sort_order" label="排序" width="80" />
            <el-table-column label="状态" width="92">
              <template #default="{ row }">
                <el-tag :type="row.is_active ? 'success' : 'info'">{{ row.is_active ? '启用' : '停用' }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column label="标题/标签" min-width="220">
              <template #default="{ row }">
                <strong>{{ row.title || row.label || row.code }}</strong>
                <div class="muted">{{ row.href || row.value || row.published_at || row.file_original_name }}</div>
              </template>
            </el-table-column>
            <el-table-column prop="summary" label="说明" min-width="260" show-overflow-tooltip />
            <el-table-column v-if="tab.name === 'download'" label="附件" min-width="180">
              <template #default="{ row }">
                <span v-if="row.file_original_name">{{ row.file_original_name }}</span>
                <span v-else class="muted">未上传</span>
              </template>
            </el-table-column>
            <el-table-column label="操作" width="230" fixed="right">
              <template #default="{ row }">
                <div class="table-action-row">
                  <el-button size="small" :icon="Edit" @click="openEdit(row)">编辑</el-button>
                  <el-upload
                    v-if="tab.name === 'download'"
                    :show-file-list="false"
                    :http-request="(options) => uploadFile(row, options)"
                  >
                    <el-button size="small" :icon="Upload">上传</el-button>
                  </el-upload>
                  <el-button size="small" type="danger" :icon="Delete" @click="deleteItem(row)">删除</el-button>
                </div>
              </template>
            </el-table-column>
          </el-table>
        </el-tab-pane>
      </el-tabs>
    </el-card>

    <el-dialog v-model="itemEditorVisible" :title="itemForm.id ? '编辑首页内容' : '新增首页内容'" width="880px">
      <el-form :model="itemForm" label-position="top" class="home-manager-grid">
        <el-form-item label="类型">
          <el-select v-model="itemForm.section" disabled>
            <el-option v-for="tab in itemTabs" :key="tab.name" :label="tab.label" :value="tab.name" />
          </el-select>
        </el-form-item>
        <el-form-item label="排序">
          <el-input-number v-model="itemForm.sort_order" :min="0" :max="999999" />
        </el-form-item>
        <el-form-item label="启用">
          <el-switch v-model="itemForm.is_active" />
        </el-form-item>

        <template v-if="itemForm.section === 'nav_link'">
          <el-form-item label="标签">
            <el-input v-model="itemForm.label" />
          </el-form-item>
          <el-form-item label="链接">
            <el-input v-model="itemForm.href" />
          </el-form-item>
        </template>

        <template v-else-if="itemForm.section === 'hero_status' || itemForm.section === 'highlight'">
          <el-form-item label="标签">
            <el-input v-model="itemForm.label" />
          </el-form-item>
          <el-form-item label="数值">
            <el-input v-model="itemForm.value" />
          </el-form-item>
          <el-form-item v-if="itemForm.section === 'highlight'" label="说明" class="wide-field">
            <el-input v-model="itemForm.summary" type="textarea" :rows="3" />
          </el-form-item>
        </template>

        <template v-else>
          <el-form-item v-if="itemForm.section === 'service'" label="编号">
            <el-input v-model="itemForm.code" />
          </el-form-item>
          <el-form-item label="标题">
            <el-input v-model="itemForm.title" />
          </el-form-item>
          <el-form-item v-if="itemForm.section === 'notice' || itemForm.section === 'download'" label="发布日期">
            <el-date-picker v-model="itemForm.published_at" value-format="YYYY-MM-DD" type="date" />
          </el-form-item>
          <el-form-item label="摘要/说明" class="wide-field">
            <el-input v-model="itemForm.summary" type="textarea" :rows="3" />
          </el-form-item>
          <el-form-item v-if="itemForm.section === 'notice'" label="详情" class="wide-field">
            <RichTextEditor v-model="itemForm.body" />
          </el-form-item>
          <el-form-item v-if="itemForm.section === 'notice'" label="外部链接">
            <el-input v-model="itemForm.href" />
          </el-form-item>
        </template>
      </el-form>
      <template #footer>
        <el-button @click="itemEditorVisible = false">取消</el-button>
        <el-button type="primary" :loading="savingItem" @click="saveItem">保存</el-button>
      </template>
    </el-dialog>
  </section>
</template>

<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Delete, Edit, Plus, Refresh, Upload } from '@element-plus/icons-vue'
import { useRoute, useRouter } from 'vue-router'
import { api } from '../api.js'
import RichTextEditor from '../components/RichTextEditor.vue'
import { useSessionStore } from '../store.js'

const route = useRoute()
const router = useRouter()
const session = useSessionStore()
const loading = ref(false)
const savingSection = ref(false)
const savingItem = ref(false)
const activeSection = ref('nav')
const activeItemSection = ref('notice')
const sections = ref([])
const items = ref([])
const publicHome = ref(null)
const itemEditorVisible = ref(false)
const assetVersion = ref(Date.now())
const assetForms = reactive({ logo_alt: '', banner_alt: '' })
const canManageHomeAssets = computed(() => session.can('manage_home_assets') || session.can('public_home.manage_assets'))
const assetStatusItems = computed(() => [
  { key: 'logo', label: 'Logo', uploaded: Boolean(assetFor('nav', 'logo')) },
  { key: 'favicon', label: 'Favicon', uploaded: Boolean(assetFor('nav', 'favicon')) },
  { key: 'banner', label: 'Banner', uploaded: Boolean(assetFor('hero', 'banner')) }
])
const currentPublicBatch = computed(() => publicHome.value?.current_batch || null)
const currentBatchIsE2e = computed(() => isLikelyE2eBatch(currentPublicBatch.value))
const currentBatchLabel = computed(() => {
  if (!currentPublicBatch.value) return '未展示'
  if (currentBatchIsE2e.value) return `测试批次：${currentPublicBatch.value.name || currentPublicBatch.value.code}`

  return currentPublicBatch.value.name || currentPublicBatch.value.code || '已配置'
})
const currentBatchTagType = computed(() => {
  if (!currentPublicBatch.value) return 'warning'

  return currentBatchIsE2e.value ? 'danger' : 'success'
})

const itemTabs = [
  { name: 'notice', label: '通知公告' },
  { name: 'download', label: '资料下载' },
  { name: 'service', label: '服务事项' },
  { name: 'nav_link', label: '导航链接' },
  { name: 'hero_status', label: '横幅状态' },
  { name: 'highlight', label: '亮点数据' }
]
const sectionKeys = ['brand', 'nav', 'hero', 'footer']
const itemKeys = itemTabs.map((tab) => tab.name)

const sectionForms = reactive({
  nav: { title: '', is_active: true },
  hero: {
    title: '',
    eyebrow: '',
    body: '',
    primary_label: '',
    primary_href: '',
    secondary_label: '',
    secondary_href: '',
    status_title: '',
    is_active: true
  },
  footer: { body: '', is_active: true }
})

const itemForm = reactive(emptyItem('notice'))

function emptyItem(section) {
  return {
    id: null,
    section,
    title: '',
    label: '',
    value: '',
    code: '',
    summary: '',
    body: '',
    href: '',
    published_at: '',
    sort_order: 10,
    is_active: true,
    metadata: {}
  }
}

function itemsFor(section) {
  return items.value.filter((item) => item.section === section)
}

function applyRouteTabs() {
  const section = typeof route.query.section === 'string' ? route.query.section : ''
  const items = typeof route.query.items === 'string' ? route.query.items : ''

  if (sectionKeys.includes(section)) activeSection.value = section
  if (itemKeys.includes(items)) activeItemSection.value = items
}

function handleSectionTabChange(name) {
  router.replace({ path: route.path, query: { ...route.query, section: name } })
}

function handleItemTabChange(name) {
  router.replace({ path: route.path, query: { ...route.query, items: name } })
}

async function loadContent() {
  loading.value = true
  try {
    const [result, homepage] = await Promise.all([
      api('/public-home'),
      api('/public/homepage')
    ])
    sections.value = result.sections || []
    items.value = result.items || []
    publicHome.value = homepage || null
    fillSectionForms()
  } finally {
    loading.value = false
  }
}

function sectionByKey(key) {
  return sections.value.find((section) => section.key === key) || {}
}

function fillSectionForms() {
  const nav = sectionByKey('nav')
  Object.assign(sectionForms.nav, {
    title: nav.title || '',
    is_active: nav.is_active !== false
  })

  const hero = sectionByKey('hero')
  const metadata = hero.metadata || {}
  Object.assign(sectionForms.hero, {
    title: hero.title || '',
    eyebrow: hero.eyebrow || '',
    body: hero.body || '',
    primary_label: metadata.primary_action?.label || '',
    primary_href: metadata.primary_action?.href || '',
    secondary_label: metadata.secondary_action?.label || '',
    secondary_href: metadata.secondary_action?.href || '',
    status_title: metadata.status_title || '',
    is_active: hero.is_active !== false
  })

  const footer = sectionByKey('footer')
  Object.assign(sectionForms.footer, {
    body: footer.body || '',
    is_active: footer.is_active !== false
  })

  assetForms.logo_alt = sectionByKey('nav').metadata?.assets?.logo?.alt || ''
  assetForms.banner_alt = sectionByKey('hero').metadata?.assets?.banner?.alt || ''
}

function assetFor(sectionKey, type) {
  return sectionByKey(sectionKey).metadata?.assets?.[type] || null
}

function assetMetaLines(sectionKey, type) {
  const asset = assetFor(sectionKey, type)
  if (!asset) return []

  return [
    asset.original_name ? `文件：${asset.original_name}` : '',
    asset.extension ? `类型：${String(asset.extension).toUpperCase()}` : '',
    asset.size_bytes ? `大小：${formatBytes(asset.size_bytes)}` : '',
    asset.uploaded_at ? `上传时间：${asset.uploaded_at}` : '',
    asset.uploaded_by_name ? `上传人：${asset.uploaded_by_name}` : (asset.uploaded_by ? `上传人ID：${asset.uploaded_by}` : '')
  ].filter(Boolean)
}

function formatBytes(value) {
  const bytes = Number(value || 0)
  if (bytes >= 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(2)} MB`
  if (bytes >= 1024) return `${(bytes / 1024).toFixed(1)} KB`
  return `${bytes} B`
}

function isLikelyE2eBatch(batch) {
  if (!batch) return false
  const value = `${batch.name || ''} ${batch.code || ''}`.toUpperCase()

  return value.includes('E2E-')
}

async function saveSection(key) {
  savingSection.value = true
  try {
    let body
    if (key === 'hero') {
      body = {
        title: sectionForms.hero.title,
        eyebrow: sectionForms.hero.eyebrow,
        body: sectionForms.hero.body,
        is_active: sectionForms.hero.is_active,
        metadata: {
          primary_action: { label: sectionForms.hero.primary_label, href: sectionForms.hero.primary_href },
          secondary_action: { label: sectionForms.hero.secondary_label, href: sectionForms.hero.secondary_href },
          status_title: sectionForms.hero.status_title
        }
      }
    } else {
      body = { ...sectionForms[key], metadata: {} }
    }

    await api(`/public-home/sections/${key}`, { method: 'PUT', body: JSON.stringify(body) })
    ElMessage.success('基础区域已保存')
    await loadContent()
  } finally {
    savingSection.value = false
  }
}

function openCreate(section) {
  Object.assign(itemForm, emptyItem(section))
  const existing = itemsFor(section)
  itemForm.sort_order = existing.length ? Math.max(...existing.map((item) => Number(item.sort_order || 0))) + 10 : 10
  itemEditorVisible.value = true
}

function openEdit(row) {
  Object.assign(itemForm, emptyItem(row.section), {
    ...row,
    published_at: row.published_at ? String(row.published_at).slice(0, 10) : ''
  })
  itemEditorVisible.value = true
}

function itemPayload() {
  return {
    section: itemForm.section,
    title: itemForm.title || null,
    label: itemForm.label || null,
    value: itemForm.value || null,
    code: itemForm.code || null,
    summary: itemForm.summary || null,
    body: itemForm.body || null,
    href: itemForm.href || null,
    published_at: itemForm.published_at || null,
    sort_order: Number(itemForm.sort_order || 0),
    is_active: Boolean(itemForm.is_active),
    metadata: itemForm.metadata || {}
  }
}

async function saveItem() {
  savingItem.value = true
  try {
    const path = itemForm.id ? `/public-home/items/${itemForm.id}` : '/public-home/items'
    const method = itemForm.id ? 'PUT' : 'POST'
    await api(path, { method, body: JSON.stringify(itemPayload()) })
    ElMessage.success('内容已保存')
    itemEditorVisible.value = false
    await loadContent()
  } finally {
    savingItem.value = false
  }
}

async function deleteItem(row) {
  await ElMessageBox.confirm('确认删除这条首页内容吗？', '删除确认', { type: 'warning' })
  await api(`/public-home/items/${row.id}`, { method: 'DELETE' })
  ElMessage.success('内容已删除')
  await loadContent()
}

async function uploadFile(row, options) {
  const data = new FormData()
  data.append('file', options.file)
  try {
    await api(`/public-home/items/${row.id}/file`, { method: 'POST', body: data })
    ElMessage.success('附件已上传')
    options.onSuccess?.()
    await loadContent()
  } catch (error) {
    options.onError?.(error)
    ElMessage.error(error.message || '附件上传失败')
  }
}

async function uploadAsset(sectionKey, type, options) {
  const data = new FormData()
  data.append('type', type)
  data.append('file', options.file)
  data.append('alt', assetAlt(type))
  try {
    await api(`/public-home/sections/${sectionKey}/asset`, { method: 'POST', body: data })
    ElMessage.success(type === 'favicon' ? '站点图标已上传，刷新或重新打开标签页后生效' : '品牌素材已上传')
    options.onSuccess?.()
    assetVersion.value = Date.now()
    await loadContent()
  } catch (error) {
    options.onError?.(error)
    ElMessage.error(error.message || '素材上传失败')
  }
}

function assetAlt(type) {
  if (type === 'logo') return assetForms.logo_alt
  if (type === 'banner') return assetForms.banner_alt

  return sectionForms.nav.title || '站点图标'
}

async function deleteAsset(sectionKey, type) {
  await ElMessageBox.confirm('删除后前台将回到兜底样式，确认删除？', '删除素材', { type: 'warning' })
  await api(`/public-home/sections/${sectionKey}/asset/${type}`, { method: 'DELETE' })
  ElMessage.success('品牌素材已删除')
  assetVersion.value = Date.now()
  await loadContent()
}

onMounted(() => {
  applyRouteTabs()
  loadContent()
})

watch(() => [route.query.section, route.query.items], applyRouteTabs)
</script>
