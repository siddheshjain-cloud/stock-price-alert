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
    [string]$TestTaskOutputPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RoutingPath)) {
    $RoutingPath = Join-Path $PSScriptRoot 'm1-model-routing.psd1'
}

function Stop-SpaRun {
    param([Parameter(Mandatory = $true)][string]$Message)

    Write-Output ('SPA-RUN FAIL: {0}' -f $Message)
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

$testOnlyOverrides = @('RoutingPath', 'BackendPath', 'FrontendPath', 'DependencyMarkerPath', 'TestModelCheckOutputPath', 'TestTaskOutputPath')
$usedTestOnlyOverrides = @($testOnlyOverrides | Where-Object { $PSBoundParameters.ContainsKey($_) })
if ($TestMode -and -not $DryRun) {
    Stop-SpaRun '-TestMode requires -DryRun and can never invoke a task.'
}
if (-not $TestMode -and $usedTestOnlyOverrides.Count -gt 0) {
    Stop-SpaRun 'Test-only overrides require both -TestMode and -DryRun.'
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

$taskId = $Task.Trim().ToUpperInvariant()
if (-not $routing.ContainsKey('Routes') -or -not $routing.Routes.ContainsKey($taskId)) {
    Stop-SpaRun "Unknown SPA task ID: $taskId"
}

$route = $routing.Routes[$taskId]
$action = Get-RequiredValue -Table $route -Name 'Action' -Context $taskId
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
    exit 0
}

if ($DryRun) {
    Write-Output 'DRY RUN    task invocation skipped'
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
    exit 0
}
finally {
    if (Test-Path -LiteralPath $lastMessagePath) {
        Remove-Item -LiteralPath $lastMessagePath -Force -ErrorAction SilentlyContinue
    }
}
