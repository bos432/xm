<?php

namespace App\Http\Controllers;

use App\Models\RbacPermission;
use App\Models\RbacRole;
use App\Models\User;
use App\Support\AuditLogger;
use App\Support\Role;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class RbacController extends Controller
{
    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    public function roles(Request $request)
    {
        $this->authorizeManage($request);

        return RbacRole::query()
            ->with('permissions:id,code,name,group')
            ->orderByDesc('is_builtin')
            ->orderBy('id')
            ->get();
    }

    public function storeRole(Request $request)
    {
        $this->authorizeManage($request);

        $role = RbacRole::create($this->validatedRole($request));
        $this->auditLogger->record($request, 'rbac.role_created', $role);

        return response()->json($role->load('permissions'), 201);
    }

    public function updateRole(Request $request, RbacRole $role)
    {
        $this->authorizeManage($request);

        if ($role->code === Role::SUPER_ADMIN && ! $request->boolean('is_active', true)) {
            return response()->json(['message' => '不能停用超级管理员角色'], 422);
        }

        $role->update($this->validatedRole($request, $role));
        $this->auditLogger->record($request, 'rbac.role_updated', $role);

        return $role->refresh()->load('permissions');
    }

    public function permissions(Request $request)
    {
        $this->authorizeManage($request);

        return RbacPermission::query()->orderBy('group')->orderBy('code')->get();
    }

    public function updatePermissions(Request $request, RbacRole $role)
    {
        $this->authorizeManage($request);

        if ($role->code === Role::SUPER_ADMIN) {
            return response()->json(['message' => '超级管理员权限不可被降级'], 422);
        }

        $data = $request->validate([
            'permission_ids' => ['required', 'array'],
            'permission_ids.*' => ['integer', 'exists:permissions,id'],
        ]);

        $role->permissions()->sync($data['permission_ids']);
        $this->auditLogger->record($request, 'rbac.permissions_updated', $role);

        return $role->refresh()->load('permissions');
    }

    public function updateUserRoles(Request $request, User $user)
    {
        $this->authorizeManage($request);

        if ($user->role === Role::SUPER_ADMIN && $user->id !== $request->user()->id) {
            return response()->json(['message' => '不能调整其他超级管理员的附加角色'], 422);
        }

        $data = $request->validate([
            'role_ids' => ['required', 'array'],
            'role_ids.*' => ['integer', 'exists:roles,id'],
        ]);

        $superAdminRoleId = RbacRole::query()->where('code', Role::SUPER_ADMIN)->value('id');
        if ($superAdminRoleId && in_array($superAdminRoleId, $data['role_ids'], true) && $user->role !== Role::SUPER_ADMIN) {
            return response()->json(['message' => '超级管理员不能作为附加角色分配'], 422);
        }

        $sync = collect($data['role_ids'])
            ->mapWithKeys(fn (int $roleId) => [$roleId => ['assigned_by' => $request->user()->id]])
            ->all();
        $user->additionalRoles()->sync($sync);
        $this->auditLogger->record($request, 'rbac.user_roles_updated', $user);

        return $user->refresh()->load(['unit', 'additionalRoles']);
    }

    private function validatedRole(Request $request, ?RbacRole $role = null): array
    {
        $id = $role?->id ?? 'NULL';

        return $request->validate([
            'code' => [
                'required',
                'string',
                'max:80',
                'regex:/^[a-z][a-z0-9_]*$/',
                Rule::unique('roles', 'code')->ignore($id),
            ],
            'name' => ['required', 'string', 'max:120'],
            'description' => ['nullable', 'string', 'max:500'],
            'is_active' => ['required', 'boolean'],
        ]) + ['is_builtin' => $role?->is_builtin ?? false];
    }

    private function authorizeManage(Request $request): void
    {
        if (! Role::userCan($request->user(), 'manage_roles')) {
            abort(403, '无权管理角色权限');
        }
    }
}
