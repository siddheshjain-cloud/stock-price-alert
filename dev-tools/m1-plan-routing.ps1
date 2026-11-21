Set-StrictMode -Version Latest

function Get-M1PlanCatalog {
    param(
        [Parameter(Mandatory = $true)][string]$PlanIndexPath,
        [Parameter(Mandatory = $true)][string]$PlanRoot
    )

    if (-not (Test-Path -LiteralPath $PlanIndexPath -PathType Leaf)) {
        throw "M1 plan index is missing: $PlanIndexPath"
    }

    $planRoot = [System.IO.Path]::GetFullPath($PlanRoot)
    $indexText = [System.IO.File]::ReadAllText($PlanIndexPath)
    $entries = @([regex]::Matches(
        $indexText,
        '(?m)^\s*([0-9]+)\.\s*\[[^\]]+\]\(([^)]+)\)'
    ))
    if ($entries.Count -eq 0) {
        throw "M1 plan index does not contain any implementation plan entries: $PlanIndexPath"
    }

    $plans = New-Object System.Collections.Generic.List[object]
    foreach ($entry in $entries) {
        $planNumber = [int]$entry.Groups[1].Value
        $planLeaf = $entry.Groups[2].Value.Trim()
        $planFile = Join-Path $planRoot $planLeaf
        if (-not (Test-Path -LiteralPath $planFile -PathType Leaf)) {
            throw "M1 plan file is missing: $planFile"
        }

        $planText = [System.IO.File]::ReadAllText($planFile)
        $taskHeadings = @([regex]::Matches($planText, '(?m)^##\s+Task\s+([0-9]+):'))
        if ($taskHeadings.Count -eq 0) {
            throw "M1 plan file contains no implementation task headings: $planFile"
        }

        $plans.Add([pscustomobject]@{
            PlanNumber = $planNumber
            PlanLeaf = $planLeaf
            PlanFile = [System.IO.Path]::GetFullPath($planFile)
            TaskCount = $taskHeadings.Count
        })
    }
    return $plans
}

function Get-M1ImplementationRoute {
    param(
        [Parameter(Mandatory = $true)][string]$TaskId,
        [Parameter(Mandatory = $true)][string]$PlanIndexPath,
        [Parameter(Mandatory = $true)][string]$PlanRoot,
        [Parameter(Mandatory = $true)][string]$RepositoryPath,
        [string]$SpecPath = '',
        [string]$Repository = 'Backend',
        [string]$Branch = 'feature/investment-operating-system-m1',
        [string]$Sandbox = 'workspace-write',
        [string]$PromptPath = ''
    )

    $taskId = $TaskId.Trim().ToUpperInvariant()
    $taskMatch = [regex]::Match($taskId, '^P([0-9]+)T([0-9]+)$')
    if (-not $taskMatch.Success) {
        throw "Unknown M1 implementation task ID: $taskId"
    }

    $planNumber = [int]$taskMatch.Groups[1].Value
    $taskNumber = [int]$taskMatch.Groups[2].Value
    $plans = @(Get-M1PlanCatalog -PlanIndexPath $PlanIndexPath -PlanRoot $PlanRoot)
    $plan = @($plans | Where-Object { [int]$_.PlanNumber -eq $planNumber })
    if ($plan.Count -ne 1) {
        throw "M1 plan $planNumber was not found in the frozen plan index."
    }
    $plan = $plan[0]

    if ($taskNumber -lt 1 -or $taskNumber -gt [int]$plan.TaskCount) {
        throw "M1 task '$taskId' does not match a task in Plan $planNumber."
    }

    $taskTitle = ''
    foreach ($line in @([System.IO.File]::ReadAllLines($plan.PlanFile))) {
        $heading = [regex]::Match($line, '^##\s+Task\s+([0-9]+):\s*(.*?)\s*$')
        if ($heading.Success -and [int]$heading.Groups[1].Value -eq $taskNumber) {
            $taskTitle = $heading.Groups[2].Value.Trim()
            break
        }
    }
    if ([string]::IsNullOrWhiteSpace($taskTitle)) {
        throw "M1 plan '$($plan.PlanLeaf)' does not contain Task $taskNumber."
    }

    $sectionHeading = "## Task $taskNumber`:$taskTitle"
    return [pscustomobject]@{
        TaskId = $taskId
        PlanNumber = $planNumber
        PlanLeaf = [string]$plan.PlanLeaf
        PlanFile = [string]$plan.PlanFile
        TaskNumber = $taskNumber
        TaskTitle = $taskTitle
        SectionHeading = $sectionHeading
        Repository = $Repository
        RepositoryPath = [System.IO.Path]::GetFullPath($RepositoryPath)
        Branch = $Branch
        Sandbox = $Sandbox
        SpecPath = if ([string]::IsNullOrWhiteSpace($SpecPath)) { '' } else { [System.IO.Path]::GetFullPath($SpecPath) }
        PromptPath = if ([string]::IsNullOrWhiteSpace($PromptPath)) { '' } else { [System.IO.Path]::GetFullPath($PromptPath) }
        CommitPushRequired = $true
        ReviewGate = ''
    }
}

function Get-M1ImplementationPrompt {
    param(
        [Parameter(Mandatory = $true)][object]$Route,
        [Parameter(Mandatory = $true)][string]$TemplatePath
    )

    if (-not (Test-Path -LiteralPath $TemplatePath -PathType Leaf)) {
        throw "Generic M1 implementation prompt template is missing: $TemplatePath"
    }

    $prompt = [System.IO.File]::ReadAllText($TemplatePath)
    $replacements = [ordered]@{
        '{{TASK_ID}}' = [string]$Route.TaskId
        '{{PLAN_PATH}}' = [string]$Route.PlanFile
        '{{PLAN_TASK_NUMBER}}' = [string]$Route.TaskNumber
        '{{PLAN_TASK_TITLE}}' = [string]$Route.TaskTitle
        '{{SECTION_HEADING}}' = [string]$Route.SectionHeading
        '{{REPOSITORY_PATH}}' = [string]$Route.RepositoryPath
        '{{SPEC_PATH}}' = [string]$Route.SpecPath
        '{{BRANCH}}' = [string]$Route.Branch
        '{{COMMIT_PUSH}}' = if ([bool]$Route.CommitPushRequired) { 'YES' } else { 'NO' }
    }
    foreach ($key in $replacements.Keys) {
        $prompt = $prompt.Replace($key, [string]$replacements[$key])
    }
    return $prompt
}
