# Writes version info (Task Manager / taskbar tooltip name + version) for the .exe files. Called by BUILD.bat.
$root = Split-Path $PSScriptRoot -Parent
$ver = [regex]::Match((Get-Content (Join-Path $root 'app\bluFPS.ps1') -Raw), "AppVersion = '([\d.]+)'").Groups[1].Value
if (-not $ver) { throw 'Could not read the version from app\bluFPS.ps1' }
$v4 = "$ver.0"; if (($ver.Split('.')).Count -ge 4) { $v4 = $ver }
function Write-Info($title, $file) {
@"
using System.Reflection;
[assembly: AssemblyTitle("$title")]
[assembly: AssemblyDescription("$title")]
[assembly: AssemblyProduct("bluFPS")]
[assembly: AssemblyCompany("bluFPS")]
[assembly: AssemblyVersion("$v4")]
[assembly: AssemblyFileVersion("$v4")]
"@ | Set-Content (Join-Path $root "build\$file") -Encoding ASCII
}
Write-Info 'bluFPS' 'AssemblyInfo.cs'
Write-Info 'bluFPS Setup' 'AssemblyInfoSetup.cs'
Write-Host "Version $ver"
