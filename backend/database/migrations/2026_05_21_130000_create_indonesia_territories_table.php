<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('indonesia_territories', function (Blueprint $table): void {
            $table->id();
            $table->string('code', 16)->unique();
            $table->string('level', 24);
            $table->string('name', 120);
            $table->string('normalized_name', 120);
            $table->string('parent_code', 16)->nullable();
            $table->string('province_code', 16)->nullable();
            $table->string('city_code', 16)->nullable();
            $table->string('district_code', 16)->nullable();
            $table->string('province_name', 120)->nullable();
            $table->string('city_name', 120)->nullable();
            $table->string('district_name', 120)->nullable();
            $table->timestamps();

            $table->index(['level', 'province_code'], 'territories_level_province_index');
            $table->index(['level', 'city_code'], 'territories_level_city_index');
            $table->index(['level', 'district_code'], 'territories_level_district_index');
            $table->index(['level', 'parent_code'], 'territories_level_parent_index');
            $table->index(['level', 'normalized_name'], 'territories_level_name_index');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('indonesia_territories');
    }
};
