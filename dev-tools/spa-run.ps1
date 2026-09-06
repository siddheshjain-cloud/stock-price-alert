[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Task,
    [switch]$DryRun,
    [switch]$TestMode,
    [string]$RoutingPath = '',
    [string]$BackendPath = '',
    [string]$FrontendPath = '',
    [string]$DependencyMarkerPath = '',
    [string]$TestModelCheckOutputPath = '',
    [string]$TestTaskOutputPath = '',
    [string]$StatePath = '',
    [Nullable[double]]$MaxMinutes,
    [string]$Until = '',
    [ValidateRange(0, 1440)]
    [int]$SafetyBufferMinutes = 15,
    [string]$TestNow = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:SpaMaxMinutesSpecified = $PSBoundParameters.ContainsKey('MaxMinutes')
$script:SpaTaskId = $Task.Trim().ToUpperInvariant()
$script:SpaSummaryAction = 'NOT AVAILABLE'
$script:SpaSummaryModel = 'NOT AVAILABLE'
$script:SpaSummaryReasoning = 'NOT AVAILABLE'
$script:SpaLastSafe = 'NOT AVAILABLE'
$script:SpaRemoteStatus = 'NOT AVAILABLE'

# Keep all Git calls made by this process and its child scripts unattended.
$env:GIT_PAGER = 'cat'
$env:PAGER = 'cat'
$env:GIT_TERMINAL_PROMPT = '0'

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

function Remove-SpaFinalTaskSummary {
    param([Parameter(Mandatory = $true)][string]$Text)

    return ([regex]::Replace(
        $Text,
        '(?ms)\r?\n?^={60}\r?\nSPA TASK SUMMARY\r?\n={60}\r?\n.*?^={60}\s*\z',
        ''
    )).TrimEnd()
}

function Stop-SpaRun {
    param([Parameter(Mandatory = $true)][string]$Message)

    Write-Output ('SPA-RUN FAIL: {0}' -f $Message)
    Write-SpaTaskSummary -Result 'STOPPED' -Reason $Message -Next ('Resolve failure and rerun spa-run {0}' -f $script:SpaTaskId)
    exit 1
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

    $matches = @([regex]::Matches($Text, '(?im)^VERDICT\s+(SAFE WITH NON-BLOCKING OBSERVATIONS|SAFE|CHANGES REQUIRED)\s*$'))
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
    if ($changeLines.Count -ne 1 -or $changeLines[0].Substring(3).Replace('\', '/') -ne $relativeStatePath) {
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

function Invoke-M1ChildRoute {
    param(
        [Parameter(Mandatory = $true)][string]$RouteId,
        [switch]$ChildDryRun
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
    $output = & powershell.exe @arguments 2>&1 | Out-String
    $trimmedOutput = $output.TrimEnd()
    return [pscustomobject]@{
        Code = $LASTEXITCODE
        Output = $trimmedOutput
        DisplayOutput = Remove-SpaFinalTaskSummary -Text $trimmedOutput
    }
}

function Invoke-M1Remaining {
    $stateToolsPath = Join-Path $PSScriptRoot 'm1-state.ps1'
    if (-not (Test-Path -LiteralPath $stateToolsPath -PathType Leaf)) {
        Stop-SpaRun "M1 state helper is missing: $stateToolsPath"
    }
    . $stateToolsPath

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

            $result = Invoke-M1ChildRoute -RouteId $unit.RouteId
            if ($result.DisplayOutput) { Write-Output $result.DisplayOutput }
            if ($result.Code -ne 0) { throw "Unit '$($unit.RouteId)' failed; RUNNING_LOCAL remains the durable non-complete state." }
            $verdict = Get-M1ChildVerdict -Text $result.Output

            $backendSync = Sync-M1Repository -Name 'Backend' -Path $backendRepositoryPath -ExpectedBranch $requiredBranch
            $frontendSync = Sync-M1Repository -Name 'Frontend' -Path $toolingPath -ExpectedBranch $requiredBranch
            $hardStopAfterCheckpoint = $false
            if ($verdict -eq 'CHANGES REQUIRED') {
                Set-M1Property -InputObject $taskRecord -Name 'status' -Value 'REMEDIATION_REQUIRED'
                Set-M1Property -InputObject $taskRecord -Name 'activeRoute' -Value $null
                if ([int]$taskRecord.remediationAttempts -ge 2) {
                    $hardStopAfterCheckpoint = $true
                }
            }
            elseif ($unit.Stage -eq 'REVIEW' -or ([string]$taskRecord.action).Equals('REVIEW', [System.StringComparison]::OrdinalIgnoreCase)) {
                Set-M1Property -InputObject $taskRecord -Name 'lastSuccessfulReviewVerdict' -Value $verdict
                Set-M1Property -InputObject $taskRecord.evidence -Name 'reviewSucceeded' -Value $true
                Set-M1Property -InputObject $taskRecord.evidence -Name 'implementationSucceeded' -Value $true
                Set-M1Property -InputObject $taskRecord.evidence -Name 'testsSucceeded' -Value $true
                Set-M1Property -InputObject $taskRecord.evidence -Name 'relevantCommitsPushed' -Value $true
                Set-M1Property -InputObject $taskRecord -Name 'status' -Value 'COMPLETE'
                Set-M1Property -InputObject $taskRecord -Name 'activeRoute' -Value $null
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

$testOnlyOverrides = @('RoutingPath', 'BackendPath', 'FrontendPath', 'DependencyMarkerPath', 'TestModelCheckOutputPath', 'TestTaskOutputPath', 'StatePath', 'TestNow')
$usedTestOnlyOverrides = @($testOnlyOverrides | Where-Object { $PSBoundParameters.ContainsKey($_) })
if ($TestMode -and -not $DryRun) {
    Stop-SpaRun '-TestMode requires -DryRun and can never invoke a task.'
}
if (-not $TestMode -and $usedTestOnlyOverrides.Count -gt 0) {
    Stop-SpaRun 'Test-only overrides require both -TestMode and -DryRun.'
}

$taskId = $script:SpaTaskId
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

Write-Output ''
Write-Output 'Starting...'

$lastMessagePath = Join-Path ([System.IO.Path]::GetTempPath()) ('spa-run-result-' + [guid]::NewGuid().ToString('N') + '.txt')
try {
    $taskArgs = @($codexArgs)
    $taskArgs += @('--output-last-message', $lastMessagePath, '-')
    [System.IO.File]::ReadAllText($promptPath) | & $commandPath @taskArgs 2>&1 | ForEach-Object { Write-Output $_ }
    $taskCode = $LASTEXITCODE

    if ($taskCode -ne 0) {
        Stop-SpaRun "Task CLI exited with code $taskCode."
    }
    if (-not (Test-Path -LiteralPath $lastMessagePath -PathType Leaf)) {
        Stop-SpaRun 'Task completed without a captured final response.'
    }

    $verdict = Get-ReviewVerdict -Text ([System.IO.File]::ReadAllText($lastMessagePath))

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
}
