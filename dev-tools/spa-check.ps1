[CmdletBinding()]
param(
    [string]$BackendPath = 'C:\GitHub\backendtest',
    [string]$FrontendPath = 'C:\GitHub\stock-price-alert',
    [string]$PythonPath = 'C:\venvs\spa-m1\Scripts\python.exe',
    [string]$ExpectedBranch = 'feature/investment-operating-system-m1'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

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

function Get-RepoStatus {
    param(
        [string]$Path,
        [string]$Label
    )

    $result = [pscustomobject]@{
        Label    = $Label
        Path     = $Path
        Exists   = $false
        IsGit    = $false
        Branch   = ''
        ShortHead = ''
        Clean    = $false
        Upstream = ''
        Ahead    = $null
        Behind   = $null
        Ok       = $false
        Reason   = ''
    }

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Container)) {
        $result.Reason = 'path missing'
        return $result
    }

    $result.Exists = $true
    if (-not (Test-GitRepo -Path $Path)) {
        $result.Reason = 'not a git repo'
        return $result
    }

    $result.IsGit = $true
    $result.Branch = Get-GitValue -Path $Path -Arguments @('rev-parse', '--abbrev-ref', 'HEAD')
    $result.ShortHead = Get-GitValue -Path $Path -Arguments @('rev-parse', '--short', 'HEAD')

    $porcelain = @(& git -C $Path status --porcelain=v1 2>$null)
    $result.Clean = ($porcelain.Count -eq 0)

    $upstream = Get-GitValue -Path $Path -Arguments @('rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}')
    if (-not [string]::IsNullOrWhiteSpace($upstream)) {
        $result.Upstream = $upstream
        $counts = Get-GitValue -Path $Path -Arguments @('rev-list', '--left-right', '--count', 'HEAD...@{u}')
        if (-not [string]::IsNullOrWhiteSpace($counts)) {
            $parts = $counts -split '\s+'
            if ($parts.Count -eq 2) {
                $result.Ahead = $parts[0]
                $result.Behind = $parts[1]
            }
        }
    }

    $expectedBranchOk = ($result.Branch -eq $ExpectedBranch)
    $result.Ok = $expectedBranchOk -and $result.Clean

    if (-not $expectedBranchOk) {
        $result.Reason = "branch '$($result.Branch)' is not '$ExpectedBranch'"
    }
    elseif (-not $result.Clean) {
        $result.Reason = 'working tree is dirty'
    }

    return $result
}

function Format-RepoLine {
    param([pscustomobject]$Repo)

    $state = if ($Repo.Ok) { 'OK  ' } else { 'FAIL' }
    $branch = if ([string]::IsNullOrWhiteSpace($Repo.Branch)) { '-' } else { $Repo.Branch }
    $head = if ([string]::IsNullOrWhiteSpace($Repo.ShortHead)) { '-' } else { $Repo.ShortHead }
    $clean = if ($Repo.Clean) { 'CLEAN' } else { 'DIRTY' }

    $line = '{0,-10} {1} {2}  {3}  {4}' -f $Repo.Label, $state, $branch, $head, $clean
    if ($Repo.IsGit) {
        if ([string]::IsNullOrWhiteSpace($Repo.Upstream)) {
            $line += '  UPSTREAM none'
        }
        else {
            $line += "  UPSTREAM $($Repo.Upstream) AHEAD $($Repo.Ahead) BEHIND $($Repo.Behind)"
        }
    }

    return $line
}

$backend = Get-RepoStatus -Path $BackendPath -Label 'BACKEND'
$frontend = Get-RepoStatus -Path $FrontendPath -Label 'FRONTEND'

$pythonOk = $false
$pythonVersionText = 'unavailable'
if (Test-Path -LiteralPath $PythonPath -PathType Leaf) {
    $versionOutput = & $PythonPath --version 2>&1 | Out-String
    $versionText = $versionOutput.Trim()
    if ($versionText -match '^Python\s+3\.12\.\d+') {
        $pythonOk = $true
        $pythonVersionText = $versionText
    }
    else {
        $pythonVersionText = if ([string]::IsNullOrWhiteSpace($versionText)) { 'Python version not 3.12.x' } else { $versionText }
    }
}
else {
    $pythonVersionText = 'python path missing'
}

$pytestOk = $false
$pytestVersionText = 'unavailable'
if ($pythonOk) {
    $pytestOutput = & $PythonPath -m pytest --version 2>&1 | Out-String
    $pytestText = $pytestOutput.Trim()
    if ($pytestText -match 'pytest\s+\d+\.\d+(\.\d+)?') {
        $pytestOk = $true
        $pytestVersionText = ($pytestText -split "`r?`n")[0]
    }
    else {
        $pytestVersionText = if ([string]::IsNullOrWhiteSpace($pytestText)) { 'pytest unavailable' } else { $pytestText }
    }
}

$ready = $backend.Ok -and $frontend.Ok -and $pythonOk -and $pytestOk

Write-Output (Format-RepoLine -Repo $backend)
if (-not $backend.Ok -and -not [string]::IsNullOrWhiteSpace($backend.Reason)) {
    Write-Output ("BACKEND    reason: {0}" -f $backend.Reason)
}
Write-Output (Format-RepoLine -Repo $frontend)
if (-not $frontend.Ok -and -not [string]::IsNullOrWhiteSpace($frontend.Reason)) {
    Write-Output ("FRONTEND   reason: {0}" -f $frontend.Reason)
}

$pythonState = if ($pythonOk) { 'OK  ' } else { 'FAIL' }
Write-Output ('{0,-10} {1} {2}' -f 'PYTHON', $pythonState, $pythonVersionText)

$pytestState = if ($pytestOk) { 'OK  ' } else { 'FAIL' }
Write-Output ('{0,-10} {1} {2}' -f 'PYTEST', $pytestState, $pytestVersionText)

if ($ready) {
    Write-Output 'READY     YES'
    exit 0
}
else {
    Write-Output 'READY     NO'
    exit 1
}
