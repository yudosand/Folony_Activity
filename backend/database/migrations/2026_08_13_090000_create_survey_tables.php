<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('survey_product_options', function (Blueprint $table): void {
            $table->string('id')->primary();
            $table->string('name');
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->unique('name');
        });

        Schema::create('survey_commodity_options', function (Blueprint $table): void {
            $table->string('id')->primary();
            $table->string('name');
            $table->string('unit')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->unique('name');
        });

        Schema::create('survey_responses', function (Blueprint $table): void {
            $table->string('id')->primary();
            $table->string('type', 32);
            $table->string('user_id');
            $table->string('user_name');
            $table->string('user_role', 32);
            $table->string('area_name')->nullable();
            $table->string('territory_province');
            $table->string('territory_city');
            $table->string('territory_district');
            $table->string('territory_subdistrict');
            $table->json('photo_attachment');
            $table->json('payload');
            $table->timestamp('submitted_at');
            $table->timestamps();

            $table->index(['type', 'submitted_at']);
            $table->index(['user_id', 'submitted_at']);
        });

        $now = now();
        foreach (['Beras', 'Minyak goreng', 'Gula', 'Telur', 'Mie instan', 'Air mineral'] as $name) {
            DB::table('survey_product_options')->insert([
                'id' => (string) Str::uuid(),
                'name' => $name,
                'is_active' => true,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        foreach ([
            ['name' => 'Beras medium', 'unit' => 'kg'],
            ['name' => 'Gula pasir', 'unit' => 'kg'],
            ['name' => 'Minyak goreng', 'unit' => 'liter'],
            ['name' => 'Telur ayam', 'unit' => 'kg'],
            ['name' => 'Cabai merah', 'unit' => 'kg'],
            ['name' => 'Bawang merah', 'unit' => 'kg'],
        ] as $commodity) {
            DB::table('survey_commodity_options')->insert([
                'id' => (string) Str::uuid(),
                'name' => $commodity['name'],
                'unit' => $commodity['unit'],
                'is_active' => true,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('survey_responses');
        Schema::dropIfExists('survey_commodity_options');
        Schema::dropIfExists('survey_product_options');
    }
};
