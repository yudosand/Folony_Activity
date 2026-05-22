<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->json('territory_assignments')->nullable()->after('territory_subdistrict');
        });

        DB::table('users')
            ->whereNotNull('territory_scope')
            ->orderBy('id')
            ->get([
                'id',
                'territory_scope',
                'territory_province',
                'territory_city',
                'territory_district',
                'territory_subdistrict',
            ])
            ->each(function ($user): void {
                DB::table('users')
                    ->where('id', $user->id)
                    ->update([
                        'territory_assignments' => json_encode([[
                            'territory_scope' => $user->territory_scope,
                            'territory_province' => $user->territory_province,
                            'territory_city' => $user->territory_city,
                            'territory_district' => $user->territory_district,
                            'territory_subdistrict' => $user->territory_subdistrict,
                        ]], JSON_UNESCAPED_UNICODE),
                    ]);
            });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->dropColumn('territory_assignments');
        });
    }
};
