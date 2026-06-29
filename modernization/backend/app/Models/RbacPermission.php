<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class RbacPermission extends Model
{
    use HasFactory;

    protected $table = 'permissions';

    protected $fillable = [
        'code',
        'name',
        'group',
        'description',
    ];
}
