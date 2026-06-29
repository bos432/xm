<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SecurityIpRule extends Model
{
    use HasFactory;

    protected $fillable = [
        'type',
        'cidr',
        'description',
        'is_active',
        'created_by',
    ];

    protected function casts(): array
    {
        return ['is_active' => 'boolean'];
    }
}
