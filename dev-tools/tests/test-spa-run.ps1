[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$devTools = Join-Path $repoRoot 'dev-tools'
$spaRun = Join-Path $devTools 'spa-run.ps1'
$routingPath = Join-Path $devTools 'm1-model-routing.psd1'
$reviewPrompt = Join-Path $devTools 'prompts\P2T4-REVIEW.txt'
$expectedBranch = 'feature/investment-operating-system-m1'

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

function Assert-NotContains {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Needle,
        [Parameter(Mandatory = $true)][string]$Message
    )

    Assert-True ($Text.IndexOf($Needle, [System.StringComparison]::Ordinal) -lt 0) $Message
}

function Assert-FinalSummary {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Heading,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $summaryCount = @([regex]::Matches($Text, ('(?m)^' + [regex]::Escape($Heading) + '\r?$'))).Count
    $summaryAtEnd = [regex]::IsMatch(
        $Text,
        ('(?ms)^={60}\r?\n' + [regex]::Escape($Heading) + '\r?\n={60}\r?\n.*^={60}\s*\z')
    )
    Assert-True ($summaryCount -eq 1 -and $summaryAtEnd) $Message
}

function Invoke-SpaRun {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $spaRun @Arguments 2>&1 | Out-String
    return [pscustomobject]@{
        Code = $LASTEXITCODE
        Output = $output
    }
}

function Initialize-TestGitRepo {
    param(
        [Parameter(Mandatory = $true)][string]$WorkingRepo,
        [Parameter(Mandatory = $true)][string]$BareRemote,
        [Parameter(Mandatory = $true)][string]$Branch
    )

    git init --bare -q $BareRemote
    if ($LASTEXITCODE -ne 0) { throw "git init --bare failed for $BareRemote" }
    git init -q $WorkingRepo
    if ($LASTEXITCODE -ne 0) { throw "git init failed for $WorkingRepo" }
    git -C $WorkingRepo config user.email 'spa-run-test@example.com'
    git -C $WorkingRepo config user.name 'SPA Run Test'
    Set-Content -LiteralPath (Join-Path $WorkingRepo 'README.md') -Value 'test repository' -NoNewline
    Set-Content -LiteralPath (Join-Path $WorkingRepo 'requirements.txt') -Value 'pytest==8.0.0' -NoNewline
    git -C $WorkingRepo add -A
    git -C $WorkingRepo commit -q -m 'initial commit'
    if ($LASTEXITCODE -ne 0) { throw "git commit failed for $WorkingRepo" }
    git -C $WorkingRepo branch -M $Branch
    git -C $WorkingRepo remote add origin $BareRemote
    git -C $WorkingRepo push -q -u origin $Branch
    if ($LASTEXITCODE -ne 0) { throw "git push failed for $WorkingRepo" }
}

function Get-TestFingerprint {
    param([Parameter(Mandatory = $true)][string]$Root)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    $builder = New-Object System.Text.StringBuilder
    try {
        foreach ($file in @(Get-ChildItem -LiteralPath $Root -File -Filter 'requirements*.txt' | Sort-Object Name)) {
            $hash = [System.BitConverter]::ToString($sha.ComputeHash([System.IO.File]::ReadAllBytes($file.FullName))).Replace('-', '')
            [void]$builder.AppendLine(($file.Name + ':' + $hash))
        }
        return [System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($builder.ToString()))).Replace('-', '')
    }
    finally {
        $sha.Dispose()
    }
}

foreach ($path in @($spaRun, $routingPath, $reviewPrompt)) {
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "required runner artifact exists: $path"
}

if ($failures.Count -gt 0) {
    Write-Host ''
    Write-Host "RED: $($failures.Count) runner artifact(s) are missing."
    exit 1
}

$secretSentinel = 'test-secret-never-print'
$previousSecret = [System.Environment]::GetEnvironmentVariable('DEEPSEEK_API_KEY', 'Process')
[System.Environment]::SetEnvironmentVariable('DEEPSEEK_API_KEY', $secretSentinel, 'Process')

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('spa-run-test-' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    $resolved = Invoke-SpaRun -Arguments @('-Task', 'P2T4-REVIEW', '-DryRun')
    Assert-True ($resolved.Code -eq 0) 'known P2T4-REVIEW route resolves in dry-run mode'
    Assert-Match $resolved.Output 'ACTION\s+REVIEW' 'P2T4-REVIEW resolves as a review action'
    Assert-Match $resolved.Output 'MODEL\s+deepseek-v4-pro' 'P2T4-REVIEW resolves to DeepSeek V4 Pro'
    Assert-Match $resolved.Output 'PROVIDER\s+deepseek' 'P2T4-REVIEW resolves to the DeepSeek provider'
    Assert-Match $resolved.Output 'REASONING\s+high' 'P2T4-REVIEW resolves to high reasoning'
    Assert-Match $resolved.Output 'COMMAND\s+.*--profile deepseek.*--model deepseek-v4-pro.*model_provider' 'dry run displays the deterministic command construction'
    Assert-Match $resolved.Output 'COMMAND\s+.*model_reasoning_effort="high".*--ask-for-approval never.*--sandbox read-only.*-C C:\\GitHub\\backendtest.*exec --ephemeral --color never - < .*P2T4-REVIEW\.txt' 'dry run displays every safety-critical command argument'
    Assert-NotContains $resolved.Output $secretSentinel 'dry-run output does not disclose provider secrets'
    Assert-Match $resolved.Output '(?ms)^TASK\s+P2T4-REVIEW\r?$.*^ACTION\s+REVIEW\r?$.*^RESULT\s+DRY RUN\r?$.*^MODEL\s+deepseek-v4-pro\r?$.*^REASONING\s+high\r?$' 'successful dry-run summary contains the known route outcome'
    Assert-FinalSummary $resolved.Output 'SPA TASK SUMMARY' 'successful dry-run prints exactly one task summary at the bottom'

    $unknown = Invoke-SpaRun -Arguments @('-Task', 'DOES-NOT-EXIST', '-DryRun')
    Assert-True ($unknown.Code -ne 0) 'unknown task ID fails closed'
    Assert-Match $unknown.Output 'Unknown SPA task ID' 'unknown task failure is precise'
    Assert-Match $unknown.Output '(?ms)^TASK\s+DOES-NOT-EXIST\r?$.*^RESULT\s+STOPPED\r?$.*^REASON\s+Unknown SPA task ID.*^LAST SAFE\s+NOT AVAILABLE\r?$.*^REMOTE\s+NOT AVAILABLE\r?$.*^NEXT\s+Resolve failure and rerun spa-run DOES-NOT-EXIST\r?$' 'controlled failure summary contains the required recovery fields'
    Assert-FinalSummary $unknown.Output 'SPA TASK SUMMARY' 'controlled failure prints exactly one task summary at the bottom'

    $missingPromptManifest = Join-Path $tempRoot 'missing-prompt.psd1'
    @'
@{
    Version = 1
    Routes = @{
        'MISSING-PROMPT' = @{
            Action = 'IMPLEMENT'; Provider = 'openai'; Model = 'gpt-5.6-sol'; Reasoning = 'high'
            Sandbox = 'read-only'; Repository = 'Backend'; RepositoryPath = 'C:\GitHub\backendtest'
            Branch = 'feature/investment-operating-system-m1'; Prompt = 'prompts\absent.txt'
            Command = 'codex'; Profile = ''; Enabled = $true; IndependentReview = $false
        }
    }
}
'@ | Set-Content -LiteralPath $missingPromptManifest
    $liveOverride = Invoke-SpaRun -Arguments @('-Task', 'P2T4-REVIEW', '-DryRun', '-RoutingPath', $missingPromptManifest)
    Assert-True ($liveOverride.Code -ne 0) 'routing overrides are unavailable outside explicit test mode'
    Assert-Match $liveOverride.Output 'test-only overrides require both -TestMode and -DryRun' 'live override rejection is precise'

    $missingPrompt = Invoke-SpaRun -Arguments @('-Task', 'MISSING-PROMPT', '-DryRun', '-TestMode', '-RoutingPath', $missingPromptManifest)
    Assert-True ($missingPrompt.Code -ne 0) 'missing prompt fails closed'
    Assert-Match $missingPrompt.Output 'Prompt file is missing' 'missing prompt failure names the cause'

    $conflictPromptDir = Join-Path $tempRoot 'prompts'
    New-Item -ItemType Directory -Path $conflictPromptDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $conflictPromptDir 'conflict.txt') -Value 'review without edits'
    $conflictManifest = Join-Path $tempRoot 'conflict.psd1'
    @'
@{
    Version = 1
    Routes = @{
        'CONFLICT-REVIEW' = @{
            Action = 'REVIEW'; Provider = 'openai'; Model = 'gpt-5.6-sol'; Reasoning = 'high'
            Sandbox = 'read-only'; Repository = 'Backend'; RepositoryPath = 'C:\GitHub\backendtest'
            Branch = 'feature/investment-operating-system-m1'; Prompt = 'prompts\conflict.txt'
            Command = 'codex'; Profile = ''; Enabled = $true; IndependentReview = $true
            Implementer = @{ Provider = 'openai'; Model = 'gpt-5.6-sol' }
        }
    }
}
'@ | Set-Content -LiteralPath $conflictManifest
    $conflict = Invoke-SpaRun -Arguments @('-Task', 'CONFLICT-REVIEW', '-DryRun', '-TestMode', '-RoutingPath', $conflictManifest)
    Assert-True ($conflict.Code -ne 0) 'same-model implementation and review conflict fails closed'
    Assert-Match $conflict.Output 'independent review conflict' 'same-model conflict failure is precise'

    $workingRepo = Join-Path $tempRoot 'backend'
    $bareRemote = Join-Path $tempRoot 'backend-remote.git'
    $markerPath = Join-Path $tempRoot 'deps.fingerprint'
    $modelOutput = Join-Path $tempRoot 'model-output.txt'
    Initialize-TestGitRepo -WorkingRepo $workingRepo -BareRemote $bareRemote -Branch $expectedBranch
    Set-Content -LiteralPath $markerPath -Value (Get-TestFingerprint -Root $workingRepo) -NoNewline
    @(
        'MODEL_CHECK_OK'
        'model: deepseek-v4-pro'
        'provider: deepseek'
        'reasoning effort: high'
        'approval: never'
        'sandbox: read-only'
    ) | Set-Content -LiteralPath $modelOutput

    $preflightArgs = @(
        '-Task', 'P2T4-REVIEW', '-DryRun', '-TestMode', '-TestModelCheckOutputPath', $modelOutput,
        '-BackendPath', $workingRepo, '-DependencyMarkerPath', $markerPath
    )
    $realGit = (Get-Command git -CommandType Application).Source
    $gitShimDir = Join-Path $tempRoot 'git-noninteractive-shim'
    $gitEnvironmentMarker = Join-Path $tempRoot 'git-noninteractive-environment.txt'
    New-Item -ItemType Directory -Path $gitShimDir -Force | Out-Null
    @"
@echo off
if not "%GIT_PAGER%"=="cat" exit /b 91
if not "%PAGER%"=="cat" exit /b 92
if not "%GIT_TERMINAL_PROMPT%"=="0" exit /b 93
echo protected>"$gitEnvironmentMarker"
"$realGit" %*
exit /b %ERRORLEVEL%
"@ | Set-Content -LiteralPath (Join-Path $gitShimDir 'git.cmd') -Encoding ASCII
    $previousPath = $env:PATH
    $env:PATH = $gitShimDir + [System.IO.Path]::PathSeparator + $previousPath
    try {
        $ready = Invoke-SpaRun -Arguments $preflightArgs
    }
    finally {
        $env:PATH = $previousPath
    }
    Assert-True ($ready.Code -eq 0) 'matching route and clean repository pass dry-run preflight'
    Assert-Match $ready.Output 'READY\s+YES' 'matching preflight reports READY YES'
    Assert-True (Test-Path -LiteralPath $gitEnvironmentMarker -PathType Leaf) 'runner establishes non-interactive Git pager and prompt environment for child checks'

    $taskOutput = Join-Path $tempRoot 'task-output.txt'
    @('Review complete.', 'SAFE') | Set-Content -LiteralPath $taskOutput
    $validVerdict = Invoke-SpaRun -Arguments ($preflightArgs + @('-TestTaskOutputPath', $taskOutput))
    Assert-True ($validVerdict.Code -eq 0) 'one final review verdict is accepted'
    Assert-Match $validVerdict.Output 'VERDICT\s+SAFE' 'accepted review verdict is reported clearly'
    Assert-Match $validVerdict.Output '(?ms)^TASK\s+P2T4-REVIEW\r?$.*^RESULT\s+SAFE\r?$' 'successful task summary reports the validated verdict'
    Assert-FinalSummary $validVerdict.Output 'SPA TASK SUMMARY' 'successful task result prints exactly one task summary at the bottom'

    @('SAFE', 'SAFE') | Set-Content -LiteralPath $taskOutput
    $duplicateVerdict = Invoke-SpaRun -Arguments ($preflightArgs + @('-TestTaskOutputPath', $taskOutput))
    Assert-True ($duplicateVerdict.Code -ne 0) 'duplicate identical verdicts fail closed'
    Assert-Match $duplicateVerdict.Output 'exactly one recognized verdict' 'duplicate verdict rejection is precise'

    @('SAFE', 'Trailing prose') | Set-Content -LiteralPath $taskOutput
    $nonFinalVerdict = Invoke-SpaRun -Arguments ($preflightArgs + @('-TestTaskOutputPath', $taskOutput))
    Assert-True ($nonFinalVerdict.Code -ne 0) 'a verdict that is not the final nonblank line fails closed'
    Assert-Match $nonFinalVerdict.Output 'final nonblank line' 'non-final verdict rejection is precise'

    @(
        'MODEL_CHECK_OK'
        'model: gpt-5.6-sol'
        'provider: openai'
        'reasoning effort: high'
        'approval: never'
        'sandbox: read-only'
    ) | Set-Content -LiteralPath $modelOutput
    $mismatch = Invoke-SpaRun -Arguments $preflightArgs
    Assert-True ($mismatch.Code -ne 0) 'actual model mismatch fails closed'
    Assert-Match $mismatch.Output 'MODEL\s+FAIL' 'model mismatch is reported by preflight'

    @(
        'MODEL_CHECK_OK'
        'model: deepseek-v4-pro'
        'provider: openai'
        'reasoning effort: high'
        'approval: never'
        'sandbox: read-only'
    ) | Set-Content -LiteralPath $modelOutput
    $providerMismatch = Invoke-SpaRun -Arguments $preflightArgs
    Assert-True ($providerMismatch.Code -ne 0) 'actual provider mismatch fails closed independently'
    Assert-Match $providerMismatch.Output 'PROVIDER\s+FAIL' 'provider mismatch is reported by preflight'

    @(
        'MODEL_CHECK_OK'
        'model: deepseek-v4-pro'
        'provider: deepseek'
        'reasoning effort: low'
        'approval: never'
        'sandbox: read-only'
    ) | Set-Content -LiteralPath $modelOutput
    $reasoningMismatch = Invoke-SpaRun -Arguments $preflightArgs
    Assert-True ($reasoningMismatch.Code -ne 0) 'actual reasoning mismatch fails closed independently'
    Assert-Match $reasoningMismatch.Output 'REASONING\s+FAIL' 'reasoning mismatch is reported by preflight'

    @(
        'MODEL_CHECK_OK'
        'model: deepseek-v4-pro'
        'provider: deepseek'
        'reasoning effort: high'
        'sandbox: read-only'
    ) | Set-Content -LiteralPath $modelOutput
    $missingApproval = Invoke-SpaRun -Arguments $preflightArgs
    Assert-True ($missingApproval.Code -ne 0) 'missing actual approval metadata fails closed'
    Assert-Match $missingApproval.Output 'APPROVAL\s+FAIL.*actual=unavailable' 'missing approval metadata is reported'

    @(
        'MODEL_CHECK_OK'
        'model: deepseek-v4-pro'
        'provider: deepseek'
        'reasoning effort: high'
        'approval: never'
    ) | Set-Content -LiteralPath $modelOutput
    $missingSandbox = Invoke-SpaRun -Arguments $preflightArgs
    Assert-True ($missingSandbox.Code -ne 0) 'missing actual sandbox metadata fails closed'
    Assert-Match $missingSandbox.Output 'SANDBOX\s+FAIL.*actual=unavailable' 'missing sandbox metadata is reported'

    @(
        'MODEL_CHECK_OK'
        'model: deepseek-v4-pro'
        'provider: deepseek'
        'reasoning effort: high'
        'approval: on-request'
        'sandbox: read-only'
    ) | Set-Content -LiteralPath $modelOutput
    $approvalMismatch = Invoke-SpaRun -Arguments $preflightArgs
    Assert-True ($approvalMismatch.Code -ne 0) 'actual approval mismatch fails closed'
    Assert-Match $approvalMismatch.Output 'APPROVAL\s+FAIL' 'approval mismatch is reported'

    @(
        'MODEL_CHECK_OK'
        'model: deepseek-v4-pro'
        'provider: deepseek'
        'reasoning effort: high'
        'approval: never'
        'sandbox: workspace-write'
    ) | Set-Content -LiteralPath $modelOutput
    $sandboxMismatch = Invoke-SpaRun -Arguments $preflightArgs
    Assert-True ($sandboxMismatch.Code -ne 0) 'actual sandbox mismatch fails closed'
    Assert-Match $sandboxMismatch.Output 'SANDBOX\s+FAIL' 'sandbox mismatch is reported'

    @(
        'MODEL_CHECK_OK'
        'model: deepseek-v4-pro'
        'provider: deepseek'
        'reasoning effort: high'
        'approval: never'
        'sandbox: read-only'
    ) | Set-Content -LiteralPath $modelOutput
    Set-Content -LiteralPath (Join-Path $workingRepo 'dirty.txt') -Value 'dirty' -NoNewline
    $dirty = Invoke-SpaRun -Arguments $preflightArgs
    Assert-True ($dirty.Code -ne 0) 'dirty worktree fails closed'
    Assert-Match $dirty.Output 'WORKTREE\s+FAIL\s+DIRTY' 'dirty worktree failure is reported'
    Remove-Item -LiteralPath (Join-Path $workingRepo 'dirty.txt') -Force

    git -C $workingRepo checkout -q -b wrong-branch
    git -C $workingRepo push -q -u origin wrong-branch
    $wrongBranch = Invoke-SpaRun -Arguments $preflightArgs
    Assert-True ($wrongBranch.Code -ne 0) 'wrong branch fails closed'
    Assert-Match $wrongBranch.Output 'BRANCH\s+FAIL\s+wrong-branch' 'wrong branch failure is reported'

    $emptyCodexRoot = Join-Path $tempRoot 'empty-codex-home'
    New-Item -ItemType Directory -Path $emptyCodexRoot -Force | Out-Null
    $previousCodexHome = [System.Environment]::GetEnvironmentVariable('CODEX_HOME', 'Process')
    [System.Environment]::SetEnvironmentVariable('CODEX_HOME', $emptyCodexRoot, 'Process')
    try {
        $missingProfile = Invoke-SpaRun -Arguments @('-Task', 'P2T4-REVIEW')
        Assert-True ($missingProfile.Code -ne 0) 'missing DeepSeek profile aborts a live run'
        Assert-Match $missingProfile.Output 'Refusing to fall back to the default provider' 'missing profile failure explicitly rejects fallback'
        Assert-True (-not [regex]::IsMatch($missingProfile.Output, '(?im)^Starting\.\.\.$')) 'missing profile aborts before task invocation'
    }
    finally {
        [System.Environment]::SetEnvironmentVariable('CODEX_HOME', $previousCodexHome, 'Process')
    }
}
finally {
    [System.Environment]::SetEnvironmentVariable('DEEPSEEK_API_KEY', $previousSecret, 'Process')
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ''
if ($failures.Count -eq 0) {
    Write-Host 'GREEN: all spa-run tests passed.'
    exit 0
}

Write-Host "RED: $($failures.Count) spa-run test(s) failed."
$failures | ForEach-Object { Write-Host " - $_" }
exit 1
