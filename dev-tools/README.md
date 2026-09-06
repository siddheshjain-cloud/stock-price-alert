# SPA development preflight

Run this one command before a development task:

```powershell
& C:\GitHub\stock-price-alert\dev-tools\spa-check.ps1
```

Current M1 work uses the Backend target by default. The command already includes an actual Codex model check, so no separate model-check step is needed.

## What to do with the result

1. If the output ends with `READY YES`, run the approved task prompt.
2. If the output ends with `READY NO`, stop and fix only the named issue.

## What this command checks

- active repo Git branch and working tree
- remote synchronization with GitHub, read-only
- dependency-manifest fingerprint for the Backend target
- the actual Codex model, provider, and reasoning effort

Stable machine setup is not rechecked every task. `spa-check.ps1` never changes code, Git history, execution policy, or the selected model. The remote Git check is read-only. Dependencies are only touched when their manifest has changed.

## One-time dependency registration

Before the first real Backend check, register the current permanent dependency environment once:

```powershell
& C:\GitHub\stock-price-alert\dev-tools\spa-deps-sync.ps1 -RegisterCurrent
```

This verifies the permanent Python environment with `pip check` and records its requirements fingerprint. It does not reinstall packages.
