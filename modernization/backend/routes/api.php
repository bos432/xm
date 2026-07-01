<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\AcceptanceController;
use App\Http\Controllers\ApplicationBatchController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\DictionaryController;
use App\Http\Controllers\DictionaryItemController;
use App\Http\Controllers\FileController;
use App\Http\Controllers\MessageController;
use App\Http\Controllers\MailCenterController;
use App\Http\Controllers\MigrationBatchController;
use App\Http\Controllers\MigrationReadinessController;
use App\Http\Controllers\OperationLogController;
use App\Http\Controllers\OperationLogExportController;
use App\Http\Controllers\PublicHomeAdminController;
use App\Http\Controllers\PublicHomeController;
use App\Http\Controllers\ProjectController;
use App\Http\Controllers\ProjectExportController;
use App\Http\Controllers\ProjectLifecycleController;
use App\Http\Controllers\RbacController;
use App\Http\Controllers\ReviewExportController;
use App\Http\Controllers\ReviewController;
use App\Http\Controllers\SecurityController;
use App\Http\Controllers\SystemSettingController;
use App\Http\Controllers\SystemTextController;
use App\Http\Controllers\UnitController;
use App\Http\Controllers\UnitExportController;
use App\Http\Controllers\UserController;
use App\Http\Controllers\UserExportController;
use App\Models\SecurityEvent;
use App\Support\RuntimeConfig;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Route;

RateLimiter::for('auth-login', function (Request $request) {
    $ip = (string) $request->ip();
    $respond = function (Request $request, array $headers) use ($ip) {
        $retryAfter = (int) ($headers['Retry-After'] ?? 60);
        SecurityEvent::create([
            'type' => 'auth.throttled',
            'severity' => 'medium',
            'username' => (string) $request->input('username', ''),
            'ip_address' => $ip,
            'user_agent' => substr((string) $request->userAgent(), 0, 500),
            'payload' => [
                'retry_after_seconds' => $retryAfter,
            ],
        ]);

        return response()->json([
            'message' => '登录过于频繁，请稍后再试',
            'retry_after_seconds' => $retryAfter,
        ], 429, $headers);
    };
    $whitelist = collect(explode(',', RuntimeConfig::value('security.login_throttle_whitelist_ips', '') ?? ''))
        ->map(fn (string $item) => trim($item))
        ->filter()
        ->all();

    if (RuntimeConfig::boolValue('security.login_throttle_relaxed', false) || in_array($ip, $whitelist, true)) {
        return Limit::perMinute(max(1, RuntimeConfig::intValue('security.login_throttle_relaxed_per_minute', 60)))
            ->by($ip.'|'.(string) $request->input('username', ''))
            ->response($respond);
    }

    return Limit::perMinute(max(1, RuntimeConfig::intValue('security.login_throttle_per_minute', 5)))
        ->by($ip.'|'.(string) $request->input('username', ''))
        ->response($respond);
});

Route::get('/auth/captcha', [AuthController::class, 'captcha'])->middleware('throttle:30,1');
Route::post('/auth/login', [AuthController::class, 'login'])->middleware('throttle:auth-login');
Route::post('/auth/register-unit', [AuthController::class, 'registerUnit'])->middleware('throttle:5,1');
Route::post('/auth/forgot-password', [AuthController::class, 'forgotPassword'])->middleware('throttle:5,1');
Route::post('/auth/reset-password', [AuthController::class, 'resetPassword'])->middleware('throttle:5,1');
Route::get('/public/homepage', [PublicHomeController::class, 'index']);
Route::get('/public/homepage/downloads/{item}', [PublicHomeController::class, 'download']);
Route::get('/public/homepage/assets/{section}/{type}', [PublicHomeController::class, 'asset']);
Route::get('/public/application-batches/open', [ApplicationBatchController::class, 'openBatches']);
Route::get('/public/system-texts', [SystemTextController::class, 'publicIndex']);

Route::middleware('auth:sanctum')->group(function () {
    Route::middleware('active')->group(function () {
    Route::get('/auth/me', [AuthController::class, 'me']);
    Route::get('/dashboard/summary', [DashboardController::class, 'summary']);
    Route::put('/auth/profile', [AuthController::class, 'updateProfile']);
    Route::put('/auth/password', [AuthController::class, 'updatePassword']);
    Route::post('/auth/logout', [AuthController::class, 'logout']);

    Route::get('/projects/export.csv', [ProjectExportController::class, 'csv']);
    Route::get('/projects/options', [ProjectController::class, 'options']);
    Route::apiResource('projects', ProjectController::class);
    Route::post('/projects/{project}/submit', [ProjectController::class, 'submit']);
    Route::post('/projects/{project}/withdraw', [ProjectController::class, 'withdraw']);
    Route::post('/projects/{project}/enter-acceptance', [ProjectController::class, 'enterAcceptance']);
    Route::post('/projects/{project}/close', [ProjectController::class, 'close']);
    Route::post('/projects/{project}/extension', [ProjectController::class, 'requestExtension']);
    Route::post('/projects/{project}/extension/{index}/review', [ProjectController::class, 'reviewExtension']);

    Route::get('/application-batches', [ApplicationBatchController::class, 'index']);
    Route::post('/application-batches', [ApplicationBatchController::class, 'store']);
    Route::get('/application-batches/{applicationBatch}', [ApplicationBatchController::class, 'show']);
    Route::put('/application-batches/{applicationBatch}', [ApplicationBatchController::class, 'update']);
    Route::post('/application-batches/{applicationBatch}/open', [ApplicationBatchController::class, 'open']);
    Route::post('/application-batches/{applicationBatch}/close', [ApplicationBatchController::class, 'close']);
    Route::post('/application-batches/{applicationBatch}/archive', [ApplicationBatchController::class, 'archive']);

    Route::get('/acceptance', [AcceptanceController::class, 'index']);
    Route::get('/acceptance/{acceptance}', [AcceptanceController::class, 'show']);
    Route::post('/projects/{project}/acceptance', [AcceptanceController::class, 'store']);
    Route::post('/acceptance/{acceptance}/submit', [AcceptanceController::class, 'submit']);
    Route::post('/acceptance/{acceptance}/reviews', [AcceptanceController::class, 'review']);
    Route::post('/acceptance/{acceptance}/files', [AcceptanceController::class, 'uploadFile']);
    Route::post('/acceptance/{acceptance}/extensions', [AcceptanceController::class, 'extension']);

    Route::get('/lifecycle/task-books', [ProjectLifecycleController::class, 'taskBooks']);
    Route::post('/projects/{project}/task-books', [ProjectLifecycleController::class, 'storeTaskBook']);
    Route::put('/lifecycle/task-books/{taskBook}', [ProjectLifecycleController::class, 'updateTaskBook']);
    Route::post('/lifecycle/task-books/{taskBook}/submit', [ProjectLifecycleController::class, 'submitTaskBook']);
    Route::post('/lifecycle/task-books/{taskBook}/review', [ProjectLifecycleController::class, 'reviewTaskBook']);
    Route::get('/lifecycle/progress', [ProjectLifecycleController::class, 'progress']);
    Route::post('/projects/{project}/progress', [ProjectLifecycleController::class, 'storeProgress']);
    Route::put('/lifecycle/progress/{progress}', [ProjectLifecycleController::class, 'updateProgress']);
    Route::post('/lifecycle/progress/{progress}/submit', [ProjectLifecycleController::class, 'submitProgress']);
    Route::post('/lifecycle/progress/{progress}/review', [ProjectLifecycleController::class, 'reviewProgress']);
    Route::get('/lifecycle/rectifications', [ProjectLifecycleController::class, 'rectifications']);
    Route::post('/projects/{project}/rectifications', [ProjectLifecycleController::class, 'storeRectification']);
    Route::post('/lifecycle/rectifications/{rectification}/submit', [ProjectLifecycleController::class, 'submitRectification']);
    Route::post('/lifecycle/rectifications/{rectification}/review', [ProjectLifecycleController::class, 'reviewRectification']);
    Route::get('/lifecycle/expert-certifications', [ProjectLifecycleController::class, 'expertCertifications']);
    Route::post('/lifecycle/expert-certifications', [ProjectLifecycleController::class, 'storeExpertCertification']);
    Route::post('/lifecycle/expert-certifications/{certification}/review', [ProjectLifecycleController::class, 'reviewExpertCertification']);

    Route::post('/projects/{project}/files', [FileController::class, 'store']);
    Route::get('/files/{file}/download', [FileController::class, 'download']);
    Route::delete('/files/{file}', [FileController::class, 'destroy']);

    Route::get('/reviews/tasks', [ReviewController::class, 'tasks']);
    Route::get('/reviews/results', [ReviewController::class, 'results']);
    Route::get('/reviews/tasks/export.csv', [ReviewExportController::class, 'tasksCsv']);
    Route::get('/reviews/results/export.csv', [ReviewExportController::class, 'resultsCsv']);
    Route::post('/projects/{project}/reviews', [ReviewController::class, 'store']);

    Route::get('/settings', [SystemSettingController::class, 'index']);
    Route::get('/settings/runtime', [SystemSettingController::class, 'runtime']);
    Route::get('/settings/groups', [SystemSettingController::class, 'groups']);
    Route::put('/settings/groups/{group}', [SystemSettingController::class, 'updateGroup']);
    Route::post('/settings/mail/test', [SystemSettingController::class, 'testMail']);
    Route::put('/settings/{setting}', [SystemSettingController::class, 'update']);
    Route::get('/system-texts/export.csv', [SystemTextController::class, 'exportCsv']);
    Route::get('/system-texts', [SystemTextController::class, 'index']);
    Route::post('/system-texts', [SystemTextController::class, 'store']);
    Route::put('/system-texts/{systemText}', [SystemTextController::class, 'update']);
    Route::post('/system-texts/{systemText}/reset', [SystemTextController::class, 'reset']);
    Route::delete('/system-texts/{systemText}', [SystemTextController::class, 'destroy']);
    Route::get('/public-home', [PublicHomeAdminController::class, 'index']);
    Route::put('/public-home/sections/{section:key}', [PublicHomeAdminController::class, 'updateSection']);
    Route::post('/public-home/sections/{section:key}/asset', [PublicHomeAdminController::class, 'uploadAsset']);
    Route::delete('/public-home/sections/{section:key}/asset/{type}', [PublicHomeAdminController::class, 'deleteAsset']);
    Route::post('/public-home/items', [PublicHomeAdminController::class, 'storeItem']);
    Route::put('/public-home/items/{item}', [PublicHomeAdminController::class, 'updateItem']);
    Route::delete('/public-home/items/{item}', [PublicHomeAdminController::class, 'destroyItem']);
    Route::post('/public-home/items/{item}/file', [PublicHomeAdminController::class, 'uploadFile']);

    Route::get('/messages', [MessageController::class, 'index']);
    Route::post('/messages/read-all', [MessageController::class, 'markAllRead']);
    Route::post('/messages/{message}/read', [MessageController::class, 'markRead']);
    Route::get('/mail/templates', [MailCenterController::class, 'templates']);
    Route::post('/mail/templates', [MailCenterController::class, 'storeTemplate']);
    Route::put('/mail/templates/{template}', [MailCenterController::class, 'updateTemplate']);
    Route::get('/mail/logs', [MailCenterController::class, 'logs']);
    Route::post('/mail/logs/{log}/retry', [MailCenterController::class, 'retry']);
    Route::get('/roles', [RbacController::class, 'roles']);
    Route::post('/roles', [RbacController::class, 'storeRole']);
    Route::put('/roles/{role}', [RbacController::class, 'updateRole']);
    Route::get('/permissions', [RbacController::class, 'permissions']);
    Route::put('/roles/{role}/permissions', [RbacController::class, 'updatePermissions']);
    Route::put('/users/{user}/roles', [RbacController::class, 'updateUserRoles']);
    Route::get('/security/events', [SecurityController::class, 'events']);
    Route::get('/security/blocked-identities', [SecurityController::class, 'blockedIdentities']);
    Route::post('/security/blocked-identities', [SecurityController::class, 'storeBlockedIdentity']);
    Route::delete('/security/blocked-identities/{id}', [SecurityController::class, 'destroyBlockedIdentity']);
    Route::get('/security/policies', [SecurityController::class, 'policies']);
    Route::put('/security/policies', [SecurityController::class, 'updatePolicies']);
    Route::post('/security/locks/{lock}/release', [SecurityController::class, 'releaseLock']);
    Route::get('/dictionaries', [DictionaryController::class, 'index']);
    Route::apiResource('dictionary-items', DictionaryItemController::class)->except(['destroy']);
    Route::get('/users/export.csv', [UserExportController::class, 'csv']);
    Route::put('/users/{user}/password', [UserController::class, 'resetPassword']);
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
