<template>
  <section class="page-stack">
    <div class="toolbar">
      <el-segmented v-model="status" :options="statusOptions" @change="reloadProjects" />
      <div class="toolbar-actions">
        <el-input v-model="keyword" clearable placeholder="按项目、单位、账号搜索" @keyup.enter="reloadProjects" @clear="reloadProjects" />
        <el-select v-model="category" clearable placeholder="类别" @change="reloadProjects" @clear="reloadProjects">
          <el-option v-for="item in projectCategoryOptions" :key="item.code" :label="dictionaryOptionLabel(item)" :value="dictionaryOptionValue(item)" />
        </el-select>
        <el-select v-model="projectType" clearable placeholder="类型" @change="reloadProjects" @clear="reloadProjects">
          <el-option v-for="item in projectTypeOptions" :key="item.code" :label="dictionaryOptionLabel(item)" :value="dictionaryOptionValue(item)" />
        </el-select>
        <el-select v-model="applicationBatchId" clearable placeholder="申报批次" @change="reloadProjects" @clear="reloadProjects">
          <el-option v-for="batch in openBatches" :key="batch.id" :label="batch.name" :value="batch.id" />
        </el-select>
        <el-select v-if="canFilterE2e" v-model="e2eFilter" clearable placeholder="测试数据" @change="reloadProjects" @clear="reloadProjects">
          <el-option label="只看测试数据" value="1" />
          <el-option label="排除测试数据" value="0" />
        </el-select>
        <el-switch v-if="session.can('manage_acceptance')" v-model="pendingExtensionOnly" active-text="待延期" @change="reloadProjects" />
        <el-tooltip content="查询项目" placement="top">
          <el-button type="primary" :icon="Search" circle @click="reloadProjects" />
        </el-tooltip>
        <el-tooltip content="导出当前筛选项目" placement="top">
          <el-button :icon="Download" @click="exportProjects">导出</el-button>
        </el-tooltip>
        <el-button v-if="canCreate" type="primary" :icon="Plus" @click="openCreate">新建项目</el-button>
      </div>
    </div>

    <el-table :data="projects" border v-loading="loading">
      <el-table-column type="index" label="序号" width="72" align="center" :index="tableIndex" fixed="left" />
      <el-table-column prop="title" label="项目名称" min-width="220" />
      <el-table-column prop="unit.name" label="申报单位" min-width="180" />
      <el-table-column prop="application_batch.name" label="申报批次" min-width="160" />
      <el-table-column label="项目类别" width="130">
        <template #default="{ row }">{{ displayProjectCategory(row.category) }}</template>
      </el-table-column>
      <el-table-column label="项目类型" width="130">
        <template #default="{ row }">{{ displayProjectType(row.project_type) }}</template>
      </el-table-column>
      <el-table-column label="状态" width="120">
        <template #default="{ row }">
          <el-tag :type="statusMeta(row.status).type">{{ statusMeta(row.status).label }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column v-if="session.can('manage_acceptance')" label="待延期" width="90" align="center">
        <template #default="{ row }">
          <el-tag v-if="row.pending_extension_requests_count" type="warning">{{ row.pending_extension_requests_count }}</el-tag>
          <span v-else>-</span>
        </template>
      </el-table-column>
      <el-table-column prop="created_at" label="创建时间" width="180" />
      <el-table-column prop="submitted_at" label="提交时间" width="180" />
      <el-table-column label="操作" width="260" fixed="right">
        <template #default="{ row }">
          <div class="table-action-row">
            <el-button size="small" :icon="View" @click="openDetail(row)">{{ texts.t('project.action.detail', '详情') }}</el-button>
            <el-button size="small" :icon="Connection" @click="openLifecycle(row)">{{ texts.t('project.action.lifecycle', '全周期') }}</el-button>
            <el-dropdown v-if="moreActions(row).length" trigger="click" @command="(command) => runMoreAction(command, row)">
              <el-button size="small">{{ texts.t('project.action.more', '更多') }}</el-button>
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item v-for="action in moreActions(row)" :key="action.command" :command="action.command" :disabled="action.disabled">
                    {{ action.label }}
                  </el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>
          </div>
        </template>
      </el-table-column>
    </el-table>

    <el-pagination
      v-if="pagination.total > pagination.per_page"
      background
      layout="prev, pager, next, total"
      :current-page="pagination.current_page"
      :page-size="pagination.per_page"
      :total="pagination.total"
      @current-change="changePage"
    />

    <el-drawer
      v-model="dialogVisible"
      :title="editingProject ? '编辑申报项目' : '新建申报项目'"
      size="88%"
      class="project-workbench-drawer"
      destroy-on-close
    >
      <div class="project-workbench">
        <div class="workbench-header">
          <div>
            <strong>{{ editingProject ? '完善项目申报材料' : '创建项目申报草稿' }}</strong>
            <span>{{ selectedBatch?.name || '请选择开放批次' }}</span>
          </div>
          <div class="workbench-progress">
            <el-progress :percentage="formCompletion" :stroke-width="8" />
            <span>{{ formCompletionText }}</span>
          </div>
        </div>

        <el-alert
          v-if="selectedBatch"
          type="info"
          :closable="false"
          show-icon
          class="batch-hint"
        >
          <template #title>
            当前批次允许类别：{{ selectedBatchCategories.length ? selectedBatchCategories.join('、') : '不限' }}；允许类型：{{ selectedBatchProjectTypes.length ? selectedBatchProjectTypes.join('、') : '不限' }}
          </template>
        </el-alert>

        <el-tabs v-model="projectFormTab" tab-position="left" class="project-form-tabs">
          <el-tab-pane label="基本信息" name="basic">
            <el-form :model="form" label-position="top" class="project-form-grid">
              <el-form-item label="项目名称" class="span-2"><el-input v-model="form.title" maxlength="200" show-word-limit /></el-form-item>
              <el-form-item label="申报批次">
                <el-select v-model="form.application_batch_id" placeholder="请选择开放批次" @change="syncFormOptionsWithBatch">
                  <el-option v-for="batch in openBatches" :key="batch.id" :label="batch.name" :value="batch.id" />
                </el-select>
              </el-form-item>
              <el-form-item label="指南代码"><el-input v-model="form.metadata.guide_code" placeholder="例如 1006" /></el-form-item>
              <el-form-item label="项目类型">
                <el-select v-model="form.project_type" filterable :allow-create="!selectedBatchProjectTypes.length" clearable placeholder="请选择当前批次允许的项目类型">
                  <el-option v-for="item in formProjectTypeOptions" :key="item.value" :label="item.label" :value="item.value" />
                </el-select>
              </el-form-item>
              <el-form-item label="项目类别">
                <el-select v-model="form.category" filterable :allow-create="!selectedBatchCategories.length" clearable placeholder="请选择当前批次允许的项目类别">
                  <el-option v-for="item in formProjectCategoryOptions" :key="item.value" :label="item.label" :value="item.value" />
                </el-select>
              </el-form-item>
              <el-form-item label="起止年限">
                <el-date-picker v-model="projectDateRange" type="daterange" value-format="YYYY-MM-DD" range-separator="至" start-placeholder="开始日期" end-placeholder="结束日期" @change="syncProjectDateRange" />
              </el-form-item>
              <el-form-item label="归口管理单位">
                <el-select v-model="form.metadata.management_unit" filterable allow-create default-first-option clearable placeholder="选择或填写归口管理单位">
                  <el-option v-for="item in managementUnitOptions" :key="item.code" :label="dictionaryOptionLabel(item)" :value="dictionaryOptionValue(item)" />
                </el-select>
              </el-form-item>
              <el-form-item label="所属领域">
                <el-select v-model="form.metadata.field" filterable allow-create default-first-option clearable placeholder="选择或填写所属领域">
                  <el-option v-for="item in projectFieldOptions" :key="item.code" :label="dictionaryOptionLabel(item)" :value="dictionaryOptionValue(item)" />
                </el-select>
              </el-form-item>
              <el-form-item label="研究方向">
                <el-select v-model="form.metadata.research_direction" filterable allow-create default-first-option clearable placeholder="选择或填写研究方向">
                  <el-option v-for="item in researchDirectionOptions" :key="item.code" :label="dictionaryOptionLabel(item)" :value="dictionaryOptionValue(item)" />
                </el-select>
              </el-form-item>
              <el-form-item label="合作单位" class="span-2"><el-input v-model="form.metadata.cooperation_units" placeholder="多个单位用顿号或逗号分隔" /></el-form-item>
              <el-form-item label="预算金额（万元）">
                <div class="budget-input-row">
                  <el-input-number v-model="budgetAmountWanModel" :min="0" :precision="2" />
                  <span class="input-unit">万元</span>
                </div>
              </el-form-item>
              <el-form-item label="系统保存金额（元）">
                <el-input :model-value="formatCurrency(form.budget_amount)" disabled />
                <span class="field-help">业务填报按万元录入，系统自动折算为元保存。</span>
              </el-form-item>
            </el-form>
          </el-tab-pane>

          <el-tab-pane label="项目概述" name="overview">
            <el-form :model="form" label-position="top" class="project-form-stack">
              <el-form-item label="项目摘要"><el-input v-model="form.summary" type="textarea" :rows="4" maxlength="5000" show-word-limit /></el-form-item>
              <el-form-item label="国内外研究进展与产业发展现状"><el-input v-model="form.metadata.overview" type="textarea" :rows="8" /></el-form-item>
              <el-form-item label="研究目标与主要内容"><el-input v-model="form.metadata.objectives" type="textarea" :rows="6" /></el-form-item>
              <el-form-item label="创新点与预期成果"><el-input v-model="form.metadata.innovation" type="textarea" :rows="5" /></el-form-item>
            </el-form>
          </el-tab-pane>

          <el-tab-pane label="负责人/成员" name="team">
            <el-form :model="form.metadata" label-position="top" class="project-form-grid">
              <div class="form-section-title span-2">项目负责人信息</div>
              <el-form-item label="姓名"><el-input v-model="form.metadata.leader.name" /></el-form-item>
              <el-form-item label="性别"><el-select v-model="form.metadata.leader.gender" clearable><el-option label="男" value="男" /><el-option label="女" value="女" /></el-select></el-form-item>
              <el-form-item label="身份证号"><el-input v-model="form.metadata.leader.id_number" /></el-form-item>
              <el-form-item label="职称"><el-input v-model="form.metadata.leader.professional_title" /></el-form-item>
              <el-form-item label="工作单位"><el-input v-model="form.metadata.leader.work_unit" /></el-form-item>
              <el-form-item label="电子邮箱"><el-input v-model="form.metadata.leader.email" /></el-form-item>
              <el-form-item label="手机"><el-input v-model="form.metadata.leader.mobile" /></el-form-item>
              <el-form-item label="固定电话"><el-input v-model="form.metadata.leader.phone" /></el-form-item>

              <div class="form-section-title span-2">项目联系人</div>
              <el-form-item label="姓名"><el-input v-model="form.metadata.contact.name" /></el-form-item>
              <el-form-item label="职称"><el-input v-model="form.metadata.contact.professional_title" /></el-form-item>
              <el-form-item label="工作单位"><el-input v-model="form.metadata.contact.work_unit" /></el-form-item>
              <el-form-item label="电子邮箱"><el-input v-model="form.metadata.contact.email" /></el-form-item>
              <el-form-item label="手机"><el-input v-model="form.metadata.contact.mobile" /></el-form-item>
              <el-form-item label="固定电话"><el-input v-model="form.metadata.contact.phone" /></el-form-item>
            </el-form>

            <div class="table-section-title">
              <strong>项目参加成员</strong>
              <el-button size="small" type="primary" :icon="Plus" @click="addMember">新增成员</el-button>
            </div>
            <el-table :data="form.metadata.members" border size="small">
              <el-table-column type="index" label="序号" width="70" />
              <el-table-column label="姓名" min-width="130"><template #default="{ row }"><el-input v-model="row.name" /></template></el-table-column>
              <el-table-column label="性别" width="110"><template #default="{ row }"><el-select v-model="row.gender" clearable><el-option label="男" value="男" /><el-option label="女" value="女" /></el-select></template></el-table-column>
              <el-table-column label="年龄" width="110"><template #default="{ row }"><el-input-number v-model="row.age" :min="0" :max="120" controls-position="right" /></template></el-table-column>
              <el-table-column label="证件号码" min-width="180"><template #default="{ row }"><el-input v-model="row.id_number" /></template></el-table-column>
              <el-table-column label="职称" min-width="130"><template #default="{ row }"><el-input v-model="row.professional_title" /></template></el-table-column>
              <el-table-column label="学历/学位" min-width="150"><template #default="{ row }"><el-input v-model="row.education" /></template></el-table-column>
              <el-table-column label="所在单位" min-width="180"><template #default="{ row }"><el-input v-model="row.organization" /></template></el-table-column>
              <el-table-column label="负责人" width="100"><template #default="{ row }"><el-switch v-model="row.is_leader" /></template></el-table-column>
              <el-table-column label="操作" width="90" fixed="right"><template #default="{ $index }"><el-button size="small" type="danger" :icon="Delete" circle @click="removeMember($index)" /></template></el-table-column>
            </el-table>
          </el-tab-pane>

          <el-tab-pane label="经费预算" name="budget">
            <div class="table-section-title">
              <div>
                <strong>项目经费概算</strong>
                <span>合计 {{ budgetTotalWan }} 万元，已同步为 {{ formatCurrency(form.budget_amount) }}</span>
              </div>
              <el-button size="small" type="primary" :icon="Plus" @click="addBudgetItem">新增经费项</el-button>
            </div>
            <el-table :data="form.metadata.budget_items" border size="small">
              <el-table-column type="index" label="序号" width="70" />
              <el-table-column label="名称" min-width="160"><template #default="{ row }"><el-input v-model="row.name" placeholder="设备费 / 材料费" /></template></el-table-column>
              <el-table-column label="费用类型" min-width="140"><template #default="{ row }"><el-select v-model="row.expense_type"><el-option label="直接费用" value="直接费用" /><el-option label="间接费用" value="间接费用" /></el-select></template></el-table-column>
              <el-table-column label="合计(万元)" width="140"><template #default="{ row }"><el-input-number v-model="row.total" :min="0" :precision="2" controls-position="right" @change="syncBudgetAmountFromItems" /></template></el-table-column>
              <el-table-column label="专项经费(万元)" width="150"><template #default="{ row }"><el-input-number v-model="row.special_fund" :min="0" :precision="2" controls-position="right" /></template></el-table-column>
              <el-table-column label="自筹经费(万元)" width="150"><template #default="{ row }"><el-input-number v-model="row.self_fund" :min="0" :precision="2" controls-position="right" /></template></el-table-column>
              <el-table-column label="备注" min-width="160"><template #default="{ row }"><el-input v-model="row.remark" /></template></el-table-column>
              <el-table-column label="操作" width="90" fixed="right"><template #default="{ $index }"><el-button size="small" type="danger" :icon="Delete" circle @click="removeBudgetItem($index)" /></template></el-table-column>
            </el-table>
          </el-tab-pane>

          <el-tab-pane label="设备材料" name="equipment">
            <div class="table-section-title">
              <strong>项目设备材料</strong>
              <el-button size="small" type="primary" :icon="Plus" @click="addEquipmentItem">新增设备/材料</el-button>
            </div>
            <el-table :data="form.metadata.equipment_items" border size="small">
              <el-table-column type="index" label="序号" width="70" />
              <el-table-column label="物资名称" min-width="180"><template #default="{ row }"><el-input v-model="row.name" /></template></el-table-column>
              <el-table-column label="型号规格" min-width="180"><template #default="{ row }"><el-input v-model="row.spec" /></template></el-table-column>
              <el-table-column label="单价(元)" width="140"><template #default="{ row }"><el-input-number v-model="row.unit_price" :min="0" :precision="2" controls-position="right" @change="syncEquipmentAmount(row)" /></template></el-table-column>
              <el-table-column label="数量" width="120"><template #default="{ row }"><el-input-number v-model="row.quantity" :min="0" :precision="2" controls-position="right" @change="syncEquipmentAmount(row)" /></template></el-table-column>
              <el-table-column label="金额(万元)" width="140"><template #default="{ row }"><el-input-number v-model="row.amount" :min="0" :precision="2" controls-position="right" /></template></el-table-column>
              <el-table-column label="用途" min-width="180"><template #default="{ row }"><el-input v-model="row.purpose" /></template></el-table-column>
              <el-table-column label="操作" width="90" fixed="right"><template #default="{ $index }"><el-button size="small" type="danger" :icon="Delete" circle @click="removeEquipmentItem($index)" /></template></el-table-column>
            </el-table>
          </el-tab-pane>

          <el-tab-pane label="盖章承诺" name="seal">
            <el-form :model="form.metadata.seal" label-position="top" class="project-form-grid">
              <el-form-item label="法定代表人"><el-input v-model="form.metadata.seal.legal_representative" placeholder="用于申报承诺和盖章信息" /></el-form-item>
              <el-form-item label="盖章日期"><el-date-picker v-model="form.metadata.seal.seal_date" type="date" value-format="YYYY-MM-DD" /></el-form-item>
              <el-form-item label="申报承诺" class="span-2">
                <el-input
                  v-model="form.metadata.seal.commitment"
                  type="textarea"
                  :rows="5"
                  placeholder="可填写单位承诺、真实性声明、知识产权和伦理合规说明"
                />
              </el-form-item>
              <el-form-item label="备注" class="span-2"><el-input v-model="form.metadata.seal.remark" type="textarea" :rows="3" /></el-form-item>
            </el-form>
            <el-alert
              type="info"
              show-icon
              :closable="false"
              title="盖章扫描件、承诺书、合作协议等文件请在“附件材料”中上传，便于审核人员集中查看。"
            />
          </el-tab-pane>

          <el-tab-pane label="附件材料" name="files">
            <el-alert v-if="!editingProject" title="请先保存草稿，保存成功后即可在同一入口继续上传项目附件。" type="warning" show-icon :closable="false" />
            <template v-else>
              <el-alert title="申报书、预算说明、合作协议、盖章扫描件等材料可在这里集中上传。脚本文件和危险扩展名会被拒绝。" type="info" show-icon :closable="false" />
              <el-upload class="upload-box compact-upload" drag :http-request="uploadFileFromWorkbench" :show-file-list="false">
                <el-icon><UploadFilled /></el-icon>
                <div>拖拽文件到这里或点击选择</div>
              </el-upload>
              <el-table :data="workbenchFiles" border size="small">
                <el-table-column type="index" label="#" width="60" />
                <el-table-column prop="original_name" label="文件名" min-width="240" />
                <el-table-column prop="extension" label="类型" width="80" />
                <el-table-column prop="size_bytes" label="大小" width="120"><template #default="{ row }">{{ formatBytes(row.size_bytes) }}</template></el-table-column>
                <el-table-column label="操作" width="130"><template #default="{ row }"><el-button size="small" :icon="Download" circle @click="downloadFile(row)" /><el-button size="small" type="danger" :icon="Delete" circle @click="deleteWorkbenchFile(row)" /></template></el-table-column>
              </el-table>
            </template>
          </el-tab-pane>
        </el-tabs>
      </div>

      <template #footer>
        <div class="workbench-footer">
          <el-button @click="dialogVisible = false">关闭</el-button>
          <el-button @click="goPrevFormStep">上一步</el-button>
          <el-button @click="goNextFormStep">下一步</el-button>
          <el-button type="primary" :loading="saving" @click="saveProject">保存草稿</el-button>
          <el-button v-if="editingProject && canSubmit(editingProject)" type="success" :loading="saving" @click="saveAndSubmitProject">提交审核</el-button>
        </div>
      </template>
    </el-drawer>

    <el-dialog v-model="extensionVisible" title="申请延期" width="520px">
      <el-form :model="extensionForm" label-position="top">
        <el-form-item label="延期原因"><el-input v-model="extensionForm.reason" type="textarea" :rows="4" /></el-form-item>
        <el-form-item label="计划完成日期"><el-date-picker v-model="extensionForm.expected_date" value-format="YYYY-MM-DD" type="date" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="extensionVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="requestExtension">提交申请</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="closeVisible" title="关闭验收" width="520px">
      <el-form :model="closeForm" label-position="top">
        <el-form-item label="验收意见"><el-input v-model="closeForm.comment" type="textarea" :rows="4" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="closeVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="closeProject">确认关闭</el-button>
      </template>
    </el-dialog>

    <el-drawer v-model="detailVisible" title="项目详情" size="820px">
      <div v-if="detail" class="detail-stack">
        <el-descriptions :column="2" border>
          <el-descriptions-item label="项目名称" :span="2">{{ detail.title }}</el-descriptions-item>
          <el-descriptions-item label="申报单位">{{ detail.unit?.name || '-' }}</el-descriptions-item>
          <el-descriptions-item label="状态">{{ statusMeta(detail.status).label }}</el-descriptions-item>
          <el-descriptions-item label="申报批次">{{ detail.application_batch?.name || '-' }}</el-descriptions-item>
          <el-descriptions-item label="项目类别">{{ displayProjectCategory(detail.category) }}</el-descriptions-item>
          <el-descriptions-item label="项目类型">{{ displayProjectType(detail.project_type) }}</el-descriptions-item>
          <el-descriptions-item label="指南代码">{{ detailMetadata.guide_code || '-' }}</el-descriptions-item>
          <el-descriptions-item label="起止年限">{{ detailDateRange(detailMetadata) }}</el-descriptions-item>
          <el-descriptions-item label="归口管理单位">{{ displayManagementUnit(detailMetadata.management_unit) }}</el-descriptions-item>
          <el-descriptions-item label="所属领域">{{ displayProjectField(detailMetadata.field) }}</el-descriptions-item>
          <el-descriptions-item label="研究方向">{{ displayResearchDirection(detailMetadata.research_direction) }}</el-descriptions-item>
          <el-descriptions-item label="合作单位">{{ detailMetadata.cooperation_units || '-' }}</el-descriptions-item>
          <el-descriptions-item label="预算金额">{{ formatWanYuan(detail.budget_amount) }}（{{ formatCurrency(detail.budget_amount) }}）</el-descriptions-item>
          <el-descriptions-item label="终审支持">{{ finalSupportText(detail).isSupported }}</el-descriptions-item>
          <el-descriptions-item label="支持资金">{{ finalSupportText(detail).supportAmount }}</el-descriptions-item>
          <el-descriptions-item label="推荐专家">{{ finalSupportText(detail).recommendedExperts }}</el-descriptions-item>
          <el-descriptions-item label="摘要" :span="2">{{ detail.summary || '-' }}</el-descriptions-item>
        </el-descriptions>

        <section>
          <div class="section-title">项目概述</div>
          <el-descriptions :column="1" border>
            <el-descriptions-item label="国内外研究进展与产业发展现状">{{ detailMetadata.overview || '-' }}</el-descriptions-item>
            <el-descriptions-item label="研究目标与主要内容">{{ detailMetadata.objectives || '-' }}</el-descriptions-item>
            <el-descriptions-item label="创新点与预期成果">{{ detailMetadata.innovation || '-' }}</el-descriptions-item>
          </el-descriptions>
        </section>

        <section>
          <div class="section-title">负责人 / 联系人</div>
          <el-descriptions :column="2" border>
            <el-descriptions-item label="负责人">{{ detailMetadata.leader.name || '-' }}</el-descriptions-item>
            <el-descriptions-item label="负责人手机">{{ detailMetadata.leader.mobile || '-' }}</el-descriptions-item>
            <el-descriptions-item label="负责人职称">{{ detailMetadata.leader.professional_title || '-' }}</el-descriptions-item>
            <el-descriptions-item label="负责人单位">{{ detailMetadata.leader.work_unit || '-' }}</el-descriptions-item>
            <el-descriptions-item label="负责人邮箱">{{ detailMetadata.leader.email || '-' }}</el-descriptions-item>
            <el-descriptions-item label="负责人电话">{{ detailMetadata.leader.phone || '-' }}</el-descriptions-item>
            <el-descriptions-item label="联系人">{{ detailMetadata.contact.name || '-' }}</el-descriptions-item>
            <el-descriptions-item label="联系人手机">{{ detailMetadata.contact.mobile || '-' }}</el-descriptions-item>
            <el-descriptions-item label="联系人职称">{{ detailMetadata.contact.professional_title || '-' }}</el-descriptions-item>
            <el-descriptions-item label="联系人单位">{{ detailMetadata.contact.work_unit || '-' }}</el-descriptions-item>
            <el-descriptions-item label="联系人邮箱">{{ detailMetadata.contact.email || '-' }}</el-descriptions-item>
            <el-descriptions-item label="联系人电话">{{ detailMetadata.contact.phone || '-' }}</el-descriptions-item>
          </el-descriptions>
        </section>

        <section>
          <div class="section-title">项目参加成员</div>
          <el-table :data="detailMetadata.members" border size="small" empty-text="暂无成员">
            <el-table-column type="index" label="序号" width="70" />
            <el-table-column prop="name" label="姓名" min-width="120" />
            <el-table-column prop="gender" label="性别" width="80" />
            <el-table-column prop="age" label="年龄" width="80" />
            <el-table-column prop="professional_title" label="职称" min-width="120" />
            <el-table-column prop="education" label="学历/学位" min-width="130" />
            <el-table-column prop="organization" label="所在单位" min-width="180" />
            <el-table-column label="负责人" width="90">
              <template #default="{ row }">{{ row.is_leader ? '是' : '否' }}</template>
            </el-table-column>
          </el-table>
        </section>

        <section>
          <div class="section-title">经费预算</div>
          <el-table :data="detailMetadata.budget_items" border size="small" empty-text="暂无预算明细">
            <el-table-column type="index" label="序号" width="70" />
            <el-table-column prop="name" label="名称" min-width="160" />
            <el-table-column prop="expense_type" label="费用类型" width="120" />
            <el-table-column label="合计(万元)" width="120">
              <template #default="{ row }">{{ formatNumber(row.total) }}</template>
            </el-table-column>
            <el-table-column label="专项经费(万元)" width="140">
              <template #default="{ row }">{{ formatNumber(row.special_fund) }}</template>
            </el-table-column>
            <el-table-column label="自筹经费(万元)" width="140">
              <template #default="{ row }">{{ formatNumber(row.self_fund) }}</template>
            </el-table-column>
            <el-table-column prop="remark" label="备注" min-width="160" />
          </el-table>
        </section>

        <section>
          <div class="section-title">设备材料</div>
          <el-table :data="detailMetadata.equipment_items" border size="small" empty-text="暂无设备材料">
            <el-table-column type="index" label="序号" width="70" />
            <el-table-column prop="name" label="物资名称" min-width="160" />
            <el-table-column prop="spec" label="型号规格" min-width="160" />
            <el-table-column label="单价(元)" width="120">
              <template #default="{ row }">{{ formatNumber(row.unit_price) }}</template>
            </el-table-column>
            <el-table-column label="数量" width="100">
              <template #default="{ row }">{{ formatNumber(row.quantity) }}</template>
            </el-table-column>
            <el-table-column label="金额(万元)" width="120">
              <template #default="{ row }">{{ formatNumber(row.amount) }}</template>
            </el-table-column>
            <el-table-column prop="purpose" label="用途" min-width="180" />
          </el-table>
        </section>

        <section>
          <div class="section-title">盖章承诺</div>
          <el-descriptions :column="2" border>
            <el-descriptions-item label="法定代表人">{{ detailMetadata.seal.legal_representative || '-' }}</el-descriptions-item>
            <el-descriptions-item label="盖章日期">{{ detailMetadata.seal.seal_date || '-' }}</el-descriptions-item>
            <el-descriptions-item label="申报承诺" :span="2">{{ detailMetadata.seal.commitment || '-' }}</el-descriptions-item>
            <el-descriptions-item label="备注" :span="2">{{ detailMetadata.seal.remark || '-' }}</el-descriptions-item>
          </el-descriptions>
        </section>

        <section v-if="detail.timeline?.length">
          <div class="section-title">项目阶段</div>
          <el-steps :active="timelineActiveIndex(detail.timeline)" finish-status="success" process-status="process" align-center>
            <el-step v-for="item in detail.timeline" :key="item.key" :title="item.label" :description="timelineDescription(item)" />
          </el-steps>
        </section>

        <section v-if="detail.metadata?.extension_requests?.length">
          <div class="section-title">延期记录</div>
          <el-table :data="detail.metadata.extension_requests" border size="small">
            <el-table-column prop="reason" label="原因" min-width="220" />
            <el-table-column prop="expected_date" label="计划日期" width="120" />
            <el-table-column label="状态" width="100">
              <template #default="{ row }">
                <el-tag :type="extensionStatusMeta(row.status).type">{{ extensionStatusMeta(row.status).label }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="review_comment" label="处理意见" min-width="160" />
            <el-table-column prop="requested_at" label="申请时间" width="170" />
            <el-table-column v-if="session.can('manage_acceptance')" label="操作" width="130">
              <template #default="{ row, $index }">
                <el-tooltip v-if="canReviewExtension(row)" content="通过延期" placement="top"><el-button size="small" type="success" :icon="Checked" circle @click="reviewExtension($index, 'approved')" /></el-tooltip>
                <el-tooltip v-if="canReviewExtension(row)" content="驳回延期" placement="top"><el-button size="small" type="danger" :icon="CloseBold" circle @click="reviewExtension($index, 'rejected')" /></el-tooltip>
              </template>
            </el-table-column>
          </el-table>
        </section>

        <section>
          <div class="section-title">附件</div>
          <el-table :data="detail.files || []" border size="small">
            <el-table-column prop="original_name" label="文件名" min-width="220" />
            <el-table-column prop="extension" label="类型" width="80" />
            <el-table-column prop="size_bytes" label="大小" width="110"><template #default="{ row }">{{ formatBytes(row.size_bytes) }}</template></el-table-column>
            <el-table-column label="操作" width="150">
              <template #default="{ row }">
                <el-tooltip content="下载" placement="top"><el-button size="small" :icon="Download" circle @click="downloadFile(row)" /></el-tooltip>
                <el-tooltip v-if="canEdit(detail)" content="删除附件" placement="top"><el-button size="small" type="danger" :icon="Delete" circle @click="deleteFile(row)" /></el-tooltip>
                <el-tooltip v-if="session.can('view_operation_logs')" content="查看附件日志" placement="top"><el-button size="small" :icon="Files" circle @click="openFileLogs(row)" /></el-tooltip>
              </template>
            </el-table-column>
          </el-table>
        </section>

        <section>
          <div class="section-title">
            <span>审核记录</span>
            <el-tooltip v-if="session.can('review_projects')" content="查看审核结果" placement="top">
              <el-button size="small" :icon="View" circle @click="openReviewResults(detail)" />
            </el-tooltip>
            <el-tooltip v-if="session.can('view_operation_logs')" content="查看操作日志" placement="top">
              <el-button size="small" :icon="Files" circle @click="openProjectLogs(detail)" />
            </el-tooltip>
          </div>
          <el-table :data="detail.reviews || []" border size="small">
            <el-table-column label="阶段" width="110">
              <template #default="{ row }">{{ roleLabel(row.stage) }}</template>
            </el-table-column>
            <el-table-column label="结果" width="110">
              <template #default="{ row }">{{ decisionLabel(row.decision) }}</template>
            </el-table-column>
            <el-table-column prop="reviewer.username" label="审核人" width="130" />
            <el-table-column prop="score" label="评分" width="90" />
            <el-table-column prop="comment" label="意见" min-width="220" />
            <el-table-column prop="reviewed_at" label="时间" width="170" />
          </el-table>
        </section>
      </div>
    </el-drawer>
  </section>
</template>

<script setup>
import { computed, onMounted, onUnmounted, reactive, ref, watch } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Checked, CloseBold, Connection, Delete, Download, Files, Plus, Search, UploadFilled, View } from '@element-plus/icons-vue'
import { useRoute, useRouter } from 'vue-router'
import { api, downloadApi } from '../api.js'
import { useSessionStore } from '../store.js'
import { useTextStore } from '../texts.js'

const route = useRoute()
const router = useRouter()
const session = useSessionStore()
const texts = useTextStore()
const statusOptions = [
  { label: '全部', value: '' },
  { label: '草稿', value: 'draft' },
  { label: '已提交', value: 'submitted' },
  { label: '退回修改', value: 'returned' },
  { label: '审核中', value: 'reviewing' },
  { label: '已通过', value: 'approved' },
  { label: '验收中', value: 'acceptance' },
  { label: '已关闭', value: 'closed' }
]
const statusLabels = {
  draft: { label: '草稿', type: 'info' },
  submitted: { label: '已提交', type: 'warning' },
  returned: { label: '退回修改', type: 'danger' },
  reviewing: { label: '审核中', type: 'primary' },
  approved: { label: '已通过', type: 'success' },
  acceptance: { label: '验收中', type: 'primary' },
  closed: { label: '已关闭', type: 'info' },
  rejected: { label: '已拒绝', type: 'danger' }
}
const roleLabels = {
  county: '区县审核',
  department: '部门审核',
  expert: '专家评审',
  admin: '管理员终审'
}
const decisionLabels = {
  approve: '通过',
  recommend: '推荐',
  accept: '通过',
  return: '退回',
  reject: '驳回'
}
const extensionStatusLabels = {
  pending: { label: '待处理', type: 'warning' },
  approved: { label: '已通过', type: 'success' },
  rejected: { label: '已驳回', type: 'danger' }
}

const status = ref('')
const keyword = ref('')
const loading = ref(false)
const saving = ref(false)
const projects = ref([])
const projectTypeOptions = ref([])
const projectCategoryOptions = ref([])
const managementUnitOptions = ref([])
const projectFieldOptions = ref([])
const researchDirectionOptions = ref([])
const openBatches = ref([])
const category = ref('')
const projectType = ref('')
const applicationBatchId = ref('')
const e2eFilter = ref('')
const pendingExtensionOnly = ref(false)
const dialogVisible = ref(false)
const extensionVisible = ref(false)
const closeVisible = ref(false)
const detailVisible = ref(false)
const detail = ref(null)
const editingProject = ref(null)
const actionProject = ref(null)
const projectFormTab = ref('basic')
const projectDateRange = ref([])
const formSteps = ['basic', 'overview', 'team', 'budget', 'equipment', 'seal', 'files']
const form = reactive({
  title: '',
  application_batch_id: null,
  category: '',
  project_type: '',
  summary: '',
  budget_amount: 0,
  metadata: emptyProjectMetadata()
})
const extensionForm = reactive({ reason: '', expected_date: '' })
const closeForm = reactive({ comment: '' })
const pagination = reactive({ current_page: 1, per_page: 20, total: 0 })
const unitCanWriteProjects = computed(() => session.role !== 'unit' || session.user?.unit?.status === 'active')
const canCreate = computed(() => session.can('create_projects') && unitCanWriteProjects.value)
const canFilterE2e = computed(() => ['admin', 'super_admin'].includes(session.role))
const selectedBatch = computed(() => openBatches.value.find((batch) => batch.id === form.application_batch_id) || null)
const selectedBatchCategoryOptions = computed(() => batchAllowedOptions('project_category', selectedBatch.value?.allowed_categories))
const selectedBatchProjectTypeOptions = computed(() => batchAllowedOptions('project_type', selectedBatch.value?.allowed_project_types))
const selectedBatchCategories = computed(() => selectedBatchCategoryOptions.value.map((item) => item.label))
const selectedBatchProjectTypes = computed(() => selectedBatchProjectTypeOptions.value.map((item) => item.label))
const selectedBatchCategoryValues = computed(() => selectedBatchCategoryOptions.value.map((item) => item.value))
const selectedBatchProjectTypeValues = computed(() => selectedBatchProjectTypeOptions.value.map((item) => item.value))
const formProjectCategoryOptions = computed(() => {
  if (selectedBatchCategoryOptions.value.length) return selectedBatchCategoryOptions.value.map(({ label, value }) => ({ label, value }))
  return projectCategoryOptions.value.map((item) => ({ label: dictionaryOptionLabel(item), value: dictionaryOptionValue(item) }))
})
const formProjectTypeOptions = computed(() => {
  if (selectedBatchProjectTypeOptions.value.length) return selectedBatchProjectTypeOptions.value.map(({ label, value }) => ({ label, value }))
  return projectTypeOptions.value.map((item) => ({ label: dictionaryOptionLabel(item), value: dictionaryOptionValue(item) }))
})
const workbenchFiles = computed(() => editingProject.value?.files || [])
const detailMetadata = computed(() => normalizeProjectMetadata(detail.value?.metadata || {}))
const budgetAmountWanModel = computed({
  get: () => Number((Number(form.budget_amount || 0) / 10000).toFixed(2)),
  set: (value) => {
    form.budget_amount = Number((Number(value || 0) * 10000).toFixed(2))
  }
})
const budgetTotalWan = computed(() => {
  const total = (form.metadata.budget_items || []).reduce((sum, item) => sum + Number(item.total || 0), 0)
  return total.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
})
const formCompletion = computed(() => {
  const checks = [
    form.title,
    form.application_batch_id,
    form.project_type,
    form.category,
    form.summary,
    form.budget_amount,
    form.metadata.guide_code,
    form.metadata.start_date && form.metadata.end_date,
    form.metadata.management_unit,
    form.metadata.field,
    form.metadata.research_direction,
    form.metadata.overview,
    form.metadata.objectives,
    form.metadata.innovation,
    form.metadata.leader?.name,
    form.metadata.leader?.mobile,
    form.metadata.contact?.name,
    form.metadata.contact?.mobile,
    form.metadata.members?.length,
    form.metadata.budget_items?.length,
    form.metadata.equipment_items?.length,
    editingProject.value?.files?.length
  ]
  const done = checks.filter(Boolean).length
  return Math.min(100, Math.round((done / checks.length) * 100))
})
const formCompletionText = computed(() => {
  if (formCompletion.value >= 85) return '材料基本完整，可保存并提交审核'
  if (formCompletion.value >= 55) return '主体信息已填写，建议继续补齐成员、预算和附件'
  return '先完成基本信息、概述和联系人'
})

function emptyPerson() {
  return {
    name: '',
    gender: '',
    id_number: '',
    professional_title: '',
    work_unit: '',
    email: '',
    mobile: '',
    phone: ''
  }
}

function emptyProjectMetadata() {
  return {
    guide_code: '',
    start_date: '',
    end_date: '',
    management_unit: '',
    field: '',
    research_direction: '',
    cooperation_units: '',
    overview: '',
    objectives: '',
    innovation: '',
    leader: emptyPerson(),
    contact: emptyPerson(),
    members: [],
    budget_items: [],
    equipment_items: [],
    seal: {
      legal_representative: '',
      commitment: '',
      seal_date: '',
      remark: ''
    }
  }
}

function normalizeProjectMetadata(metadata = {}) {
  const defaults = emptyProjectMetadata()
  const source = metadata && typeof metadata === 'object' ? metadata : {}

  return {
    ...defaults,
    ...source,
    leader: { ...defaults.leader, ...(source.leader || {}) },
    contact: { ...defaults.contact, ...(source.contact || {}) },
    members: Array.isArray(source.members) ? source.members.map(normalizeMember) : [],
    budget_items: Array.isArray(source.budget_items) ? source.budget_items.map(normalizeBudgetItem) : [],
    equipment_items: Array.isArray(source.equipment_items) ? source.equipment_items.map(normalizeEquipmentItem) : [],
    seal: { ...defaults.seal, ...(source.seal || {}) }
  }
}

function normalizeMember(member = {}) {
  return {
    name: member.name || '',
    gender: member.gender || '',
    age: member.age === null || member.age === undefined || member.age === '' ? null : Number(member.age),
    id_number: member.id_number || '',
    professional_title: member.professional_title || '',
    education: member.education || '',
    organization: member.organization || '',
    role: member.role || '',
    task: member.task || '',
    is_leader: Boolean(member.is_leader)
  }
}

function normalizeBudgetItem(item = {}) {
  return {
    name: item.name || '',
    expense_type: item.expense_type || '直接费用',
    total: Number(item.total || 0),
    special_fund: Number(item.special_fund || 0),
    self_fund: Number(item.self_fund || 0),
    remark: item.remark || ''
  }
}

function normalizeEquipmentItem(item = {}) {
  return {
    name: item.name || '',
    spec: item.spec || '',
    unit_price: Number(item.unit_price || 0),
    quantity: Number(item.quantity || 0),
    amount: Number(item.amount || 0),
    purpose: item.purpose || ''
  }
}

function statusMeta(value) {
  return statusLabels[value] || { label: value || '-', type: 'info' }
}

function tableIndex(index) {
  return (pagination.current_page - 1) * pagination.per_page + index + 1
}

function roleLabel(role) {
  return roleLabels[role] || role || '-'
}

function decisionLabel(value) {
  return decisionLabels[value] || value || '-'
}

function extensionStatusMeta(value) {
  return extensionStatusLabels[value || 'pending'] || { label: value || '-', type: 'info' }
}

function canEdit(row) {
  return unitCanWriteProjects.value && session.can('create_projects') && ['draft', 'returned'].includes(row.status)
}

function canSubmit(row) {
  return unitCanWriteProjects.value && session.can('submit_projects') && ['draft', 'returned'].includes(row.status)
}

function canWithdraw(row) {
  return unitCanWriteProjects.value && session.can('submit_projects') && row.status === 'submitted'
}

function canDelete(row) {
  return unitCanWriteProjects.value && session.can('create_projects') && row.status === 'draft'
}

function canRequestExtension(row) {
  return unitCanWriteProjects.value && session.can('submit_projects') && ['approved', 'acceptance'].includes(row.status)
}

function canEnterAcceptance(row) {
  return session.can('manage_acceptance') && row.status === 'approved'
}

function canClose(row) {
  return session.can('manage_acceptance') && row.status === 'acceptance' && pendingExtensionCount(row) === 0
}

function canReviewExtension(row) {
  return session.can('manage_acceptance') && (row.status || 'pending') === 'pending'
}

function pendingExtensionCount(row) {
  if (row.pending_extension_requests_count !== undefined) return Number(row.pending_extension_requests_count || 0)
  return (row.metadata?.extension_requests || []).filter((item) => (item.status || 'pending') === 'pending').length
}

function normalizeOptionList(value) {
  return Array.isArray(value) ? value.map((item) => String(item || '').trim()).filter(Boolean) : []
}

function dictionaryOptions(group) {
  const groups = {
    project_category: projectCategoryOptions.value,
    project_type: projectTypeOptions.value,
    management_unit: managementUnitOptions.value,
    project_field: projectFieldOptions.value,
    research_direction: researchDirectionOptions.value
  }
  return groups[group] || []
}

function findDictionaryItem(group, value) {
  const text = String(value || '').trim()
  if (!text) return null
  return dictionaryOptions(group).find((item) => item.code === text || item.label === text) || null
}

function dictionaryOptionValue(item) {
  return item?.code || item?.label || ''
}

function dictionaryOptionLabel(item) {
  if (!item) return '-'
  if (!item.code || item.code === item.label) return item.label || item.code || '-'
  return `${item.label}（${item.code}）`
}

function dictionaryDisplay(group, value) {
  const text = String(value || '').trim()
  if (!text) return '-'
  const item = findDictionaryItem(group, text)
  return item?.label || text
}

function displayProjectCategory(value) {
  return dictionaryDisplay('project_category', value)
}

function displayProjectType(value) {
  return dictionaryDisplay('project_type', value)
}

function displayManagementUnit(value) {
  return dictionaryDisplay('management_unit', value)
}

function displayProjectField(value) {
  return dictionaryDisplay('project_field', value)
}

function displayResearchDirection(value) {
  return dictionaryDisplay('research_direction', value)
}

function batchAllowsValue(group, allowedValues, value) {
  if (!allowedValues.length) return true
  const text = String(value || '').trim()
  if (!text) return false
  const valueItem = findDictionaryItem(group, text)
  const equivalents = new Set([text, valueItem?.code, valueItem?.label].filter(Boolean))
  return allowedValues.some((allowedValue) => {
    const allowedText = String(allowedValue || '').trim()
    const allowedItem = findDictionaryItem(group, allowedText)
    return [allowedText, allowedItem?.code, allowedItem?.label].filter(Boolean).some((item) => equivalents.has(item))
  })
}

function batchAllowedOptions(group, values) {
  const known = []
  const custom = []
  const seen = new Set()

  normalizeOptionList(values).forEach((value) => {
    const item = findDictionaryItem(group, value)
    const option = item
      ? { label: dictionaryOptionLabel(item), value: dictionaryOptionValue(item), canonical: item.code || item.label, custom: false }
      : { label: value, value, canonical: `custom:${value}`, custom: true }

    if (!option.canonical || seen.has(option.canonical)) return
    seen.add(option.canonical)
    ;(option.custom ? custom : known).push(option)
  })

  return [...known, ...custom]
}

function syncFormOptionsWithBatch() {
  if (selectedBatchCategoryValues.value.length && !batchAllowsValue('project_category', selectedBatchCategoryValues.value, form.category)) {
    form.category = selectedBatchCategoryValues.value[0] || ''
  }

  if (selectedBatchProjectTypeValues.value.length && !batchAllowsValue('project_type', selectedBatchProjectTypeValues.value, form.project_type)) {
    form.project_type = selectedBatchProjectTypeValues.value[0] || ''
  }
}

function syncProjectDateRange() {
  form.metadata.start_date = projectDateRange.value?.[0] || ''
  form.metadata.end_date = projectDateRange.value?.[1] || ''
}

function syncProjectDateRangeFromForm() {
  projectDateRange.value = form.metadata.start_date && form.metadata.end_date
    ? [form.metadata.start_date, form.metadata.end_date]
    : []
}

function goPrevFormStep() {
  const index = formSteps.indexOf(projectFormTab.value)
  projectFormTab.value = formSteps[Math.max(0, index - 1)] || formSteps[0]
}

function goNextFormStep() {
  const index = formSteps.indexOf(projectFormTab.value)
  projectFormTab.value = formSteps[Math.min(formSteps.length - 1, index + 1)] || formSteps[0]
}

function addMember() {
  form.metadata.members.push(normalizeMember({}))
}

function removeMember(index) {
  form.metadata.members.splice(index, 1)
}

function addBudgetItem() {
  form.metadata.budget_items.push(normalizeBudgetItem({}))
  syncBudgetAmountFromItems()
}

function removeBudgetItem(index) {
  form.metadata.budget_items.splice(index, 1)
  syncBudgetAmountFromItems()
}

function addEquipmentItem() {
  form.metadata.equipment_items.push(normalizeEquipmentItem({}))
}

function removeEquipmentItem(index) {
  form.metadata.equipment_items.splice(index, 1)
}

function syncBudgetAmountFromItems() {
  const totalWan = form.metadata.budget_items.reduce((sum, item) => sum + Number(item.total || 0), 0)
  if (totalWan > 0) form.budget_amount = Number((totalWan * 10000).toFixed(2))
}

function syncEquipmentAmount(row) {
  const amountYuan = Number(row.unit_price || 0) * Number(row.quantity || 0)
  row.amount = Number((amountYuan / 10000).toFixed(2))
}

function formatWanYuan(value) {
  const amount = Number(value || 0)
  if (!amount) return '0.00 万元'
  return `${(amount / 10000).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} 万元`
}

function applyProjectToForm(project = {}) {
  Object.assign(form, {
    title: project.title || '',
    category: project.category || '',
    project_type: project.project_type || '',
    application_batch_id: project.application_batch_id || project.application_batch?.id || null,
    summary: project.summary || '',
    budget_amount: Number(project.budget_amount || 0),
    metadata: normalizeProjectMetadata(project.metadata || {})
  })
  syncProjectDateRangeFromForm()
  syncFormOptionsWithBatch()
}

function projectPayload() {
  syncProjectDateRange()
  return {
    title: form.title,
    application_batch_id: form.application_batch_id,
    category: form.category,
    project_type: form.project_type,
    summary: form.summary,
    budget_amount: Number(form.budget_amount || 0),
    metadata: normalizeProjectMetadata(form.metadata)
  }
}

function validateProjectDraft() {
  if (!String(form.title || '').trim()) {
    projectFormTab.value = 'basic'
    ElMessage.warning('请先填写项目名称')
    return false
  }

  if (!form.application_batch_id) {
    projectFormTab.value = 'basic'
    ElMessage.warning('请选择申报批次')
    return false
  }

  if (selectedBatchCategoryValues.value.length && !form.category) {
    projectFormTab.value = 'basic'
    ElMessage.warning('请选择项目类别')
    return false
  }

  if (selectedBatchProjectTypeValues.value.length && !form.project_type) {
    projectFormTab.value = 'basic'
    ElMessage.warning('请选择项目类型')
    return false
  }

  return true
}

function isUserCancel(err) {
  return err === 'cancel' || err === 'close' || err?.message === 'cancel' || err?.message === 'close'
}

function showActionError(err, fallback) {
  if (isUserCancel(err)) return
  ElMessage.error(err?.message || fallback)
}

function moreActions(row) {
  const actions = []
  if (canEdit(row)) {
    actions.push({ command: 'edit', label: texts.t('project.action.edit', '编辑') })
    actions.push({ command: 'upload', label: texts.t('project.action.files', '附件') })
  }
  if (canSubmit(row)) actions.push({ command: 'submit', label: texts.t('project.action.submit', '提交') })
  if (canWithdraw(row)) actions.push({ command: 'withdraw', label: texts.t('project.action.withdraw', '撤回') })
  if (canRequestExtension(row)) actions.push({ command: 'extension', label: texts.t('project.action.extension', '申请延期') })
  if (canEnterAcceptance(row)) actions.push({ command: 'enterAcceptance', label: texts.t('project.action.enter_acceptance', '进入验收') })
  if (canClose(row)) actions.push({ command: 'close', label: texts.t('project.action.close', '关闭验收') })
  if (session.can('review_projects')) actions.push({ command: 'reviews', label: texts.t('project.action.review_logs', '审核记录') })
  if (session.can('view_operation_logs')) actions.push({ command: 'logs', label: texts.t('project.action.operation_logs', '操作日志') })
  if (canDelete(row)) actions.push({ command: 'delete', label: texts.t('project.action.delete', '删除') })
  return actions
}

function runMoreAction(command, row) {
  const handlers = {
    edit: () => openEdit(row),
    upload: () => openWorkbenchFiles(row),
    submit: () => submitProject(row),
    withdraw: () => withdrawProject(row),
    extension: () => openExtension(row),
    enterAcceptance: () => enterAcceptance(row),
    close: () => openClose(row),
    reviews: () => openReviewResults(row),
    logs: () => openProjectLogs(row),
    delete: () => deleteProject(row)
  }
  handlers[command]?.()
}

function resetForm() {
  Object.assign(form, {
    title: '',
    application_batch_id: openBatches.value[0]?.id || null,
    category: '',
    project_type: '',
    summary: '',
    budget_amount: 0,
    metadata: emptyProjectMetadata()
  })
  projectDateRange.value = []
  projectFormTab.value = 'basic'
  syncFormOptionsWithBatch()
}

async function loadDictionaries() {
  const [types, categories, managementUnits, fields, directions, batches] = await Promise.all([
    api('/dictionaries?group=project_type'),
    api('/dictionaries?group=project_category'),
    api('/dictionaries?group=management_unit'),
    api('/dictionaries?group=project_field'),
    api('/dictionaries?group=research_direction'),
    api('/public/application-batches/open')
  ])
  projectTypeOptions.value = types
  projectCategoryOptions.value = categories
  managementUnitOptions.value = managementUnits
  projectFieldOptions.value = fields
  researchDirectionOptions.value = directions
  openBatches.value = batches
}

async function loadProjects() {
  loading.value = true
  try {
    const query = buildProjectQuery()
    const result = await api(`/projects${query}`)
    projects.value = result.data || result
    pagination.current_page = result.current_page || 1
    pagination.per_page = result.per_page || 20
    pagination.total = result.total || projects.value.length
  } finally {
    loading.value = false
  }
}

function buildProjectQuery() {
  const params = new URLSearchParams()
  if (status.value) params.set('status', status.value)
  if (keyword.value) params.set('keyword', keyword.value)
  if (category.value) params.set('category', category.value)
  if (projectType.value) params.set('project_type', projectType.value)
  if (applicationBatchId.value) params.set('application_batch_id', applicationBatchId.value)
  if (route.query.unit_id) params.set('unit_id', route.query.unit_id)
  if (canFilterE2e.value && e2eFilter.value !== '') params.set('e2e', e2eFilter.value)
  if (pendingExtensionOnly.value) params.set('pending_extension', '1')
  if (pagination.current_page > 1) params.set('page', pagination.current_page)
  return params.toString() ? `?${params.toString()}` : ''
}

function applyRouteQuery() {
  status.value = typeof route.query.status === 'string' ? route.query.status : ''
  keyword.value = typeof route.query.keyword === 'string' ? route.query.keyword : ''
  category.value = typeof route.query.category === 'string' ? route.query.category : ''
  projectType.value = typeof route.query.project_type === 'string' ? route.query.project_type : ''
  const batchId = route.query.application_batch_id || route.query.batch_id
  applicationBatchId.value = batchId ? Number(batchId) : ''
  e2eFilter.value = canFilterE2e.value && typeof route.query.e2e === 'string' ? route.query.e2e : ''
  pendingExtensionOnly.value = route.query.pending_extension === '1'
  pagination.current_page = route.query.page ? Number(route.query.page) || 1 : 1
}

async function syncRouteQuery() {
  const query = { ...route.query }
  const setOrDelete = (key, value) => {
    if (value === '' || value === null || value === undefined || value === false) delete query[key]
    else query[key] = String(value)
  }

  setOrDelete('status', status.value)
  setOrDelete('keyword', keyword.value)
  setOrDelete('category', category.value)
  setOrDelete('project_type', projectType.value)
  setOrDelete('application_batch_id', applicationBatchId.value)
  if (canFilterE2e.value) setOrDelete('e2e', e2eFilter.value)
  else delete query.e2e
  setOrDelete('pending_extension', pendingExtensionOnly.value ? '1' : '')
  setOrDelete('page', pagination.current_page > 1 ? pagination.current_page : '')
  delete query.project_id

  const current = JSON.stringify(route.query)
  const next = JSON.stringify(query)
  if (current === next) return false

  await router.replace({ path: route.path, query })
  return true
}

async function openRouteProject() {
  if (route.query.project_id) {
    await openDetail({ id: route.query.project_id })
  }
}

async function reloadProjects() {
  pagination.current_page = 1
  const routeChanged = await syncRouteQuery()
  if (routeChanged) return
  await loadProjects()
}

async function changePage(page) {
  pagination.current_page = page
  const routeChanged = await syncRouteQuery()
  if (routeChanged) return
  await loadProjects()
}

async function openCreate() {
  if (!projectTypeOptions.value.length && !projectCategoryOptions.value.length) await loadDictionaries()
  editingProject.value = null
  resetForm()
  dialogVisible.value = true
}

async function openEdit(row) {
  if (!projectTypeOptions.value.length && !projectCategoryOptions.value.length) await loadDictionaries()
  const project = row.files ? row : await api(`/projects/${row.id}`)
  editingProject.value = project
  projectFormTab.value = 'basic'
  applyProjectToForm(project)
  dialogVisible.value = true
}

async function openWorkbenchFiles(row) {
  await openEdit(row)
  projectFormTab.value = 'files'
}

async function saveProject() {
  if (!unitCanWriteProjects.value) {
    ElMessage.error('单位已停用，无法维护申报项目')
    return null
  }

  if (!validateProjectDraft()) return null

  saving.value = true
  try {
    const wasEditing = Boolean(editingProject.value)
    const path = editingProject.value ? `/projects/${editingProject.value.id}` : '/projects'
    const method = editingProject.value ? 'PUT' : 'POST'
    const saved = await api(path, { method, body: JSON.stringify(projectPayload()) })
    const fullProject = await api(`/projects/${saved.id}`)
    editingProject.value = fullProject
    applyProjectToForm(fullProject)
    ElMessage.success(wasEditing ? '项目已保存，可继续完善材料' : '项目草稿已创建，可继续上传附件')
    await loadProjects()
    if (detail.value?.id === fullProject.id) detail.value = fullProject
    return fullProject
  } catch (err) {
    showActionError(err, '项目保存失败')
    return null
  } finally {
    saving.value = false
  }
}

async function saveAndSubmitProject() {
  const saved = await saveProject()
  if (!saved) return
  await submitProject(saved)
}

async function submitProject(row) {
  if (!unitCanWriteProjects.value) {
    ElMessage.error('单位已停用，无法提交项目')
    return
  }

  try {
    await ElMessageBox.confirm('提交后将进入区县审核，确认提交？', '提交项目', { type: 'warning' })
    await api(`/projects/${row.id}/submit`, { method: 'POST' })
    ElMessage.success('项目已提交审核')
    if (editingProject.value?.id === row.id) {
      editingProject.value = await api(`/projects/${row.id}`)
      dialogVisible.value = false
    }
    await loadProjects()
  } catch (err) {
    showActionError(err, '项目提交失败')
  }
}

async function withdrawProject(row) {
  if (!unitCanWriteProjects.value) {
    ElMessage.error('单位已停用，无法撤回项目')
    return
  }

  try {
    await ElMessageBox.confirm('确认撤回该项目？', '撤回项目', { type: 'warning' })
    await api(`/projects/${row.id}/withdraw`, { method: 'POST' })
    ElMessage.success('项目已撤回')
    await loadProjects()
  } catch (err) {
    showActionError(err, '项目撤回失败')
  }
}

async function deleteProject(row) {
  if (!unitCanWriteProjects.value) {
    ElMessage.error('单位已停用，无法删除项目')
    return
  }

  try {
    await ElMessageBox.confirm('草稿删除后不可恢复，确认删除？', '删除项目', { type: 'warning' })
    await api(`/projects/${row.id}`, { method: 'DELETE' })
    ElMessage.success('项目已删除')
    await loadProjects()
  } catch (err) {
    showActionError(err, '项目删除失败')
  }
}

async function enterAcceptance(row) {
  try {
    await ElMessageBox.confirm('确认将项目转入验收阶段？', '进入验收', { type: 'warning' })
    await api(`/projects/${row.id}/enter-acceptance`, { method: 'POST' })
    ElMessage.success('项目已进入验收')
    await loadProjects()
  } catch (err) {
    showActionError(err, '进入验收失败')
  }
}

function openExtension(row) {
  if (!unitCanWriteProjects.value) {
    ElMessage.error('单位已停用，无法申请延期')
    return
  }

  actionProject.value = row
  Object.assign(extensionForm, { reason: '', expected_date: '' })
  extensionVisible.value = true
}

async function requestExtension() {
  saving.value = true
  try {
    await api(`/projects/${actionProject.value.id}/extension`, { method: 'POST', body: JSON.stringify(extensionForm) })
    ElMessage.success('延期申请已提交')
    extensionVisible.value = false
    await loadProjects()
  } catch (err) {
    showActionError(err, '延期申请提交失败')
  } finally {
    saving.value = false
  }
}

async function reviewExtension(index, decision) {
  const label = decision === 'approved' ? '通过' : '驳回'
  try {
    const { value: comment } = await ElMessageBox.prompt('请输入处理意见', `${label}延期申请`, {
      inputType: 'textarea',
      inputPlaceholder: '处理意见',
      confirmButtonText: label,
      cancelButtonText: '取消'
    })

    await api(`/projects/${detail.value.id}/extension/${index}/review`, {
      method: 'POST',
      body: JSON.stringify({ decision, comment })
    })
    ElMessage.success(`延期申请已${label}`)
    await openDetail(detail.value)
    await loadProjects()
  } catch (err) {
    showActionError(err, '延期申请处理失败')
  }
}

function openClose(row) {
  actionProject.value = row
  Object.assign(closeForm, { comment: '' })
  closeVisible.value = true
}

async function closeProject() {
  saving.value = true
  try {
    await api(`/projects/${actionProject.value.id}/close`, { method: 'POST', body: JSON.stringify(closeForm) })
    ElMessage.success('项目验收已关闭')
    closeVisible.value = false
    await loadProjects()
  } catch (err) {
    showActionError(err, '关闭验收失败')
  } finally {
    saving.value = false
  }
}

async function openDetail(row) {
  try {
    detail.value = await api(`/projects/${row.id}`)
    detailVisible.value = true
  } catch (err) {
    showActionError(err, '项目详情加载失败')
  }
}

function openReviewResults(row) {
  router.push(`/reviews?tab=results&project_id=${row.id}`)
}

function openLifecycle(row) {
  router.push(`/lifecycle?project_id=${row.id}`)
}

function openProjectLogs(row) {
  router.push(`/operation-logs?target_type=${encodeURIComponent('App\\Models\\Project')}&target_id=${row.id}`)
}

function openFileLogs(row) {
  router.push(`/operation-logs?target_type=${encodeURIComponent('App\\Models\\ProjectFile')}&target_id=${row.id}`)
}

async function uploadFileFromWorkbench({ file }) {
  if (!editingProject.value?.id) {
    ElMessage.warning('请先保存草稿，再上传附件')
    projectFormTab.value = 'basic'
    return
  }

  if (!unitCanWriteProjects.value) {
    ElMessage.error('单位已停用，无法上传附件')
    return
  }

  try {
    const body = new FormData()
    body.append('file', file)
    await api(`/projects/${editingProject.value.id}/files`, { method: 'POST', body })
    editingProject.value = await api(`/projects/${editingProject.value.id}`)
    ElMessage.success('附件已上传')
    if (detail.value?.id === editingProject.value.id) detail.value = editingProject.value
  } catch (err) {
    showActionError(err, '附件上传失败')
  }
}

async function exportProjects() {
  const params = new URLSearchParams()
  if (status.value) params.set('status', status.value)
  if (keyword.value) params.set('keyword', keyword.value)
  if (category.value) params.set('category', category.value)
  if (projectType.value) params.set('project_type', projectType.value)
  if (applicationBatchId.value) params.set('application_batch_id', applicationBatchId.value)
  if (canFilterE2e.value && e2eFilter.value !== '') params.set('e2e', e2eFilter.value)
  if (pendingExtensionOnly.value) params.set('pending_extension', '1')
  const query = params.toString() ? `?${params.toString()}` : ''
  try {
    await downloadApi(`/projects/export.csv${query}`, `projects-${new Date().toISOString().slice(0, 10)}.csv`)
  } catch (err) {
    ElMessage.error(err.message || '项目导出失败')
  }
}

async function downloadFile(row) {
  try {
    await downloadApi(`/files/${row.id}/download`, row.original_name || 'download')
  } catch (err) {
    ElMessage.error(err.message || '附件下载失败')
  }
}

async function deleteFile(row) {
  if (!unitCanWriteProjects.value) {
    ElMessage.error('单位已停用，无法删除附件')
    return
  }

  try {
    await ElMessageBox.confirm('确认删除该附件？', '删除附件', { type: 'warning' })
    await api(`/files/${row.id}`, { method: 'DELETE' })
    ElMessage.success('附件已删除')
    if (detail.value) await openDetail(detail.value)
  } catch (err) {
    showActionError(err, '附件删除失败')
  }
}

async function deleteWorkbenchFile(row) {
  if (!editingProject.value?.id) return

  if (!unitCanWriteProjects.value) {
    ElMessage.error('单位已停用，无法删除附件')
    return
  }

  try {
    await ElMessageBox.confirm('确认删除该附件？', '删除附件', { type: 'warning' })
    await api(`/files/${row.id}`, { method: 'DELETE' })
    editingProject.value = await api(`/projects/${editingProject.value.id}`)
    ElMessage.success('附件已删除')
    if (detail.value?.id === editingProject.value.id) detail.value = editingProject.value
  } catch (err) {
    showActionError(err, '附件删除失败')
  }
}

function formatCurrency(value) {
  if (value === null || value === undefined || value === '') return '-'
  const amount = Number(value)
  if (Number.isNaN(amount)) return `${value} 元`
  return `${amount.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} 元`
}

function formatNumber(value) {
  if (value === null || value === undefined || value === '') return '-'
  const number = Number(value)
  if (Number.isNaN(number)) return value
  return number.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

function detailDateRange(metadata) {
  if (metadata.start_date && metadata.end_date) return `${metadata.start_date} 至 ${metadata.end_date}`
  return metadata.start_date || metadata.end_date || '-'
}

function finalSupportText(project) {
  const support = project?.metadata?.final_support || {}
  const isSupported = support.is_supported === undefined || support.is_supported === null
    ? '-'
    : (support.is_supported ? supportTypeLabel(support.support_type) : '不支持')
  const supportAmount = support.support_amount_wan === undefined || support.support_amount_wan === null || support.support_amount_wan === ''
    ? '-'
    : `${Number(support.support_amount_wan || 0).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} 万元`
  return {
    isSupported,
    supportAmount,
    recommendedExperts: support.recommended_experts || '-'
  }
}

function supportTypeLabel(value) {
  const labels = {
    subsidy: '补助支持',
    interest: '贴息支持',
    other: '其他支持',
    none: '不支持'
  }
  return labels[value] || '支持'
}

function formatBytes(value) {
  const size = Number(value || 0)
  if (size < 1024) return `${size} B`
  if (size < 1024 * 1024) return `${(size / 1024).toFixed(1)} KB`
  return `${(size / 1024 / 1024).toFixed(1)} MB`
}

function timelineActiveIndex(items) {
  const currentIndex = items.findIndex((item) => item.status === 'current')
  if (currentIndex >= 0) return currentIndex
  const doneIndexes = items.map((item, index) => (item.status === 'done' ? index : -1)).filter((index) => index >= 0)
  return doneIndexes.length ? Math.max(...doneIndexes) + 1 : 0
}

function timelineDescription(item) {
  const parts = []
  if (item.handler) parts.push(item.handler)
  if (item.handled_at) parts.push(item.handled_at)
  if (item.decision) parts.push(decisionLabel(item.decision))
  return parts.join(' / ') || (item.status === 'current' ? '当前待处理' : '待流转')
}

watch(() => route.query, () => {
  applyRouteQuery()
  loadProjects()
}, { deep: true })
watch(() => route.query.project_id, openRouteProject)
onMounted(async () => {
  applyRouteQuery()
  await Promise.all([loadProjects(), loadDictionaries()])
  await openRouteProject()
  window.addEventListener('dictionaries:changed', loadDictionaries)
})

onUnmounted(() => {
  window.removeEventListener('dictionaries:changed', loadDictionaries)
})
</script>

<style scoped>
.project-workbench {
  display: grid;
  gap: 16px;
  min-height: calc(100vh - 190px);
}

.workbench-header {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(260px, 360px);
  gap: 20px;
  align-items: center;
  padding: 16px;
  border: 1px solid #dbe3ef;
  border-radius: 8px;
  background: #f8fafc;
}

.workbench-header strong {
  display: block;
  color: #0f172a;
  font-size: 18px;
  line-height: 1.4;
}

.workbench-header span {
  display: block;
  margin-top: 6px;
  color: #64748b;
  font-size: 13px;
}

.workbench-progress {
  display: grid;
  gap: 6px;
}

.workbench-progress span {
  margin: 0;
  text-align: right;
}

.batch-hint {
  border-radius: 8px;
}

.project-form-tabs {
  min-height: 560px;
}

.project-form-tabs :deep(.el-tabs__content) {
  min-width: 0;
  padding-left: 16px;
}

.project-form-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(260px, 1fr));
  gap: 14px 18px;
}

.project-form-stack {
  display: grid;
  gap: 14px;
}

.project-form-grid :deep(.el-form-item) {
  margin-bottom: 0;
}

.project-form-grid :deep(.el-input-number),
.project-form-grid :deep(.el-select),
.project-form-grid :deep(.el-date-editor) {
  width: 100%;
}

.span-2 {
  grid-column: 1 / -1;
}

.form-section-title,
.table-section-title {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  color: #0f172a;
}

.form-section-title {
  padding: 4px 0 2px;
  font-weight: 600;
}

.table-section-title {
  margin: 8px 0 12px;
}

.table-section-title span {
  margin-left: 10px;
  color: #64748b;
  font-size: 13px;
  font-weight: 400;
}

.workbench-footer {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
}

.compact-upload {
  margin: 12px 0;
}

.table-action-row {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.table-action-row :deep(.el-button + .el-button) {
  margin-left: 0;
}

.budget-input-row {
  display: flex;
  align-items: center;
  gap: 8px;
}

.input-unit {
  color: #334155;
  font-size: 14px;
}

@media (max-width: 900px) {
  .workbench-header,
  .project-form-grid {
    grid-template-columns: 1fr;
  }

  .project-form-tabs {
    min-height: auto;
  }

  .project-form-tabs :deep(.el-tabs__header) {
    width: 112px;
  }

  .project-form-tabs :deep(.el-tabs__content) {
    padding-left: 10px;
  }
}
</style>
