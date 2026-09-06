[CmdletBinding()]
param(
    [string]$Task = '',
    [switch]$DryRun,
    [switch]$Status,
    [switch]$ApplyReview,
    [string]$ReviewVerdict = '',
    [switch]$TestMode,
    [string]$RoutingPath = '',
    [string]$BackendPath = '',
    [string]$FrontendPath = '',
    [string]$DependencyMarkerPath = '',
    [string]$TestModelCheckOutputPath = '',
    [string]$TestTaskOutputPath = '',
    [string]$StatePath = '',
    [string]$TestHealthPath = '',
    [Nullable[double]]$MaxMinutes,
    [string]$Until = '',
    [ValidateRange(0, 1440)]
    [int]$SafetyBufferMinutes = 15,
    [string]$TestNow = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:SpaMaxMinutesSpecified = $PSBoundParameters.ContainsKey('MaxMinutes')
$script:SpaTaskId = if ([string]::IsNullOrWhiteSpace($Task)) { '' } else { $Task.Trim().ToUpperInvariant() }
$script:SpaSummaryAction = 'NOT AVAILABLE'
$script:SpaSummaryModel = 'NOT AVAILABLE'
$script:SpaSummaryReasoning = 'NOT AVAILABLE'
$script:SpaLastSafe = 'NOT AVAILABLE'
$script:SpaRemoteStatus = 'NOT AVAILABLE'
$script:M1StateToolsPath = Join-Path $PSScriptRoot 'm1-state.ps1'
$script:M1StateToolsLoaded = $false
$script:M1PlanToolsPath = Join-Path $PSScriptRoot 'm1-plan-routing.ps1'
$script:M1PlanToolsLoaded = $false
$script:M1ToolingRoot = Split-Path -Parent $PSScriptRoot
$script:M1PlanRoot = Join-Path $script:M1ToolingRoot 'docs\superpowers\plans'
$script:M1PlanIndexPath = Join-Path $script:M1PlanRoot '2026-09-04-investment-operating-system-milestone-1-index.md'
$script:M1SpecPath = Join-Path $script:M1ToolingRoot 'docs\superpowers\specs\2026-09-04-investment-operating-system-milestone-1-design.md'
$script:M1PromptTemplatePath = Join-Path $PSScriptRoot 'prompts\m1-implementation.txt'
$script:DefaultM1BackendPath = 'C:\GitHub\backendtest'

# Keep all Git calls made by this process and its child scripts unattended.
$env:GIT_PAGER = 'cat'
$env:PAGER = 'cat'
$env:GIT_TERMINAL_PROMPT = '0'

if (-not (Test-Path -LiteralPath $script:M1StateToolsPath -PathType Leaf)) {
    throw "M1 state helper is missing: $script:M1StateToolsPath"
}
. $script:M1StateToolsPath
$script:M1StateToolsLoaded = $true

if (-not (Test-Path -LiteralPath $script:M1PlanToolsPath -PathType Leaf)) {
    throw "M1 plan-routing helper is missing: $script:M1PlanToolsPath"
}
. $script:M1PlanToolsPath
$script:M1PlanToolsLoaded = $true

if ([string]::IsNullOrWhiteSpace($RoutingPath)) {
    $RoutingPath = Join-Path $PSScriptRoot 'm1-model-routing.psd1'
}

function Write-SpaTaskSummary {
    param(
        [Parameter(Mandatory = $true)][string]$Result,
        [string]$Reason = '',
        [string]$Tests = 'NOT AVAILABLE',
        [string]$Commit = 'NOT AVAILABLE',
        [string]$Push = 'NOT AVAILABLE',
        [string]$Worktree = 'NOT AVAILABLE',
        [string]$Remote = '',
        [string]$Next = 'NOT AVAILABLE'
    )

    if ([string]::IsNullOrWhiteSpace($Remote)) { $Remote = $script:SpaRemoteStatus }
    $separator = '=' * 60
    Write-Output $separator
    Write-Output 'SPA TASK SUMMARY'
    Write-Output $separator
    Write-Output ('{0,-12}{1}' -f 'TASK', $script:SpaTaskId)
    if ($Result -eq 'STOPPED') {
        Write-Output ('{0,-12}{1}' -f 'RESULT', 'STOPPED')
        Write-Output ('{0,-12}{1}' -f 'REASON', (($Reason -replace '\r?\n', ' ').Trim()))
        Write-Output ('{0,-12}{1}' -f 'LAST SAFE', $script:SpaLastSafe)
        Write-Output ('{0,-12}{1}' -f 'REMOTE', $Remote)
        Write-Output ('{0,-12}{1}' -f 'NEXT', $Next)
    }
    else {
        Write-Output ('{0,-12}{1}' -f 'ACTION', $script:SpaSummaryAction)
        Write-Output ('{0,-12}{1}' -f 'RESULT', $Result)
        Write-Output ('{0,-12}{1}' -f 'MODEL', $script:SpaSummaryModel)
        Write-Output ('{0,-12}{1}' -f 'REASONING', $script:SpaSummaryReasoning)
        Write-Output ('{0,-12}{1}' -f 'TESTS', $Tests)
        Write-Output ('{0,-12}{1}' -f 'COMMIT', $Commit)
        Write-Output ('{0,-12}{1}' -f 'PUSH', $Push)
        Write-Output ('{0,-12}{1}' -f 'WORKTREE', $Worktree)
        Write-Output ('{0,-12}{1}' -f 'REMOTE', $Remote)
        Write-Output ('{0,-12}{1}' -f 'NEXT', $Next)
    }
    Write-Output $separator
}

function Write-SpaSessionSummary {
    param(
        [Parameter(Mandatory = $true)][string]$Completed,
        [Parameter(Mandatory = $true)][string]$LastSafe,
        [Parameter(Mandatory = $true)][string]$Next,
        [Parameter(Mandatory = $true)][string]$Remote,
        [Parameter(Mandatory = $true)][string]$StopReason,
        [Parameter(Mandatory = $true)][string]$Resume
    )

    $separator = '=' * 60
    Write-Output $separator
    Write-Output 'SPA SESSION SUMMARY'
    Write-Output $separator
    Write-Output ('{0,-12}{1}' -f 'COMPLETED', $Completed)
    Write-Output ('{0,-12}{1}' -f 'LAST SAFE', $LastSafe)
    Write-Output ('{0,-12}{1}' -f 'NEXT', $Next)
    Write-Output ('{0,-12}{1}' -f 'REMOTE', $Remote)
    Write-Output ('{0,-12}{1}' -f 'STOP REASON', $StopReason)
    Write-Output ('{0,-12}{1}' -f 'RESUME', $Resume)
    Write-Output $separator
}

function Stop-SpaRun {
    param([Parameter(Mandatory = $true)][string]$Message)

    Write-Output ('SPA-RUN FAIL: {0}' -f $Message)
    Write-SpaTaskSummary -Result 'STOPPED' -Reason $Message -Next ('Resolve failure and rerun spa-run {0}' -f $script:SpaTaskId)
    exit 1
}

function Import-M1StateTools {
    if ($script:M1StateToolsLoaded) { return }
    if (-not (Test-Path -LiteralPath $script:M1StateToolsPath -PathType Leaf)) {
        Stop-SpaRun "M1 state helper is missing: $script:M1StateToolsPath"
    }
    . $script:M1StateToolsPath
    $script:M1StateToolsLoaded = $true
}

function Get-RequiredValue {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Table,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Context
    )

    if (-not $Table.ContainsKey($Name) -or [string]::IsNullOrWhiteSpace([string]$Table[$Name])) {
        Stop-SpaRun "$Context is missing required routing value '$Name'."
    }
    return [string]$Table[$Name]
}

function Format-CommandArgument {
    param([Parameter(Mandatory = $true)][string]$Value)

    if ($Value -match "[\s']") {
        return "'" + $Value.Replace("'", "''") + "'"
    }
    return $Value
}

function Get-ReviewVerdict {
    param([Parameter(Mandatory = $true)][string]$Text)

    $matches = @([regex]::Matches($Text, '(?im)^\s*(SAFE WITH NON-BLOCKING OBSERVATIONS|SAFE|CHANGES REQUIRED)\s*$'))
    if ($matches.Count -ne 1) {
        Stop-SpaRun 'Review output did not contain exactly one recognized verdict. No result was accepted.'
    }

    $nonblankLines = @($Text -split '\r?\n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $verdict = $matches[0].Groups[1].Value.ToUpperInvariant()
    if ($nonblankLines.Count -eq 0 -or -not $nonblankLines[-1].Trim().Equals($verdict, [System.StringComparison]::OrdinalIgnoreCase)) {
        Stop-SpaRun 'The review verdict was not the final nonblank line. No result was accepted.'
    }
    return $verdict
}

function Get-M1ChildVerdict {
    param([Parameter(Mandatory = $true)][string]$Text)

    $matches = @([regex]::Matches($Text, '(?im)^VERDICT\s+(SAFE WITH NON-BLOCKING OBSERVATIONS|SAFE|CHANGES REQUIRED|IMPLEMENTED)\s*$'))
    if ($matches.Count -ne 1) {
        throw 'Completed child route did not report exactly one validated SPA TASK RESULT verdict.'
    }
    return $matches[0].Groups[1].Value.ToUpperInvariant()
}

function Get-M1TaskRecord {
    param([Parameter(Mandatory = $true)][object]$State, [Parameter(Mandatory = $true)][string]$TaskId)

    $matches = @($State.tasks | Where-Object { ([string]$_.id).Equals($TaskId, [System.StringComparison]::OrdinalIgnoreCase) })
    if ($matches.Count -ne 1) {
        throw "M1 state must contain exactly one task record for '$TaskId'."
    }
    return $matches[0]
}

function Set-M1Property {
    param([Parameter(Mandatory = $true)][object]$InputObject, [Parameter(Mandatory = $true)][string]$Name, $Value)

    if ($InputObject -is [System.Collections.IDictionary]) {
        $InputObject[$Name] = $Value
    }
    elseif ($null -ne $InputObject.PSObject.Properties[$Name]) {
        $InputObject.$Name = $Value
    }
    else {
        $InputObject | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Publish-M1StateCheckpoint {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][string]$StateFile,
        [Parameter(Mandatory = $true)][string]$ToolingRepository,
        [Parameter(Mandatory = $true)][string]$TaskId,
        [Parameter(Mandatory = $true)][string]$Status
    )

    $repositoryRoot = [System.IO.Path]::GetFullPath($ToolingRepository).TrimEnd('\', '/')
    $fullStatePath = [System.IO.Path]::GetFullPath($StateFile)
    if (-not $fullStatePath.StartsWith($repositoryRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'M1 state path must be inside the tooling repository before it can be checkpointed.'
    }
    $relativeStatePath = $fullStatePath.Substring($repositoryRoot.Length + 1).Replace('\', '/')

    Write-M1StateAtomic -State $State -Path $fullStatePath
    $changes = (Invoke-M1Git -Path $repositoryRoot -Arguments @('status', '--porcelain=v1', '--untracked-files=normal')).Output
    $changeLines = @($changes -split '\r?\n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $singleChangePath = $null
    if ($changeLines.Count -eq 1 -and $changeLines[0] -match '^[MARCU?]{1,2}\s+(.+)$') {
        $singleChangePath = $Matches[1].Replace('\', '/')
    }
    if ($changeLines.Count -ne 1 -or $singleChangePath -ne $relativeStatePath) {
        throw "Checkpoint refused because the tooling repository has changes other than '$relativeStatePath'."
    }

    Invoke-M1Git -Path $repositoryRoot -Arguments @('add', '--', $relativeStatePath) | Out-Null
    Invoke-M1Git -Path $repositoryRoot -Arguments @('commit', '-m', ("chore: checkpoint SPA M1 $TaskId $Status")) | Out-Null
    $push = Invoke-M1Git -Path $repositoryRoot -Arguments @('push', 'origin', ([string]$State.branch)) -AllowFailure
    if ($push.Code -ne 0) {
        throw "Checkpoint commit exists locally but push failed; '$TaskId' is not a durable cross-PC checkpoint."
    }
    $counts = (Invoke-M1Git -Path $repositoryRoot -Arguments @('rev-list', '--left-right', '--count', ('HEAD...refs/remotes/origin/' + [string]$State.branch))).Output
    if ($counts -notmatch '^0\s+0$') { throw 'Checkpoint push returned successfully but local/remote synchronization is not 0/0.' }
}

function Format-ProcessArgument {
    param([Parameter(Mandatory = $true)][string]$Value)

    if ($Value -notmatch "[\s`"]") { return $Value }
    return '"' + $Value.Replace('"', '\"') + '"'
}

function Read-SpaFileDelta {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][ref]$Offset
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
    try {
        $stream = [System.IO.File]::Open(
            $Path,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite
        )
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
        try {
            if ($Offset.Value -gt $stream.Length) { $Offset.Value = $stream.Length }
            $stream.Seek($Offset.Value, [System.IO.SeekOrigin]::Begin) | Out-Null
            $reader.DiscardBufferedData()
            $text = $reader.ReadToEnd()
            $Offset.Value = $stream.Position
            return $text
        }
        finally {
            $reader.Dispose()
            $stream.Dispose()
        }
    }
    catch {
        return ''
    }
}

function Invoke-SpaTrackedProcessLegacy {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$ArgumentList,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][string]$HealthRoot,
        [string]$Task = 'NOT AVAILABLE',
        [string]$Phase = 'NOT AVAILABLE',
        [string]$Model = 'NOT AVAILABLE',
        [string]$Provider = 'NOT AVAILABLE',
        [string]$LastSafe = 'NOT AVAILABLE',
        [int]$HeartbeatSeconds = 120
    )

    Import-M1StateTools
    $tempDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ('spa-run-track-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempDirectory -Force | Out-Null
    $stdoutPath = Join-Path $tempDirectory 'stdout.txt'
    $stderrPath = Join-Path $tempDirectory 'stderr.txt'
    $startedAt = [datetimeoffset]::UtcNow
    $lastOutputAt = $startedAt
    $stdoutOffset = 0
    $stderrOffset = 0
    $outputBuilder = New-Object System.Text.StringBuilder

    $quotedArguments = @($ArgumentList | ForEach-Object { Format-ProcessArgument -Value $_ })
    $process = Start-Process `
        -FilePath $FilePath `
        -ArgumentList $quotedArguments `
        -WorkingDirectory $WorkingDirectory `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -PassThru `
        -WindowStyle Hidden

    Write-SpaHealthRecord `
        -Task $Task `
        -Phase $Phase `
        -Model $Model `
        -Provider $Provider `
        -StartedAt $startedAt `
        -LastOutputAt $lastOutputAt `
        -ProcessId $process.Id `
        -ProcessAlive $true `
        -LastSafe $LastSafe `
        -HealthRoot $HealthRoot | Out-Null

    $nextHeartbeat = ([datetimeoffset]::UtcNow).AddSeconds($HeartbeatSeconds)
    try {
        while (-not $process.HasExited) {
            Start-Sleep -Seconds 2
            $process.Refresh()
            $now = [datetimeoffset]::UtcNow
            $receivedOutput = $false

            $stdoutDelta = Read-SpaFileDelta -Path $stdoutPath -Offset ([ref]$stdoutOffset)
            if (-not [string]::IsNullOrEmpty($stdoutDelta)) {
                [void]$outputBuilder.Append($stdoutDelta)
                $receivedOutput = $true
            }

            $stderrDelta = Read-SpaFileDelta -Path $stderrPath -Offset ([ref]$stderrOffset)
            if (-not [string]::IsNullOrEmpty($stderrDelta)) {
                [void]$outputBuilder.Append($stderrDelta)
                $receivedOutput = $true
            }

            if ($receivedOutput) {
                $lastOutputAt = $now
                Write-SpaHealthRecord `
                    -Task $Task `
                    -Phase $Phase `
                    -Model $Model `
                    -Provider $Provider `
                    -StartedAt $startedAt `
                    -LastOutputAt $lastOutputAt `
                    -ProcessId $process.Id `
                    -ProcessAlive $true `
                    -LastSafe $LastSafe `
                    -HealthRoot $HealthRoot `
                    -Now $now | Out-Null
                $nextHeartbeat = $now.AddSeconds($HeartbeatSeconds)
            }
            elseif ($now -ge $nextHeartbeat) {
                Write-SpaHealthRecord `
                    -Task $Task `
                    -Phase $Phase `
                    -Model $Model `
                    -Provider $Provider `
                    -StartedAt $startedAt `
                    -LastOutputAt $lastOutputAt `
                    -ProcessId $process.Id `
                    -ProcessAlive $true `
                    -LastSafe $LastSafe `
                    -HealthRoot $HealthRoot `
                    -Now $now | Out-Null
                $nextHeartbeat = $now.AddSeconds($HeartbeatSeconds)
            }
        }

        $process.WaitForExit()
        $process.Refresh()
        $stdoutDelta = Read-SpaFileDelta -Path $stdoutPath -Offset ([ref]$stdoutOffset)
        if (-not [string]::IsNullOrEmpty($stdoutDelta)) {
            [void]$outputBuilder.Append($stdoutDelta)
            $lastOutputAt = [datetimeoffset]::UtcNow
        }
        $stderrDelta = Read-SpaFileDelta -Path $stderrPath -Offset ([ref]$stderrOffset)
        if (-not [string]::IsNullOrEmpty($stderrDelta)) {
            [void]$outputBuilder.Append($stderrDelta)
            $lastOutputAt = [datetimeoffset]::UtcNow
        }

        $code = $process.ExitCode
        $finalHealth = if ($code -eq 0) { 'COMPLETE' } else { 'STOPPED' }
        Write-SpaHealthRecord `
            -Task $Task `
            -Phase $Phase `
            -Model $Model `
            -Provider $Provider `
            -StartedAt $startedAt `
            -LastOutputAt $lastOutputAt `
            -ProcessId $process.Id `
            -ProcessAlive $false `
            -LastSafe $LastSafe `
            -HealthRoot $HealthRoot `
            -FinalHealth $finalHealth `
            -Now ([datetimeoffset]::UtcNow) | Out-Null

        return [pscustomobject]@{
            Code = $code
            Output = $outputBuilder.ToString().TrimEnd()
            DisplayOutput = Remove-SpaFinalTaskSummary -Text ($outputBuilder.ToString().TrimEnd())
        }
    }
    finally {
        if (Test-Path -LiteralPath $tempDirectory) {
            Remove-Item -LiteralPath $tempDirectory -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-M1ChildRoute {
    param(
        [Parameter(Mandatory = $true)][string]$RouteId,
        [switch]$ChildDryRun,
        [string]$HealthRoot = $env:TEMP,
        [string]$HealthTask = 'NOT AVAILABLE',
        [string]$HealthPhase = 'NOT AVAILABLE',
        [string]$HealthModel = 'NOT AVAILABLE',
        [string]$HealthProvider = 'NOT AVAILABLE',
        [string]$HealthLastSafe = 'NOT AVAILABLE'
    )

    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-Task', $RouteId)
    if ($ChildDryRun) { $arguments += '-DryRun' }
    if ($TestMode) {
        $arguments += @('-TestMode', '-RoutingPath', $RoutingPath)
        if (-not [string]::IsNullOrWhiteSpace($BackendPath)) { $arguments += @('-BackendPath', $BackendPath) }
        if (-not [string]::IsNullOrWhiteSpace($FrontendPath)) { $arguments += @('-FrontendPath', $FrontendPath) }
        if (-not [string]::IsNullOrWhiteSpace($DependencyMarkerPath)) { $arguments += @('-DependencyMarkerPath', $DependencyMarkerPath) }
        if (-not [string]::IsNullOrWhiteSpace($TestModelCheckOutputPath)) { $arguments += @('-TestModelCheckOutputPath', $TestModelCheckOutputPath) }
        if (-not [string]::IsNullOrWhiteSpace($TestTaskOutputPath)) { $arguments += @('-TestTaskOutputPath', $TestTaskOutputPath) }
    }
    if ($ChildDryRun) {
        $output = & powershell.exe @arguments 2>&1 | Out-String
        $trimmedOutput = $output.TrimEnd()
        return [pscustomobject]@{
            Code = $LASTEXITCODE
            Output = $trimmedOutput
            DisplayOutput = Remove-SpaFinalTaskSummary -Text $trimmedOutput
        }
    }

    $powershellPath = (Get-Command powershell.exe -CommandType Application).Source
    return Invoke-SpaTrackedProcess `
        -FilePath $powershellPath `
        -ArgumentList $arguments `
        -WorkingDirectory $PSScriptRoot `
        -HealthRoot $HealthRoot `
        -Task $HealthTask `
        -Phase $HealthPhase `
        -Model $HealthModel `
        -Provider $HealthProvider `
        -LastSafe $HealthLastSafe
}

function Invoke-M1Remaining {
    Import-M1StateTools

    if ([string]::IsNullOrWhiteSpace($StatePath)) {
        $script:StatePath = Join-Path $PSScriptRoot 'state\m1-state.json'
    }
    $toolingPath = if ([string]::IsNullOrWhiteSpace($FrontendPath)) { Split-Path -Parent $PSScriptRoot } else { $FrontendPath }
    $backendRepositoryPath = if ([string]::IsNullOrWhiteSpace($BackendPath)) { 'C:\GitHub\backendtest' } else { $BackendPath }

    try {
        $state = Read-M1State -Path $StatePath
        $requiredBranch = 'feature/investment-operating-system-m1'
        if (-not ([string]$state.branch).Equals($requiredBranch, [System.StringComparison]::Ordinal)) {
            throw "M1 state branch '$($state.branch)' does not match required branch '$requiredBranch'."
        }

        $now = if ([string]::IsNullOrWhiteSpace($TestNow)) { [datetimeoffset]::Now } else { [datetimeoffset]::Parse($TestNow, [System.Globalization.CultureInfo]::InvariantCulture) }
        if ($script:SpaMaxMinutesSpecified) {
            $deadline = Get-M1Deadline -Now $now -MaxMinutes $MaxMinutes
        }
        elseif (-not [string]::IsNullOrWhiteSpace($Until)) {
            $deadline = Get-M1Deadline -Now $now -Until $Until
        }
        else {
            $deadline = $null
        }

        # Validate both local repositories before either one is fetched or fast-forwarded.
        Test-M1RepositoryLocalState -Name 'Backend' -Path $backendRepositoryPath -ExpectedBranch $requiredBranch | Out-Null
        Test-M1RepositoryLocalState -Name 'Frontend' -Path $toolingPath -ExpectedBranch $requiredBranch | Out-Null
        $backendSync = Sync-M1Repository -Name 'Backend' -Path $backendRepositoryPath -ExpectedBranch $requiredBranch
        $frontendSync = Sync-M1Repository -Name 'Frontend' -Path $toolingPath -ExpectedBranch $requiredBranch
        Test-M1RecordedShas -State $state -BackendPath $backendRepositoryPath -FrontendPath $toolingPath -Branch $requiredBranch | Out-Null
        $script:SpaLastSafe = 'backend={0} frontend={1}' -f $backendSync.Head, $frontendSync.Head
        $script:SpaRemoteStatus = 'SYNCED'
        $completedThisSession = New-Object System.Collections.Generic.List[string]

        Write-Output 'SPA M1 ORCHESTRATOR'
        Write-Output ('MODE       M1-REMAINING')
        Write-Output ('BRANCH     {0}' -f $requiredBranch)
        Write-Output ('BACKEND    SYNCED {0}' -f $backendSync.Head)
        Write-Output ('FRONTEND   SYNCED {0}' -f $frontendSync.Head)

        while ($true) {
            $unit = Get-M1NextUnit -State $state
            if ($null -eq $unit) {
                Write-Output 'STATUS     ALL MACHINE-VERIFIED UNITS COMPLETE'
                Write-Output 'HUMAN GATE REQUIRED before M1 release.'
                $completed = if ($completedThisSession.Count -eq 0) { 'NONE' } else { $completedThisSession -join ', ' }
                Write-SpaSessionSummary -Completed $completed -LastSafe $script:SpaLastSafe -Next 'HUMAN GATE' -Remote 'SYNCED' -StopReason 'HUMAN GATE' -Resume 'HUMAN APPROVAL REQUIRED'
                return
            }
            Write-Output ('NEXT       {0}' -f $unit.RouteId)
            Write-Output ('TASK       {0}' -f $unit.TaskId)
            Write-Output ('STATE      {0}' -f $unit.Status)
            if ($unit.IsRecovery) { Write-Output 'RECOVERY   RESTART FROM LAST VERIFIED GIT CHECKPOINT' }

            $checkNow = if ([string]::IsNullOrWhiteSpace($TestNow)) { [datetimeoffset]::Now } else { [datetimeoffset]::Parse($TestNow, [System.Globalization.CultureInfo]::InvariantCulture) }
            if (Test-M1ShouldSoftStop -Now $checkNow -Deadline $deadline -SafetyBufferMinutes $SafetyBufferMinutes) {
                Write-Output 'SOFT STOP  SAFETY BUFFER REACHED'
                Write-Output ('CHECKPOINT backend={0} frontend={1}' -f $backendSync.Head, $frontendSync.Head)
                Write-Output ('RESUME     spa-run M1-REMAINING')
                $completed = if ($completedThisSession.Count -eq 0) { 'NONE' } else { $completedThisSession -join ', ' }
                Write-SpaSessionSummary -Completed $completed -LastSafe $script:SpaLastSafe -Next $unit.RouteId -Remote 'SYNCED' -StopReason 'TIME WINDOW' -Resume 'spa-run M1-REMAINING'
                return
            }

            if ($DryRun) {
                $preview = Invoke-M1ChildRoute -RouteId $unit.RouteId -ChildDryRun
                if ($preview.DisplayOutput) { Write-Output $preview.DisplayOutput }
                if ($preview.Code -ne 0) { throw "Dry-run route resolution failed for '$($unit.RouteId)'." }
                Write-Output 'TOKENS     NONE (DRY RUN)'
                Write-SpaSessionSummary -Completed 'NONE' -LastSafe $script:SpaLastSafe -Next $unit.RouteId -Remote 'SYNCED' -StopReason 'DRY RUN' -Resume 'spa-run M1-REMAINING'
                return
            }

            $taskRecord = Get-M1TaskRecord -State $state -TaskId $unit.TaskId
            if (([string]$taskRecord.action).Equals('HUMAN_GATE', [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Final M1 release human gate reached at '$($unit.TaskId)'."
            }
            if ($unit.Stage -eq 'REMEDIATE' -and [int]$taskRecord.remediationAttempts -ge 2) {
                throw "Repeated remediation failure after 2 attempts for '$($unit.TaskId)'."
            }

            Set-M1Property -InputObject $taskRecord -Name 'status' -Value 'RUNNING_LOCAL'
            Set-M1Property -InputObject $taskRecord -Name 'activeRoute' -Value $unit.RouteId
            Set-M1Property -InputObject $taskRecord -Name 'updatedUtc' -Value ([datetimeoffset]::UtcNow.ToString('o'))
            Publish-M1StateCheckpoint -State $state -StateFile $StatePath -ToolingRepository $toolingPath -TaskId $unit.TaskId -Status 'RUNNING_LOCAL'

            $healthRoot = if ([string]::IsNullOrWhiteSpace($TestHealthPath)) { $env:TEMP } else { $TestHealthPath }
            $healthModel = if ($unit.Stage -eq 'REVIEW') { [string]$taskRecord.reviewerModel } else { [string]$taskRecord.implementationModel }
            $healthProvider = if ($unit.Stage -eq 'REVIEW') { [string]$taskRecord.reviewerProvider } else { [string]$taskRecord.implementationProvider }
            $result = Invoke-M1ChildRoute `
                -RouteId $unit.RouteId `
                -HealthRoot $healthRoot `
                -HealthTask $unit.TaskId `
                -HealthPhase $unit.Stage `
                -HealthModel $healthModel `
                -HealthProvider $healthProvider `
                -HealthLastSafe $script:SpaLastSafe
            if ($result.DisplayOutput) { Write-Output $result.DisplayOutput }
            if ($result.Code -ne 0) { throw "Unit '$($unit.RouteId)' failed; RUNNING_LOCAL remains the durable non-complete state." }
            $verdict = Get-M1ChildVerdict -Text $result.Output

            $backendSync = Sync-M1Repository -Name 'Backend' -Path $backendRepositoryPath -ExpectedBranch $requiredBranch
            $frontendSync = Sync-M1Repository -Name 'Frontend' -Path $toolingPath -ExpectedBranch $requiredBranch
            $hardStopAfterCheckpoint = $false
            if ($unit.Stage -eq 'REVIEW' -or ([string]$taskRecord.action).Equals('REVIEW', [System.StringComparison]::OrdinalIgnoreCase)) {
                Complete-M1ReviewTransition `
                    -State $state `
                    -TaskId $unit.TaskId `
                    -ReviewRoute $unit.RouteId `
                    -Verdict $verdict `
                    -ReviewerProvider ([string]$taskRecord.reviewerProvider) `
                    -ReviewerModel ([string]$taskRecord.reviewerModel) `
                    -BackendHead $backendSync.Head `
                    -FrontendHead $frontendSync.Head `
                    -ReviewedCommitSha ([string]$taskRecord.remediationCommitSha) | Out-Null
                if (([string]$taskRecord.status).Equals('REMEDIATION_REQUIRED', [System.StringComparison]::OrdinalIgnoreCase) -and
                    [int]$taskRecord.remediationAttempts -ge 2) {
                    $hardStopAfterCheckpoint = $true
                }
            }
            else {
                Set-M1Property -InputObject $taskRecord.evidence -Name 'implementationSucceeded' -Value $true
                Set-M1Property -InputObject $taskRecord.evidence -Name 'testsSucceeded' -Value $true
                Set-M1Property -InputObject $taskRecord.evidence -Name 'relevantCommitsPushed' -Value $true
                if ($unit.Stage -eq 'REMEDIATE') {
                    Set-M1Property -InputObject $taskRecord -Name 'remediationCommitSha' -Value $backendSync.Head
                    Set-M1Property -InputObject $taskRecord -Name 'remediationAttempts' -Value ([int]$taskRecord.remediationAttempts + 1)
                }
                else {
                    Set-M1Property -InputObject $taskRecord -Name 'implementationCommitSha' -Value $backendSync.Head
                }
                Set-M1Property -InputObject $taskRecord -Name 'lastVerifiedBackendSha' -Value $backendSync.Head
                Set-M1Property -InputObject $taskRecord -Name 'activeRoute' -Value $null
                $nextStatus = if ([bool]$taskRecord.evidence.reviewRequired) { 'REVIEW_PENDING' } else { 'COMPLETE' }
                Set-M1Property -InputObject $taskRecord -Name 'status' -Value $nextStatus
            }
            Set-M1Property -InputObject $taskRecord -Name 'updatedUtc' -Value ([datetimeoffset]::UtcNow.ToString('o'))
            Set-M1Property -InputObject $state.repositories.backend -Name 'lastVerifiedSha' -Value $backendSync.Head
            Set-M1Property -InputObject $state.repositories.frontend -Name 'lastVerifiedSha' -Value $frontendSync.Head
            Publish-M1StateCheckpoint -State $state -StateFile $StatePath -ToolingRepository $toolingPath -TaskId $unit.TaskId -Status ([string]$taskRecord.status)
            Write-Output ('CHECKPOINT {0} {1} PUSHED' -f $unit.TaskId, $taskRecord.status)
            $completedThisSession.Add($unit.RouteId)
            $script:SpaLastSafe = '{0} {1}' -f $unit.TaskId, $taskRecord.status
            if ($hardStopAfterCheckpoint) {
                throw "Repeated remediation failure after 2 attempts for '$($unit.TaskId)'."
            }
        }
    }
    catch {
        Stop-SpaRun $_.Exception.Message
    }
}

function Invoke-SpaStatus {
    Import-M1StateTools

    $healthRoot = if ([string]::IsNullOrWhiteSpace($TestHealthPath)) { $env:TEMP } else { $TestHealthPath }
    $record = Get-SpaLatestHealthRecord -HealthRoot $healthRoot
    if ($null -eq $record) {
        Write-Output 'NO ACTIVE SPA WORKER'
        return
    }

    $task = if ([string]::IsNullOrWhiteSpace([string]$record.task)) { 'NOT AVAILABLE' } else { [string]$record.task }
    $phase = if ([string]::IsNullOrWhiteSpace([string]$record.phase)) { 'NOT AVAILABLE' } else { [string]$record.phase }
    $model = if ([string]::IsNullOrWhiteSpace([string]$record.model)) { 'NOT AVAILABLE' } else { [string]$record.model }
    $provider = if ([string]::IsNullOrWhiteSpace([string]$record.provider)) { 'NOT AVAILABLE' } else { [string]$record.provider }
    $started = if ([string]::IsNullOrWhiteSpace([string]$record.started_at)) { 'NOT AVAILABLE' } else { [string]$record.started_at }
    $elapsed = if ($null -ne $record.elapsed) { Format-SpaDuration -TotalSeconds ([double]$record.elapsed) } else { 'NOT AVAILABLE' }
    $lastOutput = if ([string]::IsNullOrWhiteSpace([string]$record.last_output_at)) { 'NOT AVAILABLE' } else { [string]$record.last_output_at }
    $process = if ($null -ne $record.process_id) { [string]$record.process_id } else { 'NOT AVAILABLE' }
    $process = $process + ' ' + $(if ([bool]$record.process_alive) { 'ALIVE' } else { 'EXITED' })
    $health = if ([string]::IsNullOrWhiteSpace([string]$record.health)) { 'NOT AVAILABLE' } else { [string]$record.health }
    $lastSafe = if ([string]::IsNullOrWhiteSpace([string]$record.last_safe)) { 'NOT AVAILABLE' } else { [string]$record.last_safe }
    $updated = if ([string]::IsNullOrWhiteSpace([string]$record.updated_at)) { 'NOT AVAILABLE' } else { [string]$record.updated_at }

    Write-Output 'SPA STATUS'
    Write-Output ('TASK       {0}' -f $task)
    Write-Output ('PHASE      {0}' -f $phase)
    Write-Output ('MODEL      {0}' -f $model)
    Write-Output ('PROVIDER   {0}' -f $provider)
    Write-Output ('STARTED    {0}' -f $started)
    Write-Output ('ELAPSED    {0}' -f $elapsed)
    Write-Output ('LAST OUTPUT {0}' -f $lastOutput)
    Write-Output ('PROCESS    {0}' -f $process)
    Write-Output ('HEALTH     {0}' -f $health)
    Write-Output ('LAST SAFE  {0}' -f $lastSafe)
    Write-Output ('UPDATED    {0}' -f $updated)
}

function Invoke-M1ReviewApplication {
    param([Parameter(Mandatory = $true)][string]$Verdict)

    Import-M1StateTools
    $statePath = if ([string]::IsNullOrWhiteSpace($StatePath)) {
        Join-Path $PSScriptRoot 'state\m1-state.json'
    }
    else {
        $StatePath
    }
    $toolingPath = if ([string]::IsNullOrWhiteSpace($FrontendPath)) { Split-Path -Parent $PSScriptRoot } else { $FrontendPath }
    $backendRepositoryPath = if ([string]::IsNullOrWhiteSpace($BackendPath)) { 'C:\GitHub\backendtest' } else { $BackendPath }
    $requiredBranch = 'feature/investment-operating-system-m1'

    try {
        $state = Read-M1State -Path $statePath
        if (-not ([string]$state.branch).Equals($requiredBranch, [System.StringComparison]::Ordinal)) {
            throw "M1 state branch '$($state.branch)' does not match required branch '$requiredBranch'."
        }

        Test-M1RepositoryLocalState -Name 'Backend' -Path $backendRepositoryPath -ExpectedBranch $requiredBranch | Out-Null
        Test-M1RepositoryLocalState -Name 'Frontend' -Path $toolingPath -ExpectedBranch $requiredBranch | Out-Null
        $backendSync = Sync-M1Repository -Name 'Backend' -Path $backendRepositoryPath -ExpectedBranch $requiredBranch
        $frontendSync = Sync-M1Repository -Name 'Frontend' -Path $toolingPath -ExpectedBranch $requiredBranch
        Test-M1RecordedShas -State $state -BackendPath $backendRepositoryPath -FrontendPath $toolingPath -Branch $requiredBranch | Out-Null

        $taskRecord = Get-M1TaskRecord -State $state -TaskId $script:SpaTaskId
        Complete-M1ReviewTransition `
            -State $state `
            -TaskId $script:SpaTaskId `
            -ReviewRoute ([string]$taskRecord.reviewRoute) `
            -Verdict $Verdict `
            -ReviewerProvider ([string]$taskRecord.reviewerProvider) `
            -ReviewerModel ([string]$taskRecord.reviewerModel) `
            -BackendHead $backendSync.Head `
            -FrontendHead $frontendSync.Head `
            -ReviewedCommitSha ([string]$taskRecord.remediationCommitSha) | Out-Null

        Publish-M1StateCheckpoint `
            -State $state `
            -StateFile $statePath `
            -ToolingRepository $toolingPath `
            -TaskId $script:SpaTaskId `
            -Status ([string]$taskRecord.status)

        $next = Get-M1NextUnit -State $state
        $nextLabel = if ($null -eq $next) { 'NONE' } else { $next.RouteId }
        Write-Output 'SPA REVIEW APPLIED'
        Write-Output ('TASK       {0}' -f $script:SpaTaskId)
        Write-Output ('ROUTE      {0}' -f ([string]$taskRecord.reviewRoute))
        Write-Output ('VERDICT    {0}' -f ([string]$taskRecord.lastSuccessfulReviewVerdict))
        Write-Output ('STATE      {0}' -f ([string]$taskRecord.status))
        Write-Output ('CHECKPOINT {0} {1} PUSHED' -f $script:SpaTaskId, $taskRecord.status)
        Write-Output ('NEXT       {0}' -f $nextLabel)
        Write-Output 'TOKENS     NONE'
    }
    catch {
        Stop-SpaRun $_.Exception.Message
    }
}

$testOnlyOverrides = @('RoutingPath', 'BackendPath', 'FrontendPath', 'DependencyMarkerPath', 'TestModelCheckOutputPath', 'TestTaskOutputPath', 'StatePath', 'TestNow', 'TestHealthPath')
$usedTestOnlyOverrides = @($testOnlyOverrides | Where-Object { $PSBoundParameters.ContainsKey($_) })

$taskId = $script:SpaTaskId
if ($Status) {
    Invoke-SpaStatus
    exit 0
}
if ($ApplyReview) {
    if ([string]::IsNullOrWhiteSpace($taskId) -or $taskId -eq 'M1-REMAINING') {
        Stop-SpaRun '-ApplyReview requires a known M1 task ID other than M1-REMAINING.'
    }
    if ($DryRun) {
        Stop-SpaRun '-ApplyReview persists a reviewed state transition and cannot be combined with -DryRun.'
    }
    if ([string]::IsNullOrWhiteSpace($ReviewVerdict)) {
        Stop-SpaRun '-ApplyReview requires -ReviewVerdict.'
    }
    Invoke-M1ReviewApplication -Verdict $ReviewVerdict
    exit 0
}
if ($TestMode -and -not $DryRun) {
    Stop-SpaRun '-TestMode requires -DryRun and can never invoke a task.'
}
if (-not $TestMode -and $usedTestOnlyOverrides.Count -gt 0) {
    Stop-SpaRun 'Test-only overrides require both -TestMode and -DryRun.'
}

if ($taskId -eq 'M1-REMAINING') {
    Invoke-M1Remaining
    exit 0
}
if ($PSBoundParameters.ContainsKey('MaxMinutes') -or -not [string]::IsNullOrWhiteSpace($Until) -or $PSBoundParameters.ContainsKey('SafetyBufferMinutes')) {
    Stop-SpaRun '-MaxMinutes, -Until, and -SafetyBufferMinutes are available only with M1-REMAINING.'
}

if (-not (Test-Path -LiteralPath $RoutingPath -PathType Leaf)) {
    Stop-SpaRun "Routing file is missing: $RoutingPath"
}

try {
    $routing = Import-PowerShellDataFile -LiteralPath $RoutingPath
}
catch {
    Stop-SpaRun "Routing file could not be loaded: $($_.Exception.Message)"
}

if (-not $routing.ContainsKey('Routes') -or -not $routing.Routes.ContainsKey($taskId)) {
    Stop-SpaRun "Unknown SPA task ID: $taskId"
}

$route = $routing.Routes[$taskId]
$action = Get-RequiredValue -Table $route -Name 'Action' -Context $taskId
$script:SpaSummaryAction = $action.ToUpperInvariant()
$modelRouteName = if ($route.ContainsKey('ModelRoute')) { [string]$route.ModelRoute } else { $taskId }
if ($route.ContainsKey('ModelRoute')) {
    if (-not $routing.ContainsKey('ModelRoutes') -or -not $routing.ModelRoutes.ContainsKey($modelRouteName)) {
        Stop-SpaRun "$taskId refers to unknown model route '$modelRouteName'."
    }
    $modelRoute = $routing.ModelRoutes[$modelRouteName]
}
else {
    $modelRoute = $route
}
$provider = Get-RequiredValue -Table $modelRoute -Name 'Provider' -Context $modelRouteName
$model = Get-RequiredValue -Table $modelRoute -Name 'Model' -Context $modelRouteName
$reasoning = Get-RequiredValue -Table $modelRoute -Name 'Reasoning' -Context $modelRouteName
$script:SpaSummaryModel = $model
$script:SpaSummaryReasoning = $reasoning
$commandName = Get-RequiredValue -Table $modelRoute -Name 'Command' -Context $modelRouteName
$profile = if ($modelRoute.ContainsKey('Profile')) { [string]$modelRoute.Profile } else { '' }

$isGenericImplementation = (
    $action.Equals('IMPLEMENT', [System.StringComparison]::OrdinalIgnoreCase) -and
    -not $route.ContainsKey('Prompt')
)
$genericImplementationRoute = $null
$repository = ''
$repositoryPath = ''
$expectedBranch = ''
$sandbox = ''
$promptPath = ''

if ($isGenericImplementation) {
    $repository = 'Backend'
    $repositoryPath = if ([string]::IsNullOrWhiteSpace($BackendPath)) { $script:DefaultM1BackendPath } else { $BackendPath }
    $expectedBranch = 'feature/investment-operating-system-m1'
    $sandbox = 'workspace-write'
    $genericImplementationRoute = Get-M1ImplementationRoute `
        -TaskId $taskId `
        -PlanIndexPath $script:M1PlanIndexPath `
        -PlanRoot $script:M1PlanRoot `
        -SpecPath $script:M1SpecPath `
        -RepositoryPath $repositoryPath `
        -Repository $repository `
        -Branch $expectedBranch `
        -Sandbox $sandbox `
        -PromptPath $script:M1PromptTemplatePath
    $promptPath = [string]$genericImplementationRoute.PromptPath
    if (-not (Test-Path -LiteralPath $promptPath -PathType Leaf)) {
        Stop-SpaRun "Generic M1 implementation prompt template is missing: $promptPath"
    }
}
else {
    if (-not $route.ContainsKey('Enabled') -or -not [bool]$route.Enabled) {
        $reason = if ($route.ContainsKey('DisabledReason')) { [string]$route.DisabledReason } else { 'Repository, prompt, and execution metadata are not enabled in Phase 1.' }
        Stop-SpaRun "$taskId is recorded but not yet enabled. $reason"
    }

    if ($route.ContainsKey('IndependentReview') -and [bool]$route.IndependentReview) {
        if (-not $route.ContainsKey('Implementer') -or
            -not $route.Implementer.ContainsKey('Provider') -or
            -not $route.Implementer.ContainsKey('Model') -or
            [string]::IsNullOrWhiteSpace([string]$route.Implementer.Provider) -or
            [string]::IsNullOrWhiteSpace([string]$route.Implementer.Model)) {
            Stop-SpaRun "$taskId requires implementer metadata before an independent review can run."
        }

        $sameProvider = $provider.Equals([string]$route.Implementer.Provider, [System.StringComparison]::OrdinalIgnoreCase)
        $sameModel = $model.Equals([string]$route.Implementer.Model, [System.StringComparison]::OrdinalIgnoreCase)
        if ($sameProvider -and $sameModel) {
            Stop-SpaRun "$taskId has an independent review conflict: implementer and reviewer both resolve to $provider/$model."
        }
    }

    $repository = Get-RequiredValue -Table $route -Name 'Repository' -Context $taskId
    $repositoryPath = Get-RequiredValue -Table $route -Name 'RepositoryPath' -Context $taskId
    $expectedBranch = Get-RequiredValue -Table $route -Name 'Branch' -Context $taskId
    $sandbox = Get-RequiredValue -Table $route -Name 'Sandbox' -Context $taskId
    $promptRelativePath = Get-RequiredValue -Table $route -Name 'Prompt' -Context $taskId

    if ($repository.Equals('Backend', [System.StringComparison]::OrdinalIgnoreCase) -and -not [string]::IsNullOrWhiteSpace($BackendPath)) {
        $repositoryPath = $BackendPath
    }
    elseif ($repository.Equals('Frontend', [System.StringComparison]::OrdinalIgnoreCase) -and -not [string]::IsNullOrWhiteSpace($FrontendPath)) {
        $repositoryPath = $FrontendPath
    }

    $routingRoot = Split-Path -Parent ([System.IO.Path]::GetFullPath($RoutingPath))
    $promptPath = if ([System.IO.Path]::IsPathRooted($promptRelativePath)) {
        $promptRelativePath
    }
    else {
        Join-Path $routingRoot $promptRelativePath
    }
    if (-not (Test-Path -LiteralPath $promptPath -PathType Leaf)) {
        Stop-SpaRun "Prompt file is missing: $promptPath"
    }
}

$command = $null
if ($commandName.Equals('codex', [System.StringComparison]::OrdinalIgnoreCase)) {
    foreach ($candidate in @('codex.cmd', 'codex.exe')) {
        $command = @(Get-Command $candidate -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($command) { break }
    }
}
if (-not $command) {
    $command = @(Get-Command $commandName -ErrorAction SilentlyContinue | Select-Object -First 1)
}
if (-not $command) {
    Stop-SpaRun "Required CLI '$commandName' was not found."
}
$commandPath = $command[0].Source

$codexArgs = New-Object System.Collections.Generic.List[string]
if (-not [string]::IsNullOrWhiteSpace($profile)) {
    $codexArgs.Add('--profile')
    $codexArgs.Add($profile)
}
$codexArgs.Add('--model')
$codexArgs.Add($model)
$codexArgs.Add('-c')
$codexArgs.Add(('model_provider="{0}"' -f $provider))
$codexArgs.Add('-c')
$codexArgs.Add(('model_reasoning_effort="{0}"' -f $reasoning))
$codexArgs.Add('--ask-for-approval')
$codexArgs.Add('never')
$codexArgs.Add('--sandbox')
$codexArgs.Add($sandbox)
$codexArgs.Add('-C')
$codexArgs.Add($repositoryPath)
$codexArgs.Add('exec')
$codexArgs.Add('--ephemeral')
$codexArgs.Add('--color')
$codexArgs.Add('never')

$displayArgs = @($codexArgs | ForEach-Object { Format-CommandArgument -Value $_ })
$displayCommand = ((Split-Path -Leaf $commandPath) + ' ' + ($displayArgs -join ' ') + ' - < ' + (Format-CommandArgument -Value $promptPath))

if ($DryRun -and [string]::IsNullOrWhiteSpace($TestModelCheckOutputPath)) {
    Write-Output 'SPA TASK RUNNER'
    Write-Output ('TASK       {0}' -f $taskId)
    Write-Output ('ACTION     {0}' -f $action.ToUpperInvariant())
    Write-Output ('REPO       {0}' -f (Split-Path -Leaf $repositoryPath))
    Write-Output ('MODEL      {0}' -f $model)
    Write-Output ('PROVIDER   {0}' -f $provider)
    Write-Output ('REASONING  {0}' -f $reasoning)
    Write-Output ('SANDBOX    {0}' -f $sandbox)
    if ($isGenericImplementation) {
        Write-Output ('PLAN       {0}' -f (Split-Path -Leaf $genericImplementationRoute.PlanFile))
        Write-Output ('PLAN TASK  Task {0}' -f $genericImplementationRoute.TaskNumber)
        Write-Output ('PLAN TITLE {0}' -f $genericImplementationRoute.TaskTitle)
        Write-Output 'PROMPT     GENERIC'
        Write-Output 'COMMIT/PUSH REQUIRED YES'
    }
    Write-Output 'READY      NOT CHECKED (DRY RUN)'
    Write-Output ('COMMAND    {0}' -f $displayCommand)
    Write-SpaTaskSummary -Result 'DRY RUN' -Tests 'NOT APPLICABLE' -Commit 'NOT APPLICABLE' -Push 'NOT APPLICABLE' -Worktree 'NOT CHECKED (DRY RUN)' -Remote 'NOT CHECKED (DRY RUN)'
    exit 0
}

if (-not $TestMode -and -not $DryRun -and -not [string]::IsNullOrWhiteSpace($profile)) {
    $codexRoot = if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
    $profilePath = Join-Path $codexRoot ($profile + '.config.toml')
    if (-not (Test-Path -LiteralPath $profilePath -PathType Leaf)) {
        Stop-SpaRun "Codex profile '$profile' is not configured at $profilePath. Refusing to fall back to the default provider."
    }
}

$spaCheck = Join-Path $PSScriptRoot 'spa-check.ps1'
if (-not (Test-Path -LiteralPath $spaCheck -PathType Leaf)) {
    Stop-SpaRun "SPA preflight is missing: $spaCheck"
}

$preflightArgs = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $spaCheck,
    '-Target', $repository,
    '-ExpectedBranch', $expectedBranch,
    '-ExpectedModel', $model,
    '-ExpectedProvider', $provider,
    '-ExpectedReasoning', $reasoning,
    '-ExpectedApproval', 'never',
    '-ExpectedSandbox', $sandbox,
    '-CodexProfile', $profile
)
if (-not [string]::IsNullOrWhiteSpace($BackendPath)) { $preflightArgs += @('-BackendPath', $BackendPath) }
if (-not [string]::IsNullOrWhiteSpace($FrontendPath)) { $preflightArgs += @('-FrontendPath', $FrontendPath) }
if ([string]::IsNullOrWhiteSpace($BackendPath) -and $repository.Equals('Backend', [System.StringComparison]::OrdinalIgnoreCase)) { $preflightArgs += @('-BackendPath', $repositoryPath) }
if ([string]::IsNullOrWhiteSpace($FrontendPath) -and $repository.Equals('Frontend', [System.StringComparison]::OrdinalIgnoreCase)) { $preflightArgs += @('-FrontendPath', $repositoryPath) }
if (-not [string]::IsNullOrWhiteSpace($DependencyMarkerPath)) { $preflightArgs += @('-DependencyMarkerPath', $DependencyMarkerPath) }
if (-not [string]::IsNullOrWhiteSpace($TestModelCheckOutputPath)) { $preflightArgs += @('-CodexOutputPath', $TestModelCheckOutputPath) }

$preflightOutput = & powershell.exe @preflightArgs 2>&1 | Out-String
$preflightCode = $LASTEXITCODE
Write-Output $preflightOutput.TrimEnd()
if ($preflightCode -ne 0 -or -not [regex]::IsMatch($preflightOutput, '(?im)^READY\s+YES\s*$')) {
    Stop-SpaRun 'Preflight did not prove the requested route ready.'
}
$script:SpaLastSafe = 'PREFLIGHT READY'
$script:SpaRemoteStatus = 'SYNCED'

Write-Output ''
Write-Output 'SPA TASK RUNNER'
Write-Output ('TASK       {0}' -f $taskId)
Write-Output ('ACTION     {0}' -f $action.ToUpperInvariant())
Write-Output ('REPO       {0}' -f (Split-Path -Leaf $repositoryPath))
Write-Output ('MODEL      {0}' -f $model)
Write-Output ('PROVIDER   {0}' -f $provider)
Write-Output ('REASONING  {0}' -f $reasoning)
Write-Output ('SANDBOX    {0}' -f $sandbox)
if ($isGenericImplementation) {
    Write-Output ('PLAN       {0}' -f (Split-Path -Leaf $genericImplementationRoute.PlanFile))
    Write-Output ('PLAN TASK  Task {0}' -f $genericImplementationRoute.TaskNumber)
    Write-Output ('PLAN TITLE {0}' -f $genericImplementationRoute.TaskTitle)
    Write-Output 'PROMPT     GENERIC'
    Write-Output 'COMMIT/PUSH REQUIRED YES'
}
Write-Output 'READY      YES'
Write-Output ('COMMAND    {0}' -f $displayCommand)

if (-not [string]::IsNullOrWhiteSpace($TestTaskOutputPath)) {
    if (-not (Test-Path -LiteralPath $TestTaskOutputPath -PathType Leaf)) {
        Stop-SpaRun "Test task output is missing: $TestTaskOutputPath"
    }
    $testVerdict = Get-ReviewVerdict -Text ([System.IO.File]::ReadAllText($TestTaskOutputPath))
    Write-Output ''
    Write-Output 'SPA TASK RESULT'
    Write-Output ('TASK       {0}' -f $taskId)
    Write-Output ('VERDICT    {0}' -f $testVerdict)
    Write-Output 'AUTO-CLOSE NO'
    Write-SpaTaskSummary -Result $testVerdict -Worktree 'CLEAN' -Remote 'SYNCED'
    exit 0
}

if ($DryRun) {
    Write-Output 'DRY RUN    task invocation skipped'
    Write-SpaTaskSummary -Result 'DRY RUN' -Tests 'NOT APPLICABLE' -Commit 'NOT APPLICABLE' -Push 'NOT APPLICABLE' -Worktree 'CLEAN' -Remote 'SYNCED'
    exit 0
}

$promptExecutionPath = $promptPath
$genericPromptTemporaryPath = $null
if ($isGenericImplementation) {
    $renderedPrompt = Get-M1ImplementationPrompt -Route $genericImplementationRoute -TemplatePath $promptPath
    $genericPromptTemporaryPath = Join-Path ([System.IO.Path]::GetTempPath()) ('spa-m1-prompt-' + [guid]::NewGuid().ToString('N') + '.txt')
    [System.IO.File]::WriteAllText($genericPromptTemporaryPath, $renderedPrompt, (New-Object System.Text.UTF8Encoding($false)))
    $promptExecutionPath = $genericPromptTemporaryPath
}

Write-Output ''
Write-Output 'Starting...'

$lastMessagePath = Join-Path ([System.IO.Path]::GetTempPath()) ('spa-run-result-' + [guid]::NewGuid().ToString('N') + '.txt')
try {
    $taskArgs = @($codexArgs)
    $taskArgs += @('--output-last-message', $lastMessagePath, '-')
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        [System.IO.File]::ReadAllText($promptExecutionPath) |
            & $commandPath @taskArgs 2>&1 |
            ForEach-Object {
                if ($_ -is [System.Management.Automation.ErrorRecord]) {
                    Write-Output $_.Exception.Message
                }
                else {
                    Write-Output $_
                }
            }
        $taskCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($taskCode -ne 0) {
        Stop-SpaRun "Task CLI exited with code $taskCode."
    }
    if (-not (Test-Path -LiteralPath $lastMessagePath -PathType Leaf)) {
        Stop-SpaRun 'Task completed without a captured final response.'
    }

    $finalTaskText = [System.IO.File]::ReadAllText($lastMessagePath)
    $verdict = if ($isGenericImplementation) {
        if ([string]::IsNullOrWhiteSpace($finalTaskText)) {
            Stop-SpaRun 'Task completed without a non-empty implementation report.'
        }
        'IMPLEMENTED'
    }
    else {
        Get-ReviewVerdict -Text $finalTaskText
    }

    Write-Output ''
    Write-Output 'SPA TASK RESULT'
    Write-Output ('TASK       {0}' -f $taskId)
    Write-Output ('VERDICT    {0}' -f $verdict)
    Write-Output 'AUTO-CLOSE NO'
    Write-SpaTaskSummary -Result $verdict
    exit 0
}
finally {
    if (Test-Path -LiteralPath $lastMessagePath) {
        Remove-Item -LiteralPath $lastMessagePath -Force -ErrorAction SilentlyContinue
    }
    if ($genericPromptTemporaryPath -and (Test-Path -LiteralPath $genericPromptTemporaryPath -PathType Leaf)) {
        Remove-Item -LiteralPath $genericPromptTemporaryPath -Force -ErrorAction SilentlyContinue
    }
}
