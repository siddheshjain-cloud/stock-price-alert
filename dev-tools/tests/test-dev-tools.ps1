[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$devTools = Join-Path $repoRoot 'dev-tools'
$spaCheck = Join-Path $devTools 'spa-check.ps1'
$spaModelCheck = Join-Path $devTools 'spa-model-check.ps1'
$spaDepsSync = Join-Path $devTools 'spa-deps-sync.ps1'
$promptHeader = Join-Path $devTools 'agent-prompt-header.txt'
$readme = Join-Path $devTools 'README.md'
$permanentPython = 'C:\venvs\spa-m1\Scripts\python.exe'
$expectedBranch = 'feature/investment-operating-system-m1'

$failures = New-Object System.Collections.Generic.List[string]

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        $script:failures.Add($Message)
        Write-Host "FAIL: $Message"
    }
    else {
        Write-Host "PASS: $Message"
    }
}

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$Haystack,
        [Parameter(Mandatory = $true)][string]$Needle,
        [Parameter(Mandatory = $true)][string]$Message
    )

    Assert-True ($Haystack.IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) $Message
}

function Assert-NotContains {
    param(
        [Parameter(Mandatory = $true)][string]$Haystack,
        [Parameter(Mandatory = $true)][string]$Needle,
        [Parameter(Mandatory = $true)][string]$Message
    )

    Assert-True ($Haystack.IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) $Message
}

function Read-ToolText {
    param([Parameter(Mandatory = $true)][string]$Path)

    return [System.IO.File]::ReadAllText($Path)
}

function New-TestGitRepo {
    param([Parameter(Mandatory = $true)][string]$Path)

    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    git -C $Path init -q
    if ($LASTEXITCODE -ne 0) {
        throw "git init failed for $Path"
    }

    git -C $Path config user.email 'spa-dev-tools-test@example.com'
    git -C $Path config user.name 'SPA Dev Tools Test'
    Set-Content -LiteralPath (Join-Path $Path 'README.md') -Value 'temporary test repository' -NoNewline
    git -C $Path add -A
    git -C $Path commit -q -m 'initial commit'
    if ($LASTEXITCODE -ne 0) {
        throw "git commit failed for $Path"
    }

    git -C $Path checkout -q -b $expectedBranch
    if ($LASTEXITCODE -ne 0) {
        throw "git checkout failed for $Path"
    }
}

$expectedFiles = @(
    'spa-check.ps1',
    'spa-model-check.ps1',
    'spa-deps-sync.ps1',
    'agent-prompt-header.txt',
    'README.md',
    'tests\test-dev-tools.ps1'
)

foreach ($file in $expectedFiles) {
    $filePath = Join-Path $devTools $file
    Assert-True (Test-Path -LiteralPath $filePath -PathType Leaf) "expected file exists: dev-tools\$file"
}

if ($failures.Count -gt 0) {
    Write-Host ''
    Write-Host "RED: $($failures.Count) required tooling file(s) are missing."
    Write-Host "This is expected before implementation."
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}

$spaCheckText = Read-ToolText -Path $spaCheck
$spaModelCheckText = Read-ToolText -Path $spaModelCheck
$spaDepsSyncText = Read-ToolText -Path $spaDepsSync
$promptHeaderText = Read-ToolText -Path $promptHeader

$spaCheckForbiddenPatterns = @(
    '\bgit\s+(pull|fetch|reset|checkout|switch|clean|commit|push)\b',
    '\bpip\s+install\b',
    '\bwinget\b',
    '\bchoco\b',
    '\bmsiexec\b',
    '\bInvoke-WebRequest\b',
    '\bInvoke-RestMethod\b',
    '\bStart-BitsTransfer\b'
)

foreach ($pattern in $spaCheckForbiddenPatterns) {
    Assert-True (-not [regex]::IsMatch($spaCheckText, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) "spa-check avoids forbidden mutation/network/install command: $pattern"
}

Assert-Contains $spaModelCheckText '--ask-for-approval' 'spa-model-check uses approval-never flag'
Assert-Contains $spaModelCheckText 'never' 'spa-model-check sets approval to never'
Assert-Contains $spaModelCheckText '--sandbox' 'spa-model-check uses sandbox flag'
Assert-Contains $spaModelCheckText 'read-only' 'spa-model-check sets sandbox to read-only'
Assert-NotContains $spaModelCheckText 'danger-full-access' 'spa-model-check never uses danger-full-access'
Assert-NotContains $spaModelCheckText '--sandbox workspace-write' 'spa-model-check is not write-sandboxed'
Assert-Contains $spaModelCheckText 'MODEL_CHECK_OK' 'spa-model-check verifies MODEL_CHECK_OK'

Assert-Contains $spaDepsSyncText $permanentPython 'spa-deps-sync references the fixed permanent Python'
Assert-True ([regex]::IsMatch($spaDepsSyncText, '\bCheckOnly\b', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) 'spa-deps-sync supports CheckOnly'
Assert-True ([regex]::IsMatch($spaDepsSyncText, '\bForce\b', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) 'spa-deps-sync supports Force'
$installerPatterns = @('\bwinget\b', '\bchoco\b', '\bmsiexec\b', 'python\.org', 'Install-Python', 'Install-Package')
foreach ($pattern in $installerPatterns) {
    Assert-True (-not [regex]::IsMatch($spaDepsSyncText, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) "spa-deps-sync avoids Python/package installer behavior: $pattern"
}

Assert-Contains $promptHeaderText 'C:\GitHub\backendtest' 'prompt header contains backend path'
Assert-Contains $promptHeaderText 'C:\GitHub\stock-price-alert' 'prompt header contains frontend/docs path'
Assert-Contains $promptHeaderText $permanentPython 'prompt header contains permanent Python path'
Assert-Contains $promptHeaderText 'python.exe -m pytest -q' 'prompt header contains canonical pytest command'

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('spa-dev-tools-test-' + [guid]::NewGuid().ToString('N'))
$backendRepo = Join-Path $tempRoot 'backend'
$frontendRepo = Join-Path $tempRoot 'frontend'

try {
    New-TestGitRepo -Path $backendRepo
    New-TestGitRepo -Path $frontendRepo

    $readyArgs = @(
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        $spaCheck,
        '-BackendPath',
        $backendRepo,
        '-FrontendPath',
        $frontendRepo,
        '-PythonPath',
        $permanentPython,
        '-ExpectedBranch',
        $expectedBranch
    )

    $readyOutput = & powershell.exe @readyArgs 2>&1 | Out-String
    $readyCode = $LASTEXITCODE

    Assert-True ($readyCode -eq 0) 'spa-check reports READY YES as exit 0 for clean temporary repos'
    Assert-True ([regex]::IsMatch($readyOutput, 'READY\s+YES')) 'spa-check output contains READY YES'

    Set-Content -LiteralPath (Join-Path $frontendRepo 'dirty.txt') -Value 'dirty' -NoNewline
    $dirtyOutput = & powershell.exe @readyArgs 2>&1 | Out-String
    $dirtyCode = $LASTEXITCODE

    Assert-True ($dirtyCode -ne 0) 'spa-check reports READY NO as nonzero when a temporary repo is dirty'
    Assert-True ([regex]::IsMatch($dirtyOutput, 'READY\s+NO')) 'spa-check output contains READY NO for a dirty repo'
}
finally {
    if ($tempRoot -and (Test-Path -LiteralPath $tempRoot)) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ''
if ($failures.Count -eq 0) {
    Write-Host "GREEN: all dev-tools tests passed."
    exit 0
}
else {
    Write-Host "RED: $($failures.Count) test(s) failed."
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}
