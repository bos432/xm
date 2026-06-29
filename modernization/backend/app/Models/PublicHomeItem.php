<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class PublicHomeItem extends Model
{
    use HasFactory;

    public const SECTIONS = [
        'nav_link',
        'hero_status',
        'highlight',
        'notice',
        'download',
        'service',
    ];

    protected $fillable = [
        'section',
        'title',
        'label',
        'value',
        'code',
        'summary',
        'body',
        'href',
        'published_at',
        'sort_order',
        'is_active',
        'file_disk',
        'file_path',
        'file_original_name',
        'file_mime_type',
        'file_extension',
        'file_size_bytes',
        'file_sha256',
        'legacy_source',
        'legacy_id',
        'metadata',
        'updated_by',
    ];

    protected function casts(): array
    {
        return [
            'metadata' => 'array',
            'is_active' => 'boolean',
            'published_at' => 'datetime',
        ];
    }
}
