@echo off
setlocal
cd /d "%~dp0"
title Building bluFPS

rem --- find the C# compiler that ships with Windows ---
set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if not exist "%CSC%" (
  echo Could not find the C# compiler that comes with Windows ^(.NET Framework 4^).
  echo Turn on ".NET Framework 4.8 Advanced Services" in Windows Features, then run BUILD.bat again.
  pause
  exit /b 1
)

rem --- check every script with the real PowerShell parser before building anything ---
powershell -NoProfile -ExecutionPolicy Bypass -File src\check.ps1
if errorlevel 1 (
  echo.
  echo A bluFPS script has an error and would not start. Nothing was built or published.
  echo Send the red text above.
  pause
  exit /b 1
)

rem --- find the PowerShell engine library that ships with Windows ---
set "SMA="
for /f "delims=" %%F in ('dir /b /s "%WINDIR%\Microsoft.NET\assembly\GAC_MSIL\System.Management.Automation\System.Management.Automation.dll" 2^>nul') do set "SMA=%%F"
if not defined SMA for /f "delims=" %%F in ('dir /b /s "%WINDIR%\assembly\GAC_MSIL\System.Management.Automation\System.Management.Automation.dll" 2^>nul') do set "SMA=%%F"
if not defined SMA if exist "%WINDIR%\System32\WindowsPowerShell\v1.0\System.Management.Automation.dll" set "SMA=%WINDIR%\System32\WindowsPowerShell\v1.0\System.Management.Automation.dll"
if not defined SMA (
  echo Could not find System.Management.Automation.dll ^(part of Windows PowerShell 5.1^).
  pause
  exit /b 1
)

if exist build rmdir /s /q build
if exist dist rmdir /s /q dist
mkdir build
mkdir dist
powershell -NoProfile -ExecutionPolicy Bypass -File src\prebuild.ps1
if errorlevel 1 goto fail

echo [1/3] Building bluFPS.exe ...
"%CSC%" /nologo /target:winexe /optimize+ /out:build\bluFPS.exe /win32icon:app\bluFPS.ico /win32manifest:src\app.manifest /r:System.Windows.Forms.dll /r:"%SMA%" build\AssemblyInfo.cs src\PsHost.cs src\Launcher.cs
if errorlevel 1 goto fail

echo [2/3] Building the one-file installer ...
set "RES=/resource:build\bluFPS.exe,bluFPS.exe /resource:app\bluFPS.ps1,bluFPS.ps1 /resource:app\bluFPS.vbs,bluFPS.vbs /resource:app\bluFPS.ico,bluFPS.ico /resource:app\bluFPS.png,bluFPS.png /resource:app\Uninstall.ps1,Uninstall.ps1 /resource:app\update-source.txt,update-source.txt /resource:app\Setup.ps1,Setup.ps1"
"%CSC%" /nologo /target:winexe /optimize+ /out:dist\bluFPS-Setup.exe /win32icon:app\bluFPS.ico /win32manifest:src\setup.manifest /r:System.Windows.Forms.dll /r:"%SMA%" %RES% build\AssemblyInfoSetup.cs src\PsHost.cs src\Installer.cs
if errorlevel 1 goto fail

echo [3/3] Packaging ...
powershell -NoProfile -ExecutionPolicy Bypass -File src\pack.ps1
if errorlevel 1 goto fail

echo.
echo Done! Your files are in the "dist" folder:
dir /b dist
echo.
echo Share the -Setup.exe with anyone. Keep the -update.zip for auto-updates (see UPDATING.txt).
if exist "%APPDATA%\bluFPS\publish.json" (
  echo.
  echo Publishing this version online - every installed bluFPS will find it and offer the update by itself...
  powershell -NoProfile -ExecutionPolicy Bypass -File src\publish.ps1 -Auto
) else (
  echo.
  echo TIP: run PUBLISH.bat ONCE to switch on online updates. After that, BUILD.bat publishes every new version by itself.
)
explorer dist
pause
exit /b 0

:fail
echo.
echo Build failed - see the messages above.
pause
exit /b 1
