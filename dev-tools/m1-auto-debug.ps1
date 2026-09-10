Set-StrictMode -Version Latest

function Get-SpaEvidenceMapValue {
    param(
        [Parameter(Mandatory = $true)][object]$Map,
        [Parameter(Mandatory = $true)][string]$Key
    )

    if ($null -eq $Map) { return 'NOT AVAILABLE' }
    if ($Map -is [System.Collections.IDictionary]) {
        if ($Map.Contains($Key)) { return [string]$Map[$Key] }
        return 'NOT AVAILABLE'
    }
    $property = $Map.PSObject.Properties[$Key]
    if ($null -ne $property) { return [string]$property.Value }
    return 'NOT AVAILABLE'
}

function Get-SpaFailureSignature {
    param([Parameter(Mandatory = $true)][object]$Result)

    $text = ''
    if (-not [string]::IsNullOrWhiteSpace([string]$Result.DisplayOutput)) {
        $text = [string]$Result.DisplayOutput
    }
    elseif (-not [string]::IsNullOrWhiteSpace([string]$Result.Output)) {
        $text = [string]$Result.Output
    }

    $lines = @($text -split '\r?\n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $errorLines = @($lines | Where-Object {
        $_ -match '(?i)error|exception|fail|fatal|traceback|throw|cannot|unable|invalid|missing|denied|refused|aborted'
    })
    if ($errorLines.Count -eq 0) {
        $selected = @($lines | Select-Object -First 12)
        if ($lines.Count -gt 24) {
            $selected += @($lines | Select-Object -Last 12)
        }
    }
    else {
        $selected = @($errorLines)
    }

    $normalized = (($selected -join '|') `
        -replace '\b[0-9a-fA-F]{7,40}\b', '' `
        -replace '\b\d{4}-\d{1,2}-\d{1,2}[T ]\d{2}:\d{2}:\d{2}(\.\d+)?([+-]\d{2}:\d{2}|Z)?\b', '' `
        -replace '\s+', ' ').Trim()
    if ([string]::IsNullOrWhiteSpace($normalized)) { $normalized = 'no-output' }

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($normalized)
        $hash = [System.BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '')
        return ('{0}:{1}' -f [int]$Result.Code, $hash)
    }
    finally {
        $sha.Dispose()
    }
}

function New-SpaAutoDebugEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$TaskId,
        [Parameter(Mandatory = $true)][string]$RouteId,
        [string]$PlanTaskTitle = '',
        [string]$Action = '',
        [string]$Phase = '',
        [Parameter(Mandatory = $true)][string]$Repository,
        [Parameter(Mandatory = $true)][string]$RepositoryPath,
        [string]$Command = '',
        [Parameter(Mandatory = $true)][int]$ExitCode,
        [string]$Stdout = '',
        [string]$Stderr = '',
        [string]$DisplayOutput = '',
        [string]$Model = '',
        [string]$Provider = '',
        [string]$Reasoning = '',
        [string]$Sandbox = '',
        [hashtable]$M1State = @{},
        [string]$LastSafe = '',
        [hashtable]$CurrentCommits = @{},
        [string]$OriginalObjective = '',
        [object]$OriginalFailure = $null,
        [object]$FailureTrail = $null,
        [string]$PreviousRejectedPatch = '',
        [string]$RejectionReason = ''
    )

    return [ordered]@{
        schemaVersion = 1
        capturedUtc = [datetimeoffset]::UtcNow.ToString('o')
        taskId = $TaskId
        routeId = $RouteId
        planTaskTitle = $PlanTaskTitle
        action = $Action
        phase = $Phase
        repository = $Repository
        repositoryPath = $RepositoryPath
        command = $Command
        exitCode = [int]$ExitCode
        stdout = $Stdout
        stderr = $Stderr
        displayOutput = $DisplayOutput
        model = $Model
        provider = $Provider
        reasoningEffort = $Reasoning
        sandbox = $Sandbox
        lastSafe = $LastSafe
        m1State = $M1State
        currentCommits = $CurrentCommits
        originalObjective = $OriginalObjective
        originalFailure = $OriginalFailure
        failureTrail = $FailureTrail
        previousRejectedPatch = $PreviousRejectedPatch
        rejectionReason = $RejectionReason
    }
}

function Format-SpaAutoDebugPrompt {
    param(
        [Parameter(Mandatory = $true)][object]$Evidence,
        [Parameter(Mandatory = $true)][string]$PrimaryRepositoryPath,
        [Parameter(Mandatory = $true)][string]$SecondaryRepositoryPath
    )

    $primary = [System.IO.Path]::GetFullPath($PrimaryRepositoryPath)
    $secondary = [System.IO.Path]::GetFullPath($SecondaryRepositoryPath)

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.AppendLine('SPA AUTO-DEBUG V1')
    [void]$builder.AppendLine('')
    [void]$builder.AppendLine('The original SPA M1 development task failed. Investigate the actual root cause using the')
    [void]$builder.AppendLine('supplied failure evidence, repository code, Git history, tests, configuration and')
    [void]$builder.AppendLine('surrounding architecture.')
    [void]$builder.AppendLine('')
    [void]$builder.AppendLine('Work like an experienced senior developer. Do not guess-edit. Reproduce or otherwise')
    [void]$builder.AppendLine('establish the root cause first. Use TDD where the defect can reasonably be expressed as a')
    [void]$builder.AppendLine('regression test: RED -> verify intended failure -> minimal repair -> GREEN.')
    [void]$builder.AppendLine('')
    [void]$builder.AppendLine('REPOSITORIES IN SCOPE')
    [void]$builder.AppendLine('Both SPA repositories are in scope. You may inspect either repository and follow the')
    [void]$builder.AppendLine('evidence wherever it leads, including across repository boundaries.')
    [void]$builder.AppendLine(('Primary repository (working root): ' + $primary))
    [void]$builder.AppendLine(('Secondary repository (additional writable root): ' + $secondary))
    [void]$builder.AppendLine('')
    [void]$builder.AppendLine('AUTO-DEBUGGER AUTHORITY')
    [void]$builder.AppendLine('You have broad authority inside the local SPA development workspace. Evidence-based')
    [void]$builder.AppendLine('actions you MAY take include:')
    [void]$builder.AppendLine('- inspect or search any relevant file in either SPA repository')
    [void]$builder.AppendLine('- inspect Git history and diffs, logs, tests, fixtures, configuration and local SQLite/data')
    [void]$builder.AppendLine('- run PowerShell, Python and focused tests, and reproduce the failure')
    [void]$builder.AppendLine('- add temporary diagnostics, add or modify tests, create files and edit code')
    [void]$builder.AppendLine('- delete obsolete or incorrect development code when the evidence justifies it')
    [void]$builder.AppendLine('- modify PowerShell tooling, backend application code, frontend code, fixtures and refactor')
    [void]$builder.AppendLine('  across as many files or repositories as the root cause requires')
    [void]$builder.AppendLine('- make several evidence-based repair iterations and run focused regression tests')
    [void]$builder.AppendLine('- commit and push verified repairs when they are green')
    [void]$builder.AppendLine('')
    [void]$builder.AppendLine('Do not artificially restrict yourself to the dev-tools directory and do not treat backend')
    [void]$builder.AppendLine('product code as off limits. The debugger is not a dev-tools-only agent.')
    [void]$builder.AppendLine('')
    [void]$builder.AppendLine('DEBUGGING METHOD')
    [void]$builder.AppendLine('Make the smallest sound root-cause repair, but do not avoid a necessary multi-file or')
    [void]$builder.AppendLine('cross-repository fix merely because it is larger than expected. Preserve the intended')
    [void]$builder.AppendLine('frozen M1 requirements. Do not weaken tests or safety guarantees merely to make a')
    [void]$builder.AppendLine('failure disappear. Run the tests necessary to establish that the repair works and has')
    [void]$builder.AppendLine('not broken the relevant surrounding behaviour.')
    [void]$builder.AppendLine('')
    [void]$builder.AppendLine('When green, commit and push the repair, then exit successfully so spa-run can retry the')
    [void]$builder.AppendLine('original task. If resolution genuinely requires a new architectural/product decision, a')
    [void]$builder.AppendLine('consequential external action, or you can no longer make evidence-based progress, stop and')
    [void]$builder.AppendLine('clearly explain the reason rather than inventing a fix.')
    [void]$builder.AppendLine('')
    [void]$builder.AppendLine('CONSEQUENTIAL BOUNDARIES')
    [void]$builder.AppendLine('You must NOT: force-push; rewrite published Git history; delete repositories; delete')
    [void]$builder.AppendLine('branches as a recovery strategy; intentionally destroy valuable persistent data; operate on a')
    [void]$builder.AppendLine('production/live database; deploy to production; execute broker/trading/order actions; send')
    [void]$builder.AppendLine('Telegram/email/external messages; perform live financial transactions; exfiltrate')
    [void]$builder.AppendLine('repository/data/secrets; expose credentials; rotate or change credentials or permissions;')
    [void]$builder.AppendLine('invoke live external integrations merely to test a theory; silently change the frozen M1')
    [void]$builder.AppendLine('architecture/specification to make tests pass; or remove/disable a genuine safety control')
    [void]$builder.AppendLine('merely because it blocks execution.')
    [void]$builder.AppendLine('')
    [void]$builder.AppendLine('NO DEBUGGER RECURSION')
    [void]$builder.AppendLine('Do not invoke spa-run M1-REMAINING, spa-run -ApplyReview, or another Auto-Debug session.')
    [void]$builder.AppendLine('This debugger process is supervised by deterministic spa-run code. If this session fails,')
    [void]$builder.AppendLine('the supervisor records the failure and handles it. Never launch a nested SPA supervisor.')
    [void]$builder.AppendLine('')
    [void]$builder.AppendLine('FAILURE EVIDENCE')
    [void]$builder.AppendLine(('Task id:        ' + [string]$Evidence.taskId))
    [void]$builder.AppendLine(('Route:          ' + [string]$Evidence.routeId))
    [void]$builder.AppendLine(('Plan task:      ' + [string]$Evidence.planTaskTitle))
    [void]$builder.AppendLine(('Action:         ' + [string]$Evidence.action))
    [void]$builder.AppendLine(('Phase:          ' + [string]$Evidence.phase))
    [void]$builder.AppendLine(('Repository:     ' + [string]$Evidence.repository))
    [void]$builder.AppendLine(('Repository path: ' + [string]$Evidence.repositoryPath))
    [void]$builder.AppendLine(('Command:        ' + [string]$Evidence.command))
    [void]$builder.AppendLine(('Exit code:      ' + [string]$Evidence.exitCode))
    [void]$builder.AppendLine(('Model:          ' + [string]$Evidence.model))
    [void]$builder.AppendLine(('Provider:       ' + [string]$Evidence.provider))
    [void]$builder.AppendLine(('Reasoning:      ' + [string]$Evidence.reasoningEffort))
    [void]$builder.AppendLine(('Sandbox:        ' + [string]$Evidence.sandbox))
    [void]$builder.AppendLine(('Last safe:      ' + [string]$Evidence.lastSafe))
    [void]$builder.AppendLine(('Backend HEAD:   ' + (Get-SpaEvidenceMapValue -Map $Evidence.currentCommits -Key 'backend')))
    [void]$builder.AppendLine(('Frontend HEAD:  ' + (Get-SpaEvidenceMapValue -Map $Evidence.currentCommits -Key 'frontend')))
    [void]$builder.AppendLine('')
    [void]$builder.AppendLine('BEGIN CAPTURED STDOUT')
    [void]$builder.AppendLine([string]$Evidence.stdout)
    [void]$builder.AppendLine('END CAPTURED STDOUT')
    [void]$builder.AppendLine('')
    [void]$builder.AppendLine('BEGIN CAPTURED STDERR')
    [void]$builder.AppendLine([string]$Evidence.stderr)
    [void]$builder.AppendLine('END CAPTURED STDERR')
    [void]$builder.AppendLine('')
    [void]$builder.AppendLine('BEGIN DISPLAY OUTPUT')
    [void]$builder.AppendLine([string]$Evidence.displayOutput)
    [void]$builder.AppendLine('END DISPLAY OUTPUT')
    [void]$builder.AppendLine('')
    [void]$builder.AppendLine('CURRENT M1 STATE')
    [void]$builder.AppendLine(($Evidence.m1State | ConvertTo-Json -Depth 6))
    [void]$builder.AppendLine('')
    [void]$builder.AppendLine('ORIGINAL TASK OBJECTIVE')
    $objective = [string]$Evidence.originalObjective
    if ([string]::IsNullOrWhiteSpace($objective)) { $objective = 'NOT AVAILABLE' }
    [void]$builder.AppendLine($objective)

    [void]$builder.AppendLine('')
    [void]$builder.AppendLine('V7 AUTO-DEBUG CONTEXT')
    [void]$builder.AppendLine('This context is preserved across every repair attempt. Use it to avoid repeating')
    [void]$builder.AppendLine('the same failed repair and to respect the frozen escalation order.')
    [void]$builder.AppendLine('')
    [void]$builder.AppendLine('ORIGINAL FAILURE')
    if ($null -eq $Evidence.originalFailure) {
        [void]$builder.AppendLine('NOT AVAILABLE')
    }
    else {
        [void]$builder.AppendLine(($Evidence.originalFailure | ConvertTo-Json -Depth 8))
    }
    [void]$builder.AppendLine('')
    [void]$builder.AppendLine('STRUCTURED FAILURE TRAIL')
    $trail = @()
    if ($null -ne $Evidence.failureTrail) {
        foreach ($trailEntry in $Evidence.failureTrail) {
            $trail += $trailEntry
        }
    }
    if ($trail.Count -eq 0) {
        [void]$builder.AppendLine('NONE')
    }
    else {
        [void]$builder.AppendLine(($trail | ConvertTo-Json -Depth 10))
    }
    [void]$builder.AppendLine('')
    [void]$builder.AppendLine('PREVIOUS REJECTED PATCH')
    $rejectedPatch = [string]$Evidence.previousRejectedPatch
    if ([string]::IsNullOrWhiteSpace($rejectedPatch)) { $rejectedPatch = 'NONE' }
    [void]$builder.AppendLine($rejectedPatch)
    [void]$builder.AppendLine('')
    [void]$builder.AppendLine('EXACT REJECTION REASON')
    $rejectionReason = [string]$Evidence.rejectionReason
    if ([string]::IsNullOrWhiteSpace($rejectionReason)) { $rejectionReason = 'NONE' }
    [void]$builder.AppendLine($rejectionReason)
    return $builder.ToString()
}

function Write-SpaAutoDebugArtifacts {
    param(
        [Parameter(Mandatory = $true)][string]$EvidenceRoot,
        [Parameter(Mandatory = $true)][object]$Evidence,
        [Parameter(Mandatory = $true)][string]$Prompt,
        [Parameter(Mandatory = $true)][int]$Cycle
    )

    if (-not (Test-Path -LiteralPath $EvidenceRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $EvidenceRoot -Force | Out-Null
    }
    $suffix = ('{0:D2}' -f $Cycle)
    $evidenceFile = Join-Path $EvidenceRoot ('evidence-' + $suffix + '.json')
    $promptFile = Join-Path $EvidenceRoot ('debug-prompt-' + $suffix + '.txt')
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText(
        $evidenceFile,
        ($Evidence | ConvertTo-Json -Depth 12),
        $encoding
    )
    [System.IO.File]::WriteAllText($promptFile, $Prompt, $encoding)
    return [pscustomobject]@{
        EvidenceRoot = [System.IO.Path]::GetFullPath($EvidenceRoot)
        EvidenceFile = [System.IO.Path]::GetFullPath($evidenceFile)
        PromptFile = [System.IO.Path]::GetFullPath($promptFile)
    }
}

function Get-SpaAutoDebugRoute {
    # Runtime debugger routing seam. Auto-Debug orchestration never hard-codes a
    # debugger provider/model: AUTO_DEBUG_PROVIDER / AUTO_DEBUG_MODEL /
    # AUTO_DEBUG_REASONING select the active debugger without rewriting spa-run.
    #
    # Tonight's defaults (no environment overrides):
    #   provider deepseek, model deepseek-v4-pro, reasoning high
    #
    # Tomorrow, switching Auto-Debug to Claude is a configuration change:
    #   AUTO_DEBUG_PROVIDER=claude
    #   AUTO_DEBUG_MODEL=claude-opus   (omit to keep Claude's configured default)

    $provider = ([string]$env:AUTO_DEBUG_PROVIDER).Trim()
    if ([string]::IsNullOrWhiteSpace($provider)) { $provider = 'deepseek' }
    $knownProviders = @('deepseek', 'claude')
    if ($knownProviders -notcontains $provider.ToLowerInvariant()) {
        throw "AUTO_DEBUG_PROVIDER '$provider' is not supported. Supported providers: $($knownProviders -join ', ')."
    }
    $provider = $provider.ToLowerInvariant()

    $model = ([string]$env:AUTO_DEBUG_MODEL).Trim()
    if ([string]::IsNullOrWhiteSpace($model)) {
        if ($provider -eq 'claude') {
            # Claude is authenticated locally and may keep its configured model
            # until AUTO_DEBUG_MODEL explicitly selects one tomorrow.
            $model = ''
        }
        else {
            $model = 'deepseek-v4-pro'
        }
    }

    $reasoning = ([string]$env:AUTO_DEBUG_REASONING).Trim()
    if ([string]::IsNullOrWhiteSpace($reasoning)) { $reasoning = 'high' }

    $displayModel = if ([string]::IsNullOrWhiteSpace($model)) { 'claude-default' } else { $model }
    return [pscustomobject]@{
        Provider = $provider
        Model = $model
        DisplayModel = $displayModel
        Reasoning = $reasoning
        Mode = 'REPAIR'
        ReadOnly = $false
        IsHuman = $false
    }
}

function Get-SpaAutoDebugEscalationPlan {
    # Frozen V7 escalation order. Code-repair attempts never promote themselves:
    # each stage produces a candidate, deterministic retry/promotion remains
    # authoritative, and the final advisory stage is explicitly read-only.
    return @(
        [ordered]@{
            Index = 0
            Key = 'FLASH_REPAIR'
            Provider = 'deepseek'
            Model = 'deepseek-v4-flash'
            Reasoning = 'high'
            Mode = 'REPAIR'
            ReadOnly = $false
            Description = 'DeepSeek Flash repair'
        },
        [ordered]@{
            Index = 1
            Key = 'FLASH_SELF_DEBUG'
            Provider = 'deepseek'
            Model = 'deepseek-v4-flash'
            Reasoning = 'high'
            Mode = 'SELF_DEBUG'
            ReadOnly = $false
            Description = 'DeepSeek Flash self-debug'
        },
        [ordered]@{
            Index = 2
            Key = 'PRO_REPAIR'
            Provider = 'deepseek'
            Model = 'deepseek-v4-pro'
            Reasoning = 'high'
            Mode = 'REPAIR'
            ReadOnly = $false
            Description = 'DeepSeek Pro repair'
        },
        [ordered]@{
            Index = 3
            Key = 'PRO_SELF_DEBUG'
            Provider = 'deepseek'
            Model = 'deepseek-v4-pro'
            Reasoning = 'high'
            Mode = 'SELF_DEBUG'
            ReadOnly = $false
            Description = 'DeepSeek Pro self-debug'
        },
        [ordered]@{
            Index = 4
            Key = 'CLAUDE_APPELLATE'
            Provider = 'claude'
            Model = 'claude-opus'
            Reasoning = 'high'
            Mode = 'REVIEW'
            ReadOnly = $true
            Description = 'Claude Opus appellate review'
        },
        [ordered]@{
            Index = 5
            Key = 'HUMAN'
            Provider = 'human'
            Model = 'human'
            Reasoning = ''
            Mode = 'HUMAN'
            ReadOnly = $true
            Description = 'Human escalation'
        }
    )
}

function Get-SpaAutoDebugEscalationStep {
    param(
        [Parameter(Mandatory = $true)][int]$Index
    )

    $plan = @(Get-SpaAutoDebugEscalationPlan)
    if ($Index -lt 0) { $Index = 0 }
    if ($Index -ge $plan.Count) { $Index = $plan.Count - 1 }
    $step = $plan[$Index]
    $model = [string]$step.Model
    return [pscustomobject]@{
        Index = [int]$Index
        Key = [string]$step.Key
        Provider = [string]$step.Provider
        Model = $model
        DisplayModel = if ([string]::IsNullOrWhiteSpace($model)) { 'default' } else { $model }
        Reasoning = [string]$step.Reasoning
        Mode = [string]$step.Mode
        ReadOnly = [bool]$step.ReadOnly
        IsHuman = ([string]$step.Provider -eq 'human')
        Description = [string]$step.Description
    }
}

function Test-SpaAutoDebugDeterministicFailure {
    param([Parameter(Mandatory = $true)][object]$Result)

    $code = 0
    if ($null -ne $Result.PSObject.Properties['Code']) { $code = [int]$Result.Code }
    $text = @(
        [string]$Result.Output
        [string]$Result.DisplayOutput
        [string]$Result.Stdout
        [string]$Result.Stderr
    ) -join "`n"

    # V7 orchestration/configuration failures. A disabled or missing review route,
    # or missing review execution metadata, is a tooling configuration defect and
    # not a code defect. It is classified before the provider categories so the
    # supervisor stops through the existing configuration/human path without
    # spending any Flash/Pro code-repair cycle on it.
    $routeConfigurationPattern = '(?i)(?:is recorded but not yet enabled|requires implementer metadata before an independent review can run|unknown spa task id|refers to unknown model route)'
    if ($text -match $routeConfigurationPattern) {
        $evidenceLine = @(
            $text -split '\r?\n' |
                Where-Object { $_ -match $routeConfigurationPattern } |
                Select-Object -First 1
        )
        return [pscustomobject]@{
            IsDeterministic = $true
            Category = 'ORCHESTRATION_CONFIGURATION'
            Reason = 'The review route or its execution metadata is not enabled for orchestration.'
            Evidence = ([string]$evidenceLine).Trim()
        }
    }

    if ($code -eq 401 -or $text -match '(?i)\b401\b|\bunauthorized\b|\bauthentication\b|\binvalid api key\b|\bmissing (?:api )?token\b|\bexpired (?:api )?token\b') {
        return [pscustomobject]@{
            IsDeterministic = $true
            Category = 'AUTHENTICATION'
            Reason = 'Provider authentication failed (401).'
            Evidence = ''
        }
    }
    if ($code -eq 402 -or $text -match '(?i)\b402\b|\binsufficient balance\b|\bbilling\b|\bpayment required\b|\bquota exceeded\b|\bout of credits\b') {
        return [pscustomobject]@{
            IsDeterministic = $true
            Category = 'BILLING'
            Reason = 'Provider billing/balance failure (402).'
            Evidence = ''
        }
    }
    if ($text -match '(?i)\bprovider unavailable\b|\bprovider_unavailable\b|\bapi unavailable\b|\bservice unavailable\b|\b503\b|\boverloaded\b|\brate limit exceeded\b') {
        return [pscustomobject]@{
            IsDeterministic = $true
            Category = 'PROVIDER_UNAVAILABLE'
            Reason = 'The provider is unavailable.'
            Evidence = ''
        }
    }
    if ($text -match '(?i)\bmodel unavailable\b|\bmodel_not_found\b|\bunknown model\b|\binvalid model\b|\bmodel .* not (?:available|found)\b|\b404\b.*\bmodel\b') {
        return [pscustomobject]@{
            IsDeterministic = $true
            Category = 'MODEL_UNAVAILABLE'
            Reason = 'The requested model is unavailable.'
            Evidence = ''
        }
    }

    return [pscustomobject]@{
        IsDeterministic = $false
        Category = ''
        Reason = ''
        Evidence = ''
    }
}

function Get-SpaAutoDebugHarnessFailurePattern {
    # Exact harness-owned failure signatures. These describe the harness failing
    # to prepare or bookkeep a candidate, not the candidate failing validation.
    return '(?i)(?:candidate status:|candidate diffstat:|candidate verification failed|candidate checkpoint|candidate scope|checkpoint refused because the tooling repository has changes|repository is dirty|repository became dirty|is not a durable|\.git-commit-temp)'
}

function Test-SpaAutoDebugCodeValidationRejection {
    # V7 may spend a code-repair attempt only when the candidate was rejected by
    # the authoritative validation layer: a prescribed test failure, validator
    # failure, static/AST guard failure, or deterministic scope/invariant guard.
    # Harness bookkeeping, commit preparation, and orchestration/configuration
    # failures are never code-validation rejections.
    param([Parameter(Mandatory = $true)][object]$Result)

    if ($null -ne $Result.PSObject.Properties['Source'] -and
        ([string]$Result.Source).Equals('HARNESS', [System.StringComparison]::OrdinalIgnoreCase)) {
        return $false
    }

    $text = @(
        [string]$Result.Output
        [string]$Result.DisplayOutput
        [string]$Result.Stdout
        [string]$Result.Stderr
    ) -join ([char]10)
    if ($text -match (Get-SpaAutoDebugHarnessFailurePattern)) { return $false }

    $deterministic = Test-SpaAutoDebugDeterministicFailure -Result $Result
    if ([bool]$deterministic.IsDeterministic) { return $false }

    return $true
}

function Test-SpaAutoDebugProClass {
    # A Pro/deep originating task keeps Pro-classified repair attempts. Flash
    # classified tasks keep the existing Flash-first escalation behavior.
    param(
        [string]$Model = '',
        [string]$ModelRoute = ''
    )

    $routeName = ([string]$ModelRoute).Trim()
    if ($routeName -match '(?i)(?:^|[^A-Za-z])PRO(?:$|[^A-Za-z])') { return $true }

    $modelName = ([string]$Model).Trim()
    if ($modelName -match '(?i)(?:^|[^A-Za-z0-9])pro(?:$|[^A-Za-z0-9])') { return $true }

    return $false
}

function Get-SpaAutoDebugEscalationStartIndex {
    # Frozen V7 escalation plan index 0 is Flash repair and index 2 is Pro
    # repair. Pro/deep tasks start at PRO_REPAIR so a repair attempt can never
    # begin as, or fall back to, Flash.
    param([bool]$IsProClass)

    if ($IsProClass) { return 2 }
    return 0
}

function New-SpaAutoDebugFailureTrailEntry {
    param(
        [Parameter(Mandatory = $true)][int]$Attempt,
        [Parameter(Mandatory = $true)][string]$Stage,
        [Parameter(Mandatory = $true)][string]$Provider,
        [Parameter(Mandatory = $true)][string]$Model,
        [Parameter(Mandatory = $true)][object]$Failure,
        [string]$PreviousRejectedPatch = '',
        [string]$RejectionReason = ''
    )

    $signature = Get-SpaFailureSignature -Result $Failure
    return [ordered]@{
        attempt = [int]$Attempt
        stage = $Stage
        provider = $Provider
        model = $Model
        capturedUtc = [datetimeoffset]::UtcNow.ToString('o')
        failure = [ordered]@{
            code = [int]$Failure.Code
            signature = $signature
            output = [string]$Failure.Output
            displayOutput = [string]$Failure.DisplayOutput
            stdout = [string]$Failure.Stdout
            stderr = [string]$Failure.Stderr
        }
        previousRejectedPatch = $PreviousRejectedPatch
        rejectionReason = $RejectionReason
    }
}

function Reset-SpaAutoDebugRepository {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedBranch,
        [Parameter(Mandatory = $true)][string]$InitialHead
    )

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
            throw "$Name repository is missing: $Path"
        }
        $branch = (& git -C $Path branch --show-current 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or -not $branch.Equals($ExpectedBranch, [System.StringComparison]::Ordinal)) {
            throw "$Name repository cannot be reset to the V7 initial head because it is not on '$ExpectedBranch'."
        }
        & git -C $Path reset --hard $InitialHead 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "$Name repository reset to V7 initial head failed."
        }
        & git -C $Path clean -fd 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "$Name repository clean after V7 reset failed."
        }

        & git -C $Path fetch --prune origin $ExpectedBranch 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "$Name repository fetch before V7 reset failed."
        }
        $remoteRef = 'refs/remotes/origin/' + $ExpectedBranch
        $remoteHead = (& git -C $Path rev-parse --verify $remoteRef 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($remoteHead) -and
            -not $remoteHead.Equals($InitialHead, [System.StringComparison]::Ordinal)) {
            & git -C $Path push --force origin ($InitialHead + ':' + $ExpectedBranch) 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "$Name repository rejected-candidate rollback failed; the V7 initial head could not be restored on origin."
            }
        }
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

function Find-SpaAutoDebugCommand {
    param([Parameter(Mandatory = $true)][string]$Provider)

    if ($Provider -eq 'claude') {
        $candidates = @('claude.cmd', 'claude.exe', 'claude')
    }
    else {
        $candidates = @('codex.cmd', 'codex.exe')
    }
    foreach ($candidate in $candidates) {
        $found = @(Get-Command $candidate -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($found) { return $found[0] }
    }
    return $null
}
