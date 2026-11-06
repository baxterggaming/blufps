# bluFPS uninstaller
Add-Type -AssemblyName PresentationFramework
$dir = $PSScriptRoot

$bak = Join-Path $env:APPDATA 'bluFPS\backup.json'
$active = $false
if (Test-Path $bak) { $t = (Get-Content $bak -Raw); if ($t -and $t.Trim() -ne '{}') { $active = $true } }
if ($active) {
    $a = [Windows.MessageBox]::Show("bluFPS tweaks are still applied to Windows.`n`nChoose No, open bluFPS and press 'Revert all' if you want them undone first.`n`nUninstall anyway?", 'Uninstall bluFPS', 'YesNo', 'Warning')
    if ($a -ne 'Yes') { exit }
}

try { Start-Process schtasks.exe -ArgumentList '/Delete /TN "bluFPS" /F' -WindowStyle Hidden -Wait } catch {}
Remove-Item (Join-Path ([Environment]::GetFolderPath('Desktop')) 'bluFPS.lnk') -ErrorAction SilentlyContinue
Remove-Item (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\bluFPS.lnk') -ErrorAction SilentlyContinue
Remove-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\bluFPS' -Recurse -ErrorAction SilentlyContinue

# delete the install folder after this script exits
Start-Process cmd.exe -WindowStyle Hidden -ArgumentList "/c ping 127.0.0.1 -n 3 >nul & rmdir /s /q `"$dir`""
[Windows.MessageBox]::Show('bluFPS has been removed.', 'Uninstall bluFPS', 'OK', 'Information') | Out-Null
