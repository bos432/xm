<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ReviewDispatchRule extends Model
{
    protected $fillable = [
        'name',
        'target_stage',
        'management_unit',
        'project_field',
        'research_direction',
        'project_category',
        'project_type',
        'recommended_user_ids',
        'expert_count',
        'auto_assign',
        'is_active',
        'priority',
        'remark',
        'created_by',
        'updated_by',
    ];

    protected function casts(): array
    {
        return [
            'recommended_user_ids' => 'array',
            'expert_count' => 'integer',
            'auto_assign' => 'boolean',
            'is_active' => 'boolean',
            'priority' => 'integer',
        ];
    }
}
