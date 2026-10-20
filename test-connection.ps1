param(
    [int]$TimeoutSeconds = 90,
    [string]$Prompt = 'Reply with exactly: ok'
)

# Runs a short non-interactive request with a hard timeout.
# On timeout the whole process tree is killed, so a bad key or an
# unreachable endpoint cannot leave a hung claude.exe behind.

$ErrorActionPreference = 'Stop'

$outFile = [System.IO.Path]::GetTempFileName()
$errFile = [System.IO.Path]::GetTempFileName()

$cmdLine = '/d /c claude -p "' + $Prompt + '" --output-format json'

$proc = Start-Process -FilePath $env:ComSpec `
    -ArgumentList $cmdLine `
    -NoNewWindow -PassThru `
    -RedirectStandardOutput $outFile `
    -RedirectStandardError $errFile

$exited = $proc.WaitForExit($TimeoutSeconds * 1000)

if (-not $exited) {
    & taskkill.exe /PID $proc.Id /T /F 2>&1 | Out-Null
    Write-Host "Connection test timed out after $TimeoutSeconds seconds."
    $outText = Get-Content -Path $outFile -Raw -ErrorAction SilentlyContinue
    $errText = Get-Content -Path $errFile -Raw -ErrorAction SilentlyContinue
    if ($outText) { Write-Host $outText.TrimEnd() }
    if ($errText) { Write-Host $errText.TrimEnd() }
    Remove-Item $outFile, $errFile -Force -ErrorAction SilentlyContinue
    exit 1
}

$outText = Get-Content -Path $outFile -Raw -ErrorAction SilentlyContinue
$errText = Get-Content -Path $errFile -Raw -ErrorAction SilentlyContinue
if ($outText) { Write-Host $outText.TrimEnd() }
if ($errText) { Write-Host $errText.TrimEnd() }

$code = $proc.ExitCode
Remove-Item $outFile, $errFile -Force -ErrorAction SilentlyContinue
exit $code
