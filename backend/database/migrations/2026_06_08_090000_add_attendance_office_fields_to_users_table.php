<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->decimal('office_latitude', 10, 7)->nullable()->after('work_location');
            $table->decimal('office_longitude', 10, 7)->nullable()->after('office_latitude');
            $table->unsignedInteger('attendance_radius_meters')->nullable()->after('office_longitude');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->dropColumn([
                'office_latitude',
                'office_longitude',
                'attendance_radius_meters',
            ]);
        });
    }
};
