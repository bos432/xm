<?php

namespace App\Http\Controllers;

use App\Models\Unit;
use App\Support\AuditLogger;
use App\Support\Role;
use Illuminate\Http\Request;

class UnitController extends Controller
{
    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    public function index(Request $request)
    {
        $this->authorizeUnitManagement($request);

        $query = Unit::query()->latest();

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        if ($keyword = $request->query('keyword')) {
            $query->where(function ($query) use ($keyword): void {
                $query->where('name', 'like', '%'.$keyword.'%')
                    ->orWhere('credit_code', 'like', '%'.$keyword.'%')
                    ->orWhere('contact_name', 'like', '%'.$keyword.'%');
            });
        }

        if ($request->boolean('pending_registration')) {
            $query->where('status', 'suspended')
                ->where(function ($query) {
                    $query->where('metadata', 'like', '%"registration_status":"pending"%')
                        ->orWhere('metadata', 'like', '%"registration_status": "pending"%');
                });
        }

        return $query->paginate(20);
    }

    public function me(Request $request)
    {
        if ($request->user()->role !== Role::UNIT || ! $request->user()->unit_id) {
            abort(403, '无权查看单位资料');
        }

        return $request->user()->unit;
    }

    public function store(Request $request)
    {
        $this->authorizeUnitManagement($request);

        $unit = Unit::create($this->validatedData($request));

        $this->auditLogger->record($request, 'unit.created', $unit, [
            'name' => $unit->name,
            'credit_code' => $unit->credit_code,
        ]);

        return response()->json($unit, 201);
    }

    public function show(Request $request, Unit $unit)
    {
        $this->authorizeUnitManagement($request);

        return $unit;
    }

    public function update(Request $request, Unit $unit)
    {
        $this->authorizeUnitManagement($request);

        $wasActive = $unit->status === 'active';
        $data = $this->applyRegistrationReviewState($request, $unit, $this->validatedData($request, $unit));
        $unit->update($data);

        $this->auditLogger->record($request, 'unit.updated', $unit, [
            'name' => $unit->name,
            'credit_code' => $unit->credit_code,
            'status' => $unit->status,
        ]);

        if ($wasActive && $unit->status !== 'active') {
            $this->revokeUnitUserTokens($request, $unit);
        }

        return $unit->refresh();
    }

    private function authorizeUnitManagement(Request $request): void
    {
        if (! in_array('manage_units', Role::capabilities($request->user()->role), true)) {
            abort(403, '无权维护单位资料');
        }
    }

    private function validatedData(Request $request, ?Unit $unit = null): array
    {
        $unitId = $unit?->id ?? 'NULL';

        return $request->validate([
            'name' => ['required', 'string', 'max:200'],
            'credit_code' => ['nullable', 'string', 'max:80', 'unique:units,credit_code,'.$unitId],
            'contact_name' => ['nullable', 'string', 'max:100'],
            'contact_mobile' => ['nullable', 'string', 'max:40'],
            'email' => ['nullable', 'email', 'max:120'],
            'address' => ['nullable', 'string', 'max:500'],
            'region_code' => ['nullable', 'string', 'max:50'],
            'status' => ['required', 'in:active,suspended,archived'],
            'metadata' => ['nullable', 'array'],
        ]);
    }

    private function applyRegistrationReviewState(Request $request, Unit $unit, array $data): array
    {
        if (($data['status'] ?? $unit->status) !== 'active') {
            return $data;
        }

        $metadata = is_array($unit->metadata) ? $unit->metadata : [];
        if (array_key_exists('metadata', $data) && is_array($data['metadata'])) {
            $metadata = array_merge($metadata, $data['metadata']);
        }

        if (($metadata['registration_status'] ?? null) !== 'pending') {
            return $data;
        }

        $metadata['registration_status'] = 'approved';
        $metadata['reviewed_at'] = now()->toDateTimeString();
        $metadata['reviewed_by'] = $request->user()->id;
        $data['metadata'] = $metadata;

        return $data;
    }

    private function revokeUnitUserTokens(Request $request, Unit $unit): void
    {
        $revokedTokens = 0;
        $affectedUsers = 0;

        $unit->users()->each(function ($user) use (&$revokedTokens, &$affectedUsers): void {
            $tokenCount = $user->tokens()->count();
            if ($tokenCount === 0) {
                return;
            }

            $revokedTokens += $tokenCount;
            $affectedUsers++;
            $user->tokens()->delete();
        });

        $this->auditLogger->record($request, 'unit.tokens_revoked', $unit, [
            'name' => $unit->name,
            'reason' => 'unit_deactivated',
            'affected_users' => $affectedUsers,
            'revoked_tokens' => $revokedTokens,
        ]);
    }
}
