<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('roles', function (Blueprint $table) {
            $table->id();
            $table->string('code', 80)->unique();
            $table->string('name', 120);
            $table->string('description', 500)->nullable();
            $table->boolean('is_builtin')->default(false)->index();
            $table->boolean('is_active')->default(true)->index();
            $table->timestamps();
        });

        Schema::create('permissions', function (Blueprint $table) {
            $table->id();
            $table->string('code', 120)->unique();
            $table->string('name', 160);
            $table->string('group', 80)->default('general')->index();
            $table->string('description', 500)->nullable();
            $table->timestamps();
        });

        Schema::create('permission_role', function (Blueprint $table) {
            $table->id();
            $table->foreignId('role_id')->constrained('roles')->cascadeOnDelete();
            $table->foreignId('permission_id')->constrained('permissions')->cascadeOnDelete();
            $table->timestamps();
            $table->unique(['role_id', 'permission_id']);
        });

        Schema::create('role_user', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('role_id')->constrained('roles')->cascadeOnDelete();
            $table->foreignId('assigned_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->unique(['user_id', 'role_id']);
        });

        Schema::create('application_batches', function (Blueprint $table) {
            $table->id();
            $table->string('name', 200);
            $table->string('code', 80)->unique();
            $table->timestamp('starts_at')->nullable()->index();
            $table->timestamp('ends_at')->nullable()->index();
            $table->string('status', 40)->default('draft')->index();
            $table->longText('allowed_categories')->nullable();
            $table->longText('allowed_project_types')->nullable();
            $table->longText('guide')->nullable();
            $table->longText('attachment_requirements')->nullable();
            $table->longText('metadata')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });

        Schema::table('projects', function (Blueprint $table) {
            if (! Schema::hasColumn('projects', 'application_batch_id')) {
                $table->foreignId('application_batch_id')
                    ->nullable()
                    ->after('owner_id')
                    ->constrained('application_batches')
                    ->nullOnDelete();
            }
        });

        Schema::create('acceptance_applications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('project_id')->constrained('projects')->cascadeOnDelete();
            $table->foreignId('unit_id')->constrained('units')->restrictOnDelete();
            $table->foreignId('submitted_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('status', 40)->default('draft')->index();
            $table->string('current_reviewer_role', 40)->nullable()->index();
            $table->text('summary')->nullable();
            $table->timestamp('submitted_at')->nullable()->index();
            $table->timestamp('closed_at')->nullable()->index();
            $table->longText('metadata')->nullable();
            $table->timestamps();
        });

        Schema::create('acceptance_reviews', function (Blueprint $table) {
            $table->id();
            $table->foreignId('acceptance_application_id')->constrained('acceptance_applications')->cascadeOnDelete();
            $table->foreignId('reviewer_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('stage', 60)->index();
            $table->string('decision', 40)->index();
            $table->decimal('score', 5, 2)->nullable();
            $table->text('comment')->nullable();
            $table->timestamp('reviewed_at')->nullable()->index();
            $table->longText('metadata')->nullable();
            $table->timestamps();
        });

        Schema::create('acceptance_extensions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('acceptance_application_id')->nullable()->constrained('acceptance_applications')->cascadeOnDelete();
            $table->foreignId('project_id')->constrained('projects')->cascadeOnDelete();
            $table->foreignId('requested_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('status', 40)->default('pending')->index();
            $table->text('reason');
            $table->date('expected_date')->nullable();
            $table->text('review_comment')->nullable();
            $table->timestamp('reviewed_at')->nullable()->index();
            $table->longText('metadata')->nullable();
            $table->timestamps();
        });

        Schema::create('mail_templates', function (Blueprint $table) {
            $table->id();
            $table->string('key', 120)->unique();
            $table->string('name', 160);
            $table->string('subject', 255);
            $table->longText('body');
            $table->boolean('is_active')->default(true)->index();
            $table->boolean('is_builtin')->default(false)->index();
            $table->longText('metadata')->nullable();
            $table->timestamps();
        });

        Schema::create('mail_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('mail_template_id')->nullable()->constrained('mail_templates')->nullOnDelete();
            $table->string('template_key', 120)->nullable()->index();
            $table->string('to_address', 191)->index();
            $table->string('to_name', 160)->nullable();
            $table->string('subject', 255);
            $table->longText('body');
            $table->string('status', 40)->default('queued')->index();
            $table->text('error')->nullable();
            $table->unsignedInteger('retry_count')->default(0);
            $table->timestamp('queued_at')->nullable()->index();
            $table->timestamp('sent_at')->nullable()->index();
            $table->foreignId('triggered_by')->nullable()->constrained('users')->nullOnDelete();
            $table->longText('metadata')->nullable();
            $table->timestamps();
        });

        Schema::create('security_events', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('type', 120)->index();
            $table->string('severity', 40)->default('info')->index();
            $table->string('username', 120)->nullable()->index();
            $table->string('ip_address', 80)->nullable()->index();
            $table->string('user_agent', 500)->nullable();
            $table->longText('payload')->nullable();
            $table->timestamps();
        });

        Schema::create('security_locks', function (Blueprint $table) {
            $table->id();
            $table->string('identity_type', 40)->index();
            $table->string('identity_value', 160)->index();
            $table->unsignedInteger('failed_count')->default(0);
            $table->string('reason', 160)->nullable();
            $table->boolean('is_active')->default(true)->index();
            $table->timestamp('locked_until')->nullable()->index();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });

        Schema::create('security_ip_rules', function (Blueprint $table) {
            $table->id();
            $table->string('type', 40)->index();
            $table->string('cidr', 80)->index();
            $table->string('description', 500)->nullable();
            $table->boolean('is_active')->default(true)->index();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });

        $batchId = DB::table('application_batches')->insertGetId([
            'name' => '历史默认批次',
            'code' => 'HISTORY-DEFAULT',
            'status' => 'open',
            'starts_at' => now()->subYears(10),
            'ends_at' => now()->addYears(10),
            'guide' => '历史项目自动归集批次，用于兼容迁移前已存在的申报项目。',
            'attachment_requirements' => '沿用原项目材料要求。',
            'metadata' => json_encode(['system_default' => true], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('projects')->whereNull('application_batch_id')->update(['application_batch_id' => $batchId]);
        DB::table('users')->where('role', 'admin')->update(['role' => 'super_admin']);

        DB::table('projects')
            ->whereNotNull('metadata')
            ->orderBy('id')
            ->get(['id', 'metadata'])
            ->each(function ($project): void {
                $metadata = json_decode((string) $project->metadata, true);
                if (! is_array($metadata) || ! is_array($metadata['extension_requests'] ?? null)) {
                    return;
                }

                foreach ($metadata['extension_requests'] as $request) {
                    if (! is_array($request) || blank($request['reason'] ?? null)) {
                        continue;
                    }

                    DB::table('acceptance_extensions')->insert([
                        'project_id' => $project->id,
                        'requested_by' => null,
                        'reviewed_by' => null,
                        'status' => $request['status'] ?? 'pending',
                        'reason' => $request['reason'],
                        'expected_date' => $request['expected_date'] ?? null,
                        'review_comment' => $request['review_comment'] ?? null,
                        'reviewed_at' => $request['reviewed_at'] ?? null,
                        'metadata' => json_encode([
                            'legacy_metadata' => true,
                            'legacy_requested_by' => $request['requested_by'] ?? null,
                            'legacy_reviewed_by' => $request['reviewed_by'] ?? null,
                        ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
                        'created_at' => $request['requested_at'] ?? now(),
                        'updated_at' => now(),
                    ]);
                }
            });
    }

    public function down(): void
    {
        Schema::dropIfExists('security_ip_rules');
        Schema::dropIfExists('security_locks');
        Schema::dropIfExists('security_events');
        Schema::dropIfExists('mail_logs');
        Schema::dropIfExists('mail_templates');
        Schema::dropIfExists('acceptance_extensions');
        Schema::dropIfExists('acceptance_reviews');
        Schema::dropIfExists('acceptance_applications');

        Schema::table('projects', function (Blueprint $table) {
            if (Schema::hasColumn('projects', 'application_batch_id')) {
                $table->dropConstrainedForeignId('application_batch_id');
            }
        });

        Schema::dropIfExists('application_batches');
        Schema::dropIfExists('role_user');
        Schema::dropIfExists('permission_role');
        Schema::dropIfExists('permissions');
        Schema::dropIfExists('roles');
    }
};
