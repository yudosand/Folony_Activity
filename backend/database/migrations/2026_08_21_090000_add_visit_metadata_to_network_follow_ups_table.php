<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('network_follow_ups', function (Blueprint $table): void {
            $table->timestamp('visit_started_at')->nullable()->after('note');
            $table->timestamp('visit_finished_at')->nullable()->after('visit_started_at');
            $table->unsignedInteger('visit_duration_seconds')->nullable()->after('visit_finished_at');
            $table->json('photo_attachment')->nullable()->after('visit_duration_seconds');
        });
    }

    public function down(): void
    {
        Schema::table('network_follow_ups', function (Blueprint $table): void {
            $table->dropColumn([
                'visit_started_at',
                'visit_finished_at',
                'visit_duration_seconds',
                'photo_attachment',
            ]);
        });
    }
};
