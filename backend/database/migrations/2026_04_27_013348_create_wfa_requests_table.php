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
        Schema::create('wfa_requests', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->string('requester_id')->index();
            $table->string('requester_name');
            $table->string('requester_role', 32);
            $table->string('mode', 32);
            $table->string('compensation_mode', 32)->nullable();
            $table->dateTime('work_date')->index();
            $table->string('start_time', 5);
            $table->string('end_time', 5);
            $table->string('location_label');
            $table->text('reason');
            $table->text('initial_task');
            $table->string('status', 32)->default('pending')->index();
            $table->text('note')->nullable();
            $table->dateTime('submitted_at')->index();
            $table->dateTime('actual_start_at')->nullable();
            $table->dateTime('actual_end_at')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('wfa_requests');
    }
};
