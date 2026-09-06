[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$devTools = Join-Path $repoRoot 'dev-tools'
$spaRun = Join-Path $devTools 'spa-run.ps1'
$stateTools = Join-Path $devTools 'm1-state.ps1'
$autoDebugTools = Join-Path $devTools 'm1-auto-debug.ps1'
$debugLauncher = Join-Path $devTools 'spa-auto-debug-launch.ps1'
$routingPath = Join-Path $devTools 'm1-model-routing.psd1'
$expectedBranch = 'feature/investment-operating-system-m1'
$failures = New-Object System.Collections.Generic.List[string]

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if ($Condition) { Write-Host "PASS: $Message" }
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

    Assert-True ($Text.IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) $Message
}

function Invoke-SpaRunTolerant {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $spaRun @Arguments 2>&1 | Out-String
        return [pscustomobject]@{ Code = $LASTEXITCODE; Output = $output }
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

function Invoke-Git {
    param([string]$Path, [string[]]$Arguments)
    $output = & git -C $Path @Arguments 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "git failed in ${Path}: git $($Arguments -join ' ')`n$output"
    }
    return $output.Trim()
}

function Initialize-RemotePair {
    param([string]$Root, [string]$Name)

    $remote = Join-Path $Root ($Name + '-remote.git')
    $office = Join-Path $Root ($Name + '-office')
    $homeClone = Join-Path $Root ($Name + '-home')
    & git init --bare -q $remote
    if ($LASTEXITCODE -ne 0) { throw "git init --bare failed for $remote" }
    & git init -q $office
    if ($LASTEXITCODE -ne 0) { throw "git init failed for $office" }
    Invoke-Git $office @('config', 'user.email', 'spa-auto-debug-test@example.com') | Out-Null
    Invoke-Git $office @('config', 'user.name', 'SPA Auto Debug Test') | Out-Null
    Set-Content -LiteralPath (Join-Path $office 'README.md') -Value 'initial' -NoNewline
    Invoke-Git $office @('add', '-A') | Out-Null
    Invoke-Git $office @('commit', '-q', '-m', 'initial') | Out-Null
    Invoke-Git $office @('branch', '-M', $expectedBranch) | Out-Null
    Invoke-Git $office @('remote', 'add', 'origin', $remote) | Out-Null
    Invoke-Git $office @('push', '-q', '-u', 'origin', $expectedBranch) | Out-Null
    & git clone -q --branch $expectedBranch $remote $homeClone
    if ($LASTEXITCODE -ne 0) { throw "git clone failed for $homeClone" }
    Invoke-Git $homeClone @('config', 'user.email', 'spa-auto-debug-test@example.com') | Out-Null
    Invoke-Git $homeClone @('config', 'user.name', 'SPA Auto Debug Test') | Out-Null
    return [pscustomobject]@{ Remote = $remote; Office = $office; Home = $homeClone; Sha = (Invoke-Git $homeClone @('rev-parse', 'HEAD')) }
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

function New-TestTask {
    param(
        [string]$Id,
        [string]$Status,
        [string]$BackendSha,
        [string]$FrontendSha
    )

    return [ordered]@{
        id = $Id
        action = 'IMPLEMENT'
        status = $Status
        implementationProvider = 'deepseek'
        implementationModel = 'deepseek-v4-flash'
        reviewerProvider = $null
        reviewerModel = $null
        reviewRoute = $null
        remediationRoute = $Id
        lastVerifiedBackendSha = $BackendSha
        lastVerifiedFrontendSha = $FrontendSha
        implementationCommitSha = $BackendSha
        remediationCommitSha = $null
        lastSuccessfulReviewVerdict = $null
        remediationAttempts = 0
        evidence = [ordered]@{
            implementationSucceeded = $false
            testsSucceeded = $false
            reviewRequired = $false
            reviewSucceeded = $false
            relevantCommitsPushed = $false
        }
        updatedUtc = '2026-09-07T00:00:00Z'
    }
}

function New-TestState {
    param([object[]]$Tasks)

    return [ordered]@{
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

function New-AdScenario {
    param([string]$Root, [string]$Name)

    $backend = Initialize-RemotePair -Root $Root -Name ($Name + '-backend')
    $frontend = Initialize-RemotePair -Root $Root -Name ($Name + '-frontend')
    Set-Content -LiteralPath (Join-Path $backend.Home 'requirements.txt') -Value 'pytest==8.0.0' -NoNewline
    Invoke-Git $backend.Home @('add', '-A') | Out-Null
    Invoke-Git $backend.Home @('commit', '-q', '-m', 'add backend manifest') | Out-Null
    Invoke-Git $backend.Home @('push', '-q', 'origin', $expectedBranch) | Out-Null
    $marker = Join-Path $Root ($Name + '-deps.fingerprint')
    Set-Content -LiteralPath $marker -Value (Get-TestFingerprint -Root $backend.Home) -NoNewline

    $task = New-TestTask -Id 'P2T5' -Status 'RUNNING_LOCAL' -BackendSha $null -FrontendSha $null
    $task.activeRoute = 'P2T5'
    $task.updatedUtc = '2026-09-07T08:00:00Z'
    $state = New-TestState @($task)
    $statePath = Join-Path $frontend.Home 'state.json'
    Write-M1StateAtomic -State $state -Path $statePath
    Invoke-Git $frontend.Home @('add', '-A') | Out-Null
    Invoke-Git $frontend.Home @('commit', '-q', '-m', 'checkpoint P2T5 RUNNING_LOCAL') | Out-Null
    Invoke-Git $frontend.Home @('push', '-q', 'origin', $expectedBranch) | Out-Null

    return [pscustomobject]@{
        Backend = $backend
        Frontend = $frontend
        StatePath = $statePath
        MarkerPath = $marker
    }
}

function Set-AdEnvironment {
    param([hashtable]$Values)
    foreach ($key in $Values.Keys) {
        if ($null -eq $Values[$key]) {
            [System.Environment]::SetEnvironmentVariable([string]$key, $null, 'Process')
        }
        else {
            [System.Environment]::SetEnvironmentVariable([string]$key, [string]$Values[$key], 'Process')
        }
    }
}

function Write-SpaFakeCodexTooling {
    param([string]$Directory)

    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    $sourceFile = Join-Path $PSScriptRoot 'spa-fake-codex-source.cs'
    $source = [System.IO.File]::ReadAllText($sourceFile)
    $fakeExe = Join-Path $Directory 'codex.exe'
    Add-Type -TypeDefinition $source -Language CSharp -OutputAssembly $fakeExe -OutputType ConsoleApplication -ErrorAction Stop | Out-Null
    if (-not (Test-Path -LiteralPath $fakeExe -PathType Leaf)) {
        throw "Fake codex.exe was not produced at $fakeExe"
    }
}
foreach ($path in @($spaRun, $stateTools, $autoDebugTools, $debugLauncher, $routingPath)) {
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "required auto-debug artifact exists: $path"
}

if ($failures.Count -gt 0) {
    Write-Host ''
    Write-Host "RED: $($failures.Count) auto-debug artifact(s) are missing."
    exit 1
}

. $stateTools
. $autoDebugTools

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('spa-auto-debug-test-' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    $fakeBackendRoot = Join-Path $tempRoot 'contract-backend'
    $fakeFrontendRoot = Join-Path $tempRoot 'contract-frontend'
    New-Item -ItemType Directory -Path $fakeBackendRoot, $fakeFrontendRoot -Force | Out-Null
    $longErrorLine = 'Traceback (most recent call last): line 3 / module crash: KEYSTONE_ERROR_NOT_MOCKED'
    $evidence = New-SpaAutoDebugEvidence `
        -TaskId 'P2T5' `
        -RouteId 'P2T5' `
        -PlanTaskTitle 'Make research revisions irreversible' `
        -Action 'IMPLEMENT' `
        -Phase 'IMPLEMENT' `
        -Repository 'Backend' `
        -RepositoryPath $fakeBackendRoot `
        -Command ('powershell.exe -File spa-run.ps1 -Task P2T5') `
        -ExitCode 7 `
        -Stdout ("child line one`r`n$longErrorLine") `
        -Stderr 'native stderr evidence' `
        -DisplayOutput ("child line one`r`n$longErrorLine") `
        -Model 'deepseek-v4-flash' `
        -Provider 'deepseek' `
        -Reasoning 'high' `
        -Sandbox 'workspace-write' `
        -LastSafe 'P2T4 COMPLETE' `
        -OriginalObjective ('SPA M1 IMPLEMENTATION TASK' + [System.Environment]::NewLine + 'Do the frozen P2T5 requirement.')
    $prompt = Format-SpaAutoDebugPrompt -Evidence $evidence -PrimaryRepositoryPath $fakeBackendRoot -SecondaryRepositoryPath $fakeFrontendRoot
    Assert-True (-not [string]::IsNullOrWhiteSpace($prompt)) 'auto-debug prompt is generated'
    Assert-Match $prompt 'SPA AUTO-DEBUG' 'generated prompt identifies the Auto-Debug contract'
    Assert-Match $prompt ([regex]::Escape($fakeBackendRoot)) 'generated prompt includes the primary repository'
    Assert-Match $prompt ([regex]::Escape($fakeFrontendRoot)) 'generated prompt includes the secondary repository'
    Assert-Match $prompt 'Both SPA repositories are in scope' 'generated prompt makes both repositories available for repair'
    Assert-NotContains $prompt 'ONLY the dev-tools directory' 'generated prompt does not contain an artificial dev-tools-only restriction'
    Assert-NotContains $prompt 'never modify the backend' 'generated prompt does not forbid backend product repairs'
    Assert-NotContains $prompt 'never modify the frontend' 'generated prompt does not forbid frontend repairs'
    Assert-Match $prompt 'force-push' 'generated prompt preserves the consequential boundary list'
    Assert-Match $prompt 'deploy to production' 'generated prompt preserves production boundaries'
    Assert-Match $prompt ([regex]::Escape($longErrorLine)) 'generated prompt does not truncate likely error lines'
    Assert-Match $prompt 'native stderr evidence' 'generated prompt preserves native stderr evidence'
    Assert-Match $prompt 'Do not invoke spa-run M1-REMAINING' 'generated prompt forbids debugger recursion into the supervisor'
    Assert-Match $prompt ([regex]::Escape('BEGIN CAPTURED STDOUT')) 'generated prompt delimits captured stdout'

    $contractEvidenceDir = Join-Path $tempRoot 'contract-evidence'
    $artifacts = Write-SpaAutoDebugArtifacts -EvidenceRoot $contractEvidenceDir -Evidence $evidence -Prompt $prompt -Cycle 1
    Assert-True (Test-Path -LiteralPath $artifacts.EvidenceFile -PathType Leaf) 'evidence JSON artifact is preserved'
    Assert-True (Test-Path -LiteralPath $artifacts.PromptFile -PathType Leaf) 'debugger prompt artifact is preserved'
    $parsedEvidence = Get-Content -Raw -LiteralPath $artifacts.EvidenceFile | ConvertFrom-Json
    Assert-True ([string]$parsedEvidence.taskId -eq 'P2T5') 'evidence JSON records the original task id'
    Assert-True ([int]$parsedEvidence.exitCode -eq 7) 'evidence JSON records the failed command exit code'
    Assert-True ([string]$parsedEvidence.stdout -match [regex]::Escape($longErrorLine)) 'evidence JSON preserves complete stdout without truncation'
    Assert-True ([string]$parsedEvidence.stderr -eq 'native stderr evidence') 'evidence JSON preserves complete stderr'
    Assert-True ([string]$parsedEvidence.displayOutput -eq 'child line one' + [System.Environment]::NewLine + $longErrorLine) 'evidence JSON preserves DisplayOutput'

    $codexShimDir = Join-Path $tempRoot 'codex-shim'
    Write-SpaFakeCodexTooling -Directory $codexShimDir

    # Scenario A: FAILURE -> AUTO-DEBUG -> RETRY. The fake child fails once, the
    # debugger commits a real repair in the other project, and the exact same
    # route is retried and succeeds.
    $scenarioA = New-AdScenario -Root $tempRoot -Name 'a'
    $aEvidenceRoot = Join-Path $tempRoot 'a-evidence'
    $aHealthRoot = Join-Path $tempRoot 'a-health'
    New-Item -ItemType Directory -Path $aEvidenceRoot, $aHealthRoot -Force | Out-Null
    $aGate = Join-Path $tempRoot 'a-gate.txt'
    Set-Content -LiteralPath $aGate -Value 'fail-A' -NoNewline
    $aCount = Join-Path $tempRoot 'a-debug-count.txt'
    $aAddDir = Join-Path $tempRoot 'a-add-dir.txt'
    Set-AdEnvironment @{
        SPA_AD_GATE_FILE = $aGate
        SPA_AD_COUNT_FILE = $aCount
        SPA_AD_ADD_DIR_CAPTURE = $aAddDir
        SPA_AD_GATE_1 = 'pass'
        SPA_AD_REPAIR_REPO = $scenarioA.Backend.Home
        SPA_AD_BRANCH = $expectedBranch
        SPA_AD_DEBUG_EXIT = $null
    }
    $oldPathA = $env:PATH
    $env:PATH = $codexShimDir + [System.IO.Path]::PathSeparator + $oldPathA
    try {
        $runA = Invoke-SpaRunTolerant @(
            '-Task', 'M1-REMAINING', '-TestMode', '-AllowTestExecution',
            '-StatePath', $scenarioA.StatePath, '-RoutingPath', $routingPath,
            '-BackendPath', $scenarioA.Backend.Home, '-FrontendPath', $scenarioA.Frontend.Home,
            '-DependencyMarkerPath', $scenarioA.MarkerPath,
            '-TestEvidenceRoot', $aEvidenceRoot, '-TestHealthPath', $aHealthRoot
        )
    }
    finally {
        $env:PATH = $oldPathA
    }
    Assert-True ($runA.Code -eq 0) 'A: retried original task succeeds and M1 continues'
    Assert-Match $runA.Output 'AUTO-DEBUG' 'A: supervisor announces Auto-Debug after child failure'
    Assert-Match $runA.Output 'AUTO-DEBUG\s+FIXED' 'A: session summary reports AUTO-DEBUG FIXED'
    Assert-Match $runA.Output 'DEBUG CYCLES\s+1' 'A: session summary reports one debug cycle'
    Assert-Match $runA.Output 'RETRIED\s+P2T5' 'A: session summary reports the retried original task'
    Assert-True ([int]([System.IO.File]::ReadAllText($aCount).Trim()) -eq 1) 'A: exactly one Auto-Debug cycle ran'
    Assert-Match $runA.Output 'ROUTE_FAILURE_SIGNATURE_ALPHA' 'A: child failure evidence remains visible to the human'
    Assert-True ([System.IO.File]::ReadAllText($aAddDir).Trim() -eq $scenarioA.Frontend.Home) 'A: debugger receives the other repository as an additional writable root'
    Assert-True (((@(Invoke-Git $scenarioA.Backend.Home @('log', '--oneline', '-3'))) -join "`n") -match 'test auto-debug repair') 'A: debugger committed a verified repair in the original project'
    $aState = Read-M1State -Path $scenarioA.StatePath
    Assert-True (([string]$aState.tasks[0].status).Equals('COMPLETE', [System.StringComparison]::OrdinalIgnoreCase)) 'A: original task completes only after the retried route succeeds'
    Assert-True (([string]$aState.repositories.backend.lastVerifiedSha) -ne $scenarioA.Backend.Sha) 'A: checkpoint records the repaired backend head'
    $aEvidenceFiles = @(Get-ChildItem -LiteralPath $aEvidenceRoot -File -Filter 'evidence-*.json')
    Assert-True ($aEvidenceFiles.Count -eq 1) 'A: complete failure evidence was preserved'
    if ($aEvidenceFiles.Count -eq 1) {
        $aEvidence = Get-Content -Raw -LiteralPath $aEvidenceFiles[0].FullName | ConvertFrom-Json
        Assert-True ([string]$aEvidence.taskId -eq 'P2T5') 'A: failure evidence records the original task id'
        Assert-True ([int]$aEvidence.exitCode -ne 0) 'A: failure evidence records the nonzero child exit'
        Assert-True ([string]$aEvidence.stdout -match 'ROUTE_FAILURE_SIGNATURE_ALPHA') 'A: failure evidence preserves the actual error output'
        Assert-True ([string]$aEvidence.model -eq 'deepseek-v4-flash') 'A: failure evidence records the original task model'
        Assert-True ([string]$aEvidence.repositoryPath -eq $scenarioA.Backend.Home) 'A: failure evidence records the original repository'
    }
    $aPromptFiles = @(Get-ChildItem -LiteralPath $aEvidenceRoot -File -Filter 'debug-prompt-*.txt')
    Assert-True ($aPromptFiles.Count -eq 1) 'A: debugger prompt artifact is preserved'
    if ($aPromptFiles.Count -eq 1) {
        $aPromptText = Get-Content -Raw -LiteralPath $aPromptFiles[0].FullName
        Assert-Match $aPromptText ([regex]::Escape($scenarioA.Frontend.Home)) 'A: real debugger prompt includes both repositories in scope'
        Assert-Match $aPromptText 'ROUTE_FAILURE_SIGNATURE_ALPHA' 'A: real debugger prompt receives untruncated child output'
    }
    Assert-True ([string]::IsNullOrWhiteSpace((Invoke-Git $scenarioA.Backend.Home @('status', '--porcelain=v1')))) 'A: backend worktree is clean after verified repair'
    Assert-True ([string]::IsNullOrWhiteSpace((Invoke-Git $scenarioA.Frontend.Home @('status', '--porcelain=v1')))) 'A: frontend worktree is clean after retry and checkpoint'

    # Scenario B: the debugger itself fails. It must not recurse into another
    # Auto-Debug and the supervisor must stop safely after three cycles.
    $scenarioB = New-AdScenario -Root $tempRoot -Name 'b'
    $bGate = Join-Path $tempRoot 'b-gate.txt'
    Set-Content -LiteralPath $bGate -Value 'fail-A' -NoNewline
    $bCount = Join-Path $tempRoot 'b-debug-count.txt'
    Set-AdEnvironment @{
        SPA_AD_GATE_FILE = $bGate
        SPA_AD_COUNT_FILE = $bCount
        SPA_AD_ADD_DIR_CAPTURE = $null
        SPA_AD_GATE_1 = $null
        SPA_AD_GATE_2 = $null
        SPA_AD_GATE_3 = $null
        SPA_AD_REPAIR_REPO = $null
        SPA_AD_DEBUG_EXIT = 'fail'
    }
    $oldPathB = $env:PATH
    $env:PATH = $codexShimDir + [System.IO.Path]::PathSeparator + $oldPathB
    try {
        $runB = Invoke-SpaRunTolerant @(
            '-Task', 'M1-REMAINING', '-TestMode', '-AllowTestExecution',
            '-StatePath', $scenarioB.StatePath, '-RoutingPath', $routingPath,
            '-BackendPath', $scenarioB.Backend.Home, '-FrontendPath', $scenarioB.Frontend.Home,
            '-DependencyMarkerPath', $scenarioB.MarkerPath,
            '-TestEvidenceRoot', (Join-Path $tempRoot 'b-evidence'), '-TestHealthPath', (Join-Path $tempRoot 'b-health')
        )
    }
    finally {
        $env:PATH = $oldPathB
    }
    Assert-True ($runB.Code -ne 0) 'B: failed debugger leaves the supervisor stopped, not hung'
    Assert-Match $runB.Output 'RESULT\s+STOPPED SAFELY' 'B: stopped summary reports STOPPED SAFELY'
    Assert-Match $runB.Output 'AUTO-DEBUG\s+COULD NOT RESOLVE' 'B: stopped summary reports unresolved Auto-Debug'
    Assert-Match $runB.Output 'DEBUG CYCLES\s+3' 'B: stopped summary reports three debug cycles'
    Assert-Match $runB.Output 'FAILED\s+P2T5' 'B: stopped summary names the failed original task'
    Assert-True ([int]([System.IO.File]::ReadAllText($bCount).Trim()) -eq 3) 'B: debugger failure does not recurse or loop beyond the stagnation guard'
    $bState = Read-M1State -Path $scenarioB.StatePath
    Assert-True (([string]$bState.tasks[0].status).Equals('RUNNING_LOCAL', [System.StringComparison]::OrdinalIgnoreCase)) 'B: failed debugger never marks the original task complete'
    Assert-True ([string]::IsNullOrWhiteSpace((Invoke-Git $scenarioB.Backend.Home @('status', '--porcelain=v1')))) 'B: backend remains clean'
    Assert-True ([string]::IsNullOrWhiteSpace((Invoke-Git $scenarioB.Frontend.Home @('status', '--porcelain=v1')))) 'B: frontend remains clean'

    # Scenario C: three succeeding debugger cycles that produce no repair and no
    # failure-signature change stop safely. A successful debugger alone must not
    # advance the checkpoint.
    $scenarioC = New-AdScenario -Root $tempRoot -Name 'c'
    $cGate = Join-Path $tempRoot 'c-gate.txt'
    Set-Content -LiteralPath $cGate -Value 'fail-A' -NoNewline
    $cCount = Join-Path $tempRoot 'c-debug-count.txt'
    Set-AdEnvironment @{
        SPA_AD_GATE_FILE = $cGate
        SPA_AD_COUNT_FILE = $cCount
        SPA_AD_ADD_DIR_CAPTURE = $null
        SPA_AD_GATE_1 = 'fail-A'
        SPA_AD_GATE_2 = 'fail-A'
        SPA_AD_GATE_3 = 'fail-A'
        SPA_AD_REPAIR_REPO = $null
        SPA_AD_DEBUG_EXIT = $null
    }
    $oldPathC = $env:PATH
    $env:PATH = $codexShimDir + [System.IO.Path]::PathSeparator + $oldPathC
    try {
        $runC = Invoke-SpaRunTolerant @(
            '-Task', 'M1-REMAINING', '-TestMode', '-AllowTestExecution',
            '-StatePath', $scenarioC.StatePath, '-RoutingPath', $routingPath,
            '-BackendPath', $scenarioC.Backend.Home, '-FrontendPath', $scenarioC.Frontend.Home,
            '-DependencyMarkerPath', $scenarioC.MarkerPath,
            '-TestEvidenceRoot', (Join-Path $tempRoot 'c-evidence'), '-TestHealthPath', (Join-Path $tempRoot 'c-health')
        )
    }
    finally {
        $env:PATH = $oldPathC
    }
    Assert-True ($runC.Code -ne 0) 'C: repeated no-progress cycles stop the runner safely'
    Assert-Match $runC.Output 'DEBUG CYCLES\s+3' 'C: no-progress guard stops after three cycles'
    Assert-Match $runC.Output 'COULD NOT RESOLVE' 'C: no-progress stop is reported as unresolved'
    Assert-Match $runC.Output 'REASON\s+' 'C: no-progress stop explains an evidence-based reason'
    $cState = Read-M1State -Path $scenarioC.StatePath
    Assert-True (([string]$cState.tasks[0].status).Equals('RUNNING_LOCAL', [System.StringComparison]::OrdinalIgnoreCase)) 'C: successful debugger run alone does not complete the original task'
    Assert-True ([int]([System.IO.File]::ReadAllText($cCount).Trim()) -eq 3) 'C: debugger cycles were bounded by stagnation, not random choice'

    # Scenario D: meaningful progress (repaired HEAD plus changed failure
    # signature) allows the runner to continue past what a fixed two-attempt cap
    # would allow; the second verified repair lets the original route succeed.
    $scenarioD = New-AdScenario -Root $tempRoot -Name 'd'
    $dGate = Join-Path $tempRoot 'd-gate.txt'
    Set-Content -LiteralPath $dGate -Value 'fail-A' -NoNewline
    $dCount = Join-Path $tempRoot 'd-debug-count.txt'
    Set-AdEnvironment @{
        SPA_AD_GATE_FILE = $dGate
        SPA_AD_COUNT_FILE = $dCount
        SPA_AD_ADD_DIR_CAPTURE = $null
        SPA_AD_GATE_1 = 'fail-B'
        SPA_AD_GATE_2 = 'pass'
        SPA_AD_REPAIR_REPO = $scenarioD.Backend.Home
        SPA_AD_BRANCH = $expectedBranch
        SPA_AD_DEBUG_EXIT = $null
    }
    $oldPathD = $env:PATH
    $env:PATH = $codexShimDir + [System.IO.Path]::PathSeparator + $oldPathD
    try {
        $runD = Invoke-SpaRunTolerant @(
            '-Task', 'M1-REMAINING', '-TestMode', '-AllowTestExecution',
            '-StatePath', $scenarioD.StatePath, '-RoutingPath', $routingPath,
            '-BackendPath', $scenarioD.Backend.Home, '-FrontendPath', $scenarioD.Frontend.Home,
            '-DependencyMarkerPath', $scenarioD.MarkerPath,
            '-TestEvidenceRoot', (Join-Path $tempRoot 'd-evidence'), '-TestHealthPath', (Join-Path $tempRoot 'd-health')
        )
    }
    finally {
        $env:PATH = $oldPathD
    }
    Assert-True ($runD.Code -eq 0) 'D: progress signals permit continuation and the retried route eventually succeeds'
    Assert-Match $runD.Output 'DEBUG CYCLES\s+2' 'D: two verified repair cycles were needed and allowed'
    Assert-Match $runD.Output 'AUTO-DEBUG\s+FIXED' 'D: final summary reports the Auto-Debug fix'
    Assert-True ([int]([System.IO.File]::ReadAllText($dCount).Trim()) -eq 2) 'D: no fixed numeric retry cap stopped the progress run'
    $dBackendLog = (Invoke-Git $scenarioD.Backend.Home @('log', '--oneline', '-6'))
    Assert-True (((@($dBackendLog)) -join "`n") -match 'test auto-debug repair cycle 1') 'D: first repair commit exists'
    Assert-True (((@($dBackendLog)) -join "`n") -match 'test auto-debug repair cycle 2') 'D: second repair commit exists'

    # STATUS surface: Auto-Debug heartbeat fields and state transitions.
    $statusHealthRoot = Join-Path $tempRoot 'status-health'
    New-Item -ItemType Directory -Path $statusHealthRoot -Force | Out-Null
    $statusStarted = [datetimeoffset]'2026-09-07T12:00:00+00:00'
    Write-SpaHealthRecord `
        -Task 'AUTO-DEBUG P2T5' `
        -Phase 'AUTO-DEBUG' `
        -Model 'deepseek-v4-pro' `
        -Provider 'deepseek' `
        -StartedAt $statusStarted `
        -LastOutputAt $statusStarted.AddMinutes(2) `
        -ProcessId 5101 `
        -ProcessAlive $true `
        -LastSafe 'P2T4 COMPLETE' `
        -OriginalTask 'P2T5' `
        -DebugCycle 2 `
        -HealthRoot $statusHealthRoot `
        -Now $statusStarted.AddMinutes(3) | Out-Null
    $statusDebug = Invoke-SpaRunTolerant @('-Status', '-TestHealthPath', $statusHealthRoot)
    Assert-True ($statusDebug.Code -eq 0) 'STATUS: -Status succeeds while Auto-Debug is running'
    Assert-Match $statusDebug.Output 'STATE\s+AUTO_DEBUGGING' 'STATUS: Auto-Debug phase reports AUTO_DEBUGGING'
    Assert-Match $statusDebug.Output 'ORIGINAL TASK\s+P2T5' 'STATUS: Auto-Debug status reports the original task'
    Assert-Match $statusDebug.Output 'DEBUG CYCLE\s+2' 'STATUS: Auto-Debug status reports the current debug cycle'
    Assert-Match $statusDebug.Output 'MODEL\s+deepseek-v4-pro' 'STATUS: Auto-Debug status reports the debugger model'
    Assert-Match $statusDebug.Output 'LAST SAFE\s+P2T4 COMPLETE' 'STATUS: Auto-Debug status reports the last safe checkpoint'

    Write-SpaHealthRecord `
        -Task 'P2T5' `
        -Phase 'IMPLEMENT' `
        -Model 'deepseek-v4-pro' `
        -Provider 'deepseek' `
        -StartedAt $statusStarted `
        -LastOutputAt $statusStarted.AddMinutes(2) `
        -ProcessId 5102 `
        -ProcessAlive $true `
        -LastSafe 'P2T4 COMPLETE' `
        -Retry $true `
        -HealthRoot $statusHealthRoot `
        -Now $statusStarted.AddMinutes(3) | Out-Null
    $statusRetry = Invoke-SpaRunTolerant @('-Status', '-TestHealthPath', $statusHealthRoot)
    Assert-True ($statusRetry.Code -eq 0) 'STATUS: -Status succeeds during a retry'
    Assert-Match $statusRetry.Output 'STATE\s+RETRYING' 'STATUS: retried child reports RETRYING'

    Write-SpaHealthRecord `
        -Task 'P2T5' `
        -Phase 'IMPLEMENT' `
        -Model 'deepseek-v4-pro' `
        -Provider 'deepseek' `
        -StartedAt $statusStarted `
        -LastOutputAt $statusStarted.AddMinutes(2) `
        -ProcessId 5103 `
        -ProcessAlive $false `
        -LastSafe 'P2T4 COMPLETE' `
        -HealthRoot $statusHealthRoot `
        -FinalHealth 'STOPPED' `
        -Now $statusStarted.AddMinutes(4) | Out-Null
    $statusStopped = Invoke-SpaRunTolerant @('-Status', '-TestHealthPath', $statusHealthRoot)
    Assert-True ($statusStopped.Code -eq 0) 'STATUS: -Status succeeds after a stopped worker'
    Assert-Match $statusStopped.Output 'STATE\s+STOPPED' 'STATUS: stopped worker reports STOPPED'
}
finally {
    Set-AdEnvironment @{
        SPA_AD_GATE_FILE = $null
        SPA_AD_COUNT_FILE = $null
        SPA_AD_ADD_DIR_CAPTURE = $null
        SPA_AD_GATE_1 = $null
        SPA_AD_GATE_2 = $null
        SPA_AD_GATE_3 = $null
        SPA_AD_REPAIR_REPO = $null
        SPA_AD_BRANCH = $null
        SPA_AD_DEBUG_EXIT = $null
    }
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ''
if ($failures.Count -eq 0) {
    Write-Host 'GREEN: all SPA Auto-Debug tests passed.'
    exit 0
}

Write-Host "RED: $($failures.Count) SPA Auto-Debug test(s) failed."
$failures | ForEach-Object { Write-Host " - $_" }
exit 1
