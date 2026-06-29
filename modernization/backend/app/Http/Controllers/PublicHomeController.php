<?php

namespace App\Http\Controllers;

use App\Models\PublicHomeItem;
use App\Models\PublicHomeSection;
use App\Models\SystemSetting;
use App\Models\ApplicationBatch;
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

    public function asset(string $section, string $type)
    {
        if (! in_array($section, ['nav', 'hero'], true) || ! in_array($type, ['logo', 'banner'], true)) {
            abort(404);
        }

        $model = PublicHomeSection::query()
            ->where('key', $section)
            ->where('is_active', true)
            ->firstOrFail();

        $asset = $this->assetMetadata($model, $type);
        if (! $asset || ! $this->hasAllowedAssetFile($asset, $type)) {
            abort(404, '素材不存在');
        }

        if (! Storage::disk($asset['disk'])->exists($asset['path'])) {
            abort(404, '素材不存在');
        }

        return Storage::disk($asset['disk'])->response($asset['path'], $asset['original_name'] ?? $type);
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

        $openBatches = $this->openBatchesPayload();

        return [
            'brand' => $this->brandPayload($sections),
            'nav' => $this->navPayload($sections, $items),
            'hero' => $this->heroPayload($sections, $items),
            'highlights' => $this->highlightsPayload($items),
            'notices' => $this->articlePayload($items->get('notice', collect())),
            'downloads' => $this->downloadPayload($items->get('download', collect())),
            'services' => $this->servicesPayload($items),
            'open_batches' => $openBatches,
            'current_batch' => $openBatches->first(),
            'footer' => $sections->get('footer')?->body ?? '',
        ];
    }

    private function brandPayload(Collection $sections): array
    {
        $nav = $sections->get('nav');
        $asset = $nav ? $this->assetMetadata($nav, 'logo') : null;

        return [
            'logo_url' => $asset && $this->hasAllowedAssetFile($asset, 'logo') ? '/api/public/homepage/assets/nav/logo' : null,
            'logo_alt' => $asset['alt'] ?? ($nav?->title ?: '系统标识'),
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
            'banner_url' => $this->heroBannerUrl($hero),
            'banner_alt' => $metadata['banner_alt'] ?? ($hero?->title ?: '首页横幅'),
            'primary_action' => $metadata['primary_action'] ?? ['label' => '', 'href' => '#'],
            'secondary_action' => $metadata['secondary_action'] ?? ['label' => '', 'href' => '#'],
            'status_title' => $metadata['status_title'] ?? '',
            'status_items' => $items->get('hero_status', collect())->map(fn (PublicHomeItem $item) => [
                'label' => $item->label ?: $item->title,
                'value' => $item->value ?? '',
            ])->values()->all(),
        ];
    }

    private function heroBannerUrl(?PublicHomeSection $hero): ?string
    {
        $asset = $hero ? $this->assetMetadata($hero, 'banner') : null;

        return $asset && $this->hasAllowedAssetFile($asset, 'banner') ? '/api/public/homepage/assets/hero/banner' : null;
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

    private function openBatchesPayload(): Collection
    {
        return ApplicationBatch::query()
            ->where('status', ApplicationBatch::STATUS_OPEN)
            ->where(function ($query): void {
                $query->whereNull('starts_at')->orWhere('starts_at', '<=', now());
            })
            ->where(function ($query): void {
                $query->whereNull('ends_at')->orWhere('ends_at', '>=', now());
            })
            ->orderByDesc('starts_at')
            ->get(['id', 'name', 'code', 'starts_at', 'ends_at', 'guide']);
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

    private function assetMetadata(PublicHomeSection $section, string $type): ?array
    {
        $metadata = is_array($section->metadata) ? $section->metadata : [];
        $asset = $metadata['assets'][$type] ?? null;

        return is_array($asset) ? $asset : null;
    }

    private function hasAllowedAssetFile(array $asset, string $type): bool
    {
        if (! in_array($asset['disk'] ?? null, ['local', 'private'], true)) {
            return false;
        }

        $path = str_replace('\\', '/', (string) ($asset['path'] ?? ''));

        return $path !== ''
            && $path === ($asset['path'] ?? '')
            && ! str_starts_with($path, '/')
            && ! str_contains($path, '../')
            && ! str_contains($path, '/..')
            && str_starts_with($path, 'public-home/assets/'.$type.'/');
    }

    private function legacySettingFallback(): array
    {
        $raw = SystemSetting::query()
            ->where('key', 'public.homepage_content')
            ->value('value');

        if (! is_string($raw) || $raw === '') {
            return [
                'brand' => ['logo_url' => null, 'logo_alt' => '系统标识'],
                'nav' => ['title' => '', 'links' => []],
                'hero' => [
                    'eyebrow' => '',
                    'title' => '',
                    'description' => '',
                    'banner_url' => null,
                    'banner_alt' => '首页横幅',
                    'primary_action' => ['label' => '', 'href' => '#'],
                    'secondary_action' => ['label' => '', 'href' => '#'],
                    'status_title' => '',
                    'status_items' => [],
                ],
                'highlights' => [],
                'notices' => [],
                'downloads' => [],
                'services' => [],
                'open_batches' => [],
                'current_batch' => null,
                'footer' => '',
            ];
        }

        $decoded = json_decode($raw, true);

        return is_array($decoded) ? $decoded : [];
    }
}
