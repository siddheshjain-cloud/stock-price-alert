# Investment Operating System Milestone 1 — Research Brain Pilot — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Feature:** Investment Operating System Milestone 1 — Research Brain Pilot (Document → Extraction → Evidence → Facts → Research View)

**Goal:** Implement the smallest working version of the approved pilot design: four small additive tables, one service owning the extraction/evidence/fact write path and the `get_company_facts` read path, and one real run against IKIO's (and, as a portability check, UNO Minda's) already-ingested Q1 FY2027 document set.

**Architecture:** Four new SQLAlchemy models (`ExtractionRun`, `Evidence`, `ExtractedFact`, `FactEvidence`) following the exact immutability discipline already used by `OwnershipSnapshot`/`ResearchRevision` (`before_update`/`before_delete` event listeners rejecting mutation). `ResearchBrainService` owns the write path (`create_extraction_run`, `record_evidence`, `record_fact`) and the read path (`get_company_facts`), mirroring `DocumentLibraryService`'s existing read/write split. A new, separate Alembic migration adds the four tables; it does **not** modify `migrations/m1_table_inventory.py`'s frozen `M1_TABLES` set or the `20260904_02` revision — this is new, independently-additive scope, not a reopening of frozen M1.

**Tech Stack:** Python 3.12, Flask-SQLAlchemy 3.0.5, SQLAlchemy 2.0, Alembic, pytest 8.3.5 — identical to the rest of the backend; no new runtime dependency.

**Spec:** `2026-10-06-investment-operating-system-m1-research-brain-pilot.md` (as amended by the follow-up commit adding `as_of_date`, `value_type`, and the test-DB-only contradiction test).

## Global Constraints

- Run implementation and test commands from `backendtest`.
- Additive only: do not modify `Document`, `Company`, `Ticker`, `ResearchRevision`, `OwnershipSnapshot`, `GovernanceFlag`, or any other existing model or table.
- Do not modify `migrations/m1_table_inventory.py`'s `M1_TABLES` frozenset or the `20260904_02` migration. The four new tables get their own migration revision and their own separate, analogous table-inventory constant.
- Do not change `Document.ingestion_status` or any of its allowed transitions. `DocumentValidationService` continues to forbid reaching `ANALYSED`; this plan does not touch that rule.
- No OCR, no ML/NLP extraction, no forecasting, no valuation, no UI, no Cycle/Theme/Causal Intelligence. Extraction is manual/semi-manual by design.
- No synthetic/false fact is ever inserted into the real `instance/trading_app.db`. The contradiction/supersession behavior is proven only against a disposable test database/fixture; the real database only ever receives facts the pilot run actually believes.
- Scope is exactly IKIO (primary) + UNO Minda (portability check only) — no other company.

---

## Task 1: Research Brain models

**Files:**
- Create: `app/models/research_brain.py`
- Create: `tests/research/test_research_brain_models.py`
- Modify: `app/models/__init__.py`

**Interfaces:**
- Consumes: `BaseModel`, `Document.id`, `Company.id`, `User.id`.
- Produces: `ExtractionRun`, `Evidence`, `ExtractedFact`, `FactEvidence`.

- [ ] **Step 1: Write failing model tests**

  Cover: each model's required/nullable fields exactly as specified in the design proposal (including `ExtractedFact.as_of_date` distinct from `created_at`, and `value_type` as a two-value enum `NUMERIC`/`TEXT` with `unit` meaningful only for `NUMERIC`); `FactEvidence`'s composite PK (`fact_id`, `evidence_id`) allowing one fact to link multiple evidence rows and one evidence row to back multiple facts; `ExtractedFact.supersedes_fact_id` self-referential FK; immutability (`before_update`/`before_delete` raise `InvalidRequestError`) on all four models, mirroring `OwnershipSnapshot`'s existing test pattern in `tests/research/test_ownership_snapshots.py`.

- [ ] **Step 2: Run tests to verify missing models**

  Run: `python -m pytest tests/research/test_research_brain_models.py -q`

  Expected: FAIL importing `ExtractionRun`/`Evidence`/`ExtractedFact`/`FactEvidence`.

- [ ] **Step 3: Implement the models**

  Map `ExtractionRun(id, document_id, method, extracted_by_user_id, created_at)`; `Evidence(id, extraction_run_id, document_id, text_snippet, locator, created_by_user_id, created_at)`; `ExtractedFact(id, company_id, fact_type, value_type, value, unit, period, as_of_date, supersedes_fact_id, created_by_user_id, created_at)`; `FactEvidence(fact_id, evidence_id, created_at)` with composite PK, same shape as `DocumentCompanyLink`. Use `enum_type(...)` for `value_type` exactly as `research_types.py`'s helper is already used elsewhere. Attach `before_update`/`before_delete` immutability listeners to all four, exactly as `app/models/ownership.py` and `app/models/research.py` already do. Register all four in `app/models/__init__.py`.

- [ ] **Step 4: Run tests to verify models pass**

  Run: `python -m pytest tests/research/test_research_brain_models.py -q`

  Expected: PASS.

---

## Task 2: Additive migration for the four new tables

**Files:**
- Create: `migrations/research_brain_pilot_table_inventory.py`
- Create: `migrations/versions/<next_revision>_research_brain_pilot.py`
- Create: `tests/migrations/test_research_brain_pilot_migration.py`

**Interfaces:**
- Consumes: `app.models` (registers the four new tables' metadata), `migrations/m1_table_inventory.py` (read-only — to assert this migration does not touch it).
- Produces: the four live tables in the real schema; a new frozen 4-table inventory constant analogous to `M1_TABLES`.

- [ ] **Step 1: Write failing migration test**

  Mirror `tests/migrations/test_m1_additive_migration.py`'s pattern: build a fresh database at the prior head (`20260904_02`), upgrade to the new revision, and assert exactly the four new tables appear (via `scripts/inspect_database_schema.inspect_schema`) with no changes to any of the frozen 20 `M1_TABLES` tables' columns/constraints. Assert downgrade removes exactly the four new tables and nothing else.

- [ ] **Step 2: Run test to verify missing revision**

  Run: `python -m pytest tests/migrations/test_research_brain_pilot_migration.py -q`

  Expected: FAIL — revision does not exist.

- [ ] **Step 3: Implement the inventory constant and migration**

  `migrations/research_brain_pilot_table_inventory.py` defines `RESEARCH_BRAIN_PILOT_TABLES: frozenset[str] = frozenset({"extraction_run", "evidence", "extracted_fact", "fact_evidence"})`, following `m1_table_inventory.py`'s exact docstring/structure convention, explicit about why this is a separate constant from `M1_TABLES` rather than an edit to it. The new migration revision chains `down_revision = "20260904_02"`, creates exactly these four tables and their constraints/indexes, and defines a clean `downgrade()`.

- [ ] **Step 4: Run test to verify migration passes**

  Run: `python -m pytest tests/migrations/test_research_brain_pilot_migration.py -q`

  Expected: PASS.

---

## Task 3: `ResearchBrainService` write path

**Files:**
- Create: `app/services/research_brain_service.py`
- Create: `tests/research/test_research_brain_service_writes.py`

**Interfaces:**
- Consumes: the four new models (Task 1), `scripts/spa_bridge/drive_evidence.download_and_hash` (reused, not reimplemented) for later real-document use in Task 5 — not required by this task's own tests, which use the test database only.
- Produces: `ResearchBrainService.create_extraction_run(document_id, method, extracted_by_user_id)`, `record_evidence(extraction_run_id, document_id, text_snippet, locator, created_by_user_id)`, `record_fact(company_id, fact_type, value_type, value, unit, period, as_of_date, evidence_ids, created_by_user_id, supersedes_fact_id=None)`.

- [ ] **Step 1: Write failing service tests**

  Cover: creating an extraction run and evidence rows against a seeded test document; recording a fact with multiple `evidence_ids` (asserting the resulting `FactEvidence` rows — the cross-document-corroboration shape); recording a fact with `supersedes_fact_id` pointing at a prior fact and asserting both rows persist unmodified (no update, no delete — this is the append-only path tested at the service layer, independent of Task 4's read-side contradiction test). All against a disposable test database/fixture, never the real one.

- [ ] **Step 2: Run tests to verify missing service**

  Run: `python -m pytest tests/research/test_research_brain_service_writes.py -q`

  Expected: FAIL — `ResearchBrainService` does not exist.

- [ ] **Step 3: Implement the write path**

  Each method does one atomic commit (one `db.session.add()`/`flush()`/`commit()` per call), matching `DocumentLibraryService.create_document`'s transactional shape. `record_fact` inserts the `ExtractedFact` row, then one `FactEvidence` row per id in `evidence_ids`, in the same transaction — a fact with no evidence at all is rejected (every fact must cite at least one evidence row; this is the mechanism's core discipline, not an optional nicety).

- [ ] **Step 4: Run tests to verify write path passes**

  Run: `python -m pytest tests/research/test_research_brain_service_writes.py -q`

  Expected: PASS.

---

## Task 4: `ResearchBrainService` read path and contradiction-acceptance test

**Files:**
- Create: `tests/research/test_research_brain_service_reads.py`
- Modify: `app/services/research_brain_service.py`

**Interfaces:**
- Consumes: the write path (Task 3) to seed fixtures within each test.
- Produces: `ResearchBrainService.get_company_facts(company_id)`.

- [ ] **Step 1: Write failing read tests**

  Cover: `get_company_facts` returns, for each `(fact_type, period)`, only the current (non-superseded) `ExtractedFact`, each with every linked `Evidence` row and its originating `Document`. Include the proposal's contradiction-acceptance success criterion exactly as amended: seed a fact, seed a second fact for the same `(company_id, fact_type, period)` with `supersedes_fact_id` pointing at the first, assert `get_company_facts` returns only the second, and separately assert the first row is still readable directly by id (proving supersession, not deletion). This entire test runs against the test database/fixture only.

- [ ] **Step 2: Run tests to verify missing method**

  Run: `python -m pytest tests/research/test_research_brain_service_reads.py -q`

  Expected: FAIL — `get_company_facts` does not exist.

- [ ] **Step 3: Implement the read path**

  `get_company_facts` groups by `(fact_type, period)`, picks the row never referenced by another row's `supersedes_fact_id` as current (same "latest revision" lookup shape used elsewhere in M1), and eager-loads each current fact's `FactEvidence` → `Evidence` → `Document` chain so the result needs no further queries to be fully sourced.

- [ ] **Step 4: Run tests to verify read path passes**

  Run: `python -m pytest tests/research/test_research_brain_service_reads.py -q`

  Expected: PASS.

---

## Task 5: Real pilot run — IKIO primary, UNO Minda portability check

**Files:**
- Create: `scripts/research_brain_pilot_run.py` (one-off, reviewable script — not a permanent service entrypoint)

**Interfaces:**
- Consumes: `ResearchBrainService` (Task 3/4), `scripts/spa_bridge/drive_evidence.download_and_hash` (reused, read-only).
- Produces: real `ExtractionRun`/`Evidence`/`ExtractedFact`/`FactEvidence` rows in `instance/trading_app.db` for IKIO (and, separately, UNO Minda).

- [ ] **Step 1: Extract manually from IKIO's three Q1 FY2027 documents**

  Download each of `IKIO_RESULTS_Q1_FY2027`, `IKIO_CONCALL_14_08_2026`, `IKIO_PRESENTATION_Q1_FY2027` via the existing read-only Drive path; manually read the text (no OCR/NLP); for each, call `create_extraction_run` + `record_evidence` for the specific passage(s) used.

- [ ] **Step 2: Record and corroborate one real fact**

  Call `record_fact` for one real numeric metric (e.g. quarterly revenue) found in the Quarterly Results document, with `evidence_ids` including a second `Evidence` row from the Concall or Investor Presentation that independently states or confirms the same figure — this is success criterion 1 and 2 from the design proposal, proven for real, not just in a test fixture.

- [ ] **Step 3: Verify via the Research View**

  Run `ResearchBrainService.get_company_facts(ikio_company_id)` and confirm the fact and its evidence/document chain are returned correctly — success criterion 4.

- [ ] **Step 4: Portability check — UNO Minda**

  Repeat steps 1–2 once, minimally, for UNO Minda's equivalent Q1 FY2027 triple, with no schema or service change — success criterion 5. This step does not need to repeat the full corroboration depth of IKIO; one real fact with one piece of evidence is sufficient to prove portability.

- [ ] **Step 5: Verify no state outside scope changed**

  Confirm `PRAGMA integrity_check` = `ok`; `document`, `company`, `ticker` row counts unchanged from the post-backfill baseline (1,246 / 69 / 69); only the four new tables gained rows.

---

## Task 6: `ExtractionUnit` persistence layer (amendment, 2026-10-07)

**Files:**
- Create: `app/models/research_brain.py` (modify — add `ExtractionUnit`)
- Modify: `app/models/__init__.py`
- Create: `migrations/research_brain_extraction_unit_table_inventory.py`
- Create: `migrations/versions/<next_revision>_research_brain_extraction_unit.py`
- Create: `tests/migrations/test_research_brain_extraction_unit_migration.py`
- Create: `tests/research/test_research_brain_extraction_unit_models.py`
- Modify: `app/services/research_brain_service.py`
- Create: `tests/research/test_research_brain_extraction_unit_service.py`

**Interfaces:**
- Consumes: `ExtractionRun` (reused unchanged), `Document.id`.
- Produces: `ExtractionUnit`; `Evidence.source_extraction_unit_id` (new nullable column); `ResearchBrainService.record_extraction_unit(...)`, `get_extraction_units(document_id)`; `record_evidence(..., source_extraction_unit_id=None)`.

- [ ] **Step 1: Write failing model tests**

  Cover `ExtractionUnit`'s exact columns (including `content_text` as unbounded `Text`, not `String(4000)`); `unit_type` enum `PAGE`/`SECTION`/`TABLE`; `UniqueConstraint(extraction_run_id, unit_type, sequence_number)`; immutability (`before_update`/`before_delete` raise `InvalidRequestError`, same as the other three models); and the key reprocessing behavior explicitly: two separate `ExtractionRun`s against the *same* `document_id` may each own their own `ExtractionUnit` rows with the *same* `(unit_type, sequence_number)` (e.g. two different PAGE-1 extractions, one per run) without violating any constraint — reprocessing is never blocked by the schema, only skipped by choice at the service/script layer.

- [ ] **Step 2: Run tests to verify missing model** — `python -m pytest tests/research/test_research_brain_extraction_unit_models.py -q`, expect FAIL (`ExtractionUnit` does not exist).

- [ ] **Step 3: Implement `ExtractionUnit`** in `app/models/research_brain.py`, register in `app/models/__init__.py`, add the `before_update`/`before_delete` listeners alongside the other three immutable models.

- [ ] **Step 4: Run tests to verify model passes.**

- [ ] **Step 5: Write failing migration test**, mirroring `tests/migrations/test_research_brain_pilot_migration.py`'s pattern exactly: fresh DB at `20261006_01` → upgrade to the new revision → assert exactly the one new table appears, `evidence` gains exactly the one new nullable column, and every other already-frozen table (`M1_TABLES` *and* the three other Research Brain Pilot tables) is byte-for-byte unchanged. Assert downgrade reverses both changes cleanly.

- [ ] **Step 6: Run migration test to verify it fails, then implement** the new inventory constant + migration revision (chained after `20261006_01`, not reopening it) using the same `db.metadata.create_all(..., checkfirst=True)` pattern; add the nullable column to `evidence` via `op.add_column`. Run the test again to confirm PASS.

- [ ] **Step 7: Write failing service tests** for `record_extraction_unit`, `get_extraction_units` (empty-vs-non-empty as the "already processed" signal), and `record_evidence`'s new optional parameter (defaulting to `None`, existing call sites/tests from Tasks 3–4 continue to pass unmodified). Include one test proving a second `record_extraction_unit` call under a *different* `extraction_run_id` for the same document is accepted (reprocessing), and one proving a duplicate `(extraction_run_id, unit_type, sequence_number)` is rejected at the database (not reprocessing — a genuine duplicate within one pass).

- [ ] **Step 8: Run tests to verify missing methods, then implement.** Same one-atomic-commit-per-call shape as the existing write methods.

- [ ] **Step 9: Run the full suite** (`tests/research/`, `tests/documents/`, `tests/migrations/`, then the complete repo suite) to confirm no regression, the same discipline Tasks 1–4 followed.

**Explicitly not in Task 6's scope:** processing any of the 87 Snapshot-A documents or the 7 held disclosures through this new layer. That is Snapshot B's job, gated on its own separate authorization — Task 6 only builds and tests the mechanism, against the test database/fixtures, exactly like Tasks 1–4 did before Task 5.

---

## What this plan does not do

Does not implement OCR/ML extraction, forecasting, valuation, any UI, Cycle/Theme/Causal Intelligence, or any change to `Document.ingestion_status`. Does not modify the frozen `M1_TABLES` set, the `20260904_02` migration, or the `20261006_01` migration. Does not insert any synthetic/false fact into the real database. Does not process the 87-document Snapshot-A corpus or the 7 held disclosures. Scope is exactly the five tables, one service, the IKIO + UNO Minda pilot run, and the `ExtractionUnit` persistence layer described above — nothing else is in scope without a separate, explicitly-approved proposal.
