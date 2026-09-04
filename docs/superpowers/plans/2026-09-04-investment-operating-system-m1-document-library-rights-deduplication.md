# Investment Operating System Milestone 1 — Document Library, Rights, and Deduplication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Feature:** Investment Operating System Milestone 1 — Document Library, Rights, and Deduplication

**Goal:** Implement the common Document Library, institutional-report metadata, deterministic deduplication, rights isolation, atomic aggregate commands, and append-only document audit history.

**Architecture:** Documents and their company/institution metadata use normalized SQLAlchemy models, while a canonicalization service builds the final SHA-256 metadata fingerprint before insertion. `DocumentAccessPolicy` is implemented and tested before command/query APIs. `DocumentLibraryService` owns complete transactions for initial creation, link changes, state/rights changes, duplicate decisions, and audit rows; product entitlement is only an input and never overrides rights.

**Tech Stack:** Python 3.12, Flask-SQLAlchemy 3.0.5, SQLAlchemy 2.0, Marshmallow 3.20.1, `hashlib` SHA-256, `unicodedata` NFKC normalization, pytest 8.3.5.

**Spec:** `../stock-price-alert/docs/superpowers/specs/2026-09-04-investment-operating-system-milestone-1-design.md`

## Global Constraints

- Depends on the Core Research Domain and Entitlement/Query/Projection plans plus the Foundation repository gate.
- Run implementation and test commands from `backendtest`.
- Use one common Document Library; do not create brokerage-specific storage or institutional-analysis tables.
- Initial creation is one atomic aggregate containing Document metadata, complete initial company links, optional primary company, conditional `InstitutionalReportMetadata`, final fingerprint, and duplicate decision.
- `Document.metadata_fingerprint` is non-null at insertion; no provisional or incomplete Document may become visible.
- A document has zero or one primary company; genuine multi-company/industry documents may have none.
- Public accessibility never implies redistribution. Product tier and administrator research access never override document distribution rights.
- `storage_key` is never returned by a service projection or API schema.
- Restricted/user-uploaded private documents remain available only to provider/admin; unrelated premium users receive a non-revealing not-found result.
- Derived/aggregate eligibility inherits the most restrictive source rights and must not leak values through counts, ranges, or differences.
- Do not add upload, download, preview, sharing, PDF parsing, OCR, discovery, Telegram scanning, analysis, consensus, or frontend behavior.
- Do not modify legacy tables, Kite, websocket, Trade, Ticker, Telegram, authentication, or legacy schemas/routes.

---

## Task 1: Document, institution, link, metadata, and audit models

**Files:**
- Create: `app/models/document.py`
- Create: `app/models/institution.py`
- Create: `app/models/institutional_report.py`
- Create: `tests/documents/test_document_models.py`
- Modify: `app/models/disclosure.py`
- Modify: `app/models/__init__.py`
- Tests: `tests/documents/test_document_models.py`

**Interfaces:**
- Consumes: `BaseModel`, `Company`, existing `user.id`, and the temporary nullable `CompanyDisclosure.document_id` field from Plan 2.
- Produces: `Document`, `DocumentCompanyLink`, `DocumentAuditEvent`, `Institution`, `InstitutionalReportMetadata`, and the final `CompanyDisclosure.document_id -> document.id` foreign key mapping.

- [ ] **Step 1: Write failing model and relationship tests**

  Cover every first-class type including `QUARTERLY_RESULTS`, `CREDIT_RATING_REPORT`, and `INDUSTRY_REPORT`; all four access/acquisition/distribution/ingestion dimensions; opaque storage fields; SHA-256 and fingerprint lengths; user provider/rights-verifier FKs; unique institution normalized name; one-to-one institutional metadata; composite unique document/company link; zero-primary validity; two-primary rejection; multiple reports per institution; append-only audit fields; and disclosure-to-document linking. Reflect legacy tables and assert no column changes.

- [ ] **Step 2: Run tests to verify missing document models**

  Run: `python -m pytest tests/documents/test_document_models.py -q`

  Expected: FAIL importing `Document` and related classes.

- [ ] **Step 3: Implement the normalized models**

  Map `Document` with `id`, `document_type`, `title`, `document_date`, `reporting_period`, `publisher_name`, `publisher_reference`, `original_source_url`, `discovery_source_type`, `discovery_source_reference`, `source_access`, `acquisition_method`, `distribution_status`, `ingestion_status`, `storage_provider`, `storage_key`, `content_hash_sha256`, `metadata_fingerprint`, `mime_type`, `file_size_bytes`, `provided_by_user_id`, `distribution_basis`, `rights_verified_by_user_id`, `rights_verified_at`, `created_by_user_id`, `created_at`, `updated_at`, and `archived_at`. Map `DocumentCompanyLink(document_id, company_id, is_primary, created_at)`, `Institution(id, name, normalized_name, website, created_at, updated_at)`, `InstitutionalReportMetadata(document_id, institution_id, analyst_name, report_type, created_at, updated_at)`, and `DocumentAuditEvent(id, document_id, event_type, field_changed, old_value, new_value, actor_user_id, reason, created_at)`. Apply the frozen specification's exact required/nullability and enum rules. Use portable string-backed enums for closed state values, `String(64)` for hashes, `JSON` for audit old/new values, `BigInteger` for file size, and explicit `updated_at`/`archived_at`. Add unique `Document.metadata_fingerprint`, unique `(document_id, company_id)`, a filtered unique index that permits at most one `is_primary=true` link on dialects that support it, and service-level enforcement for portability. Replace the temporary disclosure string column with `ForeignKey("document.id")`; do not add reverse relationships to legacy models.

- [ ] **Step 4: Run document and legacy schema tests**

  Run: `python -m pytest tests/documents/test_document_models.py tests/migrations/test_legacy_schema_immutability.py -q`

  Expected: all tests pass and legacy schema snapshots are unchanged.

- [ ] **Step 5: Commit document persistence**

  ```bash
  git add app/models/document.py app/models/institution.py app/models/institutional_report.py app/models/disclosure.py app/models/__init__.py tests/documents/test_document_models.py
  git commit -m "feat: add common document library models"
  ```

## Task 2: Document request schemas and state validation

**Files:**
- Create: `app/schemas/document.py`
- Create: `app/services/document_validation_service.py`
- Create: `tests/documents/test_document_validation.py`
- Modify: `app/schemas/__init__.py`
- Tests: `tests/documents/test_document_validation.py`

**Interfaces:**
- Consumes: Document classifications and `ResearchValidationError`.
- Produces: Marshmallow `DocumentCreateSchema`, `DocumentPatchSchema`, `DocumentCompanyLinkSchema`, `InstitutionCreateSchema`, and `DocumentValidationService.validate_create(payload: dict) -> dict`, `validate_patch(document: Document, changes: dict) -> dict`, and `validate_transition(document: Document, changes: dict) -> None`.

- [ ] **Step 1: Write failing validation matrix tests**

  Parameterize valid and invalid combinations for DISCOVERED, AWAITING_UPLOAD, STORED, and ANALYSED; source access; acquisition method; distribution status; storage metadata; user provider; public/link URL requirements; APP_DISTRIBUTABLE basis/verifier/time; institutional metadata conditionality; at-least-one institutional company link; zero-or-one primary; URL schemes; lowercase/invalid SHA-256; and unknown request fields. Assert M1 cannot transition STORED to ANALYSED through its endpoint.

- [ ] **Step 2: Run tests to verify missing schemas/service**

  Run: `python -m pytest tests/documents/test_document_validation.py -q`

  Expected: FAIL importing the new schemas or validator.

- [ ] **Step 3: Implement strict schemas and cross-field rules**

  Set Marshmallow `unknown = RAISE`. Normalize HTTP/HTTPS URLs without following them. Apply defaults: public sources become LINK_ONLY unless verified broader rights; restricted user uploads become PRIVATE_LIBRARY; `USER_UPLOAD` requires `provided_by_user_id`; `STORED`/`ANALYSED` require `storage_provider`, `storage_key`, and SHA-256 while MIME type and file size remain optional but validated when supplied; and `PUBLIC_DOWNLOAD` is rejected for RESTRICTED/UNKNOWN access. Return field-keyed validation details.

- [ ] **Step 4: Run validation tests**

  Run: `python -m pytest tests/documents/test_document_validation.py -q`

  Expected: all state-matrix cases pass.

- [ ] **Step 5: Commit document validation**

  ```bash
  git add app/schemas/__init__.py app/schemas/document.py app/services/document_validation_service.py tests/documents/test_document_validation.py
  git commit -m "feat: validate document rights and ingestion state"
  ```

## Task 3: Generic deterministic fingerprint and duplicate decisions

**Files:**
- Create: `app/services/document_deduplication_service.py`
- Create: `tests/documents/test_document_deduplication.py`
- Modify: none

**Interfaces:**
- Consumes: normalized document input, complete company-ID collection, and optional institution ID.
- Produces: `FINGERPRINT_VERSION = 1`, `normalize_fingerprint_text(value: str | None) -> str | None`, `DocumentDeduplicationService.canonical_payload(*, document_type: str, company_ids: list[str], document_date: date | None, title: str, publisher_name: str | None, institution_id: str | None, reporting_period: str | None, report_type: str | None) -> dict[str, object]`, `metadata_fingerprint(**inputs) -> str`, and `find_duplicate(*, metadata_fingerprint: str, content_hash_sha256: str | None) -> DuplicateDecision` where `DuplicateDecision` contains `kind` and `matched_document_id`.

- [ ] **Step 1: Write failing canonicalization and deduplication tests**

  Assert NFKC normalization, trimmed/collapsed whitespace, casefolding while retaining normalized punctuation, ISO dates and the literal null sentinel `"<NULL>"`, stable sorted JSON serialization, sorted unique company IDs, order/primary independence, institutional ID precedence over publisher name, applicable reporting period/report type, analyst exclusion, type differentiation, and known SHA-256 golden hashes. Test decisions `NONE`, `METADATA_MATCH`, `EXACT_BINARY`, and `BINARY_METADATA_CONFLICT`; institution/date alone never makes a duplicate.

- [ ] **Step 2: Run tests to verify missing service**

  Run: `python -m pytest tests/documents/test_document_deduplication.py -q`

  Expected: FAIL importing `DocumentDeduplicationService`.

- [ ] **Step 3: Implement versioned canonical hashing and lookup**

  Normalize text with `unicodedata.normalize("NFKC", value)`, whitespace collapse, trim, casefold, and no punctuation removal. Use `"<NULL>"` for absent scalar inputs and `[]` for no companies. Serialize a dictionary containing exactly `version`, `document_type`, `company_ids`, `document_date`, `title`, `publisher_or_institution`, `reporting_period`, and `institutional_report_type` using `json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)`, then hash UTF-8 bytes with SHA-256. The canonical golden string `{"company_ids":["company-a","company-b"],"document_date":"2026-08-31","document_type":"INSTITUTIONAL_RESEARCH","institutional_report_type":"initiating_coverage","publisher_or_institution":"institution-1","reporting_period":"fy27e","title":"example report","version":1}` must hash to `53d6d92f91928606498b4775c3d6a5eb6d412fc6210087422d21a78fd463ad8d`. Query content hash first, then metadata fingerprint, and return an immutable `DuplicateDecision(kind: str, matched_document_id: str | None)`.

- [ ] **Step 4: Run fingerprint tests twice**

  Run: `python -m pytest tests/documents/test_document_deduplication.py -q`

  Run again: `python -m pytest tests/documents/test_document_deduplication.py -q`

  Expected: both runs pass with identical golden fingerprints.

- [ ] **Step 5: Commit deterministic deduplication**

  ```bash
  git add app/services/document_deduplication_service.py tests/documents/test_document_deduplication.py
  git commit -m "feat: add deterministic document deduplication"
  ```

## Task 4: Document access and derived-rights policy

**Files:**
- Create: `app/policies/document_access.py`
- Create: `tests/security/test_document_access_policy.py`
- Create: `tests/security/test_document_rights_leakage.py`
- Modify: `app/policies/__init__.py`
- Tests: the two files above

**Interfaces:**
- Consumes: `ResearchAccessContext`, Document rights/state/provider fields, and distribution status.
- Produces: immutable `DocumentAccessDecision(visible: bool, metadata_fields: frozenset[str], may_contribute_to_aggregate: bool)`, `DocumentAccessPolicy.evaluate(document: Document, context: ResearchAccessContext) -> DocumentAccessDecision`, and `DocumentAccessPolicy.project(document: Document, decision: DocumentAccessDecision) -> dict[str, object]`.

- [ ] **Step 1: Write failing rights matrix and sentinel tests**

  Cover free, premium, administrator, provider, and unrelated-user contexts across `source_access` values `PUBLIC`, `RESTRICTED`, and `UNKNOWN`, and across `distribution_status` values `UNKNOWN`, `LINK_ONLY`, `PRIVATE_LIBRARY`, and `APP_DISTRIBUTABLE`. Prove public does not imply distributable; premium never unlocks restricted/private; provider/admin can manage private metadata; admin research access does not make content distributable; LINK_ONLY returns official link metadata but no storage reference; every projection excludes `storage_key`; archived/private inaccessible records return `visible=False`; and restricted contributions cannot influence exposed counts, ranges, or differences.

- [ ] **Step 2: Run tests to verify missing policy**

  Run: `python -m pytest tests/security/test_document_access_policy.py tests/security/test_document_rights_leakage.py -q`

  Expected: FAIL importing `DocumentAccessPolicy`.

- [ ] **Step 3: Implement explicit rights decisions and projections**

  Use allowlisted fields per decision; never dump the ORM object directly. `may_contribute_to_aggregate` is true for consumer aggregation only when independently APP_DISTRIBUTABLE, and for private provider/admin views only when the aggregate itself remains inside that same private context. Return no count for filtered-out records. The policy does not accept a product tier as a rights override.

- [ ] **Step 4: Run rights and entitlement isolation tests**

  Run: `python -m pytest tests/security/test_document_access_policy.py tests/security/test_document_rights_leakage.py tests/security/test_research_data_isolation.py -q`

  Expected: all tests pass; no private sentinel appears in an unrelated premium projection.

- [ ] **Step 5: Commit document rights policy**

  ```bash
  git add app/policies/__init__.py app/policies/document_access.py tests/security/test_document_access_policy.py tests/security/test_document_rights_leakage.py
  git commit -m "feat: enforce document distribution rights"
  ```

## Task 5: Atomic initial document aggregate creation

**Files:**
- Create: `app/services/document_library_service.py`
- Create: `tests/documents/test_document_create_service.py`
- Modify: none

**Interfaces:**
- Consumes: Tasks 1–4 models, validation, deduplication, and rights types.
- Produces: `DocumentLibraryService.create_document(payload: dict, actor_user_id: str) -> Document`, `DocumentLibraryService.create_institution(payload: dict, actor_user_id: str) -> Institution`, and `DocumentLibraryService.update_institution(institution_id: str, changes: dict, actor_user_id: str) -> Institution`.

- [ ] **Step 1: Write failing aggregate transaction tests**

  Test normalized unique institution creation/correction plus ordinary single-company creation, zero-primary multi-company/industry creation, required institutional metadata/company link, final fingerprint using all sorted links, exact and metadata duplicate conflicts, concurrent identical creation, default rights, invalid company rollback, missing institution rollback, and injected failure after each insert stage. After every failure assert zero Document, link, metadata, and audit rows.

- [ ] **Step 2: Run tests to verify missing service**

  Run: `python -m pytest tests/documents/test_document_create_service.py -q`

  Expected: FAIL importing `DocumentLibraryService`.

- [ ] **Step 3: Implement one complete creation transaction**

  Implement institution commands with normalized-name uniqueness, correction-only updates, and one transaction. For documents, validate and normalize the whole request before adding rows. Resolve every Company and conditional Institution, compute the final fingerprint, then within one transaction rerun duplicate lookup, insert Document with non-null fingerprint, insert all links, insert institutional metadata when required, and commit once. Catch the unique fingerprint race and raise `ResearchConflictError("document_duplicate", "Document requires duplicate review")` after rollback. Do not emit a creation audit event because the approved audit model targets meaningful state changes.

- [ ] **Step 4: Run create, deduplication, validation, and rights tests**

  Run: `python -m pytest tests/documents/test_document_create_service.py tests/documents/test_document_deduplication.py tests/documents/test_document_validation.py tests/security/test_document_access_policy.py -q`

  Expected: all tests pass and no incomplete document becomes query-visible.

- [ ] **Step 5: Commit aggregate creation**

  ```bash
  git add app/services/document_library_service.py tests/documents/test_document_create_service.py
  git commit -m "feat: create document aggregates atomically"
  ```

## Task 6: Atomic company-link addition and fingerprint recomputation

**Files:**
- Create: `tests/documents/test_document_company_links.py`
- Modify: `app/services/document_library_service.py`
- Tests: `tests/documents/test_document_company_links.py`

**Interfaces:**
- Consumes: Task 5 service and fingerprint interface.
- Produces: `DocumentLibraryService.add_company_link(document_id: str, company_id: str, is_primary: bool, actor_user_id: str, reason: str) -> Document`.

- [ ] **Step 1: Write failing link-change transaction tests**

  Assert the method loads the complete existing link set, rejects duplicate links/two primaries, accepts a zero-primary multi-company result, recomputes fingerprint from sorted final IDs, ignores link order/primary in hashing, preserves all rights fields byte-for-byte, writes one `COMPANY_LINKS_CHANGED` event with sorted old/new IDs, primary IDs, and fingerprints, and rolls back link/fingerprint/audit on duplicate conflict or injected failure.

- [ ] **Step 2: Run tests to verify missing method**

  Run: `python -m pytest tests/documents/test_document_company_links.py -q`

  Expected: FAIL because `add_company_link` is absent.

- [ ] **Step 3: Implement locked recomputation transaction**

  Lock the Document and its links, build the proposed set without mutation, validate zero-or-one primary, compute the proposed fingerprint, run duplicate checks, then add the link, set the fingerprint, append the audit event, and commit once. Use `field_changed="company_links"`; old/new JSON contains no title, source reference, storage data, or content.

- [ ] **Step 4: Run link and create tests**

  Run: `python -m pytest tests/documents/test_document_company_links.py tests/documents/test_document_create_service.py -q`

  Expected: all tests pass; conflict cases preserve the previous rights and fingerprint.

- [ ] **Step 5: Commit link recomputation**

  ```bash
  git add app/services/document_library_service.py tests/documents/test_document_company_links.py
  git commit -m "feat: recompute document fingerprints on company links"
  ```

## Task 7: Audited document metadata, state, rights, and archival changes

**Files:**
- Create: `tests/documents/test_document_updates_and_audit.py`
- Modify: `app/services/document_library_service.py`
- Tests: `tests/documents/test_document_updates_and_audit.py`

**Interfaces:**
- Consumes: `DocumentPatchSchema`, validation service, deduplication service, and `DocumentAuditEvent`.
- Produces: `DocumentLibraryService.update_document(document_id: str, changes: dict, actor_user_id: str, reason: str | None) -> Document`.

- [ ] **Step 1: Write failing update/audit tests**

  Cover source access, acquisition, distribution, ingestion, rights verification/revocation, storage attachment metadata, canonical fingerprint input corrections, archive/restore, and noncanonical metadata changes. Assert required reasons, allowed state transitions, STORED-to-ANALYSED rejection, fingerprint recomputation only for canonical inputs, duplicate rollback, correct event types/field/old/new/actor/reason, append-only audit rows, and no audit secrets or file content.

- [ ] **Step 2: Run tests to verify missing update method**

  Run: `python -m pytest tests/documents/test_document_updates_and_audit.py -q`

  Expected: FAIL because `update_document` is absent.

- [ ] **Step 3: Implement validated audited changes**

  Lock the Document, validate the complete resulting state, recompute/deduplicate before applying canonical changes, then update current fields and append one focused audit row per meaningful changed field in the same transaction. Analyst, discovery, access, storage, and rights changes never alter the fingerprint. Any exception rolls back current-state changes and audit rows.

- [ ] **Step 4: Run update and rights suites**

  Run: `python -m pytest tests/documents/test_document_updates_and_audit.py tests/security/test_document_access_policy.py tests/security/test_document_rights_leakage.py -q`

  Expected: all tests pass; audit immutability and non-leakage assertions pass.

- [ ] **Step 5: Commit audited document changes**

  ```bash
  git add app/services/document_library_service.py tests/documents/test_document_updates_and_audit.py
  git commit -m "feat: audit document state and rights changes"
  ```

## Task 8: Rights-safe document and institutional queries

**Files:**
- Create: `tests/documents/test_document_queries.py`
- Modify: `app/services/document_library_service.py`
- Tests: `tests/documents/test_document_queries.py`

**Interfaces:**
- Consumes: `PageResult`, `DocumentAccessPolicy`, and document relationships.
- Produces: `DocumentLibraryService.get_document(document_id: str, context: ResearchAccessContext) -> dict[str, object]`, `list_company_documents(company_id: str, filters: dict, page: int, per_page: int, context: ResearchAccessContext) -> PageResult`, and `list_institutional_reports(company_id: str, *, latest_per_institution: bool, page: int, per_page: int, context: ResearchAccessContext) -> PageResult`.

- [ ] **Step 1: Write failing query and history tests**

  Test type/institution/report-type/date filters, deterministic newest ordering, rights filtering before counts/pagination, non-revealing inaccessible lookup, latest-per-institution selection without deleting/hiding older paginated history, multiple reports per institution, official source preference with Telegram retained only as discovery metadata, and complete absence of `storage_key` and restricted hashes/private references.

- [ ] **Step 2: Run tests to verify missing query methods**

  Run: `python -m pytest tests/documents/test_document_queries.py -q`

  Expected: FAIL because the query methods are absent.

- [ ] **Step 3: Implement policy-first filtered queries**

  Apply candidate rights predicates before totals where expressible in SQL, then evaluate any remaining ownership condition before serialization. Return only explicit policy projections. `latest_per_institution` uses a window/subquery keyed by institution and report date/created-at/ID; the ordinary history path remains available.

- [ ] **Step 4: Run all document and security tests**

  Run: `python -m pytest tests/documents tests/security/test_document_access_policy.py tests/security/test_document_rights_leakage.py tests/security/test_research_data_isolation.py -q`

  Expected: all tests pass; unauthorized rows contribute neither values nor counts.

- [ ] **Step 5: Commit document queries**

  ```bash
  git add app/services/document_library_service.py tests/documents/test_document_queries.py
  git commit -m "feat: add rights-safe document queries"
  ```

## Completion gate

All eight task groups pass. Initial creation and link changes are atomic, canonical fingerprints are deterministic, rights never widen through entitlement or deduplication, private resources are non-enumerable, storage keys never leave the service boundary, audit rows are append-only and atomic, and no analysis/file-ingestion feature or legacy-system change exists.
