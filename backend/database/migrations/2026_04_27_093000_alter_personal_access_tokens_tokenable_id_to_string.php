<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('personal_access_tokens')) {
            return;
        }

        $driver = Schema::getConnection()->getDriverName();

        if ($driver === 'mysql') {
            DB::statement('ALTER TABLE personal_access_tokens MODIFY tokenable_id VARCHAR(64) NOT NULL');

            return;
        }

        if ($driver === 'sqlite') {
            return;
        }

        Schema::table('personal_access_tokens', function (Blueprint $table) {
            $table->string('tokenable_id', 64)->change();
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('personal_access_tokens')) {
            return;
        }

        $driver = Schema::getConnection()->getDriverName();

        if ($driver === 'mysql') {
            DB::statement('ALTER TABLE personal_access_tokens MODIFY tokenable_id BIGINT UNSIGNED NOT NULL');

            return;
        }

        if ($driver === 'sqlite') {
            return;
        }

        Schema::table('personal_access_tokens', function (Blueprint $table) {
            $table->unsignedBigInteger('tokenable_id')->change();
        });
    }
};
