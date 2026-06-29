<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class MailLog extends Model
{
    use HasFactory;

    protected $fillable = [
        'mail_template_id',
        'template_key',
        'to_address',
        'to_name',
        'subject',
        'body',
        'status',
        'error',
        'retry_count',
        'queued_at',
        'sent_at',
        'triggered_by',
        'metadata',
    ];

    protected function casts(): array
    {
        return [
            'queued_at' => 'datetime',
            'sent_at' => 'datetime',
            'metadata' => 'array',
        ];
    }

    public function template()
    {
        return $this->belongsTo(MailTemplate::class, 'mail_template_id');
    }
}
