<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AcceptanceApplication extends Model
{
    use HasFactory;

    public const STATUS_DRAFT = 'draft';
    public const STATUS_SUBMITTED = 'submitted';
    public const STATUS_REVIEWING = 'reviewing';
    public const STATUS_RETURNED = 'returned';
    public const STATUS_REJECTED = 'rejected';
    public const STATUS_APPROVED = 'approved';
    public const STATUS_CLOSED = 'closed';

    protected $fillable = [
        'project_id',
        'unit_id',
        'submitted_by',
        'status',
        'current_reviewer_role',
        'summary',
        'submitted_at',
        'closed_at',
        'metadata',
    ];

    protected function casts(): array
    {
        return [
            'submitted_at' => 'datetime',
            'closed_at' => 'datetime',
            'metadata' => 'array',
        ];
    }

    public function project()
    {
        return $this->belongsTo(Project::class);
    }

    public function unit()
    {
        return $this->belongsTo(Unit::class);
    }

    public function submitter()
    {
        return $this->belongsTo(User::class, 'submitted_by');
    }

    public function reviews()
    {
        return $this->hasMany(AcceptanceReview::class);
    }

    public function extensions()
    {
        return $this->hasMany(AcceptanceExtension::class);
    }
}
