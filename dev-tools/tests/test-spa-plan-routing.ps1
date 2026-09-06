[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$devTools = Join-Path $repoRoot 'dev-tools'
$spaRun = Join-Path $devTools 'spa-run.ps1'
$routingPath = Join-Path $devTools 'm1-model-routing.psd1'
$planRoot = Join-Path $repoRoot 'docs\superpowers\plans'
$planIndex = Join-Path $planRoot '2026-09-04-investment-operating-system-milestone-1-index.md'
$specPath = Join-Path $repoRoot 'docs\superpowers\specs\2026-09-04-investment-operating-system-milestone-1-design.md'
$promptTemplate = Join-Path $devTools 'prompts\m1-implementation.txt'
$stateTools = Join-Path $devTools 'm1-state.ps1'
$planTools = Join-Path $devTools 'm1-plan-routing.ps1'
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

function Assert-NotContains {
    param([string]$Text, [string]$Needle, [string]$Message)
    Assert-True ($Text.IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) $Message
}

function Invoke-SpaRun {
    param([string[]]$Arguments)
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $spaRun @Arguments 2>&1 | Out-String
    [pscustomobject]@{ Code = $LASTEXITCODE; Output = $output }
}

foreach ($required in @($spaRun, $routingPath, $planIndex, $specPath, $promptTemplate, $stateTools, $planTools)) {
    Assert-True (Test-Path -LiteralPath $required -PathType Leaf) "required plan-routing artifact exists: $required"
}

if ($failures.Count -gt 0) {
    Write-Host ''
    Write-Host 'RED: required plan-routing artifact(s) are missing.'
    exit 1
}

. $stateTools
. $planTools
$routing = Import-PowerShellDataFile -LiteralPath $routingPath

function Get-RouteModel {
    param([string]$TaskId)
    $route = $routing.Routes[$TaskId]
    $name = [string]$route.ModelRoute
    $model = $routing.ModelRoutes[$name]
    [pscustomobject]@{
        Provider = [string]$model.Provider
        Model = [string]$model.Model
        Reasoning = [string]$model.Reasoning
    }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('spa-plan-routing-test-' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    Assert-True (-not [bool]$routing.Routes.P2T5.Enabled) 'P2T5 remains recorded as a not-enabled route before generic implementation resolution'

    $p2t5 = Get-M1ImplementationRoute `
        -TaskId 'P2T5' `
        -PlanIndexPath $planIndex `
        -PlanRoot $planRoot `
        -SpecPath $specPath `
        -RepositoryPath 'C:\GitHub\backendtest'
    $p2t5Model = Get-RouteModel 'P2T5'
    Assert-True ($p2t5.PlanNumber -eq 2) 'P2T5 resolves to Plan 2'
    Assert-True ([System.IO.Path]::GetFileName($p2t5.PlanFile) -match 'core-research-domain') 'P2T5 resolves to the actual Core Research Domain plan file'
    Assert-True ($p2t5.TaskNumber -eq 5) 'P2T5 resolves to Task 5'
    Assert-True ($p2t5.RepositoryPath -eq 'C:\GitHub\backendtest') 'P2T5 resolves to backendtest'
    Assert-True ($p2t5Model.Provider -eq 'deepseek' -and $p2t5Model.Model -eq 'deepseek-v4-flash' -and $p2t5Model.Reasoning -eq 'high') 'P2T5 resolves to DeepSeek V4 Flash High'
    Assert-True (-not [string]::IsNullOrWhiteSpace($p2t5.SectionHeading)) 'P2T5 resolves to a non-empty plan section anchor'
    $p2t5Prompt = Get-M1ImplementationPrompt -Route $p2t5 -TemplatePath $promptTemplate
    Assert-Match $p2t5Prompt 'TASK ID:\s+P2T5' 'rendered prompt injects the exact task ID'
    Assert-Match $p2t5Prompt 'PLAN FILE:\s+.*core-research-domain' 'rendered prompt injects the exact plan file'
    Assert-Match $p2t5Prompt 'SECTION ANCHOR:\s+## Task 5:' 'rendered prompt injects the exact task section anchor'
    Assert-Match $p2t5Prompt 'COMMIT/PUSH REQUIRED:\s+YES' 'rendered prompt injects the commit/push requirement'
    Assert-NotContains $p2t5Prompt '{{PLAN_PATH}}' 'rendered prompt leaves no unresolved plan placeholder'

    $p2t9 = Get-M1ImplementationRoute `
        -TaskId 'P2T9' `
        -PlanIndexPath $planIndex `
        -PlanRoot $planRoot `
        -SpecPath $specPath `
        -RepositoryPath 'C:\GitHub\backendtest'
    $p2t9Model = Get-RouteModel 'P2T9'
    Assert-True ($p2t9.PlanNumber -eq 2 -and $p2t9.TaskNumber -eq 9) 'P2T9 resolves to Plan 2 Task 9'
    Assert-True ($p2t9Model.Provider -eq 'deepseek' -and $p2t9Model.Model -eq 'deepseek-v4-pro' -and $p2t9Model.Reasoning -eq 'high') 'P2T9 resolves to DeepSeek V4 Pro High'

    $p3t1 = Get-M1ImplementationRoute `
        -TaskId 'P3T1' `
        -PlanIndexPath $planIndex `
        -PlanRoot $planRoot `
        -SpecPath $specPath `
        -RepositoryPath 'C:\GitHub\backendtest'
    $p3t1Model = Get-RouteModel 'P3T1'
    Assert-True ($p3t1.PlanNumber -eq 3 -and $p3t1.TaskNumber -eq 1) 'P3T1 resolves to Plan 3 Task 1'
    Assert-True ($p3t1Model.Provider -eq 'deepseek' -and $p3t1Model.Model -eq 'deepseek-v4-flash' -and $p3t1Model.Reasoning -eq 'high') 'P3T1 resolves to DeepSeek V4 Flash High'

    $p4t4 = Get-M1ImplementationRoute `
        -TaskId 'P4T4' `
        -PlanIndexPath $planIndex `
        -PlanRoot $planRoot `
        -SpecPath $specPath `
        -RepositoryPath 'C:\GitHub\backendtest'
    $p4t4Model = Get-RouteModel 'P4T4'
    Assert-True ($p4t4.PlanNumber -eq 4 -and $p4t4.TaskNumber -eq 4) 'P4T4 resolves to Plan 4 Task 4'
    Assert-True ($p4t4Model.Provider -eq 'deepseek' -and $p4t4Model.Model -eq 'deepseek-v4-pro' -and $p4t4Model.Reasoning -eq 'high') 'P4T4 resolves to DeepSeek V4 Pro High'

    $p5t8 = Get-M1ImplementationRoute `
        -TaskId 'P5T8' `
        -PlanIndexPath $planIndex `
        -PlanRoot $planRoot `
        -SpecPath $specPath `
        -RepositoryPath 'C:\GitHub\backendtest'
    $p5t8Model = Get-RouteModel 'P5T8'
    Assert-True ($p5t8.PlanNumber -eq 5 -and $p5t8.TaskNumber -eq 8) 'P5T8 resolves to Plan 5 Task 8'
    Assert-True ($p5t8Model.Provider -eq 'deepseek' -and $p5t8Model.Model -eq 'deepseek-v4-pro' -and $p5t8Model.Reasoning -eq 'high') 'P5T8 resolves to DeepSeek V4 Pro High'

    $unknownFailed = $false
    try { Get-M1ImplementationRoute -TaskId 'DOES-NOT-EXIST' -PlanIndexPath $planIndex -PlanRoot $planRoot -SpecPath $specPath -RepositoryPath 'C:\GitHub\backendtest' | Out-Null }
    catch { $unknownFailed = ($_.Exception.Message -match 'Unknown|invalid|task') }
    Assert-True $unknownFailed 'unknown implementation task fails closed'

    $missingPlanIndex = Join-Path $tempRoot 'missing-index.md'
    Set-Content -LiteralPath $missingPlanIndex -Value '1. [Missing](missing-plan.md)' -NoNewline
    $missingPlanFailed = $false
    try { Get-M1ImplementationRoute -TaskId 'P2T5' -PlanIndexPath $missingPlanIndex -PlanRoot $tempRoot -SpecPath $specPath -RepositoryPath 'C:\GitHub\backendtest' | Out-Null }
    catch { $missingPlanFailed = ($_.Exception.Message -match 'missing|plan') }
    Assert-True $missingPlanFailed 'missing plan file fails closed'

    $shortPlanIndex = Join-Path $tempRoot 'short-index.md'
    $shortPlan = Join-Path $tempRoot 'short-plan.md'
    Set-Content -LiteralPath $shortPlanIndex -Value '2. [Short](short-plan.md)' -NoNewline
    @(
        '# Short plan',
        '## Task 1: Only task'
    ) | Set-Content -LiteralPath $shortPlan
    $missingSectionFailed = $false
    try { Get-M1ImplementationRoute -TaskId 'P2T5' -PlanIndexPath $shortPlanIndex -PlanRoot $tempRoot -SpecPath $specPath -RepositoryPath 'C:\GitHub\backendtest' | Out-Null }
    catch { $missingSectionFailed = ($_.Exception.Message -match 'does not contain Task 5|does not match a task in Plan 2|Task 5') }
    Assert-True $missingSectionFailed 'missing plan task section/anchor fails closed'

    $codexShimDir = Join-Path $tempRoot 'codex-shim'
    $tokenMarker = Join-Path $tempRoot 'MODEL_WAS_CALLED.txt'
    New-Item -ItemType Directory -Path $codexShimDir -Force | Out-Null
    @"
@echo off
echo called>"$tokenMarker"
exit /b 99
"@ | Set-Content -LiteralPath (Join-Path $codexShimDir 'codex.cmd') -Encoding ASCII
    $oldPath = $env:PATH
    $env:PATH = $codexShimDir + [System.IO.Path]::PathSeparator + $oldPath
    try {
        $dryRun = Invoke-SpaRun @('-Task', 'P2T5', '-DryRun')
    }
    finally {
        $env:PATH = $oldPath
    }
    Assert-True ($dryRun.Code -eq 0) 'generic P2T5 dry-run resolves successfully'
    Assert-Match $dryRun.Output 'ACTION\s+IMPLEMENT' 'generic dry-run reports IMPLEMENT action'
    Assert-Match $dryRun.Output 'PLAN\s+.*core-research-domain' 'generic dry-run reports the exact Plan 2 file'
    Assert-Match $dryRun.Output 'PLAN TASK\s+Task 5' 'generic dry-run reports Task 5'
    Assert-Match $dryRun.Output 'REPO\s+backendtest' 'generic dry-run reports backendtest'
    Assert-Match $dryRun.Output 'MODEL\s+deepseek-v4-flash' 'generic dry-run reports DeepSeek V4 Flash'
    Assert-Match $dryRun.Output 'PROVIDER\s+deepseek' 'generic dry-run reports DeepSeek provider'
    Assert-Match $dryRun.Output 'REASONING\s+high' 'generic dry-run reports high reasoning'
    Assert-True (-not (Test-Path -LiteralPath $tokenMarker)) 'generic dry-run consumes no model tokens'

    $reviewDryRun = Invoke-SpaRun @('-Task', 'P2T4-REVIEW', '-DryRun')
    Assert-True ($reviewDryRun.Code -eq 0) 'existing P2T4-REVIEW routing remains enabled'
    Assert-Match $reviewDryRun.Output 'ACTION\s+REVIEW' 'existing P2T4-REVIEW routing remains a review route'
    Assert-Match $reviewDryRun.Output 'MODEL\s+deepseek-v4-pro' 'existing P2T4-REVIEW model routing is unchanged'

    $promptText = [System.IO.File]::ReadAllText($promptTemplate)
    Assert-Match $promptText '\{\{PLAN_PATH\}\}' 'generic prompt has a plan-path placeholder'
    Assert-Match $promptText '\{\{SECTION_HEADING\}\}' 'generic prompt has a section-anchor placeholder'
    Assert-Match $promptText '\{\{TASK_ID\}\}' 'generic prompt has a task-id placeholder'
    Assert-NotContains $promptText 'Write failing migration-path tests' 'generic prompt does not duplicate a giant plan task body'
    Assert-True ($promptText.Length -lt 4000) 'generic prompt remains a small template'

    Assert-NotContains $promptText 'python -m pip install -r requirements-dev.txt' 'generic prompt does not reintroduce environment bootstrap'
    Assert-NotContains $promptText 'npm install' 'generic prompt does not reintroduce frontend bootstrap'

    $resumeState = [ordered]@{
        schemaVersion = 1
        milestone = 'M1'
        branch = 'feature/investment-operating-system-m1'
        repositories = [ordered]@{
            backend = [ordered]@{ lastVerifiedSha = $null }
            frontend = [ordered]@{ lastVerifiedSha = $null }
        }
        tasks = @(
            [ordered]@{
                id = 'P2T4'; action = 'IMPLEMENT'; status = 'COMPLETE'
                implementationProvider = 'deepseek'; implementationModel = 'deepseek-v4-pro'
                reviewerProvider = $null; reviewerModel = $null; reviewRoute = $null
                remediationRoute = 'P2T4'; lastVerifiedBackendSha = $null; lastVerifiedFrontendSha = $null
                implementationCommitSha = $null; remediationCommitSha = $null; lastSuccessfulReviewVerdict = 'SAFE'
                remediationAttempts = 0
                evidence = [ordered]@{ implementationSucceeded = $true; testsSucceeded = $true; reviewRequired = $false; reviewSucceeded = $false; relevantCommitsPushed = $true }
                updatedUtc = '2026-09-06T00:00:00Z'
            },
            [ordered]@{
                id = 'P2T5'; action = 'IMPLEMENT'; status = 'PENDING'
                implementationProvider = 'deepseek'; implementationModel = 'deepseek-v4-flash'
                reviewerProvider = $null; reviewerModel = $null; reviewRoute = $null
                remediationRoute = 'P2T5'; lastVerifiedBackendSha = $null; lastVerifiedFrontendSha = $null
                implementationCommitSha = $null; remediationCommitSha = $null; lastSuccessfulReviewVerdict = $null
                remediationAttempts = 0
                evidence = [ordered]@{ implementationSucceeded = $false; testsSucceeded = $false; reviewRequired = $false; reviewSucceeded = $false; relevantCommitsPushed = $false }
                updatedUtc = '2026-09-06T00:00:00Z'
            }
        )
    }
    $next = Get-M1NextUnit -State $resumeState
    Assert-True ($next.RouteId -eq 'P2T5' -and -not $next.IsRecovery) 'existing M1 resume/next-unit behavior still selects P2T5'
    $health = Get-SpaHealthStatus -Now ([datetimeoffset]'2026-09-06T12:00:00Z') -StartedAt ([datetimeoffset]'2026-09-06T11:59:00Z') -LastOutputAt ([datetimeoffset]'2026-09-06T12:00:00Z') -ProcessAlive $true
    Assert-True ($health -eq 'ACTIVE') 'existing worker health-status behavior still functions'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ''
if ($failures.Count -eq 0) {
    Write-Host 'GREEN: all SPA plan-routing tests passed.'
    exit 0
}

Write-Host "RED: $($failures.Count) SPA plan-routing test(s) failed."
$failures | ForEach-Object { Write-Host " - $_" }
exit 1
