# SPA Task Runner — Safe Resume and M1 Orchestration Implementation Plan

> **For agentic workers:** Execute this plan task-by-task with TDD. Do not run actual M1 product tasks while building the runner. Use dry-run/fake command execution until the runner itself is verified.

**Goal:** Build a deterministic `spa-run` PowerShell orchestrator that routes each M1 task to its predefined AI model, verifies the environment, checkpoints only verified work to GitHub, and safely resumes on another PC after planned interruption or unexpected power loss.

**Architecture:** GitHub is the durable cross-PC checkpoint. Local uncommitted work is never treated as complete. The runner maintains a small tracked M1 state file in `stock-price-alert`, but completion is only recorded after implementation, required tests, independent review, and push have succeeded. On another PC, `spa-run M1-REMAINING` fast-forwards clean repositories from GitHub, validates state against recorded SHAs, and restarts the first task that is not verified complete.

**Tech Stack:** PowerShell, Git, existing `spa-check.ps1`, Codex CLI, configured OpenAI/DeepSeek providers, optional Claude CLI, JSON/PSD1 state/routing files.

**Repositories:**
- Tooling/docs: `C:\GitHub\stock-price-alert`
- Backend: `C:\GitHub\backendtest`
- Branch: `feature/investment-operating-system-m1`

## Global Constraints

- No production/deployment database.
- No Kite, Telegram, live websocket/trading, deployment, secrets, permissions, or main/master changes.
- Never auto-merge divergent Git histories.
- Never use `git reset --hard`, `git clean`, or discard unrelated user work.
- A dirty worktree fails closed.
- Fast-forward pull is allowed only when branch is correct, worktree is clean, and remote state is strictly ahead.
- Only verified + reviewed + pushed work may be marked COMPLETE.
- A power failure may lose/restart the current unfinished task, but must never invalidate prior verified tasks.
- Model/provider/reasoning mismatch fails closed.
- Independent review must use a different model/provider from the implementation/remediation model when a different reviewer is available.
- Do not build cloud execution in this milestone.
- Do not build WIP branches merely to preserve partially completed AI work.
- Planned time limits are soft safe-boundary limits; never interrupt a task merely because the clock expires.
- Correct and safe before complete; complete before elegant.

---

## File responsibilities

Create/modify only focused tooling files in `stock-price-alert`:

- `dev-tools/spa-run.ps1`
  - user-facing runner and orchestration loop
- `dev-tools/m1-model-routing.psd1`
  - task/review → provider/model/reasoning/action/repo/plan mapping
- `dev-tools/state/m1-state.json`
  - durable milestone state/checkpoint metadata
- `dev-tools/prompts/`
  - only dedicated review/remediation prompts that cannot be derived directly from frozen plans
- `dev-tools/tests/`
  - deterministic runner tests/self-tests
- `dev-tools/spa-check.ps1`
  - modify only if a minimal reusable interface is required

Do not modify SPA product application code while implementing this tooling.

---

## State semantics

Each M1 unit must have a machine-readable state such as:

- `PENDING`
- `RUNNING_LOCAL`
- `IMPLEMENTED`
- `REVIEW_PENDING`
- `REMEDIATION_REQUIRED`
- `COMPLETE`

Required durable fields per task:
- task id
- action
- status
- implementation provider/model
- reviewer provider/model
- last verified backend/frontend SHA as applicable
- implementation commit SHA if available
- remediation commit SHA if available
- last successful review verdict
- updated UTC timestamp

`RUNNING_LOCAL` is informational only and must never be interpreted as durable completion after a restart.

The durable recovery rule is:

1. Pull/fast-forward clean repos.
2. Read state.
3. Verify recorded completed-task SHAs exist locally/remotely.
4. Find first task not `COMPLETE`.
5. If status was `RUNNING_LOCAL`, `IMPLEMENTED`, `REVIEW_PENDING`, or `REMEDIATION_REQUIRED`, resume from the safest deterministic stage supported by evidence.
6. Never infer completion from prose alone.

For a sudden power failure during implementation, the default safe behavior on another clean PC is to restart that unfinished implementation task from the last verified Git checkpoint.

---

## Planned-stop semantics

Support:

```powershell
spa-run M1-REMAINING -MaxMinutes 120
```

and:

```powershell
spa-run M1-REMAINING -Until "18:30"
```

The deadline is a **soft boundary**.

Before beginning each new implementation/review/remediation unit:
- calculate remaining time;
- if within a configurable safety buffer (default 15 minutes), stop cleanly;
- print last verified checkpoint and next task;
- leave both repos clean and synced.

If a task has already started, finish the current safe unit rather than killing it solely because the soft deadline passed.

Unexpected shutdown/power loss is handled by the recovery semantics above.

---

## Task 1 — Deterministic routing core

**Files:**
- Create `dev-tools/m1-model-routing.psd1`
- Create `dev-tools/tests/test-spa-routing.ps1`

**Behavior:**
- map every frozen M1 task ID to PLAN/TASK, repository, action, provider/model/reasoning;
- distinguish IMPLEMENT and REVIEW routes;
- include implementer metadata for review gates;
- reject unknown task IDs;
- reject same-model independent certification when alternate reviewer is required.

Use the already frozen routing table:
- Flash High default for bounded tasks
- Pro High for high-risk tasks
- review gates per agreed M1 routing
- current `P2T4-REVIEW` must route to DeepSeek V4-Pro High because GPT-5.6 Sol High performed the remediation.

**TDD:**
- RED tests for known route, unknown route, P2T4 independent-model route, same-model conflict.
- Implement minimal routing.
- GREEN.
- Commit.

---

## Task 2 — Provider/model invocation and preflight

**Files:**
- Create/extend `dev-tools/spa-run.ps1`
- Modify `dev-tools/spa-check.ps1` only if needed
- Add focused tests

**Behavior:**
- inspect installed Codex/Claude tooling and existing provider configuration;
- prefer deterministic per-run/profile/CODEX_HOME isolation;
- do not embed, echo, or commit secrets;
- fail closed if provider/model/reasoning cannot be selected deterministically;
- invoke `spa-check` and parse a machine-readable result if practical;
- display:
  - TASK
  - ACTION
  - REPO
  - MODEL
  - PROVIDER
  - REASONING
  - SANDBOX
  - READY YES/NO
- support `-DryRun` without consuming model tokens.

**TDD:**
- wrong model/provider → fail
- wrong branch → fail
- dirty repo → fail
- missing prompt/plan → fail
- dry-run builds correct command without executing it
- no secret material appears in generated files/output

Commit after green.

---

## Task 3 — Durable M1 checkpoint state

**Files:**
- Create `dev-tools/state/m1-state.json`
- Add state helper functions/tests

**Initial state:**
Agent must verify Git history before seeding.
Expected historical status from current project context:
- Plan 1 tasks complete
- Plan 2 Tasks 1–3 complete
- Plan 2 Task 4 implementation/remediation exists, remediation commit `6c417294e5a060346c2294666a10a4cff610ee82`, independent re-certification pending
- Plan 2 Task 5 onward pending

Do not blindly trust these expectations; verify commits and branch state.

**Behavior:**
- state writes are atomic (`temp` then replace);
- COMPLETE may be written only after objective gate conditions pass;
- state records verified SHAs;
- state changes intended for cross-PC continuation are committed/pushed to `stock-price-alert`;
- if push fails, do not claim checkpoint durable.

**TDD:**
- interrupted/RUNNING_LOCAL never becomes COMPLETE
- incomplete state resumes same task
- completed state advances one task
- recorded SHA missing → fail closed
- push/checkpoint failure → no durable-complete claim
- malformed state → fail closed

Commit after green.

---

## Task 4 — Cross-PC repository synchronization and recovery

**Files:**
- Extend `spa-run.ps1`
- Add recovery tests

**Behavior when `spa-run M1-REMAINING` starts:**
- inspect both repos;
- require correct branch;
- require clean worktrees;
- `git fetch`;
- if local behind remote with no local divergence, `git pull --ff-only`;
- if ahead/diverged/dirty unexpectedly, stop and report;
- validate state against remote-visible commits;
- determine first incomplete task;
- restart an unfinished implementation from last verified checkpoint;
- never recover by destructive reset.

**Power-failure example that must pass:**
- P2T5 and P2T6 COMPLETE and pushed
- P2T7 RUNNING_LOCAL when power dies
- clean Home PC starts runner
- pulls latest remote
- identifies P2T7 as first unfinished task
- restarts P2T7
- does not rerun P2T5/P2T6
- does not mark P2T7 complete without fresh evidence

Commit after green.

---

## Task 5 — Safe time-bounded orchestration

**Files:**
- Extend `spa-run.ps1`
- Add deadline tests

**Behavior:**
- `-MaxMinutes N`
- `-Until HH:mm`
- default safety buffer 15 minutes, configurable internally or via parameter
- before each new unit, check remaining time
- if within buffer, stop at clean verified checkpoint
- if current unit exceeds time, allow it to finish safely; do not hard-kill merely for deadline
- print next task and resume command

**Tests:**
- enough time → starts next unit
- inside buffer → does not start next unit
- deadline expires during simulated unit → completes unit/checkpoint, then stops
- no task state marked COMPLETE on simulated forced interruption

Commit after green.

---

## Task 6 — Single-task and M1 orchestration modes

**Files:**
- Extend `spa-run.ps1`
- Add orchestration tests

Support:

```powershell
spa-run P2T4-REVIEW
spa-run P2T5
spa-run M1-REMAINING
spa-run M1-REMAINING -MaxMinutes 120
spa-run M1-REMAINING -Until "18:30"
```

The M1 loop must execute units **sequentially**, never fire all dependent tasks in parallel.

For each task:
1. preflight
2. implementation with predefined model
3. required focused tests
4. regression/full tests as task requires
5. commit/push
6. independent review at defined review gates
7. if review finds defects:
   - verify findings
   - route remediation
   - retest
   - use independent re-review
8. only then mark COMPLETE
9. checkpoint/push state
10. deadline check
11. next task

Hard human stop conditions:
- frozen-spec/architecture conflict
- unknown/unmapped task
- unexplained test failure
- repeated remediation failure after 2 attempts
- migration reaches active/deployment database boundary
- secrets/permissions/production/broker/capital actions
- model/provider unavailable
- final M1 release gate requiring explicit human approval

No automated human-approval bypass.

Commit after green.

---

## Task 7 — P2T4 review prompt and end-to-end dry run

**Files:**
- Create `dev-tools/prompts/P2T4-REVIEW.txt` if not already present
- Extend tests

Review exact range:
- original Task 4 implementation: `0ed2831a7d64a8bf70d72f9ef7d1e8b4bbe69b79`
- remediation: `6c417294e5a060346c2294666a10a4cff610ee82`

Reviewer:
- DeepSeek V4-Pro High
- independent of Sol remediation

Must inspect:
- ORM immutability
- transaction cleanup
- constraint-specific `IntegrityError` translation
- uniqueness/concurrency behavior
- SQLite limitation vs production `FOR UPDATE`
- complexity/inefficiency
- fresh tests when environment permits

Verdict:
- SAFE
- SAFE WITH NON-BLOCKING OBSERVATIONS
- CHANGES REQUIRED

Run only **dry-run** during tooling implementation unless explicitly asked to consume the review tokens.

Verify output resolves exactly to DeepSeek Pro High.

Commit after green.

---

## Final verification

Before claiming runner complete:

- focused PowerShell/self-tests all pass
- `spa-check` still works
- `spa-run P2T4-REVIEW -DryRun` resolves expected route
- `spa-run M1-REMAINING -DryRun` identifies P2T4 review as the next unresolved gate
- simulated power-failure recovery test passes
- simulated Office→Home fast-forward/resume test passes
- simulated deadline stop passes
- unknown task / dirty repo / wrong branch / provider mismatch all fail closed
- `git diff --check` passes
- no secrets in changed files
- worktree clean after commit
- push succeeds
- local/remote divergence 0/0

Commit message for the completed tooling feature:

```text
chore: add resumable SPA M1 task orchestrator
```

Do not start P2T5 while implementing the runner.
Do not declare P2T4 closed.
After tooling is green, the first real command should be the independent `P2T4-REVIEW`.
