# DeepSeek Codex Context Handoff

## What I am doing
Setting up and using Codex CLI with DeepSeek on my office PC for the
SPA M1 development project. I am a non-coder.

## Machines
- Office PC (current): C:\GitHub\backendtest, C:\GitHub\stock-price-alert
- Home PC: same repos, same setup, synced via GitHub
- GitHub is the sync authority between both machines.

## What is already set up (office PC)
- Python 3.12.10 installed
- Permanent venv: C:\venvs\spa-m1\Scripts\python.exe
- Codex CLI v0.155.1 (standalone install, npm version removed)
- Codex configured for DeepSeek: model=deepseek-flash, reasoning=high,
  approval=never, sandbox=read-only
- config.toml at C:\Users\User\.codex\config.toml
- models.json at C:\Users\User\.codex\models.json

## The one command I run before every task
& C:\GitHub\stock-price-alert\dev-tools\spa-check.ps1
Expected output ends with: READY YES
If READY NO, fix only the named issue.

## Key files
- SOP: C:\GitHub\spa-check-simplified-office.txt
- README: C:\GitHub\stock-price-alert\dev-tools\README.md
- Backend: C:\GitHub\backendtest
- Frontend/docs: C:\GitHub\stock-price-alert
- Branch: feature/investment-operating-system-m1

## What is NOT part of this project (ignore these)
- Tesseract OCR
- gcloud CLI
- Service account keys
- Drive OAuth secrets

## Known quirk
The DeepSeek setup script (codex-deepseek-setup-en.ps1) breaks the
model line in config.toml. If re-run, manually verify config.toml
first two lines show:
  model = "deepseek-flash"
  model_reasoning_effort = "high"

## What I need help with right now
[FILL THIS IN EACH TIME: paste the error, question, or task]

## Current state
[FILL THIS IN EACH TIME: paste output of spa-check.ps1 if relevant]