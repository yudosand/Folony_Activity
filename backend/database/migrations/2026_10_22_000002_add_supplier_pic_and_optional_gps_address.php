<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('suppliers', function (Blueprint $table) {
            // Existing supplier records do not yet have a contact PIC.
            $table->string('pic_name')->nullable();
            $table->string('territory_province')->nullable()->change();
            $table->string('territory_city')->nullable()->change();
            $table->string('territory_district')->nullable()->change();
            $table->text('address')->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('suppliers', function (Blueprint $table) {
            $table->dropColumn('pic_name');
            // Keep GPS-only records readable; restoring NOT NULL would lose data.
        });
    }
};
