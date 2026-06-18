<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Project extends Model
{
    use HasFactory;

    public const STATUS_DRAFT = 'draft';
    public const STATUS_SUBMITTED = 'submitted';
    public const STATUS_RETURNED = 'returned';
    public const STATUS_REVIEWING = 'reviewing';
    public const STATUS_APPROVED = 'approved';
    public const STATUS_REJECTED = 'rejected';
    public const STATUS_ACCEPTANCE = 'acceptance';
    public const STATUS_CLOSED = 'closed';

    protected $fillable = [
        'legacy_id',
        'unit_id',
        'owner_id',
        'title',
        'category',
        'project_type',
        'status',
        'summary',
        'budget_amount',
        'submitted_at',
        'current_reviewer_role',
        'metadata',
    ];

    protected function casts(): array
    {
        return [
            'budget_amount' => 'decimal:2',
            'submitted_at' => 'datetime',
            'metadata' => 'array',
        ];
    }

    public function unit()
    {
        return $this->belongsTo(Unit::class);
    }

    public function owner()
    {
        return $this->belongsTo(User::class, 'owner_id');
    }

    public function files()
    {
        return $this->hasMany(ProjectFile::class);
    }

    public function reviews()
    {
        return $this->hasMany(ProjectReview::class);
    }

    public function pendingExtensionRequestsCount(): int
    {
        $requests = $this->metadata['extension_requests'] ?? [];

        return collect($requests)
            ->filter(fn (array $request) => ($request['status'] ?? 'pending') === 'pending')
            ->count();
    }
}
