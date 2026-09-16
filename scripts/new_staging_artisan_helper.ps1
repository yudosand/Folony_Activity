param([Parameter(Mandatory = $true)][ValidatePattern('^[a-zA-Z0-9-]+$')][string]$ReleaseId)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$deployRoot = Join-Path $projectRoot 'deploy'
New-Item -ItemType Directory -Path $deployRoot -Force | Out-Null
$destination = Join-Path $deployRoot ('staging-artisan-once-' + $ReleaseId + '.php')
if (-not (Test-Path -LiteralPath $destination)) {
    $bytes = New-Object byte[] 24
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    $token = -join ($bytes | ForEach-Object { $_.ToString('x2') })
    $template = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'templates/staging-artisan-once.php.template') -Raw
    $source = $template.Replace('__DEPLOY_TOKEN__', $token).Replace('__DEPLOY_RELEASE__', $ReleaseId)
    [IO.File]::WriteAllText($destination, $source)
}
Write-Output $destination
