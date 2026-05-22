<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('face_verification_logs', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->string('user_id');
            $table->string('face_profile_id')->nullable();
            $table->string('attendance_record_id')->nullable();
            $table->string('action');
            $table->string('result');
            $table->decimal('match_score', 5, 2)->nullable();
            $table->decimal('liveness_score', 5, 2)->nullable();
            $table->json('capture_attachment')->nullable();
            $table->json('metadata')->nullable();
            $table->timestamp('verified_at');
            $table->text('note')->nullable();
            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('face_profile_id')->references('id')->on('face_profiles')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('face_verification_logs');
    }
};
