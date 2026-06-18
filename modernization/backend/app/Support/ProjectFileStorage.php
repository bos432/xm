<?php

namespace App\Support;

use App\Models\ProjectFile;

final class ProjectFileStorage
{
    public static function isAllowedDisk(ProjectFile $file): bool
    {
        return is_string($file->disk) && in_array($file->disk, ['local', 'private'], true);
    }

    public static function isAllowedPath(ProjectFile $file): bool
    {
        if (! is_string($file->path) || $file->path === '') {
            return false;
        }

        $path = str_replace('\\', '/', $file->path);

        if ($path !== $file->path || str_starts_with($path, '/') || str_contains($path, '../') || str_contains($path, '/..')) {
            return false;
        }

        return str_starts_with($path, 'project-files/'.$file->project_id.'/')
            || str_starts_with($path, 'legacy/projects/');
    }
}
