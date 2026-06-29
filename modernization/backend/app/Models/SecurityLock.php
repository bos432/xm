<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SecurityLock extends Model
{
    use HasFactory;

    protected $fillable = [
        'identity_type',
        'identity_value',
        'failed_count',
        'reason',
        'is_active',
        'locked_until',
        'created_by',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'locked_until' => 'datetime',
        ];
    }

    public function isLocked(): bool
    {
        return $this->is_active && (! $this->locked_until || $this->locked_until->isFuture());
    }
}
