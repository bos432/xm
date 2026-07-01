<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'name',
        'username',
        'email',
        'mobile',
        'password',
        'role',
        'unit_id',
        'is_active',
        'last_login_at',
        'last_login_ip',
        'metadata',
    ];

    protected $hidden = ['password', 'remember_token'];

    protected function casts(): array
    {
        return [
            'password' => 'hashed',
            'is_active' => 'boolean',
            'last_login_at' => 'datetime',
            'metadata' => 'array',
        ];
    }

    public function unit()
    {
        return $this->belongsTo(Unit::class);
    }

    public function additionalRoles()
    {
        return $this->belongsToMany(RbacRole::class, 'role_user', 'user_id', 'role_id')
            ->withTimestamps();
    }
}
