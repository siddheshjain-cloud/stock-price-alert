# Phase 3 Development Checkpoint

**Live, update-in-place record of Phase 3 engineering progress.** Read this
first when resuming Phase 3 work in a new session. Update it in place at
each shutdown checkpoint rather than creating a new dated file -- the
`Last updated` line and the slice ledger are the source of truth for
"what is actually committed," independent of any single conversation's
memory.

**Last updated:** 2026-10-12 (shutdown checkpoint after I3AS Slice 1 --
Phase 3 A-G remain complete and now merged; I3AS Slice 1, the legacy
Trade/Telegram alert integration, is also complete, including a
same-day live-database incident, full recovery, and a root-cause
safeguard -- see "I3AS Slice 1" section below)

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
  `feature/research-coverage-foundation`): open, carries I3AS Slice 1
  (see below), stacked on the same base PR #1 used, for the same
  reason -- `feature/research-coverage-foundation` -> `master` is still
  intentionally unmerged.
- `feature/research-coverage-foundation` -> `master` **remains
  unmerged, with no PR of its own** -- explicitly not done, pending
  separate owner approval, unchanged from every prior checkpoint.
- `gh` CLI authenticated this session via owner browser action (device
  flow); portable zip install used after the MSI installer hung on a
  UAC prompt it could not get non-interactively -- killed, no admin
  rights used or required.

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

## Resume instructions for the next session

**Phase 3 (Slices A-G) and I3AS Slice 1 are both complete and merged/
PR'd.** There is no pending implementation work to resume from either.
If a future session is asked to "continue Phase 3" or "continue I3AS,"
read this checkpoint first and confirm there is genuinely new scope
before writing any code.

**Outstanding, owner-level only:**
- Merging PR #2 into `feature/research-coverage-foundation`.
- Merging `feature/research-coverage-foundation` into `master` (no PR
  yet, unchanged standing position).
- Deciding whether to proceed to I3AS Alert-2 (Investment Brain
  integration: kill switch, gate `FAIL`, `InvestmentCase` view-changing
  supersession) -- the design proposal's §8 sequencing, not yet
  started.
- The Research Orchestrator remains unbuilt and unauthorized, unchanged
  from every prior checkpoint.
