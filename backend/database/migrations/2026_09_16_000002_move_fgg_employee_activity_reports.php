<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration {
    public function up(): void
    {
        // Successful operations are the durable source for the field timeline.
        // Remove only exact auto-generated duplicates, preserving manual entries.
        DB::table('fgg_operations')->where('state', 'succeeded')->orderBy('id')->chunkById(200, function ($operations) {
            foreach ($operations as $operation) {
                DB::table('employee_activities')->where('request_id', 'fgg-'.$operation->id)
                    ->where('user_id', $operation->user_id)
                    ->where('note', 'FGG '.$operation->hub_id.' · '.($operation->action === 'receive' ? 'Menerima DST ' : 'Mengirim pesanan ').$operation->target)
                    ->delete();
            }
        });
    }

    public function down(): void
    {
        // Report routing must not recreate employee work sessions on rollback.
    }
};
