[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$devTools = Join-Path $repoRoot 'dev-tools'
$autoDebugTools = Join-Path $devTools 'm1-auto-debug.ps1'
$debugLauncher = Join-Path $devTools 'spa-auto-debug-launch.ps1'
$failures = New-Object System.Collections.Generic.List[string]

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if ($Condition) { Write-Host "PASS: $Message" }
    else {
        $script:failures.Add($Message)
        Write-Host "FAIL: $Message"
    }
}

function Assert-Match {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Message
    )

    Assert-True ([regex]::IsMatch($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) $Message
}

function Set-AdEnvironment {
    param([hashtable]$Values)
    foreach ($key in $Values.Keys) {
        if ($null -eq $Values[$key]) {
            [System.Environment]::SetEnvironmentVariable([string]$key, $null, 'Process')
        }
        else {
            [System.Environment]::SetEnvironmentVariable([string]$key, [string]$Values[$key], 'Process')
        }
    }
}

function Write-FakeDebuggerCli {
    param(
        [string]$Directory,
        [string]$Name,
        [string]$OutputLine
    )

    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    $fakeSource = @'
using System;
using System.IO;
using System.Text;

public static class SpaFakeCli
{
    public static int Main(string[] args)
    {
        string argFile = Environment.GetEnvironmentVariable("SPA_ROUTE_TEST_ARGS");
        if (!string.IsNullOrWhiteSpace(argFile))
        {
            File.WriteAllText(argFile, string.Join("\n", args), new UTF8Encoding(false));
        }
        for (int i = 0; i < args.Length - 1; i++)
        {
            if (string.Equals(args[i], "--output-last-message", StringComparison.OrdinalIgnoreCase))
            {
                string text = Environment.GetEnvironmentVariable("SPA_ROUTE_TEST_LAST_TEXT");
                File.WriteAllText(args[i + 1], string.IsNullOrWhiteSpace(text) ? "FAKE_DEBUGGER_RESPONSE" : text, new UTF8Encoding(false));
            }
        }
        string outline = Environment.GetEnvironmentVariable("SPA_ROUTE_TEST_OUT_LINE");
        Console.WriteLine(string.IsNullOrWhiteSpace(outline) ? "FAKE_DEBUGGER_RESPONSE" : outline);
        return 0;
    }
}
'@
    $fakeExe = Join-Path $Directory ($Name + '.exe')
    Add-Type -TypeDefinition $fakeSource -Language CSharp -OutputAssembly $fakeExe -OutputType ConsoleApplication -ErrorAction Stop | Out-Null
    if (-not (Test-Path -LiteralPath $fakeExe -PathType Leaf)) {
        throw "Fake CLI was not produced at $fakeExe"
    }
}

foreach ($path in @($autoDebugTools, $debugLauncher)) {
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "required route artifact exists: $path"
}

. $autoDebugTools

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('spa-auto-debug-route-test-' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    # 1. Defaults tonight: DeepSeek V4-Pro with high reasoning.
    Set-AdEnvironment @{ AUTO_DEBUG_PROVIDER = $null; AUTO_DEBUG_MODEL = $null; AUTO_DEBUG_REASONING = $null }
    $defaultRoute = Get-SpaAutoDebugRoute
    Assert-True ([string]$defaultRoute.Provider -eq 'deepseek') 'default debugger provider is deepseek'
    Assert-True ([string]$defaultRoute.Model -eq 'deepseek-v4-pro') 'default debugger model is deepseek-v4-pro'
    Assert-True ([string]$defaultRoute.DisplayModel -eq 'deepseek-v4-pro') 'default debugger display model is deepseek-v4-pro'
    Assert-True ([string]$defaultRoute.Reasoning -eq 'high') 'default debugger reasoning is high'

    # 2. Model and reasoning are configurable without supervisor changes.
    Set-AdEnvironment @{ AUTO_DEBUG_PROVIDER = 'deepseek'; AUTO_DEBUG_MODEL = 'deepseek-v4-pro-x'; AUTO_DEBUG_REASONING = 'max' }
    $overrideRoute = Get-SpaAutoDebugRoute
    Assert-True ([string]$overrideRoute.Provider -eq 'deepseek') 'deepseek provider override is honored'
    Assert-True ([string]$overrideRoute.Model -eq 'deepseek-v4-pro-x') 'AUTO_DEBUG_MODEL override is honored'
    Assert-True ([string]$overrideRoute.Reasoning -eq 'max') 'AUTO_DEBUG_REASONING override is honored'

    # 3. Claude is selectable through the same seam without live authentication.
    Set-AdEnvironment @{ AUTO_DEBUG_PROVIDER = 'claude'; AUTO_DEBUG_MODEL = $null; AUTO_DEBUG_REASONING = $null }
    $claudeDefaultRoute = Get-SpaAutoDebugRoute
    Assert-True ([string]$claudeDefaultRoute.Provider -eq 'claude') 'Claude provider is selectable through the seam'
    Assert-True ([string]$claudeDefaultRoute.Model -eq '') 'Claude keeps its configured default when AUTO_DEBUG_MODEL is unset'
    Assert-True ([string]$claudeDefaultRoute.DisplayModel -eq 'claude-default') 'Claude display model reports claude-default'

    Set-AdEnvironment @{ AUTO_DEBUG_PROVIDER = 'claude'; AUTO_DEBUG_MODEL = 'claude-opus'; AUTO_DEBUG_REASONING = 'high' }
    $claudeRoute = Get-SpaAutoDebugRoute
    Assert-True ([string]$claudeRoute.Model -eq 'claude-opus') 'AUTO_DEBUG_MODEL selects the Claude model tomorrow'

    Set-AdEnvironment @{ AUTO_DEBUG_PROVIDER = 'unknown'; AUTO_DEBUG_MODEL = $null; AUTO_DEBUG_REASONING = $null }
    $unsupportedCaught = $false
    try { $null = Get-SpaAutoDebugRoute } catch { $unsupportedCaught = $true }
    Assert-True $unsupportedCaught 'unsupported AUTO_DEBUG_PROVIDER is rejected explicitly'

    Set-AdEnvironment @{ AUTO_DEBUG_PROVIDER = $null; AUTO_DEBUG_MODEL = $null; AUTO_DEBUG_REASONING = $null }

    $workingRepo = Join-Path $tempRoot 'working-repo'
    $additionalRepo = Join-Path $tempRoot 'additional-repo'
    New-Item -ItemType Directory -Path $workingRepo, $additionalRepo -Force | Out-Null
    $promptFile = Join-Path $tempRoot 'debug-prompt.txt'
    Set-Content -LiteralPath $promptFile -Value 'SPA AUTO-DEBUG ROUTE TEST PROMPT' -Encoding ASCII

    $codexShimDir = Join-Path $tempRoot 'codex-shim'
    Write-FakeDebuggerCli -Directory $codexShimDir -Name 'codex' -OutputLine 'FAKE_CODEX_DONE'
    $claudeShimDir = Join-Path $tempRoot 'claude-shim'
    Write-FakeDebuggerCli -Directory $claudeShimDir -Name 'claude' -OutputLine 'FAKE_CLAUDE_DONE'

    $oldPath = $env:PATH
    try {
        # 4. CLI discovery follows the configured provider.
        $env:PATH = $codexShimDir + [System.IO.Path]::PathSeparator + $oldPath
        $codexCli = Find-SpaAutoDebugCommand -Provider 'deepseek'
        Assert-True ($null -ne $codexCli -and ([string]$codexCli.Name -match '^codex')) 'codex CLI resolves for the deepseek route'

        $env:PATH = $claudeShimDir + [System.IO.Path]::PathSeparator + $oldPath
        $claudeCli = Find-SpaAutoDebugCommand -Provider 'claude'
        Assert-True ($null -ne $claudeCli -and ([string]$claudeCli.Name -match '^claude')) 'claude CLI resolves for the claude route'

        # 5. The codex/deepseek launcher route passes the configured debugger
        #    model, provider, reasoning and both repositories to the CLI.
        $env:PATH = $codexShimDir + [System.IO.Path]::PathSeparator + $oldPath
        $codexArgsFile = Join-Path $tempRoot 'codex-args.txt'
        $codexLastMessage = Join-Path $tempRoot 'codex-last.txt'
        Set-AdEnvironment @{
            SPA_ROUTE_TEST_ARGS = $codexArgsFile
            SPA_ROUTE_TEST_OUT_LINE = 'FAKE_CODEX_DONE'
        }
        $codexCommandPath = @(Get-Command 'codex.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1)[0].Source
        $launchCodex = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $debugLauncher `
            -CodexCommand $codexCommandPath `
            -Profile 'deepseek' `
            -Model 'deepseek-v4-pro' `
            -Provider 'deepseek' `
            -Reasoning 'high' `
            -Sandbox 'workspace-write' `
            -WorkingDirectory $workingRepo `
            -AdditionalDirectory $additionalRepo `
            -PromptPath $promptFile `
            -OutputLastMessagePath $codexLastMessage 2>&1 | Out-String
        Assert-True ($LASTEXITCODE -eq 0) 'codex debugger launcher exits successfully'
        $codexArgs = if (Test-Path -LiteralPath $codexArgsFile) { [System.IO.File]::ReadAllText($codexArgsFile) } else { '' }
        Assert-Match $codexArgs '--model[\r\n]+deepseek-v4-pro' 'codex route passes the configured debugger model'
        Assert-Match $codexArgs 'model_provider=deepseek' 'codex route passes the configured provider'
        Assert-Match $codexArgs 'model_reasoning_effort=high' 'codex route passes the configured reasoning effort'
        Assert-Match $codexArgs '--ask-for-approval[\r\n]+never' 'codex route passes approval never'
        Assert-Match $codexArgs ([regex]::Escape($additionalRepo)) 'codex route passes the additional repository as a writable root'
        Assert-True (Test-Path -LiteralPath $codexLastMessage -PathType Leaf) 'codex route preserves the captured final response'

        # 6. The Claude route uses the real Claude non-interactive contract and
        #    never falls back to codex-style flags.
        $env:PATH = $claudeShimDir + [System.IO.Path]::PathSeparator + $oldPath
        $claudeArgsFile = Join-Path $tempRoot 'claude-args.txt'
        $claudeLastMessage = Join-Path $tempRoot 'claude-last.txt'
        Set-AdEnvironment @{
            SPA_ROUTE_TEST_ARGS = $claudeArgsFile
            SPA_ROUTE_TEST_OUT_LINE = 'FAKE_CLAUDE_DONE'
        }
        $claudeCommandPath = @(Get-Command 'claude.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1)[0].Source
        $launchClaude = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $debugLauncher `
            -CodexCommand $claudeCommandPath `
            -Provider 'claude' `
            -Reasoning 'high' `
            -Sandbox 'workspace-write' `
            -WorkingDirectory $workingRepo `
            -AdditionalDirectory $additionalRepo `
            -PromptPath $promptFile `
            -OutputLastMessagePath $claudeLastMessage 2>&1 | Out-String
        Assert-True ($LASTEXITCODE -eq 0) 'claude debugger launcher exits successfully without authentication'
        $claudeArgs = if (Test-Path -LiteralPath $claudeArgsFile) { [System.IO.File]::ReadAllText($claudeArgsFile) } else { '' }
        Assert-Match $claudeArgs '(?m)^-p[`r`n]?$' 'claude route uses print mode'
        Assert-Match $claudeArgs '--permission-mode[\r\n]+bypassPermissions' 'claude route uses bypassPermissions for autonomous repairs'
        Assert-Match $claudeArgs ([regex]::Escape($additionalRepo)) 'claude route passes the additional repository'
        Assert-True ($claudeArgs.IndexOf('--ask-for-approval', [System.StringComparison]::Ordinal) -lt 0) 'claude route never uses codex approval flags'
        Assert-True ($claudeArgs.IndexOf('-C', [System.StringComparison]::Ordinal) -lt 0) 'claude route never invents a directory flag'
        Assert-True ($claudeArgs.IndexOf('--model', [System.StringComparison]::Ordinal) -lt 0) 'claude route leaves the model unset until AUTO_DEBUG_MODEL selects one'
        Assert-True (Test-Path -LiteralPath $claudeLastMessage -PathType Leaf) 'claude route preserves the captured final response'
        $claudeCaptured = [System.IO.File]::ReadAllText($claudeLastMessage)
        Assert-Match $claudeCaptured 'FAKE_CLAUDE_DONE' 'claude route captures the debugger final response'

        # 7. Supplying AUTO_DEBUG_MODEL for claude flows into the real CLI.
        $env:PATH = $claudeShimDir + [System.IO.Path]::PathSeparator + $oldPath
        $claudeModelArgsFile = Join-Path $tempRoot 'claude-model-args.txt'
        Set-AdEnvironment @{
            SPA_ROUTE_TEST_ARGS = $claudeModelArgsFile
            SPA_ROUTE_TEST_OUT_LINE = 'FAKE_CLAUDE_DONE'
        }
        $launchClaudeModel = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $debugLauncher `
            -CodexCommand $claudeCommandPath `
            -Model 'claude-opus' `
            -Provider 'claude' `
            -Reasoning 'high' `
            -Sandbox 'workspace-write' `
            -WorkingDirectory $workingRepo `
            -AdditionalDirectory $additionalRepo `
            -PromptPath $promptFile `
            -OutputLastMessagePath (Join-Path $tempRoot 'claude-model-last.txt') 2>&1 | Out-String
        Assert-True ($LASTEXITCODE -eq 0) 'claude launcher accepts an explicit model through the seam'
        $claudeModelArgs = if (Test-Path -LiteralPath $claudeModelArgsFile) { [System.IO.File]::ReadAllText($claudeModelArgsFile) } else { '' }
        Assert-Match $claudeModelArgs '--model[\r\n]+claude-opus' 'claude route forwards the configured model'
    }
    finally {
        $env:PATH = $oldPath
        Set-AdEnvironment @{ SPA_ROUTE_TEST_ARGS = $null; SPA_ROUTE_TEST_OUT_LINE = $null }
    }
}
finally {
    Set-AdEnvironment @{ AUTO_DEBUG_PROVIDER = $null; AUTO_DEBUG_MODEL = $null; AUTO_DEBUG_REASONING = $null }
    if (Test-Path -LiteralPath $tempRoot) {
        [System.IO.Directory]::Delete($tempRoot, $true)
    }
}

Write-Host ''
if ($failures.Count -eq 0) {
    Write-Host 'GREEN: all SPA Auto-Debug route tests passed.'
    exit 0
}

Write-Host "RED: $($failures.Count) SPA Auto-Debug route test(s) failed."
$failures | ForEach-Object { Write-Host " - $_" }
exit 1
