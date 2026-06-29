<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ProjectRectification extends Model
{
    protected $fillable = [
        'project_id',
        'acceptance_application_id',
        'unit_id',
        'created_by',
        'submitted_by',
        'reviewed_by',
        'status',
        'title',
        'requirement',
        'response',
        'due_date',
        'submitted_at',
        'reviewed_at',
        'review_comment',
        'metadata',
    ];

    protected function casts(): array
    {
        return [
            'due_date' => 'date',
            'submitted_at' => 'datetime',
            'reviewed_at' => 'datetime',
            'metadata' => 'array',
        ];
    }

    public function project()
    {
        return $this->belongsTo(Project::class);
    }

    public function acceptance()
    {
        return $this->belongsTo(AcceptanceApplication::class, 'acceptance_application_id');
    }

    public function unit()
    {
        return $this->belongsTo(Unit::class);
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
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
