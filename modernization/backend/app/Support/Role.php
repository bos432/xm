<?php

namespace App\Support;

use App\Models\RbacRole;
use App\Models\User;
use Illuminate\Support\Facades\Schema;

final class Role
{
    public const SUPER_ADMIN = 'super_admin';
    public const ADMIN = 'admin';
    public const UNIT = 'unit';
    public const COUNTY = 'county';
    public const DEPARTMENT = 'department';
    public const EXPERT = 'expert';

    public static function builtInRoles(): array
    {
        return [
            self::SUPER_ADMIN => '超级管理员',
            self::ADMIN => '业务管理员',
            self::UNIT => '申报单位',
            self::COUNTY => '区县审核',
            self::DEPARTMENT => '部门审核',
            self::EXPERT => '专家评审',
        ];
    }

    public static function adminRoles(): array
    {
        return [self::SUPER_ADMIN, self::ADMIN];
    }

    public static function reviewerRoles(): array
    {
        return [self::COUNTY, self::DEPARTMENT, self::EXPERT, self::ADMIN, self::SUPER_ADMIN];
    }

    public static function reviewerStageFor(string $role): string
    {
        return $role === self::SUPER_ADMIN ? self::ADMIN : $role;
    }

    public static function canManageSettings(string $role): bool
    {
        return in_array($role, self::adminRoles(), true);
    }

    public static function canManageSensitiveSettings(string $role): bool
    {
        return $role === self::SUPER_ADMIN;
    }

    public static function canManageBusiness(string $role): bool
    {
        return in_array($role, self::adminRoles(), true);
    }

    public static function permissionsCatalog(): array
    {
        return [
            ['code' => 'view_dashboard', 'name' => '运行概览', 'group' => '通用'],
            ['code' => 'view_messages', 'name' => '站内消息', 'group' => '通用'],
            ['code' => 'view_projects', 'name' => '查看项目', 'group' => '项目'],
            ['code' => 'project.view_detail', 'name' => '查看项目详情', 'group' => '项目'],
            ['code' => 'project.view_timeline', 'name' => '查看项目阶段条', 'group' => '项目'],
            ['code' => 'project.update', 'name' => '编辑项目', 'group' => '项目'],
            ['code' => 'project.delete', 'name' => '删除项目', 'group' => '项目'],
            ['code' => 'create_projects', 'name' => '创建项目', 'group' => '项目'],
            ['code' => 'submit_projects', 'name' => '提交项目', 'group' => '项目'],
            ['code' => 'upload_project_files', 'name' => '上传项目附件', 'group' => '项目'],
            ['code' => 'review_projects', 'name' => '项目审核', 'group' => '项目'],
            ['code' => 'manage_dispatch_rules', 'name' => '派单规则', 'group' => '项目'],
            ['code' => 'manage_units', 'name' => '单位管理', 'group' => '组织'],
            ['code' => 'manage_users', 'name' => '账号管理', 'group' => '组织'],
            ['code' => 'view_own_unit', 'name' => '单位资料', 'group' => '组织'],
            ['code' => 'manage_application_batches', 'name' => '申报批次', 'group' => '项目'],
            ['code' => 'manage_acceptance', 'name' => '验收管理', 'group' => '验收'],
            ['code' => 'submit_acceptance', 'name' => '提交验收', 'group' => '验收'],
            ['code' => 'review_acceptance', 'name' => '验收审核', 'group' => '验收'],
            ['code' => 'acceptance.view_pending', 'name' => '查看待处理验收', 'group' => '验收'],
            ['code' => 'acceptance.view_reviewed', 'name' => '查看已处理验收', 'group' => '验收'],
            ['code' => 'acceptance.review', 'name' => '处理验收审核', 'group' => '验收'],
            ['code' => 'view_lifecycle', 'name' => '查看全周期', 'group' => '全周期'],
            ['code' => 'view_task_books', 'name' => '查看合同任务书', 'group' => '全周期'],
            ['code' => 'create_task_books', 'name' => '新增合同任务书', 'group' => '全周期'],
            ['code' => 'update_task_books', 'name' => '编辑合同任务书', 'group' => '全周期'],
            ['code' => 'submit_task_books', 'name' => '提交合同任务书', 'group' => '全周期'],
            ['code' => 'review_task_books', 'name' => '审核合同任务书', 'group' => '全周期'],
            ['code' => 'view_project_progress', 'name' => '查看实施进展', 'group' => '全周期'],
            ['code' => 'create_project_progress', 'name' => '新增实施进展', 'group' => '全周期'],
            ['code' => 'update_project_progress', 'name' => '编辑实施进展', 'group' => '全周期'],
            ['code' => 'submit_project_progress', 'name' => '提交实施进展', 'group' => '全周期'],
            ['code' => 'review_project_progress', 'name' => '审核实施进展', 'group' => '全周期'],
            ['code' => 'view_rectifications', 'name' => '查看整改闭环', 'group' => '全周期'],
            ['code' => 'create_rectifications', 'name' => '发起整改要求', 'group' => '全周期'],
            ['code' => 'submit_rectifications', 'name' => '提交整改材料', 'group' => '全周期'],
            ['code' => 'review_rectifications', 'name' => '审核整改闭环', 'group' => '全周期'],
            ['code' => 'view_expert_certifications', 'name' => '查看专家认证', 'group' => '全周期'],
            ['code' => 'submit_expert_certifications', 'name' => '提交专家认证', 'group' => '全周期'],
            ['code' => 'review_expert_certifications', 'name' => '审核专家认证', 'group' => '全周期'],
            ['code' => 'manage_home_content', 'name' => '首页内容', 'group' => '门户'],
            ['code' => 'manage_home_assets', 'name' => '首页素材', 'group' => '门户'],
            ['code' => 'public_home.manage_assets', 'name' => '首页素材维护', 'group' => '门户'],
            ['code' => 'manage_dictionaries', 'name' => '数据字典', 'group' => '系统'],
            ['code' => 'manage_system_texts', 'name' => '系统文案', 'group' => '高风险'],
            ['code' => 'view_migration', 'name' => '迁移准备', 'group' => '系统'],
            ['code' => 'view_operation_logs', 'name' => '操作日志', 'group' => '系统'],
            ['code' => 'manage_settings', 'name' => '系统配置', 'group' => '高风险'],
            ['code' => 'settings.manage_smtp', 'name' => 'SMTP 配置', 'group' => '高风险'],
            ['code' => 'manage_mail', 'name' => '邮件中心', 'group' => '高风险'],
            ['code' => 'manage_roles', 'name' => '角色权限', 'group' => '高风险'],
            ['code' => 'manage_security', 'name' => '安全中心', 'group' => '高风险'],
            ['code' => 'security.manage_whitelist', 'name' => '登录/IP 白名单', 'group' => '高风险'],
            ['code' => 'system_text.manage', 'name' => '系统文案维护', 'group' => '高风险'],
        ];
    }

    public static function builtInCapabilities(string $role): array
    {
        $common = [
            'view_dashboard',
            'view_messages',
        ];

        $adminBusiness = [
            'view_projects',
            'project.view_detail',
            'project.view_timeline',
            'project.update',
            'project.delete',
            'review_projects',
            'manage_units',
            'manage_users',
            'manage_application_batches',
            'manage_dispatch_rules',
            'manage_acceptance',
            'review_acceptance',
            'acceptance.view_pending',
            'acceptance.view_reviewed',
            'acceptance.review',
            'view_lifecycle',
            'view_task_books',
            'review_task_books',
            'view_project_progress',
            'review_project_progress',
            'view_rectifications',
            'create_rectifications',
            'review_rectifications',
            'view_expert_certifications',
            'review_expert_certifications',
            'view_operation_logs',
            'manage_home_content',
            'manage_dictionaries',
        ];

        $byRole = match ($role) {
            self::SUPER_ADMIN => [
                ...$adminBusiness,
                'manage_home_assets',
                'public_home.manage_assets',
                'manage_settings',
                'manage_mail',
                'settings.manage_smtp',
                'manage_roles',
                'manage_security',
                'security.manage_whitelist',
                'manage_system_texts',
                'system_text.manage',
                'view_migration',
            ],
            self::ADMIN => $adminBusiness,
            self::COUNTY, self::DEPARTMENT, self::EXPERT => [
                'view_projects',
                'project.view_detail',
                'project.view_timeline',
                'review_projects',
                'review_acceptance',
                'acceptance.view_pending',
                'acceptance.view_reviewed',
                'acceptance.review',
                'view_lifecycle',
                'view_task_books',
                'view_project_progress',
                'view_rectifications',
                'view_expert_certifications',
            ],
            self::UNIT => [
                'view_projects',
                'project.view_detail',
                'project.view_timeline',
                'project.update',
                'project.delete',
                'view_own_unit',
                'create_projects',
                'submit_projects',
                'upload_project_files',
                'submit_acceptance',
                'view_lifecycle',
                'view_task_books',
                'create_task_books',
                'update_task_books',
                'submit_task_books',
                'view_project_progress',
                'create_project_progress',
                'update_project_progress',
                'submit_project_progress',
                'view_rectifications',
                'submit_rectifications',
                'view_expert_certifications',
            ],
            default => [],
        };

        if ($role === self::EXPERT) {
            $byRole[] = 'view_expert_certifications';
            $byRole[] = 'submit_expert_certifications';
        }

        return array_values(array_unique([...$common, ...$byRole]));
    }

    public static function capabilities(string $role): array
    {
        $databasePermissions = self::databaseCapabilities([$role]);

        return $databasePermissions ?: self::builtInCapabilities($role);
    }

    public static function capabilitiesForUser(User $user): array
    {
        $codes = [$user->role];

        if ($user->relationLoaded('additionalRoles')) {
            $codes = [
                ...$codes,
                ...$user->additionalRoles
                    ->where('is_active', true)
                    ->pluck('code')
                    ->all(),
            ];
        } elseif (Schema::hasTable('role_user') && Schema::hasTable('roles')) {
            $codes = [
                ...$codes,
                ...$user->additionalRoles()
                    ->where('is_active', true)
                    ->pluck('code')
                    ->all(),
            ];
        }

        $databasePermissions = self::databaseCapabilities($codes);
        $fallback = collect($codes)
            ->flatMap(fn (string $role) => self::builtInCapabilities($role))
            ->all();

        return array_values(array_unique([...$fallback, ...$databasePermissions]));
    }

    public static function userCan(User $user, string $permission): bool
    {
        return in_array($permission, self::capabilitiesForUser($user), true);
    }

    public static function menus(string $role): array
    {
        return self::menusFromCapabilities(self::capabilities($role));
    }

    public static function menusForUser(User $user): array
    {
        return self::menusFromCapabilities(self::capabilitiesForUser($user));
    }

    public static function profile(User|string $userOrRole): array
    {
        if ($userOrRole instanceof User) {
            return [
                'role' => $userOrRole->role,
                'permissions' => self::capabilitiesForUser($userOrRole),
                'menus' => self::menusForUser($userOrRole),
            ];
        }

        return [
            'role' => $userOrRole,
            'permissions' => self::capabilities($userOrRole),
            'menus' => self::menus($userOrRole),
        ];
    }

    private static function menusFromCapabilities(array $capabilities): array
    {
        $menus = [
            ['key' => 'dashboard', 'path' => '/dashboard', 'label' => '运行概览', 'permission' => 'view_dashboard'],
            ['key' => 'projects', 'path' => '/projects', 'label' => '项目申报', 'permission' => 'view_projects'],
            ['key' => 'application_batches', 'path' => '/application-batches', 'label' => '申报批次', 'permission' => 'manage_application_batches'],
            ['key' => 'acceptance', 'path' => '/acceptance', 'label' => '验收管理', 'permission' => 'submit_acceptance'],
            ['key' => 'acceptance_admin', 'path' => '/acceptance', 'label' => '验收管理', 'permission' => 'manage_acceptance'],
            ['key' => 'acceptance_review', 'path' => '/acceptance?scope=pending', 'label' => '验收管理', 'permission' => 'review_acceptance'],
            ['key' => 'lifecycle', 'path' => '/lifecycle', 'label' => '全周期管理', 'permission' => 'view_lifecycle'],
            ['key' => 'units', 'path' => '/units', 'label' => '单位管理', 'permission' => 'manage_units'],
            ['key' => 'users', 'path' => '/users', 'label' => '账号管理', 'permission' => 'manage_users'],
            ['key' => 'unit_profile', 'path' => '/unit-profile', 'label' => '单位资料', 'permission' => 'view_own_unit'],
            ['key' => 'reviews', 'path' => '/reviews', 'label' => '审核任务', 'permission' => 'review_projects'],
            ['key' => 'dispatch_rules', 'path' => '/review-dispatch-rules', 'label' => '派单规则', 'permission' => 'manage_dispatch_rules'],
            ['key' => 'messages', 'path' => '/messages', 'label' => '站内消息', 'permission' => 'view_messages'],
            ['key' => 'public_home', 'path' => '/public-home', 'label' => '首页管理', 'permission' => 'manage_home_content'],
            ['key' => 'mail_center', 'path' => '/mail-center', 'label' => '邮件中心', 'permission' => 'manage_mail'],
            ['key' => 'roles', 'path' => '/roles', 'label' => '角色权限', 'permission' => 'manage_roles'],
            ['key' => 'security', 'path' => '/security', 'label' => '安全中心', 'permission' => 'manage_security'],
            ['key' => 'dictionary_items', 'path' => '/dictionary-items', 'label' => '数据字典', 'permission' => 'manage_dictionaries'],
            ['key' => 'system_texts', 'path' => '/system-texts', 'label' => '系统文案', 'permission' => 'manage_system_texts'],
            ['key' => 'settings', 'path' => '/settings', 'label' => '系统配置', 'permission' => 'manage_settings'],
            ['key' => 'migration', 'path' => '/migration', 'label' => '迁移准备', 'permission' => 'view_migration'],
            ['key' => 'operation_logs', 'path' => '/operation-logs', 'label' => '操作日志', 'permission' => 'view_operation_logs'],
        ];

        $seenPaths = [];

        return array_values(array_filter($menus, function (array $menu) use ($capabilities, &$seenPaths): bool {
            if (! in_array($menu['permission'], $capabilities, true)) {
                return false;
            }

            $basePath = strtok($menu['path'], '?') ?: $menu['path'];
            if (in_array($basePath, $seenPaths, true)) {
                return false;
            }

            $seenPaths[] = $basePath;

            return true;
        }));
    }

    private static function databaseCapabilities(array $roleCodes): array
    {
        if (! Schema::hasTable('roles') || ! Schema::hasTable('permissions')) {
            return [];
        }

        return RbacRole::query()
            ->whereIn('code', array_values(array_unique($roleCodes)))
            ->where('is_active', true)
            ->with('permissions:id,code')
            ->get()
            ->flatMap(fn (RbacRole $role) => $role->permissions->pluck('code'))
            ->unique()
            ->values()
            ->all();
    }
}
