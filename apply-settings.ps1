param(
    [string]$BaseUrl,
    [string]$AuthToken,
    [string]$ApiKey,
    [string]$Model,
    [string]$OpusModel,
    [string]$SonnetModel,
    [string]$HaikuModel,
    [switch]$ClearProvider,
    [switch]$DisableNonessentialTraffic,
    [switch]$MarkOnboarded
)

# Merges provider settings into %USERPROFILE%\.claude\settings.json
# without destroying unrelated settings (theme, permissions, hooks, ...).
# Empty values remove the corresponding key.

$ErrorActionPreference = 'Stop'

$settingsPath = Join-Path $env:USERPROFILE '.claude\settings.json'
$settingsDir  = Split-Path -Parent $settingsPath
if (-not (Test-Path $settingsDir)) {
    New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
}

function Read-SettingsFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return @{} }
    $raw = Get-Content -Path $Path -Raw -Encoding UTF8
    if ($null -eq $raw -or $raw.Trim().Length -eq 0) { return @{} }
    $obj = $raw | ConvertFrom-Json
    $hash = @{}
    foreach ($p in $obj.PSObject.Properties) { $hash[$p.Name] = $p.Value }
    return $hash
}

$settings = $null
try {
    $settings = Read-SettingsFile -Path $settingsPath
} catch {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    Copy-Item -Path $settingsPath -Destination "$settingsPath.broken-$stamp" -Force
    Write-Warning "Existing settings.json was not valid JSON. Backed up and starting fresh."
    $settings = @{}
}

$envMap = @{}
if ($settings.ContainsKey('env') -and $settings['env']) {
    foreach ($p in $settings['env'].PSObject.Properties) {
        if ($null -ne $p.Value) { $envMap[$p.Name] = [string]$p.Value }
    }
}

function Set-Or-Remove {
    param($Map, [string]$Key, [string]$Value)
    if (-not [string]::IsNullOrWhiteSpace($Value)) {
        $Map[$Key] = $Value.Trim()
    } else {
        $Map.Remove($Key) | Out-Null
    }
}

if ($ClearProvider) {
    $providerKeys = @(
        'ANTHROPIC_BASE_URL',
        'ANTHROPIC_AUTH_TOKEN',
        'ANTHROPIC_API_KEY',
        'ANTHROPIC_MODEL',
        'ANTHROPIC_DEFAULT_OPUS_MODEL',
        'ANTHROPIC_DEFAULT_SONNET_MODEL',
        'ANTHROPIC_DEFAULT_HAIKU_MODEL',
        'ANTHROPIC_SMALL_FAST_MODEL',
        'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC'
    )
    foreach ($k in $providerKeys) { $envMap.Remove($k) | Out-Null }
} else {
    Set-Or-Remove $envMap 'ANTHROPIC_BASE_URL'              $BaseUrl
    Set-Or-Remove $envMap 'ANTHROPIC_AUTH_TOKEN'            $AuthToken
    Set-Or-Remove $envMap 'ANTHROPIC_API_KEY'               $ApiKey
    Set-Or-Remove $envMap 'ANTHROPIC_MODEL'                 $Model
    Set-Or-Remove $envMap 'ANTHROPIC_DEFAULT_OPUS_MODEL'    $OpusModel
    Set-Or-Remove $envMap 'ANTHROPIC_DEFAULT_SONNET_MODEL'  $SonnetModel
    Set-Or-Remove $envMap 'ANTHROPIC_DEFAULT_HAIKU_MODEL'   $HaikuModel

    if ($DisableNonessentialTraffic) {
        $envMap['CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC'] = '1'
    } else {
        $envMap.Remove('CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC') | Out-Null
    }
}

$settings['env'] = $envMap

if (Test-Path $settingsPath) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    Copy-Item -Path $settingsPath -Destination "$settingsPath.bak-$stamp" -Force
}

$json = $settings | ConvertTo-Json -Depth 20
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($settingsPath, $json, $utf8NoBom)

if ($MarkOnboarded) {
    $cfgPath = Join-Path $env:USERPROFILE '.claude.json'
    $cfg = @{}
    $cfgReadOk = $true
    if (Test-Path $cfgPath) {
        try {
            $rawCfg = Get-Content -Path $cfgPath -Raw -Encoding UTF8
            if ($null -ne $rawCfg -and $rawCfg.Trim().Length -gt 0) {
                $objCfg = $rawCfg | ConvertFrom-Json
                foreach ($p in $objCfg.PSObject.Properties) { $cfg[$p.Name] = $p.Value }
            }
        } catch {
            $cfgReadOk = $false
            Copy-Item -Path $cfgPath -Destination "$cfgPath.broken-$(Get-Date -Format 'yyyyMMdd-HHmmss')" -Force
            $cfg = @{}
        }
    }
    if ($cfgReadOk -and $cfg['hasCompletedOnboarding'] -eq $true) {
        Write-Host 'Onboarding already complete.'
    } else {
        if (Test-Path $cfgPath) {
            Copy-Item -Path $cfgPath -Destination "$cfgPath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')" -Force
        }
        $cfg['hasCompletedOnboarding'] = $true
        $jsonCfg = $cfg | ConvertTo-Json -Depth 100
        [System.IO.File]::WriteAllText($cfgPath, $jsonCfg, $utf8NoBom)
        Write-Host 'Onboarding marked complete (skips the login screen).'
    }
}

function Mask-Secret {
    param([string]$Value)
    if ([string]::IsNullOrEmpty($Value)) { return '(not set)' }
    if ($Value.Length -le 10) { return '****' }
    return $Value.Substring(0, 4) + '****' + $Value.Substring($Value.Length - 4)
}

Write-Host ''
Write-Host 'Settings saved:' $settingsPath
Write-Host '  ANTHROPIC_BASE_URL   :' $(if ($envMap['ANTHROPIC_BASE_URL']) { $envMap['ANTHROPIC_BASE_URL'] } else { '(official / not set)' })
Write-Host '  ANTHROPIC_AUTH_TOKEN :' (Mask-Secret $envMap['ANTHROPIC_AUTH_TOKEN'])
Write-Host '  ANTHROPIC_API_KEY    :' (Mask-Secret $envMap['ANTHROPIC_API_KEY'])
Write-Host '  ANTHROPIC_MODEL      :' $(if ($envMap['ANTHROPIC_MODEL']) { $envMap['ANTHROPIC_MODEL'] } else { '(default)' })
Write-Host ''
