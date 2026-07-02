<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('review_dispatch_rules', function (Blueprint $table): void {
            $table->unsignedInteger('expert_count')->nullable()->after('recommended_user_ids');
        });
    }

    public function down(): void
    {
        Schema::table('review_dispatch_rules', function (Blueprint $table): void {
            $table->dropColumn('expert_count');
        });
    }
};
