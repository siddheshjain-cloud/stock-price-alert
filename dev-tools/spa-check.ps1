[CmdletBinding()]
param(
    [ValidateSet('Backend', 'Frontend')]
    [string]$Target = 'Backend',
    [string]$BackendPath = 'C:\GitHub\backendtest',
    [string]$FrontendPath = 'C:\GitHub\stock-price-alert',
    [string]$ExpectedBranch = 'feature/investment-operating-system-m1',
    [string]$ExpectedModel = '',
    [string]$ExpectedProvider = '',
    [string]$ExpectedReasoning = '',
    [string]$ExpectedApproval = 'never',
    [string]$ExpectedSandbox = 'read-only',
    [string]$CodexProfile = '',
    [string]$CodexOutputPath = '',
    [string]$DependencyMarkerPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$repoPath = if ($Target -eq 'Backend') { $BackendPath } else { $FrontendPath }

function Test-GitRepo {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Container)) {
        return $false
    }

    $inside = & git -C $Path rev-parse --is-inside-work-tree 2>$null
    return ($LASTEXITCODE -eq 0 -and ($inside -join '') -eq 'true')
}

function Get-GitValue {
    param(
        [string]$Path,
        [string[]]$Arguments
    )

    $output = & git -C $Path @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    return ($output -join ' ').Trim()
}

function Get-FirstRegexValue {
    param(
        [string]$Text,
        [string]$Pattern
    )

    $match = [regex]::Match($Text, $Pattern)
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }

    return ''
}

function Get-DependencyFingerprint {
    param([string]$Root)

    $files = @(Get-ChildItem -LiteralPath $Root -File -Filter 'requirements*.txt' | Sort-Object -Property Name)
    if ($files.Count -eq 0) {
        throw 'No requirements*.txt files were found in the backend root.'
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

Write-Output 'SPA DEVELOPMENT PREFLIGHT'
Write-Output '------------------------------------------------------------'
Write-Output ('TARGET     {0}' -f $Target.ToUpperInvariant())

$isGit = $false
$branch = ''
$localFull = ''
$localShort = ''
$worktreeClean = $false
$repoOk = $false

if ([string]::IsNullOrWhiteSpace($repoPath) -or -not (Test-Path -LiteralPath $repoPath -PathType Container)) {
    Write-Output 'BRANCH     FAIL path missing'
    Write-Output 'WORKTREE   FAIL UNAVAILABLE'
    Write-Output 'LOCAL      -'
}
elseif (-not (Test-GitRepo -Path $repoPath)) {
    Write-Output 'BRANCH     FAIL not a git repo'
    Write-Output 'WORKTREE   FAIL UNAVAILABLE'
    Write-Output 'LOCAL      -'
}
else {
    $isGit = $true
    $branch = Get-GitValue -Path $repoPath -Arguments @('rev-parse', '--abbrev-ref', 'HEAD')
    $localFull = Get-GitValue -Path $repoPath -Arguments @('rev-parse', 'HEAD')
    $localShort = Get-GitValue -Path $repoPath -Arguments @('rev-parse', '--short', 'HEAD')

    $porcelain = @(& git -C $repoPath status --porcelain=v1 2>$null)
    $statusCode = $LASTEXITCODE
    $worktreeClean = ($statusCode -eq 0 -and $porcelain.Count -eq 0)

    $branchText = if ([string]::IsNullOrWhiteSpace($branch)) { '-' } else { $branch }
    if ($branch -eq $ExpectedBranch) {
        Write-Output ('BRANCH     OK   {0}' -f $branchText)
    }
    else {
        Write-Output ('BRANCH     FAIL {0}' -f $branchText)
    }

    if ($statusCode -ne 0) {
        Write-Output 'WORKTREE   FAIL CHECK FAILED'
    }
    elseif ($worktreeClean) {
        Write-Output 'WORKTREE   OK   CLEAN'
    }
    else {
        Write-Output 'WORKTREE   FAIL DIRTY'
    }

    $shortText = if ([string]::IsNullOrWhiteSpace($localShort)) { '-' } else { $localShort }
    Write-Output ('LOCAL      {0}' -f $shortText)

    $repoOk = ($branch -eq $ExpectedBranch) -and $worktreeClean
}

$remoteOk = $false
if ($isGit -and -not [string]::IsNullOrWhiteSpace($branch)) {
    $remoteRef = 'refs/heads/' + $branch
    $remoteLines = @(& git -C $repoPath ls-remote origin $remoteRef 2>$null)
    $remoteCode = $LASTEXITCODE
    $remoteSha = ''

    if ($remoteCode -eq 0 -and $remoteLines.Count -ge 1) {
        $remoteSha = (($remoteLines[0] -split '\s+')[0]).Trim()
    }

    if ([string]::IsNullOrWhiteSpace($remoteSha)) {
        Write-Output 'REMOTE     FAIL CHECK FAILED'
    }
    elseif ($remoteSha -eq $localFull) {
        Write-Output 'REMOTE     OK   SYNCED'
        $remoteOk = $true
    }
    else {
        Write-Output 'REMOTE     FAIL DIFFERENT'
    }
}
else {
    Write-Output 'REMOTE     FAIL CHECK FAILED'
}

$depsOk = $false
if ($Target -eq 'Frontend') {
    Write-Output 'DEPS       OK   NOT APPLICABLE TO CURRENT M1 FRONTEND CHECK'
    $depsOk = $true
}
else {
    $requirements = @()
    if (Test-Path -LiteralPath $repoPath -PathType Container) {
        $requirements = @(Get-ChildItem -LiteralPath $repoPath -File -Filter 'requirements*.txt' -ErrorAction SilentlyContinue | Sort-Object -Property Name)
    }

    $fingerprint = ''
    $fingerprintError = ''
    if ($requirements.Count -eq 0) {
        $fingerprintError = 'NO REQUIREMENTS MANIFEST'
    }
    else {
        try {
            $fingerprint = Get-DependencyFingerprint -Root $repoPath
        }
        catch {
            $fingerprintError = $_.Exception.Message
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($fingerprintError)) {
        Write-Output ('DEPS       FAIL {0}' -f $fingerprintError)
        Write-Output 'ACTION     run spa-deps-sync.ps1 -RegisterCurrent once'
    }
    else {
        $markerPath = if (-not [string]::IsNullOrWhiteSpace($DependencyMarkerPath)) {
            $DependencyMarkerPath
        }
        else {
            Join-Path 'C:\venvs\spa-m1' '.spa-m1-deps.fingerprint'
        }

        if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
            Write-Output 'DEPS       FAIL REGISTRATION NEEDED'
            Write-Output 'ACTION     run spa-deps-sync.ps1 -RegisterCurrent once'
        }
        else {
            $storedFingerprint = ([System.IO.File]::ReadAllText($markerPath)).Trim()
            if ($storedFingerprint -eq $fingerprint) {
                Write-Output 'DEPS       OK   CURRENT'
                $depsOk = $true
            }
            else {
                Write-Output 'DEPS       FAIL SYNC NEEDED'
                Write-Output 'ACTION     run spa-deps-sync.ps1'
            }
        }
    }
}

$model = ''
$provider = ''
$reasoning = ''
$approval = ''
$sandbox = ''
$modelOk = $false
$codexText = ''
$modelCommandExitCode = 1

if (-not [string]::IsNullOrWhiteSpace($CodexOutputPath)) {
    if (Test-Path -LiteralPath $CodexOutputPath -PathType Leaf) {
        $codexText = [System.IO.File]::ReadAllText($CodexOutputPath)
        $modelCommandExitCode = 0
    }
}
else {
    $codexLauncher = $null
    foreach ($candidate in @('codex.cmd', 'codex.exe')) {
        $resolved = @(Get-Command $candidate -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($resolved) {
            $codexLauncher = $resolved[0].Source
            break
        }
    }

    if (-not $codexLauncher) {
        $resolved = @(Get-Command codex -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($resolved) {
            $codexLauncher = $resolved[0].Source
        }
    }

    if ($codexLauncher) {
        $codexPrompt = 'Reply with exactly: MODEL_CHECK_OK. Do not inspect, modify, or execute anything in the repository.'
        $codexArgs = @()
        if (-not [string]::IsNullOrWhiteSpace($CodexProfile)) {
            $codexArgs += @('--profile', $CodexProfile)
        }
        if (-not [string]::IsNullOrWhiteSpace($ExpectedModel)) {
            $codexArgs += @('--model', $ExpectedModel)
        }
        if (-not [string]::IsNullOrWhiteSpace($ExpectedProvider)) {
            $codexArgs += @('-c', ('model_provider="{0}"' -f $ExpectedProvider))
        }
        if (-not [string]::IsNullOrWhiteSpace($ExpectedReasoning)) {
            $codexArgs += @('-c', ('model_reasoning_effort="{0}"' -f $ExpectedReasoning))
        }
        # Probe with the route's effective sandbox so preflight validates what the
        # launched task requests instead of the model profile's stored default.
        $codexArgs += @(
            '--ask-for-approval',
            'never',
            '--sandbox',
            $ExpectedSandbox,
            'exec',
            '--skip-git-repo-check',
            '-'
        )

        try {
            Push-Location -LiteralPath ([System.IO.Path]::GetTempPath())
            $codexText = ($codexPrompt | & $codexLauncher @codexArgs 2>&1 | Out-String)
            $modelCommandExitCode = $LASTEXITCODE
        }
        catch {
            $codexText = "Codex invocation failed: $($_.Exception.Message)"
            $modelCommandExitCode = if ($LASTEXITCODE -is [int] -and $LASTEXITCODE -ne 0) { $LASTEXITCODE } else { 1 }
        }
        finally {
            Pop-Location
        }
    }
}

if ($codexText) {
    $model = Get-FirstRegexValue -Text $codexText -Pattern '(?im)^\s*model:\s*(.+)$'
    $provider = Get-FirstRegexValue -Text $codexText -Pattern '(?im)^\s*provider:\s*(.+)$'
    $reasoning = Get-FirstRegexValue -Text $codexText -Pattern '(?im)^\s*reasoning(?:_effort| effort):\s*(.+)$'
    $parsedApproval = Get-FirstRegexValue -Text $codexText -Pattern '(?im)^\s*approval:\s*(.+)$'
    $parsedSandbox = Get-FirstRegexValue -Text $codexText -Pattern '(?im)^\s*sandbox:\s*(.+)$'

    if (-not [string]::IsNullOrWhiteSpace($parsedApproval)) {
        $approval = $parsedApproval
    }
    if (-not [string]::IsNullOrWhiteSpace($parsedSandbox)) {
        $sandbox = $parsedSandbox
    }

    $expectedModelOk = [string]::IsNullOrWhiteSpace($ExpectedModel) -or $model.Equals($ExpectedModel, [System.StringComparison]::OrdinalIgnoreCase)
    $expectedProviderOk = [string]::IsNullOrWhiteSpace($ExpectedProvider) -or $provider.Equals($ExpectedProvider, [System.StringComparison]::OrdinalIgnoreCase)
    $expectedReasoningOk = [string]::IsNullOrWhiteSpace($ExpectedReasoning) -or $reasoning.Equals($ExpectedReasoning, [System.StringComparison]::OrdinalIgnoreCase)
    $expectedApprovalOk = [string]::IsNullOrWhiteSpace($ExpectedApproval) -or $approval.Equals($ExpectedApproval, [System.StringComparison]::OrdinalIgnoreCase)
    $expectedSandboxOk = [string]::IsNullOrWhiteSpace($ExpectedSandbox) -or $sandbox.Equals($ExpectedSandbox, [System.StringComparison]::OrdinalIgnoreCase)
    $modelOk = ($modelCommandExitCode -eq 0) -and
               ($codexText.IndexOf('MODEL_CHECK_OK', [System.StringComparison]::Ordinal) -ge 0) -and
               (-not [string]::IsNullOrWhiteSpace($model)) -and
               (-not [string]::IsNullOrWhiteSpace($provider)) -and
               $expectedModelOk -and $expectedProviderOk -and $expectedReasoningOk -and
               $expectedApprovalOk -and $expectedSandboxOk
}

$modelText = if ([string]::IsNullOrWhiteSpace($model)) { 'unavailable' } else { $model }
$providerText = if ([string]::IsNullOrWhiteSpace($provider)) { 'unavailable' } else { $provider }
$reasoningText = if ([string]::IsNullOrWhiteSpace($reasoning)) { '-' } else { $reasoning }
$approvalText = if ([string]::IsNullOrWhiteSpace($approval)) { 'unavailable' } else { $approval }
$sandboxText = if ([string]::IsNullOrWhiteSpace($sandbox)) { 'unavailable' } else { $sandbox }

if (-not [string]::IsNullOrWhiteSpace($ExpectedModel) -and -not $modelText.Equals($ExpectedModel, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Output ('MODEL      FAIL expected={0} actual={1}' -f $ExpectedModel, $modelText)
}
else {
    Write-Output ('MODEL      {0}' -f $modelText)
}
if (-not [string]::IsNullOrWhiteSpace($ExpectedProvider) -and -not $providerText.Equals($ExpectedProvider, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Output ('PROVIDER   FAIL expected={0} actual={1}' -f $ExpectedProvider, $providerText)
}
else {
    Write-Output ('PROVIDER   {0}' -f $providerText)
}
if (-not [string]::IsNullOrWhiteSpace($ExpectedReasoning) -and -not $reasoningText.Equals($ExpectedReasoning, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Output ('REASONING  FAIL expected={0} actual={1}' -f $ExpectedReasoning, $reasoningText)
}
else {
    Write-Output ('REASONING  {0}' -f $reasoningText)
}
if ($modelCommandExitCode -ne 0) {
    Write-Output ('MODEL CHECK FAIL exit={0}' -f $modelCommandExitCode)
}
if (-not [string]::IsNullOrWhiteSpace($ExpectedApproval) -and -not $approvalText.Equals($ExpectedApproval, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Output ('APPROVAL   FAIL expected={0} actual={1}' -f $ExpectedApproval, $approvalText)
}
else {
    Write-Output ('APPROVAL   {0}' -f $approvalText)
}
if (-not [string]::IsNullOrWhiteSpace($ExpectedSandbox) -and -not $sandboxText.Equals($ExpectedSandbox, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Output ('SANDBOX    FAIL expected={0} actual={1}' -f $ExpectedSandbox, $sandboxText)
}
else {
    Write-Output ('SANDBOX    {0}' -f $sandboxText)
}

$ready = $repoOk -and $remoteOk -and $depsOk -and $modelOk

Write-Output '------------------------------------------------------------'
if ($ready) {
    Write-Output 'READY      YES'
    exit 0
}

Write-Output 'READY      NO'
exit 1
