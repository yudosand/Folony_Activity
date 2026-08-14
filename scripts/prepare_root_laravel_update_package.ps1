Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$backendRoot = Join-Path $projectRoot 'backend'
$deployRoot = Join-Path $projectRoot 'deploy\activity.foodcolony.com-root-update'
$packageRoot = Join-Path $deployRoot 'laravel-root-update'
$zipPath = Join-Path $deployRoot 'laravel-root-update.zip'
$tempStageRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("folony-root-update-" + [System.Guid]::NewGuid().ToString('N'))
$tempPackageRoot = Join-Path $tempStageRoot 'laravel-root-update'

function Reset-Directory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$ExpectedRoot
    )

    $resolvedRoot = [System.IO.Path]::GetFullPath($ExpectedRoot)
    $resolvedPath = [System.IO.Path]::GetFullPath($Path)

    if (-not $resolvedPath.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to modify path outside deploy root: $resolvedPath"
    }

    if (Test-Path -LiteralPath $resolvedPath) {
        Remove-Item -LiteralPath $resolvedPath -Recurse -Force
    }

    New-Item -ItemType Directory -Path $resolvedPath | Out-Null
}

Reset-Directory -Path $packageRoot -ExpectedRoot $deployRoot
New-Item -ItemType Directory -Path $tempPackageRoot -Force | Out-Null

$copyDirectories = @(
    'app',
    'bootstrap',
    'config',
    'database',
    'public',
    'resources',
    'routes',
    'vendor'
)

$copyFiles = @(
    '.editorconfig',
    '.gitattributes',
    '.gitignore',
    'artisan',
    'composer.json',
    'composer.lock',
    'package.json',
    'phpunit.xml',
    'README.md',
    'vite.config.js'
)

foreach ($directory in $copyDirectories) {
    Copy-Item -LiteralPath (Join-Path $backendRoot $directory) -Destination (Join-Path $tempPackageRoot $directory) -Recurse -Force
}

$publicStoragePath = Join-Path $tempPackageRoot 'public\storage'
if (Test-Path -LiteralPath $publicStoragePath) {
    Remove-Item -LiteralPath $publicStoragePath -Recurse -Force
}

$bootstrapCacheRoot = Join-Path $tempPackageRoot 'bootstrap\cache'
if (Test-Path -LiteralPath $bootstrapCacheRoot) {
    Get-ChildItem -LiteralPath $bootstrapCacheRoot -File -Filter '*.php' | Remove-Item -Force
}

foreach ($file in $copyFiles) {
    Copy-Item -LiteralPath (Join-Path $backendRoot $file) -Destination (Join-Path $tempPackageRoot $file) -Force
}

$clearCacheHelper = Join-Path $projectRoot 'deploy\clear-cache-once.php'
if (Test-Path -LiteralPath $clearCacheHelper) {
    Copy-Item -LiteralPath $clearCacheHelper -Destination (Join-Path $tempPackageRoot 'public\clear-cache-once.php') -Force
}

$cleanupTestUserHelper = Join-Path $projectRoot 'deploy\cleanup-test-user-once.php'
if (Test-Path -LiteralPath $cleanupTestUserHelper) {
    Copy-Item -LiteralPath $cleanupTestUserHelper -Destination (Join-Path $tempPackageRoot 'public\cleanup-test-user-once.php') -Force
}

$cleanupAttendanceHelper = Join-Path $projectRoot 'deploy\cleanup-attendance-test-once.php'
if (Test-Path -LiteralPath $cleanupAttendanceHelper) {
    Copy-Item -LiteralPath $cleanupAttendanceHelper -Destination (Join-Path $tempPackageRoot 'public\cleanup-attendance-test-once.php') -Force
}

$emergencyRepairHelper = Join-Path $projectRoot 'deploy\emergency-repair-once.php'
if (Test-Path -LiteralPath $emergencyRepairHelper) {
    Copy-Item -LiteralPath $emergencyRepairHelper -Destination (Join-Path $tempPackageRoot 'public\emergency-repair-once.php') -Force
}

$readmePath = Join-Path $tempPackageRoot 'UPLOAD_README.txt'
@"
Paket update root Laravel untuk production absent.folony.co.id

Paket ini TIDAK membawa:
- .env
- storage/
- public/storage dari lokal
- database/database.sqlite
- node_modules/
- bootstrap/cache/*.php

Tujuan:
- overwrite code Laravel aktif tanpa menyentuh data environment dan storage server

Langkah di server:
1. backup file public/index.php bila perlu
2. upload file zip ini ke root Laravel production
3. extract isinya ke root yang sama
4. pilih overwrite untuk file code
5. JANGAN ganti .env server
6. jalankan:
   php artisan optimize:clear
   php artisan storage:link
   php artisan route:list --path=admin
   php artisan migrate --force

Jika tidak ada akses SSH:
- buka https://absent.folony.co.id/clear-cache-once.php?token=folony-clear-20260804-b63a91 setelah extract selesai
- helper ini menjalankan optimize:clear dan mencoba menghapus dirinya otomatis

Catatan foto/lampiran:
- Bila link foto /storage/field-uploads/... 404 nginx, pastikan public/storage adalah symlink ke storage/app/public.
- Cek dengan: ls -ld public/storage storage/app/public
"@ | Set-Content -LiteralPath $readmePath

Copy-Item -LiteralPath (Join-Path $tempPackageRoot '*') -Destination $packageRoot -Recurse -Force

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

try {
    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $tempStageRoot,
        $zipPath,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $false
    )
} catch {
    throw "Failed to create zip archive at $zipPath. $($_.Exception.Message)"
}

if (Test-Path -LiteralPath $tempStageRoot) {
    Remove-Item -LiteralPath $tempStageRoot -Recurse -Force
}

Write-Host "Root Laravel update package ready at: $zipPath"
