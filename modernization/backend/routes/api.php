<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\DictionaryController;
use App\Http\Controllers\DictionaryItemController;
use App\Http\Controllers\FileController;
use App\Http\Controllers\MessageController;
use App\Http\Controllers\MigrationBatchController;
use App\Http\Controllers\MigrationReadinessController;
use App\Http\Controllers\OperationLogController;
use App\Http\Controllers\OperationLogExportController;
use App\Http\Controllers\PublicHomeAdminController;
use App\Http\Controllers\PublicHomeController;
use App\Http\Controllers\ProjectController;
use App\Http\Controllers\ProjectExportController;
use App\Http\Controllers\ReviewExportController;
use App\Http\Controllers\ReviewController;
use App\Http\Controllers\SystemSettingController;
use App\Http\Controllers\UnitController;
use App\Http\Controllers\UnitExportController;
use App\Http\Controllers\UserController;
use App\Http\Controllers\UserExportController;
use Illuminate\Support\Facades\Route;

Route::get('/auth/captcha', [AuthController::class, 'captcha'])->middleware('throttle:30,1');
Route::post('/auth/login', [AuthController::class, 'login'])->middleware('throttle:5,1');
Route::get('/public/homepage', [PublicHomeController::class, 'index']);
Route::get('/public/homepage/downloads/{item}', [PublicHomeController::class, 'download']);

Route::middleware('auth:sanctum')->group(function () {
    Route::middleware('active')->group(function () {
    Route::get('/auth/me', [AuthController::class, 'me']);
    Route::get('/dashboard/summary', [DashboardController::class, 'summary']);
    Route::put('/auth/profile', [AuthController::class, 'updateProfile']);
    Route::put('/auth/password', [AuthController::class, 'updatePassword']);
    Route::post('/auth/logout', [AuthController::class, 'logout']);

    Route::get('/projects/export.csv', [ProjectExportController::class, 'csv']);
    Route::apiResource('projects', ProjectController::class);
    Route::post('/projects/{project}/submit', [ProjectController::class, 'submit']);
    Route::post('/projects/{project}/withdraw', [ProjectController::class, 'withdraw']);
    Route::post('/projects/{project}/enter-acceptance', [ProjectController::class, 'enterAcceptance']);
    Route::post('/projects/{project}/close', [ProjectController::class, 'close']);
    Route::post('/projects/{project}/extension', [ProjectController::class, 'requestExtension']);
    Route::post('/projects/{project}/extension/{index}/review', [ProjectController::class, 'reviewExtension']);

    Route::post('/projects/{project}/files', [FileController::class, 'store']);
    Route::get('/files/{file}/download', [FileController::class, 'download']);
    Route::delete('/files/{file}', [FileController::class, 'destroy']);

    Route::get('/reviews/tasks', [ReviewController::class, 'tasks']);
    Route::get('/reviews/results', [ReviewController::class, 'results']);
    Route::get('/reviews/tasks/export.csv', [ReviewExportController::class, 'tasksCsv']);
    Route::get('/reviews/results/export.csv', [ReviewExportController::class, 'resultsCsv']);
    Route::post('/projects/{project}/reviews', [ReviewController::class, 'store']);

    Route::get('/settings', [SystemSettingController::class, 'index']);
    Route::put('/settings/{setting}', [SystemSettingController::class, 'update']);
    Route::get('/public-home', [PublicHomeAdminController::class, 'index']);
    Route::put('/public-home/sections/{section:key}', [PublicHomeAdminController::class, 'updateSection']);
    Route::post('/public-home/items', [PublicHomeAdminController::class, 'storeItem']);
    Route::put('/public-home/items/{item}', [PublicHomeAdminController::class, 'updateItem']);
    Route::delete('/public-home/items/{item}', [PublicHomeAdminController::class, 'destroyItem']);
    Route::post('/public-home/items/{item}/file', [PublicHomeAdminController::class, 'uploadFile']);

    Route::get('/messages', [MessageController::class, 'index']);
    Route::post('/messages/read-all', [MessageController::class, 'markAllRead']);
    Route::post('/messages/{message}/read', [MessageController::class, 'markRead']);
    Route::get('/dictionaries', [DictionaryController::class, 'index']);
    Route::apiResource('dictionary-items', DictionaryItemController::class)->except(['destroy']);
    Route::get('/users/export.csv', [UserExportController::class, 'csv']);
    Route::apiResource('users', UserController::class)->except(['destroy']);
    Route::get('/units/me', [UnitController::class, 'me']);
    Route::get('/units/export.csv', [UnitExportController::class, 'csv']);
    Route::apiResource('units', UnitController::class)->except(['destroy']);
    Route::get('/migration/readiness', [MigrationReadinessController::class, 'show']);
    Route::get('/migration/batches', [MigrationBatchController::class, 'index']);
    Route::get('/migration/batches/{migrationBatch}', [MigrationBatchController::class, 'show']);
    Route::get('/operation-logs/export.csv', [OperationLogExportController::class, 'csv']);
    Route::get('/operation-logs', [OperationLogController::class, 'index']);
    });
});
