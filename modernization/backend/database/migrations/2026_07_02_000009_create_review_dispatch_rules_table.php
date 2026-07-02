<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('review_dispatch_rules', function (Blueprint $table): void {
            $table->id();
            $table->string('name', 160);
            $table->string('target_stage', 40)->index();
            $table->string('management_unit', 120)->nullable()->index();
            $table->string('project_field', 120)->nullable()->index();
            $table->string('research_direction', 120)->nullable()->index();
            $table->string('project_category', 120)->nullable()->index();
            $table->string('project_type', 120)->nullable()->index();
            $table->longText('recommended_user_ids')->nullable();
            $table->boolean('auto_assign')->default(false)->index();
            $table->boolean('is_active')->default(true)->index();
            $table->unsignedInteger('priority')->default(100)->index();
            $table->text('remark')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('review_dispatch_rules');
    }
};
