[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$CodexCommand,
    [string]$Profile = '',
    [string]$Model = '',
    [Parameter(Mandatory = $true)][string]$Provider,
    [Parameter(Mandatory = $true)][string]$Reasoning,
    [Parameter(Mandatory = $true)][string]$Sandbox,
    [Parameter(Mandatory = $true)][string]$WorkingDirectory,
    [Parameter(Mandatory = $true)][string]$AdditionalDirectory,
    [Parameter(Mandatory = $true)][string]$PromptPath,
    [Parameter(Mandatory = $true)][string]$OutputLastMessagePath,
    [switch]$ReadOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

if ($Provider -notin @('deepseek', 'claude')) {
    Write-Output ("AUTO-DEBUG FAIL: unsupported debugger provider: {0}" -f $Provider)
    exit 2
}
if (-not (Test-Path -LiteralPath $PromptPath -PathType Leaf)) {
    Write-Output ("AUTO-DEBUG FAIL: debugger prompt is missing: {0}" -f $PromptPath)
    exit 2
}
if (-not (Test-Path -LiteralPath $CodexCommand -PathType Leaf)) {
    Write-Output ("AUTO-DEBUG FAIL: debugger command is missing: {0}" -f $CodexCommand)
    exit 2
}
if ([string]::IsNullOrWhiteSpace($WorkingDirectory) -or -not (Test-Path -LiteralPath $WorkingDirectory -PathType Container)) {
    Write-Output ("AUTO-DEBUG FAIL: working repository is missing: {0}" -f $WorkingDirectory)
    exit 2
}
if ([string]::IsNullOrWhiteSpace($AdditionalDirectory) -or
    -not (Test-Path -LiteralPath $AdditionalDirectory -PathType Container) -or
    $AdditionalDirectory.Equals($WorkingDirectory, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Output ("AUTO-DEBUG FAIL: additional repository must exist and differ from the working repository: {0}" -f $AdditionalDirectory)
    exit 2
}
if ($Provider -eq 'deepseek' -and [string]::IsNullOrWhiteSpace($Model)) {
    Write-Output 'AUTO-DEBUG FAIL: the deepseek route requires an explicit debugger model.'
    exit 2
}

$debuggerArgs = New-Object System.Collections.Generic.List[string]

if ($ReadOnly -and $Provider -eq 'claude') {
    # V7 appellate review is advisory only. Claude gets the prompt and repository
    # context for read-only analysis, but no bypassPermissions/add-dir grant and
    # no repair/promotion path.
    $debuggerArgs.Add('-p')
    if (-not [string]::IsNullOrWhiteSpace($Model)) {
        $debuggerArgs.Add('--model')
        $debuggerArgs.Add($Model)
    }
    $debuggerArgs.Add('--output-format')
    $debuggerArgs.Add('text')
}
elseif ($Provider -eq 'claude') {
    $debuggerArgs.Add('-p')
    if (-not [string]::IsNullOrWhiteSpace($Model)) {
        $debuggerArgs.Add('--model')
        $debuggerArgs.Add($Model)
    }
    $debuggerArgs.Add('--output-format')
    $debuggerArgs.Add('text')
    $debuggerArgs.Add('--permission-mode')
    $debuggerArgs.Add('bypassPermissions')
    $debuggerArgs.Add('--add-dir')
    $debuggerArgs.Add($AdditionalDirectory)
}
else {
    if (-not [string]::IsNullOrWhiteSpace($Profile)) {
        $debuggerArgs.Add('--profile')
        $debuggerArgs.Add($Profile)
    }
    $debuggerArgs.Add('--model')
    $debuggerArgs.Add($Model)
    $debuggerArgs.Add('-c')
    $debuggerArgs.Add(('model_provider="{0}"' -f $Provider))
    $debuggerArgs.Add('-c')
    $debuggerArgs.Add(('model_reasoning_effort="{0}"' -f $Reasoning))
    $debuggerArgs.Add('--ask-for-approval')
    $debuggerArgs.Add('never')
    $debuggerArgs.Add('--sandbox')
    $debuggerArgs.Add($Sandbox)
    $debuggerArgs.Add('-C')
    $debuggerArgs.Add($WorkingDirectory)
    $debuggerArgs.Add('--add-dir')
    $debuggerArgs.Add($AdditionalDirectory)
    $debuggerArgs.Add('exec')
    $debuggerArgs.Add('--ephemeral')
    $debuggerArgs.Add('--color')
    $debuggerArgs.Add('never')
    $debuggerArgs.Add('--output-last-message')
    $debuggerArgs.Add($OutputLastMessagePath)
    $debuggerArgs.Add('-')
}

$previousErrorActionPreference = $ErrorActionPreference
$captured = New-Object System.Text.StringBuilder
try {
    $ErrorActionPreference = 'Continue'
    if ($Provider -eq 'claude') {
        Push-Location -LiteralPath $WorkingDirectory
    }
    try {
        [System.IO.File]::ReadAllText($PromptPath) |
            & $CodexCommand @debuggerArgs 2>&1 |
            ForEach-Object {
                $line = if ($_ -is [System.Management.Automation.ErrorRecord]) {
                    $_.Exception.Message
                }
                else {
                    [string]$_
                }
                [void]$captured.AppendLine($line)
                Write-Output $line
            }
        $code = $LASTEXITCODE
    }
    finally {
        if ($Provider -eq 'claude') {
            Pop-Location
        }
    }
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}

if ($code -ne 0) {
    Write-Output ("AUTO-DEBUG CLI EXIT {0}" -f $code)
    exit $code
}
if ($Provider -eq 'claude') {
    $finalResponse = $captured.ToString().TrimEnd()
    if ([string]::IsNullOrWhiteSpace($finalResponse)) {
        Write-Output 'AUTO-DEBUG FAIL: debugger completed without a captured final response.'
        exit 2
    }
    if (-not [string]::IsNullOrWhiteSpace($OutputLastMessagePath)) {
        [System.IO.File]::WriteAllText($OutputLastMessagePath, $finalResponse, (New-Object System.Text.UTF8Encoding($false)))
    }
}
elseif (-not (Test-Path -LiteralPath $OutputLastMessagePath -PathType Leaf)) {
    Write-Output 'AUTO-DEBUG FAIL: debugger completed without a captured final response.'
    exit 2
}
Write-Output 'AUTO-DEBUG COMPLETE'
exit 0
