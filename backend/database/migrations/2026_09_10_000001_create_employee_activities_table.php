<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('employee_activities', function (Blueprint $table) {
            $table->bigIncrements('id');
            $table->string('request_id', 100)->unique();
            $table->string('user_id');
            $table->foreign('user_id')->references('id')->on('users');
            $table->text('note');
            $table->text('photo_url')->nullable();
            $table->boolean('is_finished')->default(false);
            $table->timestamp('started_at');
            $table->timestamps();
            $table->index(['user_id', 'id']);
            $table->index('created_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('employee_activities');
    }
};
