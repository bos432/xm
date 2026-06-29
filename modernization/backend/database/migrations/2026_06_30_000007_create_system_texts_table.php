<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('system_texts', function (Blueprint $table) {
            $table->id();
            $table->string('key', 160)->unique();
            $table->string('group', 80)->default('通用')->index();
            $table->string('label', 160);
            $table->text('default_value')->nullable();
            $table->text('value')->nullable();
            $table->text('description')->nullable();
            $table->boolean('is_builtin')->default(false)->index();
            $table->boolean('is_active')->default(true)->index();
            $table->unsignedInteger('sort_order')->default(0)->index();
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('system_texts');
    }
};
