<?php

namespace App\Console\Commands;

use App\Models\IndonesiaTerritory;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;
use SplFileObject;

class ImportIndonesiaTerritoriesCommand extends Command
{
    protected $signature = 'territory:import-indonesia {path : Path file JSON hasil export master wilayah}';

    protected $description = 'Import master wilayah Indonesia dari file JSON lokal.';

    public function handle(): int
    {
        $path = $this->argument('path');
        $absolutePath = $this->isAbsolutePath($path)
            ? $path
            : base_path($path);

        if (! File::exists($absolutePath)) {
            $this->error(sprintf('File tidak ditemukan: %s', $absolutePath));

            return self::FAILURE;
        }

        if (preg_match('/\.(jsonl|ndjson)$/i', $absolutePath) === 1) {
            return $this->importNdjson($absolutePath);
        }

        return $this->importJsonArray($absolutePath);
    }

    private function isAbsolutePath(string $path): bool
    {
        return str_starts_with($path, DIRECTORY_SEPARATOR)
            || preg_match('/^[A-Za-z]:[\\\\\\/]/', $path) === 1;
    }

    private function importJsonArray(string $absolutePath): int
    {
        $raw = File::get($absolutePath);
        $raw = preg_replace('/^\xEF\xBB\xBF/', '', $raw) ?? $raw;
        $decoded = json_decode($raw, true);

        if (! is_array($decoded)) {
            $this->error('File JSON tidak valid atau bukan array.');

            return self::FAILURE;
        }

        $rows = collect($decoded)
            ->filter(fn ($row) => is_array($row) && isset($row['code'], $row['level'], $row['name']))
            ->map(fn (array $row) => $this->normalizeRow($row))
            ->values();

        if ($rows->isEmpty()) {
            $this->error('Tidak ada baris wilayah yang valid di file JSON.');

            return self::FAILURE;
        }

        DB::transaction(function () use ($rows): void {
            IndonesiaTerritory::query()->delete();
            foreach ($rows->chunk(1000) as $chunk) {
                IndonesiaTerritory::query()->insert($chunk->all());
            }
        });

        $this->info(sprintf(
            'Import selesai: %d baris master wilayah dimasukkan dari %s',
            $rows->count(),
            $absolutePath,
        ));

        return self::SUCCESS;
    }

    private function importNdjson(string $absolutePath): int
    {
        $file = new SplFileObject($absolutePath, 'r');
        $batch = [];
        $count = 0;
        $isFirstLine = true;

        DB::transaction(function () use ($file, &$batch, &$count, &$isFirstLine): void {
            IndonesiaTerritory::query()->delete();

            while (! $file->eof()) {
                $line = $file->fgets();
                if ($isFirstLine) {
                    $line = preg_replace('/^\xEF\xBB\xBF/', '', $line) ?? $line;
                    $isFirstLine = false;
                }

                $line = trim($line);
                if ($line === '') {
                    continue;
                }

                $row = json_decode($line, true);
                if (! is_array($row) || ! isset($row['code'], $row['level'], $row['name'])) {
                    continue;
                }

                $batch[] = $this->normalizeRow($row);
                $count++;

                if (count($batch) >= 1000) {
                    IndonesiaTerritory::query()->insert($batch);
                    $batch = [];
                }
            }

            if ($batch !== []) {
                IndonesiaTerritory::query()->insert($batch);
            }
        });

        if ($count === 0) {
            $this->error('Tidak ada baris wilayah yang valid di file JSON Lines.');

            return self::FAILURE;
        }

        $this->info(sprintf(
            'Import selesai: %d baris master wilayah dimasukkan dari %s',
            $count,
            $absolutePath,
        ));

        return self::SUCCESS;
    }

    private function normalizeRow(array $row): array
    {
        $timestamp = Carbon::now();

        return [
            'code' => (string) $row['code'],
            'level' => (string) $row['level'],
            'name' => (string) $row['name'],
            'normalized_name' => (string) ($row['normalized_name'] ?? mb_strtolower(trim((string) $row['name']))),
            'parent_code' => $row['parent_code'] ?? null,
            'province_code' => $row['province_code'] ?? null,
            'city_code' => $row['city_code'] ?? null,
            'district_code' => $row['district_code'] ?? null,
            'province_name' => $row['province_name'] ?? null,
            'city_name' => $row['city_name'] ?? null,
            'district_name' => $row['district_name'] ?? null,
            'created_at' => $timestamp,
            'updated_at' => $timestamp,
        ];
    }
}
