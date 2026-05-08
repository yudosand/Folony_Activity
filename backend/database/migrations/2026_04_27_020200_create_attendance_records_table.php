<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('attendance_records', function (Blueprint $table): void {
            $table->string('id')->primary();
            $table->string('user_id');
            $table->date('work_date');
            $table->string('action');
            $table->string('status');
            $table->timestamp('recorded_at');
            $table->json('location');
            $table->json('verification')->nullable();
            $table->text('note')->nullable();
            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->index(['user_id', 'work_date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('attendance_records');
    }
};
