[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$devTools = Join-Path $repoRoot 'dev-tools'
$spaCheck = Join-Path $devTools 'spa-check.ps1'
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

function New-MockCodexOutput {
    param([Parameter(Mandatory = $true)][string]$Path)

    $content = @(
        'MODEL_CHECK_OK'
        'model: deepseek-v4-flash'
        'provider: deepseek'
        'reasoning effort: high'
        'approval: never'
        'sandbox: read-only'
    ) -join [System.Environment]::NewLine

    [System.IO.File]::WriteAllText($Path, $content, [System.Text.Encoding]::UTF8)
}

function Get-TestFingerprint {
    param([Parameter(Mandatory = $true)][string]$Root)

    $files = @(Get-ChildItem -LiteralPath $Root -File -Filter 'requirements*.txt' | Sort-Object -Property Name)
    if ($files.Count -eq 0) {
        throw 'No requirements*.txt files were found.'
    }

    $sha = [System.Security.Cryptography.SHA256]::Create()
    $builder = New-Object System.Text.StringBuilder

    try {
        foreach ($file in $files) {
            $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
            $fileHashBytes = $sha.ComputeHash($bytes)
            $fileHash = [System.BitConverter]::ToString($fileHashBytes).Replace('-', '')
            [void]$builder.AppendLine(($file.Name + ':' + $fileHash))
        }

        $combinedBytes = [System.Text.Encoding]::UTF8.GetBytes($builder.ToString())
        $combinedHashBytes = $sha.ComputeHash($combinedBytes)
        return [System.BitConverter]::ToString($combinedHashBytes).Replace('-', '')
    }
    finally {
        $sha.Dispose()
    }
}

function Initialize-TestGitRepo {
    param(
        [Parameter(Mandatory = $true)][string]$WorkingRepo,
        [Parameter(Mandatory = $true)][string]$BareRemote,
        [Parameter(Mandatory = $true)][string]$Branch
    )

    New-Item -ItemType Directory -Path (Split-Path -Parent $WorkingRepo) -Force | Out-Null
    git init --bare -q $BareRemote
    if ($LASTEXITCODE -ne 0) {
        throw "git init --bare failed for $BareRemote"
    }

    git init -q $WorkingRepo
    if ($LASTEXITCODE -ne 0) {
        throw "git init failed for $WorkingRepo"
    }

    git -C $WorkingRepo config user.email 'spa-dev-tools-test@example.com'
    git -C $WorkingRepo config user.name 'SPA Dev Tools Test'
    Set-Content -LiteralPath (Join-Path $WorkingRepo 'README.md') -Value 'temporary test repository' -NoNewline
    git -C $WorkingRepo add -A
    git -C $WorkingRepo commit -q -m 'initial commit'
    if ($LASTEXITCODE -ne 0) {
        throw "git commit failed for $WorkingRepo"
    }

    git -C $WorkingRepo branch -M $Branch
    if ($LASTEXITCODE -ne 0) {
        throw "git branch rename failed for $WorkingRepo"
    }

    git -C $WorkingRepo remote add origin $BareRemote
    if ($LASTEXITCODE -ne 0) {
        throw "git remote add failed for $WorkingRepo"
    }

    git -C $WorkingRepo push -q -u origin $Branch
    if ($LASTEXITCODE -ne 0) {
        throw "git push failed for $WorkingRepo"
    }
}

$expectedFiles = @(
    'spa-check.ps1',
    'spa-deps-sync.ps1',
    'agent-prompt-header.txt',
    'README.md',
    'tests\test-spa-check.ps1'
)

foreach ($file in $expectedFiles) {
    $filePath = Join-Path $devTools $file
    Assert-True (Test-Path -LiteralPath $filePath -PathType Leaf) "expected file exists: dev-tools\$file"
}

if ($failures.Count -gt 0) {
    Write-Host ''
    Write-Host "RED: $($failures.Count) required tooling file(s) are missing."
    Write-Host 'This is expected before implementation.'
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}

$spaCheckText = Read-ToolText -Path $spaCheck
$spaDepsSyncText = Read-ToolText -Path $spaDepsSync
$promptHeaderText = Read-ToolText -Path $promptHeader
$readmeText = Read-ToolText -Path $readme

Assert-True ([regex]::IsMatch($spaCheckText, '\$Target\s*=\s*[''"]Backend[''"]', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) 'spa-check default target is Backend'

$spaCheckForbiddenMutationPatterns = @(
    '\bgit\s+(pull|fetch|reset|switch|checkout|merge|rebase|clean|commit|push)\b'
)

foreach ($pattern in $spaCheckForbiddenMutationPatterns) {
    Assert-True (-not [regex]::IsMatch($spaCheckText, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) "spa-check avoids prohibited Git mutation command: $pattern"
}

Assert-NotContains $spaCheckText 'Set-ExecutionPolicy' 'spa-check does not change Windows execution policy'
Assert-NotContains $spaCheckText 'pytest' 'spa-check does not perform pytest checks'
Assert-NotContains $spaCheckText '--version' 'spa-check does not perform Python/pytest version checks'
Assert-NotContains $spaCheckText 'pip' 'spa-check does not invoke pip'
Assert-Contains $spaCheckText 'ls-remote' 'spa-check uses read-only ls-remote remote check'

Assert-Contains $spaCheckText 'MODEL_CHECK_OK' 'spa-check integrates Codex model verification'
Assert-Contains $spaCheckText '--ask-for-approval' 'spa-check invokes Codex with approval flag'
Assert-Contains $spaCheckText 'never' 'spa-check invokes Codex with approval never'
Assert-Contains $spaCheckText '--sandbox' 'spa-check invokes Codex with sandbox flag'
Assert-Contains $spaCheckText 'read-only' 'spa-check invokes Codex with read-only sandbox'
Assert-NotContains $spaCheckText 'danger-full-access' 'spa-check never uses danger-full-access'

Assert-NotContains $readmeText 'spa-model-check' 'README does not require a separate model-check command'

Assert-Contains $spaDepsSyncText $permanentPython 'spa-deps-sync references the fixed permanent Python'
Assert-Contains $spaDepsSyncText 'RegisterCurrent' 'spa-deps-sync supports RegisterCurrent'
Assert-Contains $spaDepsSyncText 'Force' 'spa-deps-sync supports Force'

$pipCheckIndex = $spaDepsSyncText.IndexOf('pip check', [System.StringComparison]::OrdinalIgnoreCase)
$markerWriteIndex = $spaDepsSyncText.IndexOf('WriteAllText', [System.StringComparison]::OrdinalIgnoreCase)
Assert-True (($pipCheckIndex -ge 0) -and ($markerWriteIndex -ge 0) -and ($pipCheckIndex -lt $markerWriteIndex)) 'spa-deps-sync RegisterCurrent runs pip check before writing marker'

$installerPatterns = @('\bwinget\b', '\bchoco\b', '\bmsiexec\b', 'python\.org', 'Install-Python', 'Install-Package')
foreach ($pattern in $installerPatterns) {
    Assert-True (-not [regex]::IsMatch($spaDepsSyncText, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) "spa-deps-sync avoids Python/package installer behavior: $pattern"
}

Assert-Contains $promptHeaderText 'C:\GitHub\backendtest' 'prompt header contains backend path'
Assert-Contains $promptHeaderText 'C:\GitHub\stock-price-alert' 'prompt header contains frontend/docs path'
Assert-Contains $promptHeaderText $permanentPython 'prompt header contains permanent Python path'
Assert-Contains $promptHeaderText 'C:\venvs\spa-m1\Scripts\python.exe -m pytest -q' 'prompt header contains canonical full-test path'

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('spa-simplified-test-' + [guid]::NewGuid().ToString('N'))

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $frontendRepo = Join-Path $tempRoot 'frontend'
    $frontendRemote = Join-Path $tempRoot 'frontend-remote.git'
    $codexMock = Join-Path $tempRoot 'codex-mock.txt'
    New-MockCodexOutput -Path $codexMock

    Initialize-TestGitRepo -WorkingRepo $frontendRepo -BareRemote $frontendRemote -Branch $expectedBranch

    $frontendArgs = @(
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        $spaCheck,
        '-Target',
        'Frontend',
        '-FrontendPath',
        $frontendRepo,
        '-CodexOutputPath',
        $codexMock,
        '-ExpectedBranch',
        $expectedBranch
    )

    $syncedOutput = & powershell.exe @frontendArgs 2>&1 | Out-String
    $syncedCode = $LASTEXITCODE
    Assert-True ($syncedCode -eq 0) 'spa-check reports READY YES as exit 0 for a synced clean temporary repo'
    Assert-True ([regex]::IsMatch($syncedOutput, 'READY\s+YES')) 'spa-check output contains READY YES for a synced clean repo'

    $codexShimDir = Join-Path $tempRoot 'codex-shim'
    New-Item -ItemType Directory -Path $codexShimDir -Force | Out-Null
    @'
@echo off
echo MODEL_CHECK_OK
echo model: deepseek-v4-flash
echo provider: deepseek
echo reasoning effort: high
echo approval: never
echo sandbox: read-only
exit /b 9
'@ | Set-Content -LiteralPath (Join-Path $codexShimDir 'codex.cmd') -Encoding ASCII
    $failedModelArgs = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $spaCheck,
        '-Target', 'Frontend', '-FrontendPath', $frontendRepo,
        '-ExpectedBranch', $expectedBranch,
        '-ExpectedModel', 'deepseek-v4-flash', '-ExpectedProvider', 'deepseek', '-ExpectedReasoning', 'high'
    )
    $previousPath = $env:PATH
    $env:PATH = $codexShimDir + [System.IO.Path]::PathSeparator + $previousPath
    try {
        $failedModelOutput = & powershell.exe @failedModelArgs 2>&1 | Out-String
        $failedModelCode = $LASTEXITCODE
    }
    finally {
        $env:PATH = $previousPath
    }
    Assert-True ($failedModelCode -ne 0) 'spa-check rejects an otherwise valid model header when the model command exits nonzero'
    Assert-True ([regex]::IsMatch($failedModelOutput, 'MODEL CHECK\s+FAIL\s+exit=9')) 'spa-check reports the nonzero model command exit code'

    $realGit = (Get-Command git -CommandType Application).Source
    $gitShimDir = Join-Path $tempRoot 'git-shim'
    New-Item -ItemType Directory -Path $gitShimDir -Force | Out-Null
    $gitShim = Join-Path $gitShimDir 'git.cmd'
    @"
@echo off
if /I "%~3"=="status" exit /b 17
"$realGit" %*
exit /b %ERRORLEVEL%
"@ | Set-Content -LiteralPath $gitShim -Encoding ASCII
    $previousPath = $env:PATH
    $env:PATH = $gitShimDir + [System.IO.Path]::PathSeparator + $previousPath
    try {
        $statusFailureOutput = & powershell.exe @frontendArgs 2>&1 | Out-String
        $statusFailureCode = $LASTEXITCODE
    }
    finally {
        $env:PATH = $previousPath
    }
    Assert-True ($statusFailureCode -ne 0) 'spa-check fails closed when git status fails'
    Assert-True ([regex]::IsMatch($statusFailureOutput, 'WORKTREE\s+FAIL\s+CHECK FAILED')) 'spa-check reports git status failure instead of CLEAN'

    $dirtyFile = Join-Path $frontendRepo 'dirty.txt'
    Set-Content -LiteralPath $dirtyFile -Value 'dirty' -NoNewline
    $dirtyOutput = & powershell.exe @frontendArgs 2>&1 | Out-String
    $dirtyCode = $LASTEXITCODE
    Assert-True ($dirtyCode -ne 0) 'spa-check reports READY NO as nonzero when the selected repo is dirty'
    Assert-True ([regex]::IsMatch($dirtyOutput, 'READY\s+NO')) 'spa-check output contains READY NO for a dirty repo'

    Remove-Item -LiteralPath $dirtyFile -Force
    Set-Content -LiteralPath (Join-Path $frontendRepo 'local-only.txt') -Value 'local-only' -NoNewline
    git -C $frontendRepo add -A
    git -C $frontendRepo commit -q -m 'local only commit'
    if ($LASTEXITCODE -ne 0) {
        throw 'Local commit for remote-different test failed.'
    }

    $differentOutput = & powershell.exe @frontendArgs 2>&1 | Out-String
    $differentCode = $LASTEXITCODE
    Assert-True ($differentCode -ne 0) 'spa-check reports READY NO as nonzero when local and remote differ'
    Assert-True ([regex]::IsMatch($differentOutput, 'READY\s+NO')) 'spa-check output contains READY NO when local and remote differ'
    Assert-True ([regex]::IsMatch($differentOutput, 'REMOTE\s+\S+\s+DIFFERENT')) 'spa-check reports REMOTE DIFFERENT when local and remote differ'

    $backendRepo = Join-Path $tempRoot 'backend'
    $backendRemote = Join-Path $tempRoot 'backend-remote.git'
    $depsMarker = Join-Path $tempRoot 'deps-marker.txt'
    $missingFrontend = Join-Path $tempRoot 'missing-frontend'

    Initialize-TestGitRepo -WorkingRepo $backendRepo -BareRemote $backendRemote -Branch $expectedBranch
    Set-Content -LiteralPath (Join-Path $backendRepo 'requirements-dev.txt') -Value 'pytest==8.0.0' -NoNewline
    git -C $backendRepo add -A
    git -C $backendRepo commit -q -m 'add requirements manifest'
    if ($LASTEXITCODE -ne 0) {
        throw 'Backend requirements commit failed.'
    }
    git -C $backendRepo push -q origin $expectedBranch
    if ($LASTEXITCODE -ne 0) {
        throw 'Backend requirements push failed.'
    }

    $testFingerprint = Get-TestFingerprint -Root $backendRepo
    [System.IO.File]::WriteAllText($depsMarker, $testFingerprint, [System.Text.Encoding]::ASCII)

    $backendArgs = @(
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        $spaCheck,
        '-Target',
        'Backend',
        '-BackendPath',
        $backendRepo,
        '-FrontendPath',
        $missingFrontend,
        '-DependencyMarkerPath',
        $depsMarker,
        '-CodexOutputPath',
        $codexMock,
        '-ExpectedBranch',
        $expectedBranch
    )

    $backendOutput = & powershell.exe @backendArgs 2>&1 | Out-String
    $backendCode = $LASTEXITCODE
    Assert-True ($backendCode -eq 0) 'spa-check Backend readiness does not require the inactive frontend repo'
    Assert-True ([regex]::IsMatch($backendOutput, 'DEPS\s+OK\s+CURRENT')) 'spa-check Backend reports DEPS CURRENT when marker matches'
}
finally {
    if ($tempRoot -and (Test-Path -LiteralPath $tempRoot)) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ''
if ($failures.Count -eq 0) {
    Write-Host 'GREEN: all simplified spa-check tests passed.'
    exit 0
}
else {
    Write-Host "RED: $($failures.Count) test(s) failed."
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}
