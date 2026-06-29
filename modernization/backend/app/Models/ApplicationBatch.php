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

    public function isOpenNow(): bool
    {
        if ($this->status !== self::STATUS_OPEN) {
            return false;
        }

        $now = now();

        return (! $this->starts_at || $this->starts_at->lte($now))
            && (! $this->ends_at || $this->ends_at->gte($now));
    }
}
