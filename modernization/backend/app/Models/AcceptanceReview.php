<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AcceptanceReview extends Model
{
    use HasFactory;

    protected $fillable = [
        'acceptance_application_id',
        'reviewer_id',
        'stage',
        'decision',
        'score',
        'comment',
        'reviewed_at',
        'metadata',
    ];

    protected function casts(): array
    {
        return [
            'score' => 'decimal:2',
            'reviewed_at' => 'datetime',
            'metadata' => 'array',
        ];
    }

    public function acceptance()
    {
        return $this->belongsTo(AcceptanceApplication::class, 'acceptance_application_id');
    }

    public function reviewer()
    {
        return $this->belongsTo(User::class, 'reviewer_id');
    }
}
