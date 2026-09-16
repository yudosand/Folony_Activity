<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('fgg_accounts', function (Blueprint $table) {
            $table->id();
            $table->string('user_id');
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->string('environment', 20);
            $table->string('member_id');
            $table->string('name');
            $table->text('token')->nullable();
            $table->json('hubs');
            $table->string('hub_id')->nullable();
            $table->timestamps();
            $table->unique(['user_id', 'environment']);
        });
        Schema::create('fgg_operations', function (Blueprint $table) {
            $table->id();
            $table->string('user_id');
            $table->string('environment', 20);
            $table->string('member_id');
            $table->string('hub_id');
            $table->string('action', 20);
            $table->string('target', 100);
            $table->string('state', 20)->default('pending');
            $table->timestamps();
            $table->unique(['environment', 'member_id', 'action', 'target'], 'fgg_operation_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('fgg_operations');
        Schema::dropIfExists('fgg_accounts');
    }
};
