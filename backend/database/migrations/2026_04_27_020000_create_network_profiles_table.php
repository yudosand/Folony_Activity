<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('network_profiles', function (Blueprint $table): void {
            $table->string('id')->primary();
            $table->string('owner_id');
            $table->string('owner_name');
            $table->string('owner_role');
            $table->string('area_name');
            $table->string('type');
            $table->string('name');
            $table->text('address');
            $table->string('business_type');
            $table->string('phone_number');
            $table->string('status');
            $table->string('reference_name')->nullable();
            $table->text('note')->nullable();
            $table->json('photo_attachment')->nullable();
            $table->json('personality_metrics')->nullable();
            $table->json('documents')->nullable();
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->timestamps();

            $table->foreign('owner_id')->references('id')->on('users')->cascadeOnDelete();
            $table->index(['owner_id', 'type']);
            $table->index(['owner_role', 'area_name', 'type']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('network_profiles');
    }
};
