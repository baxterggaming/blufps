@echo off
if not exist "%~dp0Setup.ps1" (
  echo Please extract the whole zip folder first, then run Setup.bat again.
  pause
  exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0Setup.ps1"
