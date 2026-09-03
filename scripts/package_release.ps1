param(
    [string]$Version = "1.0.1"
)

$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot | Split-Path -Parent
$releaseDir = Join-Path $repoRoot "release_v$Version"
$buildDir = Join-Path $repoRoot "build\windows\x64\runner\Release"

if (-not (Test-Path $releaseDir)) {
    New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
}

Write-Host "=== Packaging Windows Portable ZIP ==="
$zipFile = Join-Path $releaseDir "Infyn-DL-v$Version-windows-portable.zip"
if (Test-Path $zipFile) {
    Remove-Item -Force $zipFile
}
Compress-Archive -Path "$buildDir\*" -DestinationPath $zipFile
Write-Host "Created ZIP: $zipFile ($( (Get-Item $zipFile).Length ) bytes)"

Write-Host "=== Compiling Inno Setup Installer ==="
$isccExe = "C:\Users\rajvi\AppData\Local\Programs\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $isccExe)) {
    $isccExe = "ISCC.exe"
}

$issFile = Join-Path $repoRoot "windows\installer\inno_setup.iss"

& $isccExe "/DMyAppVersion=$Version" "/DSourceDir=$buildDir" "/DOutputDir=$releaseDir" "/DOutputBaseFilename=Infyn-DL-v$Version-windows-setup" $issFile

Write-Host "=== Copying Android APKs ==="
$apkDir = Join-Path $repoRoot "build\app\outputs\flutter-apk"
if (Test-Path "$apkDir\app-release.apk") {
    Copy-Item "$apkDir\app-release.apk" (Join-Path $releaseDir "Infyn-DL-v$Version-android-universal.apk") -Force
}
if (Test-Path "$apkDir\app-arm64-v8a-release.apk") {
    Copy-Item "$apkDir\app-arm64-v8a-release.apk" (Join-Path $releaseDir "Infyn-DL-v$Version-android-arm64-v8a.apk") -Force
}
if (Test-Path "$apkDir\app-armeabi-v7a-release.apk") {
    Copy-Item "$apkDir\app-armeabi-v7a-release.apk" (Join-Path $releaseDir "Infyn-DL-v$Version-android-armeabi-v7a.apk") -Force
}

Write-Host "=== Final Release v$Version Artifacts ==="
Get-ChildItem $releaseDir | Select-Object Name, Length | Format-Table
