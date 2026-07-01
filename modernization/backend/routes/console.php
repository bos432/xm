<?php

use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

Artisan::command('system:modernization-summary', function () {
    $this->info('Project Application System modernization workspace is installed.');
});

Artisan::command('queue:failed-count', function () {
    $this->line(Schema::hasTable('failed_jobs') ? (string) DB::table('failed_jobs')->count() : '0');
});
