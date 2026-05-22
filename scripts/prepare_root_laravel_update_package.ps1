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

foreach ($file in $copyFiles) {
    Copy-Item -LiteralPath (Join-Path $backendRoot $file) -Destination (Join-Path $tempPackageRoot $file) -Force
}

$readmePath = Join-Path $tempPackageRoot 'UPLOAD_README.txt'
@"
Paket update root Laravel untuk /www/wwwroot/activity.foodcolony.com

Paket ini TIDAK membawa:
- .env
- storage/
- database/database.sqlite
- node_modules/

Tujuan:
- overwrite code Laravel aktif tanpa menyentuh data environment dan storage server

Langkah di server:
1. backup file public/index.php bila perlu
2. upload file zip ini ke /www/wwwroot/activity.foodcolony.com
3. extract isinya ke root yang sama
4. pilih overwrite untuk file code
5. JANGAN ganti .env server
6. jalankan:
   php artisan optimize:clear
   php artisan route:list --path=admin
   php artisan migrate --force
"@ | Set-Content -LiteralPath $readmePath

Copy-Item -LiteralPath (Join-Path $tempPackageRoot '*') -Destination $packageRoot -Recurse -Force

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

& tar.exe -a -cf $zipPath -C $tempStageRoot 'laravel-root-update'

if ($LASTEXITCODE -ne 0) {
    throw "Failed to create zip archive at $zipPath"
}

if (Test-Path -LiteralPath $tempStageRoot) {
    Remove-Item -LiteralPath $tempStageRoot -Recurse -Force
}

Write-Host "Root Laravel update package ready at: $zipPath"
