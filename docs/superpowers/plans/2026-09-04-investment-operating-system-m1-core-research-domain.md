# Investment Operating System Milestone 1 — Core Research Domain Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Feature:** Investment Operating System Milestone 1 — Core Research Domain

**Goal:** Implement the normalized company research models, immutable revisions, administrator-supplied forecast and valuation snapshots, and domain validation required by Milestone 1.

**Architecture:** Add focused SQLAlchemy 2.0 model modules that inherit the existing `BaseModel`, with portable string-backed classifications and explicit fixed-precision numeric columns. `ResearchCommandService` owns validation, revision concurrency, transactions, and rollback. Existing User and Ticker tables remain unchanged; new foreign keys and unidirectional relationships live only on new models.

**Tech Stack:** Python 3.12, Flask-SQLAlchemy 3.0.5, SQLAlchemy 2.0 typed mappings, Marshmallow 3.20.1, pytest 8.3.5, SQLite test database.

**Spec:** `../stock-price-alert/docs/superpowers/specs/2026-09-04-investment-operating-system-milestone-1-design.md`

## Global Constraints

- Depends on completion of the Foundation plan's repository gate.
- Run all implementation and test commands from `backendtest`.
- Add no columns to existing `user`, `ticker`, `trade`, `tag`, `trade_tags`, or `telegram_verification` tables; do not modify `app/models/user.py` or `app/models/ticker.py` in this plan.
- Use string UUID primary keys and UTC `created_at` from `BaseModel`; mutable metadata models declare timezone-aware `updated_at` and archival fields explicitly.
- Store financial amounts as `Numeric`, never `Float`; serialize them only in Plan 3/5.
- Revision rows and their child rows are append-only and have no update or delete command.
- Services own commits and rollbacks; stale revision bases return a typed conflict rather than overwriting.
- EPS and every valuation bridge/reference value are administrator-supplied snapshots; do not calculate EPS, net debt, multiples, discounting, or enterprise-to-equity values.
- Do not create SOTP component tables, operating-metric engines, institutional-analysis tables, APIs, seed data, migrations, or frontend files.
- Research services must not be imported by `live/websocket.py`, `app/models/trade.py`, or `app/services/telegram_service.py`.

---

## Task 1: Shared research classifications, numeric helpers, and domain errors

**Files:**
- Create: `app/models/research_types.py`
- Create: `app/utils/research_errors.py`
- Create: `app/utils/research_validation.py`
- Create: `tests/research/test_research_types.py`
- Create: `tests/research/test_research_validation.py`
- Modify: none

**Interfaces:**
- Consumes: SQLAlchemy `Enum`, `Numeric`, and the approved machine values.
- Produces: string constant classes `ResearchTier`, `EntitlementStatus`, `ManagementQuality`, `GovernanceStatus`, `GovernanceSeverity`, `GovernanceFlagStatus`, `ResearchPointKind`, `ValuationMethod`, plus `enum_type(name: str, values: Sequence[str]) -> sa.Enum`, `money_column(nullable: bool = True)`, `validate_upper_slug(value: str, field: str) -> str`, `validate_percentage(value: Decimal | None, field: str) -> None`, `ResearchValidationError`, `ResearchConflictError`, `ResearchNotFoundError`, and `ResearchForbiddenError`.

- [ ] **Step 1: Write failing classification and validation tests**

  Assert the exact valuation methods are `PE`, `EV_EBITDA`, `PB`, `NAV`, `SOTP`, `ASSET_VALUE`, `UNIT_BASED`, and `OTHER`. Assert `validate_upper_slug("EBITDA_PER_TON", "reference_metric")` succeeds while lowercase, whitespace, punctuation, empty, and over-64-character inputs raise `ResearchValidationError` with `code == "validation_error"` and a field-keyed `details` mapping.

- [ ] **Step 2: Run tests to verify missing modules**

  Run: `python -m pytest tests/research/test_research_types.py tests/research/test_research_validation.py -q`

  Expected: FAIL during import because the new modules do not exist.

- [ ] **Step 3: Implement the shared interfaces**

  Use `sa.Enum(*values, name=name, native_enum=False, validate_strings=True)` for closed classifications and `sa.Numeric(20, 4)` for financial snapshots. Define errors with exact constructor shape:

  ```python
  class ResearchValidationError(Exception):
      code = "validation_error"

      def __init__(self, details: dict[str, list[str]]):
          super().__init__("Request validation failed")
          self.details = details
  ```

  Define `ResearchConflictError(code: str, message: str)`, `ResearchNotFoundError(code: str, message: str)`, and `ResearchForbiddenError(code: str, message: str)` with public `code` and `message` attributes and no raw exception payload. `validate_upper_slug` must enforce `^[A-Z][A-Z0-9_]{0,63}$`; metric and unit slugs must never use a closed database enum.

- [ ] **Step 4: Run focused tests**

  Run: `python -m pytest tests/research/test_research_types.py tests/research/test_research_validation.py -q`

  Expected: all tests pass.

- [ ] **Step 5: Commit shared domain primitives**

  ```bash
  git add app/models/research_types.py app/utils/research_errors.py app/utils/research_validation.py tests/research/test_research_types.py tests/research/test_research_validation.py
  git commit -m "feat: add research domain primitives"
  ```

## Task 2: Business group and company identity

**Files:**
- Create: `app/models/company.py`
- Create: `app/services/research_command_service.py`
- Create: `tests/research/test_company_models.py`
- Modify: `app/models/__init__.py`
- Tests: `tests/research/test_company_models.py`

**Interfaces:**
- Consumes: `BaseModel`, existing `ticker.id`, and UTC datetime conventions.
- Produces: `BusinessGroup`, `Company`, `Company.ticker` as a unidirectional read relationship, `Company.display_label`, `ResearchCommandService.create_company(payload: dict, actor_user_id: str) -> Company`, and `ResearchCommandService.update_company(company_id: str, changes: dict, actor_user_id: str) -> Company`.

- [ ] **Step 1: Write failing identity and constraint tests**

  Test unique `BusinessGroup.name`, unique normalized uppercase 12-character `Company.isin`, unique `Company.ticker_id`, display-name fallback, and group assignment requiring both `business_group_basis` and `business_group_source_reference`. Assert no column is added to the reflected `ticker` table.

- [ ] **Step 2: Run the model tests to verify missing classes**

  Run: `python -m pytest tests/research/test_company_models.py -q`

  Expected: FAIL importing `BusinessGroup` and `Company`.

- [ ] **Step 3: Implement models and constraints**

  `BusinessGroup` fields are `name`, `notes`, `source_reference`, and `updated_at`. `Company` fields are `ticker_id`, `legal_name`, `display_name`, `isin`, indexed `sector`, indexed `industry`, `business_group_id`, `business_group_basis`, `business_group_source_reference`, and `updated_at`. Add named unique and check constraints for ticker, ISIN, and complete group evidence. Create `ResearchCommandService` with the two signatures above; normalize ISIN before duplicate checks, resolve the existing Ticker, validate group evidence, commit once, and rollback/translate uniqueness failures. Export both classes from `app/models/__init__.py`; do not add reverse relationships to legacy models.

- [ ] **Step 4: Run identity and legacy schema tests**

  Run: `python -m pytest tests/research/test_company_models.py tests/migrations/test_legacy_schema_immutability.py -q`

  Expected: all tests pass; the legacy ticker schema snapshot is unchanged.

- [ ] **Step 5: Commit company identity**

  ```bash
  git add app/models/company.py app/models/__init__.py app/services/research_command_service.py tests/research/test_company_models.py
  git commit -m "feat: add company research identity"
  ```

## Task 3: One-row user entitlement persistence

**Files:**
- Create: `app/models/entitlement.py`
- Create: `tests/research/test_entitlement_model.py`
- Modify: `app/models/__init__.py`
- Modify: `app/services/research_command_service.py`
- Modify: `tests/conftest.py`
- Tests: `tests/research/test_entitlement_model.py`

**Interfaces:**
- Consumes: existing `user.id`, `ResearchTier`, and `EntitlementStatus`.
- Produces: `UserEntitlement` with unique `(user_id, product_code)`, `ResearchCommandService.upsert_entitlement(user_id: str, payload: dict, actor_user_id: str) -> UserEntitlement`, and fixture behavior where `premium_user` owns an active `INVESTMENT_RESEARCH/PREMIUM` row.

- [ ] **Step 1: Write failing persistence tests**

  Assert the model stores `tier`, `status`, `valid_from`, and `valid_until`; a second row for the same `(user_id, product_code)` raises `IntegrityError`; different products remain possible; no entitlement history table exists; and reflection shows no new `user` columns.

- [ ] **Step 2: Run tests to verify missing model**

  Run: `python -m pytest tests/research/test_entitlement_model.py -q`

  Expected: FAIL importing `UserEntitlement`.

- [ ] **Step 3: Implement the entitlement model and premium fixture**

  Use `product_code: String(64)`, string-backed tier/status enums, nullable timezone-aware validity bounds, and `updated_at`. Add `UniqueConstraint("user_id", "product_code", name="uq_user_entitlement_user_product")`. Use a unidirectional `user` relationship; do not modify `User`. Implement `upsert_entitlement` to lock/query the one row, create it if missing, otherwise update tier/status/validity in place, and commit once.

- [ ] **Step 4: Run entitlement and legacy user tests**

  Run: `python -m pytest tests/research/test_entitlement_model.py tests/legacy/test_user_contract.py -q`

  Expected: all tests pass and legacy user serialization has no entitlement fields.

- [ ] **Step 5: Commit entitlement persistence**

  ```bash
  git add app/models/entitlement.py app/models/__init__.py app/services/research_command_service.py tests/conftest.py tests/research/test_entitlement_model.py
  git commit -m "feat: add research entitlement persistence"
  ```

## Task 4: Narrative research revisions and concurrency primitive

**Files:**
- Create: `app/models/research.py`
- Modify: `app/services/research_command_service.py`
- Create: `tests/research/test_research_revisions.py`
- Modify: `app/models/__init__.py`
- Tests: `tests/research/test_research_revisions.py`

**Interfaces:**
- Consumes: `Company`, existing administrator `User`, `ResearchValidationError`, and `ResearchConflictError`.
- Produces: `ResearchRevision`, `ResearchPoint`, and `ResearchCommandService.create_research_revision(company_id: str, actor_user_id: str, payload: dict) -> ResearchRevision` where payload accepts `base_revision_id`, revision fields, and ordered `points`.

- [ ] **Step 1: Write failing immutable-revision tests**

  Test first revision number 1 with null supersedes/base, ordered CATALYST/RISK children, second revision requiring the current base and non-empty `change_reason`, stale base returning `ResearchConflictError`, required `thesis_invalidation`, management-rationale conditional validation, unique `(company_id, revision_number)`, atomic rollback for an invalid child, and absence of update/delete commands.

- [ ] **Step 2: Run tests to verify missing models and service**

  Run: `python -m pytest tests/research/test_research_revisions.py -q`

  Expected: FAIL importing the new classes.

- [ ] **Step 3: Implement revision models and command transaction**

  Map `ResearchRevision` with `id`, `company_id`, `revision_number`, `supersedes_revision_id`, `why_selected`, `what_is_changing`, `business_journey`, `thesis`, `thesis_invalidation`, `management_summary`, `management_quality`, `management_rationale`, `management_evidence`, `governance_status`, `change_reason`, `effective_at`, `created_by_user_id`, and `created_at`. Map `ResearchPoint` with `id`, `research_revision_id`, `kind`, `title`, `detail`, `status`, `target_date`, and `sort_order`, plus unique `(research_revision_id, kind, sort_order)`. Apply the required/nullability and enum rules stated in the frozen specification, including required management rationale outside `UNASSESSED`. In the service, select the current revision ordered by `revision_number DESC` with `with_for_update()`, compare `base_revision_id`, assign the next number, validate all points before adding any row, commit once, and rollback on all exceptions. Translate the unique race into `ResearchConflictError("revision_conflict", "Research revision changed")`.

- [ ] **Step 4: Run revision and legacy live-boundary tests**

  Run: `python -m pytest tests/research/test_research_revisions.py tests/legacy/test_live_pipeline_boundaries.py -q`

  Expected: all tests pass and no live module imports the command service.

- [ ] **Step 5: Commit narrative revision support**

  ```bash
  git add app/models/research.py app/models/__init__.py app/services/research_command_service.py tests/research/test_research_revisions.py
  git commit -m "feat: add immutable research revisions"
  ```

## Task 5: Ownership snapshots

**Files:**
- Create: `app/models/ownership.py`
- Create: `tests/research/test_ownership_snapshots.py`
- Modify: `app/models/__init__.py`
- Modify: `app/services/research_command_service.py`
- Tests: `tests/research/test_ownership_snapshots.py`

**Interfaces:**
- Consumes: `Company`, administrator `User`, and percentage validation.
- Produces: `OwnershipSnapshot` and `ResearchCommandService.add_ownership_snapshot(company_id: str, actor_user_id: str, payload: dict) -> OwnershipSnapshot`.

- [ ] **Step 1: Write failing snapshot tests**

  Assert unique `(company_id, as_of_date)`, percentages from 0 through 100, required `source_reference` when either percentage is present, allowance for a notes-only snapshot, append-only history, and rollback on duplicate dates.

- [ ] **Step 2: Run tests to verify missing model and command**

  Run: `python -m pytest tests/research/test_ownership_snapshots.py -q`

  Expected: FAIL importing `OwnershipSnapshot`.

- [ ] **Step 3: Implement the model and command**

  Use `Numeric(7, 4)` for percentages, `Date` for `as_of_date`, named range/source check constraints, and no `updated_at`. Validate the entire payload before insertion and commit once.

- [ ] **Step 4: Run snapshot tests**

  Run: `python -m pytest tests/research/test_ownership_snapshots.py -q`

  Expected: all tests pass.

- [ ] **Step 5: Commit ownership history**

  ```bash
  git add app/models/ownership.py app/models/__init__.py app/services/research_command_service.py tests/research/test_ownership_snapshots.py
  git commit -m "feat: add ownership snapshots"
  ```

## Task 6: Governance flags and manually curated disclosures

**Files:**
- Create: `app/models/governance.py`
- Create: `app/models/disclosure.py`
- Create: `tests/research/test_governance_and_disclosures.py`
- Modify: `app/models/__init__.py`
- Modify: `app/services/research_command_service.py`
- Tests: `tests/research/test_governance_and_disclosures.py`

**Interfaces:**
- Consumes: `Company`, administrator `User`, and a temporary nullable document identifier that Plan 4 finalizes before migration generation.
- Produces: `GovernanceFlag`, `CompanyDisclosure`, `ResearchCommandService.create_governance_flag(company_id: str, actor_user_id: str, payload: dict) -> GovernanceFlag`, `ResearchCommandService.update_governance_flag(flag_id: str, actor_user_id: str, changes: dict) -> GovernanceFlag`, `ResearchCommandService.create_disclosure(company_id: str, actor_user_id: str, payload: dict) -> CompanyDisclosure`, and `ResearchCommandService.update_disclosure(disclosure_id: str, actor_user_id: str, changes: dict) -> CompanyDisclosure`.

- [ ] **Step 1: Write failing governance/disclosure tests**

  Test required factual evidence/source/interpretation, valid severity/status, resolved date only for RESOLVED, archival preservation, `is_key` default false, manual true/false updates, event date ordering inputs, required disclosure source reference, and no numeric importance field. Store `document_id` as null throughout this plan because Plan 4 Task 1 adds the final foreign key when the `document` table enters metadata.

- [ ] **Step 2: Run tests to verify missing models**

  Run: `python -m pytest tests/research/test_governance_and_disclosures.py -q`

  Expected: FAIL importing `GovernanceFlag` and `CompanyDisclosure`.

- [ ] **Step 3: Implement mutable audited facts**

  Map `GovernanceFlag` with `id`, `company_id`, `flag_type`, `title`, `severity`, `status`, `factual_evidence`, `source_title`, `source_url_or_reference`, `interpretation`, `observed_on`, `resolved_on`, `created_by_user_id`, `created_at`, `updated_at`, and `archived_at`. Map `CompanyDisclosure` with `id`, `company_id`, `event_type`, `event_date`, `title`, `original_source_url_or_reference`, `exchange_reference`, `significance_note`, `is_key`, `document_id`, `created_by_user_id`, `created_at`, `updated_at`, and `archived_at`. Apply the frozen specification's required/nullability and closed-state rules, including `is_key: Boolean(nullable=False, default=False, server_default=sa.false())`. In this pre-Document commit, map `document_id` as `String(36), nullable=True` and reject non-null values in the command service; Plan 4 Task 1 replaces that mapping with `ForeignKey("document.id")` before any additive migration is created. Keep `event_type` as a length-limited uppercase slug rather than a Reg. 30-only enum. Implement the four produced command methods with validation, one commit, rollback, correction/archive behavior, and no delete path.

- [ ] **Step 4: Run focused and legacy tests**

  Run: `python -m pytest tests/research/test_governance_and_disclosures.py tests/legacy -q`

  Expected: all tests pass and existing routes remain unchanged.

- [ ] **Step 5: Commit governance and disclosure facts**

  ```bash
  git add app/models/governance.py app/models/disclosure.py app/models/__init__.py app/services/research_command_service.py tests/research/test_governance_and_disclosures.py
  git commit -m "feat: add governance flags and disclosures"
  ```

## Task 7: Market-plan revision stream

**Files:**
- Create: `app/models/market_plan.py`
- Create: `tests/research/test_market_plan_revisions.py`
- Modify: `app/models/__init__.py`
- Modify: `app/services/research_command_service.py`
- Tests: `tests/research/test_market_plan_revisions.py`

**Interfaces:**
- Consumes: the revision concurrency behavior established in Task 4.
- Produces: `MarketPlanRevision` and `ResearchCommandService.create_market_plan_revision(company_id: str, actor_user_id: str, payload: dict) -> MarketPlanRevision`.

- [ ] **Step 1: Write failing market-plan tests**

  Cover positive ordered accumulation bounds, preferred price within bounds, paired ordered supply bounds, positive `invalidation_level`, required `effective_at`, independent naming from `ResearchRevision.thesis_invalidation`, stale-base conflict, and immutable history.

- [ ] **Step 2: Run tests to verify missing model**

  Run: `python -m pytest tests/research/test_market_plan_revisions.py -q`

  Expected: FAIL importing `MarketPlanRevision`.

- [ ] **Step 3: Implement model and command**

  Store all prices in `Numeric(20, 4)`, `currency="INR"`, and use unique `(company_id, revision_number)`. Reuse the Task 4 lock/compare/next-number algorithm; validate all bounds before adding the revision.

- [ ] **Step 4: Run market and narrative revision tests**

  Run: `python -m pytest tests/research/test_market_plan_revisions.py tests/research/test_research_revisions.py -q`

  Expected: all tests pass and the two invalidation properties remain distinct.

- [ ] **Step 5: Commit market plans**

  ```bash
  git add app/models/market_plan.py app/models/__init__.py app/services/research_command_service.py tests/research/test_market_plan_revisions.py
  git commit -m "feat: add immutable market plans"
  ```

## Task 8: Forecast revisions with administrator-supplied EPS

**Files:**
- Create: `app/models/forecast.py`
- Create: `tests/research/test_forecast_revisions.py`
- Modify: `app/models/__init__.py`
- Modify: `app/services/research_command_service.py`
- Tests: `tests/research/test_forecast_revisions.py`

**Interfaces:**
- Consumes: revision concurrency and `money_column`.
- Produces: `ForecastRevision`, `ForecastLine`, and `ResearchCommandService.create_forecast_revision(company_id: str, actor_user_id: str, payload: dict) -> ForecastRevision` accepting ordered `lines`.

- [ ] **Step 1: Write failing forecast tests**

  Test unique fiscal year per revision; optional revenue, EBITDA, margin, PAT, and EPS; exact Decimal persistence; 0–100 margin; valid unit values; EPS present or null independently of PAT; no share-count column; no derived EPS; atomic rollback for duplicate fiscal years; and stale-base conflict.

- [ ] **Step 2: Run tests to verify missing forecast classes**

  Run: `python -m pytest tests/research/test_forecast_revisions.py -q`

  Expected: FAIL importing `ForecastRevision` and `ForecastLine`.

- [ ] **Step 3: Implement forecast header, lines, and command**

  `ForecastLine` fields are exactly `forecast_revision_id`, `fiscal_year`, `is_estimate`, `revenue`, `ebitda`, `pat`, `ebitda_margin_pct`, `eps`, `currency`, and `unit`, with unique `(forecast_revision_id, fiscal_year)`. The command validates all lines first, inserts header and lines atomically, and performs no financial calculation.

- [ ] **Step 4: Run forecast and revision tests**

  Run: `python -m pytest tests/research/test_forecast_revisions.py tests/research/test_research_revisions.py -q`

  Expected: all tests pass; supplied EPS is unchanged and null EPS remains null.

- [ ] **Step 5: Commit forecast snapshots**

  ```bash
  git add app/models/forecast.py app/models/__init__.py app/services/research_command_service.py tests/research/test_forecast_revisions.py
  git commit -m "feat: add immutable forecast snapshots"
  ```

## Task 9: Method-neutral valuation revisions and reference lines

**Files:**
- Create: `app/models/valuation.py`
- Create: `tests/research/test_valuation_revisions.py`
- Modify: `app/models/__init__.py`
- Modify: `app/services/research_command_service.py`
- Tests: `tests/research/test_valuation_revisions.py`

**Interfaces:**
- Consumes: `ForecastRevision`, `ForecastLine`, valuation method constants, slug validation, and revision concurrency.
- Produces: `ValuationRevision`, `ValuationReferenceLine`, and `ResearchCommandService.create_valuation_revision(company_id: str, actor_user_id: str, payload: dict) -> ValuationRevision`.

- [ ] **Step 1: Write failing valuation tests**

  Cover independent unique revision streams by `(company_id, valuation_method)`; zero/one/many immutable reference lines; unique non-negative sort order; required metric/value/unit/basis; uppercase extensible slugs; same-company forecast linkage; required fiscal year for a forecast link; existence of the referenced forecast metric; EPS linkage to supplied EPS; unit-based simultaneous `CAPACITY`, `EV_PER_TON`, `EBITDA_PER_TON`, and `COST_PER_TON`; every method's validation; meaningful conclusion; stale base; and atomic rollback.

  Add bridge cases proving positive debt, negative net cash, null bridge fields for equity-value methods, and exact persistence of inconsistent administrator snapshots without calculation or equality enforcement.

- [ ] **Step 2: Run tests to verify missing valuation classes**

  Run: `python -m pytest tests/research/test_valuation_revisions.py -q`

  Expected: FAIL importing `ValuationRevision` and `ValuationReferenceLine`.

- [ ] **Step 3: Implement valuation storage and method validation**

  Map `ValuationRevision` with `id`, `company_id`, `valuation_method`, `revision_number`, `supersedes_revision_id`, `justified_multiple`, `implied_enterprise_value`, `net_debt`, `other_equity_adjustment`, `implied_future_equity_value`, `required_return_pct`, `discount_period_years`, `present_value`, `current_market_cap`, `currency`, `unit`, `valuation_notes`, `as_of_date`, `change_reason`, `created_by_user_id`, and `created_at`. Map `ValuationReferenceLine` with `id`, `valuation_revision_id`, optional `reference_forecast_revision_id`, optional `reference_fiscal_year`, required `reference_metric`, `reference_metric_value`, `reference_metric_unit`, `reference_metric_basis`, and `sort_order`. Use unique `(company_id, valuation_method, revision_number)` and unique `(valuation_revision_id, sort_order)`. Validate the eight methods exactly as specification section 10.3 defines. Insert reference lines with their parent transaction, never mutate them, never create method-specific tables, and never compute the enterprise-to-equity bridge.

- [ ] **Step 4: Run all core-domain tests**

  Run: `python -m pytest tests/research/test_research_types.py tests/research/test_research_validation.py tests/research/test_company_models.py tests/research/test_entitlement_model.py tests/research/test_research_revisions.py tests/research/test_ownership_snapshots.py tests/research/test_governance_and_disclosures.py tests/research/test_market_plan_revisions.py tests/research/test_forecast_revisions.py tests/research/test_valuation_revisions.py -q`

  Expected: all tests pass; no migration, route, document, seed, live, trade, Telegram, or frontend file has changed.

- [ ] **Step 5: Commit valuation reasoning storage**

  ```bash
  git add app/models/valuation.py app/models/__init__.py app/services/research_command_service.py tests/research/test_valuation_revisions.py
  git commit -m "feat: add immutable valuation revisions"
  ```

## Completion gate

All nine task test groups and `python -m pytest tests/legacy -q` pass. Reflection confirms legacy tables have no new columns. Core models expose the exact interfaces listed above, and no research module is imported from the live websocket, trade, Kite, or Telegram paths.
