[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$devTools = Join-Path $repoRoot 'dev-tools'
$spaRun = Join-Path $devTools 'spa-run.ps1'
$stateTools = Join-Path $devTools 'm1-state.ps1'
$seedState = Join-Path $devTools 'state\m1-state.json'
$routingPath = Join-Path $devTools 'm1-model-routing.psd1'
$expectedBranch = 'feature/investment-operating-system-m1'
$failures = New-Object System.Collections.Generic.List[string]

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { Write-Host "PASS: $Message" }
    else { $script:failures.Add($Message); Write-Host "FAIL: $Message" }
}

function Assert-Match {
    param([string]$Text, [string]$Pattern, [string]$Message)
    Assert-True ([regex]::IsMatch($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) $Message
}

function Assert-FinalSessionSummary {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $sessionCount = @([regex]::Matches($Text, '(?m)^SPA SESSION SUMMARY\r?$')).Count
    $allSummaryCount = @([regex]::Matches($Text, '(?m)^SPA (?:TASK|SESSION) SUMMARY\r?$')).Count
    $summaryAtEnd = [regex]::IsMatch($Text, '(?ms)^={60}\r?\nSPA SESSION SUMMARY\r?\n={60}\r?\n.*^={60}\s*\z')
    Assert-True ($sessionCount -eq 1 -and $allSummaryCount -eq 1 -and $summaryAtEnd) $Message
}

function Invoke-SpaRun {
    param([string[]]$Arguments)
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $spaRun @Arguments 2>&1 | Out-String
    [pscustomobject]@{ Code = $LASTEXITCODE; Output = $output }
}

function Invoke-Git {
    param([string]$Path, [string[]]$Arguments)
    $output = & git -C $Path @Arguments 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "git failed in ${Path}: git $($Arguments -join ' ')`n$output" }
    $output.Trim()
}

function Initialize-RemotePair {
    param([string]$Root, [string]$Name)
    $remote = Join-Path $Root ($Name + '-remote.git')
    $office = Join-Path $Root ($Name + '-office')
    $homeRepo = Join-Path $Root ($Name + '-home')
    & git init --bare -q $remote
    if ($LASTEXITCODE -ne 0) { throw "git init --bare failed for $remote" }
    & git init -q $office
    if ($LASTEXITCODE -ne 0) { throw "git init failed for $office" }
    Invoke-Git $office @('config', 'user.email', 'spa-resume-test@example.com') | Out-Null
    Invoke-Git $office @('config', 'user.name', 'SPA Resume Test') | Out-Null
    Set-Content -LiteralPath (Join-Path $office 'README.md') -Value 'initial' -NoNewline
    Invoke-Git $office @('add', '-A') | Out-Null
    Invoke-Git $office @('commit', '-q', '-m', 'initial') | Out-Null
    Invoke-Git $office @('branch', '-M', $expectedBranch) | Out-Null
    Invoke-Git $office @('remote', 'add', 'origin', $remote) | Out-Null
    Invoke-Git $office @('push', '-q', '-u', 'origin', $expectedBranch) | Out-Null
    & git clone -q --branch $expectedBranch $remote $homeRepo
    if ($LASTEXITCODE -ne 0) { throw "git clone failed for $homeRepo" }
    Invoke-Git $homeRepo @('config', 'user.email', 'spa-resume-test@example.com') | Out-Null
    Invoke-Git $homeRepo @('config', 'user.name', 'SPA Resume Test') | Out-Null
    [pscustomobject]@{ Remote = $remote; Office = $office; Home = $homeRepo; Sha = (Invoke-Git $homeRepo @('rev-parse', 'HEAD')) }
}

function New-TestTask {
    param(
        [string]$Id,
        [string]$Status,
        [string]$BackendSha,
        [string]$FrontendSha,
        [bool]$ReviewRequired = $false,
        [string]$ReviewRoute = ''
    )
    [ordered]@{
        id = $Id
        action = 'IMPLEMENT'
        status = $Status
        implementationProvider = 'deepseek'
        implementationModel = 'deepseek-v4-flash'
        reviewerProvider = if ($ReviewRequired) { 'deepseek' } else { $null }
        reviewerModel = if ($ReviewRequired) { 'deepseek-v4-pro' } else { $null }
        reviewRoute = if ($ReviewRequired) { $ReviewRoute } else { $null }
        remediationRoute = $Id
        lastVerifiedBackendSha = $BackendSha
        lastVerifiedFrontendSha = $FrontendSha
        implementationCommitSha = $BackendSha
        remediationCommitSha = $null
        lastSuccessfulReviewVerdict = $null
        remediationAttempts = 0
        evidence = [ordered]@{
            implementationSucceeded = ($Status -eq 'COMPLETE' -or $Status -eq 'REVIEW_PENDING')
            testsSucceeded = ($Status -eq 'COMPLETE' -or $Status -eq 'REVIEW_PENDING')
            reviewRequired = $ReviewRequired
            reviewSucceeded = ($Status -eq 'COMPLETE')
            relevantCommitsPushed = ($Status -eq 'COMPLETE' -or $Status -eq 'REVIEW_PENDING')
        }
        updatedUtc = '2026-09-06T00:00:00Z'
    }
}

function New-TestState {
    param([object[]]$Tasks)
    [ordered]@{
        schemaVersion = 1
        milestone = 'M1'
        branch = $expectedBranch
        repositories = [ordered]@{
            backend = [ordered]@{ lastVerifiedSha = $null }
            frontend = [ordered]@{ lastVerifiedSha = $null }
        }
        tasks = $Tasks
    }
}

foreach ($required in @($stateTools, $seedState)) {
    Assert-True (Test-Path -LiteralPath $required -PathType Leaf) "required resumability artifact exists: $required"
}
if (-not (Test-Path -LiteralPath $stateTools -PathType Leaf)) {
    Write-Host ''
    Write-Host 'RED: resumability helper is not implemented yet.'
    exit 1
}

. $stateTools

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('spa-resume-test-' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $backend = Initialize-RemotePair -Root $tempRoot -Name 'backend'
    $frontend = Initialize-RemotePair -Root $tempRoot -Name 'frontend'

    $atomicPath = Join-Path $tempRoot 'state\atomic.json'
    $atomicState = New-TestState @((New-TestTask -Id 'P2T5' -Status 'PENDING' -BackendSha $null -FrontendSha $null))
    Write-M1StateAtomic -State $atomicState -Path $atomicPath
    $atomicRead = Read-M1State -Path $atomicPath
    Assert-True ($atomicRead.tasks[0].id -eq 'P2T5') 'state atomic write/read preserves task data'
    Assert-True (@(Get-ChildItem -LiteralPath (Split-Path -Parent $atomicPath) -Filter '*.tmp' -Force).Count -eq 0) 'atomic state write leaves no temporary file'

    $malformedPath = Join-Path $tempRoot 'malformed.json'
    Set-Content -LiteralPath $malformedPath -Value '{ definitely not json'
    $malformedFailed = $false
    try { Read-M1State -Path $malformedPath | Out-Null } catch { $malformedFailed = ($_.Exception.Message -match 'malformed') }
    Assert-True $malformedFailed 'malformed state fails closed'

    $advanceState = New-TestState @(
        (New-TestTask -Id 'P2T5' -Status 'COMPLETE' -BackendSha $backend.Sha -FrontendSha $frontend.Sha),
        (New-TestTask -Id 'P2T6' -Status 'PENDING' -BackendSha $null -FrontendSha $null)
    )
    $advance = Get-M1NextUnit -State $advanceState
    Assert-True ($advance.RouteId -eq 'P2T6') 'completed task advances to the next task'

    $runningState = New-TestState @((New-TestTask -Id 'P2T7' -Status 'RUNNING_LOCAL' -BackendSha $backend.Sha -FrontendSha $frontend.Sha))
    $running = Get-M1NextUnit -State $runningState
    Assert-True ($running.RouteId -eq 'P2T7' -and $running.IsRecovery) 'RUNNING_LOCAL resumes the same task from its checkpoint'

    $missingState = New-TestState @((New-TestTask -Id 'P2T5' -Status 'COMPLETE' -BackendSha ('f' * 40) -FrontendSha $frontend.Sha))
    $missingFailed = $false
    try { Test-M1RecordedShas -State $missingState -BackendPath $backend.Home -FrontendPath $frontend.Home -Branch $expectedBranch } catch { $missingFailed = ($_.Exception.Message -match 'missing|visible') }
    Assert-True $missingFailed 'recorded SHA missing fails closed'

    Set-Content -LiteralPath (Join-Path $backend.Home 'dirty.txt') -Value 'dirty' -NoNewline
    $dirtyFailed = $false
    try { Sync-M1Repository -Name 'Backend' -Path $backend.Home -ExpectedBranch $expectedBranch | Out-Null } catch { $dirtyFailed = ($_.Exception.Message -match 'dirty') }
    Assert-True $dirtyFailed 'dirty repository fails closed'
    Remove-Item -LiteralPath (Join-Path $backend.Home 'dirty.txt') -Force

    Invoke-Git $backend.Home @('checkout', '-q', '-b', 'wrong-branch') | Out-Null
    $branchFailed = $false
    try { Sync-M1Repository -Name 'Backend' -Path $backend.Home -ExpectedBranch $expectedBranch | Out-Null } catch { $branchFailed = ($_.Exception.Message -match 'branch') }
    Assert-True $branchFailed 'wrong branch fails closed'
    Invoke-Git $backend.Home @('checkout', '-q', $expectedBranch) | Out-Null

    Set-Content -LiteralPath (Join-Path $backend.Office 'remote.txt') -Value 'remote' -NoNewline
    Invoke-Git $backend.Office @('add', '-A') | Out-Null
    Invoke-Git $backend.Office @('commit', '-q', '-m', 'remote advance') | Out-Null
    Invoke-Git $backend.Office @('push', '-q', 'origin', $expectedBranch) | Out-Null
    $remoteSha = Invoke-Git $backend.Office @('rev-parse', 'HEAD')
    $syncResult = Sync-M1Repository -Name 'Backend' -Path $backend.Home -ExpectedBranch $expectedBranch
    Assert-True ($syncResult.FastForwarded -and (Invoke-Git $backend.Home @('rev-parse', 'HEAD')) -eq $remoteSha) 'clean behind repository permits ff-only recovery'

    Set-Content -LiteralPath (Join-Path $backend.Home 'home.txt') -Value 'home' -NoNewline
    Invoke-Git $backend.Home @('add', '-A') | Out-Null
    Invoke-Git $backend.Home @('commit', '-q', '-m', 'home divergence') | Out-Null
    Set-Content -LiteralPath (Join-Path $backend.Office 'office.txt') -Value 'office' -NoNewline
    Invoke-Git $backend.Office @('add', '-A') | Out-Null
    Invoke-Git $backend.Office @('commit', '-q', '-m', 'office divergence') | Out-Null
    Invoke-Git $backend.Office @('push', '-q', 'origin', $expectedBranch) | Out-Null
    $divergedFailed = $false
    try { Sync-M1Repository -Name 'Backend' -Path $backend.Home -ExpectedBranch $expectedBranch | Out-Null } catch { $divergedFailed = ($_.Exception.Message -match 'diverg') }
    Assert-True $divergedFailed 'divergence fails closed'

    $powerState = New-TestState @(
        (New-TestTask -Id 'P2T5' -Status 'COMPLETE' -BackendSha $remoteSha -FrontendSha $frontend.Sha),
        (New-TestTask -Id 'P2T6' -Status 'COMPLETE' -BackendSha $remoteSha -FrontendSha $frontend.Sha),
        (New-TestTask -Id 'P2T7' -Status 'RUNNING_LOCAL' -BackendSha $remoteSha -FrontendSha $frontend.Sha),
        (New-TestTask -Id 'P2T8' -Status 'PENDING' -BackendSha $null -FrontendSha $null)
    )
    $powerResume = Get-M1NextUnit -State $powerState
    Assert-True ($powerResume.RouteId -eq 'P2T7' -and $powerResume.IsRecovery) 'Office-to-Home power failure resumes P2T7 only'

    $now = [datetimeoffset]'2026-09-06T12:00:00+05:30'
    $maxDeadline = Get-M1Deadline -Now $now -MaxMinutes 10
    Assert-True (Test-M1ShouldSoftStop -Now $now -Deadline $maxDeadline -SafetyBufferMinutes 15) 'MaxMinutes inside safety buffer does not start the next unit'
    $untilDeadline = Get-M1Deadline -Now $now -Until '12:10'
    Assert-True (Test-M1ShouldSoftStop -Now $now -Deadline $untilDeadline -SafetyBufferMinutes 15) 'Until inside safety buffer does not start the next unit'

    $clock = [pscustomobject]@{ Now = $now }
    $executed = New-Object System.Collections.Generic.List[string]
    $checkpointed = New-Object System.Collections.Generic.List[string]
    $engineResult = Invoke-M1SequentialEngine -UnitIds @('P2T7', 'P2T8') -Deadline ($now.AddMinutes(20)) -SafetyBufferMinutes 15 `
        -NowProvider { $clock.Now } `
        -ExecuteUnit { param($unitId) $executed.Add($unitId); $clock.Now = $clock.Now.AddMinutes(25) } `
        -CheckpointUnit { param($unitId) $checkpointed.Add($unitId) }
    Assert-True (($executed -join ',') -eq 'P2T7' -and ($checkpointed -join ',') -eq 'P2T7' -and $engineResult.NextUnit -eq 'P2T8') 'current running unit is not hard-killed by a soft deadline'

    $reviewPending = New-TestState @(
        (New-TestTask -Id 'P2T4' -Status 'REVIEW_PENDING' -BackendSha $backend.Sha -FrontendSha $frontend.Sha -ReviewRequired $true -ReviewRoute 'P2T4-REVIEW'),
        (New-TestTask -Id 'P2T5' -Status 'PENDING' -BackendSha $null -FrontendSha $null)
    )
    $reviewPending.tasks[0].lastSuccessfulReviewVerdict = 'SAFE'
    $reviewNext = Get-M1NextUnit -State $reviewPending
    Assert-True ($reviewNext.RouteId -eq 'P2T4-REVIEW') 'P2T4 remains unresolved until review status and evidence are complete'

    $seed = Read-M1State -Path $seedState
    $seedNext = Get-M1NextUnit -State $seed
    Assert-True ($seedNext.RouteId -eq 'P2T4-REVIEW') 'seed state identifies P2T4-REVIEW as next unresolved gate'

    $runBackend = Initialize-RemotePair -Root $tempRoot -Name 'run-backend'
    $runFrontend = Initialize-RemotePair -Root $tempRoot -Name 'run-frontend'
    $runStatePath = Join-Path $tempRoot 'run-state.json'
    $runState = New-TestState @(
        (New-TestTask -Id 'P2T4' -Status 'REVIEW_PENDING' -BackendSha $runBackend.Sha -FrontendSha $runFrontend.Sha -ReviewRequired $true -ReviewRoute 'P2T4-REVIEW'),
        (New-TestTask -Id 'P2T5' -Status 'PENDING' -BackendSha $null -FrontendSha $null)
    )
    Write-M1StateAtomic -State $runState -Path $runStatePath

    $commonM1Args = @(
        '-Task', 'M1-REMAINING', '-DryRun', '-TestMode',
        '-StatePath', $runStatePath, '-RoutingPath', $routingPath,
        '-BackendPath', $runBackend.Home, '-FrontendPath', $runFrontend.Home,
        '-TestNow', '2026-09-06T12:00:00+05:30'
    )
    $maxStop = Invoke-SpaRun ($commonM1Args + @('-MaxMinutes', '10'))
    Assert-True ($maxStop.Code -eq 0) 'M1-REMAINING MaxMinutes soft stop succeeds'
    Assert-Match $maxStop.Output 'SOFT STOP\s+SAFETY BUFFER REACHED' 'MaxMinutes soft stop does not start the next unit'
    Assert-Match $maxStop.Output '(?ms)^COMPLETED\s+NONE\r?$.*^LAST SAFE\s+.*\r?$.*^NEXT\s+P2T4-REVIEW\r?$.*^REMOTE\s+SYNCED\r?$.*^STOP REASON\s+TIME WINDOW\r?$.*^RESUME\s+spa-run M1-REMAINING\r?$' 'MaxMinutes soft stop prints the required session recovery fields'
    Assert-FinalSessionSummary $maxStop.Output 'MaxMinutes soft stop prints exactly one session summary at the bottom'
    $untilStop = Invoke-SpaRun ($commonM1Args + @('-Until', '12:10'))
    Assert-True ($untilStop.Code -eq 0) 'M1-REMAINING Until soft stop succeeds'
    Assert-Match $untilStop.Output 'SOFT STOP\s+SAFETY BUFFER REACHED' 'Until soft stop does not start the next unit'
    $runBackendStatus = Invoke-Git $runBackend.Home @('status', '--porcelain=v1')
    $runFrontendStatus = Invoke-Git $runFrontend.Home @('status', '--porcelain=v1')
    $runBackendCounts = Invoke-Git $runBackend.Home @('rev-list', '--left-right', '--count', ('HEAD...origin/' + $expectedBranch))
    $runFrontendCounts = Invoke-Git $runFrontend.Home @('rev-list', '--left-right', '--count', ('HEAD...origin/' + $expectedBranch))
    Assert-True ([string]::IsNullOrWhiteSpace($runBackendStatus) -and [string]::IsNullOrWhiteSpace($runFrontendStatus) -and $runBackendCounts -match '^0\s+0$' -and $runFrontendCounts -match '^0\s+0$') 'simulated planned stop leaves both repositories clean and synchronized'

    $codexShimDir = Join-Path $tempRoot 'codex-shim'
    $tokenMarker = Join-Path $tempRoot 'MODEL_WAS_CALLED.txt'
    New-Item -ItemType Directory -Path $codexShimDir -Force | Out-Null
    @"
@echo off
echo called>"$tokenMarker"
exit /b 99
"@ | Set-Content -LiteralPath (Join-Path $codexShimDir 'codex.cmd') -Encoding ASCII
    $secretSentinel = 'resume-secret-never-print'
    $oldPath = $env:PATH
    $oldSecret = $env:DEEPSEEK_API_KEY
    $env:PATH = $codexShimDir + [System.IO.Path]::PathSeparator + $oldPath
    $env:DEEPSEEK_API_KEY = $secretSentinel
    try {
        $dryRun = Invoke-SpaRun @(
            '-Task', 'M1-REMAINING', '-DryRun', '-TestMode',
            '-StatePath', $runStatePath, '-RoutingPath', $routingPath,
            '-BackendPath', $runBackend.Home, '-FrontendPath', $runFrontend.Home
        )
    }
    finally {
        $env:PATH = $oldPath
        $env:DEEPSEEK_API_KEY = $oldSecret
    }
    Assert-True ($dryRun.Code -eq 0) 'M1-REMAINING dry-run succeeds on the verified current checkpoint'
    Assert-Match $dryRun.Output 'NEXT\s+P2T4-REVIEW' 'M1-REMAINING dry-run identifies P2T4-REVIEW'
    Assert-True (-not (Test-Path -LiteralPath $tokenMarker)) 'tests and dry-runs consume no model tokens'
    Assert-True ($dryRun.Output.IndexOf($secretSentinel, [System.StringComparison]::Ordinal) -lt 0) 'dry-run prints no secrets'
    Assert-Match $dryRun.Output '(?ms)^COMPLETED\s+NONE\r?$.*^NEXT\s+P2T4-REVIEW\r?$.*^REMOTE\s+SYNCED\r?$.*^STOP REASON\s+DRY RUN\r?$.*^RESUME\s+spa-run M1-REMAINING\r?$' 'M1-REMAINING dry-run prints the required session fields'
    Assert-FinalSessionSummary $dryRun.Output 'M1-REMAINING dry-run prints exactly one session summary at the bottom'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ''
if ($failures.Count -eq 0) {
    Write-Host 'GREEN: all SPA resumability tests passed.'
    exit 0
}

Write-Host "RED: $($failures.Count) SPA resumability test(s) failed."
$failures | ForEach-Object { Write-Host " - $_" }
exit 1
