Set-StrictMode -Version Latest

$script:M1Statuses = @(
    'PENDING',
    'RUNNING_LOCAL',
    'IMPLEMENTED',
    'REVIEW_PENDING',
    'REMEDIATION_REQUIRED',
    'COMPLETE'
)

# Harness-owned plumbing artifacts. These are commit/bookkeeping temp files that
# belong to the AutoDebug/V7 harness, never to a candidate change. The harness
# materializes them inside the repository Git directory, outside the worktree;
# the exact-name exclusion below is a narrow safety net only.
$script:M1HarnessOwnedTempArtifacts = @('.git-commit-temp')

function Get-SpaHarnessOwnedTempArtifactNames {
    return @($script:M1HarnessOwnedTempArtifacts)
}

function Test-SpaHarnessOwnedTempArtifact {
    param([Parameter(Mandatory = $true)][string]$Path)

    $leaf = Split-Path -Leaf $Path
    foreach ($artifact in @(Get-SpaHarnessOwnedTempArtifactNames)) {
        if ($leaf.Equals($artifact, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

function Get-SpaCandidateStatusLines {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$StatusOutput)

    $kept = New-Object System.Collections.Generic.List[string]
    foreach ($line in @($StatusOutput -split '\r?\n')) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $match = [regex]::Match($line, '^(.{2})\s+(.+)$')
        if (-not $match.Success) { [void]$kept.Add($line); continue }
        $pathText = $match.Groups[2].Value
        if ($pathText.Contains(' -> ')) {
            $pathText = $pathText.Substring($pathText.LastIndexOf(' -> ', [System.StringComparison]::Ordinal) + 4)
        }
        $pathText = $pathText.Trim([char]0x22)
        if (Test-SpaHarnessOwnedTempArtifact -Path $pathText) { continue }
        [void]$kept.Add($line)
    }
    return $kept
}

function Test-SpaCandidateWorktreeClean {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$StatusOutput)

    return (@(Get-SpaCandidateStatusLines -StatusOutput $StatusOutput).Count -eq 0)
}

function Resolve-SpaHarnessCommitTempPath {
    param([Parameter(Mandatory = $true)][string]$RepositoryPath)

    $gitDirectory = (Invoke-M1Git -Path $RepositoryPath -Arguments @('rev-parse', '--absolute-git-dir')).Output
    if ([string]::IsNullOrWhiteSpace($gitDirectory)) {
        throw ('Repository Git directory could not be resolved for harness commit temp: ' + $RepositoryPath)
    }
    return (Join-Path $gitDirectory '.git-commit-temp')
}

function Invoke-M1CommitWithHarnessTemp {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $tempPath = Resolve-SpaHarnessCommitTempPath -RepositoryPath $Path
    $encoding = New-Object System.Text.UTF8Encoding($false)
    try {
        [System.IO.File]::WriteAllText($tempPath, ($Message + [System.Environment]::NewLine), $encoding)
        Invoke-M1Git -Path $Path -Arguments @('commit', '-q', '-F', $tempPath) | Out-Null
    }
    finally {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Test-M1HasProperty {
    param([Parameter(Mandatory = $true)][object]$InputObject, [Parameter(Mandatory = $true)][string]$Name)

    if ($InputObject -is [System.Collections.IDictionary]) {
        return $InputObject.Contains($Name)
    }
    return ($null -ne $InputObject.PSObject.Properties[$Name])
}

function Set-M1ObjectProperty {
    param(
        [Parameter(Mandatory = $true)][object]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name,
        $Value
    )

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

function Assert-M1State {
    param([Parameter(Mandatory = $true)][object]$State)

    foreach ($property in @('schemaVersion', 'milestone', 'branch', 'repositories', 'tasks')) {
        if (-not (Test-M1HasProperty -InputObject $State -Name $property)) {
            throw "M1 state is malformed: missing '$property'."
        }
    }
    if ([int]$State.schemaVersion -ne 1) { throw 'M1 state is malformed: unsupported schemaVersion.' }
    if (-not ([string]$State.milestone).Equals('M1', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'M1 state is malformed: milestone must be M1.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$State.branch)) { throw 'M1 state is malformed: branch is empty.' }
    foreach ($repositoryName in @('backend', 'frontend')) {
        if (-not (Test-M1HasProperty -InputObject $State.repositories -Name $repositoryName) -or
            -not (Test-M1HasProperty -InputObject $State.repositories.$repositoryName -Name 'lastVerifiedSha')) {
            throw "M1 state is malformed: repositories.$repositoryName.lastVerifiedSha is required."
        }
    }

    $tasks = @($State.tasks)
    if ($tasks.Count -eq 0) { throw 'M1 state is malformed: tasks is empty.' }
    $seen = @{}
    foreach ($task in $tasks) {
        foreach ($property in @(
            'id', 'action', 'status', 'implementationProvider', 'implementationModel',
            'reviewerProvider', 'reviewerModel', 'reviewRoute', 'remediationRoute',
            'lastVerifiedBackendSha', 'lastVerifiedFrontendSha', 'implementationCommitSha',
            'remediationCommitSha', 'lastSuccessfulReviewVerdict', 'remediationAttempts',
            'evidence', 'updatedUtc'
        )) {
            if (-not (Test-M1HasProperty -InputObject $task -Name $property)) {
                throw "M1 state is malformed: task '$($task.id)' is missing '$property'."
            }
        }

        $taskId = ([string]$task.id).Trim().ToUpperInvariant()
        if ([string]::IsNullOrWhiteSpace($taskId) -or $seen.ContainsKey($taskId)) {
            throw "M1 state is malformed: task IDs must be non-empty and unique ('$taskId')."
        }
        $seen[$taskId] = $true

        $status = ([string]$task.status).Trim().ToUpperInvariant()
        if ($script:M1Statuses -notcontains $status) {
            throw "M1 state is malformed: task '$taskId' has unknown status '$status'."
        }

        foreach ($property in @('implementationSucceeded', 'testsSucceeded', 'reviewRequired', 'reviewSucceeded', 'relevantCommitsPushed')) {
            if (-not (Test-M1HasProperty -InputObject $task.evidence -Name $property)) {
                throw "M1 state is malformed: task '$taskId' evidence is missing '$property'."
            }
        }

        $humanAcceptedWithDeferrals =
            (Test-M1HasProperty -InputObject $task -Name 'humanAcceptedWithDeferrals') -and
            [bool]$task.humanAcceptedWithDeferrals
        if ($humanAcceptedWithDeferrals -and $status -ne 'COMPLETE') {
            throw ('M1 state is malformed: task {0} records human acceptance with deferrals without being COMPLETE.' -f $taskId)
        }

        if ($status -eq 'REVIEW_PENDING' -and [string]::IsNullOrWhiteSpace([string]$task.reviewRoute)) {
            throw "M1 state is malformed: task '$taskId' is REVIEW_PENDING without a reviewRoute."
        }
        if ($status -eq 'REMEDIATION_REQUIRED' -and [string]::IsNullOrWhiteSpace([string]$task.remediationRoute)) {
            throw "M1 state is malformed: task '$taskId' is REMEDIATION_REQUIRED without a remediationRoute."
        }
        if ($status -eq 'COMPLETE') {
            $evidence = $task.evidence
            $reviewRequired = [bool]$evidence.reviewRequired
            $reviewSucceeded = [bool]$evidence.reviewSucceeded
            $humanAcceptanceOk = $false
            if ($humanAcceptedWithDeferrals) {
                if (-not $reviewRequired) {
                    throw ('M1 state is malformed: task {0} records human acceptance with deferrals without a required review.' -f $taskId)
                }
                if ($reviewSucceeded) {
                    throw ('M1 state is malformed: task {0} records human acceptance with deferrals while its review is marked successful.' -f $taskId)
                }
                $acceptanceReason = if (Test-M1HasProperty -InputObject $task -Name 'humanAcceptanceReason') { [string]$task.humanAcceptanceReason } else { '' }
                $acceptedAtUtc = if (Test-M1HasProperty -InputObject $task -Name 'humanAcceptedAtUtc') { [string]$task.humanAcceptedAtUtc } else { '' }
                $deferrals = @()
                if (Test-M1HasProperty -InputObject $task -Name 'humanDeferrals') { $deferrals = @($task.humanDeferrals) }
                $explicitDeferrals = @($deferrals | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
                if (-not [string]::IsNullOrWhiteSpace($acceptedAtUtc)) {
                    $parsedAcceptedAt = [datetimeoffset]::MinValue
                    if (-not [datetimeoffset]::TryParse($acceptedAtUtc, [ref]$parsedAcceptedAt)) {
                        throw ('M1 state is malformed: task {0} has an invalid humanAcceptedAtUtc value.' -f $taskId)
                    }
                }
                $humanAcceptanceOk =
                    (-not [string]::IsNullOrWhiteSpace($acceptanceReason)) -and
                    (-not [string]::IsNullOrWhiteSpace($acceptedAtUtc)) -and
                    ($explicitDeferrals.Count -ge 1) -and
                    ([string]$task.lastSuccessfulReviewVerdict).Trim().Equals('CHANGES REQUIRED', [System.StringComparison]::OrdinalIgnoreCase)
            }
            $reviewOk = (-not $reviewRequired) -or $reviewSucceeded -or $humanAcceptanceOk
            if (-not [bool]$evidence.implementationSucceeded -or
                -not [bool]$evidence.testsSucceeded -or
                -not $reviewOk -or
                -not [bool]$evidence.relevantCommitsPushed) {
                throw "M1 state is malformed: task '$taskId' is COMPLETE without all required objective evidence."
            }
            if ($reviewRequired -and [string]::IsNullOrWhiteSpace([string]$task.lastSuccessfulReviewVerdict)) {
                throw "M1 state is malformed: task '$taskId' is COMPLETE without its required review verdict."
            }
        }

        $parsedUtc = [datetimeoffset]::MinValue
        if (-not [datetimeoffset]::TryParse([string]$task.updatedUtc, [ref]$parsedUtc)) {
            throw "M1 state is malformed: task '$taskId' has an invalid updatedUtc value."
        }
    }
    return $State
}

function Read-M1State {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "M1 state file is missing: $Path"
    }
    try {
        $state = [System.IO.File]::ReadAllText($Path) | ConvertFrom-Json
    }
    catch {
        throw "M1 state is malformed and was not accepted: $($_.Exception.Message)"
    }
    return (Assert-M1State -State $state)
}

function Write-M1StateAtomic {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][string]$Path
    )

    Assert-M1State -State $State | Out-Null
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $directory = Split-Path -Parent $fullPath
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $leaf = Split-Path -Leaf $fullPath
    $temporaryPath = Join-Path $directory ('.' + $leaf + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
    $backupPath = Join-Path $directory ('.' + $leaf + '.' + [guid]::NewGuid().ToString('N') + '.bak')
    $encoding = New-Object System.Text.UTF8Encoding($false)
    try {
        $json = $State | ConvertTo-Json -Depth 12
        [System.IO.File]::WriteAllText($temporaryPath, ($json + [System.Environment]::NewLine), $encoding)
        if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
            [System.IO.File]::Replace($temporaryPath, $fullPath, $backupPath, $true)
            if (Test-Path -LiteralPath $backupPath) { Remove-Item -LiteralPath $backupPath -Force }
        }
        else {
            [System.IO.File]::Move($temporaryPath, $fullPath)
        }
    }
    finally {
        foreach ($cleanupPath in @($temporaryPath, $backupPath)) {
            if (Test-Path -LiteralPath $cleanupPath) {
                Remove-Item -LiteralPath $cleanupPath -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Get-M1NextUnit {
    param([Parameter(Mandatory = $true)][object]$State)

    Assert-M1State -State $State | Out-Null
    foreach ($task in @($State.tasks)) {
        $status = ([string]$task.status).ToUpperInvariant()
        if ($status -eq 'COMPLETE') { continue }

        $routeId = [string]$task.id
        $stage = ([string]$task.action).ToUpperInvariant()
        if ($status -eq 'REVIEW_PENDING') {
            $routeId = [string]$task.reviewRoute
            $stage = 'REVIEW'
        }
        elseif ($status -eq 'REMEDIATION_REQUIRED') {
            $routeId = [string]$task.remediationRoute
            $stage = 'REMEDIATE'
        }
        elseif ($status -eq 'RUNNING_LOCAL' -and
            (Test-M1HasProperty -InputObject $task -Name 'activeRoute') -and
            -not [string]::IsNullOrWhiteSpace([string]$task.activeRoute)) {
            $routeId = [string]$task.activeRoute
            if ($routeId.EndsWith('-REVIEW', [System.StringComparison]::OrdinalIgnoreCase)) { $stage = 'REVIEW' }
        }

        return [pscustomobject]@{
            TaskId = ([string]$task.id).ToUpperInvariant()
            RouteId = $routeId.ToUpperInvariant()
            Status = $status
            Stage = $stage
            IsRecovery = ($status -eq 'RUNNING_LOCAL')
        }
    }
    return $null
}

function Read-SpaReviewVerdict {
    param([Parameter(Mandatory = $true)][string]$Text)

    $matches = @([regex]::Matches(
        $Text,
        '(?im)^\s*(SAFE WITH NON-BLOCKING OBSERVATIONS|SAFE|CHANGES REQUIRED)\s*$'
    ))
    if ($matches.Count -ne 1) {
        throw 'Review result did not contain exactly one recognized verdict. No state transition was accepted.'
    }

    $nonblankLines = @($Text -split '\r?\n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $verdict = $matches[0].Groups[1].Value.ToUpperInvariant()
    if ($nonblankLines.Count -eq 0 -or -not $nonblankLines[-1].Trim().Equals($verdict, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'The review verdict was not the final nonblank line. No state transition was accepted.'
    }
    return $verdict
}

function Get-M1StateTaskRecord {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][string]$TaskId
    )

    Assert-M1State -State $State | Out-Null
    $matches = @($State.tasks | Where-Object { ([string]$_.id).Equals($TaskId, [System.StringComparison]::OrdinalIgnoreCase) })
    if ($matches.Count -ne 1) {
        throw "M1 state must contain exactly one task record for '$TaskId'."
    }
    return $matches[0]
}

function Complete-M1ReviewTransition {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][string]$TaskId,
        [Parameter(Mandatory = $true)][string]$ReviewRoute,
        [Parameter(Mandatory = $true)][string]$Verdict,
        [string]$ReviewerProvider = '',
        [string]$ReviewerModel = '',
        [Parameter(Mandatory = $true)][string]$BackendHead,
        [Parameter(Mandatory = $true)][string]$FrontendHead,
        [Parameter(Mandatory = $true)][string]$ReviewedCommitSha
    )

    $task = Get-M1StateTaskRecord -State $State -TaskId $TaskId
    $status = ([string]$task.status).ToUpperInvariant()
    if ($status -ne 'REVIEW_PENDING') {
        throw "Review transition for '$TaskId' requires REVIEW_PENDING; current status is '$status'."
    }

    $taskRoute = [string]$task.reviewRoute
    if ([string]::IsNullOrWhiteSpace($taskRoute) -or
        -not $taskRoute.Equals($ReviewRoute, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Review transition for '$TaskId' does not match mapped review route '$ReviewRoute'."
    }

    if ([string]::IsNullOrWhiteSpace($ReviewedCommitSha)) {
        throw "Review transition for '$TaskId' has no reviewed remediation commit."
    }
    if (-not [string]::IsNullOrWhiteSpace($BackendHead) -and
        -not $ReviewedCommitSha.Equals($BackendHead, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Review transition for '$TaskId' refuses a reviewed commit mismatch."
    }

    $parsedVerdict = Read-SpaReviewVerdict -Text $Verdict
    $isAccepted = ($parsedVerdict -ne 'CHANGES REQUIRED')
    if ($isAccepted -and -not [bool]$task.evidence.reviewRequired) {
        throw "Review transition for '$TaskId' cannot complete a task that does not require review."
    }

    if ($isAccepted) {
        Set-M1ObjectProperty -InputObject $task.evidence -Name 'reviewSucceeded' -Value $true
        Set-M1ObjectProperty -InputObject $task -Name 'status' -Value 'COMPLETE'
        Set-M1ObjectProperty -InputObject $task -Name 'activeRoute' -Value $null
    }
    else {
        Set-M1ObjectProperty -InputObject $task.evidence -Name 'reviewSucceeded' -Value $false
        Set-M1ObjectProperty -InputObject $task -Name 'status' -Value 'REMEDIATION_REQUIRED'
        Set-M1ObjectProperty -InputObject $task -Name 'activeRoute' -Value $null
    }

    Set-M1ObjectProperty -InputObject $task -Name 'lastSuccessfulReviewVerdict' -Value $parsedVerdict
    if (-not [string]::IsNullOrWhiteSpace($ReviewerProvider)) {
        Set-M1ObjectProperty -InputObject $task -Name 'reviewerProvider' -Value $ReviewerProvider
    }
    if (-not [string]::IsNullOrWhiteSpace($ReviewerModel)) {
        Set-M1ObjectProperty -InputObject $task -Name 'reviewerModel' -Value $ReviewerModel
    }
    Set-M1ObjectProperty -InputObject $task -Name 'updatedUtc' -Value ([datetimeoffset]::UtcNow.ToString('o'))
    if (-not [string]::IsNullOrWhiteSpace($BackendHead)) {
        Set-M1ObjectProperty -InputObject $State.repositories.backend -Name 'lastVerifiedSha' -Value $BackendHead
    }
    if (-not [string]::IsNullOrWhiteSpace($FrontendHead)) {
        Set-M1ObjectProperty -InputObject $State.repositories.frontend -Name 'lastVerifiedSha' -Value $FrontendHead
    }

    Assert-M1State -State $State | Out-Null
    return $task
}

function Complete-M1HumanAcceptanceTransition {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][string]$TaskId,
        [Parameter(Mandatory = $true)][string]$ReviewVerdict,
        [Parameter(Mandatory = $true)][string]$Reason,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Deferrals,
        [string]$AcceptedAtUtc = ''
    )

    $task = Get-M1StateTaskRecord -State $State -TaskId $TaskId

    if (-not [bool]$task.evidence.reviewRequired) {
        throw ('Human acceptance for {0} requires a task that requires review.' -f $TaskId)
    }
    if ([bool]$task.evidence.reviewSucceeded) {
        throw ('Human acceptance for {0} cannot apply to a task whose review already succeeded.' -f $TaskId)
    }

    $status = ([string]$task.status).Trim().ToUpperInvariant()
    if (@('RUNNING_LOCAL', 'REVIEW_PENDING', 'REMEDIATION_REQUIRED') -notcontains $status) {
        throw ('Human acceptance for {0} is not valid from status {1}.' -f $TaskId, $status)
    }

    $parsedVerdict = Read-SpaReviewVerdict -Text $ReviewVerdict
    if ($parsedVerdict -ne 'CHANGES REQUIRED') {
        throw ('Human acceptance for {0} requires the preserved reviewer verdict CHANGES REQUIRED.' -f $TaskId)
    }
    $existingVerdict = ([string]$task.lastSuccessfulReviewVerdict).Trim()
    if (-not [string]::IsNullOrWhiteSpace($existingVerdict) -and
        -not $existingVerdict.Equals('CHANGES REQUIRED', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw ('Human acceptance for {0} refuses to overwrite recorded reviewer verdict {1}.' -f $TaskId, $existingVerdict)
    }

    if ([string]::IsNullOrWhiteSpace($Reason)) {
        throw ('Human acceptance for {0} requires a non-empty acceptance reason.' -f $TaskId)
    }

    $explicitDeferrals = @($Deferrals | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { ([string]$_).Trim() })
    if ($explicitDeferrals.Count -eq 0) {
        throw ('Human acceptance for {0} requires at least one explicit deferral.' -f $TaskId)
    }

    $acceptedAt = $AcceptedAtUtc
    if ([string]::IsNullOrWhiteSpace($acceptedAt)) {
        $acceptedAt = [datetimeoffset]::UtcNow.ToString('o')
    }
    else {
        $parsedAcceptedAt = [datetimeoffset]::MinValue
        if (-not [datetimeoffset]::TryParse([string]$acceptedAt, [ref]$parsedAcceptedAt)) {
            throw ('Human acceptance for {0} has an invalid acceptance timestamp.' -f $TaskId)
        }
        $acceptedAt = $parsedAcceptedAt.ToUniversalTime().ToString('o')
    }

    Set-M1ObjectProperty -InputObject $task.evidence -Name 'reviewSucceeded' -Value $false
    Set-M1ObjectProperty -InputObject $task -Name 'lastSuccessfulReviewVerdict' -Value $parsedVerdict
    Set-M1ObjectProperty -InputObject $task -Name 'humanAcceptedWithDeferrals' -Value $true
    Set-M1ObjectProperty -InputObject $task -Name 'humanAcceptanceReason' -Value $Reason.Trim()
    Set-M1ObjectProperty -InputObject $task -Name 'humanAcceptedAtUtc' -Value $acceptedAt
    Set-M1ObjectProperty -InputObject $task -Name 'humanDeferrals' -Value @($explicitDeferrals)
    Set-M1ObjectProperty -InputObject $task -Name 'status' -Value 'COMPLETE'
    Set-M1ObjectProperty -InputObject $task -Name 'activeRoute' -Value $null
    Set-M1ObjectProperty -InputObject $task -Name 'updatedUtc' -Value ([datetimeoffset]::UtcNow.ToString('o'))

    Assert-M1State -State $State | Out-Null
    return $task
}

function Get-SpaHealthStatus {
    param(
        [Parameter(Mandatory = $true)][datetimeoffset]$Now,
        [Parameter(Mandatory = $true)][datetimeoffset]$StartedAt,
        [Parameter(Mandatory = $true)][datetimeoffset]$LastOutputAt,
        [Parameter(Mandatory = $true)][bool]$ProcessAlive,
        [string]$FinalHealth = ''
    )

    if (-not $ProcessAlive) {
        if ([string]::IsNullOrWhiteSpace($FinalHealth)) { return 'STOPPED' }
        return $FinalHealth.ToUpperInvariant()
    }

    if ($LastOutputAt -lt $StartedAt) {
        throw 'Health record last_output_at cannot precede started_at.'
    }

    $silenceMinutes = ($Now - $LastOutputAt).TotalMinutes
    if ($silenceMinutes -gt 30) { return 'SUSPECTED_STALL' }
    if ($silenceMinutes -ge 15) { return 'LONG_SILENCE' }
    if (($LastOutputAt - $StartedAt).TotalSeconds -lt 1) { return 'SILENT' }
    return 'ACTIVE'
}

function Format-SpaDuration {
    param([Parameter(Mandatory = $true)][double]$TotalSeconds)

    if ($TotalSeconds -lt 0) { $TotalSeconds = 0 }
    $time = [TimeSpan]::FromSeconds($TotalSeconds)
    return ('{0:00}:{1:00}:{2:00}' -f [math]::Floor($time.TotalHours), $time.Minutes, $time.Seconds)
}

function Remove-SpaFinalTaskSummary {
    param([Parameter(Mandatory = $true)][string]$Text)

    return ([regex]::Replace(
        $Text,
        '(?ms)\r?\n?^={60}\r?\nSPA TASK SUMMARY\r?\n={60}\r?\n.*?^={60}\s*\z',
        ''
    )).TrimEnd()
}

function Write-SpaHealthRecord {
    param(
        [Parameter(Mandatory = $true)][string]$Task,
        [Parameter(Mandatory = $true)][string]$Phase,
        [Parameter(Mandatory = $true)][string]$Model,
        [Parameter(Mandatory = $true)][string]$Provider,
        [Parameter(Mandatory = $true)][datetimeoffset]$StartedAt,
        [Parameter(Mandatory = $true)][datetimeoffset]$LastOutputAt,
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [Parameter(Mandatory = $true)][bool]$ProcessAlive,
        [Parameter(Mandatory = $true)][string]$LastSafe,
        [string]$HealthRoot = $env:TEMP,
        [string]$FinalHealth = '',
        [datetimeoffset]$Now = [datetimeoffset]::UtcNow,
        [bool]$Retry = $false,
        [string]$OriginalTask = '',
        [int]$DebugCycle = 0
    )

    $health = Get-SpaHealthStatus -Now $Now -StartedAt $StartedAt -LastOutputAt $LastOutputAt -ProcessAlive $ProcessAlive -FinalHealth $FinalHealth
    $record = [ordered]@{
        task = $Task
        phase = $Phase
        model = $Model
        provider = $Provider
        started_at = $StartedAt.ToString('o')
        elapsed = [math]::Round((($Now - $StartedAt).TotalSeconds), 1)
        last_output_at = $LastOutputAt.ToString('o')
        process_id = $ProcessId
        process_alive = $ProcessAlive
        health = $health
        last_safe = $LastSafe
        updated_at = $Now.ToString('o')
    }
    if ($Retry) { $record['retry'] = $true }
    if (-not [string]::IsNullOrWhiteSpace($OriginalTask)) { $record['original_task'] = $OriginalTask }
    if ($DebugCycle -gt 0) { $record['debug_cycle'] = [int]$DebugCycle }

    $root = [System.IO.Path]::GetFullPath($HealthRoot)
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
    }
    $path = Join-Path $root ('spa-run-health-' + $ProcessId + '.json')
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, ($record | ConvertTo-Json -Depth 5), $encoding)
    return $path
}

function Read-SpaHealthRecord {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    try {
        return ([System.IO.File]::ReadAllText($Path) | ConvertFrom-Json)
    }
    catch {
        return $null
    }
}

function Get-SpaLatestHealthRecord {
    param([string]$HealthRoot = $env:TEMP)

    if ([string]::IsNullOrWhiteSpace($HealthRoot) -or -not (Test-Path -LiteralPath $HealthRoot -PathType Container)) {
        return $null
    }

    $files = @(Get-ChildItem -LiteralPath $HealthRoot -Filter 'spa-run-health-*.json' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc -Descending)
    foreach ($file in $files) {
        $record = Read-SpaHealthRecord -Path $file.FullName
        if ($null -ne $record) { return $record }
    }
    return $null
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

function Invoke-SpaTrackedProcess {
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
        [int]$HeartbeatSeconds = 120,
        [bool]$Retry = $false,
        [string]$OriginalTask = '',
        [int]$DebugCycle = 0
    )

    $startedAt = [datetimeoffset]::UtcNow
    $lastOutputAt = $startedAt
    $trackState = [pscustomobject]@{
        Output = New-Object System.Text.StringBuilder
        Stdout = New-Object System.Text.StringBuilder
        Stderr = New-Object System.Text.StringBuilder
        LastOutputAt = $startedAt
    }

    $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processStartInfo.FileName = $FilePath
    $processStartInfo.Arguments = (($ArgumentList | ForEach-Object { Format-ProcessArgument -Value $_ }) -join ' ')
    $processStartInfo.WorkingDirectory = $WorkingDirectory
    $processStartInfo.UseShellExecute = $false
    $processStartInfo.RedirectStandardOutput = $true
    $processStartInfo.RedirectStandardError = $true
    $processStartInfo.RedirectStandardInput = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processStartInfo
    $process.Start() | Out-Null
    $process.BeginOutputReadLine()
    $process.BeginErrorReadLine()

    $outputEvent = Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action {
        if ($null -ne $EventArgs.Data) {
            [void]$Event.MessageData.Output.AppendLine($EventArgs.Data)
            [void]$Event.MessageData.Stdout.AppendLine($EventArgs.Data)
            $Event.MessageData.LastOutputAt = [datetimeoffset]::UtcNow
        }
    } -MessageData $trackState
    $errorEvent = Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action {
        if ($null -ne $EventArgs.Data) {
            [void]$Event.MessageData.Output.AppendLine($EventArgs.Data)
            [void]$Event.MessageData.Stderr.AppendLine($EventArgs.Data)
            $Event.MessageData.LastOutputAt = [datetimeoffset]::UtcNow
        }
    } -MessageData $trackState

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
        -Retry $Retry `
        -OriginalTask $OriginalTask `
        -DebugCycle $DebugCycle | Out-Null

    $nextHeartbeat = ([datetimeoffset]::UtcNow).AddSeconds($HeartbeatSeconds)
    try {
        while (-not $process.HasExited) {
            Start-Sleep -Seconds 2
            $process.Refresh()
            $now = [datetimeoffset]::UtcNow
            $receivedOutput = ($trackState.LastOutputAt -ne $lastOutputAt)

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
                    -Now $now `
                    -Retry $Retry `
                    -OriginalTask $OriginalTask `
                    -DebugCycle $DebugCycle | Out-Null
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
                    -Now $now `
                    -Retry $Retry `
                    -OriginalTask $OriginalTask `
                    -DebugCycle $DebugCycle | Out-Null
                $nextHeartbeat = $now.AddSeconds($HeartbeatSeconds)
            }
        }

        $process.WaitForExit()
        Start-Sleep -Milliseconds 500
        Unregister-Event -SourceIdentifier $outputEvent.Name -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier $errorEvent.Name -ErrorAction SilentlyContinue
        if ($trackState.LastOutputAt -gt $lastOutputAt) { $lastOutputAt = $trackState.LastOutputAt }

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
            -Now ([datetimeoffset]::UtcNow) `
            -Retry $Retry `
            -OriginalTask $OriginalTask `
            -DebugCycle $DebugCycle | Out-Null

        $trimmedOutput = $trackState.Output.ToString().TrimEnd()
        $trimmedStdout = $trackState.Stdout.ToString().TrimEnd()
        $trimmedStderr = $trackState.Stderr.ToString().TrimEnd()
        return [pscustomobject]@{
            Code = $code
            Output = $trimmedOutput
            Stdout = $trimmedStdout
            Stderr = $trimmedStderr
            DisplayOutput = Remove-SpaFinalTaskSummary -Text $trimmedOutput
        }
    }
    finally {
        if ($outputEvent) { Unregister-Event -SourceIdentifier $outputEvent.Name -ErrorAction SilentlyContinue }
        if ($errorEvent) { Unregister-Event -SourceIdentifier $errorEvent.Name -ErrorAction SilentlyContinue }
        if ($null -ne $process -and -not $process.HasExited) {
            try { $process.Kill() } catch { }
        }
    }
}

function Invoke-M1Git {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$AllowFailure
    )

    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = & git -C $Path @Arguments 2>&1 | Out-String
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($code -ne 0 -and -not $AllowFailure) {
        throw "Git command failed in '$Path' (git $($Arguments -join ' ')) with exit code $code."
    }
    return [pscustomobject]@{ Code = $code; Output = $output.Trim() }
}

function Test-M1RepositoryLocalState {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedBranch
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "$Name repository is missing: $Path"
    }
    $inside = Invoke-M1Git -Path $Path -Arguments @('rev-parse', '--is-inside-work-tree') -AllowFailure
    if ($inside.Code -ne 0 -or $inside.Output -ne 'true') { throw "$Name path is not a Git repository: $Path" }

    $branch = (Invoke-M1Git -Path $Path -Arguments @('branch', '--show-current')).Output
    if (-not $branch.Equals($ExpectedBranch, [System.StringComparison]::Ordinal)) {
        throw "$Name repository is on wrong branch '$branch'; expected '$ExpectedBranch'."
    }
    $dirty = (Invoke-M1Git -Path $Path -Arguments @('status', '--porcelain=v1', '--untracked-files=normal')).Output
    if (-not (Test-SpaCandidateWorktreeClean -StatusOutput $dirty)) {
        throw "$Name repository is dirty; recovery stopped without changing it."
    }
    return $true
}

function Sync-M1Repository {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedBranch
    )

    Test-M1RepositoryLocalState -Name $Name -Path $Path -ExpectedBranch $ExpectedBranch | Out-Null

    Invoke-M1Git -Path $Path -Arguments @('fetch', '--prune', 'origin', $ExpectedBranch) | Out-Null
    $remoteRef = 'refs/remotes/origin/' + $ExpectedBranch
    $remote = Invoke-M1Git -Path $Path -Arguments @('rev-parse', '--verify', $remoteRef) -AllowFailure
    if ($remote.Code -ne 0) { throw "$Name remote branch origin/$ExpectedBranch is unavailable." }

    $countText = (Invoke-M1Git -Path $Path -Arguments @('rev-list', '--left-right', '--count', ('HEAD...' + $remoteRef))).Output
    $counts = @($countText -split '\s+' | Where-Object { $_ -ne '' })
    if ($counts.Count -ne 2) { throw "$Name repository divergence could not be determined." }
    $ahead = [int]$counts[0]
    $behind = [int]$counts[1]
    if ($ahead -gt 0 -and $behind -gt 0) { throw "$Name repository has diverged from origin/$ExpectedBranch; automatic recovery is forbidden." }
    if ($ahead -gt 0) { throw "$Name repository is ahead of origin/$ExpectedBranch; expected checkpoint state is not pushed." }

    $fastForwarded = $false
    if ($behind -gt 0) {
        Invoke-M1Git -Path $Path -Arguments @('pull', '--ff-only', 'origin', $ExpectedBranch) | Out-Null
        $fastForwarded = $true
    }

    $dirtyAfter = (Invoke-M1Git -Path $Path -Arguments @('status', '--porcelain=v1', '--untracked-files=normal')).Output
    if (-not (Test-SpaCandidateWorktreeClean -StatusOutput $dirtyAfter)) {
        throw "$Name repository became dirty during synchronization."
    }
    $finalCounts = (Invoke-M1Git -Path $Path -Arguments @('rev-list', '--left-right', '--count', ('HEAD...' + $remoteRef))).Output
    if ($finalCounts -notmatch '^0\s+0$') { throw "$Name repository is not synchronized after ff-only recovery." }

    return [pscustomobject]@{
        Name = $Name
        Path = [System.IO.Path]::GetFullPath($Path)
        Head = (Invoke-M1Git -Path $Path -Arguments @('rev-parse', 'HEAD')).Output
        FastForwarded = $fastForwarded
    }
}

function Get-M1RepositoryBaseline {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedBranch
    )

    Test-M1RepositoryLocalState -Name $Name -Path $Path -ExpectedBranch $ExpectedBranch | Out-Null
    $head = (Invoke-M1Git -Path $Path -Arguments @('rev-parse', 'HEAD')).Output
    $remoteRef = 'refs/remotes/origin/' + $ExpectedBranch
    $remote = Invoke-M1Git -Path $Path -Arguments @('rev-parse', '--verify', $remoteRef) -AllowFailure
    if ($remote.Code -ne 0) {
        throw "$Name repository remote baseline origin/$ExpectedBranch is unavailable."
    }

    return [pscustomobject]@{
        Name = $Name
        Path = [System.IO.Path]::GetFullPath($Path)
        Branch = $ExpectedBranch
        Head = $head
        RemoteRef = $remoteRef
        RemoteHead = $remote.Output
    }
}

function Assert-M1RepositoryBaseline {
    param([Parameter(Mandatory = $true)][object]$Baseline)

    if ($null -eq $Baseline) {
        throw 'Repository baseline is missing.'
    }
    if (-not (Test-Path -LiteralPath $Baseline.Path -PathType Container)) {
        throw "$($Baseline.Name) repository is missing: $($Baseline.Path)"
    }

    $branch = (Invoke-M1Git -Path $Baseline.Path -Arguments @('branch', '--show-current')).Output
    if (-not $branch.Equals([string]$Baseline.Branch, [System.StringComparison]::Ordinal)) {
        throw "$($Baseline.Name) repository branch changed from '$($Baseline.Branch)' to '$branch' during the task."
    }

    $head = (Invoke-M1Git -Path $Baseline.Path -Arguments @('rev-parse', 'HEAD')).Output
    if (-not $head.Equals([string]$Baseline.Head, [System.StringComparison]::Ordinal)) {
        throw "$($Baseline.Name) repository HEAD changed unexpectedly during the task."
    }

    $remote = Invoke-M1Git -Path $Baseline.Path -Arguments @('rev-parse', '--verify', $Baseline.RemoteRef) -AllowFailure
    if ($remote.Code -ne 0) {
        throw "$($Baseline.Name) repository remote state could not be inspected after the task."
    }
    if (-not $remote.Output.Equals([string]$Baseline.RemoteHead, [System.StringComparison]::Ordinal)) {
        throw "$($Baseline.Name) repository remote state changed unexpectedly during the task."
    }
}

function Complete-M1ImplementationCandidate {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedBranch,
        [Parameter(Mandatory = $true)][object]$Baseline,
        [Parameter(Mandatory = $true)][string]$TaskId
    )

    $status = (Invoke-M1Git -Path $Path -Arguments @('status', '--porcelain=v1', '--untracked-files=normal')).Output
    if (Test-SpaCandidateWorktreeClean -StatusOutput $status) {
        return [pscustomobject]@{
            Name = $Name
            Path = [System.IO.Path]::GetFullPath($Path)
            Head = $Baseline.Head
            CandidateCommitted = $false
        }
    }

    Assert-M1RepositoryBaseline -Baseline $Baseline

    $unstagedCheck = Invoke-M1Git -Path $Path -Arguments @('diff', '--check') -AllowFailure
    if ($unstagedCheck.Code -ne 0) {
        throw "$Name candidate verification failed before checkpoint (unstaged whitespace/conflict markers)."
    }

    $addArguments = @('add', '-A', '--', '.')
    foreach ($artifact in @(Get-SpaHarnessOwnedTempArtifactNames)) {
        $addArguments += (':(exclude)' + $artifact)
    }
    Invoke-M1Git -Path $Path -Arguments $addArguments | Out-Null
    $stagedCheck = Invoke-M1Git -Path $Path -Arguments @('diff', '--cached', '--check') -AllowFailure
    if ($stagedCheck.Code -ne 0) {
        throw "$Name candidate verification failed before checkpoint (staged whitespace/conflict markers)."
    }
    Invoke-M1CommitWithHarnessTemp -Path $Path -Message ('chore: checkpoint SPA M1 ' + $TaskId + ' IMPLEMENTED')
    $push = Invoke-M1Git -Path $Path -Arguments @('push', 'origin', $ExpectedBranch) -AllowFailure
    if ($push.Code -ne 0) {
        throw "$Name candidate checkpoint was committed locally but push failed; '$TaskId' is not durable."
    }

    $remoteRef = 'refs/remotes/origin/' + $ExpectedBranch
    $counts = (Invoke-M1Git -Path $Path -Arguments @('rev-list', '--left-right', '--count', ('HEAD...' + $remoteRef))).Output
    if ($counts -notmatch '^0\s+0$') {
        throw "$Name candidate checkpoint push returned but local/remote synchronization is not 0/0."
    }

    return [pscustomobject]@{
        Name = $Name
        Path = [System.IO.Path]::GetFullPath($Path)
        Head = (Invoke-M1Git -Path $Path -Arguments @('rev-parse', 'HEAD')).Output
        CandidateCommitted = $true
    }
}

function Assert-M1CommitVisible {
    param([string]$RepositoryName, [string]$RepositoryPath, [string]$Sha, [string]$Branch)

    if ([string]::IsNullOrWhiteSpace($Sha)) { return }
    if ($Sha -notmatch '^[0-9a-fA-F]{40}$') { throw "$RepositoryName recorded SHA '$Sha' is malformed." }
    $exists = Invoke-M1Git -Path $RepositoryPath -Arguments @('cat-file', '-e', ($Sha + '^{commit}')) -AllowFailure
    if ($exists.Code -ne 0) { throw "$RepositoryName recorded SHA '$Sha' is missing locally." }
    $visible = Invoke-M1Git -Path $RepositoryPath -Arguments @('merge-base', '--is-ancestor', $Sha, ('refs/remotes/origin/' + $Branch)) -AllowFailure
    if ($visible.Code -ne 0) { throw "$RepositoryName recorded SHA '$Sha' is not visible on origin/$Branch." }
}

function Test-M1RecordedShas {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][string]$BackendPath,
        [Parameter(Mandatory = $true)][string]$FrontendPath,
        [Parameter(Mandatory = $true)][string]$Branch
    )

    Assert-M1State -State $State | Out-Null
    Assert-M1CommitVisible -RepositoryName 'Backend' -RepositoryPath $BackendPath -Sha ([string]$State.repositories.backend.lastVerifiedSha) -Branch $Branch
    Assert-M1CommitVisible -RepositoryName 'Frontend' -RepositoryPath $FrontendPath -Sha ([string]$State.repositories.frontend.lastVerifiedSha) -Branch $Branch
    foreach ($task in @($State.tasks)) {
        foreach ($field in @('lastVerifiedBackendSha', 'implementationCommitSha', 'remediationCommitSha')) {
            Assert-M1CommitVisible -RepositoryName 'Backend' -RepositoryPath $BackendPath -Sha ([string]$task.$field) -Branch $Branch
        }
        Assert-M1CommitVisible -RepositoryName 'Frontend' -RepositoryPath $FrontendPath -Sha ([string]$task.lastVerifiedFrontendSha) -Branch $Branch
    }
    return $true
}

function Get-M1Deadline {
    param(
        [Parameter(Mandatory = $true)][datetimeoffset]$Now,
        [Nullable[double]]$MaxMinutes,
        [string]$Until = ''
    )

    if ($null -ne $MaxMinutes -and -not [string]::IsNullOrWhiteSpace($Until)) {
        throw 'Specify only one of -MaxMinutes or -Until.'
    }
    if ($null -ne $MaxMinutes) {
        $minutes = [double]$MaxMinutes
        if ($minutes -le 0) { throw '-MaxMinutes must be greater than zero.' }
        return $Now.AddMinutes($minutes)
    }
    if (-not [string]::IsNullOrWhiteSpace($Until)) {
        $parsed = [datetime]::MinValue
        if (-not [datetime]::TryParseExact($Until, 'HH:mm', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) {
            throw '-Until must use 24-hour HH:mm format.'
        }
        return [datetimeoffset]::new($Now.Year, $Now.Month, $Now.Day, $parsed.Hour, $parsed.Minute, 0, $Now.Offset)
    }
    return $null
}

function Test-M1ShouldSoftStop {
    param(
        [Parameter(Mandatory = $true)][datetimeoffset]$Now,
        [AllowNull()][Nullable[datetimeoffset]]$Deadline,
        [Parameter(Mandatory = $true)][int]$SafetyBufferMinutes
    )

    if ($SafetyBufferMinutes -lt 0) { throw '-SafetyBufferMinutes cannot be negative.' }
    if ($null -eq $Deadline) { return $false }
    return (([datetimeoffset]$Deadline - $Now).TotalMinutes -le $SafetyBufferMinutes)
}

function Invoke-M1SequentialEngine {
    param(
        [Parameter(Mandatory = $true)][string[]]$UnitIds,
        [AllowNull()][Nullable[datetimeoffset]]$Deadline,
        [Parameter(Mandatory = $true)][int]$SafetyBufferMinutes,
        [Parameter(Mandatory = $true)][scriptblock]$NowProvider,
        [Parameter(Mandatory = $true)][scriptblock]$ExecuteUnit,
        [Parameter(Mandatory = $true)][scriptblock]$CheckpointUnit
    )

    $lastCheckpoint = $null
    for ($index = 0; $index -lt $UnitIds.Count; $index++) {
        $unitId = $UnitIds[$index]
        $now = [datetimeoffset](& $NowProvider)
        if (Test-M1ShouldSoftStop -Now $now -Deadline $Deadline -SafetyBufferMinutes $SafetyBufferMinutes) {
            return [pscustomobject]@{ Stopped = $true; LastCheckpoint = $lastCheckpoint; NextUnit = $unitId }
        }

        # Deliberately do not inspect the deadline while a unit is executing.
        & $ExecuteUnit $unitId | Out-Null
        & $CheckpointUnit $unitId | Out-Null
        $lastCheckpoint = $unitId
    }
    return [pscustomobject]@{ Stopped = $false; LastCheckpoint = $lastCheckpoint; NextUnit = $null }
}
