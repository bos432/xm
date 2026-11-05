<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ProjectReview extends Model
{
    use HasFactory;

    public function scopeCurrentRound(Builder $query): Builder
    {
        // IDs avoid same-second timestamp ambiguity when a returned project is resubmitted.
        return $query->where('project_reviews.id', '>', function ($returned): void {
            $returned->from('project_reviews as returned_reviews')
                ->selectRaw('COALESCE(MAX(returned_reviews.id), 0)')
                ->whereColumn('returned_reviews.project_id', 'project_reviews.project_id')
                ->where('returned_reviews.decision', 'return');
        });
    }

    protected $fillable = [
        'legacy_id',
        'project_id',
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

    public function project()
    {
        return $this->belongsTo(Project::class);
    }

    public function reviewer()
    {
        return $this->belongsTo(User::class, 'reviewer_id');
    }
}
