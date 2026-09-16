<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('fgg_delivery_trips', function (Blueprint $table) {
            $table->id();
            $table->string('environment', 20);
            $table->string('member_id', 100);
            $table->string('hub_id', 100);
            $table->string('user_id');
            $table->string('target', 100);
            $table->text('destination_address');
            $table->timestamp('started_at');
            $table->timestamp('arrived_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->json('start_location');
            $table->json('arrival_location')->nullable();
            $table->timestamps();
            $table->unique(['environment', 'member_id', 'target'], 'fgg_trip_order_unique');
            $table->index(['user_id', 'started_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('fgg_delivery_trips');
    }
};
