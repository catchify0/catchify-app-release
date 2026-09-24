# PowerShell environment setup for catchify local tools
$repoRoot = (Get-Item "$PSScriptRoot\..").FullName
$flutterRoot = Join-Path $repoRoot "tools\flutter"
$flutterBin = Join-Path $flutterRoot "bin"
$dartSdkBin = Join-Path $flutterBin "cache\dart-sdk\bin"
$androidSdk = Join-Path $repoRoot "tools\android-sdk"
$platformTools = Join-Path $androidSdk "platform-tools"

$env:ANDROID_HOME = $androidSdk
$env:ANDROID_SDK_ROOT = $androidSdk
$env:FLUTTER_ROOT = $flutterRoot

if ($env:PATH -notlike "*$flutterBin*") {
    $env:PATH = "$flutterBin;$dartSdkBin;$platformTools;$env:PATH"
}

Write-Host "Catchify local environment configured:" -ForegroundColor Green
Write-Host "  Flutter SDK : $flutterBin"
Write-Host "  Dart SDK    : $dartSdkBin"
Write-Host "  Android SDK : $androidSdk"
