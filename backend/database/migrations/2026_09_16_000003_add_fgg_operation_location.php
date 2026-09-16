<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('fgg_operations', function (Blueprint $table) {
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->decimal('accuracy_meters', 10, 2)->nullable();
            $table->timestamp('captured_at')->nullable();
        });
    }
    public function down(): void
    {
        Schema::table('fgg_operations', fn (Blueprint $table) => $table->dropColumn(['latitude', 'longitude', 'accuracy_meters', 'captured_at']));
    }
};
