<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
return new class extends Migration {
    public function up(): void {
        Schema::create('business_categories', function (Blueprint $t) {
            $t->string('id', 80)->primary(); $t->string('name', 120)->unique();
            $t->string('color', 7); $t->boolean('active')->default(true); $t->timestamps();
        });
        Schema::create('business_kinds', function (Blueprint $t) {
            $t->string('id', 100)->primary(); $t->string('category_id', 80);
            $t->foreign('category_id')->references('id')->on('business_categories')->restrictOnDelete();
            $t->string('name', 120); $t->string('icon', 30)->default('store');
            $t->boolean('active')->default(true); $t->timestamps();
            $t->unique(['category_id', 'name']);
        });
        Schema::create('business_aliases', function (Blueprint $t) {
            $t->string('normalized', 255)->primary(); $t->string('kind_id', 100);
            $t->foreign('kind_id')->references('id')->on('business_kinds')->restrictOnDelete();
        });
        Schema::table('network_profiles', function (Blueprint $t) {
            $t->string('business_kind_id', 100)->nullable()->index();
            $t->foreign('business_kind_id')->references('id')->on('business_kinds')->restrictOnDelete();
        });
    }
    public function down(): void {
        Schema::table('network_profiles', function (Blueprint $t) { $t->dropForeign(['business_kind_id']); $t->dropColumn('business_kind_id'); });
        Schema::dropIfExists('business_aliases'); Schema::dropIfExists('business_kinds'); Schema::dropIfExists('business_categories');
    }
};
