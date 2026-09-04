# Investment Operating System Milestone 1 — API Integration, IKIO Seed, and Regression Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Feature:** Investment Operating System Milestone 1 — API Integration, IKIO Seed, and Regression Completion

**Goal:** Expose the approved research/document contracts, create the additive Milestone 1 migration and sourced IKIO seed, and prove complete legacy, security, rights, and migration non-interference.

**Architecture:** Register separate consumer and administrative blueprints in the existing Flask application factory. Routes authenticate, validate through dedicated Marshmallow schemas, invoke already-tested services, and serialize explicit projections; they never own domain calculations or bypass policies. The additive migration is created only after all model metadata exists and after the Foundation deployment gate authorizes it; automated migration tests use temporary database copies only.

**Tech Stack:** Python 3.12, Flask 2.3.3 blueprints, Flask-JWT-Extended 4.5.3, Flask-SQLAlchemy 3.0.5, Marshmallow 3.20.1, Flask-Migrate 4.0.5/Alembic 1.16.x, pytest 8.3.5.

**Spec:** `../stock-price-alert/docs/superpowers/specs/2026-09-04-investment-operating-system-milestone-1-design.md`

## Global Constraints

- Depends on all tasks in Plans 1–4. Plan 5 Task 1 requires the signed human/deployment baseline gate from Plan 1 only before an active-database migration operation; repository-safe generation and testing use disposable databases.
- Run implementation and tests from `backendtest`; add no frontend application files.
- Preserve every existing legacy endpoint path, status code, response key, JWT identity rule, model column, websocket subscription, ticker update, trade evaluation, Kite credential, and Telegram notification behavior.
- Use the existing `@jwt_required()` and `@admin_required` mechanisms; tier comes from `EntitlementService`, not JWT claims.
- Routes call service interfaces exactly as defined in earlier plans; services own transactions and rollback.
- Never expose `storage_key`, restricted hashes/private references, premium values to free users, or restricted values/counts/aggregates to unauthorized users.
- Rights-sensitive inaccessible documents return 404; premium entitlement and administrator research access never override distribution rights.
- Do not add file transfer, PDF processing, automated discovery, institutional analysis/consensus, valuation/forecast engines, SOTP components, billing, Elasticsearch research indexing, or frontend behavior.
- Do not run migration commands against an active database while executing automated tasks in this plan.

---

## Task 1: Additive Milestone 1 migration and two-path migration tests

**Files:**
- Create: `migrations/versions/20260904_02_investment_operating_system_m1.py`
- Create: `tests/migrations/test_milestone1_fresh_upgrade.py`
- Create: `tests/migrations/test_milestone1_existing_schema_upgrade.py`
- Modify: `tests/migrations/helpers.py`
- Tests: the two files above plus legacy immutability tests

**Interfaces:**
- Consumes: signed `BASELINE_EQUIVALENT=true` deployment gate, baseline revision `20260904_01`, and complete Plan 2/4 SQLAlchemy metadata.
- Produces: additive Alembic revision `20260904_02` and tested empty-database and existing-schema-copy upgrade paths.

- [ ] **Step 1: Verify the human gate before any active-database migration operation**

  Read `docs/deployment/investment-operating-system-m1-database-gate.md` and inspect the controlled deployment record named by that runbook for each active environment. Confirm each record contains dialect/driver, backup and restore verification, Alembic state, redacted schema inventory, model comparison, resolved drift, reviewer/time, and `BASELINE_EQUIVALENT=true`. This signed gate is mandatory before generating from an active database, stamping an active database, or upgrading an active database. If any item is absent or any drift is unresolved, do not perform any of those active-database operations; Plans 2–4 remain valid. Repository-safe generation, review, and testing of revision `20260904_02` against a disposable temporary database remain allowed and must not contact an active database.

- [ ] **Step 2: Write failing migration-path tests**

  Fresh path: empty temporary SQLite → upgrade `head` → assert legacy plus all Milestone 1 tables/constraints/indexes. Existing path: create exact legacy schema copy → stamp `20260904_01` → snapshot legacy tables → upgrade `head` → assert snapshot equality and new tables. Both tests assert there is one `(user_id, product_code)` entitlement row, nullable forecast EPS, valuation method stream uniqueness, valuation reference-line ordering, document fingerprint non-null/unique, document link uniqueness, institution uniqueness, and document audit relationships.

  Expected new table set is exactly: `business_group`, `company`, `user_entitlement`, `research_revision`, `research_point`, `ownership_snapshot`, `governance_flag`, `company_disclosure`, `market_plan_revision`, `forecast_revision`, `forecast_line`, `valuation_revision`, `valuation_reference_line`, `institution`, `document`, `document_company_link`, `institutional_report_metadata`, and `document_audit_event`.

- [ ] **Step 3: Run tests to verify the additive revision is missing**

  Run: `python -m pytest tests/migrations/test_milestone1_fresh_upgrade.py tests/migrations/test_milestone1_existing_schema_upgrade.py -q`

  Expected: FAIL because revision `20260904_02` does not exist.

- [ ] **Step 4: Generate, constrain, and verify the additive revision**

  In PowerShell, create a disposable baseline database for autogeneration rather than pointing Alembic at an active database:

  ```powershell
  $iosM1MigrationDb = Join-Path ([System.IO.Path]::GetTempPath()) ("ios-m1-autogenerate-{0}.db" -f [guid]::NewGuid())
  $env:DATABASE_URL = "sqlite:///$($iosM1MigrationDb.Replace('\', '/'))"
  flask --app main:app db upgrade 20260904_01
  ```

  Run: `flask --app main:app db revision --autogenerate --rev-id 20260904_02 -m "investment operating system milestone 1"`

  Review the generated operations line by line. `upgrade()` creates only the exact new-table set above in FK-safe order; `downgrade()` drops only those tables in reverse order. Remove every operation that alters, recreates, renames, indexes, or changes a column on a legacy table. Keep new foreign keys that point from new tables to `user.id` and `ticker.id`; add no reverse legacy columns. Include dialect-portable constraints plus supported filtered-primary index behavior.

  Run: `python -m pytest tests/migrations/test_milestone1_fresh_upgrade.py tests/migrations/test_milestone1_existing_schema_upgrade.py tests/migrations/test_legacy_schema_immutability.py -q`

  Expected: all tests pass; both upgrade paths reach `20260904_02` and legacy snapshots are identical.

- [ ] **Step 5: Commit the additive migration**

  ```bash
  git add migrations/versions/20260904_02_investment_operating_system_m1.py tests/migrations/helpers.py tests/migrations/test_milestone1_fresh_upgrade.py tests/migrations/test_milestone1_existing_schema_upgrade.py
  git commit -m "build: add Investment Operating System migration"
  ```

## Task 2: Research error mapping and blueprint registration

**Files:**
- Create: `app/routes/research.py`
- Create: `app/routes/admin_research.py`
- Create: `app/routes/documents.py`
- Create: `app/routes/admin_documents.py`
- Create: `tests/api/test_research_blueprints.py`
- Modify: `app/__init__.py`
- Modify: `app/utils/error_handlers.py`
- Modify: `app/utils/research_errors.py`
- Tests: `tests/api/test_research_blueprints.py`

**Interfaces:**
- Consumes: `ResearchValidationError`, `ResearchConflictError`, `ResearchNotFoundError`, and `ResearchForbiddenError`.
- Produces: blueprints `research_bp`, `admin_research_bp`, `admin_entitlements_bp`, `documents_bp`, and `admin_documents_bp`; stable error payload `{"error": code, "message": message, "details": details}`; and `research_error_boundary(view: Callable) -> Callable`, applied inside `@admin_required` so the legacy decorator cannot convert downstream domain errors into token errors.

- [ ] **Step 1: Write failing registration and error tests**

  Assert `app.blueprints` contains all five new blueprint names registered with prefixes `/api/research`, `/api/admin/research`, and `/api/admin/users`. Use a test-only Blueprint to raise each typed error and assert 400/403/404/409 stable codes; wrap a test-only admin view as `@admin_required` above `@research_error_boundary` and prove domain conflicts remain 409 while invalid/non-admin tokens retain existing 401/403 responses. Assert generic 500 hides exception text and rolls back. Re-run representative legacy error cases unchanged.

- [ ] **Step 2: Run tests to verify blueprints are absent**

  Run: `python -m pytest tests/api/test_research_blueprints.py -q`

  Expected: FAIL because the blueprints are not registered.

- [ ] **Step 3: Add route modules, registration, and isolated research error mapping**

  Define each Blueprint at module scope and register it in `create_app` with the exact prefixes. Extend `register_error_handlers` with typed handlers before the generic handlers. Implement `research_error_boundary` to catch typed domain errors and unexpected errors, call `db.session.rollback()`, and return the same stable research payload; all administrative research routes apply decorators in the order `@admin_required` then `@research_error_boundary`. Do not modify `admin_required` or existing handler payloads for Marshmallow, IntegrityError, Werkzeug, or legacy routes.

- [ ] **Step 4: Run registration and legacy API tests**

  Run: `python -m pytest tests/api/test_research_blueprints.py tests/legacy -q`

  Expected: all tests pass and legacy URL rules/payloads are unchanged.

- [ ] **Step 5: Commit integration scaffolding**

  ```bash
  git add app/routes/research.py app/routes/admin_research.py app/routes/documents.py app/routes/admin_documents.py app/__init__.py app/utils/error_handlers.py app/utils/research_errors.py tests/api/test_research_blueprints.py
  git commit -m "feat: register research API boundaries"
  ```

## Task 3: Administrative company, entitlement, fact, and institution APIs

**Files:**
- Create: `app/schemas/admin_research.py`
- Create: `tests/api/test_admin_research_facts.py`
- Modify: `app/routes/admin_research.py`
- Modify: `app/routes/admin_documents.py`
- Modify: `app/services/research_command_service.py`
- Tests: `tests/api/test_admin_research_facts.py`

**Interfaces:**
- Consumes: model/command interfaces from Plan 2, `DocumentLibraryService` institution commands from Plan 4, existing `@admin_required`, `@research_error_boundary`, and Marshmallow unknown-field rejection.
- Produces: company create/patch; ownership create; governance create/patch; disclosure create/patch; institution create/patch; and `PUT /api/admin/users/<user_id>/entitlements/investment-research` backed by `ResearchCommandService.upsert_entitlement(user_id: str, payload: dict, actor_user_id: str) -> UserEntitlement`.

- [ ] **Step 1: Write failing administrative fact API tests**

  Cover every endpoint from specification section 9.2 in this task, admin/non-admin/JWT behavior, unknown fields, validation details, 404s, unique conflicts, in-place entitlement updates, missing-row creation, `is_key` default/manual changes, governance archival, institution normalization, decimal-string responses, and absence of sensitive or legacy-field changes.

- [ ] **Step 2: Run tests to verify routes/schemas are missing**

  Run: `python -m pytest tests/api/test_admin_research_facts.py -q`

  Expected: FAIL with 404 or missing schema/service methods.

- [ ] **Step 3: Implement strict schemas and thin routes**

  Define separate create/patch schemas with `unknown=RAISE`; server derives IDs, actor IDs, timestamps, and entitlement product code. Each route applies `@admin_required` above `@research_error_boundary`, obtains the JWT user through existing helpers, loads JSON, invokes one service method, and serializes an explicit administrative response. `upsert_entitlement` updates the unique row rather than appending history.

- [ ] **Step 4: Run administrative and entitlement tests**

  Run: `python -m pytest tests/api/test_admin_research_facts.py tests/research/test_entitlement_service.py tests/research/test_governance_and_disclosures.py -q`

  Expected: all tests pass; changed entitlements affect subsequent requests without new JWTs.

- [ ] **Step 5: Commit administrative fact APIs**

  ```bash
  git add app/schemas/admin_research.py app/routes/admin_research.py app/routes/admin_documents.py app/services/research_command_service.py tests/api/test_admin_research_facts.py
  git commit -m "feat: add administrative research facts API"
  ```

## Task 4: Administrative immutable revision APIs

**Files:**
- Create: `tests/api/test_admin_research_revisions.py`
- Modify: `app/schemas/admin_research.py`
- Modify: `app/routes/admin_research.py`
- Tests: `tests/api/test_admin_research_revisions.py`

**Interfaces:**
- Consumes: `ResearchCommandService.create_research_revision`, `create_market_plan_revision`, `create_forecast_revision`, and `create_valuation_revision`.
- Produces: POST endpoints for research, market-plan, forecast, and valuation revisions with nested children and `base_revision_id` concurrency.

- [ ] **Step 1: Write failing revision API tests**

  Test first/current/stale revision behavior, atomic invalid-child rollback, exact `thesis_invalidation` versus `invalidation_level`, forecast lines with administrator EPS, and all valuation methods. Include an EV/EBITDA request with EBITDA and NET_DEBT lines plus supplied bridge fields, a PE request linked to forecast EPS, and UNIT_BASED with simultaneous CAPACITY/EV_PER_TON/EBITDA_PER_TON/COST_PER_TON lines. Assert bridge values are stored even when arithmetically inconsistent.

- [ ] **Step 2: Run tests to verify endpoints are missing**

  Run: `python -m pytest tests/api/test_admin_research_revisions.py -q`

  Expected: FAIL with 404 responses.

- [ ] **Step 3: Implement nested schemas and service-only routes**

  Use decimal fields that deserialize to `Decimal` and serialize to strings. Reject client IDs/revision numbers/actors/timestamps. Pass complete nested payloads to one command-service call; do not flush or commit in routes. Map stale bases and duplicate races to 409.

- [ ] **Step 4: Run API and core revision tests**

  Run: `python -m pytest tests/api/test_admin_research_revisions.py tests/research/test_research_revisions.py tests/research/test_market_plan_revisions.py tests/research/test_forecast_revisions.py tests/research/test_valuation_revisions.py -q`

  Expected: all tests pass; invalid nested requests leave no header or child rows.

- [ ] **Step 5: Commit immutable revision APIs**

  ```bash
  git add app/schemas/admin_research.py app/routes/admin_research.py tests/api/test_admin_research_revisions.py
  git commit -m "feat: add administrative research revision API"
  ```

## Task 5: Consumer research, disclosures, and history APIs

**Files:**
- Create: `tests/api/test_research_consumer_api.py`
- Modify: `app/routes/research.py`
- Modify: `app/schemas/research.py`
- Tests: `tests/api/test_research_consumer_api.py`

**Interfaces:**
- Consumes: `EntitlementService`, `ResearchQueryService`, `ResearchPresenter`, and `MarketPriceService` from Plan 3.
- Produces: all consumer company list/detail/disclosure/history endpoints in specification section 9.1, excluding document endpoints handled by Task 6.

- [ ] **Step 1: Write failing consumer API matrix tests**

  Cover filters/pagination, unknown company, CMP current/stale/unavailable, free/premium/admin projections, null-versus-omission, locked-section metadata, database entitlement changes with an unchanged JWT, and rights-neutral company data. Test `GET /api/research/companies/<company_id>/disclosures?event_type=REG30&is_key=true&sort=-event_date&per_page=5` returns exactly the newest five with deterministic ties and no free-tier significance notes. Test history section/method filters and free non-leakage.

- [ ] **Step 2: Run tests to verify endpoints are missing**

  Run: `python -m pytest tests/api/test_research_consumer_api.py -q`

  Expected: FAIL with 404 responses.

- [ ] **Step 3: Implement authenticated thin consumer routes**

  Each route loads the current User from JWT identity, resolves context from the entitlement service, validates query parameters, calls one query service, then calls the presenter/schema. Use `items`, `page`, `per_page`, `total_items`, and `total_pages` for new collections. Do not use `PaginatedAPIMixin` because its legacy `_meta/_links` shape differs and must remain unchanged for legacy callers.

- [ ] **Step 4: Run consumer and leakage tests**

  Run: `python -m pytest tests/api/test_research_consumer_api.py tests/security/test_research_data_isolation.py tests/legacy -q`

  Expected: all tests pass; recursive premium sentinels are absent from every free response.

- [ ] **Step 5: Commit consumer research APIs**

  ```bash
  git add app/routes/research.py app/schemas/research.py tests/api/test_research_consumer_api.py
  git commit -m "feat: add entitlement-safe research API"
  ```

## Task 6: Administrative and consumer document APIs

**Files:**
- Create: `tests/api/test_document_api.py`
- Modify: `app/routes/documents.py`
- Modify: `app/routes/admin_documents.py`
- Modify: `app/schemas/document.py`
- Tests: `tests/api/test_document_api.py`

**Interfaces:**
- Consumes: `DocumentLibraryService`, `DocumentAccessPolicy`, `EntitlementService`, and document schemas.
- Produces: document aggregate create, document patch, company-link add, company document list, institutional report list, and document detail endpoints exactly as specification section 9 defines.

- [ ] **Step 1: Write failing API rights and transaction tests**

  Cover complete aggregate creation, institutional conditional metadata, invalid aggregate rollback, duplicate 409, link-change recomputation/rollback, audited state changes, type/institution/date filters, latest-per-institution, provider/admin private access, unrelated premium 404, public-not-distributable behavior, LINK_ONLY with no stored reference, and recursive absence of `storage_key`, restricted hash, private source reference, counts, and aggregates. Assert no upload/download/preview/share/analysis route exists.

- [ ] **Step 2: Run tests to verify document endpoints are missing**

  Run: `python -m pytest tests/api/test_document_api.py -q`

  Expected: FAIL with 404 responses.

- [ ] **Step 3: Implement policy-enforced document routes**

  Administrative routes use `@admin_required`, validate complete payloads, and call one library-service command. Consumer routes use JWT plus entitlement context, but authorize every record through `DocumentAccessPolicy` before serialization or count calculation. Return 404 for rights-sensitive invisibility and 409 for duplicate candidates; never return an ORM dump.

- [ ] **Step 4: Run document API and rights suites**

  Run: `python -m pytest tests/api/test_document_api.py tests/documents tests/security/test_document_access_policy.py tests/security/test_document_rights_leakage.py -q`

  Expected: all tests pass; private/restricted data cannot be inferred through response shape or totals.

- [ ] **Step 5: Commit document APIs**

  ```bash
  git add app/routes/documents.py app/routes/admin_documents.py app/schemas/document.py tests/api/test_document_api.py
  git commit -m "feat: add rights-safe document API"
  ```

## Task 7: Idempotent source-backed IKIO seed command

**Files:**
- Create: `seed_data/ikio_research.json`
- Create: `scripts/seed_research.py`
- Create: `tests/seed/test_ikio_seed.py`
- Modify: none

**Interfaces:**
- Consumes: existing `Ticker(symbol="IKIO")`, `ResearchCommandService` company identity command, and `DocumentLibraryService.create_document`.
- Produces: `seed_ikio(payload_path: Path, actor_user_id: str) -> Company` and CLI arguments `--payload`, `--actor-user-id`, and `--dry-run`.

- [ ] **Step 1: Write failing seed tests**

  Test missing ticker aborts without creating market data; non-admin actor aborts; first run creates one Company linked to the existing ticker and one link-safe quarterly-results Document; second run creates no duplicate; CMP is never seeded; unknown research/management/governance/ownership/forecast/valuation fields remain absent; and dry-run validates/resolves without committing.

- [ ] **Step 2: Run tests to verify seed files are absent**

  Run: `python -m pytest tests/seed/test_ikio_seed.py -q`

  Expected: FAIL importing `seed_ikio` or opening the payload.

- [ ] **Step 3: Add the verified payload and service-driven command**

  Use `seed_version="ios-m1-ikio-v1"`, ticker symbol `IKIO`, legal/display name `IKIO Technologies Limited`, and ISIN `INE0LOJ01019`. Cite the official NSE integrated filing URL `https://nsearchives.nseindia.com/corporate/ixbrl/INTEGRATED_FILING_INDAS_184272_08082026200616_iXBRL_WEB.html` in the payload. Add one `QUARTERLY_RESULTS` Document titled `IKIO Technologies Limited — Q1 FY27 Integrated Filing`, dated `2026-08-08`, reporting period `Q1_FY27`, publisher `National Stock Exchange of India Limited`, official URL above, discovery `OFFICIAL_SITE`, source access `PUBLIC`, acquisition `MANUAL_REFERENCE`, distribution `LINK_ONLY`, ingestion `DISCOVERED`, and one primary IKIO company link. Do not store/download a file or create narrative research from unsourced interpretation.

  The script resolves the existing ticker and actor, validates `seed_version`, reuses company by ticker/ISIN, checks the Document fingerprint before creation, and invokes the same command/library services as the admin API.

- [ ] **Step 4: Run seed and idempotency tests**

  Run: `python -m pytest tests/seed/test_ikio_seed.py -q`

  Expected: all tests pass; two executions leave one company and one document, with ticker price unchanged.

- [ ] **Step 5: Commit the IKIO seed**

  ```bash
  git add seed_data/ikio_research.json scripts/seed_research.py tests/seed/test_ikio_seed.py
  git commit -m "feat: add sourced IKIO research seed"
  ```

## Task 8: Full regression, architecture boundary, and release verification

**Files:**
- Create: `tests/test_milestone1_architecture_boundaries.py`
- Create: `tests/test_milestone1_api_contract.py`
- Modify: `tests/migrations/test_milestone1_fresh_upgrade.py`
- Modify: `tests/migrations/test_milestone1_existing_schema_upgrade.py`
- Tests: all files above and the complete suite

**Interfaces:**
- Consumes: every Milestone 1 and legacy interface.
- Produces: release-blocking proof that the complete implementation matches the frozen specification without legacy or rights regressions.

- [ ] **Step 1: Write failing whole-system boundary assertions**

  Parse imports and Flask URL rules to assert research/document services never enter `live/websocket.py`, `kite`, `Trade.check`, `Trade.update_etas`, or Telegram notification paths; no frontend path exists; no file/analysis/consensus/engine/SOTP endpoint or model exists; existing API response-key snapshots are unchanged; all research endpoints require JWT; all admin endpoints require admin; and every new collection uses the approved pagination shape.

- [ ] **Step 2: Run the complete suite and capture failures**

  Run: `python -m pytest -q`

  Expected: any remaining contract, migration, security, or integration mismatch fails with a named test; no external network call is allowed.

- [ ] **Step 3: Make only requirement-linked corrections**

  Correct the specific schema allowlist, route-to-service call, transaction boundary, model constraint, migration operation, or test fixture identified by each failure. Do not refactor legacy code or introduce an out-of-scope subsystem.

- [ ] **Step 4: Run release verification commands**

  Run: `python -m pytest -q`

  Expected: all tests pass.

  Run: `git diff --exit-code "$(git merge-base HEAD origin/master)" -- app/models/user.py app/models/ticker.py app/models/trade.py app/models/tag.py app/models/telegram_verification.py live/websocket.py kite app/services/telegram_service.py app/routes/auth.py app/routes/trades.py app/routes/tickers.py app/routes/tags.py app/routes/telegram.py`

  Expected: no implementation diff except any explicitly reviewed `app/__init__.py`/error-handler integration outside this command; all listed legacy files are unchanged.

  Run: `python -m pytest tests/migrations/test_milestone1_fresh_upgrade.py tests/migrations/test_milestone1_existing_schema_upgrade.py tests/migrations/test_legacy_schema_immutability.py -q`

  Expected: both migration paths pass and legacy schemas remain identical.

- [ ] **Step 5: Commit final regression guards**

  ```bash
  git add tests/test_milestone1_architecture_boundaries.py tests/test_milestone1_api_contract.py tests/migrations/test_milestone1_fresh_upgrade.py tests/migrations/test_milestone1_existing_schema_upgrade.py
  git commit -m "test: complete Investment Operating System regression gates"
  ```

## Deployment-only migration procedure

These commands are not part of automated implementation and run only after Task 1's signed gate:

1. Set `DATABASE_URL` to one inventoried active database and set `IOS_M1_AUDIT_DIR` to its secured evidence directory.
2. Re-run the read-only inventory and compare it with the signed artifact.
3. If the database is empty, run `flask --app main:app db upgrade 20260904_02`.
4. If the database contains the verified legacy schema and has no Alembic history, run `flask --app main:app db stamp 20260904_01`, verify `flask --app main:app db current`, then run `flask --app main:app db upgrade 20260904_02`.
5. If any Alembic history already exists or any schema drift appears, stop. Record the difference and obtain a reviewed reconciliation revision/path before any stamp or upgrade.
6. Re-run the schema inventory, legacy-table comparison, and application smoke tests; retain the backup until rollback/restore acceptance is signed.

Local or CI downgrade tests may exercise `20260904_02 -> 20260904_01`. No shared or production downgrade runs automatically.

## Completion gate

All tests pass in one clean run; both migration paths pass; only new tables are added; every consumer/admin contract matches the specification; the IKIO seed is sourced and idempotent; free/premium/document-rights leakage matrices pass; `storage_key` never appears; legacy API/import/schema checks pass; and no active database command has run outside the signed deployment procedure.
