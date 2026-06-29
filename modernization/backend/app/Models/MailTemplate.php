<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class MailTemplate extends Model
{
    use HasFactory;

    protected $fillable = [
        'key',
        'name',
        'subject',
        'body',
        'is_active',
        'is_builtin',
        'metadata',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'is_builtin' => 'boolean',
            'metadata' => 'array',
        ];
    }
}
