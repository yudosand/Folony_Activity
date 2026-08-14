<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('survey_responses', function (Blueprint $table): void {
            $table->decimal('latitude', 10, 7)->nullable()->after('territory_subdistrict');
            $table->decimal('longitude', 10, 7)->nullable()->after('latitude');
            $table->decimal('location_accuracy_meters', 8, 2)->nullable()->after('longitude');
        });
    }

    public function down(): void
    {
        Schema::table('survey_responses', function (Blueprint $table): void {
            $table->dropColumn([
                'latitude',
                'longitude',
                'location_accuracy_meters',
            ]);
        });
    }
};
