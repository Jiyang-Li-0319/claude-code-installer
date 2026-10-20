param(
    [int]$TimeoutSeconds = 60
)

# Read-only diagnostics for "Failed to connect to api.anthropic.com: Status 403".
# Prints where claude lives, what settings/env it will actually use, which
# endpoints are reachable, and finishes with one real test request.
# This file is intentionally pure ASCII.

$ErrorActionPreference = 'SilentlyContinue'

# Everything printed below is also written to this file, so the whole report
# can be sent back instead of scrolling a cmd window.
$reportPath = Join-Path $PSScriptRoot ('diagnose-report-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.txt')
$transcriptStarted = $false
try {
    Start-Transcript -Path $reportPath -Force | Out-Null
    $transcriptStarted = $true
} catch {
}

function Mask-Secret {
    param([string]$Value)
    if ([string]::IsNullOrEmpty($Value)) { return '(not set)' }
    if ($Value.Length -le 10) { return '****' }
    return $Value.Substring(0, 4) + '****' + $Value.Substring($Value.Length - 4)
}

function Write-Section {
    param([string]$Title)
    Write-Host ''
    Write-Host ('--- ' + $Title + ' ---')
}

Write-Host '================================================'
Write-Host ' Claude Code connection diagnostics'
Write-Host '================================================'

Write-Section 'System'
Write-Host ('User        : ' + $env:USERNAME)
Write-Host ('Profile     : ' + $env:USERPROFILE)
Write-Host ('Working dir : ' + (Get-Location).Path)

Write-Section 'claude command'
$found = $false
foreach ($name in @('claude.exe', 'claude.cmd', 'claude')) {
    $c = Get-Command $name -ErrorAction SilentlyContinue
    if ($c) {
        Write-Host ($c.Name + ' -> ' + $c.Source)
        $found = $true
    }
}
if (-not $found) {
    Write-Host 'claude was not found on PATH in this window.'
} else {
    $ver = & claude --version 2>&1
    Write-Host ('version     : ' + (($ver | Out-String).Trim()))
}

Write-Section 'Config files'
$settingsPath = Join-Path $env:USERPROFILE '.claude\settings.json'
$baseUrlSetting = $null
$tokenSetting = $null
if (Test-Path $settingsPath) {
    Write-Host ('settings.json : ' + $settingsPath)
    $raw = Get-Content -Path $settingsPath -Raw -Encoding UTF8
    try {
        $obj = $raw | ConvertFrom-Json
        $envBlock = $obj.env
        if ($null -eq $envBlock) {
            Write-Host '  WARNING: there is no "env" block.'
        } else {
            foreach ($p in $envBlock.PSObject.Properties) {
                $v = [string]$p.Value
                if ($p.Name -eq 'ANTHROPIC_BASE_URL') { $baseUrlSetting = $v }
                if ($p.Name -eq 'ANTHROPIC_AUTH_TOKEN' -or $p.Name -eq 'ANTHROPIC_API_KEY') { $tokenSetting = $v }
                if ($p.Name -match 'TOKEN|KEY|SECRET') { $v = Mask-Secret $v }
                Write-Host ('  env.' + $p.Name + ' = ' + $v)
            }
        }
    } catch {
        Write-Host '  WARNING: settings.json is not valid JSON.'
    }
} else {
    Write-Host ('NO settings.json at ' + $settingsPath)
}

$cfgPath = Join-Path $env:USERPROFILE '.claude.json'
if (Test-Path $cfgPath) {
    try {
        $cfg = Get-Content -Path $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Write-Host ('  hasCompletedOnboarding = ' + $cfg.hasCompletedOnboarding)
        if ($cfg.oauthAccount) {
            Write-Host '  oauthAccount present: this machine has logged in with a Claude account.'
        }
    } catch {
        Write-Host '  .claude.json is not valid JSON.'
    }
} else {
    Write-Host ('NO .claude.json at ' + $cfgPath)
}

Write-Section 'Key findings'
if (-not (Test-Path $settingsPath)) {
    Write-Host '  settings.json is MISSING, so claude falls back to the official endpoint.'
}
if ([string]::IsNullOrWhiteSpace($baseUrlSetting)) {
    Write-Host '  ANTHROPIC_BASE_URL is NOT set in settings.json.'
} else {
    Write-Host ('  settings.json ANTHROPIC_BASE_URL = ' + $baseUrlSetting)
}
if ([string]::IsNullOrWhiteSpace($tokenSetting)) {
    Write-Host '  No API key / auth token is set in settings.json.'
} else {
    Write-Host '  An API key / auth token is present (masked above).'
}
$procBase = [Environment]::GetEnvironmentVariable('ANTHROPIC_BASE_URL', 'Process')
if ($procBase -and $baseUrlSetting -and ($procBase -ne $baseUrlSetting)) {
    Write-Host ('  WARNING: this window also has ANTHROPIC_BASE_URL=' + $procBase)
    Write-Host '           (different from settings.json; env usually wins).'
}
if ([string]::IsNullOrWhiteSpace($baseUrlSetting) -and [string]::IsNullOrWhiteSpace($procBase)) {
    Write-Host '  VERDICT: no third-party endpoint is configured. api.anthropic.com returns'
    Write-Host '           403 for mainland-China networks, which matches the reported error.'
    Write-Host '  ACTION : run switch-provider.bat, choose 1 (DeepSeek), paste an API key,'
    Write-Host '           then close claude, open a NEW cmd window and run claude again.'
} else {
    Write-Host '  VERDICT: an endpoint IS configured. If the test request still fails,'
    Write-Host '           the error text below says whether it is the key or the endpoint.'
}

Write-Section 'Effective environment variables'
$names = @(
    'ANTHROPIC_BASE_URL',
    'ANTHROPIC_AUTH_TOKEN',
    'ANTHROPIC_API_KEY',
    'ANTHROPIC_MODEL',
    'ANTHROPIC_DEFAULT_OPUS_MODEL',
    'ANTHROPIC_DEFAULT_SONNET_MODEL',
    'ANTHROPIC_DEFAULT_HAIKU_MODEL',
    'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC',
    'CLAUDE_CONFIG_DIR',
    'HTTPS_PROXY',
    'HTTP_PROXY',
    'NO_PROXY'
)
foreach ($n in $names) {
    $procVal = [Environment]::GetEnvironmentVariable($n, 'Process')
    $userVal = [Environment]::GetEnvironmentVariable($n, 'User')
    $machVal = [Environment]::GetEnvironmentVariable($n, 'Machine')
    $parts = @()
    if ($procVal) { $parts += ('this-window=' + $procVal) }
    if ($userVal) { $parts += ('user=' + $userVal) }
    if ($machVal) { $parts += ('machine=' + $machVal) }
    if ($parts.Count -eq 0) {
        Write-Host ('  ' + $n + ' = (not set)')
    } else {
        $joined = $parts -join '  |  '
        if ($n -match 'TOKEN|KEY') { $joined = Mask-Secret ($parts -join '') }
        Write-Host ('  ' + $n + ' = ' + $joined)
    }
}

Write-Section 'Network reachability'
Write-Host '(403 from api.anthropic.com is the regional block, not a broken network.)'
$urls = @(
    'https://api.anthropic.com/v1/models',
    'https://api.deepseek.com/anthropic',
    'https://api.moonshot.cn',
    'https://open.bigmodel.cn',
    'https://dashscope.aliyuncs.com',
    'https://api.minimax.cn'
)
foreach ($u in $urls) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $code = -1
    try {
        $r = Invoke-WebRequest -Uri $u -Method Get -TimeoutSec 12 -UseBasicParsing -MaximumRedirection 2
        $code = [int]$r.StatusCode
    } catch {
        if ($_.Exception.Response) {
            $code = [int]$_.Exception.Response.StatusCode
        }
    }
    $sw.Stop()
    $label = if ($code -eq -1) { 'NO RESPONSE' } else { 'HTTP ' + $code }
    Write-Host ('  ' + $u + ' -> ' + $label + ' (' + $sw.ElapsedMilliseconds + ' ms)')
}

Write-Section 'Test request'
$outFile = [System.IO.Path]::GetTempFileName()
$errFile = [System.IO.Path]::GetTempFileName()
$cmdLine = '/d /c claude -p "Reply with exactly: ok" --output-format json'
$proc = Start-Process -FilePath $env:ComSpec `
    -ArgumentList $cmdLine `
    -NoNewWindow -PassThru `
    -RedirectStandardOutput $outFile `
    -RedirectStandardError $errFile

$exited = $proc.WaitForExit($TimeoutSeconds * 1000)
if (-not $exited) {
    & taskkill.exe /PID $proc.Id /T /F 2>&1 | Out-Null
    Write-Host ('  TIMEOUT after ' + $TimeoutSeconds + ' seconds')
}
$outText = Get-Content -Path $outFile -Raw -ErrorAction SilentlyContinue
$errText = Get-Content -Path $errFile -Raw -ErrorAction SilentlyContinue
if ($outText) { Write-Host $outText.TrimEnd() }
if ($errText) { Write-Host $errText.TrimEnd() }
Remove-Item $outFile, $errFile -Force -ErrorAction SilentlyContinue

Write-Host ''
Write-Host '================================================'
Write-Host ' What the results mean'
Write-Host '================================================'
Write-Host ' - "Failed to connect to api.anthropic.com: Status 403" in the test request'
Write-Host '   means NO third-party endpoint is configured (or settings.json did not load).'
Write-Host '   Fix: run switch-provider.bat and choose a mainland-China provider.'
Write-Host ' - If env.ANTHROPIC_BASE_URL is set here but the request still hits'
Write-Host '   api.anthropic.com, an OS-level ANTHROPIC_* variable is overriding it,'
Write-Host '   or claude is reading a different config directory.'
Write-Host ' - Right after changing settings.json you must close claude completely and'
Write-Host '   open a NEW cmd window.'
Write-Host ''
if ($transcriptStarted) { Stop-Transcript | Out-Null }
Write-Host ('Full report saved to: ' + $reportPath)
Write-Host ''
