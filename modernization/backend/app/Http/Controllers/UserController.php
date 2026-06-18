<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Support\AuditLogger;
use App\Support\Role;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class UserController extends Controller
{
    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    public function index(Request $request)
    {
        $this->authorizeUserManagement($request);

        $query = User::query()->with('unit')->latest();

        if ($role = $request->query('role')) {
            $query->where('role', $role);
        }

        if ($request->has('is_active') && $request->query('is_active') !== '') {
            $query->where('is_active', $request->boolean('is_active'));
        }

        if ($keyword = $request->query('keyword')) {
            $query->where(function ($query) use ($keyword): void {
                $query->where('name', 'like', '%'.$keyword.'%')
                    ->orWhere('username', 'like', '%'.$keyword.'%')
                    ->orWhere('mobile', 'like', '%'.$keyword.'%')
                    ->orWhere('email', 'like', '%'.$keyword.'%');
            });
        }

        return $query->paginate(20);
    }

    public function store(Request $request)
    {
        $this->authorizeUserManagement($request);

        $data = $this->validatedData($request);
        $user = User::create($data);

        $this->auditLogger->record($request, 'user.created', $user, [
            'username' => $user->username,
            'role' => $user->role,
            'unit_id' => $user->unit_id,
        ]);

        return response()->json($user->load('unit'), 201);
    }

    public function show(Request $request, User $user)
    {
        $this->authorizeUserManagement($request);

        return $user->load('unit');
    }

    public function update(Request $request, User $user)
    {
        $this->authorizeUserManagement($request);

        $data = $this->validatedData($request, $user);
        if (($data['password'] ?? '') === '') {
            unset($data['password']);
        }
        $passwordWillChange = array_key_exists('password', $data);

        $wasActive = $user->is_active;
        $user->update($data);

        $this->auditLogger->record($request, 'user.updated', $user, [
            'username' => $user->username,
            'role' => $user->role,
            'unit_id' => $user->unit_id,
            'is_active' => $user->is_active,
        ]);

        if ($wasActive && ! $user->is_active) {
            $this->revokeTokens($request, $user, 'user_deactivated');
        } elseif ($passwordWillChange) {
            $this->revokeTokens($request, $user, 'password_reset');
        }

        return $user->refresh()->load('unit');
    }

    private function authorizeUserManagement(Request $request): void
    {
        if (! in_array('manage_users', Role::capabilities($request->user()->role), true)) {
            abort(403, '无权维护账号');
        }
    }

    private function validatedData(Request $request, ?User $user = null): array
    {
        $userId = $user?->id ?? 'NULL';

        return $request->validate([
            'name' => ['required', 'string', 'max:100'],
            'username' => ['required', 'string', 'max:100', 'unique:users,username,'.$userId],
            'email' => ['nullable', 'email', 'max:120', 'unique:users,email,'.$userId],
            'mobile' => ['nullable', 'string', 'max:40'],
            'password' => [$user ? 'nullable' : 'required', 'string', 'min:8', 'max:200'],
            'role' => ['required', Rule::in([Role::ADMIN, Role::UNIT, Role::COUNTY, Role::DEPARTMENT, Role::EXPERT])],
            'unit_id' => ['nullable', 'exists:units,id'],
            'is_active' => ['required', 'boolean'],
        ]);
    }

    private function revokeTokens(Request $request, User $user, string $reason): void
    {
        $revokedTokens = $user->tokens()->count();
        $user->tokens()->delete();

        $this->auditLogger->record($request, 'user.tokens_revoked', $user, [
            'username' => $user->username,
            'reason' => $reason,
            'revoked_tokens' => $revokedTokens,
        ]);
    }
}
