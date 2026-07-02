<?php

namespace Database\Seeders;

use App\Models\DictionaryItem;
use App\Models\ApplicationBatch;
use App\Models\MailTemplate;
use App\Models\PublicHomeItem;
use App\Models\PublicHomeSection;
use App\Models\RbacPermission;
use App\Models\RbacRole;
use App\Models\SystemSetting;
use App\Models\SystemText;
use App\Models\Unit;
use App\Models\User;
use App\Support\Role;
use App\Support\SystemTextCatalog;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $this->seedRolesAndPermissions();
        $this->seedSystemTexts();

        $adminUnit = Unit::firstOrCreate(
            ['name' => '系统管理单位'],
            ['status' => 'active']
        );

        User::firstOrCreate(
            ['username' => 'admin'],
            [
                'unit_id' => $adminUnit->id,
                'name' => '系统管理员',
                'password' => Hash::make('ChangeMe-2026'),
                'role' => Role::SUPER_ADMIN,
                'is_active' => true,
            ]
        );

        User::firstOrCreate(
            ['username' => 'health_check_user'],
            [
                'unit_id' => $adminUnit->id,
                'name' => '部署健康检查账号',
                'email' => 'health_check@example.test',
                'password' => Hash::make('HealthCheck-2026'),
                'role' => Role::UNIT,
                'is_active' => true,
                'metadata' => ['health_check' => true],
            ]
        );

        User::updateOrCreate(
            ['username' => 'e2e_20260702_delivery_admin'],
            [
                'unit_id' => $adminUnit->id,
                'name' => 'E2E-20260702 delivery admin',
                'email' => 'e2e_20260702_delivery_admin@example.test',
                'password' => Hash::make('Test@2026pass'),
                'role' => Role::ADMIN,
                'is_active' => true,
                'metadata' => ['e2e' => true, 'delivery' => true],
            ]
        );

        $settings = [
            ['key' => 'sms.provider', 'value' => '', 'group' => 'sms', 'is_secret' => false, 'description' => '短信供应商标识'],
            ['key' => 'sms.api_key', 'value' => '', 'group' => 'sms', 'is_secret' => true, 'description' => '短信接口密钥'],
            ['key' => 'mail.mailer', 'value' => 'log', 'group' => 'mail', 'is_secret' => false, 'description' => '邮件驱动：smtp/log/array'],
            ['key' => 'mail.host', 'value' => '', 'group' => 'mail', 'is_secret' => false, 'description' => 'SMTP 主机'],
            ['key' => 'mail.port', 'value' => '465', 'group' => 'mail', 'is_secret' => false, 'description' => 'SMTP 端口'],
            ['key' => 'mail.encryption', 'value' => 'ssl', 'group' => 'mail', 'is_secret' => false, 'description' => '加密方式：ssl/tls/空'],
            ['key' => 'mail.username', 'value' => '', 'group' => 'mail', 'is_secret' => false, 'description' => 'SMTP 用户名'],
            ['key' => 'mail.password', 'value' => '', 'group' => 'mail', 'is_secret' => true, 'description' => 'SMTP 密码或授权码'],
            ['key' => 'mail.from_address', 'value' => '', 'group' => 'mail', 'is_secret' => false, 'description' => '发件邮箱地址'],
            ['key' => 'mail.from_name', 'value' => '阿拉善盟科技计划项目管理信息系统', 'group' => 'mail', 'is_secret' => false, 'description' => '发件人名称'],
            ['key' => 'site.name', 'value' => '阿拉善盟科技计划项目管理信息系统', 'group' => 'site', 'is_secret' => false, 'description' => '系统名称'],
            ['key' => 'site.admin_subtitle', 'value' => '科技项目管理后台', 'group' => 'site', 'is_secret' => false, 'description' => '后台副标题'],
            ['key' => 'site.footer_text', 'value' => '阿拉善盟科技计划项目管理信息系统 版权所有', 'group' => 'site', 'is_secret' => false, 'description' => '首页版权/备案文字'],
            ['key' => 'site.app_url_display', 'value' => 'https://nxm.zlck888.com', 'group' => 'site', 'is_secret' => false, 'description' => '后台展示用 APP_URL'],
            ['key' => 'upload.allowed_extensions', 'value' => 'jpg,jpeg,png,pdf,doc,docx,xls,xlsx,zip,webp,svg', 'group' => 'upload', 'is_secret' => false, 'description' => '允许上传扩展名'],
            ['key' => 'upload.max_kb', 'value' => '20480', 'group' => 'upload', 'is_secret' => false, 'description' => '通用上传大小上限 KB'],
            ['key' => 'upload.blocked_extensions', 'value' => 'php,phtml,phar,asp,aspx,jsp,jspx,cer,asa,cdx,war,sh,bat,cmd,ps1,exe,dll,html,js', 'group' => 'upload', 'is_secret' => false, 'description' => '危险扩展名黑名单'],
            ['key' => 'security.login_failure_threshold', 'value' => '5', 'group' => 'security', 'is_secret' => false, 'description' => '登录失败锁定阈值'],
            ['key' => 'security.lock_minutes', 'value' => '30', 'group' => 'security', 'is_secret' => false, 'description' => '达到阈值后的锁定分钟数'],
            ['key' => 'security.ip_whitelist_enabled', 'value' => '0', 'group' => 'security', 'is_secret' => false, 'description' => '是否启用 IP 白名单'],
            ['key' => 'security.ip_blacklist_enabled', 'value' => '1', 'group' => 'security', 'is_secret' => false, 'description' => '是否启用 IP 黑名单'],
            ['key' => 'security.login_throttle_per_minute', 'value' => '5', 'group' => 'security', 'is_secret' => false, 'description' => '登录接口每分钟限制'],
            ['key' => 'security.login_throttle_relaxed', 'value' => '0', 'group' => 'security', 'is_secret' => false, 'description' => '是否临时放宽登录限流'],
            ['key' => 'security.login_throttle_relaxed_per_minute', 'value' => '60', 'group' => 'security', 'is_secret' => false, 'description' => '临时放宽后的每分钟限制'],
            ['key' => 'security.login_throttle_whitelist_ips', 'value' => '', 'group' => 'security', 'is_secret' => false, 'description' => '登录限流测试白名单 IP'],
            ['key' => 'security.login_throttle_relaxed_until', 'value' => '', 'group' => 'security', 'is_secret' => false, 'description' => '登录限流临时放宽截止时间'],
            ['key' => 'security.login_throttle_relaxed_by', 'value' => '', 'group' => 'security', 'is_secret' => false, 'description' => '登录限流临时放宽操作人'],
            ['key' => 'security.login_throttle_relaxed_reason', 'value' => '', 'group' => 'security', 'is_secret' => false, 'description' => '登录限流临时放宽原因'],
            ['key' => 'workflow.default_first_stage', 'value' => 'county', 'group' => 'workflow', 'is_secret' => false, 'description' => '项目提交后的第一审核角色'],
            ['key' => 'review.score_enabled.county', 'value' => '0', 'group' => 'review', 'is_secret' => false, 'description' => '区县审核是否启用评分'],
            ['key' => 'review.score_enabled.department', 'value' => '0', 'group' => 'review', 'is_secret' => false, 'description' => '部门审核是否启用评分'],
            ['key' => 'review.score_enabled.expert', 'value' => '1', 'group' => 'review', 'is_secret' => false, 'description' => '专家评审是否启用评分'],
            ['key' => 'review.score_enabled.admin', 'value' => '0', 'group' => 'review', 'is_secret' => false, 'description' => '管理员终审是否启用评分'],
            ['key' => 'review.expert_assignment.count', 'value' => '3', 'group' => 'review', 'is_secret' => false, 'description' => '专家阶段默认随机抽取人数'],
            ['key' => 'review.expert_assignment.random_enabled', 'value' => '1', 'group' => 'review', 'is_secret' => false, 'description' => '专家阶段是否启用随机专家组'],
        ];

        foreach ($settings as $setting) {
            SystemSetting::firstOrCreate(['key' => $setting['key']], $setting);
        }

        $this->seedApplicationBatches();
        $this->seedMailTemplates();
        SystemSetting::firstOrCreate(
            ['key' => 'public.homepage_content'],
            [
                'value' => json_encode([
                    'nav' => [
                        'title' => '阿拉善盟科技计划项目管理信息系统',
                        'links' => [
                            ['label' => '通知公告', 'href' => '#notices'],
                            ['label' => '服务事项', 'href' => '#services'],
                            ['label' => '资料下载', 'href' => '#downloads'],
                            ['label' => '登录', 'href' => '/login'],
                        ],
                    ],
                    'hero' => [
                        'eyebrow' => '科技计划项目申报服务',
                        'title' => '项目申报、审核、评审与验收一体化办理',
                        'description' => '面向申报单位、归口管理单位、专家和科技管理部门，提供在线申报、材料提交、分级审核、专家评审、验收管理和资料查询服务。',
                        'primary_action' => ['label' => '进入系统', 'href' => '/login'],
                        'secondary_action' => ['label' => '查看通知', 'href' => '#notices'],
                        'status_title' => '2025 年科技计划项目申报',
                        'status_items' => [
                            ['label' => '在线申报', 'value' => '开放'],
                            ['label' => '历史数据', 'value' => '逐步迁移'],
                        ],
                    ],
                    'highlights' => [
                        ['label' => '申报服务', 'value' => '在线受理', 'description' => '企业和单位可在线创建项目、保存草稿、提交材料。'],
                        ['label' => '审核流程', 'value' => '分级办理', 'description' => '归口、部门、专家和管理员按权限流转处理。'],
                        ['label' => '历史查询', 'value' => '逐步迁移', 'description' => '旧系统历史项目将按批次迁移并开放查询。'],
                    ],
                    'notices' => [
                        ['title' => '阿拉善盟科学技术局关于发布2025年阿拉善盟科技计划项目申报指南的通知', 'date' => '2025-04-08', 'summary' => '2025 年阿拉善盟科技计划项目申报指南已发布，请申报单位按指南要求准备项目材料并通过新系统提交。'],
                        ['title' => '关于发布2024年阿拉善盟第一批科技计划项目申报指南的通知', 'date' => '2024-08-30', 'summary' => '2024 年第一批科技计划项目申报工作已启动，项目类别、申报条件和材料清单以通知要求为准。'],
                        ['title' => '关于发布2022年阿拉善盟应用技术研究与开发项目申报指南的通知', 'date' => '2022-03-11', 'summary' => '应用技术研究与开发项目申报材料请按指南规范填写，附件材料应完整、真实、可核验。'],
                        ['title' => '关于发布2021年内蒙古自治区第一批技术攻关类“揭榜挂帅”项目榜单的公告', 'date' => '2021-09-01', 'summary' => '技术攻关类项目榜单已发布，符合条件的单位可按榜单方向组织申报。'],
                    ],
                    'downloads' => [
                        ['title' => '【2023】阿拉善盟科技计划项目申报书', 'date' => '2023-03-20', 'summary' => '项目申报书模板用于填写项目基本信息、建设内容、技术路线、预算和预期成果。'],
                        ['title' => '【2023】承诺书（企业提供）', 'date' => '2023-03-20', 'summary' => '企业申报单位需按要求提交承诺书，并对材料真实性和合规性负责。'],
                        ['title' => '【2023】科研诚信承诺书', 'date' => '2023-03-20', 'summary' => '科研诚信承诺书用于申报主体承诺遵守科研诚信和项目管理要求。'],
                        ['title' => '申报单位填报流程', 'date' => '2022-03-08', 'summary' => '说明申报单位从账号登录、单位资料维护、项目填报到附件提交的操作流程。'],
                    ],
                    'services' => [
                        ['code' => '01', 'title' => '项目申报', 'description' => '支持草稿、提交、撤回、退回修改和附件上传。'],
                        ['code' => '02', 'title' => '单位管理', 'description' => '维护企业和单位基础资料，支撑项目归属和审核。'],
                        ['code' => '03', 'title' => '专家评审', 'description' => '专家按任务查看项目材料，填写意见和评分。'],
                        ['code' => '04', 'title' => '验收延期', 'description' => '项目通过后支持验收流转、延期申请和关闭归档。'],
                    ],
                    'footer' => '阿拉善盟科技计划项目管理信息系统 版权所有',
                ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
                'group' => 'public_home',
                'is_secret' => false,
                'description' => '首页展示内容（导航、横幅、公告、下载、服务事项）',
            ]
        );

        $this->seedPublicHomeContent();

        $dictionaryItems = [
            ['group' => 'project_status', 'code' => 'draft', 'label' => '草稿', 'sort_order' => 10],
            ['group' => 'project_status', 'code' => 'submitted', 'label' => '已提交', 'sort_order' => 20],
            ['group' => 'project_status', 'code' => 'reviewing', 'label' => '审核中', 'sort_order' => 30],
            ['group' => 'project_status', 'code' => 'returned', 'label' => '退回修改', 'sort_order' => 40],
            ['group' => 'project_status', 'code' => 'approved', 'label' => '已通过', 'sort_order' => 50],
            ['group' => 'project_status', 'code' => 'rejected', 'label' => '已驳回', 'sort_order' => 60],
            ['group' => 'project_status', 'code' => 'acceptance', 'label' => '验收中', 'sort_order' => 70],
            ['group' => 'project_status', 'code' => 'closed', 'label' => '已关闭', 'sort_order' => 80],
            ['group' => 'project_category', 'code' => 'technology', 'label' => '科技项目', 'sort_order' => 10],
            ['group' => 'project_category', 'code' => 'industry', 'label' => '产业项目', 'sort_order' => 20],
            ['group' => 'project_category', 'code' => 'service', 'label' => '服务业项目', 'sort_order' => 30],
            ['group' => 'project_type', 'code' => 'key_support', 'label' => '重点扶持', 'sort_order' => 10],
            ['group' => 'project_type', 'code' => 'innovation_demo', 'label' => '创新示范', 'sort_order' => 20],
            ['group' => 'project_type', 'code' => 'transformation', 'label' => '技术改造', 'sort_order' => 30],
            ['group' => 'management_unit', 'code' => 'league_science_department', 'label' => '盟级管理部门', 'sort_order' => 10],
            ['group' => 'management_unit', 'code' => 'county_science_department', 'label' => '旗区科技管理部门', 'sort_order' => 20],
            ['group' => 'management_unit', 'code' => 'industry_authority', 'label' => '行业主管部门', 'sort_order' => 30],
            ['group' => 'project_field', 'code' => 'resource_utilization', 'label' => '资源综合利用', 'sort_order' => 10],
            ['group' => 'project_field', 'code' => 'modern_agriculture', 'label' => '现代农牧业', 'sort_order' => 20],
            ['group' => 'project_field', 'code' => 'ecological_environment', 'label' => '生态环境', 'sort_order' => 30],
            ['group' => 'project_field', 'code' => 'digital_technology', 'label' => '数字技术', 'sort_order' => 40],
            ['group' => 'project_field', 'code' => 'social_development', 'label' => '社会发展', 'sort_order' => 50],
            ['group' => 'research_direction', 'code' => 'mineral_resources', 'label' => '矿产资源开发利用', 'sort_order' => 10],
            ['group' => 'research_direction', 'code' => 'energy_saving', 'label' => '节能降碳与清洁生产', 'sort_order' => 20],
            ['group' => 'research_direction', 'code' => 'achievement_transformation', 'label' => '科技成果转化', 'sort_order' => 30],
            ['group' => 'research_direction', 'code' => 'industrial_upgrade', 'label' => '产业升级与技术改造', 'sort_order' => 40],
            ['group' => 'review_role', 'code' => 'county', 'label' => '区县审核', 'sort_order' => 10],
            ['group' => 'review_role', 'code' => 'department', 'label' => '部门审核', 'sort_order' => 20],
            ['group' => 'review_role', 'code' => 'expert', 'label' => '专家评审', 'sort_order' => 30],
            ['group' => 'review_role', 'code' => 'admin', 'label' => '管理员终审', 'sort_order' => 40],
            ['group' => 'expert_review_criterion', 'code' => 'policy_importance', 'label' => '项目实施的重要性、必要性', 'sort_order' => 20, 'metadata' => ['section' => '政策符合性评价', 'max_score' => 5]],
            ['group' => 'expert_review_criterion', 'code' => 'policy_trend_analysis', 'label' => '对国内外现状及趋势分析是否准确、全面', 'sort_order' => 30, 'metadata' => ['section' => '政策符合性评价', 'max_score' => 5]],
            ['group' => 'expert_review_criterion', 'code' => 'technical_advanced_practical', 'label' => '对研究内容先进性和实用性评价', 'sort_order' => 50, 'metadata' => ['section' => '项目成果及技术水平评价', 'max_score' => 5]],
            ['group' => 'expert_review_criterion', 'code' => 'technical_goals_clear', 'label' => '研究目标是否明确清晰、重点突出', 'sort_order' => 60, 'metadata' => ['section' => '项目成果及技术水平评价', 'max_score' => 10]],
            ['group' => 'expert_review_criterion', 'code' => 'technical_route_feasible', 'label' => '采用的技术路线是否可行、工艺和研究方法是否先进', 'sort_order' => 70, 'metadata' => ['section' => '项目成果及技术水平评价', 'max_score' => 5]],
            ['group' => 'expert_review_criterion', 'code' => 'technical_innovation', 'label' => '采用的技术是否具有创新性', 'sort_order' => 80, 'metadata' => ['section' => '项目成果及技术水平评价', 'max_score' => 5]],
            ['group' => 'expert_review_criterion', 'code' => 'industry_university_research', 'label' => '企业、高校、科研院所等是否开展实质性合作，进行联合科技攻关', 'sort_order' => 100, 'metadata' => ['section' => '产学研合作评价', 'max_score' => 10]],
            ['group' => 'expert_review_criterion', 'code' => 'team_level_division', 'label' => '研发团队整体科研水平及人员分工合理性', 'sort_order' => 120, 'metadata' => ['section' => '项目实施条件评价', 'max_score' => 5]],
            ['group' => 'expert_review_criterion', 'code' => 'leader_research_ability', 'label' => '项目负责人的科研水平及创新能力', 'sort_order' => 130, 'metadata' => ['section' => '项目实施条件评价', 'max_score' => 5]],
            ['group' => 'expert_review_criterion', 'code' => 'unit_management_ability', 'label' => '项目申报单位的组织管理能力和项目组织实施机制', 'sort_order' => 140, 'metadata' => ['section' => '项目实施条件评价', 'max_score' => 5]],
            ['group' => 'expert_review_criterion', 'code' => 'existing_research_foundation', 'label' => '现有研究工作基础及条件', 'sort_order' => 150, 'metadata' => ['section' => '项目实施条件评价', 'max_score' => 5]],
            ['group' => 'expert_review_criterion', 'code' => 'benefit_technical_indicators', 'label' => '项目的技术指标是否明确', 'sort_order' => 170, 'metadata' => ['section' => '项目预期效益评价', 'max_score' => 5]],
            ['group' => 'expert_review_criterion', 'code' => 'benefit_economic', 'label' => '项目的经济效益是否明显，带动当地产业发展情况', 'sort_order' => 180, 'metadata' => ['section' => '项目预期效益评价', 'max_score' => 10]],
            ['group' => 'expert_review_criterion', 'code' => 'benefit_outputs', 'label' => '项目的成果指标是否明显，形成的专利、技术标准和人才培养等情况', 'sort_order' => 190, 'metadata' => ['section' => '项目预期效益评价', 'max_score' => 5]],
            ['group' => 'expert_review_criterion', 'code' => 'benefit_social', 'label' => '项目的社会效益是否明显，科技惠民、节能减排、改善环境等情况', 'sort_order' => 200, 'metadata' => ['section' => '项目预期效益评价', 'max_score' => 5]],
            ['group' => 'expert_review_criterion', 'code' => 'budget_relevance', 'label' => '项目预算是否符合项目实际、项目预算的目标相关性', 'sort_order' => 220, 'metadata' => ['section' => '经费预算', 'max_score' => 5]],
            ['group' => 'expert_review_criterion', 'code' => 'budget_reasonable', 'label' => '项目预算的合理性', 'sort_order' => 230, 'metadata' => ['section' => '经费预算', 'max_score' => 5]],
        ];

        foreach ($dictionaryItems as $item) {
            if ($item['group'] === 'expert_review_criterion') {
                DictionaryItem::updateOrCreate(['group' => $item['group'], 'code' => $item['code']], $item);
            } else {
                DictionaryItem::firstOrCreate(['group' => $item['group'], 'code' => $item['code']], $item);
            }
        }
    }

    private function seedPublicHomeContent(): void
    {
        foreach ($this->publicHomeSections() as $section) {
            PublicHomeSection::firstOrCreate(['key' => $section['key']], $section);
        }

        foreach ($this->publicHomeItems() as $item) {
            PublicHomeItem::firstOrCreate(
                [
                    'section' => $item['section'],
                    'title' => $item['title'] ?? null,
                    'label' => $item['label'] ?? null,
                ],
                $item
            );
        }
    }

    private function seedRolesAndPermissions(): void
    {
        $permissionIds = [];
        foreach (Role::permissionsCatalog() as $permission) {
            $model = RbacPermission::updateOrCreate(
                ['code' => $permission['code']],
                $permission
            );
            $permissionIds[$permission['code']] = $model->id;
        }

        foreach (Role::builtInRoles() as $code => $name) {
            $role = RbacRole::updateOrCreate(
                ['code' => $code],
                [
                    'name' => $name,
                    'is_builtin' => true,
                    'is_active' => true,
                ]
            );

            $ids = collect(Role::builtInCapabilities($code))
                ->map(fn (string $permission) => $permissionIds[$permission] ?? null)
                ->filter()
                ->values()
                ->all();

            $role->permissions()->sync($ids);
        }
    }

    private function seedSystemTexts(): void
    {
        foreach (SystemTextCatalog::items() as $item) {
            $text = SystemText::firstOrCreate(
                ['key' => $item['key']],
                ['is_active' => true] + [
                    'group' => $item['group'],
                    'label' => $item['label'],
                    'default_value' => $item['default_value'],
                    'is_builtin' => true,
                    'sort_order' => $item['sort_order'] ?? 0,
                ]
            );

            $text->update([
                'group' => $item['group'],
                'label' => $item['label'],
                'default_value' => $item['default_value'],
                'is_builtin' => true,
                'sort_order' => $item['sort_order'] ?? 0,
            ]);
        }
    }

    private function seedApplicationBatches(): void
    {
        ApplicationBatch::firstOrCreate(
            ['code' => 'HISTORY-DEFAULT'],
            [
                'name' => '历史默认批次',
                'status' => ApplicationBatch::STATUS_OPEN,
                'starts_at' => now()->subYears(10),
                'ends_at' => now()->addYears(10),
                'guide' => '历史项目自动归集批次，用于兼容迁移前已存在的申报项目。',
                'attachment_requirements' => '沿用原项目材料要求。',
                'metadata' => ['system_default' => true],
            ]
        );
    }

    private function seedMailTemplates(): void
    {
        $templates = [
            ['key' => 'password_reset', 'name' => '找回密码', 'subject' => '项目申报系统密码重置', 'body' => "您正在重置项目申报系统账号密码。\n\n请在 {{ expire_minutes }} 分钟内打开以下链接设置新密码：\n{{ reset_link }}\n\n如果不是本人操作，请忽略本邮件。"],
            ['key' => 'registration_pending', 'name' => '注册待审', 'subject' => '单位注册申请已提交', 'body' => "您的单位注册申请已提交。\n单位：{{ unit_name }}\n账号：{{ username }}\n请等待管理员审核启用。"],
            ['key' => 'registration_result', 'name' => '注册审核结果', 'subject' => '单位注册审核结果', 'body' => "您的单位注册审核结果：{{ result }}。\n{{ comment }}"],
            ['key' => 'project_submitted', 'name' => '项目提交', 'subject' => '项目已提交', 'body' => "项目“{{ project_title }}”已提交，当前阶段：{{ stage }}。"],
            ['key' => 'review_flow', 'name' => '审核流转', 'subject' => '项目审核流转提醒', 'body' => "项目“{{ project_title }}”已流转到 {{ stage }}，请及时处理。"],
            ['key' => 'review_result', 'name' => '审核结果', 'subject' => '项目审核结果', 'body' => "项目“{{ project_title }}”审核结果：{{ decision }}。\n{{ comment }}"],
            ['key' => 'acceptance_submitted', 'name' => '验收提交', 'subject' => '验收申请已提交', 'body' => "项目“{{ project_title }}”已提交验收申请，当前阶段：{{ stage }}。"],
            ['key' => 'acceptance_review', 'name' => '验收审核', 'subject' => '验收审核流转提醒', 'body' => "项目“{{ project_title }}”验收已流转到 {{ stage }}，请及时处理。"],
            ['key' => 'extension_result', 'name' => '延期处理', 'subject' => '延期申请处理结果', 'body' => "项目“{{ project_title }}”延期申请结果：{{ decision }}。\n{{ comment }}"],
            ['key' => 'test_mail', 'name' => '测试邮件', 'subject' => '项目申报系统测试邮件', 'body' => "这是一封测试邮件。\n发送时间：{{ sent_at }}"],
        ];

        foreach ($templates as $template) {
            MailTemplate::updateOrCreate(
                ['key' => $template['key']],
                $template + ['is_active' => true, 'is_builtin' => true]
            );
        }
    }

    private function publicHomeSections(): array
    {
        return [
            [
                'key' => 'nav',
                'title' => '阿拉善盟科技计划项目管理信息系统',
                'is_active' => true,
            ],
            [
                'key' => 'hero',
                'eyebrow' => '科技计划项目申报服务',
                'title' => '项目申报、审核、评审与验收一体化办理',
                'body' => '面向申报单位、归口管理单位、专家和科技管理部门，提供在线申报、材料提交、分级审核、专家评审、验收管理和资料查询服务。',
                'metadata' => [
                    'primary_action' => ['label' => '进入系统', 'href' => '/login'],
                    'secondary_action' => ['label' => '查看通知', 'href' => '#notices'],
                    'status_title' => '2025 年科技计划项目申报',
                ],
                'is_active' => true,
            ],
            [
                'key' => 'footer',
                'body' => '阿拉善盟科技计划项目管理信息系统 版权所有',
                'is_active' => true,
            ],
        ];
    }

    private function publicHomeItems(): array
    {
        return [
            ['section' => 'nav_link', 'label' => '通知公告', 'href' => '#notices', 'sort_order' => 10, 'is_active' => true],
            ['section' => 'nav_link', 'label' => '服务事项', 'href' => '#services', 'sort_order' => 20, 'is_active' => true],
            ['section' => 'nav_link', 'label' => '资料下载', 'href' => '#downloads', 'sort_order' => 30, 'is_active' => true],
            ['section' => 'nav_link', 'label' => '登录', 'href' => '/login', 'sort_order' => 40, 'is_active' => true],
            ['section' => 'hero_status', 'label' => '在线申报', 'value' => '开放', 'sort_order' => 10, 'is_active' => true],
            ['section' => 'hero_status', 'label' => '历史数据', 'value' => '逐步迁移', 'sort_order' => 20, 'is_active' => true],
            ['section' => 'highlight', 'label' => '申报服务', 'value' => '在线受理', 'summary' => '企业和单位可在线创建项目、保存草稿、提交材料。', 'sort_order' => 10, 'is_active' => true],
            ['section' => 'highlight', 'label' => '审核流程', 'value' => '分级办理', 'summary' => '归口、部门、专家和管理员按权限流转处理。', 'sort_order' => 20, 'is_active' => true],
            ['section' => 'highlight', 'label' => '历史查询', 'value' => '逐步迁移', 'summary' => '旧系统历史项目将按批次迁移并开放查询。', 'sort_order' => 30, 'is_active' => true],
            ['section' => 'notice', 'title' => '阿拉善盟科学技术局关于发布2025年阿拉善盟科技计划项目申报指南的通知', 'published_at' => '2025-04-08', 'summary' => '2025 年阿拉善盟科技计划项目申报指南已发布，请申报单位按指南要求准备项目材料并通过新系统提交。', 'sort_order' => 10, 'is_active' => true],
            ['section' => 'notice', 'title' => '关于发布2024年阿拉善盟第一批科技计划项目申报指南的通知', 'published_at' => '2024-08-30', 'summary' => '2024 年第一批科技计划项目申报工作已启动，项目类别、申报条件和材料清单以通知要求为准。', 'sort_order' => 20, 'is_active' => true],
            ['section' => 'notice', 'title' => '关于发布2022年阿拉善盟应用技术研究与开发项目申报指南的通知', 'published_at' => '2022-03-11', 'summary' => '应用技术研究与开发项目申报材料请按指南规范填写，附件材料应完整、真实、可核验。', 'sort_order' => 30, 'is_active' => true],
            ['section' => 'notice', 'title' => '关于发布2021年内蒙古自治区第一批技术攻关类“揭榜挂帅”项目榜单的公告', 'published_at' => '2021-09-01', 'summary' => '技术攻关类项目榜单已发布，符合条件的单位可按榜单方向组织申报。', 'sort_order' => 40, 'is_active' => true],
            ['section' => 'download', 'title' => '【2023】阿拉善盟科技计划项目申报书', 'published_at' => '2023-03-20', 'summary' => '项目申报书模板用于填写项目基本信息、建设内容、技术路线、预算和预期成果。', 'sort_order' => 10, 'is_active' => false, 'metadata' => ['warning' => 'seeded_without_file']],
            ['section' => 'download', 'title' => '【2023】承诺书（企业提供）', 'published_at' => '2023-03-20', 'summary' => '企业申报单位需按要求提交承诺书，并对材料真实性和合规性负责。', 'sort_order' => 20, 'is_active' => false, 'metadata' => ['warning' => 'seeded_without_file']],
            ['section' => 'download', 'title' => '【2023】科研诚信承诺书', 'published_at' => '2023-03-20', 'summary' => '科研诚信承诺书用于申报主体承诺遵守科研诚信和项目管理要求。', 'sort_order' => 30, 'is_active' => false, 'metadata' => ['warning' => 'seeded_without_file']],
            ['section' => 'download', 'title' => '申报单位填报流程', 'published_at' => '2022-03-08', 'summary' => '说明申报单位从账号登录、单位资料维护、项目填报到附件提交的操作流程。', 'sort_order' => 40, 'is_active' => false, 'metadata' => ['warning' => 'seeded_without_file']],
            ['section' => 'service', 'code' => '01', 'title' => '项目申报', 'summary' => '支持草稿、提交、撤回、退回修改和附件上传。', 'sort_order' => 10, 'is_active' => true],
            ['section' => 'service', 'code' => '02', 'title' => '单位管理', 'summary' => '维护企业和单位基础资料，支撑项目归属和审核。', 'sort_order' => 20, 'is_active' => true],
            ['section' => 'service', 'code' => '03', 'title' => '专家评审', 'summary' => '专家按任务查看项目材料，填写意见和评分。', 'sort_order' => 30, 'is_active' => true],
            ['section' => 'service', 'code' => '04', 'title' => '验收延期', 'summary' => '项目通过后支持验收流转、延期申请和关闭归档。', 'sort_order' => 40, 'is_active' => true],
        ];
    }
}
