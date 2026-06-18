<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Unit extends Model
{
    use HasFactory;

    protected $fillable = [
        'legacy_id',
        'name',
        'credit_code',
        'contact_name',
        'contact_mobile',
        'email',
        'address',
        'region_code',
        'status',
        'metadata',
    ];

    protected function casts(): array
    {
        return ['metadata' => 'array'];
    }

    public function users()
    {
        return $this->hasMany(User::class);
    }
}
