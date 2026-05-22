<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('performance_targets', function (Blueprint $table): void {
            $table->id();
            $table->string('user_id');
            $table->string('metric_key', 80);
            $table->unsignedSmallInteger('period_year');
            $table->unsignedTinyInteger('period_month');
            $table->unsignedInteger('target_value');
            $table->string('created_by')->nullable();
            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('created_by')->references('id')->on('users')->nullOnDelete();
            $table->unique(
                ['user_id', 'metric_key', 'period_year', 'period_month'],
                'performance_targets_user_metric_period_unique',
            );
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('performance_targets');
    }
};
