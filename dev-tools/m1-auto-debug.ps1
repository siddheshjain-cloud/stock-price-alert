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
        [string]$OriginalObjective = ''
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
