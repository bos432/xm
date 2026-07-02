<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AcceptanceExtension extends Model
{
    use HasFactory;

    protected $fillable = [
        'acceptance_application_id',
        'project_id',
        'requested_by',
        'reviewed_by',
        'status',
        'reason',
        'expected_date',
        'review_comment',
        'reviewed_at',
        'metadata',
    ];

    protected function casts(): array
    {
        return [
            'expected_date' => 'date',
            'reviewed_at' => 'datetime',
            'metadata' => 'array',
        ];
    }

    public function requester()
    {
        return $this->belongsTo(User::class, 'requested_by');
    }

    public function reviewer()
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }
}
