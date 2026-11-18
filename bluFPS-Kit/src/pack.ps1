# Creates the final files in dist\ (called by BUILD.bat)
$root = Split-Path $PSScriptRoot -Parent
$app = Join-Path $root 'app'; $dist = Join-Path $root 'dist'; $build = Join-Path $root 'build'
$ver = [regex]::Match((Get-Content (Join-Path $app 'bluFPS.ps1') -Raw), "AppVersion = '([\d.]+)'").Groups[1].Value
if (-not $ver) { throw 'Could not read the version from app\bluFPS.ps1' }

Rename-Item (Join-Path $dist 'bluFPS-Setup.exe') "bluFPS-v$ver-Setup.exe"

$files = @('bluFPS.ps1', 'bluFPS.vbs', 'bluFPS.ico', 'bluFPS.png', 'Uninstall.ps1') | ForEach-Object { Join-Path $app $_ }
$files += Join-Path $build 'bluFPS.exe'
if (Test-Path (Join-Path $root 'CHANGELOG.txt')) { $files += Join-Path $root 'CHANGELOG.txt' }
$zip = Join-Path $dist "bluFPS-v$ver-update.zip"
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path $files -DestinationPath $zip
$macSrc = Join-Path $root 'mac'
if (Test-Path $macSrc) {
    $tmp = Join-Path $build 'mac'
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    Copy-Item $macSrc $tmp -Recurse
    $utf8 = New-Object Text.UTF8Encoding $false
    $sw = Join-Path $tmp 'Sources\main.swift'
    [IO.File]::WriteAllText($sw, ((Get-Content $sw -Raw) -replace 'let appVersion = "[\d.]+"', ('let appVersion = "' + $ver + '"')), $utf8)
    $pl = Join-Path $tmp 'Info.plist'
    [IO.File]::WriteAllText($pl, ((Get-Content $pl -Raw) -replace '(?s)(<key>CFBundleShortVersionString</key>\s*<string>)[\d.]+(</string>)', ('${1}' + (($ver -split '\.')[0..2] -join '.') + '${2}')), $utf8)
    $macZip = Join-Path $dist "bluFPS-v$ver-Mac.zip"
    if (Test-Path $macZip) { Remove-Item $macZip }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory($tmp, $macZip, [IO.Compression.CompressionLevel]::Optimal, $false)
}
Write-Host "Version $ver"
