# Phase 3 Development Checkpoint

**Live, update-in-place record of Phase 3 engineering progress.** Read this
first when resuming Phase 3 work in a new session. Update it in place at
each shutdown checkpoint rather than creating a new dated file -- the
`Last updated` line and the slice ledger are the source of truth for
"what is actually committed," independent of any single conversation's
memory.

**Before reading further, consult the [SPA Codebase & Architecture
Registry](2026-10-12-spa-codebase-architecture-registry.md)** -- the
primary navigation reference for the repo map, module/service index,
API contract status, and known gaps. This checkpoint remains the
authoritative slice-by-slice ledger ("what is actually shipped and
tested"); the registry is the structural map around it.

**Wealth Desk UI/UX:** see the [Wealth Desk Architecture Proposal](2026-10-12-wealth-desk-architecture-proposal.md)
-- three navigation approaches, a recommendation, wireframes, and
implementation milestones, reserved for owner approval before any
frontend implementation begins.

**Last updated:** 2026-10-12 (milestone checkpoint -- I3AS Alert-3
complete, merged into `feature/research-coverage-foundation` (PR #5),
real-company validated. `master` itself is current as of PR #4
(Research Coverage Slices 1-4, Phase 3 A-G, I3AS Slice 1/Alert-2);
Alert-3 is one PR ahead of `master`, pending its own separate merge
decision, per the Quality-Gated Autonomous Development Protocol below.)

---

## Repository state (verified at last checkpoint)

- **Code repository:** `C:/github/backendtest`
- **Branch:** `feature/phase3-slice-c-cycle-intelligence` (stacked: this
  branch carries Slice A through Slice G commits in sequence; despite its
  name it is the current working branch for all of Phase 3, not only
  Slice C -- each slice branched from the previous slice's tip rather
  than from `master`)
- **HEAD:** `82a092b` -- "feat(phase3-slice-g): add Investment Case
  (nine-gate assessment) and InvestmentCaseService"
- **Working tree:** clean
- **GitHub:** fully integrated through PR #1, owner-approved and
  executed 2026-10-12. `gh` CLI authenticated (device-flow browser
  auth, owner action; portable zip install after the MSI installer
  hung on a UAC prompt it could not get in a non-interactive session --
  killed, no admin rights used or required). PR #1's title/description
  were updated to reflect the full A-G stack, then merged into
  `feature/research-coverage-foundation` via an ordinary merge commit
  (`9ff53f2`) -- **not** squash, **not** rebase, so all seven individual
  Phase 3 commits remain intact and individually reachable, per the
  owner's explicit "preserve existing commit history" instruction.
  Verified independently via plain `git log`/`git merge-base`, not just
  the GitHub UI. The PR branch (`feature/phase3-slice-a-contracts`) was
  **not** deleted. `feature/research-coverage-foundation` -> `master`
  remains unmerged and has no PR of its own yet -- **explicitly not
  done**, per the owner's own instruction, pending separate approval.
- **Live database** (`instance/trading_app.db`): Alembic revision
  `20261007_05` -- **five migrations behind this branch's head
  (`20261008_05`)**. The live database has never been migrated during
  Phase 3 work; every migration (Slices A, C, D, G) has only ever been
  tested against isolated SQLite copies in a session scratchpad, built
  via `sqlite3.Connection.backup()`, never against the live file. Slices
  E/F added no migration (service-layer corrections + new wrapper
  services only, no schema change). Slice G's migration
  (`20261008_05`) was verified both ways on an isolated copy this
  session: `flask db upgrade` to head created exactly the five new
  tables and both partial-unique "single genesis" indexes; `flask db
  downgrade 20261008_04` cleanly dropped all five with nothing left
  behind. The live file's own revision was re-checked immediately
  before and after this session's work and is unchanged.
- **Design/planning repository:** `C:/github/stock-price-alert`,
  `docs/superpowers/plans/` -- holds the design proposal, the
  architecture-review addendum, and this checkpoint.

## Latest regression result

**1,474 passed, 0 failed** (full suite, `python -m pytest -q`, ~13.3
min, 2026-10-11, after Slice G). The one previously-recurring,
pre-existing flake named below passed cleanly this run too --
consistent with it being a true intermittent flake rather than anything
Slice G (or any Phase 3 code) touches.

`tests/documents/test_content_addressed_document_architecture.py::test_changing_storage_location_does_not_create_new_binary_identity`
-- a **known, recurring, pre-existing flake**, unrelated to any Phase 3
work (it asserts a global, unscoped `DocumentContent` row count; each
test gets a fully isolated fresh SQLite file per `tests/conftest.py`'s
`app` fixture, so there is no real cross-test leakage mechanism). It has
now recurred across three separate full-suite runs (after Slice D, after
Slice E not at all, after Slice F) and passed cleanly again after Slice
G. Diagnosed twice already; do not re-investigate without a new symptom.
Phase 3 code has never touched document/content-hash logic.

## Slice completion ledger

| Slice | Delivers | Commit | Status |
|---|---|---|---|
| A | Contracts: `scenario`/`origin` columns + partial-unique-index pair on `forecast_revision`/`valuation_revision`; `FinancialMetricDefinition`; `FiscalPeriod` resolver | `30bb2a6` | Done |
| B | `financial_diagnostics_service.py`, `financial_narration_service.py`; `ADJUSTED` metric namespace; real Chemplast D5 pilot (reconciled COGS, CCVL impairment adjustment) | `0686d95` | Done |
| C | `CycleObservation`/`CycleAssessment`/`CompanyExposure`; `CycleIntelligenceService`; DB-enforced revision-chain integrity (no branching, single genesis, race-safe); real Chemplast PVC/VCM-spread `CycleAssessment` + `CompanyExposure` | `cbfb6b8` | Done |
| D | `InvestmentHypothesis`/`InvestmentHypothesisCitation`/`ForecastAssumption`; `HypothesisAssumptionService`; P3-D atomicity rule (one row = one driver = one provenance source); real Chemplast hypothesis citing real Slice B/C output | `54eb7fd` | Done |
| E | Scenario-aware `create_forecast_revision` (fixed two latent gaps: scenario never wired into the values-builder/current-lookup, and the race-detector still checked the pre-Slice-A constraint name); `ForecastRevisionAssumption`; `ForecastEngineService` | `aa4a0ef` | Done |
| F | Same scenario-aware correction applied to `create_valuation_revision` (same two gaps, same fix); `ValuationEngineService` deriving `reference_metric_value` directly from cited `ForecastLine`s, never caller-asserted | `d9ca4e0` | Done |
| G | `InvestmentCase`, `InvestmentCaseForecast`/`InvestmentCaseValuation` link tables, `InvestmentCaseKillSwitch`, `InvestmentCaseGateResult` (nine gates), `InvestmentCaseService.get_scenario_return_spread` | `82a092b` | **Done** |
| Orchestrator | Contract only (§6 of the design proposal) | -- | Not implemented; not authorized under any circumstance without separate approval |

**Phase 3's implementation scope (Slices A-G) is now complete.** The
only named, specified-but-intentionally-unbuilt piece of the approved
design proposal is the Research Orchestrator (§6) -- a future trigger/
consumer mechanism that requires separate, explicit owner approval
before any implementation, exactly as it did at every prior checkpoint.

## Outstanding acceptance item (carried forward, not an engine defect)

**The real-Chemplast four-scenario forecast and valuation demonstration
remains unresolved.** The real BULL-scenario `ForecastAssumption` rows
from the Slice D pilot (citing a real `CompanyExposure`/`CycleAssessment`
and a real `ResearchProposition`, both grounded in verbatim Q4 FY26
earnings-call commentary) carry a real `metric_slug` but no
`assumed_value` was ever recorded. `ForecastEngineService` and
`ValuationEngineService` both correctly refuse to fabricate a number in
its absence -- confirmed by running the real attempt against an isolated
database copy and observing the explicit "cannot be computed without
fabricating a figure" rejection, not a silent or invented result. No real
numeric Chemplast `ForecastRevision` or `ValuationRevision` exists yet.
Resolving this requires either additional real, evidence-grounded
numeric assumptions (a deliberate analyst judgment call, explicitly
justified and attributed, not a verbatim-quoted figure) or recording it
as a standing limitation of the current real-document evidence base.
This was independent of Slice G and did not block it -- confirmed again
at the Slice G boundary: Slice G's own full-chain mechanism was proven
end to end against disposable fixtures (nine gates, a kill switch, and
a live, non-fabricated Bull/Base/Bear return spread), the same
substitution every non-acceptance engine test in this codebase already
uses, with no real-Chemplast numeric trace attempted. This gap remains
open and un-widened by Slice G.

## Engineering-autonomy permissions and standing constraints (preserved)

- Engineering autonomy over implementation details, schema design within
  an approved scope, code organization, testing, ordinary corrective
  changes, and committing -- granted per-slice throughout this
  engagement and intended to continue under the same terms for Slice G.
- **Never** modify or migrate the live database without a separate,
  explicit authorization; all migration testing happens only against
  isolated SQLite copies in the session scratchpad.
- **Never** create a parallel/duplicate architecture, a second ingestion
  or extraction pathway, or bypass an existing tested mechanism -- every
  slice so far has been a thin, additive extension of prior slices'
  infrastructure (Slice C reused Slice 4's `ResearchProposition`
  mechanism unchanged for Transformation; Slice D reused all five of its
  provenance targets as-is; Slices E/F are corrections to, and thin
  wrappers around, the pre-existing M1 revision-chain code, never a
  second forecast/valuation mechanism).
- Do not fabricate reported Facts or calculated forecasts/valuations.
  Explicit, justified analyst-authored numerical assumptions are
  permitted and must be clearly distinguished from both reported Facts
  and from calculated results derived from them.
- No new frameworks, no AI/LLM dependency in any diagnostics/narration/
  engine service (verified by dedicated import-boundary tests in Slice
  B; the same discipline has been maintained, not re-tested per slice,
  in every slice since).

## GitHub integration state (as of this checkpoint)

- **PR #1** (`feature/phase3-slice-a-contracts` -> `feature/research-
  coverage-foundation`): **merged**, 2026-10-12, via an ordinary merge
  commit (`9ff53f2`) -- not squash, not rebase -- preserving all seven
  Phase 3 commits individually. Verified independently via plain
  `git log`/`git merge-base`, not just the GitHub UI. The PR branch was
  not deleted.
- **PR #2** (`feature/i3as-slice1-trade-alert-integration` ->
  `feature/research-coverage-foundation`): **merged**, 2026-10-12, same
  ordinary-merge-commit discipline as PR #1.
- **PR #3** (`feature/i3as-slice2-investment-brain-alerts` ->
  `feature/research-coverage-foundation`): **merged**, 2026-10-12, same
  ordinary-merge-commit discipline as PRs #1/#2 (`2e66bf2`). All three
  PRs now share one common base/merge target; no history rewritten in
  the stack.
- **PR #4** (`feature/research-coverage-foundation` -> `master`):
  **merged**, 2026-10-12, on explicit owner instruction, same ordinary-
  merge-commit discipline (`456946f`, 89 commits). Verified
  independently: pre-existing `master` tip (`9d08640`) remains an
  ancestor (no history rewritten), and every key feature commit across
  all three prior PRs is now also an ancestor of `master`. **`master`
  is current.**
- **PR #5** (`feature/i3as-alert3-governance-cycle-hypothesis` ->
  `feature/research-coverage-foundation`): **merged**, 2026-10-12
  (`4ba89ab`), autonomously under the Quality-Gated Autonomous
  Development Protocol below -- full regression green (1,502 passed)
  before merge, no per-step owner approval needed for this routine
  gate. `feature/research-coverage-foundation` is now one PR ahead of
  `master` (PR #4's merge point); merging Alert-3 into `master` is a
  separate decision, not yet made.
- `gh` CLI authenticated this session via owner browser action (device
  flow); portable zip install used after the MSI installer hung on a
  UAC prompt it could not get non-interactively -- killed, no admin
  rights used or required.

## Quality-Gated Autonomous Development Protocol (owner-directed, 2026-10-12)

Supersedes this engagement's prior per-PR approval cadence into
`feature/research-coverage-foundation` (merges into `master` remain
excluded -- see below, unchanged). For previously-approved scopes:

- Implement, run targeted tests, complete a full regression pass,
  commit, push, and regular-merge (never squash/rebase) PRs into
  `feature/research-coverage-foundation` autonomously once all checks
  pass -- do not wait for owner approval at each routine PR gate.
- Full regression is the integration-acceptance bar; targeted tests are
  for development feedback only, not a substitute for it.
- Test parallelism may be considered, but only after confirming fixture
  isolation is genuinely independent -- not by default.
- While a long regression run is in flight, preparing independent
  next-step work is fine; merging or claiming completion before that
  run's result is known is not.
- Update this checkpoint after completed milestones, not after every
  routine operation -- this section itself is the first entry logged
  under that lighter cadence.

**Unchanged, still absolute:** no live-database changes, no production
migrations or deployments, no destructive operations, no history
rewriting, and no merge into `master` without the owner's own explicit,
separate instruction each time -- the 2026-10-12 `master` merge above
was exactly that explicit instruction, not a standing grant. The
Incident-to-Safeguard Doctrine continues to apply unchanged to any
future incident.

## I3AS Slice 1 (complete, 2026-10-12): legacy Trade/Telegram alert integration

Per the owner's approved design proposal and architecture decisions
(`2026-10-12-integrated-investment-intelligence-alert-system-design-
proposal.md`, §9), Slice 1 -- the legacy Trade/Telegram pathway
absorption -- was implemented, tested, and committed (`7db9295`,
`cd0358a`; PR #2 above). `AlertEvent`/`AlertDelivery` (two new,
purely-additive tables, migration `20261012_01`) and `AlertService`
now give the one pathway already live in production (`Trade.check` ->
`TickerManager.send_trade_notification` -> `TelegramService.
send_trade_alert`) a durable, auditable delivery record it never had
before, without changing that pathway's own behavior at all --
characterization tests pin its exact message content/recipient/return
value both before and after. Full regression suite: 1,493 passed, 0
failed.

**A same-day incident occurred during this slice's own development**,
fully resolved before the slice was considered complete: an ad-hoc
debugging script called `create_app()` directly (not through the
pytest fixture) and silently connected to the real
`instance/trading_app.db`, because no `.env`/`DATABASE_URL` exists
anywhere in this environment -- nothing distinguished that call from
main.py/console.py/live/websocket.py's own legitimate use of the exact
same default. Impact: 3 throwaway `User` rows and 16 tables created
out-of-band via raw `db.create_all()` (all empty except 3 rows each in
the two new alert tables) -- verified exhaustively, zero impact to any
pre-existing `company`/`ticker`/`trade` data. Recovered via: a
read-only-sourced `sqlite3.Connection.backup()` snapshot, a full
inventory, cross-validation against two independent older backups, a
rehearsal on a disposable copy (including a full `flask db upgrade`/
`downgrade` cycle proving the cleaned state is a genuinely healthy
baseline, not just visually similar), and -- only after the owner
reviewed and explicitly approved the exact recovery operations --
execution against the live file. Independently re-verified afterward:
45 tables (exact match to two independent prior backups),
`company`/`ticker`/`trade` row counts unchanged, the one real
production user intact, `alembic_version` unchanged at `20261007_05`,
`integrity_check: ok`. **Root-caused and fixed, not just patched**:
`create_app()` now fails closed unless the database URI was already
overridden (which the test fixture already does) or the caller passes
`allow_default_database=True` as an explicit, auditable, one-line
opt-in -- updated in all six real call sites, with dedicated tests
proving the guard fires for the exact incident shape and never fires
for tests. See commit `7db9295`'s message for the complete record.

## The Incident-to-Safeguard Doctrine (owner-named, 2026-10-12)

Formalizing the standing discipline the 2026-10-12 incident was already
handled under, so every future incident in this engagement is handled
the same way, not reinvented each time:

1. **Stop** -- halt the specific action class that caused the problem
   immediately on discovery; do not keep operating in the mode that
   caused it while investigating.
2. **Investigate read-only** -- establish exact scope and impact
   (inventory, row counts, dependency checks) without any write, on a
   verified backup or copy, never the live artifact itself.
3. **Rehearse** -- prove the proposed fix on a disposable copy first,
   including whatever downstream compatibility the real fix would need
   (here: a full `flask db upgrade`/`downgrade` cycle, not just a
   visual table-count match).
4. **Owner approves the exact operations** -- present the precise
   commands/diff, not a summary, before anything touches the real
   artifact.
5. **Execute, then independently re-verify** -- run the approved
   operations, then confirm the result against the pre-incident
   baseline from a fresh read, not by trusting the operation's own
   reported success.
6. **Root-cause, not patch** -- fix the actual mechanism that allowed
   the incident (here: `create_app()`'s missing opt-in guard), not just
   the symptom, with a test that would have caught the original
   incident shape and proves the fix doesn't break legitimate use.
7. **Record it in-line** -- the incident and its resolution live in the
   same commit/checkpoint as the work it happened during, not a
   separate quarantined document, so the history reads as what
   actually happened.

## I3AS Alert-2 (complete, 2026-10-12): Investment Brain alerts

Per the owner's approved design proposal, Alert-2 -- kill-switch
triggers, gate-`FAIL` results, and material `InvestmentCase`
view-changing supersessions -- was implemented, tested, and committed
(`093823a`; PR #3 above), reusing Alert-1's `AlertEvent`/
`AlertDelivery`/`AlertService` infrastructure completely unchanged --
no schema change, no new migration. `InvestmentCaseService.
trigger_kill_switch`/`record_gate_result`/`create_investment_case` each
call `AlertService.record_event` once after their own already-
committed write, wrapped so an `AlertService` failure (proven via a
hard-raising monkeypatch in tests, not just `AlertService`'s own
already-non-raising internal failure modes) can never affect the
authoritative Investment Brain write -- the same fail-safe-isolation
shape Alert-1 proved, now proven one level up the call stack.
Recipients are always `AlertService.admin_recipient_ids()` (admin-only,
per owner decision); existing Trade/Telegram alerts are untouched.
6 new tests extend the existing Slice G suite. Full regression suite:
1,499 passed, 0 failed. No live-database work was needed or performed
-- this slice added no schema.

## I3AS Alert-3 (complete, 2026-10-12): broader Research Brain event sources

Per the owner's approved design proposal, Alert-3 -- `GovernanceFlag`
(creation-time severity HIGH/CRITICAL only; LOW/MEDIUM/INFO emit
nothing), `CycleAssessment` supersession (genesis emits nothing;
`company_id` is `None` on this event type since `CycleAssessment` is
World-layer and company-independent by design, not a bug), and
`InvestmentHypothesis` supersession (genesis emits nothing) -- was
implemented, tested, and committed (`c8c3a09`; PR #5 above), reusing
Alert-1/Alert-2's infrastructure completely unchanged. Same fail-safe-
isolation shape proven twice already, now proven a third time. 3 new
tests extend the existing acceptance suites. Full regression suite:
1,502 passed, 0 failed.

**Real-company validation (owner-directed), performed and recorded
honestly:** ran against an isolated copy of the live database, backed
up read-only and migrated to head -- never the live file itself, per
the Incident-to-Safeguard Doctrine's own discipline -- using **UNO
Minda Limited's real company identity** (`9cbdabe1-...`), a real linked
`Document` (`UNO_REG30_CREDIT_RATING_14_09_2026`), and the real
Tachi-S JV `ResearchProposition` already present in the live corpus
(23 real `ExtractedFact` rows and 49 real linked documents exist for
this company; Chemplast Sanmar has 24 real linked documents but zero
`ExtractedFact`/`GovernanceFlag`/`ResearchProposition` rows -- none of
Phase 3's real-data pilots were ever persisted to the live file, as
recorded at every prior checkpoint). Both supersession-based sources
fired exactly once, correctly typed, correctly attributed to the real
company, with an **honest, non-fabricated `FAILED` delivery outcome**
reflecting the real admin account's genuine no-Telegram-connected
state -- not a bug, a correct report of real production account state.
**No real HIGH/CRITICAL governance event exists in either real
company's corpus to validate the `GovernanceFlag` source against** --
recorded here as a standing limitation rather than fabricated; that one
source remains fixture-validated only. The isolated copy was deleted
after the run; the live database's table count (45) and
`alembic_version` (`20261007_05`) were independently re-verified
unchanged both before and after.

## Wealth Desk: investment_case read API (complete, 2026-10-12)

Per the Overnight Autonomous Development mandate's instruction to
implement safe, reusable, read-only backend improvements while the
Wealth Desk UI proposal awaits owner review (see the architecture
proposal doc), the current `InvestmentCase` (view, revision metadata,
gate results, kill switches, scenario return spread) is now exposed as
a new `investment_case` section on the existing `research_bp`
company-detail aggregate. No new read pathway was introduced -- this
reuses the established `EntitlementService` /
`ResearchAccessPolicy.PREMIUM_SECTIONS` / `ResearchPresenter` /
marshmallow-schema stack exactly as every other premium section does.
Premium/admin only; free tier sees it as a locked section like every
other premium section. Implemented in `research_query_service.py`
(`_investment_case_dict`), new schemas in `schemas/research.py`, and a
small `InvestmentCaseService.list_kill_switches` read addition.

Both frozen-contract test files that hardcode the full premium-section
key/shape sets had to be extended properly rather than weakened:
`tests/security/test_research_data_isolation.py` (new shapes, new
`PROTECTED_FIELD_NAMES` entries, real sentinel-seeded fixture data
added to the shared `research_security_matrix` fixture so the new
section has real content to assert against) and
`tests/research/test_research_access_policy.py` (added
`"investment_case"` to its own independent `PREMIUM_SECTIONS` frozen
set). 2 new tests added directly
(`test_research_query_service.py`, `test_research_consumer_reads.py`).
Full regression suite: 1,504 passed, 0 failed.

**Real-company validation (owner-directed), performed and recorded
honestly:** ran against the same isolated, migrated copy of the live
database used for prior validations -- never the live file. Both real
companies (Chemplast Sanmar, UNO Minda) correctly return
`investment_case: None`, with no error and no fabrication, because no
real `ResearchRevision`/`ForecastRevision`/`ValuationRevision` exists
for any company in the live corpus (0 rows system-wide, confirmed) --
`InvestmentCase` hard-requires citing exactly those revision types, so
none can exist yet either. This is a continuation of the standing gap
already recorded at every prior checkpoint, not a new finding; the API
reports that true state honestly rather than manufacturing a case.

Committed as `a251984`, opened as PR #6, merged into
`feature/research-coverage-foundation` as `b2c0667` (regular merge
commit, no squash/rebase) -- a routine gate under the Quality-Gated
Autonomous Development Protocol, not requiring per-step owner
approval.

## Master Integration: Alert-3 + Wealth Desk read API (complete, 2026-10-12)

Per the owner's explicit "SPA -- Owner-Approved Master Integration"
instruction, `feature/research-coverage-foundation` was merged into
`master`. Before merging: fetched both branches and inspected the one
commit unique to `master` (`456946f`, the PR #4 merge-commit object
itself) -- confirmed its content parent (`2e66bf2`) was already an
ancestor of the feature branch tip, meaning master held no divergent
content the feature branch lacked. A local dry-run merge
(`git merge --no-commit --no-ff`) produced **zero conflicts** and a
diff of exactly 17 files / 643 insertions / 1 deletion, matching the
combined content of PR #5 (Alert-3) + PR #6 (Wealth Desk read API)
with no surprises. Full regression suite re-run against the merged
tree: **1,504 passed, 0 failed**.

Opened as **PR #7** (`feature/research-coverage-foundation` ->
`master`), verified `CLEAN`/`MERGEABLE` with the identical diff stat
GitHub-side, merged as a **regular merge commit** (no squash/rebase)
as commit **`f8da0f4`**. Local `master` fast-forwarded to `f8da0f4`;
independently re-verified HEAD and confirmed every individual commit
(`c8c3a09`, `4ba89ab`, `a251984`, `b2c0667`) is preserved intact in the
history, not squashed. No live database migration, write, or runtime
configuration change was made; no production deployment occurred.

**`master` is now current through I3AS Alert-3 and the Wealth Desk
`investment_case` read API.**

## Resume instructions for the next session

**Everything through the master integration above is complete.**
There is no pending implementation work to resume from any of it. If a
future session is asked to "continue Phase 3," "continue I3AS," or
"continue Wealth Desk," read this checkpoint first and confirm there
is genuinely new scope before writing any code.

**Next queued work (owner-directed, in order):**
1. "SPA -- Real-Company Investment Brain Acceptance": full
   real-data acceptance pass (Chemplast Sanmar primary, UNO Minda
   secondary) on an isolated, migrated database copy only -- inventory
   real evidence, build a source-backed ResearchRevision/
   InvestmentHypothesis where evidence permits, identify and escalate
   required financial/cycle assumptions rather than fabricate them,
   and only then build/validate an actual InvestmentCase end-to-end
   (gates, kill switches, scenario spread, consumer API, alerts/
   provenance) if and where inputs are genuinely justified. Report
   software-pass vs. real-data-pass status separately; update this
   checkpoint with the true acceptance status.
2. "SPA -- Priority Directive | 12-25 October 2026": provisional
   Private Wealth Desk UI (Daily Brief + Investment Coverage Grid +
   Company Workspace, on the existing Next.js frontend, wired to real
   research/InvestmentCase APIs, no mock conclusions) and Continuous
   Research Monitoring V1 (audit existing ingestion/scheduling first,
   smallest safe monitoring workflow, dedup/evidence lineage/run logs/
   failure handling/approval boundaries, no automatic recommendations
   from unvalidated evidence). Hard scope freeze through 2026-10-25:
   no Phase 3.5, Matrix Intelligence, Portfolio/Wealth Intelligence, or
   unrelated modules; no production deploy/live DB migration/
   destructive changes without separate authorization.

**Outstanding, owner-level only:**
- Deciding on I3AS's next scope, if any -- the design proposal's named
  slices (Alert-1/2/3) are now all complete; nothing further is named
  in it.
- Wealth Desk final UI/UX direction -- the owner has indicated they
  will finalize the UI directly per their own requirements; the
  provisional UI above is explicitly "provisional," not final design.
- The Research Orchestrator remains unbuilt and unauthorized, unchanged
  from every prior checkpoint.
