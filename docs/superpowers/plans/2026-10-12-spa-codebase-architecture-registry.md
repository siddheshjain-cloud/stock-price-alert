# SPA Codebase & Architecture Registry

**The primary navigation reference for SPA development.** Read this
*before* starting any new task. It is a structured index with
pointers, not a specification — follow its paths into the real code
rather than trusting field-level detail here to stay current forever.

## How to use this registry (binding on future sessions)

1. Consult this registry before beginning a new task.
2. Inspect only the code relevant to the task and whatever has changed
   since the "Verified baseline" commits below (`git log <sha>..HEAD`
   on the relevant repo).
3. Update the affected section(s) whenever architecture, APIs, schemas,
   or a major feature's status changes — update in place, don't append
   a new dated copy.
4. Perform a full re-inventory only when this registry is missing,
   materially stale, or inconsistent with the actual code.
5. **Actual code is authoritative whenever this document and the code
   disagree.** Trust `git log`/the file tree over any claim here that
   looks stale.

---

## Verified baseline (2026-10-12, overnight session)

| Repo | Path | Branch | Verified commit |
|---|---|---|---|
| Backend (`backendtest`) | `C:\github\backendtest` | `feature/research-coverage-foundation` (working branch; `master` is the integration target, not yet merged to) | `061b3b3` (working branch, PR #10); `master` at `f8da0f4` (PR #7) |
| Design docs (`stock-price-alert`, docs-only clone) | `C:\GitHub\stock-price-alert` | `feature/investment-operating-system-m1` | `90b8c1f` |
| Frontend (`stock-price-alert`, Next.js app) | `C:\Users\Home\Documents\GitHub\stock-price-alert` | `feature/wealth-desk-ui` (checked out); `feature/investment-operating-system-m1` re-synced to `90b8c1f` in the same pass | `e8d6868` (`feature/wealth-desk-ui`), `90b8c1f` (`feature/investment-operating-system-m1`) -- both current as of this backup, same remote/branch history as the docs clone (two local checkouts of one repo, not two repos; see "Repository map" below) |

---

## Repository map

- **`backendtest`** (`siddheshjain-cloud/backendtest`, fork of
  `sohamsjain/backendtest`? — unconfirmed upstream, not load-bearing):
  the Flask backend. All application code, tests, migrations.
- **`stock-price-alert`** (`siddheshjain-cloud/stock-price-alert`, fork
  of `sohamsjain/stock-price-alert`): **one GitHub repo, two local
  clones** —
  - `C:\GitHub\stock-price-alert` — used throughout this engagement for
    `docs/superpowers/` planning documents only.
  - `C:\Users\Home\Documents\GitHub\stock-price-alert` — the actual
    Next.js frontend app (`app/`, `components/`, `lib/`) **plus** a
    large, separate `dev-tools/` tree (a historical SPA-M1 orchestration/
    AutoDebug automation harness used earlier in this engagement) and
    the same `docs/superpowers/` tree. **Not independently audited in
    this pass** — out of scope for current Wealth Desk/I3AS work; note
    its existence if a future task ever touches orchestration tooling.
  - Both clones share one remote and branch; a commit pushed from
    either is visible in the other after `git fetch`/`pull`. Do not
    assume they are interchangeable working directories for different
    purposes — they are the same history, checked out twice.

---

## Backend module index (`backendtest`)

**29 models** (`app/models/`) — grouped by capability:
- *Legacy/M1 core:* `user`, `ticker`, `trade`, `tag`, `company`,
  `document`, `disclosure`, `governance`, `ownership`, `market_plan`,
  `institution`, `institutional_report`, `entitlement`,
  `telegram_verification`, `research` (ResearchRevision/ResearchPoint),
  `research_types` (shared enums).
- *Research Brain (pre-Phase-3):* `research_brain`
  (Evidence/ExtractedFact), `research_coverage` (CandidateFinding/
  FactDerivation/ResearchProposition).
- *Phase 3 (Investment Intelligence Foundation, Slices A-G):*
  `financial_metric_definition`, `cycle_intelligence`,
  `investment_hypothesis`, `forecast`, `forecast_revision_assumption`,
  `valuation`, `investment_case`.
- *I3AS (Alert System):* `alert`, `alert_types`.

**21 services** (`app/services/`) — one service owns writes to its own
model(s) only (P3-A ownership-boundary convention, held throughout):
`research_brain_service`, `research_coverage_service`,
`research_command_service` (legacy M1 commands + Phase 3 A's
`scenario`-aware forecast/valuation write paths + Alert-3's
`GovernanceFlag` hook), `research_query_service`, `research_presenter`,
`entitlement_service`, `document_library_service`,
`document_validation_service`, `document_deduplication_service`,
`telegram_service`, `market_price_service`, `fiscal_period`,
`financial_diagnostics_service`, `financial_narration_service`,
`cycle_intelligence_service`, `hypothesis_assumption_service`,
`forecast_engine_service`, `valuation_engine_service`,
`investment_case_service`, `alert_service`, `research_seed_service`.

**10 route blueprints** (`app/routes/`): `auth`, `users`, `trades`,
`tickers`, `tags`, `telegram` (always registered); `research`,
`documents`, `admin_research`, `admin_documents` (registered only when
`create_app(register_research=True)` — see `app/__init__.py`'s own
docstring for exactly why `live/websocket.py` deliberately omits this).
**No route blueprint exists yet for Phase 3 or I3AS** — see "Known
gaps" below.

**Auth/entitlement pattern** (`app/utils/auth.py`,
`app/services/entitlement_service.py`,
`app/policies/research_access.py`): `admin_required` (JWT + `is_admin`)
for writes; `consumer_required` (JWT only) + `EntitlementService.
resolve(user)` → `ResearchAccessContext(user_id, is_admin, tier)` for
tiered reads. `ResearchAccessPolicy.FREE_SECTIONS`/`PREMIUM_SECTIONS`
are named, explicit constants; `ResearchPresenter` picks one of three
explicit marshmallow schemas (Admin/Premium/Free) per request — never
a single schema with conditionally-hidden fields. Extend this pattern
for any new tiered section; do not invent a second access-control
mechanism.

## Database

- **14 migrations** (`migrations/versions/`), head: `20261012_01`
  (I3AS Slice 1's `alert_event`/`alert_delivery`). Alert-2/Alert-3
  added no migrations (new enum string values + new service wiring
  only, no schema change).
- **Live database** (`instance/trading_app.db`): **`20261007_05`** —
  five migrations behind head. Never migrated during Phase 3/I3AS work;
  every migration is tested only against isolated SQLite copies (see
  Phase 3 Development Checkpoint's "Incident-to-Safeguard Doctrine" for
  why this is a hard rule, not a preference). 45 tables at this
  revision; two real companies exist (Chemplast Sanmar, UNO Minda) with
  real linked documents — see the Checkpoint's "real-company
  validation" entries for exact row counts and what real data exists
  for each.
- `create_app()` fails closed against the live database unless
  explicitly opted into (`allow_default_database=True`) or a non-default
  `DATABASE_URL` is set — see `app/__init__.py`'s
  `_require_explicit_database_opt_in`. This is the root-cause fix for
  the 2026-10-12 incident; do not bypass it in ad-hoc scripts.

## Frontend index (`stock-price-alert` Next.js app)

- **Pages** (`app/`): `/` (redirect only), `/auth/signin`,
  `/auth/signup`, `/alerts` (renders `TradesPage` — "Alerts" in this
  product is the Trade feature, not I3AS), `/settings` (Telegram
  connection only).
- **Design system already installed, mostly unused:** shadcn/ui
  (Radix) — `card`, `table`, `tabs`, `dialog`, `drawer`, `sheet`,
  `chart` (recharts), `badge`, `command`, `dropdown-menu`,
  `breadcrumb`, `select`, `tooltip`, `skeleton`, `sonner`
  (`components/ui/`). The sidebar (`components/layout/app-sidebar.tsx`)
  has four dead nav placeholders (`url: "#"`): Dashboard, Analytics,
  Notifications, Friends.
- **API clients** (`lib/api/`): `auth.ts`, `telegram.ts`, `tickers.ts`,
  `trades.ts` — **only four files.** No client exists for the
  `research` blueprint (built backend-only in an earlier phase) or for
  anything Phase 3/I3AS. See the Wealth Desk Architecture Proposal
  (`2026-10-12-wealth-desk-architecture-proposal.md`) for the full
  implication of this.

## API contract status (frontend ↔ backend)

| Backend capability | Route exists | Frontend client exists | Notes |
|---|---|---|---|
| Auth | Yes (`auth_bp`) | Yes (`auth.ts`) | Wired |
| Trades/Tickers/Tags | Yes | Yes (`trades.ts`, `tickers.ts`) | Wired |
| Telegram | Yes | Yes (`telegram.ts`) | Wired |
| Research consumer (`research_bp`) | Yes | **No** | Built, never consumed |
| Admin research writes | Yes | N/A (admin tooling, no UI planned) | — |
| Phase 3 (Investment Brain) | **No route at all** | No | Service-layer only; read API is the overnight backend-work item, see Checkpoint |
| I3AS (Alerts) | **No route at all** | No | Same as above |

## Feature status ledger

See the Phase 3 Development Checkpoint
(`2026-10-08-phase3-development-checkpoint.md`) for the authoritative,
continuously-updated slice-by-slice ledger (Phase 3 A-G, I3AS
Alert-1/2/3, PR/merge state, regression results). This registry does
not duplicate it — consult it directly for "what is actually shipped
and tested" at any point in time.

## Known gaps (as of this baseline)

- `investment_case` is now readable via the existing `research_bp`
  company-detail endpoint (premium/admin only), and the admin-only
  I3AS alert feed is now readable via `GET /api/admin/alerts`
  (`admin_alerts_bp`, PR #9) -- the "no HTTP route for any Phase
  3/I3AS object" gap recorded at the first baseline no longer applies
  to either of these two objects. No other Phase 3/I3AS object has a
  route yet.
- No portfolio/holdings data model (`Holding`/`Transaction`) exists —
  Master Roadmap V2 Tier 0.3, never built. Any "portfolio" UI language
  should say "Watchlist"/"Coverage" until this changes.
- The Research Orchestrator (Phase 3 design proposal §6) remains
  unbuilt and unauthorized under any circumstance without separate
  approval — unchanged standing position.
- `GovernanceFlag`'s "status -> OPEN transition" alert nuance (design
  proposal, I3AS Alert-3) was deliberately not built — only
  creation-time severity is alert-worthy today.
- `dev-tools/` (frontend repo) is unaudited — see "Repository map."
- **RESOLVED 2026-10-12:** Continuous Monitoring V1's real Google
  Sheets/Drive connectivity. Root cause was two bugs, not an
  environment limitation: no transport timeout configured anywhere
  (an occasional bad anycast IP pick hung forever), and a per-row
  Drive-client rebuild cost masked by that hang. Both fixed (PR #10,
  `061b3b3`); verified with two real, idempotent scans against an
  isolated DB copy (258 real rows each, 0 errors). Still true:
  verifies manifest *ingestion* only, not SPA's upstream *discovery*
  coverage — two separate systems.
- **Real-company Investment Brain acceptance is inventoried but not
  built.** UNO Minda is the only one of the three pilot companies
  (Chemplast Sanmar, UNO Minda, AXISCADES) with a genuine evidence base
  (23 `ExtractedFact` rows + 1 `ResearchProposition`) a source-backed
  `ResearchRevision`/`InvestmentHypothesis`/`InvestmentCase` could cite
  without fabrication. None has been built yet — still queued as the
  owner's priority (3), next in line.
- **Disaster recovery backup exists in exactly one place.** A full,
  verified, encrypted backup was created 2026-10-12 at
  `C:\SPA\DisasterRecovery_20261012_150645\` -- but the owner's
  designated off-machine copy (Google Drive) is blocked: the only
  Drive credential on this machine is read-only (confirmed via a
  real write attempt, a genuine 403). The backup has not left this
  PC's local disk. See the Phase 3 Development Checkpoint's
  "Repository Housekeeping & Disaster Recovery Backup" section for
  full detail.

## Maintenance log

- **2026-10-12 (disaster recovery VERIFIED):** Owner completed the
  Drive OAuth consent themselves; the resulting write-capable token
  was verified with a real write-then-delete test before trusting
  it. Uploaded the full backup (17 files) to Google Drive under
  `SPA_Disaster_Recovery/DisasterRecovery_20261012_150645/`, with
  every file's MD5 checked against Drive's own reported MD5 after
  upload -- zero mismatches. Status upgraded from PARTIAL to
  VERIFIED; all three legs (local backup, encrypted credentials,
  off-machine copy) independently confirmed.
- **2026-10-12 (final disaster recovery completion, same day,
  earlier pass):** Re-encrypted the credentials archive with a new,
  never-printed passphrase (the original had been exposed in chat);
  old archive deleted. DR-01 office-PC restore guide finalized.
- **2026-10-12 (overnight):** Full inventory performed. Baseline
  commits recorded above.
- **2026-10-12 (stop-and-save checkpoint):** Baseline SHAs bumped
  (backend `master` PR #7 `f8da0f4`, working branch PR #8 `f711d3d`;
  docs `59cae82`) after the Wealth Desk `investment_case` read API,
  I3AS Alert-3, and Continuous Monitoring V1 all merged into
  `feature/research-coverage-foundation`. Frontend clone flagged stale
  (not re-synced this session). See the Phase 3 Development Checkpoint
  for full narrative detail — this registry only tracks structure/
  baseline/gaps, per its own maintenance rules.
- **2026-10-12 (housekeeping & disaster recovery backup):** Baseline
  SHAs bumped again -- backend working branch now `061b3b3` (PR #10,
  Sheets/Drive connectivity fix), `master` unchanged at `f8da0f4`;
  docs clone `90b8c1f`; frontend clone's `feature/wealth-desk-ui` at
  `e8d6868` (its `feature/investment-operating-system-m1` ref
  re-synced to `90b8c1f` during this pass). Owner-approved selective
  cleanup executed (`.next`, backend `__pycache__`, 3 disposable
  session test-DB copies, 5 regression logs deleted; nothing else
  touched -- see checkpoint for the full authorized/not-authorized
  list). Full encrypted disaster-recovery backup created and
  restore-rehearsed; off-machine copy blocked (read-only Drive
  credential only) -- status PARTIAL, not VERIFIED, per owner
  instruction.
