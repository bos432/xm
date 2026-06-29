<?php

namespace App\Http\Controllers;

use App\Models\MigrationBatch;
use App\Support\Role;
use Illuminate\Http\Request;

class MigrationBatchController extends Controller
{
    public function index(Request $request)
    {
        if (! Role::userCan($request->user(), 'view_migration')) {
            abort(403, '无权查看迁移批次');
        }

        return MigrationBatch::query()->with('items')->latest()->paginate(20);
    }

    public function show(Request $request, MigrationBatch $migrationBatch)
    {
        if (! Role::userCan($request->user(), 'view_migration')) {
            abort(403, '无权查看迁移批次');
        }

        return $migrationBatch->load('items');
    }
}
