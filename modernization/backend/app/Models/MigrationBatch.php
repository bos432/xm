<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class MigrationBatch extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'mode',
        'source_path',
        'status',
        'started_at',
        'finished_at',
        'summary',
        'metadata',
    ];

    protected function casts(): array
    {
        return [
            'started_at' => 'datetime',
            'finished_at' => 'datetime',
            'summary' => 'array',
            'metadata' => 'array',
        ];
    }

    public function items()
    {
        return $this->hasMany(MigrationBatchItem::class);
    }
}

