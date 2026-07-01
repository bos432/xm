<?php

namespace App\Http\Controllers;

use App\Http\Requests\StorePublicHomeFileRequest;
use App\Http\Requests\StorePublicHomeAssetRequest;
use App\Models\PublicHomeItem;
use App\Models\PublicHomeSection;
use App\Support\AuditLogger;
use App\Support\Role;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use Illuminate\Support\Str;

class PublicHomeAdminController extends Controller
{
    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    public function index(Request $request)
    {
        $this->authorizeManage($request);

        return response()->json([
            'sections' => PublicHomeSection::query()->orderBy('key')->get(),
            'items' => PublicHomeItem::query()
                ->orderBy('section')
                ->orderBy('sort_order')
                ->orderByDesc('published_at')
                ->orderByDesc('id')
                ->get(),
        ]);
    }

    public function updateSection(Request $request, PublicHomeSection $section)
    {
        $this->authorizeManage($request);

        $data = $request->validate([
            'title' => ['nullable', 'string', 'max:200'],
            'eyebrow' => ['nullable', 'string', 'max:200'],
            'body' => ['nullable', 'string'],
            'metadata' => ['nullable', 'array'],
            'is_active' => ['required', 'boolean'],
        ]);

        if (array_key_exists('metadata', $data)) {
            $data['metadata'] = $this->preserveAssetMetadata($section, $data['metadata'] ?? []);
        }

        $data['updated_by'] = $request->user()->id;
        $section->update($data);
        $this->auditLogger->record($request, 'public_home.section_updated', $section, ['key' => $section->key]);

        return response()->json($section->refresh());
    }

    public function storeItem(Request $request)
    {
        $this->authorizeManage($request);

        $data = $this->validateItem($request);
        $data['updated_by'] = $request->user()->id;
        $item = PublicHomeItem::create($data);
        $this->auditLogger->record($request, 'public_home.item_created', $item, ['section' => $item->section]);

        return response()->json($item, 201);
    }

    public function updateItem(Request $request, PublicHomeItem $item)
    {
        $this->authorizeManage($request);

        $data = $this->validateItem($request);
        $data['updated_by'] = $request->user()->id;
        $item->update($data);
        $this->auditLogger->record($request, 'public_home.item_updated', $item, ['section' => $item->section]);

        return response()->json($item->refresh());
    }

    public function destroyItem(Request $request, PublicHomeItem $item)
    {
        $this->authorizeManage($request);
        $this->deleteFileIfAllowed($item);
        $this->auditLogger->record($request, 'public_home.item_deleted', $item, ['section' => $item->section]);
        $item->delete();

        return response()->noContent();
    }

    public function uploadFile(StorePublicHomeFileRequest $request, PublicHomeItem $item)
    {
        $this->authorizeManage($request);

        if ($item->section !== 'download') {
            abort(422, '只有资料下载内容可以上传附件');
        }

        $uploaded = $request->file('file');
        $path = $this->storeUploadedFile($item, $uploaded);
        $this->deleteFileIfAllowed($item);

        $item->update([
            'file_disk' => config('filesystems.default'),
            'file_path' => $path,
            'file_original_name' => $this->safeOriginalName($uploaded),
            'file_mime_type' => $uploaded->getMimeType(),
            'file_extension' => strtolower($uploaded->getClientOriginalExtension()),
            'file_size_bytes' => $uploaded->getSize(),
            'file_sha256' => hash_file('sha256', $uploaded->getRealPath()),
            'updated_by' => $request->user()->id,
        ]);

        $this->auditLogger->record($request, 'public_home.download_file_uploaded', $item, [
            'extension' => $item->file_extension,
            'size_bytes' => $item->file_size_bytes,
        ]);

        return response()->json($item->refresh());
    }

    public function uploadAsset(StorePublicHomeAssetRequest $request, PublicHomeSection $section)
    {
        $this->authorizeAssetManage($request);

        $type = $request->string('type')->toString();
        if (($type === 'banner' && $section->key !== 'hero') || (in_array($type, ['logo', 'favicon'], true) && $section->key !== 'nav')) {
            abort(422, '素材类型与首页区域不匹配');
        }

        $uploaded = $request->file('file');
        $metadata = is_array($section->metadata) ? $section->metadata : [];
        $oldAsset = $metadata['assets'][$type] ?? null;
        $extension = strtolower($uploaded->getClientOriginalExtension());
        $path = $uploaded->storeAs(
            'public-home/assets/'.$type.'/'.$section->id,
            (string) Str::uuid().'.'.$extension
        );

        if (is_array($oldAsset)) {
            $this->deleteAssetFileIfAllowed($oldAsset, $type);
        }

        $metadata['assets'][$type] = [
            'disk' => config('filesystems.default'),
            'path' => $path,
            'original_name' => $this->safeOriginalName($uploaded),
            'mime_type' => $uploaded->getMimeType(),
            'extension' => $extension,
            'size_bytes' => $uploaded->getSize(),
            'sha256' => hash_file('sha256', $uploaded->getRealPath()),
            'alt' => $request->input('alt') ?: ($section->title ?: $section->key),
            'uploaded_at' => now()->toDateTimeString(),
            'uploaded_by' => $request->user()->id,
            'uploaded_by_name' => $request->user()->name ?: $request->user()->username,
        ];

        if ($type === 'banner') {
            $metadata['banner_alt'] = $metadata['assets'][$type]['alt'];
        }

        $section->update([
            'metadata' => $metadata,
            'updated_by' => $request->user()->id,
        ]);

        $this->auditLogger->record($request, 'public_home.asset_uploaded', $section, [
            'key' => $section->key,
            'type' => $type,
            'size_bytes' => $uploaded->getSize(),
        ]);

        return response()->json($section->refresh());
    }

    public function deleteAsset(Request $request, PublicHomeSection $section, string $type)
    {
        $this->authorizeAssetManage($request);

        if (! in_array($type, ['logo', 'banner', 'favicon'], true)) {
            abort(404);
        }

        $metadata = is_array($section->metadata) ? $section->metadata : [];
        $asset = $metadata['assets'][$type] ?? null;
        if (is_array($asset)) {
            $this->deleteAssetFileIfAllowed($asset, $type);
        }

        unset($metadata['assets'][$type]);
        if ($type === 'banner') {
            unset($metadata['banner_alt']);
        }

        $section->update([
            'metadata' => $metadata,
            'updated_by' => $request->user()->id,
        ]);

        $this->auditLogger->record($request, 'public_home.asset_deleted', $section, [
            'key' => $section->key,
            'type' => $type,
        ]);

        return response()->json($section->refresh());
    }

    private function validateItem(Request $request): array
    {
        return $request->validate([
            'section' => ['required', 'string', Rule::in(PublicHomeItem::SECTIONS)],
            'title' => ['nullable', 'string', 'max:255'],
            'label' => ['nullable', 'string', 'max:200'],
            'value' => ['nullable', 'string', 'max:200'],
            'code' => ['nullable', 'string', 'max:50'],
            'summary' => ['nullable', 'string', 'max:2000'],
            'body' => ['nullable', 'string'],
            'href' => ['nullable', 'string', 'max:600'],
            'published_at' => ['nullable', 'date'],
            'sort_order' => ['required', 'integer', 'min:0', 'max:999999'],
            'is_active' => ['required', 'boolean'],
            'metadata' => ['nullable', 'array'],
        ]);
    }

    private function authorizeManage(Request $request): void
    {
        if (! Role::userCan($request->user(), 'manage_home_content')) {
            abort(403, '无权管理首页内容');
        }
    }

    private function preserveAssetMetadata(PublicHomeSection $section, array $metadata): array
    {
        $existing = is_array($section->metadata) ? $section->metadata : [];

        if (! isset($metadata['assets']) && isset($existing['assets'])) {
            $metadata['assets'] = $existing['assets'];
        }

        if (! isset($metadata['banner_alt']) && isset($existing['banner_alt'])) {
            $metadata['banner_alt'] = $existing['banner_alt'];
        }

        return $metadata;
    }

    private function authorizeAssetManage(Request $request): void
    {
        if (! Role::userCan($request->user(), 'manage_home_assets') && ! Role::userCan($request->user(), 'public_home.manage_assets')) {
            abort(403, '只有超级管理员可以维护首页素材');
        }
    }

    private function storeUploadedFile(PublicHomeItem $item, UploadedFile $file): string
    {
        $extension = strtolower($file->getClientOriginalExtension());

        return $file->storeAs(
            'public-home/downloads/'.$item->id,
            (string) Str::uuid().'.'.$extension
        );
    }

    private function safeOriginalName(UploadedFile $file): string
    {
        $name = preg_replace('/[\x00-\x1F\x7F]+/u', ' ', $file->getClientOriginalName()) ?? '';
        $name = trim(preg_replace('/\s+/u', ' ', $name) ?? '');

        return $name !== '' ? $name : 'attachment.'.$file->getClientOriginalExtension();
    }

    private function deleteFileIfAllowed(PublicHomeItem $item): void
    {
        if (! $this->hasAllowedDownloadFile($item)) {
            return;
        }

        Storage::disk($item->file_disk)->delete($item->file_path);
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

    private function deleteAssetFileIfAllowed(array $asset, string $type): void
    {
        if (! $this->hasAllowedAssetFile($asset, $type)) {
            return;
        }

        Storage::disk($asset['disk'])->delete($asset['path']);
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
}
