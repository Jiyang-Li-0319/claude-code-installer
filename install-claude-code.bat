@echo off
setlocal EnableExtensions
title Claude Code Installer for Windows
cd /d "%~dp0"

set "SCRIPT_DIR=%~dp0"
set "HELPER=%SCRIPT_DIR%apply-settings.ps1"
set "PS=powershell -NoProfile -ExecutionPolicy Bypass"
set "CONFIG_ONLY=0"
if /i "%~1"=="/config-only" set "CONFIG_ONLY=1"

rem All helper scripts must sit next to this file. Running the .bat straight
rem out of a WeChat / QQ download folder leaves them behind, and the
rem configuration step then fails with a confusing PowerShell error.
set "MISSING="
for %%f in (apply-settings.ps1 test-connection.ps1 install-node.ps1) do (
    if not exist "%SCRIPT_DIR%%%f" (
        echo Missing helper file: %%f
        set "MISSING=1"
    )
)
if defined MISSING goto :missing_files

echo ================================================================
echo   Claude Code one-click installer for Windows 10/11
echo ================================================================
echo.
echo This script installs Claude Code and configures it to use
echo DeepSeek / Kimi / GLM / Qwen / MiniMax / OpenRouter / Anthropic.
echo It does NOT need administrator rights (except the Node.js MSI,
echo where Windows will show a UAC prompt).
echo.

if "%CONFIG_ONLY%"=="1" goto :configure
call :install
call :configure
goto :end


rem ---------------------------------------------------------------
rem Install Claude Code
rem ---------------------------------------------------------------
:install
echo [1/3] Checking the existing installation...
where claude.cmd >nul 2>nul
if not errorlevel 1 goto :have_claude
where claude.exe >nul 2>nul
if not errorlevel 1 goto :have_claude

echo Claude Code was not found. Starting installation...
call :ensure_node
if errorlevel 1 goto :try_native

echo.
echo Installing from npm (this can take a few minutes)...
call npm install -g @anthropic-ai/claude-code@latest
if errorlevel 1 (
    echo.
    echo npmjs.org failed. Retrying with the npmmirror registry...
    call npm install -g @anthropic-ai/claude-code@latest --registry=https://registry.npmmirror.com
)
if errorlevel 1 goto :try_native

set "PATH=%APPDATA%\npm;%PATH%"
where claude.cmd >nul 2>nul
if errorlevel 1 (
    echo npm reported success, but claude.cmd was not found.
    goto :try_native
)
goto :have_claude

:try_native
echo.
echo Trying the official native installer...
echo NOTE: claude.ai may be blocked in mainland China. If it fails,
echo       use a VPN/proxy or install Node.js manually and re-run.
%PS% -Command "irm https://claude.ai/install.ps1 | iex"
if errorlevel 1 (
    echo.
    echo ERROR: automatic installation failed.
    echo.
    echo Manual fix:
    echo   1. Install Node.js 22 or newer from https://nodejs.org
    echo   2. Open a NEW cmd window and run:
    echo      npm install -g @anthropic-ai/claude-code
    echo   3. Re-run this script.
    echo.
    pause
    exit /b 1
)
set "PATH=%USERPROFILE%\.local\bin;%PATH%"
call :add_native_path
where claude.exe >nul 2>nul
if errorlevel 1 (
    echo.
    echo Native install finished, but claude.exe is not visible yet.
    echo Close this window, open a NEW cmd window, and run this script again.
    pause
    exit /b 1
)

:have_claude
echo.
echo Installed version:
call claude --version
echo.
goto :eof


rem ---------------------------------------------------------------
rem Ensure Node.js 22+
rem ---------------------------------------------------------------
:ensure_node
where node >nul 2>nul
if errorlevel 1 goto :node_missing

set "NODE_VER="
for /f "delims=" %%v in ('node -v 2^>nul') do set "NODE_VER=%%v"
set "NODE_MAJOR=%NODE_VER:v=%"
for /f "tokens=1 delims=." %%a in ("%NODE_MAJOR%") do set "NODE_MAJOR=%%a"
if not defined NODE_MAJOR goto :node_missing
if %NODE_MAJOR% LSS 22 (
    echo Node.js %NODE_VER% is too old. Claude Code needs Node.js 22 or newer.
    goto :node_missing
)
echo Node.js %NODE_VER% found.
exit /b 0

:node_missing
echo.
echo Node.js 22+ is required. Trying to install Node.js LTS...
where winget >nul 2>nul
if errorlevel 1 goto :node_msi
echo.
echo Using winget...
call winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements
set "PATH=%ProgramFiles%\nodejs;%APPDATA%\npm;%PATH%"
where node >nul 2>nul
if not errorlevel 1 (
    echo Node.js installed with winget.
    exit /b 0
)

:node_msi
echo.
echo Downloading and installing Node.js LTS from nodejs.org...
%PS% -File "%SCRIPT_DIR%install-node.ps1"
if errorlevel 1 (
    echo Node.js installation failed or was cancelled.
    exit /b 1
)
set "PATH=%ProgramFiles%\nodejs;%APPDATA%\npm;%PATH%"
where node >nul 2>nul
if errorlevel 1 (
    echo Node.js was installed but is not visible in this window.
    echo Close this window, open a NEW cmd window, and re-run this script.
    exit /b 1
)
echo Node.js installed.
exit /b 0


rem ---------------------------------------------------------------
rem Add the native install directory to the user PATH (registry)
rem ---------------------------------------------------------------
:add_native_path
%PS% -Command "$dir = Join-Path $env:USERPROFILE '.local\bin'; $cur = (Get-ItemProperty -Path 'HKCU:\Environment' -Name Path -ErrorAction SilentlyContinue).Path; if ($null -eq $cur) { $cur = '' }; if ($cur -notlike ('*' + $dir + '*')) { $new = (($cur.TrimEnd(';') + ';' + $dir).TrimStart(';')); Set-ItemProperty -Path 'HKCU:\Environment' -Name Path -Value $new -Type ExpandString; Write-Host ('Added to user PATH: ' + $dir) } else { Write-Host 'User PATH already contains the native install directory.' }"
exit /b 0


rem ---------------------------------------------------------------
rem Choose and apply a model provider
rem ---------------------------------------------------------------
:configure
echo [2/3] Choose the model provider for this computer:
echo.
echo   1. DeepSeek            (mainland China, recommended)
echo   2. Kimi / Moonshot     (mainland China)
echo   3. Zhipu GLM           (mainland China)
echo   4. Qwen / DashScope    (mainland China)
echo   5. MiniMax             (mainland China)
echo   6. OpenRouter          (international models)
echo   7. Anthropic official  (Claude account; VPN needed in CN)
echo   8. Custom Anthropic-compatible endpoint
echo   9. Skip configuration
echo.
set "PROVIDER="
set /p "PROVIDER=Enter 1-9 [1]: "
if not defined PROVIDER set "PROVIDER=1"

set "CC_LABEL="
set "CC_BASE_URL="
set "CC_MODEL="
set "CC_OPUS_MODEL="
set "CC_SONNET_MODEL="
set "CC_HAIKU_MODEL="
set "CC_KEY="
set "CC_OFFICIAL=0"

if "%PROVIDER%"=="1" goto :p_deepseek
if "%PROVIDER%"=="2" goto :p_kimi
if "%PROVIDER%"=="3" goto :p_glm
if "%PROVIDER%"=="4" goto :p_qwen
if "%PROVIDER%"=="5" goto :p_minimax
if "%PROVIDER%"=="6" goto :p_openrouter
if "%PROVIDER%"=="7" goto :p_official
if "%PROVIDER%"=="8" goto :p_custom
if "%PROVIDER%"=="9" goto :p_skip
echo Invalid choice - skipping configuration.
goto :configure_done

:p_deepseek
set "CC_LABEL=DeepSeek"
set "CC_BASE_URL=https://api.deepseek.com/anthropic"
set "CC_MODEL=deepseek-flash[1m]"
set "CC_OPUS_MODEL=deepseek-flash[1m]"
set "CC_SONNET_MODEL=deepseek-flash[1m]"
set "CC_HAIKU_MODEL=deepseek-flash"
goto :ask_key

:p_kimi
set "CC_LABEL=Kimi / Moonshot"
set "CC_BASE_URL=https://api.moonshot.cn/anthropic"
set "CC_MODEL=kimi-k3[1m]"
set "CC_OPUS_MODEL=kimi-k3[1m]"
set "CC_SONNET_MODEL=kimi-k3[1m]"
set "CC_HAIKU_MODEL=kimi-k2.7-code-highspeed"
goto :ask_key

:p_glm
set "CC_LABEL=Zhipu GLM"
set "CC_BASE_URL=https://open.bigmodel.cn/api/anthropic"
set "CC_MODEL=glm-5.3[1m]"
set "CC_OPUS_MODEL=glm-5.3[1m]"
set "CC_SONNET_MODEL=glm-5.3[1m]"
set "CC_HAIKU_MODEL=glm-5.3-flash[1m]"
goto :ask_key

:p_qwen
set "CC_LABEL=Qwen / DashScope"
set "CC_BASE_URL=https://dashscope.aliyuncs.com/apps/anthropic"
set "CC_MODEL=qwen3.7-plus"
set "CC_OPUS_MODEL=qwen3.7-plus"
set "CC_SONNET_MODEL=qwen3.7-plus"
set "CC_HAIKU_MODEL=qwen3.7-plus"
goto :ask_key

:p_minimax
set "CC_LABEL=MiniMax"
set "CC_BASE_URL=https://api.minimax.cn/anthropic"
set "CC_MODEL=MiniMax-M3"
set "CC_OPUS_MODEL=MiniMax-M3"
set "CC_SONNET_MODEL=MiniMax-M3"
set "CC_HAIKU_MODEL=MiniMax-M3.1-Flash[1m]"
goto :ask_key

:p_openrouter
set "CC_LABEL=OpenRouter"
set "CC_BASE_URL=https://openrouter.ai/api"
echo.
echo OpenRouter needs a model slug such as anthropic/claude-sonnet-4.5
echo or openai/gpt-5.1. Check https://openrouter.ai/models for the
echo current list.
set /p "CC_MODEL=Model slug: "
if not defined CC_MODEL (
    echo No model entered - skipping configuration.
    goto :configure_done
)
set "CC_OPUS_MODEL=%CC_MODEL%"
set "CC_SONNET_MODEL=%CC_MODEL%"
set "CC_HAIKU_MODEL=%CC_MODEL%"
goto :ask_key

:p_official
set "CC_LABEL=Anthropic official"
set "CC_OFFICIAL=1"
goto :apply_config

:p_custom
set "CC_LABEL=Custom endpoint"
echo.
set /p "CC_BASE_URL=Base URL (for example https://api.example.com/anthropic): "
if not defined CC_BASE_URL goto :configure_done
set /p "CC_MODEL=Model id: "
if not defined CC_MODEL goto :configure_done
set "CC_OPUS_MODEL=%CC_MODEL%"
set "CC_SONNET_MODEL=%CC_MODEL%"
set "CC_HAIKU_MODEL=%CC_MODEL%"
goto :ask_key

:p_skip
echo Skipped provider configuration.
goto :configure_done

:ask_key
if defined CLAUDE_CODE_API_KEY (
    set "CC_KEY=%CLAUDE_CODE_API_KEY%"
    echo Using the API key from the CLAUDE_CODE_API_KEY environment variable.
    goto :apply_config
)
echo.
echo Paste the API key for %CC_LABEL% (it will be visible while pasting).
set /p "CC_KEY=API key: "
if not defined CC_KEY (
    echo No key entered. Installation is done, but the provider was not configured.
    echo Re-run switch-provider.bat later.
    goto :configure_done
)
goto :apply_config

:apply_config
echo.
echo [3/3] Writing configuration...
if "%CC_OFFICIAL%"=="1" (
    %PS% -File "%HELPER%" -ClearProvider
    if errorlevel 1 (
        echo ERROR: failed to update settings.json.
        goto :configure_done
    )
    echo.
    echo Official Anthropic selected.
    echo Run: claude
    echo Log in with /login if prompted. A VPN/proxy is required in mainland China.
    goto :configure_done
)

%PS% -File "%HELPER%" -BaseUrl "%CC_BASE_URL%" -AuthToken "%CC_KEY%" -Model "%CC_MODEL%" -OpusModel "%CC_OPUS_MODEL%" -SonnetModel "%CC_SONNET_MODEL%" -HaikuModel "%CC_HAIKU_MODEL%" -DisableNonessentialTraffic -MarkOnboarded
if errorlevel 1 (
    echo ERROR: failed to update settings.json.
    goto :configure_done
)

echo.
echo Testing the connection (a short request will be sent)...
%PS% -File "%SCRIPT_DIR%test-connection.ps1" -TimeoutSeconds 90
if errorlevel 1 (
    echo.
    echo Test failed. Common causes:
    echo   - wrong API key or no credit
    echo   - base URL / model id changed (check the provider's docs)
    echo   - a proxy or VPN is interfering
    echo Run "claude doctor" for diagnostics.
) else (
    echo.
    echo Success! Claude Code is ready.
)

:configure_done
echo.
echo ----------------------------------------------------------------
echo Next steps:
echo   cd /d your-project-folder
echo   claude
echo In the session, run /status to confirm the active model and endpoint.
echo ----------------------------------------------------------------
echo.
goto :eof


:missing_files
echo.
echo ERROR: some helper files are missing from this folder.
echo.
echo This usually means the .bat was run straight out of a chat app's
echo download cache (WeChat / QQ) or only the .bat file was copied.
echo.
echo Fix:
echo   1. Copy the WHOLE ClaudeCode-Installer folder to a normal place,
echo      for example C:\ClaudeCode-Installer
echo   2. Do not run it from inside a .zip preview or a chat cache folder
echo   3. Run install-claude-code.bat from the copied folder
echo.
pause
exit /b 1


:end
pause
exit /b 0
