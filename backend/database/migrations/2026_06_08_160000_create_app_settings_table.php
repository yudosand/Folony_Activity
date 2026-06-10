<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('app_settings', function (Blueprint $table): void {
            $table->string('key')->primary();
            $table->text('value')->nullable();
        });

        DB::table('app_settings')->insert([
            ['key' => 'attendance.office_latitude', 'value' => '-6.159692890088879'],
            ['key' => 'attendance.office_longitude', 'value' => '106.81804453790896'],
            ['key' => 'attendance.office_radius_meters', 'value' => '1000'],
        ]);
    }

    public function down(): void
    {
        Schema::dropIfExists('app_settings');
    }
};
