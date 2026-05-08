<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('network_follow_ups', function (Blueprint $table): void {
            $table->string('id')->primary();
            $table->string('network_profile_id');
            $table->string('title');
            $table->text('note');
            $table->string('actor_id');
            $table->string('actor_name');
            $table->timestamp('created_at');

            $table->foreign('network_profile_id')->references('id')->on('network_profiles')->cascadeOnDelete();
            $table->index(['network_profile_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('network_follow_ups');
    }
};
