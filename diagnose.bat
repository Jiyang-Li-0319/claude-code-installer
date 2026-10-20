@echo off
setlocal
cd /d "%~dp0"
title Claude Code diagnostics
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0diagnose.ps1" %*
echo.
echo A full report was saved as diagnose-report-*.txt in this folder.
echo Send that file back for analysis.
pause
