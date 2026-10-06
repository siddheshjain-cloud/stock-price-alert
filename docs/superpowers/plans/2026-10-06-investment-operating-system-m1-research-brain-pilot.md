STATUS: PROPOSAL — APPROVED FOR PLANNING ONLY — DOES NOT AUTHORIZE IMPLEMENTATION

# Investment Operating System Milestone 1 — Research Brain Pilot — Design Proposal

**Date:** 2026-10-06

**Provenance:** This is a new, standalone design proposal, not an implementation plan. It is inspired by — but does not inherit the approval status of — Tier 0.1 ("Research Intelligence Deepening") in `2026-09-25-spa-post-m1-master-roadmap-v2.md`, which remains its own unapproved proposal. It draws its input data from the SPA-to-M1 Document Library historical backfill completed and committed separately in `backendtest` (`feat(spa-bridge): add SPA-to-M1 Document Library bridge implementation`), which established a real corpus of 1,246 documents across 69 companies. No code or M1 state is created or modified by this document.

## Objective

Prove the smallest useful version of the Research Brain path on a handful of real, already-ingested documents:

```
Document → Extraction → Evidence → Facts → Research View
```

This is the first three links of the North-Star epistemic chain already named in the Master Roadmap V2's cross-cutting principles (`Source → Evidence → Fact → Hypothesis/Inference → Forecast → Valuation → SPA Research View`), stopping deliberately before Hypothesis/Inference, Forecast, or Valuation. The pilot's job is to prove the mechanism, not to produce research conclusions.

## Explicit non-goals

This pilot does **not** include, and any growth toward these must be a separate, later, explicitly-approved proposal:

- OCR or ML-based extraction — the pilot's extraction step may be manual or semi-manual; accuracy/automation is out of scope.
- Forecasting or valuation of any kind.
- Any UI.
- Cycle/Theme/Causal Intelligence (Tier 0.5/0.6 and beyond).
- Any change to `Document.ingestion_status` or its allowed transitions. `DocumentValidationService` currently forbids reaching `ANALYSED`; this pilot does not touch that rule and does not require it to change — the new models below are entirely additive and sit alongside `Document`, never inside it.
- Scale-up beyond the two pilot companies named below.

## What already exists and is reused as-is

- **`Document` / `DocumentCompanyLink`** (`app/models/document.py`) — identity, metadata, company linkage. The pilot reads against the existing 1,246-document corpus; nothing here is modified.
- **Read-only Drive file access** — `scripts/spa_bridge/drive_evidence.download_and_hash()`, already proven in the SPA bridge canary. Fetching a document's bytes for extraction reuses this, not a new credential or access path.
- **`DocumentLibraryService.list_company_documents()`** — the existing paginated, filterable read pattern. The new Research View read method (below) is a sibling of this, not a new kind of query surface.
- **M1's immutability/hindsight-preservation discipline** — already applied uniformly across `ResearchRevision`, `ForecastRevision`, `ValuationRevision`, and `OwnershipSnapshot`: append-only, explicit supersession rather than in-place update, no retroactive editing. The new `ExtractedFact` model (below) inherits this discipline directly rather than inventing its own.

## What is genuinely new

Three small, additive tables and one read method — nothing else.

### `ExtractionRun`
Provenance for one extraction pass over one document. Immutable.

| Field | Notes |
|---|---|
| `id` | PK |
| `document_id` | FK → `document.id` |
| `method` | e.g. `"manual_pilot"` — the pilot's extraction is manual/semi-manual by design |
| `extracted_by_user_id` | FK → user |
| `created_at` | |

### `Evidence`
One excerpt of source text, tied to exactly one extraction run and document. Immutable — never updated or deleted, matching `GovernanceFlag`'s evidence-citation discipline but as a structured, queryable row instead of a free-text field.

| Field | Notes |
|---|---|
| `id` | PK |
| `extraction_run_id` | FK → `extraction_run.id` |
| `document_id` | FK → `document.id` (denormalized for direct joins) |
| `text_snippet` | the excerpted text itself |
| `locator` | nullable — page/section, if available |
| `created_by_user_id` | |
| `created_at` | |

### `ExtractedFact`
A structured, typed data point. **Resolved design points (per explicit instruction):**

1. **Many-to-many with Evidence**, via a join table — not a single FK — because cross-document corroboration (one fact, multiple independent source documents) is a core pilot success criterion, and a single-FK design cannot represent that at all.
2. **Point-in-time semantics via explicit supersession**, not update-in-place — identical in shape to `ResearchRevision.supersedes_revision_id`. A later, contradictory reading of the same `(company_id, fact_type, period)` creates a **new** `ExtractedFact` row that names the fact it supersedes; the original row is never edited or deleted. "Current" is defined the same way M1 already defines "current revision" elsewhere: the row not referenced by any other row's `supersedes_fact_id`.
3. **`as_of_date` is distinct from `created_at`.** `created_at` is row-insert bookkeeping — when this pilot happened to record the fact. `as_of_date` is epistemic time — when the underlying information actually became knowable/applicable (e.g. the concall date, the results-announcement date, the document's own `document_date`/`original_published_at`). `period` names the business reporting period (e.g. `"Q1 FY2027"`); `as_of_date` names the specific point in time within/around that period the fact is anchored to. Point-in-time research needs to ask "what was knowable as of date X" — that question must be answerable from `as_of_date`, never from `created_at`.
4. **`value_type` lets one `value` column hold either a numeric metric or a textual/management assertion**, without a larger ontology: one discriminator field (`NUMERIC` | `TEXT`), not a family of fact-subtype tables or per-type columns. `unit` only applies when `value_type = NUMERIC`.

| Field | Notes |
|---|---|
| `id` | PK |
| `company_id` | FK → `company.id` |
| `fact_type` | e.g. `"quarterly_revenue"`, `"ebitda_margin"`, `"management_commentary"` |
| `value_type` | `NUMERIC` \| `TEXT` — the one discriminator needed to support both metrics and textual assertions |
| `value` | stored as text regardless of `value_type`; a numeric fact's literal value, or a management assertion's quoted/paraphrased text |
| `unit` | nullable; meaningful only when `value_type = NUMERIC` |
| `period` | e.g. `"Q1 FY2027"` — the business reporting period |
| `as_of_date` | when the underlying information became knowable/applicable (see above) — distinct from `created_at` |
| `supersedes_fact_id` | nullable FK → `extracted_fact.id` — append-only revision chain |
| `created_by_user_id` | |
| `created_at` | row-insert bookkeeping only, not epistemic time |

### `FactEvidence` (join table)
Composite-PK join table, same shape as the existing `DocumentCompanyLink`.

| Field | Notes |
|---|---|
| `fact_id` | FK → `extracted_fact.id`, part of composite PK |
| `evidence_id` | FK → `evidence.id`, part of composite PK |
| `created_at` | |

This is what makes cross-document corroboration representable: one `ExtractedFact` row links to N `Evidence` rows, each pointing at a different source `Document`.

### Research View (read method, not a new table)
One new read-only service method, sibling to `list_company_documents()`:

- `get_company_facts(company_id)` → for each `(fact_type, period)`, the current (non-superseded) `ExtractedFact`, together with every linked `Evidence` row and its originating `Document`. Every fact in the output is traceable to at least one real document; nothing is presented unsourced.

Not included in the pilot: a `get_fact_history()` revision-chain viewer. It falls out naturally from the same schema later if wanted, but isn't needed to prove the pilot's success criteria.

## Pilot companies and documents

Both already fully ingested by the completed M1 Document Library backfill — no new ingestion work needed.

**Primary — IKIO Technologies Limited** (also M1's original proven canary company):
- `IKIO_RESULTS_Q1_FY2027` (Quarterly Results)
- `IKIO_CONCALL_14_08_2026` (Concall transcript)
- `IKIO_PRESENTATION_Q1_FY2027` (Investor Presentation)

All three cover the same reporting period (Q1 FY2027), making them a real, cross-referenceable set for corroborating one fact across independent documents.

**Portability check only — UNO Minda Limited:**
- `UNOMINDA_RESULTS_Q1_FY2027`, `UNOMINDA_CONCALL_Q1_FY2027`, `UNOMINDA_PRESENTATION_Q1_FY2027`

UNO Minda is explicitly a portability check, not a second primary pilot — it confirms the schema and extraction approach aren't accidentally IKIO-specific, nothing more.

## Success criteria

1. At least one real figure (e.g., a specific quarterly revenue or margin number) extracted from IKIO's Q1 FY2027 Quarterly Results document, recorded as an `ExtractedFact` with a linked `Evidence` row pointing at the exact source text.
2. The same fact corroborated by a **second, independent** `Evidence` row from either IKIO's Concall or Investor Presentation for the same quarter — proving the many-to-many `FactEvidence` design, not just its schema.
3. A contradiction-acceptance test proving supersession actually works, not just that the column exists: confirm `get_company_facts()` returns only the current `ExtractedFact` for a given `(company_id, fact_type, period)` while a superseded row remains intact and queryable via its revision chain. This test runs against the test database/fixture (the same pattern already established by `tests/spa_bridge/fixtures/manifest_snapshot_2026-10-06.json`), or against genuine contradictory source evidence if the pilot documents happen to contain a real one (e.g. a provisional figure later restated) — **never** by inserting a synthetic, deliberately-false fact into the real `instance/trading_app.db` Research Brain tables. The real database only ever holds facts the pilot actually believes, even provisionally.
4. `get_company_facts('IKIO')` returns results with every fact traceable to real `Evidence` and `Document` rows.
5. The same mechanism (extraction → evidence → fact) produces at least one fact for UNO Minda without any schema or service change — the portability check.

## What this document does not do

No tables are created, no migration is written, no code is modified. Nothing in `backendtest` changes as a result of this document. This is a design proposal only, scoped for review before any implementation task is opened.
