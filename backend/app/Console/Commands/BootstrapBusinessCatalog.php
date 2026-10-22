<?php
namespace App\Console\Commands;
use App\Models\BusinessCategory;
use App\Models\BusinessKind;
use App\Services\BusinessCatalog;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class BootstrapBusinessCatalog extends Command {
    protected $signature = 'business:bootstrap {--apply : Apply to staging after a private backup}';
    protected $description = 'Preview or seed reviewed business categories and map existing staging profiles';
    public function handle(): int {
        if (parse_url(config('app.url'), PHP_URL_HOST) !== 'staging-absent.folony.co.id') {
            $this->error('This trial command is restricted to staging.'); return self::FAILURE;
        }
        $catalog = json_decode(file_get_contents(database_path('data/business-catalog.json')), true, 512, JSON_THROW_ON_ERROR);
        $rows = DB::table('network_profiles')->get(['id','business_type','business_kind_id','latitude','longitude','updated_at']);
        $groups = [];
        foreach ($rows as $row) {
            if ($row->business_kind_id !== null) continue;
            $kind = $catalog['aliases'][BusinessCatalog::normalize($row->business_type ?? '')] ?? null;
            if ($kind) $groups[$kind][] = $row->id;
        }
        $count = array_sum(array_map('count', $groups));
        $this->info(json_encode(['profiles'=>$rows->count(),'to_map'=>$count,'already_mapped'=>$rows->whereNotNull('business_kind_id')->count(),'remain_review'=>$rows->whereNull('business_kind_id')->count()-$count]));
        if (!$this->option('apply')) return self::SUCCESS;
        $dir = storage_path('app/private/business-catalog-backups');
        if (!is_dir($dir)) mkdir($dir, 0700, true);
        $backup = $dir.'/before-'.date('Ymd-His').'-'.bin2hex(random_bytes(4)).'.json';
        if (file_put_contents($backup, json_encode($rows, JSON_THROW_ON_ERROR)) === false) throw new \RuntimeException('Backup failed');
        chmod($backup, 0600);
        DB::transaction(function () use ($catalog, $groups) {
            foreach ($catalog['categories'] as $row) BusinessCategory::firstOrCreate(['id'=>$row['id']], $row);
            foreach ($catalog['kinds'] as $row) BusinessKind::firstOrCreate(['id'=>$row['id']], $row);
            foreach ($catalog['aliases'] as $alias=>$kind) DB::table('business_aliases')->insertOrIgnore(['normalized'=>$alias,'kind_id'=>$kind]);
            foreach ($groups as $kind=>$ids) foreach (array_chunk($ids, 400) as $chunk) {
                // Preserve original labels, coordinates, ownership and timestamps.
                DB::table('network_profiles')->whereNull('business_kind_id')->whereIn('id',$chunk)->update(['business_kind_id'=>$kind]);
            }
        });
        $this->info('Applied. Backup: '.$backup);
        return self::SUCCESS;
    }
}
