[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$devTools = Join-Path $repoRoot 'dev-tools'
$spaRun = Join-Path $devTools 'spa-run.ps1'
$stateTools = Join-Path $devTools 'm1-state.ps1'
$failures = New-Object System.Collections.Generic.List[string]

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if ($Condition) {
        Write-Host "PASS: $Message"
    }
    else {
        $script:failures.Add($Message)
        Write-Host "FAIL: $Message"
    }
}

function Assert-Match {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Message
    )

    Assert-True ([regex]::IsMatch($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) $Message
}

function Invoke-SpaRun {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $spaRun @Arguments 2>&1 | Out-String
    [pscustomobject]@{
        Code = $LASTEXITCODE
        Output = $output
    }
}

if (-not (Test-Path -LiteralPath $stateTools -PathType Leaf)) {
    throw "M1 state helper is missing: $stateTools"
}
. $stateTools

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('spa-health-test-' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $healthRoot = Join-Path $tempRoot 'health'
    New-Item -ItemType Directory -Path $healthRoot -Force | Out-Null
    $emptyHealthRoot = Join-Path $tempRoot 'empty-health'

    $started = [datetimeoffset]'2026-09-07T10:00:00+00:00'
    $activeHealth = Get-SpaHealthStatus -Now $started.AddMinutes(5) -StartedAt $started -LastOutputAt $started.AddMinutes(1) -ProcessAlive $true
    Assert-True ($activeHealth -eq 'ACTIVE') 'new child output refreshes health to ACTIVE'

    $silentHealth = Get-SpaHealthStatus -Now $started.AddMinutes(5) -StartedAt $started -LastOutputAt $started -ProcessAlive $true
    Assert-True ($silentHealth -eq 'SILENT') 'silent-but-alive child reports SILENT within the initial threshold'

    $longSilence = Get-SpaHealthStatus -Now $started.AddMinutes(20) -StartedAt $started -LastOutputAt $started -ProcessAlive $true
    Assert-True ($longSilence -eq 'LONG_SILENCE') 'silent-but-alive child reports LONG_SILENCE, not failure'

    $suspected = Get-SpaHealthStatus -Now $started.AddMinutes(31) -StartedAt $started -LastOutputAt $started -ProcessAlive $true
    Assert-True ($suspected -eq 'SUSPECTED_STALL') 'long simulated silence reports SUSPECTED_STALL'

    $firstPath = Write-SpaHealthRecord `
        -Task 'P2T4-REVIEW' `
        -Phase 'REVIEW' `
        -Model 'deepseek-v4-pro' `
        -Provider 'deepseek' `
        -StartedAt $started `
        -LastOutputAt $started `
        -ProcessId 4242 `
        -ProcessAlive $true `
        -LastSafe 'backend=abc frontend=def' `
        -HealthRoot $healthRoot `
        -Now $started.AddMinutes(5)
    $updatedPath = Write-SpaHealthRecord `
        -Task 'P2T4-REVIEW' `
        -Phase 'REVIEW' `
        -Model 'deepseek-v4-pro' `
        -Provider 'deepseek' `
        -StartedAt $started `
        -LastOutputAt $started.AddMinutes(6) `
        -ProcessId 4242 `
        -ProcessAlive $true `
        -LastSafe 'backend=abc frontend=def' `
        -HealthRoot $healthRoot `
        -Now $started.AddMinutes(7)
    $updatedRecord = Read-SpaHealthRecord -Path $updatedPath
    Assert-True ($firstPath -eq $updatedPath) 'heartbeat record is keyed by child process ID'
    Assert-True (([datetimeoffset]::Parse([string]$updatedRecord.updated_at) -gt $started.AddMinutes(5))) 'heartbeat record is updated over time'
    Assert-True ([string]$updatedRecord.health -eq 'ACTIVE') 'new fake child output refreshes last_output_at and health'

    $silenceRecord = Write-SpaHealthRecord `
        -Task 'P2T4-REVIEW' `
        -Phase 'REVIEW' `
        -Model 'deepseek-v4-pro' `
        -Provider 'deepseek' `
        -StartedAt $started `
        -LastOutputAt $started `
        -ProcessId 4243 `
        -ProcessAlive $true `
        -LastSafe 'backend=abc frontend=def' `
        -HealthRoot $healthRoot `
        -Now $started.AddMinutes(20)
    Assert-True (([string]$silenceRecord -eq (Join-Path $healthRoot 'spa-run-health-4243.json'))) 'silent health record is written locally'
    $silenceRead = Read-SpaHealthRecord -Path $silenceRecord
    Assert-True ([string]$silenceRead.health -eq 'LONG_SILENCE') 'silent-but-alive health record reports LONG_SILENCE'

    $stallRecord = Write-SpaHealthRecord `
        -Task 'P2T4-REVIEW' `
        -Phase 'REVIEW' `
        -Model 'deepseek-v4-pro' `
        -Provider 'deepseek' `
        -StartedAt $started `
        -LastOutputAt $started `
        -ProcessId 4244 `
        -ProcessAlive $true `
        -LastSafe 'backend=abc frontend=def' `
        -HealthRoot $healthRoot `
        -Now $started.AddMinutes(31)
    $stallRead = Read-SpaHealthRecord -Path $stallRecord
    Assert-True ([string]$stallRead.health -eq 'SUSPECTED_STALL') 'simulated stall reports SUSPECTED_STALL'
    Assert-True ([bool]$stallRead.process_alive) 'stall classification does not kill the child process'

    $trackedHealthRoot = Join-Path $tempRoot 'tracked-health'
    New-Item -ItemType Directory -Path $trackedHealthRoot -Force | Out-Null
    $fakeChild = Join-Path $tempRoot 'fake-child.ps1'
    @'
Write-Output "FIRST_OUTPUT"
Start-Sleep -Seconds 3
Write-Output "SECOND_OUTPUT"
'@ | Set-Content -LiteralPath $fakeChild -Encoding ASCII
    $tracked = Invoke-SpaTrackedProcess `
        -FilePath (Get-Command powershell.exe -CommandType Application).Source `
        -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $fakeChild) `
        -WorkingDirectory $tempRoot `
        -HealthRoot $trackedHealthRoot `
        -Task 'FAKE-CHILD' `
        -Phase 'REVIEW' `
        -Model 'deepseek-v4-pro' `
        -Provider 'deepseek' `
        -LastSafe 'backend=abc frontend=def' `
        -HeartbeatSeconds 1
    Assert-True ($tracked.Code -eq 0) 'tracked fake child exits successfully'
    Assert-True (($tracked.Output -match 'FIRST_OUTPUT') -and ($tracked.Output -match 'SECOND_OUTPUT')) 'tracked fake child output is captured'
    $trackedRecord = Get-SpaLatestHealthRecord -HealthRoot $trackedHealthRoot
    Assert-True ($null -ne $trackedRecord) 'tracked child creates a health record'
    Assert-True ([string]$trackedRecord.task -eq 'FAKE-CHILD') 'tracked child health record stores the task'
    Assert-True ([string]$trackedRecord.health -eq 'COMPLETE') 'tracked child exits with final COMPLETE health'
    Assert-True (-not [bool]$trackedRecord.process_alive) 'tracked child health record marks the process exited'

    $codexShimDir = Join-Path $tempRoot 'codex-shim'
    New-Item -ItemType Directory -Path $codexShimDir -Force | Out-Null
    $tokenMarker = Join-Path $tempRoot 'MODEL_WAS_CALLED.txt'
    @"
@echo off
echo called>"$tokenMarker"
exit /b 99
"@ | Set-Content -LiteralPath (Join-Path $codexShimDir 'codex.cmd') -Encoding ASCII

    $oldPath = $env:PATH
    $oldSecret = $env:DEEPSEEK_API_KEY
    $env:PATH = $codexShimDir + [System.IO.Path]::PathSeparator + $oldPath
    $env:DEEPSEEK_API_KEY = 'health-secret-never-print'
    try {
        $status = Invoke-SpaRun @('-Status', '-TestHealthPath', $healthRoot)
    }
    finally {
        $env:PATH = $oldPath
        $env:DEEPSEEK_API_KEY = $oldSecret
    }
    Assert-True ($status.Code -eq 0) '-Status exits successfully'
    Assert-Match $status.Output '(?m)^SPA STATUS\r?$' '-Status prints the SPA STATUS header'
    Assert-Match $status.Output 'TASK\s+P2T4-REVIEW' '-Status reports the current task'
    Assert-Match $status.Output 'PHASE\s+REVIEW' '-Status reports the current phase'
    Assert-Match $status.Output 'MODEL\s+deepseek-v4-pro' '-Status reports the current model'
    Assert-Match $status.Output 'PROVIDER\s+deepseek' '-Status reports the current provider'
    Assert-Match $status.Output 'HEALTH\s+(ACTIVE|LONG_SILENCE|SUSPECTED_STALL)' '-Status reports a valid live health state'
    Assert-Match $status.Output 'LAST SAFE\s+backend=abc frontend=def' '-Status reports the last safe checkpoint'
    Assert-True (-not (Test-Path -LiteralPath $tokenMarker)) '-Status consumes no model tokens'
    Assert-True ($status.Output.IndexOf('health-secret-never-print', [System.StringComparison]::Ordinal) -lt 0) '-Status prints no provider secrets'

    $oldPath2 = $env:PATH
    $env:PATH = $codexShimDir + [System.IO.Path]::PathSeparator + $oldPath2
    try {
        $noWorker = Invoke-SpaRun @('-Status', '-TestHealthPath', $emptyHealthRoot)
    }
    finally {
        $env:PATH = $oldPath2
    }
    Assert-True ($noWorker.Code -eq 0) 'no-worker status exits successfully'
    Assert-Match $noWorker.Output 'NO ACTIVE SPA WORKER' 'no health record produces a clean no-active-worker result'
    Assert-True (-not (Test-Path -LiteralPath $tokenMarker)) 'no-worker status consumes no model tokens'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ''
if ($failures.Count -eq 0) {
    Write-Host 'GREEN: all SPA health and status tests passed.'
    exit 0
}

Write-Host "RED: $($failures.Count) SPA health/status test(s) failed."
$failures | ForEach-Object { Write-Host " - $_" }
exit 1
