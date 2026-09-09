[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$devTools = Join-Path $repoRoot 'dev-tools'
$spaRun = Join-Path $devTools 'spa-run.ps1'
$stateTools = Join-Path $devTools 'm1-state.ps1'
$routingPath = Join-Path $devTools 'm1-model-routing.psd1'
$reviewPrompt = Join-Path $devTools 'prompts\P2T4-REVIEW.txt'
$reviewPrompt9 = Join-Path $devTools 'prompts\P2T9-REVIEW.txt'
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

function Invoke-SpaRunTolerant {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $spaRun @Arguments 2>&1 | Out-String
        return [pscustomobject]@{
            Code = $LASTEXITCODE
            Output = $output
        }
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
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

foreach ($path in @($spaRun, $stateTools, $routingPath, $reviewPrompt, $reviewPrompt9)) {
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "required runner artifact exists: $path"
}

if ($failures.Count -gt 0) {
    Write-Host ''
    Write-Host "RED: $($failures.Count) runner artifact(s) are missing."
    exit 1
}

. $stateTools

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

    $p2t9Review = Invoke-SpaRun -Arguments @('-Task', 'P2T9-REVIEW', '-DryRun')
    Assert-True ($p2t9Review.Code -eq 0) 'known P2T9-REVIEW route resolves in dry-run mode'
    Assert-Match $p2t9Review.Output 'ACTION\s+REVIEW' 'P2T9-REVIEW resolves as a review action'
    Assert-Match $p2t9Review.Output 'MODEL\s+gpt-5\.6-sol' 'P2T9-REVIEW resolves to the configured SOL reviewer'
    Assert-Match $p2t9Review.Output 'PROVIDER\s+openai' 'P2T9-REVIEW resolves to the OpenAI provider'
    Assert-Match $p2t9Review.Output 'REASONING\s+high' 'P2T9-REVIEW resolves to high reasoning'
    Assert-Match $p2t9Review.Output 'COMMAND\s+.*--model gpt-5\.6-sol.*model_provider="openai".*--sandbox read-only.*-C C:\\GitHub\\backendtest.*exec --ephemeral --color never - < .*P2T9-REVIEW\.txt' 'P2T9-REVIEW dry run displays the independent review command'
    Assert-Match $p2t9Review.Output '(?ms)^TASK\s+P2T9-REVIEW\r?$.*^ACTION\s+REVIEW\r?$.*^RESULT\s+DRY RUN\r?$.*^MODEL\s+gpt-5\.6-sol\r?$.*^REASONING\s+high\r?$' 'successful P2T9-REVIEW dry-run summary contains the known route outcome'
    Assert-FinalSummary $p2t9Review.Output 'SPA TASK SUMMARY' 'successful P2T9-REVIEW dry-run prints exactly one task summary at the bottom'

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

    $workspacePreflightArgs = @(
        '-Task', 'P2T5', '-DryRun', '-TestMode', '-TestModelCheckOutputPath', $modelOutput,
        '-BackendPath', $workingRepo, '-DependencyMarkerPath', $markerPath
    )

    @(
        'MODEL_CHECK_OK'
        'model: deepseek-v4-flash'
        'provider: deepseek'
        'reasoning effort: high'
        'approval: never'
        'sandbox: workspace-write'
    ) | Set-Content -LiteralPath $modelOutput
    $workspaceReady = Invoke-SpaRun -Arguments $workspacePreflightArgs
    Assert-True ($workspaceReady.Code -eq 0) 'workspace-write route passes preflight when the effective sandbox is workspace-write'
    Assert-Match $workspaceReady.Output 'SANDBOX\s+workspace-write' 'workspace-write preflight reports the route effective sandbox'
    Assert-Match $workspaceReady.Output 'READY\s+YES' 'workspace-write preflight reports READY YES'

    @(
        'MODEL_CHECK_OK'
        'model: deepseek-v4-flash'
        'provider: deepseek'
        'reasoning effort: high'
        'approval: never'
        'sandbox: workspace-write [workdir, /tmp, $TMPDIR]'
    ) | Set-Content -LiteralPath $modelOutput
    $workspaceAnnotatedReady = Invoke-SpaRun -Arguments $workspacePreflightArgs
    Assert-True ($workspaceAnnotatedReady.Code -eq 0) 'workspace-write route passes preflight when Codex annotates the effective sandbox with writable roots'
    Assert-Match $workspaceAnnotatedReady.Output 'SANDBOX\s+workspace-write' 'annotated workspace-write preflight normalizes the sandbox value'
    Assert-Match $workspaceAnnotatedReady.Output 'READY\s+YES' 'annotated workspace-write preflight reports READY YES'

    @(
        'MODEL_CHECK_OK'
        'model: deepseek-v4-flash'
        'provider: deepseek'
        'reasoning effort: high'
        'approval: never'
        'sandbox: read-only'
    ) | Set-Content -LiteralPath $modelOutput
    $workspaceMismatch = Invoke-SpaRun -Arguments $workspacePreflightArgs
    Assert-True ($workspaceMismatch.Code -ne 0) 'workspace-write route fails closed when the effective sandbox is read-only'
    Assert-Match $workspaceMismatch.Output 'SANDBOX\s+FAIL expected=workspace-write actual=read-only' 'effective read-only sandbox mismatch is precise'

    $workspaceGuardMismatches = @(
        @{
            Label = 'MODEL'
            Lines = @('MODEL_CHECK_OK', 'model: gpt-5.6-sol', 'provider: deepseek', 'reasoning effort: high', 'approval: never', 'sandbox: workspace-write')
        }
        @{
            Label = 'PROVIDER'
            Lines = @('MODEL_CHECK_OK', 'model: deepseek-v4-flash', 'provider: openai', 'reasoning effort: high', 'approval: never', 'sandbox: workspace-write')
        }
        @{
            Label = 'REASONING'
            Lines = @('MODEL_CHECK_OK', 'model: deepseek-v4-flash', 'provider: deepseek', 'reasoning effort: low', 'approval: never', 'sandbox: workspace-write')
        }
        @{
            Label = 'APPROVAL'
            Lines = @('MODEL_CHECK_OK', 'model: deepseek-v4-flash', 'provider: deepseek', 'reasoning effort: high', 'approval: on-request', 'sandbox: workspace-write')
        }
    )
    foreach ($guard in $workspaceGuardMismatches) {
        $guard.Lines | Set-Content -LiteralPath $modelOutput
        $guardRun = Invoke-SpaRun -Arguments $workspacePreflightArgs
        Assert-True ($guardRun.Code -ne 0) "$($guard.Label) mismatch still fails closed on a workspace-write route"
        Assert-Match $guardRun.Output ($guard.Label + '\s+FAIL') "$($guard.Label) mismatch is still reported on a workspace-write route"
    }

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
    git -C $workingRepo checkout -q $expectedBranch

    $nativeCodexHome = Join-Path $tempRoot 'native-codex-home'
    New-Item -ItemType Directory -Path $nativeCodexHome -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $nativeCodexHome 'deepseek.config.toml') -Value 'fake profile' -NoNewline

    $nativeCodexShimDir = Join-Path $tempRoot 'native-codex-shim'
    New-Item -ItemType Directory -Path $nativeCodexShimDir -Force | Out-Null
    @'
@echo off
setlocal EnableExtensions
set "SPA_RUN_TEST_TASK=0"
set "SPA_RUN_TEST_OUTPUT="
set "SPA_RUN_TEST_MODEL=deepseek-v4-pro"
set "SPA_RUN_TEST_SANDBOX=read-only"

:parse
if "%~1"=="" goto run
if /I "%~1"=="--output-last-message" (
    set "SPA_RUN_TEST_TASK=1"
    if not "%~2"=="" set "SPA_RUN_TEST_OUTPUT=%~2"
    shift
)
if /I "%~1"=="--model" if not "%~2"=="" set "SPA_RUN_TEST_MODEL=%~2"
if /I "%~1"=="--sandbox" if not "%~2"=="" set "SPA_RUN_TEST_SANDBOX=%~2"
shift
goto parse

:run
if "%SPA_RUN_TEST_TASK%"=="0" (
    echo MODEL_CHECK_OK
    echo model: %SPA_RUN_TEST_MODEL%
    echo provider: deepseek
    echo reasoning effort: high
    echo approval: never
    echo sandbox: %SPA_RUN_TEST_SANDBOX%
    exit /b 0
)
echo NATIVE_STDOUT_HEALTHY
echo NATIVE_STDERR_HEALTHY 1>&2
if /I "%SPA_RUN_TEST_NATIVE_EXIT%"=="fail" exit /b 7
if defined SPA_RUN_TEST_OUTPUT (
    > "%SPA_RUN_TEST_OUTPUT%" echo Review complete.
    >> "%SPA_RUN_TEST_OUTPUT%" echo SAFE
)
exit /b 0
'@ | Set-Content -LiteralPath (Join-Path $nativeCodexShimDir 'codex.cmd') -Encoding ASCII

    $previousNativePath = $env:PATH
    $previousNativeCodexHome = [System.Environment]::GetEnvironmentVariable('CODEX_HOME', 'Process')
    $previousNativeExit = [System.Environment]::GetEnvironmentVariable('SPA_RUN_TEST_NATIVE_EXIT', 'Process')
    $env:PATH = $nativeCodexShimDir + [System.IO.Path]::PathSeparator + $previousNativePath
    [System.Environment]::SetEnvironmentVariable('CODEX_HOME', $nativeCodexHome, 'Process')
    [System.Environment]::SetEnvironmentVariable('SPA_RUN_TEST_NATIVE_EXIT', $null, 'Process')
    try {
        $nativeLiveArgs = @(
            '-Task', 'P2T4-REVIEW',
            '-TestMode', '-AllowTestExecution',
            '-BackendPath', $workingRepo,
            '-DependencyMarkerPath', $markerPath
        )
        $nativeStderrSuccess = Invoke-SpaRunTolerant -Arguments $nativeLiveArgs
        Assert-True ($nativeStderrSuccess.Code -eq 0) 'native child stderr and zero exit code are not treated as task failure'
        Assert-Match $nativeStderrSuccess.Output 'NATIVE_STDOUT_HEALTHY' 'native child stdout is preserved as ordinary task output'
        Assert-Match $nativeStderrSuccess.Output 'NATIVE_STDERR_HEALTHY' 'native child stderr is preserved as ordinary task output'
        Assert-NotContains $nativeStderrSuccess.Output 'NativeCommandError' 'native child stderr is not rendered as a PowerShell red terminating error'
        Assert-NotContains $nativeStderrSuccess.Output '+ CategoryInfo' 'native child stderr does not leak PowerShell error formatting'
        Assert-Match $nativeStderrSuccess.Output 'VERDICT\s+SAFE' 'healthy native child result is accepted by exit code'

        [System.Environment]::SetEnvironmentVariable('SPA_RUN_TEST_NATIVE_EXIT', 'fail', 'Process')
        $nativeStderrFailure = Invoke-SpaRunTolerant -Arguments $nativeLiveArgs
        Assert-True ($nativeStderrFailure.Code -ne 0) 'nonzero native child exit code still fails closed'
        Assert-Match $nativeStderrFailure.Output 'Task CLI exited with code 7' 'nonzero native child failure reports the authoritative exit code'
        Assert-Match $nativeStderrFailure.Output 'NATIVE_STDERR_HEALTHY' 'native child stderr is preserved before a nonzero exit'
        Assert-NotContains $nativeStderrFailure.Output 'NativeCommandError' 'nonzero native child stderr is not rendered as a PowerShell red terminating error'

        [System.Environment]::SetEnvironmentVariable('SPA_RUN_TEST_NATIVE_EXIT', $null, 'Process')
        $workspaceLiveArgs = @(
            '-Task', 'P2T5',
            '-TestMode', '-AllowTestExecution',
            '-BackendPath', $workingRepo,
            '-DependencyMarkerPath', $markerPath
        )
        $workspaceNative = Invoke-SpaRunTolerant -Arguments $workspaceLiveArgs
        Assert-True ($workspaceNative.Code -eq 0) 'workspace-write route passes live preflight when the model CLI reports the requested effective sandbox'
        Assert-Match $workspaceNative.Output 'SANDBOX\s+workspace-write' 'live workspace-write preflight reports the route effective sandbox'
        Assert-Match $workspaceNative.Output 'RESULT\s+IMPLEMENTED' 'simulated workspace-write implementation completes after effective-sandbox preflight'
    }
    finally {
        $env:PATH = $previousNativePath
        [System.Environment]::SetEnvironmentVariable('CODEX_HOME', $previousNativeCodexHome, 'Process')
        [System.Environment]::SetEnvironmentVariable('SPA_RUN_TEST_NATIVE_EXIT', $previousNativeExit, 'Process')
    }

    $trackedChild = Join-Path $tempRoot 'tracked-child.ps1'
    @'
Write-Output 'CHILD_RESULT_LINE_ONE'
Write-Output 'CHILD_RESULT_LINE_TWO'
Write-Output 'CHILD_RESULT_LINE_THREE'
'@ | Set-Content -LiteralPath $trackedChild -Encoding ASCII
    $trackedHealthRoot = Join-Path $tempRoot 'tracked-health'
    New-Item -ItemType Directory -Path $trackedHealthRoot -Force | Out-Null

    # The real (non-dry-run) branch of Invoke-M1ChildRoute returns Invoke-SpaTrackedProcess
    # directly, so exercise that native boundary with a fake child that emits several lines.
    $childResult = Invoke-SpaTrackedProcess `
        -FilePath (Get-Command powershell.exe -CommandType Application).Source `
        -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $trackedChild) `
        -WorkingDirectory $tempRoot `
        -HealthRoot $trackedHealthRoot `
        -Task 'P2T5' `
        -Phase 'IMPLEMENT' `
        -Model 'deepseek-v4-flash' `
        -Provider 'deepseek' `
        -LastSafe 'backend=probe frontend=probe' `
        -HeartbeatSeconds 1

    $childItems = @($childResult)
    Assert-True ($childItems.Count -eq 1) 'real tracked child route returns exactly one structured result object'
    Assert-True (($childItems[0].Code -is [int]) -and -not [string]::IsNullOrWhiteSpace([string]$childItems[0].Output)) 'real tracked child result exposes Code and Output'
    Assert-True (($childItems[0].Output -match 'CHILD_RESULT_LINE_ONE') -and
        ($childItems[0].Output -match 'CHILD_RESULT_LINE_TWO') -and
        ($childItems[0].Output -match 'CHILD_RESULT_LINE_THREE')) 'multiple live child output lines remain captured for the human'

    Assert-True ($null -ne $childItems[0].PSObject.Properties['DisplayOutput']) 'real tracked child result exposes DisplayOutput'
    $m1CallerError = ''
    $callerDisplayOutput = $null
    try {
        if ($childItems[0].DisplayOutput) { $callerDisplayOutput = $childItems[0].DisplayOutput }
    }
    catch {
        $m1CallerError = $_.Exception.Message
    }
    Assert-True ([string]::IsNullOrWhiteSpace($m1CallerError)) ('M1 caller reads DisplayOutput without StrictMode property failure' + $(if ($m1CallerError) { " (error: $m1CallerError)" } else { '' }))
    Assert-True (($callerDisplayOutput -match 'CHILD_RESULT_LINE_ONE') -and
        ($callerDisplayOutput -match 'CHILD_RESULT_LINE_TWO') -and
        ($callerDisplayOutput -match 'CHILD_RESULT_LINE_THREE')) 'M1 caller displays every captured child line through DisplayOutput'

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
