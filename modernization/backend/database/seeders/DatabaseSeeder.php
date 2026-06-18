<?php

namespace Database\Seeders;

use App\Models\DictionaryItem;
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
}
