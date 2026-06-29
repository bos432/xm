<?php

namespace Database\Seeders;

use App\Models\DictionaryItem;
use App\Models\PublicHomeItem;
use App\Models\PublicHomeSection;
use App\Models\SystemSetting;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
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
                'role' => 'admin',
                'is_active' => true,
            ]
        );

        $settings = [
            ['key' => 'sms.provider', 'value' => '', 'group' => 'sms', 'is_secret' => false, 'description' => '短信供应商标识'],
            ['key' => 'sms.api_key', 'value' => '', 'group' => 'sms', 'is_secret' => true, 'description' => '短信接口密钥'],
            ['key' => 'mail.from_address', 'value' => '', 'group' => 'mail', 'is_secret' => false, 'description' => '系统邮件发件地址'],
            ['key' => 'workflow.default_first_stage', 'value' => 'county', 'group' => 'workflow', 'is_secret' => false, 'description' => '项目提交后的第一审核角色'],
        ];

        foreach ($settings as $setting) {
            SystemSetting::firstOrCreate(['key' => $setting['key']], $setting);
        }

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
            ['group' => 'review_role', 'code' => 'county', 'label' => '区县审核', 'sort_order' => 10],
            ['group' => 'review_role', 'code' => 'department', 'label' => '部门审核', 'sort_order' => 20],
            ['group' => 'review_role', 'code' => 'expert', 'label' => '专家评审', 'sort_order' => 30],
            ['group' => 'review_role', 'code' => 'admin', 'label' => '管理员终审', 'sort_order' => 40],
        ];

        foreach ($dictionaryItems as $item) {
            DictionaryItem::firstOrCreate(['group' => $item['group'], 'code' => $item['code']], $item);
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
