<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class OperationLog extends Model
{
    use HasFactory;

    protected $fillable = ['user_id', 'action', 'target_type', 'target_id', 'ip_address', 'user_agent', 'payload', 'created_at', 'updated_at'];

    protected function casts(): array
    {
        return ['payload' => 'array'];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
