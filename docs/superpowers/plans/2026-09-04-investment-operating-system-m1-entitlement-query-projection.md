# Investment Operating System Milestone 1 — Entitlement, Query, and Response Projection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Feature:** Investment Operating System Milestone 1 — Entitlement, Query, and Response Projection

**Goal:** Enforce research entitlements in backend services and produce explicit free, premium, and administrative research projections without leaking protected values.

**Architecture:** Resolve effective tier from `UserEntitlement` for every request, then pass an immutable access context through query and presentation layers. Query services select company research and read current market price through a read-only Ticker boundary. New schemas live in a focused `app/schemas` package while existing legacy schemas and route payloads remain unchanged.

**Tech Stack:** Python 3.12, Flask 2.3.3, Flask-SQLAlchemy 3.0.5, SQLAlchemy 2.0, Flask-JWT-Extended 4.5.3, Marshmallow 3.20.1, pytest 8.3.5.

**Spec:** `../stock-price-alert/docs/superpowers/specs/2026-09-04-investment-operating-system-milestone-1-design.md`

## Global Constraints

- Depends on all tasks in the Core Research Domain plan and the Foundation repository gate.
- Run implementation and test commands from `backendtest`.
- Resolve tier from the database on every protected research request; JWT claims never establish tier.
- Missing, inactive, revoked, not-yet-valid, expired, or malformed entitlement state resolves safely to `FREE`.
- Administrator research access does not override document distribution rights; document authorization is added in Plan 4.
- Free responses omit premium sections and values; locked metadata may reveal only section name and required tier, never snippets, values, counts, or aggregates.
- A present `null` means authorized-but-unknown; an absent field or section means it is outside the caller's projection.
- `Ticker.last_price` and `Ticker.last_updated` are read only; research services never write Ticker, Trade, Kite, websocket, or Telegram state.
- Do not add routes, document models, migrations, seed data, Elasticsearch indexing, or frontend files in this plan.

---

## Task 1: Entitlement resolution and research access policy

**Files:**
- Create: `app/services/entitlement_service.py`
- Create: `app/policies/__init__.py`
- Create: `app/policies/research_access.py`
- Create: `tests/research/test_entitlement_service.py`
- Create: `tests/research/test_research_access_policy.py`
- Modify: none

**Interfaces:**
- Consumes: `User`, `UserEntitlement`, UTC time, `ResearchTier`, and `EntitlementStatus`.
- Produces: immutable `ResearchAccessContext(user_id: str, is_admin: bool, tier: str)`, `EntitlementService.resolve(user: User, at: datetime | None = None) -> ResearchAccessContext`, `ResearchAccessPolicy.allowed_sections(context: ResearchAccessContext) -> frozenset[str]`, and `ResearchAccessPolicy.locked_sections(context: ResearchAccessContext) -> list[dict[str, str]]`.

- [ ] **Step 1: Write failing entitlement matrix tests**

  Test missing row, inactive, revoked, future `valid_from`, expired `valid_until`, valid free, valid premium, and administrator users. Insert a token containing a fake tier claim and assert `resolve()` ignores it because the method reads only the supplied `User` and database row. Assert free sections are exactly `company`, `business_group`, `market_quote`, `public_documents`, and `public_disclosures`; premium/admin additionally receive ownership, management, research, governance, disclosure significance, market plan, forecast, valuation, and history.

- [ ] **Step 2: Run tests to verify missing services**

  Run: `python -m pytest tests/research/test_entitlement_service.py tests/research/test_research_access_policy.py -q`

  Expected: FAIL importing the new service and policy.

- [ ] **Step 3: Implement database-backed resolution**

  Define:

  ```python
  @dataclass(frozen=True)
  class ResearchAccessContext:
      user_id: str
      is_admin: bool
      tier: str

  class EntitlementService:
      @staticmethod
      def resolve(user: User, at: datetime | None = None) -> ResearchAccessContext:
          check_time = at or datetime.now(timezone.utc)
          row = UserEntitlement.query.filter_by(
              user_id=user.id,
              product_code="INVESTMENT_RESEARCH",
          ).one_or_none()
          tier = resolve_effective_tier(row, check_time)
          return ResearchAccessContext(user.id, bool(user.is_admin), tier)
  ```

  `resolve_effective_tier` returns `FREE` for every unsafe state. The access policy elevates administrators for research sections only and returns deterministic section lists.

- [ ] **Step 4: Run policy tests**

  Run: `python -m pytest tests/research/test_entitlement_service.py tests/research/test_research_access_policy.py -q`

  Expected: all tests pass, including stale-JWT-claim cases.

- [ ] **Step 5: Commit entitlement policy**

  ```bash
  git add app/services/entitlement_service.py app/policies/__init__.py app/policies/research_access.py tests/research/test_entitlement_service.py tests/research/test_research_access_policy.py
  git commit -m "feat: enforce research entitlement policy"
  ```

## Task 2: Explicit response schemas and leakage-safe presenter

**Files:**
- Create: `app/schemas/__init__.py`
- Create: `app/schemas/research.py`
- Create: `app/services/research_presenter.py`
- Create: `tests/research/test_research_presenter.py`
- Modify: none

**Interfaces:**
- Consumes: `ResearchAccessContext`, `ResearchAccessPolicy`, domain model instances, and decimal/date serialization conventions.
- Produces: `CompanyFreeSchema`, `CompanyPremiumSchema`, `CompanyAdminSchema`, and `ResearchPresenter.company_detail(aggregate: dict[str, object], context: ResearchAccessContext) -> dict[str, object]`.

- [ ] **Step 1: Write failing recursive leakage tests**

  Build one aggregate containing sentinel premium strings and numbers in every premium section. For a free context, recursively serialize to text and assert none of those sentinels, protected keys, snippets, counts, or derived totals appear. Assert each locked item has exactly `section` and `required_tier` keys, for example `{"section": "forecast", "required_tier": "PREMIUM"}`, with deterministic names only. For premium/admin, assert authorized unknown fields are present with null and known values serialize as decimal strings.

- [ ] **Step 2: Run tests to verify missing presenter**

  Run: `python -m pytest tests/research/test_research_presenter.py -q`

  Expected: FAIL importing the schemas and presenter.

- [ ] **Step 3: Implement explicit projections**

  Define separate Marshmallow schemas rather than dumping a full object and deleting keys. `ResearchPresenter.company_detail` selects exactly one schema class based on context and includes `company`, `market_quote`, and `access`; it does not embed document or disclosure collections, which use their dedicated endpoints and projections in later tasks. Do not inspect JWTs or query the database inside the presenter.

- [ ] **Step 4: Run presenter and entitlement tests**

  Run: `python -m pytest tests/research/test_research_presenter.py tests/research/test_entitlement_service.py tests/research/test_research_access_policy.py -q`

  Expected: all tests pass; recursive sentinel scan finds no free-tier leakage.

- [ ] **Step 5: Commit explicit research projections**

  ```bash
  git add app/schemas/__init__.py app/schemas/research.py app/services/research_presenter.py tests/research/test_research_presenter.py
  git commit -m "feat: add entitlement-safe research projections"
  ```

## Task 3: Read-only market price boundary

**Files:**
- Create: `app/services/market_price_service.py`
- Create: `tests/research/test_market_price_service.py`
- Modify: none

**Interfaces:**
- Consumes: existing `Ticker.last_price` and `Ticker.last_updated`.
- Produces: `MarketPriceService.project(ticker: Ticker) -> dict[str, object]` returning `{"cmp": float | None, "as_of": datetime | None, "stale": bool}` and `MarketPriceService.is_stale(as_of: datetime | None, now: datetime, max_age: timedelta) -> bool`.

- [ ] **Step 1: Write failing projection tests**

  Test current, stale, zero/unavailable, and null timestamp cases. Capture SQLAlchemy attribute history and session dirty state before/after projection; assert no Ticker or Trade mutation and no commit. Use a default stale threshold of 15 minutes supplied as a method argument, not global market logic.

- [ ] **Step 2: Run tests to verify missing service**

  Run: `python -m pytest tests/research/test_market_price_service.py -q`

  Expected: FAIL importing `MarketPriceService`.

- [ ] **Step 3: Implement pure read projection**

  The service reads already-loaded attributes only. Treat `last_price == 0.0` as unavailable and return `cmp=None`; preserve the existing JSON-number convention when a price exists. Do not import `Trade`, `Kite`, `live.websocket`, or `telegram_service`.

- [ ] **Step 4: Run market and live-boundary tests**

  Run: `python -m pytest tests/research/test_market_price_service.py tests/legacy/test_live_pipeline_boundaries.py -q`

  Expected: all tests pass; live pipeline imports remain unchanged.

- [ ] **Step 5: Commit the market boundary**

  ```bash
  git add app/services/market_price_service.py tests/research/test_market_price_service.py
  git commit -m "feat: add read-only market price projection"
  ```

## Task 4: Company list and current-detail query service

**Files:**
- Create: `app/services/research_query_service.py`
- Create: `tests/research/test_research_query_service.py`
- Modify: none

**Interfaces:**
- Consumes: `Company`, all current domain revisions, `MarketPriceService`, `ResearchAccessContext`, and `ResearchAccessPolicy`.
- Produces: `PageResult(items: list[object], page: int, per_page: int, total_items: int, total_pages: int)`, `ResearchQueryService.list_companies(*, q: str | None, sector: str | None, industry: str | None, page: int, per_page: int, context: ResearchAccessContext) -> PageResult`, and `ResearchQueryService.get_company_detail(company_id: str, context: ResearchAccessContext) -> dict[str, object]`.

- [ ] **Step 1: Write failing list/detail query tests**

  Test search across legal/display name, symbol, and ISIN; exact sector/industry filters; stable ordering by display label then ID; page bounds; current revision chosen by highest revision number; current valuation chosen independently per method; latest ownership by date; active governance; current market quote; and no Elasticsearch call. Assert free queries do not load or return premium relationships in their aggregate.

- [ ] **Step 2: Run tests to verify missing query service**

  Run: `python -m pytest tests/research/test_research_query_service.py -q`

  Expected: FAIL importing `ResearchQueryService`.

- [ ] **Step 3: Implement SQLAlchemy query composition**

  Validate `page >= 1` and `1 <= per_page <= 100`. Use SQLAlchemy statements and explicit eager loading selected from `allowed_sections(context)`. Build an aggregate with keys matching the presenter schema: `company`, `business_group`, `market_quote`, `research`, `management`, `governance`, `ownership`, `market_plan`, `forecast`, `valuations`, and `access_input`. Raise `ResearchNotFoundError` for unknown company IDs.

- [ ] **Step 4: Run query, presenter, and market tests**

  Run: `python -m pytest tests/research/test_research_query_service.py tests/research/test_research_presenter.py tests/research/test_market_price_service.py -q`

  Expected: all tests pass; query count assertions show free detail avoids premium child queries.

- [ ] **Step 5: Commit research queries**

  ```bash
  git add app/services/research_query_service.py tests/research/test_research_query_service.py
  git commit -m "feat: add company research queries"
  ```

## Task 5: Disclosure collections and immutable history queries

**Files:**
- Create: `tests/research/test_research_collection_queries.py`
- Modify: `app/services/research_query_service.py`
- Tests: `tests/research/test_research_collection_queries.py`

**Interfaces:**
- Consumes: Task 4 `PageResult` and access context.
- Produces: `ResearchQueryService.list_disclosures(company_id: str, *, event_type: str | None, is_key: bool | None, date_from: date | None, date_to: date | None, newest_first: bool, page: int, per_page: int, context: ResearchAccessContext) -> PageResult` and `ResearchQueryService.get_history(company_id: str, *, section: str, valuation_method: str | None, page: int, per_page: int, context: ResearchAccessContext) -> PageResult`.

- [ ] **Step 1: Write failing collection tests**

  Assert `event_type=REG30`, `is_key=True`, newest-first ordering with `created_at` and ID tie-breakers, and `per_page=5` returns the deterministic latest five. Assert free disclosures omit `significance_note`. Assert history rejects free context, accepts premium/admin, limits sections to research/market/forecast/valuation, and requires/validates `valuation_method` only for valuation history.

- [ ] **Step 2: Run tests to verify missing methods**

  Run: `python -m pytest tests/research/test_research_collection_queries.py -q`

  Expected: FAIL because the two methods are absent.

- [ ] **Step 3: Implement filtered pagination and authorization**

  Apply all filters in SQL, exclude archived disclosures by default, and return `PageResult`. Raise `ResearchNotFoundError` for an inaccessible company, `ResearchValidationError` for invalid filters, and a typed `ResearchForbiddenError` for locked history. Do not reveal history counts to free callers.

- [ ] **Step 4: Run collection and leakage tests**

  Run: `python -m pytest tests/research/test_research_collection_queries.py tests/research/test_research_presenter.py -q`

  Expected: all tests pass; free results contain no significance or history values/counts.

- [ ] **Step 5: Commit collection queries**

  ```bash
  git add app/services/research_query_service.py tests/research/test_research_collection_queries.py
  git commit -m "feat: add disclosure and research history queries"
  ```

## Task 6: Entitlement and projection security matrix

**Files:**
- Create: `tests/security/test_research_data_isolation.py`
- Modify: `tests/conftest.py`
- Tests: `tests/security/test_research_data_isolation.py`

**Interfaces:**
- Consumes: every interface from Tasks 1–5.
- Produces: a release-blocking free/premium/admin matrix reused by Plan 5 API tests through fixture `research_security_matrix`.

- [ ] **Step 1: Write the failing matrix test**

  Parameterize missing, inactive, revoked, future, expired, FREE, PREMIUM, admin-without-row, and admin-with-stale-tier-claim cases. For each, call query service plus presenter, recursively inspect keys and scalar values, and compare against an explicit allowed-section set. Assert entitlement changes in the database affect the next call without issuing a new JWT.

- [ ] **Step 2: Run the matrix to expose any projection gaps**

  Run: `python -m pytest tests/security/test_research_data_isolation.py -q`

  Expected: any unfiltered field fails with its JSON path; safe cases pass.

- [ ] **Step 3: Make minimal policy, query, or schema corrections**

  Correct only the responsible allowlist, eager-load selection, or explicit schema. Do not add generic recursive field deletion, client-side hiding, document rights, or route behavior.

- [ ] **Step 4: Run all Plan 3 and legacy tests**

  Run: `python -m pytest tests/research/test_entitlement_service.py tests/research/test_research_access_policy.py tests/research/test_research_presenter.py tests/research/test_market_price_service.py tests/research/test_research_query_service.py tests/research/test_research_collection_queries.py tests/security/test_research_data_isolation.py tests/legacy -q`

  Expected: all tests pass; legacy response contracts remain unchanged and no research service appears in the live import graph.

- [ ] **Step 5: Commit the security matrix**

  ```bash
  git add tests/conftest.py tests/security/test_research_data_isolation.py app/policies/research_access.py app/services/entitlement_service.py app/services/research_query_service.py app/services/research_presenter.py app/schemas/research.py
  git commit -m "test: enforce research data isolation matrix"
  ```

## Completion gate

All six task groups pass. Missing and stale entitlements resolve to free, premium sentinels never appear in free projections, administrators receive research access without any document-rights shortcut, Ticker remains clean after projection, and all legacy tests remain green.
