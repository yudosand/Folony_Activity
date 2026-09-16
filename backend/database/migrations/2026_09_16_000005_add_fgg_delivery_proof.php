<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('fgg_operations', function (Blueprint $table) {
            $table->string('proof_path')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('fgg_operations', function (Blueprint $table) {
            $table->dropColumn('proof_path');
        });
    }
};
