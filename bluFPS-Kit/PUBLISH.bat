@echo off
cd /d "%~dp0"
title Publish bluFPS update
powershell -NoProfile -ExecutionPolicy Bypass -File src\publish.ps1
echo.
pause
