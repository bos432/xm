<?php

use App\Models\ApplicationBatch;
use App\Models\DictionaryItem;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Hash;

$app = require __DIR__.'/isolated-app.php';
$app->make(Kernel::class)->bootstrap();
if (User::query()->getConnection()->getSchemaBuilder()->hasTable('users')) {
    throw new RuntimeException('Refusing to reseed an existing isolated database. Use a new run ID.');
}
Artisan::call('migrate', ['--force' => true, '--no-interaction' => true]);
$unit = Unit::create(['name' => 'QA Isolated Applicant', 'credit_code' => 'QA-ISOLATED-'.bin2hex(random_bytes(6)), 'status' => 'active']);
$accounts = [];
foreach (['unit', 'county', 'department', 'expert', 'expert_2', 'expert_3', 'admin', 'super_admin'] as $label) {
    $role = str_starts_with($label, 'expert') ? 'expert' : $label;
    $password = 'Qa-'.bin2hex(random_bytes(18));
    $user = User::create([
        'name' => 'QA '.$label, 'username' => 'qa_'.$label,
        'email' => 'qa_'.$label.'@example.invalid', 'password' => Hash::make($password),
        'role' => $role, 'unit_id' => $role === 'unit' ? $unit->id : null,
        'is_active' => true, 'metadata' => ['e2e' => true],
    ]);
    $accounts[$label] = ['id' => $user->id, 'username' => $user->username, 'password' => $password, 'role' => $role];
}
$batch = ApplicationBatch::create([
    'name' => 'QA Isolated Browser Batch', 'code' => 'QA-ISOLATED-BROWSER',
    'status' => 'open', 'starts_at' => now()->subDay(), 'ends_at' => now()->addWeek(),
    'metadata' => ['acceptance_required_materials' => ['acceptance_application', 'financial']],
]);
foreach ([['quality', 'Quality', 35], ['innovation', 'Innovation', 35], ['impact', 'Impact', 30]] as [$code, $label, $max]) {
    DictionaryItem::create(['group' => 'expert_review_criterion', 'code' => $code, 'label' => $label, 'is_active' => true, 'sort_order' => $max, 'metadata' => ['max_score' => $max]]);
}
foreach (['project_category' => 'QA Category', 'project_type' => 'QA Type'] as $group => $label) {
    DictionaryItem::create(['group' => $group, 'code' => $group.'_qa', 'label' => $label, 'is_active' => true, 'sort_order' => 1]);
}
$manifest = ['base_url' => 'http://127.0.0.1:18742', 'batch_id' => $batch->id, 'accounts' => $accounts];
$file = getenv('NXM_QA_SANDBOX').'/credentials.json';
file_put_contents($file, json_encode($manifest, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
chmod($file, 0600);
echo json_encode(['status' => 'ready', 'database_driver' => 'sqlite', 'accounts' => count($accounts), 'batch_id' => $batch->id, 'external_delivery' => false]).PHP_EOL;
