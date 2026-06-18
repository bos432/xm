<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class MigrationBatchItem extends Model
{
    use HasFactory;

    protected $fillable = [
        'migration_batch_id',
        'legacy_table',
        'target_table',
        'status',
        'create_found',
        'insert_statement_count',
        'estimated_row_count',
        'warning_count',
        'metadata',
    ];

    protected function casts(): array
    {
        return [
            'create_found' => 'boolean',
            'metadata' => 'array',
        ];
    }
}

