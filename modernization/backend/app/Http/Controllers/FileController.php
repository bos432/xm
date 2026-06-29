<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreProjectFileRequest;
use App\Models\Project;
use App\Models\ProjectFile;
use App\Support\AuditLogger;
use App\Support\ProjectFileStorage;
use App\Support\Role;
use Illuminate\Http\UploadedFile;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class FileController extends Controller
{
    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    public function store(StoreProjectFileRequest $request, Project $project)
    {
        $this->authorizeProjectWrite($request, $project);

        $uploaded = $request->file('file');
        $path = $uploaded->store('project-files/'.$project->id);

        $file = ProjectFile::create([
            'project_id' => $project->id,
            'uploaded_by' => $request->user()->id,
            'disk' => config('filesystems.default'),
            'path' => $path,
            'original_name' => $this->safeOriginalName($uploaded),
            'mime_type' => $uploaded->getMimeType(),
            'extension' => strtolower($uploaded->getClientOriginalExtension()),
            'size_bytes' => $uploaded->getSize(),
            'sha256' => hash_file('sha256', $uploaded->getRealPath()),
            'purpose' => $request->input('purpose', 'application'),
            'metadata' => $request->input('metadata', []),
        ]);

        $this->auditLogger->record($request, 'project_file.uploaded', $file, [
            'project_id' => $project->id,
            'extension' => $file->extension,
            'size_bytes' => $file->size_bytes,
        ]);

        return response()->json($file, 201);
    }

    private function safeOriginalName(UploadedFile $file): string
    {
        $name = preg_replace('/[\x00-\x1F\x7F]+/u', ' ', $file->getClientOriginalName()) ?? '';
        $name = trim(preg_replace('/\s+/u', ' ', $name) ?? '');

        return $name !== '' ? $name : 'attachment.'.$file->getClientOriginalExtension();
    }

    public function download(Request $request, ProjectFile $file)
    {
        $this->authorizeProjectAccess($request, $file->project);

        if (! ProjectFileStorage::isAllowedDisk($file)) {
            $this->recordInvalidDisk($request, $file);

            return response()->json(['message' => '附件存储磁盘无效'], 404);
        }

        if (! ProjectFileStorage::isAllowedPath($file)) {
            $this->recordInvalidPath($request, $file);

            return response()->json(['message' => '附件文件路径无效'], 404);
        }

        if (! Storage::disk($file->disk)->exists($file->path)) {
            $this->auditLogger->record($request, 'project_file.missing', $file, [
                'disk' => $file->disk,
                'path' => $file->path,
            ]);

            return response()->json(['message' => '附件文件不存在'], 404);
        }

        $this->auditLogger->record($request, 'project_file.downloaded', $file);

        return Storage::disk($file->disk)->download($file->path, $file->original_name);
    }

    public function destroy(Request $request, ProjectFile $file)
    {
        $this->authorizeProjectWrite($request, $file->project);

        if (! ProjectFileStorage::isAllowedDisk($file)) {
            $this->recordInvalidDisk($request, $file);
            abort(422, '附件存储磁盘无效');
        }

        if (! ProjectFileStorage::isAllowedPath($file)) {
            $this->recordInvalidPath($request, $file);
            abort(422, '附件文件路径无效');
        }

        Storage::disk($file->disk)->delete($file->path);
        $this->auditLogger->record($request, 'project_file.deleted', $file);
        $file->delete();

        return response()->noContent();
    }

    private function authorizeProjectAccess(Request $request, Project $project): void
    {
        $user = $request->user();

        if (! Role::userCan($user, 'view_projects')) {
            abort(403, '无权访问项目文件');
        }

        if ($user->role === Role::UNIT && $project->unit_id !== $user->unit_id) {
            abort(403, '无权访问该项目文件');
        }
    }

    private function authorizeProjectWrite(Request $request, Project $project): void
    {
        $this->authorizeProjectAccess($request, $project);

        $user = $request->user();
        if ($user->role !== Role::UNIT || ! $user->unit_id) {
            abort(403, '只有单位用户可以维护项目附件');
        }

        if ($user->loadMissing('unit')->unit?->status !== 'active') {
            abort(403, '单位已停用，无法维护项目附件');
        }
    }

    private function recordInvalidPath(Request $request, ProjectFile $file): void
    {
        $this->auditLogger->record($request, 'project_file.invalid_path', $file, [
            'disk' => $file->disk,
            'path' => $file->path,
        ]);
    }

    private function recordInvalidDisk(Request $request, ProjectFile $file): void
    {
        $this->auditLogger->record($request, 'project_file.invalid_disk', $file, [
            'disk' => $file->disk,
            'path' => $file->path,
        ]);
    }
}
