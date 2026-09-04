# Investment Operating System Milestone 1 — Implementation Plan Index

**Approved specification:** `docs/superpowers/specs/2026-09-04-investment-operating-system-milestone-1-design.md`

**Implementation repository:** sibling repository `backendtest`

**Planning repository:** `stock-price-alert` (documentation only; no frontend application change)

## Implementation order

1. [Foundation, Test Harness, and Migration Baseline](2026-09-04-investment-operating-system-m1-foundation-test-migration.md) — 6 tasks
2. [Core Research Domain](2026-09-04-investment-operating-system-m1-core-research-domain.md) — 9 tasks
3. [Entitlement, Query, and Response Projection](2026-09-04-investment-operating-system-m1-entitlement-query-projection.md) — 6 tasks
4. [Document Library, Rights, and Deduplication](2026-09-04-investment-operating-system-m1-document-library-rights-deduplication.md) — 8 tasks
5. [API Integration, IKIO Seed, and Regression Completion](2026-09-04-investment-operating-system-m1-api-seed-regression.md) — 8 tasks

Total: 37 focused TDD tasks.

## Plan purposes, dependencies, and completion gates

| Order | Plan | Purpose | Depends on | Completion gate |
|---|---|---|---|---|
| 1 | `2026-09-04-investment-operating-system-m1-foundation-test-migration.md` | Install an isolated pytest harness, characterize legacy auth/ticker/trade/Tag/Telegram/Kite/websocket behavior, add read-only schema inventory, commit the legacy Alembic baseline, and prove fresh/stamped baseline paths. | Frozen specification and current backend repository. | Foundation tests and legacy contracts pass; baseline creates only legacy tables; no active database was contacted. |
| 2 | `2026-09-04-investment-operating-system-m1-core-research-domain.md` | Add Company/BusinessGroup, one-row entitlements, immutable research/market/forecast/valuation streams, ownership, governance, disclosures, EPS, and valuation reference lines. | Plan 1 repository gate. | All domain tests and legacy regressions pass; legacy tables are structurally unchanged; revision transactions and concurrency rules pass. |
| 3 | `2026-09-04-investment-operating-system-m1-entitlement-query-projection.md` | Resolve database-backed tier, build explicit projections, read CMP safely, and query current/history/disclosures without premium leakage. | Plans 1–2. | Free/premium/admin matrix passes; stale JWT tier is irrelevant; Ticker remains read-only; no live import coupling exists. |
| 4 | `2026-09-04-investment-operating-system-m1-document-library-rights-deduplication.md` | Add common Document/Institution models, finalize the disclosure Document FK, enforce rights, fingerprint/deduplicate, and implement atomic create/link/update/query services and audit history. | Plans 1–3. | Rights and deduplication suites pass; no private data/count/storage key leaks; aggregate and audit transactions roll back completely on conflict. |
| 5 | `2026-09-04-investment-operating-system-m1-api-seed-regression.md` | Create the additive migration, wire administrative/consumer APIs, add the source-backed IKIO seed, and run full security, migration, and legacy regression gates. | Plans 1–4 and the signed deployment baseline gate for its migration task. | Full pytest run passes; fresh and existing-schema-copy upgrades pass; only new tables are added; no out-of-scope endpoint/model or legacy change exists. |

## Dependency rationale

The approved direction remains the safest repository-backed order:

```text
Foundation / Test / Migration Safety
                 ↓
        Core Research Domain
                 ↓
 Entitlement / Query / Projection
                 ↓
 Document Library / Rights / Deduplication
                 ↓
       API / Seed / Full Regression
```

Security is not deferred to the final plan: entitlement leakage tests are created in Plan 3 before consumer routes, and document-rights leakage tests are created in Plan 4 before document services or routes. API work begins only after its domain, policy, query, and command contracts exist.

One schema dependency crosses the plan boundary: `CompanyDisclosure.document_id` targets `document.id`, but the Document aggregate belongs to Plan 4. Plan 2 uses a nullable, non-writable string column solely so its isolated model tests can run before the `document` table exists. Plan 4 Task 1 replaces that mapping with the required foreign key before revision `20260904_02` is generated. No deployment migration is created in the intermediate state.

## Human and deployment checkpoints

### Repository-safe work

The following may run locally or in CI against temporary databases:

- dependency installation from `requirements-dev.txt`;
- pytest characterization and TDD cycles;
- read-only schema inventory against disposable test databases;
- creation and testing of Alembic revision `20260904_01` on empty temporary databases;
- construction of a model-equivalent existing-schema copy followed by a stamp rehearsal;
- domain, policy, service, route, seed, and migration tests against temporary databases.

### Active-database gate

Before generating the additive revision from an active database, stamping an existing database, or upgrading it, a deployment operator must complete all of these for every active environment:

1. identify database URL owner, dialect, driver, hosting platform, and environment;
2. create a platform-approved backup and verify its restore procedure;
3. inspect `alembic_version` and any external migration history;
4. create a redacted schema inventory with the Plan 1 read-only utility;
5. compare tables, columns, types, defaults, nullability, indexes, unique constraints, foreign keys, and enum representation with current SQLAlchemy models;
6. record every drift item and its approved disposition;
7. obtain named review approval with timestamp and `BASELINE_EQUIVALENT=true`.

If the active database already has Alembic history, differs from the verified legacy schema, lacks a recoverable backup, or has unresolved drift, no stamp or upgrade command runs. The deployment operator records the evidence and obtains a reviewed reconciliation path.

### Upgrade paths after approval

- Empty database: apply `20260904_01`, then `20260904_02` through `flask --app main:app db upgrade 20260904_02`.
- Verified existing legacy database with no migration history: stamp `20260904_01`, verify `flask --app main:app db current`, then upgrade to `20260904_02`.
- Existing database with migration history or schema drift: stop and design a reviewed environment-specific reconciliation; do not stamp over it.

## Specification coverage map

| Specification area | Concrete implementation tasks |
|---|---|
| Existing-system boundaries and application factory | Plan 1 Tasks 1–3; Plan 5 Tasks 2 and 8 |
| Company and BusinessGroup | Plan 2 Task 2; Plan 5 Task 3 |
| UserEntitlement uniqueness and updates | Plan 2 Task 3; Plan 3 Task 1; Plan 5 Task 3 |
| ResearchRevision, ResearchPoint, management, and thesis invalidation | Plan 2 Task 4; Plan 5 Task 4 |
| Ownership snapshots | Plan 2 Task 5; Plan 5 Task 3 |
| Governance flags | Plan 2 Task 6; Plan 5 Task 3 |
| CompanyDisclosure and manual `is_key` | Plan 2 Task 6; Plan 3 Task 5; Plan 5 Tasks 3 and 5 |
| MarketPlanRevision and price invalidation | Plan 2 Task 7; Plan 5 Task 4 |
| ForecastRevision, ForecastLine, and administrator EPS | Plan 2 Task 8; Plan 5 Task 4 |
| ValuationRevision, bridge snapshots, methods, and ValuationReferenceLine | Plan 2 Task 9; Plan 5 Task 4 |
| Document, links, institutions, institutional metadata, and audit events | Plan 4 Tasks 1, 5–7; Plan 5 Task 6 |
| Source/acquisition/distribution/ingestion validation | Plan 4 Task 2; Plan 5 Task 6 |
| Generic fingerprint and SHA-256 deduplication | Plan 4 Tasks 3, 5, and 6 |
| Document and derived-content rights inheritance | Plan 4 Tasks 4 and 8; Plan 5 Task 6 |
| Free/premium/admin projection, null/omission, and locked sections | Plan 3 Tasks 1, 2, and 6; Plan 5 Task 5 |
| Market CMP read-only boundary | Plan 3 Task 3; Plan 5 Tasks 5 and 8 |
| Company/current/history/disclosure queries | Plan 3 Tasks 4 and 5; Plan 5 Task 5 |
| Consumer and administrative API contracts | Plan 5 Tasks 2–6 |
| Validation and stable error behavior | Plan 2 Task 1; Plan 4 Task 2; Plan 5 Task 2 |
| Baseline, active-database gate, additive migration, and both upgrade paths | Plan 1 Tasks 4–6; Plan 5 Task 1 and deployment-only procedure |
| IKIO source-backed idempotent seed | Plan 5 Task 7 |
| Security/leakage invariants | Plan 3 Tasks 2 and 6; Plan 4 Tasks 4 and 8; Plan 5 Tasks 5, 6, and 8 |
| Explicitly out-of-scope enforcement and legacy non-interference | Every plan's Global Constraints; Plan 1 Tasks 2–3; Plan 5 Task 8 |

## Global release conditions

- The approved specification file is unchanged during implementation planning and execution unless a separately approved design change is requested.
- No frontend application file is part of Milestone 1.
- No migration alters a legacy table.
- Research code does not enter Kite, websocket, ticker update, trade evaluation, alert, Telegram, or authentication paths.
- Free users receive no premium values; stale JWT tier claims have no authority.
- Premium/admin research access does not grant document redistribution rights.
- Restricted/private documents and derived values cannot leak through fields, snippets, hashes, counts, ranges, aggregates, or existence-sensitive errors.
- `storage_key` is never exposed.
- No file ingestion, PDF processing, automated discovery, institutional analysis/consensus, forecast/valuation engine, SOTP component model, billing, or frontend research feature is implemented.
