<template>
  <div class="rich-editor">
    <div class="rich-editor-toolbar">
      <el-button-group>
        <el-tooltip content="正文" placement="top">
          <el-button size="small" @click="formatBlock('p')">正文</el-button>
        </el-tooltip>
        <el-tooltip content="二级标题" placement="top">
          <el-button size="small" @click="formatBlock('h2')">H2</el-button>
        </el-tooltip>
        <el-tooltip content="三级标题" placement="top">
          <el-button size="small" @click="formatBlock('h3')">H3</el-button>
        </el-tooltip>
      </el-button-group>
      <el-button-group>
        <el-tooltip content="加粗" placement="top">
          <el-button size="small" @click="runCommand('bold')"><b>B</b></el-button>
        </el-tooltip>
        <el-tooltip content="斜体" placement="top">
          <el-button size="small" @click="runCommand('italic')"><i>I</i></el-button>
        </el-tooltip>
        <el-tooltip content="下划线" placement="top">
          <el-button size="small" @click="runCommand('underline')"><u>U</u></el-button>
        </el-tooltip>
      </el-button-group>
      <el-button-group>
        <el-tooltip content="无序列表" placement="top">
          <el-button size="small" @click="runCommand('insertUnorderedList')">•</el-button>
        </el-tooltip>
        <el-tooltip content="有序列表" placement="top">
          <el-button size="small" @click="runCommand('insertOrderedList')">1.</el-button>
        </el-tooltip>
        <el-tooltip content="引用" placement="top">
          <el-button size="small" @click="formatBlock('blockquote')">“”</el-button>
        </el-tooltip>
      </el-button-group>
      <el-button-group>
        <el-tooltip content="插入链接" placement="top">
          <el-button size="small" @click="insertLink">链接</el-button>
        </el-tooltip>
        <el-tooltip content="上传图片" placement="top">
          <el-button size="small" :loading="uploading" @click="triggerImageUpload">图片</el-button>
        </el-tooltip>
        <el-tooltip content="清除格式" placement="top">
          <el-button size="small" @click="runCommand('removeFormat')">清除</el-button>
        </el-tooltip>
      </el-button-group>
      <input ref="fileInput" class="hidden-file-input" type="file" accept="image/jpeg,image/png,image/webp,image/gif" @change="uploadImage" />
    </div>
    <div
      ref="editor"
      class="rich-editor-body rich-content"
      contenteditable="true"
      :data-placeholder="placeholder"
      :style="{ minHeight }"
      @focus="focused = true"
      @blur="handleBlur"
      @input="syncFromEditor"
    />
  </div>
</template>

<script setup>
import { nextTick, onMounted, ref, watch } from 'vue'
import { ElMessage } from 'element-plus'
import { api } from '../api.js'

const props = defineProps({
  modelValue: {
    type: String,
    default: ''
  },
  placeholder: {
    type: String,
    default: '请输入内容'
  },
  minHeight: {
    type: String,
    default: '180px'
  },
  uploadUrl: {
    type: String,
    default: '/rich-text-images'
  }
})
const emit = defineEmits(['update:modelValue'])

const editor = ref(null)
const fileInput = ref(null)
const focused = ref(false)
const uploading = ref(false)

watch(() => props.modelValue, (value) => {
  if (!editor.value || focused.value) return
  setEditorHtml(value || '')
})

onMounted(() => {
  setEditorHtml(props.modelValue || '')
})

function setEditorHtml(value) {
  nextTick(() => {
    if (editor.value && editor.value.innerHTML !== value) {
      editor.value.innerHTML = value
    }
  })
}

function syncFromEditor() {
  emit('update:modelValue', editor.value?.innerHTML || '')
}

function handleBlur() {
  focused.value = false
  syncFromEditor()
}

function runCommand(command, value = null) {
  editor.value?.focus()
  document.execCommand(command, false, value)
  syncFromEditor()
}

function formatBlock(tag) {
  runCommand('formatBlock', tag)
}

function insertLink() {
  const href = window.prompt('请输入链接地址')
  if (!href) return
  runCommand('createLink', href)
}

function triggerImageUpload() {
  fileInput.value?.click()
}

async function uploadImage(event) {
  const file = event.target.files?.[0]
  event.target.value = ''
  if (!file) return

  const form = new FormData()
  form.append('file', file)
  uploading.value = true
  try {
    const result = await api(props.uploadUrl, { method: 'POST', body: form })
    const alt = escapeAttribute(result.original_name || file.name || '图片')
    const src = escapeAttribute(result.url)
    editor.value?.focus()
    document.execCommand('insertHTML', false, `<p><img src="${src}" alt="${alt}"></p>`)
    syncFromEditor()
    ElMessage.success('图片已插入')
  } catch (error) {
    ElMessage.error(error.message || '图片上传失败')
  } finally {
    uploading.value = false
  }
}

function escapeAttribute(value) {
  return String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/"/g, '&quot;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
}
</script>
