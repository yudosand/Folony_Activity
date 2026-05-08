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
        Schema::create('wfa_task_updates', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->string('wfa_request_id')->index();
            $table->string('created_by')->index();
            $table->text('message');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('wfa_task_updates');
    }
};
