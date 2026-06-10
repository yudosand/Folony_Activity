<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('push_device_tokens', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('user_id');
            $table->string('platform', 32)->default('android');
            $table->text('token');
            $table->char('token_hash', 64);
            $table->string('device_name')->nullable();
            $table->string('app_version')->nullable();
            $table->timestamp('last_seen_at')->nullable();
            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->unique(['user_id', 'platform', 'token_hash'], 'push_device_tokens_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('push_device_tokens');
    }
};
