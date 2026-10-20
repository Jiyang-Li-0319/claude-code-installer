@echo off
rem Change the model provider without reinstalling Claude Code.
call "%~dp0install-claude-code.bat" /config-only
rem Keep the window open so errors stay readable after a double-click run.
echo.
pause
