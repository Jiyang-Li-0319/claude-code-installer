param(
    [switch]$DryRun
)

# Downloads the current Node.js LTS MSI and installs it silently.
# Windows shows a UAC prompt because the MSI installs machine-wide.

$ErrorActionPreference = 'Stop'

$arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }

Write-Host 'Looking up the current Node.js LTS release...'
$index = Invoke-RestMethod -Uri 'https://nodejs.org/dist/index.json' -UseBasicParsing
$lts = $index | Where-Object { $_.lts } | Select-Object -First 1
if (-not $lts) { throw 'No Node.js LTS release found.' }

$version = $lts.version
$url = 'https://nodejs.org/dist/' + $version + '/node-' + $version + '-' + $arch + '.msi'
Write-Host ('Node.js LTS: ' + $version + ' (' + $arch + ')')
Write-Host ('Download:   ' + $url)

if ($DryRun) { exit 0 }

$msi = Join-Path $env:TEMP ('node-' + $version + '-' + $arch + '.msi')
Write-Host 'Downloading...'
Invoke-WebRequest -Uri $url -OutFile $msi -UseBasicParsing

Write-Host 'Installing (a UAC prompt may appear)...'
$process = Start-Process msiexec.exe -ArgumentList ('/i "' + $msi + '" /passive /norestart') -Wait -PassThru
if ($process.ExitCode -ne 0) {
    throw ('msiexec failed with exit code ' + $process.ExitCode)
}

Remove-Item -Path $msi -Force -ErrorAction SilentlyContinue
Write-Host 'Node.js installed.'
exit 0
