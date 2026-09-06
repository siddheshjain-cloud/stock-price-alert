# SPA development workspace tools

These commands are for developers working on the SPA workspace. They are safe, read-only checks and dependency helpers. They do not change application code.

## Start-of-task workspace check

Run this before editing:

```powershell
& C:\GitHub\stock-price-alert\dev-tools\spa-check.ps1
```

This checks the backend and frontend repositories, the permanent Python version, and pytest. It is read-only and will never pull, reset, checkout, switch, clean, commit, push, or change code.

## Before an expensive model run

Run this to verify the active Codex model and read-only sandbox settings:

```powershell
& C:\GitHub\stock-price-alert\dev-tools\spa-model-check.ps1
```

This does not inspect, modify, or execute anything in the repository. It only sends a harmless confirmation prompt to Codex.

## Only when dependencies changed

Run this when the Python dependency manifest has changed or when a package is genuinely missing:

```powershell
& C:\GitHub\stock-price-alert\dev-tools\spa-deps-sync.ps1
```

It reuses the existing permanent Python environment. It does not download or install Python and does not create another virtual environment.

## Important note

Pulling the latest code is a separate manual action. These tools never run `git pull` or any other Git command that changes repository state. If a workspace check reports a branch or clean-state problem, stop and ask a developer before continuing.
