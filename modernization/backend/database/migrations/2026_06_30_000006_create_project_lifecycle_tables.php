<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('project_task_books', function (Blueprint $table) {
            $table->id();
            $table->foreignId('project_id')->constrained('projects')->cascadeOnDelete();
            $table->foreignId('unit_id')->constrained('units')->restrictOnDelete();
            $table->foreignId('submitted_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('status', 40)->default('draft')->index();
            $table->string('title', 200);
            $table->longText('content')->nullable();
            $table->timestamp('submitted_at')->nullable()->index();
            $table->timestamp('reviewed_at')->nullable()->index();
            $table->text('review_comment')->nullable();
            $table->longText('metadata')->nullable();
            $table->timestamps();
        });

        Schema::create('project_progress_records', function (Blueprint $table) {
            $table->id();
            $table->foreignId('project_id')->constrained('projects')->cascadeOnDelete();
            $table->foreignId('unit_id')->constrained('units')->restrictOnDelete();
            $table->foreignId('submitted_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('status', 40)->default('draft')->index();
            $table->string('period', 120)->nullable();
            $table->date('progress_date')->nullable()->index();
            $table->longText('summary')->nullable();
            $table->longText('issues')->nullable();
            $table->longText('next_plan')->nullable();
            $table->timestamp('submitted_at')->nullable()->index();
            $table->timestamp('reviewed_at')->nullable()->index();
            $table->text('review_comment')->nullable();
            $table->longText('metadata')->nullable();
            $table->timestamps();
        });

        Schema::create('project_rectifications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('project_id')->constrained('projects')->cascadeOnDelete();
            $table->foreignId('acceptance_application_id')->nullable()->constrained('acceptance_applications')->nullOnDelete();
            $table->foreignId('unit_id')->constrained('units')->restrictOnDelete();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('submitted_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('status', 40)->default('pending')->index();
            $table->string('title', 200);
            $table->longText('requirement')->nullable();
            $table->longText('response')->nullable();
            $table->date('due_date')->nullable()->index();
            $table->timestamp('submitted_at')->nullable()->index();
            $table->timestamp('reviewed_at')->nullable()->index();
            $table->text('review_comment')->nullable();
            $table->longText('metadata')->nullable();
            $table->timestamps();
        });

        Schema::create('expert_certifications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('submitted_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('status', 40)->default('draft')->index();
            $table->string('organization', 200)->nullable();
            $table->string('specialty', 200)->nullable();
            $table->string('professional_title', 160)->nullable();
            $table->string('certificate_no', 160)->nullable();
            $table->longText('summary')->nullable();
            $table->timestamp('submitted_at')->nullable()->index();
            $table->timestamp('reviewed_at')->nullable()->index();
            $table->text('review_comment')->nullable();
            $table->longText('metadata')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('expert_certifications');
        Schema::dropIfExists('project_rectifications');
        Schema::dropIfExists('project_progress_records');
        Schema::dropIfExists('project_task_books');
    }
};
