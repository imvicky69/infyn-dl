# Setup script for infyn-dl Windows dependencies
$ErrorActionPreference = "Stop"

$binDir = Join-Path $PSScriptRoot "..\windows\bin\x64"
if (!(Test-Path $binDir)) {
    New-Item -ItemType Directory -Force -Path $binDir | Out-Null
}

Write-Host "Setting up infyn-dl Windows dependencies in $binDir..." -ForegroundColor Cyan

# 1. Download yt-dlp.exe
$ytDlpPath = Join-Path $binDir "yt-dlp.exe"
if (!(Test-Path $ytDlpPath)) {
    Write-Host "Downloading yt-dlp.exe..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe" -OutFile $ytDlpPath
    Write-Host "yt-dlp.exe installed." -ForegroundColor Green
} else {
    Write-Host "yt-dlp.exe already present." -ForegroundColor Green
}

# 2. Download standalone QuickJS
$qjsPath = Join-Path $binDir "qjs.exe"
if (!(Test-Path $qjsPath)) {
    Write-Host "Downloading qjs.exe..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri "https://github.com/quickjs-ng/quickjs/releases/download/v0.16.2/qjs-windows-x86_64.exe" -OutFile $qjsPath
    Write-Host "qjs.exe installed." -ForegroundColor Green
} else {
    Write-Host "qjs.exe already present." -ForegroundColor Green
}

# 3. Download FFmpeg essentials
$ffmpegPath = Join-Path $binDir "ffmpeg.exe"
if (!(Test-Path $ffmpegPath)) {
    Write-Host "Downloading FFmpeg essentials package..." -ForegroundColor Yellow
    $zipPath = Join-Path $env:TEMP "ffmpeg-release-essentials.zip"
    Invoke-WebRequest -Uri "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip" -OutFile $zipPath
    
    Write-Host "Extracting FFmpeg..." -ForegroundColor Yellow
    $extractDir = Join-Path $env:TEMP "ffmpeg-extract"
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
    
    $extractedBin = Get-ChildItem -Path $extractDir -Recurse -Filter "ffmpeg.exe" | Select-Object -First 1
    if ($extractedBin) {
        Copy-Item (Join-Path $extractedBin.DirectoryName "ffmpeg.exe") -Destination $binDir -Force
        Copy-Item (Join-Path $extractedBin.DirectoryName "ffprobe.exe") -Destination $binDir -Force
        Write-Host "FFmpeg installed successfully." -ForegroundColor Green
    }
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "ffmpeg.exe already present." -ForegroundColor Green
}

Write-Host "All infyn-dl binaries are ready!" -ForegroundColor Cyan
