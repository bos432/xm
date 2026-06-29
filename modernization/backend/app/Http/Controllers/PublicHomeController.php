<?php

namespace App\Http\Controllers;

use App\Models\PublicHomeItem;
use App\Models\PublicHomeSection;
use App\Models\SystemSetting;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Storage;

class PublicHomeController extends Controller
{
    public function index()
    {
        return response()->json($this->homepageContent());
    }

    public function download(PublicHomeItem $item)
    {
        if ($item->section !== 'download' || ! $item->is_active || ! $this->hasAllowedDownloadFile($item)) {
            abort(404, '资料文件不存在');
        }

        if (! Storage::disk($item->file_disk)->exists($item->file_path)) {
            abort(404, '资料文件不存在');
        }

        return Storage::disk($item->file_disk)->download($item->file_path, $item->file_original_name);
    }

    private function homepageContent(): array
    {
        if (! PublicHomeSection::query()->exists() && ! PublicHomeItem::query()->exists()) {
            return $this->legacySettingFallback();
        }

        $sections = PublicHomeSection::query()
            ->where('is_active', true)
            ->get()
            ->keyBy('key');

        $items = PublicHomeItem::query()
            ->where('is_active', true)
            ->whereIn('section', PublicHomeItem::SECTIONS)
            ->orderBy('sort_order')
            ->orderByDesc('published_at')
            ->orderByDesc('id')
            ->get()
            ->groupBy('section');

        return [
            'nav' => $this->navPayload($sections, $items),
            'hero' => $this->heroPayload($sections, $items),
            'highlights' => $this->highlightsPayload($items),
            'notices' => $this->articlePayload($items->get('notice', collect())),
            'downloads' => $this->downloadPayload($items->get('download', collect())),
            'services' => $this->servicesPayload($items),
            'footer' => $sections->get('footer')?->body ?? '',
        ];
    }

    private function navPayload(Collection $sections, Collection $items): array
    {
        return [
            'title' => $sections->get('nav')?->title ?? '',
            'links' => $items->get('nav_link', collect())->map(fn (PublicHomeItem $item) => [
                'label' => $item->label ?: $item->title,
                'href' => $item->href ?: '#',
            ])->values()->all(),
        ];
    }

    private function heroPayload(Collection $sections, Collection $items): array
    {
        $hero = $sections->get('hero');
        $metadata = is_array($hero?->metadata) ? $hero->metadata : [];

        return [
            'eyebrow' => $hero?->eyebrow ?? '',
            'title' => $hero?->title ?? '',
            'description' => $hero?->body ?? '',
            'primary_action' => $metadata['primary_action'] ?? ['label' => '', 'href' => '#'],
            'secondary_action' => $metadata['secondary_action'] ?? ['label' => '', 'href' => '#'],
            'status_title' => $metadata['status_title'] ?? '',
            'status_items' => $items->get('hero_status', collect())->map(fn (PublicHomeItem $item) => [
                'label' => $item->label ?: $item->title,
                'value' => $item->value ?? '',
            ])->values()->all(),
        ];
    }

    private function highlightsPayload(Collection $items): array
    {
        return $items->get('highlight', collect())->map(fn (PublicHomeItem $item) => [
            'label' => $item->label ?: $item->title,
            'value' => $item->value ?? '',
            'description' => $item->summary ?? '',
        ])->values()->all();
    }

    private function articlePayload(Collection $items): array
    {
        return $items->map(fn (PublicHomeItem $item) => [
            'id' => $item->id,
            'title' => $item->title ?? '',
            'date' => $item->published_at?->toDateString(),
            'summary' => $item->summary ?? '',
            'body' => $item->body ?? '',
            'href' => $item->href,
        ])->values()->all();
    }

    private function downloadPayload(Collection $items): array
    {
        return $items->map(fn (PublicHomeItem $item) => [
            'id' => $item->id,
            'title' => $item->title ?? '',
            'date' => $item->published_at?->toDateString(),
            'summary' => $item->summary ?? '',
            'download_url' => $this->hasAllowedDownloadFile($item) ? '/api/public/homepage/downloads/'.$item->id : null,
            'original_name' => $item->file_original_name,
            'size_bytes' => $item->file_size_bytes,
        ])->values()->all();
    }

    private function servicesPayload(Collection $items): array
    {
        return $items->get('service', collect())->map(fn (PublicHomeItem $item) => [
            'code' => $item->code ?? '',
            'title' => $item->title ?? '',
            'description' => $item->summary ?? '',
        ])->values()->all();
    }

    private function hasAllowedDownloadFile(PublicHomeItem $item): bool
    {
        if (! is_string($item->file_disk) || ! in_array($item->file_disk, ['local', 'private'], true)) {
            return false;
        }

        if (! is_string($item->file_path) || $item->file_path === '') {
            return false;
        }

        $path = str_replace('\\', '/', $item->file_path);

        return $path === $item->file_path
            && ! str_starts_with($path, '/')
            && ! str_contains($path, '../')
            && ! str_contains($path, '/..')
            && str_starts_with($path, 'public-home/downloads/');
    }

    private function legacySettingFallback(): array
    {
        $raw = SystemSetting::query()
            ->where('key', 'public.homepage_content')
            ->value('value');

        if (! is_string($raw) || $raw === '') {
            return [
                'nav' => ['title' => '', 'links' => []],
                'hero' => [
                    'eyebrow' => '',
                    'title' => '',
                    'description' => '',
                    'primary_action' => ['label' => '', 'href' => '#'],
                    'secondary_action' => ['label' => '', 'href' => '#'],
                    'status_title' => '',
                    'status_items' => [],
                ],
                'highlights' => [],
                'notices' => [],
                'downloads' => [],
                'services' => [],
                'footer' => '',
            ];
        }

        $decoded = json_decode($raw, true);

        return is_array($decoded) ? $decoded : [];
    }
}
