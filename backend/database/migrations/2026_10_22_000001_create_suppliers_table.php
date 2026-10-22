<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('suppliers', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('created_by');
            $table->foreign('created_by')->references('id')->on('users')->restrictOnDelete();
            $table->string('name');
            $table->string('phone_number', 32);
            $table->string('territory_province')->index();
            $table->string('territory_city')->index();
            $table->string('territory_district')->index();
            $table->text('address');
            $table->string('location_source', 16)->default('manual');
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->json('items');
            $table->text('notes')->nullable();
            $table->timestamps();
            $table->index(['created_by', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('suppliers');
    }
};
