<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('network_profiles', function (Blueprint $table): void {
            $table->string('territory_province', 120)->nullable()->after('area_name');
            $table->string('territory_city', 120)->nullable()->after('territory_province');
            $table->string('territory_district', 120)->nullable()->after('territory_city');
            $table->string('territory_subdistrict', 120)->nullable()->after('territory_district');

            $table->index(
                ['territory_province', 'territory_city', 'territory_district', 'territory_subdistrict'],
                'network_profiles_territory_index',
            );
        });

        DB::table('network_profiles')
            ->whereNotNull('area_name')
            ->update([
                'territory_city' => DB::raw('area_name'),
            ]);
    }

    public function down(): void
    {
        Schema::table('network_profiles', function (Blueprint $table): void {
            $table->dropIndex('network_profiles_territory_index');
            $table->dropColumn([
                'territory_province',
                'territory_city',
                'territory_district',
                'territory_subdistrict',
            ]);
        });
    }
};
