<?php

use App\Support\Territory\TerritoryScope;
use App\Support\Workflow\UserRole;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->string('territory_scope')->nullable()->after('work_location');
            $table->string('territory_province')->nullable()->after('territory_scope');
            $table->string('territory_city')->nullable()->after('territory_province');
            $table->string('territory_district')->nullable()->after('territory_city');
            $table->string('territory_subdistrict')->nullable()->after('territory_district');

            $table->index(['role', 'territory_scope'], 'users_role_territory_scope_index');
        });

        DB::table('users')
            ->whereIn('role', [UserRole::FGG, UserRole::AREA_MANAGER])
            ->whereNotNull('area_name')
            ->update([
                'territory_scope' => TerritoryScope::CITY,
                'territory_city' => DB::raw('area_name'),
            ]);
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->dropIndex('users_role_territory_scope_index');
            $table->dropColumn([
                'territory_scope',
                'territory_province',
                'territory_city',
                'territory_district',
                'territory_subdistrict',
            ]);
        });
    }
};
