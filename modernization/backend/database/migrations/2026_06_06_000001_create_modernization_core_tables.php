<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('units', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('legacy_id')->nullable()->index();
            $table->string('name', 200);
            $table->string('credit_code', 80)->nullable()->index();
            $table->string('contact_name', 100)->nullable();
            $table->string('contact_mobile', 40)->nullable();
            $table->string('email', 120)->nullable();
            $table->string('address', 500)->nullable();
            $table->string('region_code', 50)->nullable()->index();
            $table->string('status', 40)->default('active')->index();
            $table->json('metadata')->nullable();
            $table->timestamps();
        });

        Schema::create('users', function (Blueprint $table) {
            $table->id();
            $table->foreignId('unit_id')->nullable()->constrained()->nullOnDelete();
            $table->string('name', 100);
            $table->string('username', 100)->unique();
            $table->string('email', 120)->nullable()->unique();
            $table->string('mobile', 40)->nullable();
            $table->string('password');
            $table->string('role', 40)->index();
            $table->boolean('is_active')->default(true);
            $table->timestamp('last_login_at')->nullable()->index();
            $table->string('last_login_ip', 80)->nullable();
            $table->rememberToken();
            $table->timestamps();
        });

        Schema::create('personal_access_tokens', function (Blueprint $table) {
            $table->id();
            $table->morphs('tokenable');
            $table->string('name');
            $table->string('token', 64)->unique();
            $table->text('abilities')->nullable();
            $table->timestamp('last_used_at')->nullable();
            $table->timestamp('expires_at')->nullable()->index();
            $table->timestamps();
        });

        Schema::create('projects', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('legacy_id')->nullable()->index();
            $table->foreignId('unit_id')->constrained()->restrictOnDelete();
            $table->foreignId('owner_id')->constrained('users')->restrictOnDelete();
            $table->string('title', 200);
            $table->string('category', 100)->nullable()->index();
            $table->string('project_type', 100)->nullable()->index();
            $table->string('status', 40)->default('draft')->index();
            $table->text('summary')->nullable();
            $table->decimal('budget_amount', 14, 2)->nullable();
            $table->timestamp('submitted_at')->nullable();
            $table->string('current_reviewer_role', 40)->nullable()->index();
            $table->json('metadata')->nullable();
            $table->timestamps();
        });

        Schema::create('project_files', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('legacy_id')->nullable()->index();
            $table->foreignId('project_id')->constrained()->cascadeOnDelete();
            $table->foreignId('uploaded_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('disk', 40);
            $table->string('path', 600);
            $table->string('original_name', 255);
            $table->string('mime_type', 150)->nullable();
            $table->string('extension', 20)->index();
            $table->unsignedBigInteger('size_bytes')->default(0);
            $table->string('sha256', 64)->nullable()->index();
            $table->string('purpose', 80)->default('application')->index();
            $table->json('metadata')->nullable();
            $table->timestamps();
        });

        Schema::create('project_reviews', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('legacy_id')->nullable()->index();
            $table->foreignId('project_id')->constrained()->cascadeOnDelete();
            $table->foreignId('reviewer_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('stage', 60)->index();
            $table->string('decision', 40)->index();
            $table->decimal('score', 5, 2)->nullable();
            $table->text('comment')->nullable();
            $table->timestamp('reviewed_at')->nullable()->index();
            $table->json('metadata')->nullable();
            $table->timestamps();
        });

        Schema::create('system_settings', function (Blueprint $table) {
            $table->id();
            $table->string('key', 120)->unique();
            $table->text('value')->nullable();
            $table->string('group', 80)->default('general')->index();
            $table->boolean('is_secret')->default(false);
            $table->string('description', 500)->nullable();
            $table->timestamps();
        });

        Schema::create('dictionary_items', function (Blueprint $table) {
            $table->id();
            $table->string('group', 80)->index();
            $table->string('code', 100);
            $table->string('label', 200);
            $table->unsignedInteger('sort_order')->default(0);
            $table->boolean('is_active')->default(true)->index();
            $table->json('metadata')->nullable();
            $table->timestamps();
            $table->unique(['group', 'code']);
        });

        Schema::create('messages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('recipient_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('project_id')->nullable()->constrained()->nullOnDelete();
            $table->string('type', 80)->default('system')->index();
            $table->string('title', 200);
            $table->text('body')->nullable();
            $table->timestamp('read_at')->nullable()->index();
            $table->json('metadata')->nullable();
            $table->timestamps();
        });

        Schema::create('operation_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->string('action', 120)->index();
            $table->string('target_type', 120)->nullable()->index();
            $table->unsignedBigInteger('target_id')->nullable()->index();
            $table->string('ip_address', 80)->nullable();
            $table->string('user_agent', 500)->nullable();
            $table->json('payload')->nullable();
            $table->timestamps();
        });

        Schema::create('migration_batches', function (Blueprint $table) {
            $table->id();
            $table->string('name', 160);
            $table->string('mode', 40)->default('dry_run')->index();
            $table->string('source_path', 600);
            $table->string('status', 40)->default('pending')->index();
            $table->timestamp('started_at')->nullable();
            $table->timestamp('finished_at')->nullable();
            $table->json('summary')->nullable();
            $table->json('metadata')->nullable();
            $table->timestamps();
        });

        Schema::create('migration_batch_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('migration_batch_id')->constrained()->cascadeOnDelete();
            $table->string('legacy_table', 120)->index();
            $table->string('target_table', 120)->nullable()->index();
            $table->string('status', 40)->default('pending')->index();
            $table->boolean('create_found')->default(false);
            $table->unsignedInteger('insert_statement_count')->default(0);
            $table->unsignedInteger('estimated_row_count')->default(0);
            $table->unsignedInteger('warning_count')->default(0);
            $table->json('metadata')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('migration_batch_items');
        Schema::dropIfExists('migration_batches');
        Schema::dropIfExists('operation_logs');
        Schema::dropIfExists('messages');
        Schema::dropIfExists('dictionary_items');
        Schema::dropIfExists('system_settings');
        Schema::dropIfExists('project_reviews');
        Schema::dropIfExists('project_files');
        Schema::dropIfExists('projects');
        Schema::dropIfExists('personal_access_tokens');
        Schema::dropIfExists('users');
        Schema::dropIfExists('units');
    }
};
