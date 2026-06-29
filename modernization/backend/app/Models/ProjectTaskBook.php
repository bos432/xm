<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ProjectTaskBook extends Model
{
    protected $fillable = [
        'project_id',
        'unit_id',
        'submitted_by',
        'reviewed_by',
        'status',
        'title',
        'content',
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

    public function reviewer()
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }
}
