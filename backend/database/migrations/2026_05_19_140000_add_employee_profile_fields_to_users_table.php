<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('employee_code')->nullable()->unique()->after('id');
            $table->string('job_title')->nullable()->after('role');
            $table->string('work_location')->nullable()->after('area_name');
            $table->decimal('leave_balance_days', 5, 2)->default(12)->after('is_active');
            $table->date('joined_at')->nullable()->after('leave_balance_days');
            $table->text('address')->nullable()->after('joined_at');
            $table->string('emergency_contact_name')->nullable()->after('address');
            $table->string('emergency_contact_phone')->nullable()->after('emergency_contact_name');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropUnique(['employee_code']);
            $table->dropColumn([
                'employee_code',
                'job_title',
                'work_location',
                'leave_balance_days',
                'joined_at',
                'address',
                'emergency_contact_name',
                'emergency_contact_phone',
            ]);
        });
    }
};
