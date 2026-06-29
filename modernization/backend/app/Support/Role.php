<?php

namespace App\Support;

final class Role
{
    public const ADMIN = 'admin';
    public const UNIT = 'unit';
    public const COUNTY = 'county';
    public const DEPARTMENT = 'department';
    public const EXPERT = 'expert';

    public static function reviewerRoles(): array
    {
        return [self::COUNTY, self::DEPARTMENT, self::EXPERT, self::ADMIN];
    }

    public static function canManageSettings(string $role): bool
    {
        return $role === self::ADMIN;
    }

    public static function capabilities(string $role): array
    {
        $common = [
            'view_dashboard',
            'view_messages',
        ];

        $byRole = match ($role) {
            self::ADMIN => [
                'view_projects',
                'review_projects',
                'manage_units',
                'manage_users',
                'view_migration',
                'view_operation_logs',
                'manage_settings',
            ],
            self::COUNTY, self::DEPARTMENT, self::EXPERT => [
                'view_projects',
                'review_projects',
            ],
            self::UNIT => [
                'view_projects',
                'view_own_unit',
                'create_projects',
                'submit_projects',
                'upload_project_files',
            ],
            default => [],
        };

        return array_values(array_unique([...$common, ...$byRole]));
    }

    public static function menus(string $role): array
    {
        $capabilities = self::capabilities($role);
        $menus = [
            ['key' => 'dashboard', 'path' => '/dashboard', 'label' => '运行概览', 'permission' => 'view_dashboard'],
            ['key' => 'projects', 'path' => '/projects', 'label' => '项目申报', 'permission' => 'view_projects'],
            ['key' => 'units', 'path' => '/units', 'label' => '单位管理', 'permission' => 'manage_units'],
            ['key' => 'users', 'path' => '/users', 'label' => '账号管理', 'permission' => 'manage_users'],
            ['key' => 'unit_profile', 'path' => '/unit-profile', 'label' => '单位资料', 'permission' => 'view_own_unit'],
            ['key' => 'reviews', 'path' => '/reviews', 'label' => '审核任务', 'permission' => 'review_projects'],
            ['key' => 'messages', 'path' => '/messages', 'label' => '站内消息', 'permission' => 'view_messages'],
            ['key' => 'migration', 'path' => '/migration', 'label' => '迁移准备', 'permission' => 'view_migration'],
            ['key' => 'operation_logs', 'path' => '/operation-logs', 'label' => '操作日志', 'permission' => 'view_operation_logs'],
            ['key' => 'dictionary_items', 'path' => '/dictionary-items', 'label' => '数据字典', 'permission' => 'manage_settings'],
            ['key' => 'settings', 'path' => '/settings', 'label' => '系统配置', 'permission' => 'manage_settings'],
        ];

        return array_values(array_filter($menus, fn (array $menu) => in_array($menu['permission'], $capabilities, true)));
    }

    public static function profile(string $role): array
    {
        return [
            'role' => $role,
            'permissions' => self::capabilities($role),
            'menus' => self::menus($role),
        ];
    }
}
