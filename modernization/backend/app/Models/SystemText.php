<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SystemText extends Model
{
    protected $fillable = [
        'key',
        'group',
        'label',
        'default_value',
        'value',
        'description',
        'is_builtin',
        'is_active',
        'sort_order',
        'updated_by',
    ];

    protected function casts(): array
    {
        return [
            'is_builtin' => 'boolean',
            'is_active' => 'boolean',
        ];
    }

    public function updater()
    {
        return $this->belongsTo(User::class, 'updated_by');
    }

    public function resolvedValue(): string
    {
        if (! $this->is_active) {
            return '';
        }

        if ($this->value !== null) {
            return (string) $this->value;
        }

        return (string) $this->default_value;
    }
}
