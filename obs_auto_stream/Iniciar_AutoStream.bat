@echo off
title Pan Bendito - AutoStream OBS Monitor
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0PanBendito_AutoStream.ps1"
