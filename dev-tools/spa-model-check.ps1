[CmdletBinding()]
param(
    [string]$WorkingPath = 'C:\GitHub\backendtest'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$codexCommand = Get-Command codex -ErrorAction SilentlyContinue
if (-not $codexCommand) {
    Write-Output 'MODEL_CHECK FAIL'
    Write-Output 'Codex CLI was not found.'
    exit 1
}

if ([string]::IsNullOrWhiteSpace($WorkingPath) -or -not (Test-Path -LiteralPath $WorkingPath -PathType Container)) {
    Write-Output 'MODEL_CHECK FAIL'
    Write-Output "Working path is missing: $WorkingPath"
    exit 1
}

$prompt = 'Reply with exactly: MODEL_CHECK_OK. Do not inspect, modify, or execute anything in the repository.'

$codexArgs = @(
    '--ask-for-approval',
    'never',
    'exec',
    '--sandbox',
    'read-only',
    '--skip-git-repo-check',
    '-'
)

$combinedText = $null
try {
    Push-Location -LiteralPath $WorkingPath
    $combinedText = ($prompt | & codex @codexArgs 2>&1 | Out-String)
}
catch {
    $combinedText = "Codex invocation failed: $($_.Exception.Message)"
}
finally {
    Pop-Location
}

$text = if ($null -eq $combinedText) { '' } else { $combinedText }
Write-Output '--- CODEX MODEL CHECK OUTPUT ---'
Write-Output $text

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

$model = Get-FirstRegexValue -Text $text -Pattern '(?im)^\s*model:\s*(.+)$'
$provider = Get-FirstRegexValue -Text $text -Pattern '(?im)^\s*provider:\s*(.+)$'
$reasoning = Get-FirstRegexValue -Text $text -Pattern '(?im)^\s*reasoning(?:_effort| effort):\s*(.+)$'
$approval = Get-FirstRegexValue -Text $text -Pattern '(?im)^\s*approval:\s*(.+)$'
$sandbox = Get-FirstRegexValue -Text $text -Pattern '(?im)^\s*sandbox:\s*(.+)$'

Write-Output '--- PARSED HEADER ---'
Write-Output ("model: {0}" -f $model)
Write-Output ("provider: {0}" -f $provider)
if (-not [string]::IsNullOrWhiteSpace($reasoning)) {
    Write-Output ("reasoning effort: {0}" -f $reasoning)
}
if (-not [string]::IsNullOrWhiteSpace($approval)) {
    Write-Output ("approval: {0}" -f $approval)
}
if (-not [string]::IsNullOrWhiteSpace($sandbox)) {
    Write-Output ("sandbox: {0}" -f $sandbox)
}

$ok = [string]::IsNullOrWhiteSpace($model) -eq $false -and
      [string]::IsNullOrWhiteSpace($provider) -eq $false -and
      $text.IndexOf('MODEL_CHECK_OK', [System.StringComparison]::Ordinal) -ge 0

if ($ok) {
    Write-Output 'MODEL_CHECK_OK'
    exit 0
}

Write-Output 'MODEL_CHECK FAIL'
if ([string]::IsNullOrWhiteSpace($model) -or [string]::IsNullOrWhiteSpace($provider)) {
    Write-Output 'Could not parse model/provider from Codex header.'
}
if ($text.IndexOf('MODEL_CHECK_OK', [System.StringComparison]::Ordinal) -lt 0) {
    Write-Output 'Expected MODEL_CHECK_OK response was absent.'
}
exit 1

