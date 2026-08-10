param(
    [string]$BackendBaseUrl = "http://192.168.31.160:8000/api"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$distRoot = Join-Path $projectRoot 'dist'
$outputApk = Join-Path $distRoot 'FolonyActivity-staging-local-arm64-release.apk'
$flutterApk = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-release.apk'
$buildStartedAt = Get-Date

Set-Location $projectRoot
$env:CI = 'true'
$env:DART_SUPPRESS_ANALYTICS = 'true'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'

if (-not (Test-Path $distRoot)) {
    New-Item -ItemType Directory -Path $distRoot | Out-Null
}

Write-Host "Building Folony Activity staging APK"
Write-Host "Backend: $BackendBaseUrl"

if (Test-Path $flutterApk) {
    Remove-Item -LiteralPath $flutterApk -Force
}

& '.\tools\flutter\bin\flutter.bat' clean
if ($LASTEXITCODE -ne 0) {
    throw "Flutter clean failed with exit code $LASTEXITCODE"
}

& '.\tools\flutter\bin\flutter.bat' build apk --release --target-platform android-arm64 `
  --dart-define=HEX_ENABLE_REMOTE_WORKFLOW=true `
  --dart-define=HEX_BACKEND_BASE_URL=$BackendBaseUrl `
  --dart-define=HEX_ENABLE_DEMO_MODE=false `
  --dart-define=HEX_APP_ENV_LABEL="STAGING LOCAL"

if ($LASTEXITCODE -ne 0) {
    throw "Flutter build failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path $flutterApk)) {
    throw "Flutter build did not produce APK: $flutterApk"
}

$builtApk = Get-Item -LiteralPath $flutterApk
if ($builtApk.LastWriteTime -lt $buildStartedAt) {
    throw "Flutter APK output is older than this build run: $flutterApk"
}

Copy-Item -LiteralPath $flutterApk -Destination $outputApk -Force

Write-Host "DONE: $outputApk"
