<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class DictionaryItem extends Model
{
    use HasFactory;

    protected $fillable = ['group', 'code', 'label', 'sort_order', 'is_active', 'metadata'];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'metadata' => 'array',
        ];
    }
}

