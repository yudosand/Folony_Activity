<?php
// CLI-only, staging-only importer. Never place this file in public/.
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
$root = $argv[1] ?? '';
$mode = $argv[2] ?? '--inspect';
$file = $argv[3] ?? '';
require $root.'/vendor/autoload.php';
$app = require $root.'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

use App\Models\Supplier;
use App\Models\User;
use Illuminate\Support\Facades\DB;

if (parse_url(config('app.url'), PHP_URL_HOST) !== 'staging-absent.folony.co.id') {
    throw new RuntimeException('Staging host check failed. No changes made.');
}
$database = DB::connection()->getDatabaseName();
if ($database !== 'folonystaging') throw new RuntimeException('Staging database check failed. No changes made.');
$creator = User::query()->where('role', 'hr')->where('is_active', true)->where('full_name', 'Alya HR')->sole();
$context = ['host' => parse_url(config('app.url'), PHP_URL_HOST), 'database' => $database,
    'supplier_count' => Supplier::count(), 'creator_id' => $creator->id, 'creator_name' => $creator->full_name];
if ($mode === '--inspect') {
    $context['existing_suppliers'] = Supplier::orderBy('id')->get(['id', 'name', 'latitude', 'longitude'])->toArray();
    echo json_encode($context, JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE).PHP_EOL;
    exit;
}
if (!in_array($mode, ['--dry-run', '--apply', '--verify'], true)) throw new RuntimeException('Unknown mode');
$data = json_decode(file_get_contents($file), true, 512, JSON_THROW_ON_ERROR);
$sourceHash = '12db260548ede9498bf81a2b9ed331597271a3a7d9357b85af157309e3a35317';
if (($data['source_sha256'] ?? '') !== $sourceHash || count($data['records'] ?? []) !== 44) throw new RuntimeException('Unexpected import source');
$prepared = [];
foreach ($data['records'] as $row) {
    $no = $row['source_number'];
    if (!is_int($no) || $no < 1 || $no > 44 || isset($prepared[$no])) throw new RuntimeException('Invalid source number');
    $tag = '[Impor HSF '.$no.' / '.substr($sourceHash, 0, 12).']';
    $payload = $row['supplier'];
    validator($payload, [
        'name' => ['required', 'string', 'max:255'], 'pic_name' => ['nullable', 'string', 'max:255'],
        'phone_number' => ['present', 'nullable', 'string', 'max:32'],
        'address' => ['present', 'nullable', 'string', 'max:1000'],
        'territory_province' => ['nullable', 'string', 'max:255'], 'territory_city' => ['nullable', 'string', 'max:255'],
        'territory_district' => ['nullable', 'string', 'max:255'],
        'items' => ['present', 'array', 'max:50'], 'items.*' => ['required', 'string', 'max:255', 'distinct:ignore_case'],
        'notes' => ['required', 'string', 'max:3000'], 'location_source' => ['in:map'],
        'latitude' => ['required', 'numeric', 'between:-11.5,6.5'], 'longitude' => ['required', 'numeric', 'between:94,142'],
    ])->validate();
    if (!str_contains($payload['notes'], $tag)) throw new RuntimeException('Missing source tag');
    $payload['phone_number'] ??= ''; // Missing source phone remains missing, never invented.
    $prepared[$no] = ['tag' => $tag, 'payload' => $payload];
}
ksort($prepared);
if (array_keys($prepared) !== range(1, 44)) throw new RuntimeException('Incomplete source coverage');

$lock = DB::selectOne('SELECT GET_LOCK(?, 10) AS acquired', ['folony-supplier-excel-hsf-import']);
if ((int)$lock->acquired !== 1) throw new RuntimeException('Another supplier import is running');
try {
    $results = DB::transaction(function () use ($prepared, $mode, $creator, $context, $sourceHash) {
        $before = Supplier::orderBy('id')->get();
        $newRows = [];
        $existingIds = [];
        foreach ($prepared as $no => $entry) {
            $sameImport = Supplier::where('notes', 'like', '%'.$entry['tag'].'%')->get();
            if ($sameImport->count() > 1) throw new RuntimeException('Duplicate source marker '.$no);
            if ($sameImport->count() === 1) {
                $existing = $sameImport->first();
                foreach ($entry['payload'] as $key => $value) {
                    if (in_array($key, ['latitude', 'longitude'], true)) {
                        if (abs($existing->$key - $value) > 0.00000011) throw new RuntimeException('Existing coordinate differs for '.$no);
                    } elseif ($existing->$key !== $value) throw new RuntimeException('Existing source record differs: '.$no.' '.$key);
                }
                $existingIds[$no] = $existing->id;
                continue;
            }
            if (Supplier::whereRaw('LOWER(TRIM(name)) = ?', [mb_strtolower(trim($entry['payload']['name']))])->exists()) {
                throw new RuntimeException('Name collision needs review: '.$entry['payload']['name']);
            }
            $newRows[$no] = $entry['payload'];
        }
        if ($mode === '--verify' && count($newRows)) throw new RuntimeException('Missing imported suppliers');
        $backupPath = null;
        if ($mode === '--apply' && count($newRows)) {
            $directory = storage_path('app/private/supplier-import-backups');
            if (!is_dir($directory)) mkdir($directory, 0700, true);
            $backupPath = $directory.'/before-hsf-'.date('Ymd-His').'-'.bin2hex(random_bytes(4)).'.json';
            $handle = fopen($backupPath, 'x');
            if (!$handle) throw new RuntimeException('Backup failed');
            $bytes = json_encode(['context' => $context, 'source_sha256' => $sourceHash, 'suppliers' => $before->toArray()], JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE|JSON_THROW_ON_ERROR);
            if (fwrite($handle, $bytes) !== strlen($bytes)) throw new RuntimeException('Incomplete backup');
            fclose($handle);
            chmod($backupPath, 0600);
            foreach ($newRows as $no => $payload) {
                $supplier = new Supplier($payload);
                $supplier->created_by = $creator->id;
                $supplier->save();
                $existingIds[$no] = $supplier->id;
            }
            foreach ($before as $old) {
                if ($old->getRawOriginal() !== Supplier::findOrFail($old->id)->getRawOriginal()) throw new RuntimeException('Pre-existing supplier changed');
            }
        }
        return ['mode' => $mode, 'before_count' => $before->count(), 'new_records' => count($newRows),
            'already_imported' => count($prepared) - count($newRows), 'after_count' => Supplier::count(),
            'backup' => $backupPath, 'source_to_supplier_ids' => $existingIds];
    });
    echo json_encode($results, JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE).PHP_EOL;
} finally {
    DB::select('SELECT RELEASE_LOCK(?)', ['folony-supplier-excel-hsf-import']);
}
