<template>
  <main class="public-home">
    <header class="public-nav">
      <strong>阿拉善盟科技计划项目管理信息系统</strong>
      <nav>
        <a href="#notices">通知公告</a>
        <a href="#services">服务事项</a>
        <a href="#downloads">资料下载</a>
        <RouterLink to="/login">登录</RouterLink>
      </nav>
    </header>

    <section class="public-hero">
      <div class="hero-copy">
        <p class="eyebrow">科技计划项目申报服务</p>
        <h1>项目申报、审核、评审与验收一体化办理</h1>
        <p>面向申报单位、归口管理单位、专家和科技管理部门，提供在线申报、材料提交、分级审核、专家评审、验收管理和资料查询服务。</p>
        <div class="public-actions">
          <RouterLink class="primary-link" to="/login">进入系统</RouterLink>
          <a class="secondary-link" href="#notices">查看通知</a>
        </div>
      </div>

      <div class="hero-panel" aria-label="平台服务状态">
        <span>当前服务</span>
        <strong>2025 年科技计划项目申报</strong>
        <div>
          <small>在线申报</small>
          <b>开放</b>
        </div>
        <div>
          <small>历史数据</small>
          <b>逐步迁移</b>
        </div>
      </div>
    </section>

    <section id="notices" class="public-section feature-strip">
      <article v-for="item in highlights" :key="item.label">
        <span>{{ item.label }}</span>
        <strong>{{ item.value }}</strong>
        <p>{{ item.description }}</p>
      </article>
    </section>

    <section class="public-section public-two-column">
      <div class="portal-card">
        <div class="portal-card-title">
          <strong>通知公告</strong>
          <RouterLink to="/login">更多</RouterLink>
        </div>
        <ul class="portal-list">
          <li v-for="item in notices" :key="item.title">
            <button type="button" @click="selectedNotice = item">{{ item.title }}</button>
            <span>{{ item.date }}</span>
          </li>
        </ul>
      </div>

      <aside class="notice-detail">
        <span>公告详情</span>
        <strong>{{ selectedNotice.title }}</strong>
        <p>{{ selectedNotice.summary }}</p>
        <RouterLink class="primary-link" to="/login">登录办理</RouterLink>
      </aside>
    </section>

    <section id="services" class="public-section">
      <div class="section-heading">
        <p class="eyebrow">Online Services</p>
        <h2>服务事项</h2>
      </div>
      <div class="service-grid">
        <article v-for="service in services" :key="service.title">
          <span>{{ service.code }}</span>
          <strong>{{ service.title }}</strong>
          <p>{{ service.description }}</p>
        </article>
      </div>
    </section>

    <section id="downloads" class="public-section public-two-column public-band">
      <div class="portal-card">
        <div class="portal-card-title">
          <strong>资料下载</strong>
          <RouterLink to="/login">登录获取</RouterLink>
        </div>
        <ul class="portal-list">
          <li v-for="item in downloads" :key="item.title">
            <button type="button" @click="selectedDownload = item">{{ item.title }}</button>
            <span>{{ item.date }}</span>
          </li>
        </ul>
      </div>

      <aside class="notice-detail">
        <span>资料说明</span>
        <strong>{{ selectedDownload.title }}</strong>
        <p>{{ selectedDownload.summary }}</p>
        <RouterLink class="secondary-link" to="/login">进入系统下载</RouterLink>
      </aside>
    </section>

    <footer class="public-footer">阿拉善盟科技计划项目管理信息系统 版权所有</footer>
  </main>
</template>

<script setup>
import { ref } from 'vue'

const highlights = [
  { label: '申报服务', value: '在线受理', description: '企业和单位可在线创建项目、保存草稿、提交材料。' },
  { label: '审核流程', value: '分级办理', description: '归口、部门、专家和管理员按权限流转处理。' },
  { label: '历史查询', value: '逐步迁移', description: '旧系统历史项目将按批次迁移并开放查询。' }
]

const notices = [
  {
    title: '阿拉善盟科学技术局关于发布2025年阿拉善盟科技计划项目申报指南的通知',
    date: '2025-04-08',
    summary: '2025 年阿拉善盟科技计划项目申报指南已发布，请申报单位按指南要求准备项目材料并通过新系统提交。'
  },
  {
    title: '关于发布2024年阿拉善盟第一批科技计划项目申报指南的通知',
    date: '2024-08-30',
    summary: '2024 年第一批科技计划项目申报工作已启动，项目类别、申报条件和材料清单以通知要求为准。'
  },
  {
    title: '关于发布2022年阿拉善盟应用技术研究与开发项目申报指南的通知',
    date: '2022-03-11',
    summary: '应用技术研究与开发项目申报材料请按指南规范填写，附件材料应完整、真实、可核验。'
  },
  {
    title: '关于发布2021年内蒙古自治区第一批技术攻关类“揭榜挂帅”项目榜单的公告',
    date: '2021-09-01',
    summary: '技术攻关类项目榜单已发布，符合条件的单位可按榜单方向组织申报。'
  }
]

const downloads = [
  {
    title: '【2023】阿拉善盟科技计划项目申报书',
    date: '2023-03-20',
    summary: '项目申报书模板用于填写项目基本信息、建设内容、技术路线、预算和预期成果。'
  },
  {
    title: '【2023】承诺书（企业提供）',
    date: '2023-03-20',
    summary: '企业申报单位需按要求提交承诺书，并对材料真实性和合规性负责。'
  },
  {
    title: '【2023】科研诚信承诺书',
    date: '2023-03-20',
    summary: '科研诚信承诺书用于申报主体承诺遵守科研诚信和项目管理要求。'
  },
  {
    title: '申报单位填报流程',
    date: '2022-03-08',
    summary: '说明申报单位从账号登录、单位资料维护、项目填报到附件提交的操作流程。'
  }
]

const services = [
  { code: '01', title: '项目申报', description: '支持草稿、提交、撤回、退回修改和附件上传。' },
  { code: '02', title: '单位管理', description: '维护企业和单位基础资料，支撑项目归属和审核。' },
  { code: '03', title: '专家评审', description: '专家按任务查看项目材料，填写意见和评分。' },
  { code: '04', title: '验收延期', description: '项目通过后支持验收流转、延期申请和关闭归档。' }
]

const selectedNotice = ref(notices[0])
const selectedDownload = ref(downloads[0])
</script>
