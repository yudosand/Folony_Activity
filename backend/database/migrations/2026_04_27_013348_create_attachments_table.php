<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('attachments', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->string('module', 32);
            $table->string('reference_id');
            $table->string('file_name');
            $table->string('mime_type', 100);
            $table->string('url')->nullable();
            $table->string('thumbnail_url')->nullable();
            $table->unsignedBigInteger('size_in_bytes')->nullable();
            $table->timestamps();

            $table->index(['module', 'reference_id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('attachments');
    }
};
