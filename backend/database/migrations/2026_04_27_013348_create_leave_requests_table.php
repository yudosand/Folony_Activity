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
        Schema::create('leave_requests', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->string('requester_id')->index();
            $table->string('requester_name');
            $table->string('requester_role', 32);
            $table->string('category', 32);
            $table->string('compensation_option', 32);
            $table->dateTime('start_at');
            $table->dateTime('end_at')->nullable();
            $table->decimal('duration_value', 8, 2);
            $table->text('reason');
            $table->string('delegate_to')->nullable();
            $table->string('status', 32)->default('pending')->index();
            $table->text('note')->nullable();
            $table->dateTime('submitted_at')->index();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('leave_requests');
    }
};
