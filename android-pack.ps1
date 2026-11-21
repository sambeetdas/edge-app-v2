<#
.SYNOPSIS
    Builds an installable Android APK for Edged and copies it to .\dist\.

.PARAMETER Debug
    Build a debug APK instead of a release APK.

.PARAMETER Install
    Automatically install the built APK onto a connected Android phone via ADB.
#>
param(
    [switch]$Debug,
    [switch]$Install
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$projectRoot = $PSScriptRoot
if (-not $projectRoot) { $projectRoot = Get-Location }
Set-Location $projectRoot

# Locate Flutter CLI
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
if (-not $flutterCmd) {
    $fallback = "C:\src\flutter\bin\flutter.bat"
    if (Test-Path $fallback) {
        $flutterCmd = $fallback
    } else {
        Write-Error "Flutter SDK not found. Add Flutter to PATH or install it at C:\src\flutter."
        exit 1
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "       Edged Android APK Packager       " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/3] Fetching Flutter packages..." -ForegroundColor Yellow
& $flutterCmd pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$buildMode = if ($Debug) { "debug" } else { "release" }
Write-Host "[2/3] Building $buildMode APK..." -ForegroundColor Yellow
& $flutterCmd build apk "--$buildMode"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$sourceApk = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-$buildMode.apk"
if (-not (Test-Path $sourceApk)) {
    Write-Error "Expected APK not found at: $sourceApk"
    exit 1
}

$distDir = Join-Path $projectRoot "dist"
if (-not (Test-Path $distDir)) {
    New-Item -ItemType Directory -Path $distDir | Out-Null
}

$destName = if ($Debug) { "Edged-debug.apk" } else { "Edged-v1.0.0-release.apk" }
$destApk = Join-Path $distDir $destName
Copy-Item -Path $sourceApk -Destination $destApk -Force

$sizeMb = [math]::Round((Get-Item $destApk).Length / 1MB, 2)
Write-Host "[3/3] APK ready!" -ForegroundColor Green
Write-Host "  Path : $destApk" -ForegroundColor Cyan
Write-Host "  Size : $sizeMb MB" -ForegroundColor Cyan
Write-Host ""

if ($Install) {
    Write-Host "Installing APK onto connected phone via ADB..." -ForegroundColor Yellow
    adb install -r "$destApk"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Installed! Launching Edged..." -ForegroundColor Green
        adb shell am start -n com.edgedai.app/.MainActivity
    }
} else {
    Write-Host "To install on your phone:" -ForegroundColor White
    Write-Host "  1. Copy '$destApk' to your phone and tap it to install, OR" -ForegroundColor Gray
    Write-Host "  2. Connect your phone via USB (USB Debugging ON) and run:" -ForegroundColor Gray
    Write-Host "     adb install -r `"$destApk`"" -ForegroundColor Cyan
}
Write-Host ""
