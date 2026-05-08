Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$backendRoot = Join-Path $projectRoot 'backend'
$deployRoot = Join-Path $projectRoot 'deploy\activity.foodcolony.com'
$backendDeployRoot = Join-Path $deployRoot 'backend-app'
$publicDeployRoot = Join-Path $deployRoot 'public_html'

function Reset-DeployDirectory {
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

Reset-DeployDirectory -Path $backendDeployRoot -ExpectedRoot $deployRoot
Reset-DeployDirectory -Path $publicDeployRoot -ExpectedRoot $deployRoot

$excludeDirectories = @(
    '.git',
    '.idea',
    '.vscode',
    'node_modules',
    'tests'
)

$excludeFiles = @(
    '.env',
    '.env.mysql.example',
    'database.sqlite'
)

Get-ChildItem -LiteralPath $backendRoot -Force | ForEach-Object {
    if ($_.Name -eq 'public') {
        return
    }

    if ($excludeDirectories -contains $_.Name) {
        return
    }

    if (-not $_.PSIsContainer -and $excludeFiles -contains $_.Name) {
        return
    }

    $destination = Join-Path $backendDeployRoot $_.Name

    if ($_.PSIsContainer) {
        Copy-Item -LiteralPath $_.FullName -Destination $destination -Recurse -Force
    } else {
        Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
    }
}

Get-ChildItem -LiteralPath (Join-Path $backendRoot 'public') -Force | ForEach-Object {
    $destination = Join-Path $publicDeployRoot $_.Name

    if ($_.PSIsContainer) {
        Copy-Item -LiteralPath $_.FullName -Destination $destination -Recurse -Force
    } else {
        Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
    }
}
Copy-Item -LiteralPath (Join-Path $backendRoot '.env.activity.foodcolony.example') -Destination (Join-Path $backendDeployRoot '.env') -Force

$indexPath = Join-Path $publicDeployRoot 'index.php'
$indexContent = Get-Content -LiteralPath $indexPath -Raw
$indexContent = $indexContent.Replace("__DIR__.'/../storage/framework/maintenance.php'", "__DIR__.'/../backend-app/storage/framework/maintenance.php'")
$indexContent = $indexContent.Replace("__DIR__.'/../vendor/autoload.php'", "__DIR__.'/../backend-app/vendor/autoload.php'")
$indexContent = $indexContent.Replace("__DIR__.'/../bootstrap/app.php'", "__DIR__.'/../backend-app/bootstrap/app.php'")
Set-Content -LiteralPath $indexPath -Value $indexContent -NoNewline

$readmePath = Join-Path $deployRoot 'README.txt'
@"
Deploy package untuk subdomain activity.foodcolony.com

Struktur upload yang disarankan:
- upload isi folder public_html ke document root subdomain activity.foodcolony.com
- upload folder backend-app ke sibling document root, misalnya satu level di atas public_html

Setelah upload:
1. edit backend-app/.env
2. generate APP_KEY jika masih kosong
3. jalankan migration dan seeder
4. buat storage link jika server mengizinkan
5. set permission write untuk storage dan bootstrap/cache
"@ | Set-Content -LiteralPath $readmePath

Write-Host "Deploy package ready at: $deployRoot"
