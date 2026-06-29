<?php

namespace App\Http\Controllers;

use App\Models\SystemText;
use App\Support\AuditLogger;
use App\Support\Role;
use App\Support\SystemTextCatalog;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\Rule;

class SystemTextController extends Controller
{
    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    public function publicIndex()
    {
        $texts = SystemTextCatalog::defaults();

        if (! Schema::hasTable('system_texts')) {
            return response()->json(['texts' => $texts]);
        }

        SystemText::query()
            ->get()
            ->each(function (SystemText $text) use (&$texts): void {
                $texts[$text->key] = $text->resolvedValue();
            });

        return response()->json(['texts' => $texts]);
    }

    public function index(Request $request)
    {
        $this->authorizeManage($request);
        $this->syncBuiltInTexts();

        $query = SystemText::query()->with('updater:id,username,name');

        if ($group = $request->query('group')) {
            $query->where('group', $group);
        }

        if ($request->filled('builtin')) {
            $query->where('is_builtin', $request->boolean('builtin'));
        }

        if ($keyword = $request->query('keyword')) {
            $query->where(function ($query) use ($keyword): void {
                $query->where('key', 'like', '%'.$keyword.'%')
                    ->orWhere('label', 'like', '%'.$keyword.'%')
                    ->orWhere('default_value', 'like', '%'.$keyword.'%')
                    ->orWhere('value', 'like', '%'.$keyword.'%');
            });
        }

        return response()->json([
            'data' => $query
                ->orderBy('group')
                ->orderBy('sort_order')
                ->orderBy('id')
                ->paginate(100),
            'groups' => SystemText::query()
                ->select('group')
                ->distinct()
                ->orderBy('group')
                ->pluck('group'),
        ]);
    }

    public function store(Request $request)
    {
        $this->authorizeManage($request);

        $data = $this->validatedData($request);
        $text = SystemText::create($data + [
            'is_builtin' => false,
            'updated_by' => $request->user()->id,
        ]);

        $this->auditLogger->record($request, 'system_text.created', $text, ['key' => $text->key]);

        return response()->json($text, 201);
    }

    public function update(Request $request, SystemText $systemText)
    {
        $this->authorizeManage($request);

        $data = $this->validatedData($request, $systemText);
        if ($systemText->is_builtin) {
            unset($data['key'], $data['default_value'], $data['is_builtin']);
        }

        $systemText->update($data + ['updated_by' => $request->user()->id]);
        $this->auditLogger->record($request, 'system_text.updated', $systemText, [
            'key' => $systemText->key,
            'is_active' => $systemText->is_active,
        ]);

        return $systemText->refresh()->load('updater:id,username,name');
    }

    public function reset(Request $request, SystemText $systemText)
    {
        $this->authorizeManage($request);

        $systemText->update([
            'value' => null,
            'is_active' => true,
            'updated_by' => $request->user()->id,
        ]);

        $this->auditLogger->record($request, 'system_text.reset', $systemText, ['key' => $systemText->key]);

        return $systemText->refresh()->load('updater:id,username,name');
    }

    public function destroy(Request $request, SystemText $systemText)
    {
        $this->authorizeManage($request);

        if ($systemText->is_builtin) {
            return response()->json(['message' => '内置文案不能删除，可隐藏或回滚默认值'], 422);
        }

        $key = $systemText->key;
        $systemText->delete();
        $this->auditLogger->record($request, 'system_text.deleted', null, ['key' => $key]);

        return response()->noContent();
    }

    private function syncBuiltInTexts(): void
    {
        foreach (SystemTextCatalog::items() as $item) {
            SystemText::updateOrCreate(
                ['key' => $item['key']],
                [
                    'group' => $item['group'],
                    'label' => $item['label'],
                    'default_value' => $item['default_value'],
                    'is_builtin' => true,
                    'sort_order' => $item['sort_order'] ?? 0,
                ]
            );
        }
    }

    private function validatedData(Request $request, ?SystemText $text = null): array
    {
        $id = $text?->id ?? 'NULL';

        return $request->validate([
            'key' => [
                'required',
                'string',
                'max:160',
                'regex:/^[A-Za-z][A-Za-z0-9_.-]*$/',
                Rule::unique('system_texts', 'key')->ignore($id),
            ],
            'group' => ['required', 'string', 'max:80'],
            'label' => ['required', 'string', 'max:160'],
            'default_value' => ['nullable', 'string', 'max:20000'],
            'value' => ['nullable', 'string', 'max:20000'],
            'description' => ['nullable', 'string', 'max:2000'],
            'is_active' => ['required', 'boolean'],
            'sort_order' => ['required', 'integer', 'min:0'],
        ]);
    }

    private function authorizeManage(Request $request): void
    {
        if (! Role::userCan($request->user(), 'manage_system_texts')) {
            abort(403, '只有超级管理员可以维护系统文案');
        }
    }
}
