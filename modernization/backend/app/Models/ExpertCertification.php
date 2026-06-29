<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ExpertCertification extends Model
{
    protected $fillable = [
        'user_id',
        'submitted_by',
        'reviewed_by',
        'status',
        'organization',
        'specialty',
        'professional_title',
        'certificate_no',
        'summary',
        'submitted_at',
        'reviewed_at',
        'review_comment',
        'metadata',
    ];

    protected function casts(): array
    {
        return [
            'submitted_at' => 'datetime',
            'reviewed_at' => 'datetime',
            'metadata' => 'array',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function submitter()
    {
        return $this->belongsTo(User::class, 'submitted_by');
    }

    public function reviewer()
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }
}
