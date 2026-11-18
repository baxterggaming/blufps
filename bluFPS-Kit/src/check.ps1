# Parses every bluFPS script with the real PowerShell parser. A script that does not parse will not start on a PC,
# so BUILD.bat runs this first and stops before building or publishing anything broken.
$root = Split-Path -Parent $PSScriptRoot
$bad = 0
$dirs = @((Join-Path $root 'app'), (Join-Path $root 'src'))
foreach ($f in (Get-ChildItem -Path $dirs -Filter *.ps1 -File)) {
    $tokens = $null; $errs = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errs)
    if ($errs -and $errs.Count) {
        $bad++
        Write-Host "ERROR in $($f.Name)" -ForegroundColor Red
        foreach ($e in ($errs | Select-Object -First 8)) { Write-Host "  line $($e.Extent.StartLineNumber): $($e.Message)" -ForegroundColor Red }
    } else { Write-Host "ok  $($f.Name)" }
}
# building on this PC marks it as the owner's PC, which is what makes the owner sign-in available in the app
try { $dd = Join-Path $env:APPDATA 'bluFPS'; New-Item $dd -ItemType Directory -Force | Out-Null; $mark = Join-Path $dd 'owner.enable'; if (-not (Test-Path $mark)) { Set-Content $mark 'This PC builds bluFPS (owner PC).' } } catch {}
if ($bad) { exit 1 }
