<template>
  <main class="public-home">
    <header class="public-nav">
      <strong>项目申报系统</strong>
      <nav>
        <a href="#services">申报服务</a>
        <a href="#notices">通知资料</a>
        <RouterLink to="/login">登录</RouterLink>
      </nav>
    </header>

    <section class="public-hero">
      <div>
        <p class="eyebrow">旧新并行测试环境</p>
        <h1>项目申报系统</h1>
        <p>面向企业、区县、部门、专家和管理员的项目申报、审核、验收与延期管理平台。</p>
        <div class="public-actions">
          <RouterLink class="primary-link" to="/login">进入系统</RouterLink>
          <a class="secondary-link" href="#services">查看服务</a>
        </div>
      </div>
      <div class="public-status" aria-label="系统状态">
        <span>新项目申报</span>
        <strong>在线受理</strong>
        <span>历史数据查询</span>
        <strong>逐步迁移</strong>
      </div>
    </section>

    <section id="services" class="public-section">
      <div class="section-heading">
        <p class="eyebrow">Services</p>
        <h2>申报服务</h2>
      </div>
      <div class="public-grid">
        <article>
          <strong>企业申报</strong>
          <p>支持项目草稿、提交、附件、延期申请和站内消息提醒。</p>
        </article>
        <article>
          <strong>分级审核</strong>
          <p>区县、部门、专家、管理员按流程处理审核意见和评分。</p>
        </article>
        <article>
          <strong>验收管理</strong>
          <p>项目通过后进入验收阶段，支持延期审核和验收关闭。</p>
        </article>
      </div>
    </section>

    <section id="notices" class="public-section public-band">
      <div class="section-heading">
        <p class="eyebrow">Notices</p>
        <h2>通知资料</h2>
      </div>
      <div class="notice-list">
        <div>
          <strong>新系统试运行</strong>
          <span>新增项目请进入新系统办理，旧系统保留历史查询。</span>
        </div>
        <div>
          <strong>账号与资料</strong>
          <span>企业账号、单位资料和项目附件请按后台要求维护。</span>
        </div>
        <div>
          <strong>安全提醒</strong>
          <span>首次登录后请及时修改默认密码，妥善保管账号。</span>
        </div>
      </div>
    </section>
  </main>
</template>
