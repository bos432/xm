<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class RbacRole extends Model
{
    use HasFactory;

    protected $table = 'roles';

    protected $fillable = [
        'code',
        'name',
        'description',
        'is_builtin',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'is_builtin' => 'boolean',
            'is_active' => 'boolean',
        ];
    }

    public function permissions()
    {
        return $this->belongsToMany(RbacPermission::class, 'permission_role', 'role_id', 'permission_id')
            ->withTimestamps();
    }
}
