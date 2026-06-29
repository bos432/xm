<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class PublicHomeSection extends Model
{
    use HasFactory;

    protected $fillable = [
        'key',
        'title',
        'eyebrow',
        'body',
        'metadata',
        'is_active',
        'updated_by',
    ];

    protected function casts(): array
    {
        return [
            'metadata' => 'array',
            'is_active' => 'boolean',
        ];
    }
}
