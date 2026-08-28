<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('network_profiles', function (Blueprint $table): void {
            if (! $this->hasIndex('network_profiles', 'np_type_lat_lng_idx')) {
                $table->index(['type', 'latitude', 'longitude'], 'np_type_lat_lng_idx');
            }
            if (! $this->hasIndex('network_profiles', 'np_lat_lng_idx')) {
                $table->index(['latitude', 'longitude'], 'np_lat_lng_idx');
            }
            if (! $this->hasIndex('network_profiles', 'np_owner_created_idx')) {
                $table->index(['owner_id', 'created_at'], 'np_owner_created_idx');
            }
            if (! $this->hasIndex('network_profiles', 'np_type_created_idx')) {
                $table->index(['type', 'created_at'], 'np_type_created_idx');
            }
            if (! $this->hasIndex('network_profiles', 'np_province_type_idx')) {
                $table->index(['territory_province', 'type'], 'np_province_type_idx');
            }
            if (! $this->hasIndex('network_profiles', 'np_city_type_idx')) {
                $table->index(['territory_city', 'type'], 'np_city_type_idx');
            }
            if (! $this->hasIndex('network_profiles', 'np_district_type_idx')) {
                $table->index(['territory_district', 'type'], 'np_district_type_idx');
            }
            if (! $this->hasIndex('network_profiles', 'np_subdistrict_type_idx')) {
                $table->index(['territory_subdistrict', 'type'], 'np_subdistrict_type_idx');
            }
        });

        Schema::table('network_follow_ups', function (Blueprint $table): void {
            if (! $this->hasIndex('network_follow_ups', 'nfu_actor_created_idx')) {
                $table->index(['actor_id', 'created_at'], 'nfu_actor_created_idx');
            }
        });
    }

    public function down(): void
    {
        Schema::table('network_follow_ups', function (Blueprint $table): void {
            if ($this->hasIndex('network_follow_ups', 'nfu_actor_created_idx')) {
                $table->dropIndex('nfu_actor_created_idx');
            }
        });

        Schema::table('network_profiles', function (Blueprint $table): void {
            foreach ([
                'np_type_lat_lng_idx',
                'np_lat_lng_idx',
                'np_owner_created_idx',
                'np_type_created_idx',
                'np_province_type_idx',
                'np_city_type_idx',
                'np_district_type_idx',
                'np_subdistrict_type_idx',
            ] as $indexName) {
                if ($this->hasIndex('network_profiles', $indexName)) {
                    $table->dropIndex($indexName);
                }
            }
        });
    }

    private function hasIndex(string $table, string $indexName): bool
    {
        try {
            foreach (Schema::getIndexes($table) as $index) {
                if (($index['name'] ?? null) === $indexName) {
                    return true;
                }
            }
        } catch (Throwable) {
            return false;
        }

        return false;
    }
};
