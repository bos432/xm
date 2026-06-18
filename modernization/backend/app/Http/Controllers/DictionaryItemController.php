<?php

namespace App\Http\Controllers;

use App\Models\DictionaryItem;
use App\Support\AuditLogger;
use App\Support\Role;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class DictionaryItemController extends Controller
{
    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    public function index(Request $request)
    {
        $this->authorizeDictionaryManagement($request);

        $query = DictionaryItem::query();

        if ($group = $request->query('group')) {
            $query->where('group', $group);
        }

        if ($keyword = $request->query('keyword')) {
            $query->where(function ($query) use ($keyword): void {
                $query->where('code', 'like', '%'.$keyword.'%')
                    ->orWhere('label', 'like', '%'.$keyword.'%');
            });
        }

        return $query->orderBy('group')->orderBy('sort_order')->orderBy('id')->paginate(50);
    }

    public function store(Request $request)
    {
        $this->authorizeDictionaryManagement($request);

        $item = DictionaryItem::create($this->validatedData($request));

        $this->auditLogger->record($request, 'dictionary_item.created', $item, [
            'group' => $item->group,
            'code' => $item->code,
        ]);

        return response()->json($item, 201);
    }

    public function show(Request $request, DictionaryItem $dictionaryItem)
    {
        $this->authorizeDictionaryManagement($request);

        return $dictionaryItem;
    }

    public function update(Request $request, DictionaryItem $dictionaryItem)
    {
        $this->authorizeDictionaryManagement($request);

        $dictionaryItem->update($this->validatedData($request, $dictionaryItem));

        $this->auditLogger->record($request, 'dictionary_item.updated', $dictionaryItem, [
            'group' => $dictionaryItem->group,
            'code' => $dictionaryItem->code,
            'is_active' => $dictionaryItem->is_active,
        ]);

        return $dictionaryItem->refresh();
    }

    private function authorizeDictionaryManagement(Request $request): void
    {
        if (! Role::canManageSettings($request->user()->role)) {
            abort(403, '无权维护数据字典');
        }
    }

    private function validatedData(Request $request, ?DictionaryItem $item = null): array
    {
        return $request->validate([
            'group' => ['required', 'string', 'max:80'],
            'code' => [
                'required',
                'string',
                'max:100',
                Rule::unique('dictionary_items', 'code')
                    ->where(fn ($query) => $query->where('group', $request->input('group')))
                    ->ignore($item?->id),
            ],
            'label' => ['required', 'string', 'max:200'],
            'sort_order' => ['required', 'integer', 'min:0'],
            'is_active' => ['required', 'boolean'],
            'metadata' => ['nullable', 'array'],
        ]);
    }
}