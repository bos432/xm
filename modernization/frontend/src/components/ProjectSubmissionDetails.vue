<template>
  <div class="submission-details">
    <section>
      <h3>申报信息</h3>
      <dl class="submission-fields">
        <template v-for="field in basicFields" :key="field.key">
          <dt>{{ field.label }}</dt><dd>{{ text(metadata[field.key]) }}</dd>
        </template>
      </dl>
    </section>
    <section v-for="field in contentFields" :key="field.key">
      <h3>{{ field.label }}</h3>
      <div class="rich-content detail-rich-content" v-html="metadata[field.key] || '-'" />
    </section>
    <section>
      <h3>负责人 / 联系人</h3>
      <dl v-for="person in people" :key="person.key" class="submission-fields">
        <template v-for="field in personFields" :key="field.key">
          <dt>{{ person.label }}{{ field.label }}</dt><dd>{{ text(person.value[field.key]) }}</dd>
        </template>
      </dl>
    </section>
    <section v-for="table in tables" :key="table.key">
      <h3>{{ table.label }}</h3>
      <div v-if="table.rows.length" class="submission-table-scroll" tabindex="0" :aria-label="table.label">
        <table>
          <thead><tr><th scope="col">序号</th><th v-for="column in table.columns" :key="column.key" scope="col">{{ column.label }}</th></tr></thead>
          <tbody>
            <tr v-for="(row, index) in table.rows" :key="index">
              <td>{{ index + 1 }}</td>
              <td v-for="column in table.columns" :key="column.key">{{ column.boolean ? (row[column.key] ? '是' : '否') : text(row[column.key]) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p v-else>{{ table.empty }}</p>
    </section>
    <section>
      <h3>盖章承诺</h3>
      <dl class="submission-fields">
        <dt>法定代表人</dt><dd>{{ text(seal.legal_representative) }}</dd>
        <dt>盖章日期</dt><dd>{{ text(seal.seal_date) }}</dd>
      </dl>
      <h4>申报承诺</h4><div class="rich-content detail-rich-content" v-html="seal.commitment || '-'" />
      <h4>备注</h4><div class="rich-content detail-rich-content" v-html="seal.remark || '-'" />
    </section>
  </div>
</template>

<script>
const record = (value) => value && typeof value === 'object' && !Array.isArray(value) ? value : {}
const columns = (fields) => fields.map(([key, label, boolean]) => ({ key, label, boolean }))

export default {
  props: { project: { type: Object, required: true } },
  computed: {
    metadata() { return record(this.project?.metadata) },
    seal() { return record(this.metadata.seal) },
    basicFields() {
      return columns([['guide_code', '指南编号'], ['start_date', '开始日期'], ['end_date', '结束日期'], ['cooperation_units', '合作单位']])
    },
    contentFields() {
      return columns([['overview', '国内外研究进展与产业发展现状'], ['objectives', '研究目标与主要内容'], ['innovation', '创新点与预期成果']])
    },
    people() {
      return ['leader', 'contact'].map((key) => ({ key, label: key === 'leader' ? '负责人' : '联系人', value: record(this.metadata[key]) }))
    },
    personFields() {
      return columns([['name', '姓名'], ['mobile', '手机'], ['professional_title', '职称'], ['work_unit', '单位'], ['email', '邮箱'], ['phone', '电话']])
    },
    tables() {
      return [
        { key: 'members', label: '项目参加成员', empty: '暂无成员', columns: columns([['name', '姓名'], ['gender', '性别'], ['age', '年龄'], ['professional_title', '职称'], ['education', '学历/学位'], ['organization', '所在单位'], ['role', '角色'], ['task', '分工任务'], ['is_leader', '负责人', true]]) },
        { key: 'budget_items', label: '经费预算（万元）', empty: '暂无预算明细', columns: columns([['name', '名称'], ['expense_type', '费用类型'], ['total', '合计（万元）'], ['special_fund', '专项经费（万元）'], ['self_fund', '自筹经费（万元）'], ['remark', '备注']]) },
        { key: 'equipment_items', label: '设备材料', empty: '暂无设备材料', columns: columns([['name', '物资名称'], ['spec', '型号规格'], ['unit_price', '单价（元）'], ['quantity', '数量'], ['amount', '金额（万元）'], ['purpose', '用途']]) }
      ].map((table) => ({ ...table, rows: Array.isArray(this.metadata[table.key]) ? this.metadata[table.key].map(record) : [] }))
    }
  },
  methods: {
    text(value) { return ['string', 'number'].includes(typeof value) && value !== '' ? value : '-' }
  }
}
</script>

<style scoped>
.submission-details { min-width: 0; }
section { margin-top: 20px; }
h3 { font-size: 15px; margin: 0 0 12px; }
h4 { font-size: 14px; margin: 12px 0 8px; }
.submission-fields { display: grid; grid-template-columns: minmax(90px, 130px) minmax(0, 1fr); margin: 0; }
dt, dd { padding: 8px 12px; border-bottom: 1px solid var(--el-border-color-lighter); overflow-wrap: anywhere; }
dt { background: var(--el-fill-color-light); }
dd { margin: 0; }
.submission-table-scroll { overflow-x: auto; max-width: 100%; }
table { width: 100%; border-collapse: collapse; font-size: 13px; }
th, td { min-width: 80px; max-width: 300px; padding: 9px; text-align: left; border: 1px solid var(--el-border-color-lighter); overflow-wrap: anywhere; }
th { background: var(--el-fill-color-light); }
.detail-rich-content { overflow-wrap: anywhere; }
.detail-rich-content :deep(img) { max-width: 100%; height: auto; }
</style>
