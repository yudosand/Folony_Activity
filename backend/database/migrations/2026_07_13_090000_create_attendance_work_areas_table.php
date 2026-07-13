<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('attendance_work_areas', function (Blueprint $table): void {
            $table->string('id')->primary();
            $table->string('name');
            $table->decimal('latitude', 10, 7);
            $table->decimal('longitude', 10, 7);
            $table->unsignedInteger('radius_meters')->default(1000);
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->unique('name');
        });

        DB::table('attendance_work_areas')->insert([
            'id' => 'work_area_ho',
            'name' => 'Kantor Pusat',
            'latitude' => -6.1596929,
            'longitude' => 106.8180445,
            'radius_meters' => 1000,
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        Schema::table('users', function (Blueprint $table): void {
            $table->string('attendance_work_area_id')->nullable()->after('work_location');
            $table->index('attendance_work_area_id', 'users_attendance_work_area_id_index');
        });

        DB::table('users')
            ->whereNull('attendance_work_area_id')
            ->update(['attendance_work_area_id' => 'work_area_ho']);
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->dropIndex('users_attendance_work_area_id_index');
            $table->dropColumn('attendance_work_area_id');
        });

        Schema::dropIfExists('attendance_work_areas');
    }
};
