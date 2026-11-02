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

**Last updated:** 2026-11-02 (pipeline operations + daily automation
deployment -- `SPARS_SpaBridgeCatchup` re-enabled Ready for
2026-11-02 09:00:30 IST; 66 discovered rows acquired (4 new `STORED`,
60 exact duplicates, 2 manual-upload exceptions); the single chained
daily Cloud Run job (`--mode daily`, generation 84, image
`sha256:df19b1ed…`) was deployed at 01:50 IST; the first scheduled run
succeeded at 07:30 IST and the bridge registered 20 documents at 09:00
IST. STL row 1990 was closed as a semantic duplicate and Shanti Gold
row 2137 was registered; the remaining 16 duplicate-review rows were
then resolved (13 registered, 3 closed) and the duplicate-review queue
is now **0**. The NSE ZIP attachment fix was deployed as generation 85;
the two ZIP manual-queue rows were resolved (one STORED, one exact
duplicate), and the retry-queued exit-code fix was deployed as
generation 86. The full bridge run's transient Drive metadata timeout
is recorded as an operational reliability issue; a minimal correction
is proposed but not applied. The 2026-10-12 sections below remain the
prior milestone record.)

**Sync policy (2026-11-02):** This docs clone
(`C:\GitHub\stock-price-alert`) is the only place this checkpoint is
edited. The copy in the `stock-price-alert` frontend clone
(`C:\Users\Home\Documents\GitHub\stock-price-alert`) is a read-only
mirror: sync it from this clone, never edit it independently.

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

## Real-Company Investment Brain Acceptance: inventory (complete, 2026-10-12)

Per "SPA -- Real-Company Investment Brain Acceptance," ran a read-only
evidence inventory against an isolated, migrated copy of the live
database (never the live file) for Chemplast Sanmar (primary),
UNO Minda (secondary), and AXISCADES (added when the owner expanded
the monitoring-acceptance universe to three companies). Findings:

- **Chemplast Sanmar**: 24 real linked documents, **0** `ExtractedFact`,
  **0** `ResearchProposition`. Nothing has ever been extracted from its
  own documents -- not viable for an `InvestmentCase` build right now
  without new extraction work (separate scope).
- **UNO Minda**: 49 real linked documents, **23** `ExtractedFact` rows
  (22 current, all evidence-linked -- real 5-year financial trend,
  quarterly P&L, credit ratings, capex/JV announcements, governance/
  audit-trail disclosures) + **1** evidence-linked `ResearchProposition`
  (the Tachi-S JV thesis). The only one of the three with a genuine
  evidence base a `ResearchRevision`/`InvestmentHypothesis` could cite
  without fabrication.
- **AXISCADES**: 42 real linked documents, **0** `ExtractedFact`,
  **0** `ResearchProposition`. Same gap as Chemplast.
- System-wide: **0** `ResearchRevision`/`ForecastRevision`/
  `ValuationRevision`/`InvestmentHypothesis`/`GovernanceFlag`/
  `CompanyDisclosure`/`CycleAssessment`/`InvestmentCase` rows exist
  anywhere in the live corpus. The Investment Brain layer has never
  been fed real data -- confirms, with current real numbers, the
  standing gap already recorded at every prior checkpoint.

Per the owner's follow-up decision, all three companies were admitted
to the Continuous Monitoring V1 universe on this same inventory (their
source coverage and baseline are now verified, even though two of the
three have a sparse baseline) -- monitoring does not wait on any
company's `InvestmentCase` being complete. Building a real, source-
backed `InvestmentCase` remains a separate, slower, owner-escalation-
gated track, currently viable only for UNO Minda; that build has not
been started (the owner redirected to Continuous Monitoring V1 before
it began) and is not resumed automatically -- re-confirm scope first.

## Continuous Research Monitoring V1 (complete, 2026-10-12)

Per "SPA -- Continuous Monitoring V1 Approved." Before building
anything, audited the existing M1 ingestion/extraction pipeline
end-to-end and reported findings before changing any design (owner
instruction). Four stages, one real gap:

1. **Upstream filing discovery** -- happens entirely outside this repo
   (a separate SPA ingestion worker populates a Google Sheets
   manifest). Not part of this codebase; untouched.
2. **Manifest polling** (manifest -> M1 Document Library) --
   `scripts/bridge_spa_manifest.py` already does this correctly, but
   has always been manual/on-demand. **This is the one real gap**,
   and the only one Monitoring V1 closes.
3. **Document registration** -- `DocumentLibraryService.create_document`
   already works correctly; no gap.
4. **Extraction** (document -> `ExtractedFact`/Research Brain) --
   **not a gap**. Confirmed deliberate, by two independent pieces of
   hard evidence: `DocumentValidationService` explicitly rejects any
   `STORED -> ANALYSED` transition ("Milestone 1 cannot transition
   documents to ANALYSED"), and `ResearchCoverageService`'s own
   docstring states linking a finding "is always deliberate and
   reviewer-initiated -- there is no automated matching." Nothing
   anywhere in the app currently even exposes an HTTP route to trigger
   extraction either way. Automating this was correctly identified as
   out of scope and was **not** built.

**Architecture clarification the owner gave in response to this
finding, recorded verbatim for future sessions:** human-only
extraction is a **current M1 boundary, not SPA's permanent
objective**. The eventual direction is **automated evidence
extraction and classification, with provenance, validation, and
human approval for consequential investment judgments** -- i.e. a
future milestone should automate the mechanical extraction step while
keeping a human approval gate specifically on investment-consequential
conclusions, not remove human judgment altogether. No such milestone
is scoped or authorized yet; this is a direction marker for whoever
scopes it next, not a standing task.

**What was built** (scope held to exactly manifest polling +
registration + dedup + run logs + admin notification, per the owner's
explicit approval -- no extraction automation, no research-approval
rule changes):
- `MonitoringRun` (new, minimal, additive table + migration): one
  audit row per scan. Deliberately mutable (`RUNNING` -> one terminal
  update) -- the same shape `Trade` already uses; `BaseModel` itself
  has no blanket immutability listener, so no new exception was
  needed. Scoped to the three-company pilot universe above.
- `MonitoringService`: wraps the existing, unchanged, idempotent
  bridge via an injectable `run_fn` seam (tests never need live
  Google credentials). Records status/counts/errors/company scope;
  assesses manifest freshness from each row's own real Document Date
  (reports `UNKNOWN` when unverifiable, **never** defaults to
  `FRESH` -- "never equate a successful scan with complete exchange
  coverage" is enforced in code, not just documented). Reuses
  `AlertService` with three new, stably-deduplicated event types
  (`MONITORING_RUN_DOCUMENTS_DETECTED`, `MONITORING_RUN_FAILED`,
  `MONITORING_MANIFEST_STALE`). A clean, no-change, non-stale run
  raises no alert at all -- the `MonitoringRun` row itself is that
  case's audit trail (avoids Telegram noise, per owner requirement).
- `scripts/run_monitoring_scan.py`: single-pass CLI, no internal
  loop/cadence -- the scheduling mechanism (Windows Task Scheduler for
  this bounded pilot) stays fully external and portable. Keeps the
  fail-closed `create_app()` database guard unchanged (requires an
  explicit `DATABASE_URL`; never `allow_default_database`).
- A small, additive, backward-compatible enrichment to the existing
  bridge's own `run()`: every outcome dict now also carries the row's
  real manifest Document Date, avoiding a second Sheets read.

8 new tests. Full regression suite: **1512 passed, 0 failed**.
Committed as `ca1d1ae`, opened as PR #8, merged into
`feature/research-coverage-foundation` as `f711d3d` (regular merge
commit). Not merged into `master`.

**Scheduled-run demonstration, reported honestly:** two genuine
Windows Task Scheduler executions against an isolated dev database
copy (never live) each correctly recorded a `FAILED` `MonitoringRun`
(a real missing-dependency error, since caught and fixed) and
correctly alerted admins -- proving the full audit/alert pipeline
end-to-end under the real OS scheduler engine, not a raw subprocess.
**True live-manifest connectivity (an actual document detected
end-to-end) could not be verified from this sandboxed dev
environment**: after installing the missing dependency and confirming
real credentials are present, the real Google Sheets API call still
hangs past a bounded 60-second Task Scheduler execution-time-limit,
despite a bare TCP connection to Google's own host succeeding
immediately. This is recorded as an **unresolved environment/egress
limitation**, not papered over -- **owner decision needed**: verify
real connectivity from a host with confirmed Sheets API egress (e.g.
the actual production/worker host) before relying on this pilot for
anything beyond the bounded dev demonstration already completed.
Two `MonitoringRun` rows from killed/timed-out attempts were left in
`RUNNING` state in the isolated dev copy only (never live) -- a real,
minor, known gap: nothing yet reconciles a run killed externally back
to a terminal state. Not fixed in this slice (out of approved scope);
flagged here for whoever picks up Monitoring V2.

## Resume instructions for the next session

**Everything through Continuous Monitoring V1 is complete.** `master`
is current through PR #7 (Alert-3 + the Wealth Desk `investment_case`
read API). `feature/research-coverage-foundation` additionally holds
Continuous Monitoring V1 (PR #8) on top of that -- not yet merged into
`master`; that merge is a separate decision, not yet made. The
Wealth Desk UI (Daily Brief + Investment Coverage Grid + Company
Workspace, provisional) and the real `InvestmentCase` build for UNO
Minda remain the next executable items -- see "SPA -- Priority
Directive | 12-25 October 2026" and the Real-Company Acceptance
section above. If a future session is asked to "continue Monitoring,"
"continue Wealth Desk," or "continue Investment Brain acceptance,"
read this checkpoint first and confirm there is genuinely new scope
before writing any code.

## Wealth Desk UI, provisional slice 1 (complete, 2026-10-12)

Per "SPA -- Resume Development." Before writing any code: verified the
latest committed state across all three repo clones, and fast-forwarded
the frontend clone (`C:\Users\Home\Documents\GitHub\stock-price-alert`,
which had fallen 6 commits behind) to match the docs clone -- a clean,
safe fast-forward, no local work at risk.

Built the full agreed structure (Daily Brief + Investment Coverage
Grid + Company Workspace) on a fresh branch
`feature/wealth-desk-ui`, wired to the real backend (`GET
/research/companies`, `GET /research/companies/:id>`) -- no mock
data. Existing Trade/Telegram pages and nav untouched; only the dead
"Dashboard" (`#`) link was repointed to the new Daily Brief, and one
new "Investment Coverage" nav entry added.

Verified `tsc --noEmit`, `eslint`, and `next build` all clean (zero
new warnings beyond pre-existing ones in unrelated files). Ran a real
end-to-end smoke test against a live backend instance pointed at the
isolated dev database copy (never live) as both a genuine PREMIUM and
a genuine FREE test user -- this caught and fixed one real bug before
it shipped: `governance.status` can be `null` while the `governance`
object itself is still present (independent of whether any flags
exist), which the first empty-state check didn't distinguish from
"no governance section at all." **No real browser/visual QA was
possible in this headless environment** -- reported honestly rather
than claimed.

**One decision point surfaced, not blocked on:** the agreed Daily
Brief design is alert-first, but no HTTP route exists yet for I3AS's
`AlertEvent` feed (confirmed by reading `app/routes/*.py` directly --
unchanged from the Codebase Registry's standing "known gap"). Rather
than inventing alert data, Daily Brief currently shows the real
research-universe count/list with an explicit, honest banner saying
the live feed isn't connected yet. Wiring a real feed would need a
small, additive, read-only backend endpoint (same shape as the
`investment_case` extension) -- not built in this slice; flagged here
for the owner's call on priority (2) ("resolve real Google Sheets
ingestion") vs. this.

Committed as `5e5ed21` on `feature/wealth-desk-ui`, pushed to the
`stock-price-alert` repo. **Not merged anywhere** -- no merge
authorization was given for the frontend repo in this task, and the
owner has separately indicated they will finalize UI direction
themselves; this stays a reviewable branch until told otherwise.

## Resume instructions, Wealth Desk UI

Slice 1 (Daily Brief, Coverage Grid, Company Workspace shell) is
complete and pushed. Not yet done: disclosures/history views (the
`/research/companies/:id/disclosures` and `/history` endpoints exist
but are not yet consumed by any page), the small alerts-read backend
endpoint the owner may or may not want next, and any visual QA in an
actual browser (not possible from this environment). If a future
session is asked to "continue Wealth Desk," read this section and the
pushed branch's own commit before writing more UI code.

## Wealth Desk UI, slice 2: admin alerts feed (complete, 2026-10-12)

Per the owner's explicit instruction to build the alerts endpoint
first, then wire Daily Brief to it. Backend:
`GET /api/admin/alerts` (new `AlertService.list_recent_events`,
admin-only, newest-first across every event source, `limit`
query param bounded 1-200). 6 new tests; full regression 1518
passed, 0 failed. Committed `636e0a6`, PR #9, merged into
`feature/research-coverage-foundation` as `f55f55f`. Not merged into
`master`.

Frontend: Daily Brief now reads the real feed instead of the
placeholder banner. Gates on the current user's own `is_admin` before
fetching, since the endpoint is admin-only -- a non-admin viewer sees
an honest "admin-only" notice instead of an unexpected 403. Each
alert links through to its company's Workspace when it has one.
Committed `e8d6868` on `feature/wealth-desk-ui`, pushed. Not merged
anywhere.

Verified end-to-end against a real backend instance (isolated dev DB
copy, never live) as a real admin user and a real non-admin user:
correct ordering, correct 403 handling, and genuine heterogeneous
events (a Trade alert and a real Monitoring-sourced alert left over
from the earlier Task Scheduler demo) interleaving correctly by
recency. Same browser/visual-QA limitation as slice 1 -- not possible
in this headless environment.

## Priority 2: Google Sheets manifest connectivity -- root-caused and fixed (complete, 2026-10-12)

Per "SPA -- Next Priority." Two distinct, now-fixed problems, not
one -- found by direct diagnosis (TLS probes, `curl` against
individually-resolved IPs, and `faulthandler.dump_traceback_later`
catching a real run mid-hang), not guessed at:

1. **No timeout configured anywhere.** Neither
   `sheets_reader.build_sheets_service()` nor
   `drive_evidence.build_drive_service()` set any socket timeout on
   their HTTP transport. This PC's real network reaches Google's
   anycast pool for these APIs and is mostly healthy, but occasionally
   a connection completes a TCP+TLS handshake against a node that then
   never returns an HTTP response -- confirmed live: a faulthandler
   dump caught a real run blocked indefinitely inside `httplib2`'s
   socket read, mid-TLS-`recv`. With no timeout anywhere, one bad pick
   hung the whole process forever. **Not** a credentials, DNS, or
   proxy problem -- `netsh winhttp show proxy` and WinINET settings
   both confirmed no system proxy; the OAuth tokens and
   `SPA_MANIFEST_SHEET_ID` were already correct and already present
   on this PC from earlier historical-backfill work. Fix: both
   builders now wrap their credentials in
   `google_auth_httplib2.AuthorizedHttp(credentials,
   http=httplib2.Http(timeout=15))` -- a bad pick now fails in 15s
   instead of hanging.
2. **A previously-masked per-row cost, exposed only once (1) stopped
   masking it as "hung forever."** `bridge_spa_manifest.run()`'s
   metadata-only Drive lookup (the non-`--verify-hash` path) rebuilt a
   brand-new authenticated Drive client -- fresh credential load, fresh
   TCP/TLS handshake -- for every single manifest row, measured at
   ~1.5-2.4s each. Across the ~160-260 real rows one scan touches,
   that alone adds minutes. Fix: build that client once, lazily, and
   reuse it across every row -- the same hoisting
   `build_sheets_service()` already did correctly elsewhere in the
   same function.

**Verified with the real manifest and real credentials, never the
live database:**
- One genuine Sheets API read (Universe + Documents tabs): ~2.7s
  each, 93 and 3082 real rows.
- Two full `MonitoringService` scans back to back against an
  isolated dev database copy: both `SUCCESS`, 258 real manifest rows
  scanned each time, 0 errors, identical idempotent results (0 newly
  registered, 258 `ALREADY_REGISTERED`). Document row count unchanged
  (1251) across both runs -- no duplicates created. Each full scan
  completed in ~113-135s, bounded and predictable, down from an
  unbounded hang.
- Full backend regression suite: 1518 passed, 0 failed.

**Upstream discovery coverage vs. manifest ingestion, kept
distinct as instructed:** this fix verifies **manifest ingestion**
only -- that SPA's own worker-discovered, already-`STORED` rows can
be read and registered reliably. It says nothing about, and cannot
verify, that external SPA ingestion worker's own **upstream
discovery coverage** (whether it has actually found everything that
exists on the exchanges for these companies) -- that is a separate
system, outside this repo, untouched and unverified by this work.

**Remaining operational limitation, reported honestly:** ~2 minutes
for a 3-company scan is bounded and reliable but not fast; a larger
pilot universe would scale roughly linearly unless Drive metadata
lookups are batched -- a larger change correctly out of scope for
"without redesigning ingestion."

Committed `043a563`, PR #10, merged into
`feature/research-coverage-foundation` as `061b3b3`. Not merged into
`master`. SPARS search-first landing-page redesign left pending
owner visual approval, as instructed -- not touched.

**Owner's stated priority order for the three next items above**
(2026-10-12, given at the stop-and-save checkpoint; revisitable at
resume, not a fixed commitment): **(1) provisional Wealth Desk UI**
-- gives a usable interface, **complete** (slices 1-2 above);
**(2) resolve real Google Sheets ingestion** -- makes Continuous
Monitoring V1 actually operational, **complete** (above);
**(3) complete real-company Investment Brain acceptance** -- validates
the depth and reliability of SPA's research conclusions. **Next up.**

## Repository Housekeeping & Disaster Recovery Backup (complete, 2026-10-12)

Per "SPA -- Repository Housekeeping, Recovery Backup & Closure." No
new feature work; no live-database change; no production deploy.

**Pre-cleanup safety snapshot** taken and accepted before any
cleanup action (git bundles of all three local clones, a read-only-
safe live-DB backup, an archive of the current production worker).
See `C:\SPA\DisasterRecovery_20261012_150645\PRE_CLEANUP_SNAPSHOT_MANIFEST.md`.

**Authorized cleanup executed exactly as scoped, nothing beyond it:**
- Deleted `.next` (frontend build cache) and all 24 backend
  `__pycache__` folders -- only after confirming no python/node/
  pytest process was running. Both regenerated cleanly afterward
  (`next build` succeeded; `pytest --collect-only` found all 1,518
  tests; `create_app()` started with 46 routes, identical to before).
- Deleted the 3 disposable session test-DB copies
  (`migration_dev_copy.db`, `acceptance_copy.db`,
  `rehearsal_copy.db`) and 5 regression log files -- only after
  extracting and preserving their final pass/fail summary lines
  (`preserved_test_results/regression_results_summary.txt`) and
  confirming none is referenced by any recovery procedure.
- **Not** deleted: `trading_app_incident_backup.db` (the live-DB
  incident's own recovery record) -- copied, not moved, into a new
  durable, clearly labelled `incident_archive/`, with the original
  scratchpad copy left untouched and a SHA-256 match confirmed
  between original and copy.
- **Not** deleted: all 12 historical/superseded Cloud Run worker
  folders -- copied into one verified archive
  (`spa_worker/historical_cloudrun_folders.zip`; zip integrity and
  every folder's exact file count independently verified against
  the untouched originals), originals left in place exactly as
  found.
- **Not touched at all** (correctly out of scope): `node_modules`,
  the historical worker folders/loose zips themselves, `dev-tools/`,
  the loose `.py`/`.xlsx` files at `C:\SPA` root, any Git branch or
  clone, the live database, and all credentials. No Git remote
  changed; no history rewritten.

**Exit-code-255 survey failure, recorded as instructed:** an earlier
background directory-size survey (Git-Bash `du` against
`node_modules`) was deliberately killed for taking too long on
Windows -- its exit code 255 reflects that termination, not a
measurement or data error. Every size figure actually used in the
cleanup proposal and this backup was obtained afterward via an
independent, successful PowerShell measurement. Separately and
explicitly flagged as genuinely unverified (not blocking anything
authorized): whether the loose top-level zips at `C:\SPA` root are
byte-identical to their same-named folders, and whether the loose
`.py`/`.xlsx` files there are still imported by `cloudrun_fixed_v7_5`
-- neither question needed answering since neither item was touched.

**Full encrypted disaster recovery package, built and verified:**
- `repos/`: verified `git bundle --all` of all three local clones.
- `database/`: a fresh read-only-safe live-DB backup.
- `spa_worker/`: the current production worker + the historical
  archive above.
- `secrets_encrypted/spa_credentials_20261012.tar.gz.gpg`: all 5
  Google OAuth credential files (2 Sheets + 2 Drive pairs plus the
  Drive client registration), AES-256 encrypted via `gpg
  --symmetric`. **Never committed to Git.** Round-trip decrypted and
  SHA-256-verified byte-identical to the live files before the
  plaintext staging copy was deleted. The passphrase was reported to
  the owner directly in the session transcript only -- it is not
  written anywhere in this backup or in any repo.
- `checksums/SHA256SUMS_final.txt`: SHA-256 of all 14 files in the
  backup.
- **Isolated restore rehearsal, genuinely performed, not assumed:**
  cloned the backend bundle into a fresh directory -- `create_app()`
  started with 46 routes, identical to the live working copy;
  extracted the historical-worker archive -- all 12 folders' file
  counts matched their untouched originals exactly; restored the
  database backup into an isolated copy -- queried real data (69
  companies, 1 user) and confirmed `alembic_version` matches the
  live file. One genuine, *expected* finding surfaced by this
  rehearsal: the restored DB has no `monitoring_run` table, because
  the live database has never had that migration applied -- an
  accurate reflection of reality, not a backup defect. Full detail
  in `restore_rehearsal/RESTORE_REHEARSAL_RESULTS.md`.

**Independent/off-machine storage: BLOCKED, tested with a real
write attempt, not assumed.** A genuine `files().create()` call
against the owner's designated Google Drive destination returned a
real `403 Insufficient Permission` -- the only Drive credential
present on this machine is scoped `drive.readonly`; no write-capable
token exists, and minting one needs the owner's own interactive
browser consent (not performed autonomously). **This backup
currently exists in exactly one place: this PC's local disk.**
Recommended owner action: manually copy at least
`secrets_encrypted/`, `repos/`, and `database/` to a second
location at their convenience.

**Overall disaster-recovery status: PARTIAL**, per the owner's own
instruction to report PARTIAL rather than VERIFIED when any
essential storage destination is unavailable -- every other
component (snapshot, cleanup, encryption, checksums, restore
rehearsal) is genuinely verified; only the off-machine copy is
missing.

## Resume instructions, after housekeeping & backup

## Final Disaster Recovery Completion (complete except off-PC transfer, 2026-10-12)

Per "SPA -- Final Disaster Recovery Completion." No new feature
work, no live-DB migration, no deployment.

1. **Credential security, fixed.** The original encrypted archive's
   passphrase had been exposed in the chat transcript. Generated a
   new passphrase with Python's `secrets.token_urlsafe(48)`, written
   *only* to a dedicated file
   (`C:\SPA\DR_Secrets_DO_NOT_COMMIT\spa_credentials_passphrase_20261012.txt`,
   access restricted to the owner's own Windows account via
   `icacls`) -- never printed, logged, or committed anywhere.
   Re-encrypted `secrets_encrypted/spa_credentials_20261012.tar.gz.gpg`
   with it, round-trip verified (all 5 credential files SHA-256
   match their originals), then deleted the old,
   passphrase-compromised archive. Checksums manifest regenerated
   and self-verified (`sha256sum -c`: all 15 files `OK`).
2. **Google Drive 403, root-caused, not yet resolved -- needs the
   owner's own browser.** The existing `authorize_drive_oauth.py`
   script (already present in `cloudrun_fixed_v7_5`, requests the
   full `.../auth/drive` scope) runs a local interactive OAuth
   consent flow that only the owner can complete. The command is
   recorded in `BACKUP_MANIFEST_AND_RESTORE_GUIDE.md` for the owner
   to run themselves -- deliberately the plain Python script, not
   `Authorize-DriveOAuth.ps1` (which also pushes the result into
   Google Cloud Secret Manager and grants the production Cloud Run
   service account access to it -- out of scope for a backup task
   and not run).
3. **Off-PC backup: still not executed -- Drive write access
   remains unavailable pending (2).** Precise manual USB/SSD/
   office-PC transfer instructions (exact `robocopy` command,
   separating the passphrase file from the backup physically, and
   post-transfer `sha256sum -c` verification) are written into
   `BACKUP_MANIFEST_AND_RESTORE_GUIDE.md`. Neither path (Drive or
   manual) has actually been executed yet -- both require an action
   only the owner can perform.
4. **DR-01 office-PC restore guide finalized**:
   `C:\SPA\DisasterRecovery_20261012_150645\DR-01_OFFICE_PC_RESTORE_GUIDE.md`
   covers prerequisite tools (Git, Python 3.12.x, Node 22.x/pnpm via
   Corepack, GPG, Claude Code, Cursor), restoring all three repos
   from their bundles, rebuilding the Python venv and frontend
   `node_modules` from scratch, restoring the database to an
   **isolated** copy only (explicitly never the live file, with the
   exact wrong command called out as "the mistake that caused the
   original incident"), decrypting credentials, and the same
   verification commands this backup's own rehearsal already used.
   Explicitly out of scope and called out as such: connecting to
   real production, redeploying the Cloud Run worker, or trusting
   Sheets/Drive connectivity on a new PC without re-verifying it
   independently.

**Backup location (local):** `C:\SPA\DisasterRecovery_20261012_150645\`,
30.03MB, 17 files (15 content files + 2 checksum manifests), all
SHA-256 checksummed and self-verified.

## Off-PC upload completed and verified (2026-10-12, same day)

The owner completed the Drive OAuth consent themselves (interactive
browser flow, `authorize_drive_oauth.py`), producing a write-capable
token (`C:\SPA\private\spa-drive-write-oauth-token.json`, scope
`https://www.googleapis.com/auth/drive`). Verified with a real
write-then-delete test file before trusting it with the real upload.

Uploaded the complete backup (all 17 files, full folder structure
preserved) to Google Drive under **`SPA_Disaster_Recovery/DisasterRecovery_20261012_150645/`**
(folder link: `https://drive.google.com/drive/folders/1td2wZvV87frbomAj0LwZJqMXwRXYqtBA`).
**Every file's MD5 was computed locally and compared against the
MD5 Drive itself reports for the uploaded copy -- all 17 matched,
zero mismatches.** This is a genuine integrity check of the uploaded
bytes, not just an "upload succeeded" status code.

**Overall status: VERIFIED.** All three legs are now independently
confirmed: (1) the local backup exists, is complete, and was
restore-rehearsed; (2) credentials are encrypted with a passphrase
that was never exposed; (3) an off-machine copy now exists in Drive,
with per-file integrity verified against the local originals. The
live database was re-confirmed untouched (`alembic_version`
`20261007_05`, same file, same timestamp) throughout this entire
backup-and-upload process.

## Pipeline operations checkpoint (2026-11-01/02)

Per the owner's 2026-11-01 follow-up: explain and fix the disabled
`SPARS_SpaBridgeCatchup` task, acquire the day's 66 `DISCOVERED` rows,
and flag (not implement) whether discovery and acquisition should be
chained. No code, deployment, credential, or infrastructure changes.

### Owner's overnight closing position (recorded as stated)

- 47 documents recovered; 8 duplicate rows closed; 5 exceptions
  remaining; SPARS bridge scheduler disabled; no further development
  authorized that night.
- Verified: the 47 recovered documents are exactly the backend
  `document` rows created since midnight IST (`document` count 1,368;
  `max(created_at)` = 2026-10-31 22:39 UTC). The recovery logs show
  46 + 1 = 47 `REGISTERED`; the earlier catch-up registered 0 new
  (2,509 rows all `ALREADY_REGISTERED`, 1 documented missing Drive
  file).

### Scheduler state: why it was Disabled, and the fix

- **Created Ready:** 2026-11-01 00:13:05 IST via
  `schtasks /create /tn "SPARS_SpaBridgeCatchup" /tr ... /sc DAILY /st 09:00 /ru "Home"`;
  verified `Status: Ready`, next run 01-11-2026 09:00 at 00:13:11 IST.
- **Disabled by the prior session:** 2026-11-01 02:13:35 IST via
  `Disable-ScheduledTask`, per the prior explicit instruction to
  disarm the task before the bridge patch and leave it off pending
  release review. This was not a failed registration or a different
  task; the same task's `NextRunTime` still displays while disabled,
  which is why it looked armed.
- **Re-enabled on the current owner instruction:** 2026-11-01
  evening. Verified `State=Ready`, `Settings.Enabled=True`, trigger
  enabled, next run **2026-11-02 09:00:30 IST**,
  `LastTaskResult=267011` (never run).
- **Caveat (unchanged):** the task runs as `Home` with
  `InteractiveToken`; it requires the PC on and the Home session
  logged in at 09:00, and has no `StartWhenAvailable`. Changing that
  would be a separate settings decision.
- **Patch state:** `scripts/bridge_spa_manifest.py`,
  `scripts/scheduled/run_spa_bridge_catchup.bat`, and
  `app/services/monitoring_service.py` fixes are committed
  (`57d14d0`, `f40a19e`, `ad83ccc`); the bridge CLI imports cleanly;
  the repo working tree is unchanged by this checkpoint.

### Acquisition of 2026-11-01's 66 DISCOVERED rows

Used the existing local worker path (`Run-Local.ps1` with the
`spa-ingestion-worker` service-account key and the production
`SPA_DRIVE_OAUTH_JSON` secret): `--mode promote-discovered`, then
`--mode ingest-all --limit 66` (eligible rows sort descending by sheet
row, so this targeted exactly rows 3219–3284).

| Status | Before | After promotion | After acquisition |
|---|---:|---:|---:|
| `STORED` | 3,056 | 3,056 | **3,060 (+4)** |
| `DISCOVERED` | 66 | 0 | 0 |
| `AWAITING_UPLOAD` | 5 | 71 | 5 (old Aug–Sep rows) |
| `MANUAL_UPLOAD_QUEUED` | 91 | 91 | **93 (+2)** |
| `DUPLICATE_EXACT_BINARY` | 65 | 65 | **125 (+60)** |
| **Total** | **3,283** | **3,283** | **3,283** |

Discovery source stats (07:30 IST Cloud Run run):

| Source | Attempted | Succeeded | Accepted/appended | Failed | Note |
|---|---:|---:|---:|---:|---|
| BSE-AJAX | 77 | 0 | 0 | 77 | HTTP 403, known WAF block |
| BSE-RSS | 1 | 1 | 0 | 0 | 9 fetched; 0 new |
| NSE | 73 | 73 | **66** | 0 | 98 items → 66 new |

Acquisition: `manifest_url` for all 64 successful rows (4 stored,
60 duplicate); the remaining 2 exhausted all six routes
(`manifest_url;bse_archive;exchange_rss;screener;business_standard;alternate_url`)
and were queued for manual upload.

#### 4 newly STORED documents (Drive + manifest verified)

| Row | Company | Type | Date | Drive file | Size |
|---:|---|---|---|---|---:|
| 3219 | AXISCADES Technologies Ltd | REG30 | 2026-10-31 | `AXISCADES_REG30_31_10_2026_251B4322.pdf` | 265,680 B |
| 3263 | Juniper Green Energy Ltd | QUARTERLY_RESULTS | 2026-10-31 | `JUNIPER_RESULTS_31_10_2026_9D1FE9DC.pdf` | 1,436,196 B |
| 3283 | Priority Jewels Ltd | INVESTOR_PRESENTATION | 2026-10-31 | `PRIORITY_PRESENTATION_31_10_2026_4683CE2B.pdf` | 2,544,431 B |
| 3284 | Priority Jewels Ltd | REG30 | 2026-10-31 | `PRIORITY_REG30_31_10_2026_5B049158.pdf` | 11,135,258 B |

Drive IDs: `1GvUndxUL7SJH8WODY2ub-tI8rrN64KV3`,
`1g8PQbL24aCmrLXleIi4uHGjJ3-cHbM6v`,
`1pX_m252_PdS_wgEXQLHW3i1SBmdxqPnd`,
`12xUrwKGC_kTez3ndCTN7J7055_FRtv1a`; all match their manifest rows;
files created 16:28–16:41 UTC (21:58–22:11 IST).

#### 60 exact duplicates

Downloaded and SHA-256-verified, but not stored as new files because
the bytes already exist under another manifest row. They are now
`DUPLICATE_EXACT_BINARY` and carry the existing Drive File IDs. This
is a dedupe outcome, not an acquisition failure.

#### 2 new manual-upload exceptions

| Queue row | Company | Document | Failure | Recommended |
|---:|---|---|---|---|
| 351 | Tempsens Instruments (India) Ltd | REG30, 2026-10-30 | `missing_pdf_signature;no_configured_url`; all six routes attempted; source is an NSE ZIP | download exact PDF from Screener |
| 350 | Morepen Laboratories Ltd | REG30, 2026-10-31 | `missing_pdf_signature;no_configured_url`; all six routes attempted; source is an NSE ZIP | download exact PDF from Screener |

The queue already had older entries for the same two documents
(rows 345/348 for Tempsens, 346/349 for Morepen), so retries are
appending repeat queue rows. Not fixed; flagged for the next session.

### Backend state

- `document` count unchanged at **1,368**; `max(created_at)` still
  **2026-10-31 22:39 UTC** (the 47 overnight manual recoveries).
- The 4 new `STORED` rows await the bridge run at
  **2026-11-02 09:00:30 IST**; AXISCADES, JNPR, and PRIORITY are all
  inside the bridge's `--only-tickers` scope.
- The 60 duplicate rows and 2 queued rows are not `STORED` and will
  not be picked up by the bridge.

### Chaining decision (made 2026-11-02): single chained daily Cloud Run job

The owner approved the single chained daily job after the release gate.
The earlier recommendation for two scheduled steps was superseded once
the Cloud Run task timeout was raised and the BSE-AJAX known-degraded
status was fixed.

**Deployed 2026-11-02 01:50:14 IST** to the existing
`spa-ingestion-live-test` job (no new job, no scheduler change):
- generation **84**
- image
  `asia-south1-docker.pkg.dev/spa-ingestion/cloud-run-source-deploy/spa-ingestion-live-test@sha256:df19b1ed88ddbc75d09e2de9c8c01275c12cd6d83b09f2beefbbd71401e07e80`
- args `cloud_entrypoint.py --mode daily --lookback-days 7 --limit 100`
- task timeout **2400s**; max retries **1**; 1 task; 1 CPU / 2 GiB
- env adds `SPA_MANUAL_CHECK_FOLDER_ID`; the Drive secret is unchanged
- scheduler unchanged: ENABLED, `0 2 * * *` Etc/UTC (07:30 IST),
  180s attempt deadline, target `:run`; next run 2026-11-02 07:30 IST
- the first automatic run succeeded at 07:30 IST on 2026-11-02; the
  bridge ran at 09:00:30 and registered 20 documents (see the
  post-deployment subsection below).

The daily mode does discovery → promotion of `DISCOVERED` rows →
bounded acquisition (oldest-first, 100 max) in one execution. BSE-AJAX
403 is reported as known-degraded and no longer makes the cycle fail;
real NSE/BSE-RSS failures still produce DEGRADED/FAILED. The explicit
`ingest-all` mode keeps newest-first for manual use. The release-gate
starvation test proved newest-first could strand the oldest rows under
a >=limit arrival day; oldest-first fixes that.

**Rollback:** `release_gate/spa-ingestion-live-test.pre-automation.yaml`
restores generation 83, old digest `sha256:3630c8cf…`, args
`discover --lookback-days 7`, 900s timeout, 0 retries. Fallback
`gcloud run jobs update` commands and source-level backups
(`release_gate/source-pre-automation/`) are recorded in
`release_gate/DEPLOYMENT_RESULT_2026-11-02.md`. No schema/data
rollback; the manifest/Drive changes are additive and idempotent.

**Backend coverage limitation:** the Windows bridge's
`--only-tickers` scope has 67 tokens and covers **67 of the 93
approved companies**. 26 are outside it:
- 2 have M1 identities but are omitted from the batch list: **IKIO**
  and **GRAUWEIL** (adding them would also backfill their historical
  `STORED` rows; needs a scoped run/approval);
- 4 have NSE symbols but no M1 ticker: **JASCHIND, ASINPET, CHEMKART,
  MRTX**;
- 20 are BSE-only with no M1 ticker (the known identity-exception
  queue).

Full 93-company backend automation is therefore not yet complete: the
daily Cloud Run job covers all 93 on discovery/acquisition, while the
bridge registers 67.

### First post-deployment runs and two duplicate resolutions (2026-11-02)

- **Cloud Run 07:30 IST — SUCCESS.** Execution `sxxgr`, 9m58s
  (07:30:15–08:10:13). Discovery 23 new; processed 28 (23 new + 5 old
  AWAITING); stored 19; exact duplicates 9; manual queue 0; other issues
  0. BSE-AJAX 77/77 403 was `known_degraded` and did not fail the run;
  NSE 73/73, 23 accepted; BSE-RSS 1/1, 0 accepted.
- Manifest after: **STORED 3,079 / DUPLICATE_EXACT_BINARY 134 /
  MANUAL_UPLOAD_QUEUED 93 / AWAITING_UPLOAD 0 / DISCOVERED 0**; total
  3,306.
- **Bridge 09:00 IST — completed, exit 1 on duplicate-review warnings.**
  20 REGISTERED (the four pending rows 3219, 3263, 3283, 3284 plus 16
  new rows), 1,621 ALREADY_REGISTERED, 864
  ALREADY_REGISTERED_METADATA_CONFLICT (informational), 18
  DUPLICATE_REVIEW_REQUIRED, 1 documented missing Drive file. Backend
  `document` count 1,368 → **1,388**.
- **STL 1990 closed.** The manifest PDF is a scanned 3-page NSE copy of
  the same STL Networks resignation filing already in the backend as
  `8d210bcc` (3-page BSE text copy; Ms. Prerna Wadhwa, 2026-08-04).
  Manifest row set to `DUPLICATE_EXACT_BINARY` with a review note; no
  backend document added. Not byte-identical; owner-approved semantic
  closure.
- **Shanti Gold 2137 registered.** The manifest PDF is the 5-page full
  Board Meeting Outcome; backend `2d5a3063` is a 3-page
  rights-issue-only extract (text similarity 0.833; 2137 contains
  additional board content). Registered via a one-row recovery plan
  (`scripts/spa_bridge/recovery_plan_shanti_2137_2026-11-02.csv`) as
  document `73663d5a-0ad9-4bb1-8084-592e0907c6ac`, title `Board Meeting
  Outcome for For Meeting Held On July 31, 2026
  [404a570b-3891-4835-9165-3b50266e6833]`, content `b011b840…`;
  backend count 1,388 → **1,389**. A scoped verification run now
  reports `ALREADY_REGISTERED_METADATA_CONFLICT` for 2137 and exits 0.
- **Second batch — all remaining 16 resolved (2026-11-02).** 13 distinct
  filings registered via
  `scripts/spa_bridge/recovery_plan_remaining_duplicate_reviews_2026-11-02.csv`:
  AXISCADES 232, 234, 238, 242, 243, 245 (six distinct Jupiter Capital
  SAST events, 19 Jun–8 Jul 2026); Chemplast 353 (Amansa transaction);
  UNO Minda 1261 (Customs anti-dumping order); Quality Power 1601
  (original earnings-call intimation); Dee Development 1749 (full
  17-page board meeting outcome); Ratnaveer 2029 (preferential-issue
  monitoring report); Choice 2467 (Mr. Ashok Kumar Thakur tenure);
  Manipal Health 2620 (47-page promoter non-disposal/encumbrance
  disclosure). 3 duplicates closed: Quality 1626 and Dee 1790 (exact
  same Drive file/SHA as 1601/1749) and Sadhav 2732 (same transcript,
  0.999 text similarity, earlier 14-vs-12 Aug typo; backend holds the
  corrected copy). The scoped 9-ticker bridge recovery run registered
  **13**, with **0 DUPLICATE_REVIEW_REQUIRED** and exit 0 (log:
  `logs/spa_bridge_remaining16_recovery_2026-11-02.log`).
- Current state after the NSE ZIP retry and scoped bridge
  registration: **STORED 3,076 / DUPLICATE_EXACT_BINARY 139 /
  MANUAL_UPLOAD_QUEUED 91 / AWAITING_UPLOAD 0 / DISCOVERED 0**; total
  3,306; backend `document` **1,403**; duplicate-review queue **0**.
- Next automatic runs: Cloud Run **2026-11-03 07:30 IST**; bridge
  **2026-11-03 09:00:30 IST**.

### NSE ZIP attachment fix (2026-11-02)

- `validation.py` now unwraps ZIP attachments: raw PDFs pass through,
  a single PDF is extracted, and multiple PDFs are merged in archive
  order into one PDF; entries/size are capped and ambiguous/corrupt
  archives produce specific failure reasons.
- `production_ingestion.py` unwraps on every acquisition route and
  stores the PDF, not the ZIP; route provenance records
  `archive=zip member=<name>`.
- Deployed as **generation 85**, image
  `sha256:93ef44240dce1fc6fd409044b949cbf8e5889da6ef4754be0fbb07831c5b0f4b`;
  daily args/timeout/retries unchanged.
- **Row 3230 Tempsens — STORED** from
  `CIMG_544886_30102026214248_1.pdf` (sha `cb254b258c511a6e…`).
  **Row 3235 Morepen — DUPLICATE_EXACT_BINARY** of row 3289 (same PDF
  sha `7ae63a39783965b4…`); both queue entries removed.
- The full scheduled bridge task at 11:51 aborted on a transient Drive
  API read timeout before reaching row 3230 (`LastResult` 1). A scoped
  `TEMPSENS` bridge rerun at 12:32 succeeded (exit 0) and registered
  row 3230 as document `bd4e18e2-c6d0-4752-9fe6-814d14a2e41d`; backend
  `document` count 1,402 → **1,403**. The next full scheduled bridge
  run is 2026-11-03 09:00:30 IST.
- The 3235 retry execution originally showed a failed status because the
  pre-existing `retry-queued` mode returned exit 3 for
  `DUPLICATE_EXACT_BINARY`, causing one Cloud Run retry that then saw
  `ROW_NOT_ELIGIBLE`. Data was correct. The exit-code fix
  (`DUPLICATE_EXACT_BINARY` now returns 0 from `retry-queued`) was
  deployed as **generation 86**, image
  `sha256:b6136bc680d7af344ce8e21e8e38ef250fdf95d5aed0c76573b82aa93752919c`;
  19/19 entrypoint tests pass. No row retry was needed.

### Operational reliability issue — Drive metadata timeout (2026-11-02)

- **Evidence:** the full `SPARS_SpaBridgeCatchup` run at 11:51 IST
  aborted at 12:01 with `TimeoutError: The read operation timed out`
  inside `bridge_spa_manifest.py:492` → `file_metadata()` →
  `files().get(...).execute()` → `httplib2`; the task exited 1 before
  reaching row 3230. A scoped `TEMPSENS` rerun registered row 3230
  (`bd4e18e2…`), taking the backend to 1,403; no full rerun was done
  merely to clear `LastResult`.
- **Existing handling:** the bridge sets a 15s socket timeout on its
  Drive/Sheets transports, but its `file_metadata` and
  `ManifestSheetsReader.read_tab` `.execute()` calls use the default
  **0 retries**. Only `HttpError` 404/410 is isolated (documented
  missing Drive file); any other HttpError or TimeoutError propagates
  out of `run()` and aborts the entire 66-ticker batch. Results are
  printed only after `run()` returns, so the aborted run loses its
  per-row summary. Prior writes are durable and the bridge is
  idempotent; this is a batch-availability issue, not data corruption.
- **Proposed minimal correction (not applied; no production changes
  today):**
  1. pass `num_retries=2` (or 3) to the read-only `.execute()` calls in
     `drive_evidence.file_metadata`, `drive_evidence.download_and_hash`
     (canary-only) and `ManifestSheetsReader.read_tab`, reusing
     googleapiclient's own socket-timeout/ConnectionError/5xx retry;
  2. wrap the lazy `build_drive_service()` + `file_metadata()` per-row
     call in `bridge_spa_manifest.run()`; on a final
     TimeoutError/OSError/ConnectionError or transient HttpError,
     append a `DRIVE_METADATA_TIMEOUT` / `DRIVE_METADATA_ERROR` result
     (row, company, Drive file ID), `continue` to the next row, and add
     those outcomes to the failure summary/exit code;
  3. add focused tests for timeout-then-success and
     timeout-then-continue, with no live credentials.
  This is a backend bridge change only; apply/test after tomorrow's
  scheduled verification.
- **Tomorrow's verification unchanged:** Cloud Run daily
  **2026-11-03 07:30 IST**; bridge **2026-11-03 09:00:30 IST**. The
  bridge task's `LastResult` is 1 from the transient timeout; do not
  rerun the full bridge merely to clear it.

### Boundaries

The 2026-11-01 operational work was limited to the authorized task
enable, 66 promotions, 4 stores, 2 queue entries, and 60 duplicate
classifications. On 2026-11-02 the owner explicitly approved the daily
Cloud Run job deployment; the only production change was the existing
job update (generation 84, image `sha256:df19b1ed…`). No scheduler
change, credential/infrastructure change, or schema change. After the
first runs, the owner explicitly approved the two-row resolution (STL
1990 closed as a semantic duplicate; Shanti Gold 2137 registered via a
one-row recovery plan, scoped SHANTIGOLD run) and then the remaining-16
batch (13 registered, 3 duplicates closed; scoped 9-ticker recovery
run). On the same day the owner approved the NSE ZIP fix deployment
(generation 85) and the two-row retry. Logs:
`C:\SPA\cloudrun_fixed_v7_5\acquisition_promote_2026-11-01.log`,
`acquisition_ingest_2026-11-01.log`,
`C:\GitHub\backendtest\logs\spa_bridge_shanti2137_recovery_2026-11-02.log`,
`spa_bridge_shanti2137_verify_2026-11-02.log`,
`spa_bridge_remaining16_recovery_2026-11-02.log`,
`C:\SPA\cloudrun_fixed_v7_5_dev_2026-11-02\release_gate\deployment_zipfix_2026-11-02.log`;
deployment evidence:
`C:\SPA\cloudrun_fixed_v7_5_dev_2026-11-02\release_gate\deployment_retry_debug.log`
and `DEPLOYMENT_RESULT_2026-11-02.md`. The three confirmed distinct
filings, STL 1990, Shanti Gold 2137, and the existing 5 exceptions
were not touched.

## Resume instructions

**2026-11-02 update:** For ingestion work, the current resume point is
the Pipeline operations checkpoint above. The single chained daily
Cloud Run job is deployed (generation 84) and its first run succeeded
on 2026-11-02 07:30 IST; the 09:00:30 bridge registered 20 documents.
STL 1990 is closed as a semantic duplicate; Shanti Gold 2137 is
registered (document `73663d5a…`). The remaining 16 were then resolved
(13 registered, 3 closed), so the duplicate-review queue is **0**. The
two NSE ZIP manual-queue entries are also resolved (3230 STORED and
registered in the backend as `bd4e18e2…`; 3235 exact duplicate); 91
other manual-queue rows remain, and the bridge scope gap (67 of 93; 26
missing) is open. The full bridge task's `LastResult` is 1 from a
transient Drive timeout before row 3230; the scoped TEMPSENS rerun
registered it, and the next full scheduled run is 2026-11-03 09:00:30.
Review the Drive metadata timeout reliability proposal in the
subsection above (and `REVIEW_DRIVE_TIMEOUT_RELIABILITY.md`); do not
rerun the full bridge merely to clear `LastResult`. Do not re-run
discovery for rows 3219–3284. The chaining decision is made (single
daily job). The owner's stated next priorities are the three confirmed
distinct filings, the remaining manual-queue rows, and fixing future M1
filing identification.

Disaster recovery is complete. If resuming on **this PC**: read this
checkpoint, confirm `git status` is clean on all three repo working
directories (it was at closure), and move on to priority (3) --
real-company Investment Brain acceptance, or any new instruction. If
resuming on **another PC** (true disaster recovery): download
`SPA_Disaster_Recovery/DisasterRecovery_20261012_150645/` from Drive,
then follow `DR-01_OFFICE_PC_RESTORE_GUIDE.md` inside it. Decrypt
credentials with the passphrase the owner holds (
`C:\SPA\DR_Secrets_DO_NOT_COMMIT\spa_credentials_passphrase_20261012.txt`
on this PC -- **move this into a password manager**, it is not
itself a permanent secure store).

**Outstanding, owner-level only:**
- Deciding on I3AS's next scope, if any -- the design proposal's named
  slices (Alert-1/2/3) are now all complete; nothing further is named
  in it.
- Wealth Desk final UI/UX direction -- the owner has indicated they
  will finalize the UI directly per their own requirements; the
  provisional UI above is explicitly "provisional," not final design.
- Whether/when to scope a future "automated extraction + human
  approval for consequential judgments" milestone -- see the
  architecture clarification above. Not scoped yet; a direction
  marker only.
- Saving the credentials passphrase into a password manager and
  deleting the plaintext file -- the one remaining loose end from
  the backup itself.
- The Research Orchestrator remains unbuilt and unauthorized, unchanged
  from every prior checkpoint.
