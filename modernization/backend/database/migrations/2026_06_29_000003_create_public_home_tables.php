<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('public_home_sections', function (Blueprint $table) {
            $table->id();
            $table->string('key', 80)->unique();
            $table->string('title', 200)->nullable();
            $table->string('eyebrow', 200)->nullable();
            $table->longText('body')->nullable();
            $table->longText('metadata')->nullable();
            $table->boolean('is_active')->default(true)->index();
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });

        Schema::create('public_home_items', function (Blueprint $table) {
            $table->id();
            $table->string('section', 80)->index();
            $table->string('title', 255)->nullable();
            $table->string('label', 200)->nullable();
            $table->string('value', 200)->nullable();
            $table->string('code', 50)->nullable();
            $table->text('summary')->nullable();
            $table->longText('body')->nullable();
            $table->string('href', 600)->nullable();
            $table->timestamp('published_at')->nullable()->index();
            $table->unsignedInteger('sort_order')->default(0)->index();
            $table->boolean('is_active')->default(true)->index();
            $table->string('file_disk', 40)->nullable();
            $table->string('file_path', 600)->nullable();
            $table->string('file_original_name', 255)->nullable();
            $table->string('file_mime_type', 150)->nullable();
            $table->string('file_extension', 20)->nullable()->index();
            $table->unsignedBigInteger('file_size_bytes')->nullable();
            $table->string('file_sha256', 64)->nullable()->index();
            $table->string('legacy_source', 120)->nullable()->index();
            $table->unsignedBigInteger('legacy_id')->nullable()->index();
            $table->longText('metadata')->nullable();
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->unique(['legacy_source', 'legacy_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('public_home_items');
        Schema::dropIfExists('public_home_sections');
    }
};
