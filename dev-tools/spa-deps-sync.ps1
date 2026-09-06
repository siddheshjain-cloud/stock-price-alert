[CmdletBinding()]
param(
    [string]$BackendPath = 'C:\GitHub\backendtest',
    [string]$PythonPath = 'C:\venvs\spa-m1\Scripts\python.exe',
    [switch]$RegisterCurrent,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$venvRoot = Split-Path -Parent (Split-Path -Parent $PythonPath)
$markerPath = Join-Path $venvRoot '.spa-m1-deps.fingerprint'
$requirementsDev = Join-Path $BackendPath 'requirements-dev.txt'

if (-not (Test-Path -LiteralPath $PythonPath -PathType Leaf)) {
    Write-Error "Permanent Python was not found: $PythonPath"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($BackendPath) -or -not (Test-Path -LiteralPath $BackendPath -PathType Container)) {
    Write-Error "Backend path is missing: $BackendPath"
    exit 1
}

function Get-DependenciesFingerprint {
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

try {
    $currentFingerprint = Get-DependenciesFingerprint -Root $BackendPath
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}

$storedFingerprint = ''
if (Test-Path -LiteralPath $markerPath -PathType Leaf) {
    $storedFingerprint = ([System.IO.File]::ReadAllText($markerPath)).Trim()
}

if ($RegisterCurrent) {
    $pipCheckOutput = & $PythonPath -m pip check 2>&1
    $pipCheckCode = $LASTEXITCODE
    Write-Output ($pipCheckOutput | Out-String)

    if ($pipCheckCode -ne 0) {
        Write-Error 'pip check failed; dependency fingerprint marker was not written.'
        exit 1
    }

    [System.IO.File]::WriteAllText($markerPath, $currentFingerprint, [System.Text.Encoding]::ASCII)
    Write-Output 'DEPENDENCIES REGISTERED'
    exit 0
}

if ($storedFingerprint -eq $currentFingerprint -and -not $Force) {
    Write-Output 'DEPENDENCIES CURRENT'
    exit 0
}

if (-not (Test-Path -LiteralPath $requirementsDev -PathType Leaf)) {
    Write-Error "requirements-dev.txt was not found in the backend root: $requirementsDev"
    exit 1
}

$installArgs = @(
    '-m',
    'pip',
    'install',
    '-r',
    $requirementsDev
)

$installOutput = & $PythonPath @installArgs 2>&1
$installCode = $LASTEXITCODE
Write-Output ($installOutput | Out-String)

if ($installCode -ne 0) {
    Write-Error 'pip install failed; dependency fingerprint marker was not updated.'
    exit 1
}

$checkOutput = & $PythonPath -m pip check 2>&1
$checkCode = $LASTEXITCODE
Write-Output ($checkOutput | Out-String)

if ($checkCode -ne 0) {
    Write-Error 'pip check failed; dependency fingerprint marker was not updated.'
    exit 1
}

[System.IO.File]::WriteAllText($markerPath, $currentFingerprint, [System.Text.Encoding]::ASCII)
Write-Output 'DEPENDENCIES SYNCED'
exit 0
