Set-StrictMode -Version Latest

$script:M1Statuses = @(
    'PENDING',
    'RUNNING_LOCAL',
    'IMPLEMENTED',
    'REVIEW_PENDING',
    'REMEDIATION_REQUIRED',
    'COMPLETE'
)

function Test-M1HasProperty {
    param([Parameter(Mandatory = $true)][object]$InputObject, [Parameter(Mandatory = $true)][string]$Name)

    if ($InputObject -is [System.Collections.IDictionary]) {
        return $InputObject.Contains($Name)
    }
    return ($null -ne $InputObject.PSObject.Properties[$Name])
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

        if ($status -eq 'REVIEW_PENDING' -and [string]::IsNullOrWhiteSpace([string]$task.reviewRoute)) {
            throw "M1 state is malformed: task '$taskId' is REVIEW_PENDING without a reviewRoute."
        }
        if ($status -eq 'REMEDIATION_REQUIRED' -and [string]::IsNullOrWhiteSpace([string]$task.remediationRoute)) {
            throw "M1 state is malformed: task '$taskId' is REMEDIATION_REQUIRED without a remediationRoute."
        }
        if ($status -eq 'COMPLETE') {
            $evidence = $task.evidence
            $reviewOk = (-not [bool]$evidence.reviewRequired) -or [bool]$evidence.reviewSucceeded
            if (-not [bool]$evidence.implementationSucceeded -or
                -not [bool]$evidence.testsSucceeded -or
                -not $reviewOk -or
                -not [bool]$evidence.relevantCommitsPushed) {
                throw "M1 state is malformed: task '$taskId' is COMPLETE without all required objective evidence."
            }
            if ([bool]$evidence.reviewRequired -and [string]::IsNullOrWhiteSpace([string]$task.lastSuccessfulReviewVerdict)) {
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
    if (-not [string]::IsNullOrWhiteSpace($dirty)) { throw "$Name repository is dirty; recovery stopped without changing it." }
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
    if (-not [string]::IsNullOrWhiteSpace($dirtyAfter)) { throw "$Name repository became dirty during synchronization." }
    $finalCounts = (Invoke-M1Git -Path $Path -Arguments @('rev-list', '--left-right', '--count', ('HEAD...' + $remoteRef))).Output
    if ($finalCounts -notmatch '^0\s+0$') { throw "$Name repository is not synchronized after ff-only recovery." }

    return [pscustomobject]@{
        Name = $Name
        Path = [System.IO.Path]::GetFullPath($Path)
        Head = (Invoke-M1Git -Path $Path -Arguments @('rev-parse', 'HEAD')).Output
        FastForwarded = $fastForwarded
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
