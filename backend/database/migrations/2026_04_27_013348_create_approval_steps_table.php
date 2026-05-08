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
        Schema::create('approval_steps', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->string('module', 32);
            $table->string('reference_id');
            $table->unsignedInteger('sequence');
            $table->string('approver_role', 32);
            $table->string('approver_id')->index();
            $table->string('approver_name');
            $table->string('status', 32)->default('pending')->index();
            $table->text('note')->nullable();
            $table->dateTime('acted_at')->nullable();
            $table->timestamps();

            $table->index(['module', 'reference_id']);
            $table->unique(['module', 'reference_id', 'sequence']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('approval_steps');
    }
};
