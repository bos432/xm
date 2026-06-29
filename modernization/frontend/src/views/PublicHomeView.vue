<template>
  <main class="public-home">
    <header class="public-nav">
      <strong>阿拉善盟科技计划项目管理信息系统</strong>
      <nav>
        <a href="#home">首页</a>
        <a href="#information">资讯</a>
        <a href="#notices">通知公告</a>
        <a href="#policies">科技政策</a>
        <a href="#downloads">文件下载</a>
        <RouterLink to="/login">登录</RouterLink>
      </nav>
    </header>

    <section id="home" class="public-hero">
      <div>
        <p class="eyebrow">阿拉善盟科技计划项目管理</p>
        <h1>项目申报服务平台</h1>
        <p>面向申报单位、归口管理单位、专家和科技管理部门，提供科技计划项目申报、审核、评审、验收和资料下载服务。</p>
        <div class="public-actions">
          <RouterLink class="primary-link" to="/login">进入新系统</RouterLink>
          <a class="secondary-link" href="http://xm.zlck888.com/" target="_blank" rel="noopener">旧系统查询</a>
        </div>
      </div>
      <div class="public-login-card" aria-label="登录入口">
        <strong>后台登录</strong>
        <RouterLink v-for="entry in loginEntries" :key="entry" to="/login">{{ entry }}</RouterLink>
        <small>旧系统保留历史数据查询，新项目请进入新系统办理。</small>
      </div>
    </section>

    <section id="notices" class="public-section portal-layout">
      <div class="portal-card portal-main-card">
        <div class="portal-card-title">
          <strong>通知公告</strong>
          <a href="http://xm.zlck888.com/index.php?m=Index&a=news" target="_blank" rel="noopener">查看更多</a>
        </div>
        <ul class="portal-list">
          <li v-for="item in notices" :key="item.title">
            <a :href="item.href" target="_blank" rel="noopener">{{ item.title }}</a>
            <span>{{ item.date }}</span>
          </li>
        </ul>
      </div>

      <aside class="portal-card contact-card">
        <div class="portal-card-title">
          <strong>服务咨询</strong>
        </div>
        <p>在线咨询</p>
        <a href="http://wpa.qq.com/msgrd?v=3&uin=513038681&site=qq&menu=yes" target="_blank" rel="noopener">QQ：513038681</a>
        <p>咨询热线</p>
        <strong>13983747433</strong>
      </aside>
    </section>

    <section id="information" class="public-section portal-layout">
      <div class="portal-card portal-main-card">
        <div class="portal-card-title">
          <strong>资讯</strong>
          <a href="http://xm.zlck888.com/index.php?m=Index&a=info" target="_blank" rel="noopener">查看更多</a>
        </div>
        <ul class="portal-list">
          <li v-for="item in information" :key="item.title">
            <a :href="item.href" target="_blank" rel="noopener">{{ item.title }}</a>
            <span>{{ item.date }}</span>
          </li>
        </ul>
      </div>

      <aside id="downloads" class="portal-card download-card">
        <div class="portal-card-title">
          <strong>文件下载</strong>
          <a href="http://xm.zlck888.com/index.php?m=Index&a=file" target="_blank" rel="noopener">更多</a>
        </div>
        <ul class="download-list">
          <li v-for="item in downloads" :key="item.title">
            <a :href="item.href" target="_blank" rel="noopener">{{ item.title }}</a>
            <span>{{ item.date }}</span>
          </li>
        </ul>
      </aside>
    </section>

    <section id="policies" class="public-section public-band">
      <div class="portal-card portal-main-card">
        <div class="portal-card-title">
          <strong>科技政策</strong>
          <a href="http://xm.zlck888.com/index.php?m=Index&a=technology" target="_blank" rel="noopener">查看更多</a>
        </div>
        <ul class="portal-list">
          <li v-for="item in policies" :key="item.title">
            <a :href="item.href" target="_blank" rel="noopener">{{ item.title }}</a>
            <span>{{ item.date }}</span>
          </li>
        </ul>
      </div>

      <footer class="public-footer">阿拉善盟科技计划项目管理信息系统 版权所有</footer>
    </section>
  </main>
</template>

<script setup>
const oldBase = 'http://xm.zlck888.com/'

const loginEntries = [
  '申报单位登录',
  '归口管理单位登录',
  '盟本级管理员登录',
  '专家登录',
  '盟科技局登录'
]

const notices = [
  ['阿拉善盟科学技术局关于发布2025年阿拉善盟科技计划项目申报指南的通知', '2025-04-08', 'index.php?m=Index&a=news_content&id=81'],
  ['关于发布2024年阿拉善盟第一批科技计划项目申报指南的通知', '2024-08-30', 'index.php?m=Index&a=news_content&id=80'],
  ['关于发布2022年阿拉善盟应用技术研究与开发项目申报指南的通知', '2022-03-11', 'index.php?m=Index&a=news_content&id=76'],
  ['关于发布2021年内蒙古自治区第一批技术攻关类“揭榜挂帅”项目榜单的公告', '2021-09-01', 'index.php?m=Index&a=news_content&id=72'],
  ['关于组织开展2021年度自治区级科技企业孵化器和众创空间认定工作的通知', '2021-09-01', 'index.php?m=Index&a=news_content&id=71']
].map(toItem)

const information = [
  ['李克强主持召开国务院常务会议 部署全面推动长江经济带发展的财税支持措施等', '2021-09-01', 'index.php?m=Index&a=info_content&id=69']
].map(toItem)

const downloads = [
  ['【2023】阿拉善盟科技计划项目申报书', '2023-03-20', 'index.php?m=Index&a=get_file&id=79'],
  ['【2023】承诺书（只企业提供）', '2023-03-20', 'index.php?m=Index&a=get_file&id=78'],
  ['【2023】科研诚信承诺书', '2023-03-20', 'index.php?m=Index&a=get_file&id=77'],
  ['评审系统专家材料', '2024-09-10', 'index.php?m=Index&a=get_file&id=75'],
  ['申报单位填报流程', '2022-03-08', 'index.php?m=Index&a=get_file&id=74'],
  ['归口管理单位操作流程', '2022-03-08', 'index.php?m=Index&a=get_file&id=73']
].map(toItem)

const policies = [
  ['关于《阿拉善盟关于促进阿拉善高新技术产业开发区高质量发展的意见》的政策解读', '2021-09-01', 'index.php?m=Index&a=technology_content&id=70']
].map(toItem)

function toItem([title, date, path]) {
  return { title, date, href: `${oldBase}${path}` }
}
</script>
