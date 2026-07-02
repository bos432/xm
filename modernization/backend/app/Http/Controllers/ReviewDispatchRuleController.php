<?php

namespace App\Http\Controllers;

use App\Models\ReviewDispatchRule;
use App\Models\User;
use App\Support\AuditLogger;
use App\Support\Role;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ReviewDispatchRuleController extends Controller
{
    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    public function index(Request $request)
    {
        $this->authorizeManage($request);

        $query = ReviewDispatchRule::query()->latest('is_active')->orderBy('priority')->orderByDesc('id');

        if ($request->filled('target_stage')) {
            $query->where('target_stage', $request->query('target_stage'));
        }

        if ($request->has('is_active') && $request->query('is_active') !== '') {
            $query->where('is_active', $request->boolean('is_active'));
        }

        if ($keyword = $request->query('keyword')) {
            $query->where(function ($query) use ($keyword): void {
                $query->where('name', 'like', '%'.$keyword.'%')
                    ->orWhere('remark', 'like', '%'.$keyword.'%');
            });
        }

        return $query->paginate(20)->through(fn (ReviewDispatchRule $rule) => $this->present($rule));
    }

    public function store(Request $request)
    {
        $this->authorizeManage($request);

        $rule = ReviewDispatchRule::create($this->validatedData($request) + [
            'created_by' => $request->user()->id,
            'updated_by' => $request->user()->id,
        ]);

        $this->auditLogger->record($request, 'review_dispatch_rule.created', $rule);

        return response()->json($this->present($rule), 201);
    }

    public function update(Request $request, ReviewDispatchRule $reviewDispatchRule)
    {
        $this->authorizeManage($request);

        $reviewDispatchRule->update($this->validatedData($request) + [
            'updated_by' => $request->user()->id,
        ]);

        $this->auditLogger->record($request, 'review_dispatch_rule.updated', $reviewDispatchRule, [
            'is_active' => $reviewDispatchRule->is_active,
            'auto_assign' => $reviewDispatchRule->auto_assign,
        ]);

        return $this->present($reviewDispatchRule->refresh());
    }

    public function destroy(Request $request, ReviewDispatchRule $reviewDispatchRule)
    {
        $this->authorizeManage($request);

        $reviewDispatchRule->delete();
        $this->auditLogger->record($request, 'review_dispatch_rule.deleted', $reviewDispatchRule);

        return response()->noContent();
    }

    public function users(Request $request)
    {
        $this->authorizeManage($request);

        $roles = collect(explode(',', (string) $request->query('roles', Role::DEPARTMENT.','.Role::EXPERT)))
            ->map(fn (string $role) => trim($role))
            ->filter(fn (string $role) => in_array($role, [Role::DEPARTMENT, Role::EXPERT], true))
            ->values()
            ->all();

        return User::query()
            ->whereIn('role', $roles)
            ->where('is_active', true)
            ->orderBy('role')
            ->orderBy('name')
            ->get(['id', 'name', 'username', 'role'])
            ->map(fn (User $user): array => [
                'id' => $user->id,
                'name' => $user->name,
                'username' => $user->username,
                'role' => $user->role,
            ]);
    }

    private function validatedData(Request $request): array
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:160'],
            'target_stage' => ['required', Rule::in([Role::DEPARTMENT, Role::EXPERT])],
            'management_unit' => ['nullable', 'string', 'max:120'],
            'project_field' => ['nullable', 'string', 'max:120'],
            'research_direction' => ['nullable', 'string', 'max:120'],
            'project_category' => ['nullable', 'string', 'max:120'],
            'project_type' => ['nullable', 'string', 'max:120'],
            'recommended_user_ids' => ['nullable', 'array'],
            'recommended_user_ids.*' => ['integer', 'exists:users,id'],
            'auto_assign' => ['required', 'boolean'],
            'is_active' => ['required', 'boolean'],
            'priority' => ['required', 'integer', 'min:0', 'max:9999'],
            'remark' => ['nullable', 'string', 'max:1000'],
        ]);

        $targetRole = $data['target_stage'];
        $validUserIds = User::query()
            ->whereIn('id', $data['recommended_user_ids'] ?? [])
            ->where('role', $targetRole)
            ->where('is_active', true)
            ->pluck('id')
            ->map(fn ($id) => (int) $id)
            ->all();

        $data['recommended_user_ids'] = $validUserIds;

        return $data;
    }

    private function present(ReviewDispatchRule $rule): array
    {
        $userIds = collect($rule->recommended_user_ids ?: [])->map(fn ($id) => (int) $id)->all();
        $users = $userIds
            ? User::query()->whereIn('id', $userIds)->get(['id', 'name', 'username', 'role'])->keyBy('id')
            : collect();

        return [
            ...$rule->toArray(),
            'recommended_users' => collect($userIds)
                ->map(fn (int $id) => $users->get($id))
                ->filter()
                ->map(fn (User $user) => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'username' => $user->username,
                    'role' => $user->role,
                ])
                ->values()
                ->all(),
        ];
    }

    private function authorizeManage(Request $request): void
    {
        if (! Role::userCan($request->user(), 'manage_dispatch_rules')) {
            abort(403, '无权维护派单规则');
        }
    }
}
