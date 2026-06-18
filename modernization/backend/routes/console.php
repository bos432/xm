<?php

use Illuminate\Support\Facades\Artisan;

Artisan::command('system:modernization-summary', function () {
    $this->info('Project Application System modernization workspace is installed.');
});

