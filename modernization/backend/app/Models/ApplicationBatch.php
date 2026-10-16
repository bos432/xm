<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ApplicationBatch extends Model
{
    use HasFactory;

    public const STATUS_DRAFT = 'draft';

    public const STATUS_OPEN = 'open';

    public const STATUS_CLOSED = 'closed';

    public const STATUS_ARCHIVED = 'archived';

    public const HISTORY_DEFAULT_CODE = 'HISTORY-DEFAULT';

    protected $fillable = [
        'name',
        'code',
        'starts_at',
        'ends_at',
        'status',
        'allowed_categories',
        'allowed_project_types',
        'guide',
        'attachment_requirements',
        'metadata',
        'created_by',
    ];

    protected function casts(): array
    {
        return [
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
            'allowed_categories' => 'array',
            'allowed_project_types' => 'array',
            'metadata' => 'array',
        ];
    }

    public function scopeAvailableForNewApplications($query)
    {
        return $query
            ->where('code', '!=', self::HISTORY_DEFAULT_CODE)
            ->where(function ($query): void {
                $query->whereNull('metadata')
                    ->orWhere(function ($query): void {
                        $query->whereNull('metadata->e2e')
                            ->orWhereJsonDoesntContain('metadata->e2e', true);
                    });
            })
            ->where('name', 'not like', '%E2E-%')
            ->where('code', 'not like', '%E2E-%');
    }

    public function scopeE2eForTesting($query)
    {
        return $query->where(function ($query): void {
            $query->whereJsonContains('metadata->e2e', true)
                ->orWhere('name', 'like', '%E2E-%')
                ->orWhere('code', 'like', '%E2E-%');
        });
    }

    public function isSystemDefault(): bool
    {
        return $this->code === self::HISTORY_DEFAULT_CODE;
    }

    public function isE2e(): bool
    {
        $metadata = is_array($this->metadata) ? $this->metadata : [];
        $identity = strtoupper(trim($this->code.' '.$this->name));

        return filter_var($metadata['e2e'] ?? false, FILTER_VALIDATE_BOOLEAN)
            || str_contains($identity, 'E2E-');
    }

    public function isOpenNow(): bool
    {
        if ($this->status !== self::STATUS_OPEN || $this->isSystemDefault() || $this->isE2e()) {
            return false;
        }

        $now = now();

        return (! $this->starts_at || $this->starts_at->lte($now))
            && (! $this->ends_at || $this->ends_at->gte($now));
    }
}
