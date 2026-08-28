Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$backendRoot = Join-Path $projectRoot 'backend'
$deployRoot = Join-Path $projectRoot 'deploy'
$zipPath = Join-Path $deployRoot 'folony-laravel-staging-root.zip'
$stageRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("folony-staging-root-" + [System.Guid]::NewGuid().ToString('N'))

function Copy-ItemSafe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
}

New-Item -ItemType Directory -Path $deployRoot -Force | Out-Null
New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null

$directories = @(
    'app',
    'bootstrap',
    'config',
    'database',
    'public',
    'resources',
    'routes',
    'vendor'
)

$files = @(
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

foreach ($directory in $directories) {
    Copy-ItemSafe -Source (Join-Path $backendRoot $directory) -Destination (Join-Path $stageRoot $directory)
}

$publicStoragePath = Join-Path $stageRoot 'public\storage'
if (Test-Path -LiteralPath $publicStoragePath) {
    Remove-Item -LiteralPath $publicStoragePath -Recurse -Force
}

foreach ($file in $files) {
    Copy-ItemSafe -Source (Join-Path $backendRoot $file) -Destination (Join-Path $stageRoot $file)
}

$publicRoot = Join-Path $stageRoot 'public'
Get-ChildItem -LiteralPath $publicRoot -File -Filter '*-once.php' -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -LiteralPath $publicRoot -File -Filter 'diagnose-500-once.php' -ErrorAction SilentlyContinue | Remove-Item -Force

$stagingArtisanHelper = Join-Path $deployRoot 'staging-artisan-once-20260812.php'
if (Test-Path -LiteralPath $stagingArtisanHelper) {
    Copy-ItemSafe -Source $stagingArtisanHelper -Destination (Join-Path $stageRoot 'public\staging-artisan-once-20260812.php')
}

$stagingNetworkDiagnosticHelper = Join-Path $deployRoot 'staging-network-diagnostic-once-20260826.php'
if (Test-Path -LiteralPath $stagingNetworkDiagnosticHelper) {
    Copy-ItemSafe -Source $stagingNetworkDiagnosticHelper -Destination (Join-Path $stageRoot 'public\staging-network-diagnostic-once-20260826.php')
}

$bootstrapCacheRoot = Join-Path $stageRoot 'bootstrap\cache'
if (Test-Path -LiteralPath $bootstrapCacheRoot) {
    Get-ChildItem -LiteralPath $bootstrapCacheRoot -File -Filter '*.php' | Remove-Item -Force
}

$readmePath = Join-Path $stageRoot 'STAGING_DEPLOY_README.txt'
@"
Folony Activity staging Laravel root package

ZIP ini berisi file root Laravel secara FLAT, bukan folder pembungkus.

Upload/extract hanya di:
/home/folony-staging-absent/htdocs/staging-absent.folony.co.id

Paket ini TIDAK membawa:
- .env
- storage/
- bootstrap/cache/*.php
- public/storage dari lokal

Database staging:
- DB_DATABASE=folonystaging
- DB_USERNAME=folonystaging

Setelah extract:
1. Buat .env staging di root Laravel.
2. Jalankan helper: /staging-artisan-once-20260812.php?token=folony-staging-artisan-20260812
3. Helper akan migrate, storage:link, dan optimize:clear.
4. Cek data jaringan: /staging-network-diagnostic-once-20260826.php?token=folony-staging-network-20260826
5. Buka https://staging-absent.folony.co.id/admin/login
6. Hapus helper public/*-once.php setelah selesai.
"@ | Set-Content -LiteralPath $readmePath -Encoding ASCII

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipArchive = [System.IO.Compression.ZipFile]::Open(
    $zipPath,
    [System.IO.Compression.ZipArchiveMode]::Create
)
try {
    $stageRootFullPath = [System.IO.Path]::GetFullPath($stageRoot).TrimEnd('\', '/')
    Get-ChildItem -LiteralPath $stageRoot -Recurse -File | ForEach-Object {
        $fileFullPath = [System.IO.Path]::GetFullPath($_.FullName)
        $relativePath = $fileFullPath.Substring($stageRootFullPath.Length).TrimStart('\', '/')
        $entryName = $relativePath.Replace('\', '/')

        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zipArchive,
            $fileFullPath,
            $entryName,
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
} finally {
    $zipArchive.Dispose()
}

Remove-Item -LiteralPath $stageRoot -Recurse -Force

Write-Host "Staging Laravel root zip ready at: $zipPath"
