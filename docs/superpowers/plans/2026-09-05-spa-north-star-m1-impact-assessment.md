# SPA North-Star M1 Implementation-Plan Impact Assessment

**Status:** Proposed assessment for human review

**Date:** 2026-09-05

**Assessment scope:** The existing 37-task SPA Investment Operating System M1 implementation plan

## 1. Inputs and frozen references

This assessment treats the following specifications as frozen inputs:

| Frozen input | Path | Frozen reference |
|---|---|---|
| M1 design specification | `docs/superpowers/specs/2026-09-04-investment-operating-system-milestone-1-design.md` | Last content-changing commit `994df150b369f1310797416d131eb7feea99f9ea`; reviewed in frontend repository snapshot `747c400dd44165285b251386f2230ad9d6344e1f` |
| North-Star Architecture Amendment | `docs/superpowers/specs/2026-09-05-spa-north-star-architecture-amendment-design.md` | Frozen commit `4d80219fb896816130cc4e2aad157e96d469922e` |

The assessed implementation-plan documents are:

| Plan | Path | Last content-changing commit | Task count |
|---|---|---|---:|
| Plan 1 | `docs/superpowers/plans/2026-09-04-investment-operating-system-m1-foundation-test-migration.md` | `747c400dd44165285b251386f2230ad9d6344e1f` | 6 |
| Plan 2 | `docs/superpowers/plans/2026-09-04-investment-operating-system-m1-core-research-domain.md` | `fd2357e062893ab1a994a42eebdb410ee47329d1` | 9 |
| Plan 3 | `docs/superpowers/plans/2026-09-04-investment-operating-system-m1-entitlement-query-projection.md` | `fd2357e062893ab1a994a42eebdb410ee47329d1` | 6 |
| Plan 4 | `docs/superpowers/plans/2026-09-04-investment-operating-system-m1-document-library-rights-deduplication.md` | `fd2357e062893ab1a994a42eebdb410ee47329d1` | 8 |
| Plan 5 | `docs/superpowers/plans/2026-09-04-investment-operating-system-m1-api-seed-regression.md` | `747c400dd44165285b251386f2230ad9d6344e1f` | 8 |
| Plan index | `docs/superpowers/plans/2026-09-04-investment-operating-system-milestone-1-index.md` | `747c400dd44165285b251386f2230ad9d6344e1f` | Declares 37 |

The assessment was performed with the frontend at `4d80219fb896816130cc4e2aad157e96d469922e` before this document was created and the backend foundation at `4fc28d0d6712a6d939c3352e54e98ead643b8508`. Both repositories were clean, on `feature/investment-operating-system-m1`, and synchronized with their origin feature branches.

This document assesses plan wording. It does not amend either frozen specification, change an existing plan, authorize implementation, or begin Plan 2.

## 2. Executive result

- `NO CHANGE`: 35
- `WORDING/SEMANTIC CLARIFICATION ONLY`: 2
- `SMALL COMPATIBILITY CHANGE`: 0
- `MATERIAL DESIGN CONFLICT`: 0
- **Total:** 37

The frozen M1 implementation shape is compatible with the North-Star Architecture Amendment. Two Plan 2 tasks would benefit from precise semantic wording so an implementer does not mistake bounded M1 fields for permanent universal identities or invent point-in-time fields that the frozen design does not contain.

No future subsystem requires an M1 implementation change. Stable Company identity, immutable revision history, additive migration discipline, extensible slugs where already approved, provenance, rights isolation, and separation from legacy/live paths preserve the required seams.

## 3. Task-by-task matrix

| Plan | Task | Task title | Classification | North-Star seam | Reason | Required plan edit |
|---|---:|---|---|---|---|---|
| Plan 1 | 1 | Isolated pytest harness | NO CHANGE | M1 scope and isolation | Establishes disposable test infrastructure only; it creates no research identity or future-domain assumption. | None |
| Plan 1 | 2 | Authentication, user, and ticker contract characterization | NO CHANGE | Legacy non-interference; India-first fixtures | The NSE/IKIO ticker fixture characterizes existing M1 behavior and does not declare NSE or Ticker universal. | None |
| Plan 1 | 3 | Trade, tag, Telegram, and live-pipeline characterization | NO CHANGE | Research/market separation | Locks existing live behavior and prevents research services from entering trade, Kite, websocket, or Telegram paths. | None |
| Plan 1 | 4 | Read-only database inventory utility | NO CHANGE | Provenance and migration safety | Inspects schema metadata without adding research semantics or contacting an active database in automated work. | None |
| Plan 1 | 5 | Legacy Alembic baseline and fresh-database proof | NO CHANGE | Institutional history and additive evolution | Captures only the exact legacy schema and explicitly excludes Investment Operating System tables. | None |
| Plan 1 | 6 | Existing-schema stamp rehearsal and additive safety gate | NO CHANGE | Human governance and immutable legacy state | Requires evidence, drift review, backup, and human approval; it does not broaden M1. | None |
| Plan 2 | 1 | Shared research classifications, numeric helpers, and domain errors | NO CHANGE | India-first/global-ready; entitlements | Closed values are explicitly M1 classifications. Extensible metric/unit slugs and `product_code` leave later evolution possible without adding Global now. | None |
| Plan 2 | 2 | Business group and company identity | WORDING/SEMANTIC CLARIFICATION ONLY | Company/Ticker/ISIN | The required unique Ticker and ISIN behavior is correct for M1, but the task does not state that ISIN is the bounded identity of the primary listed equity rather than the permanent universal issuer identifier. | Add the exact wording in Section 5.1; no behavior change. |
| Plan 2 | 3 | One-row user entitlement persistence | NO CHANGE | Entitlement evolution; SPA Legacy separation | The M1 FREE/PREMIUM model is bounded by product code, permits other products, and creates no permanent global taxonomy or private-client model. | None |
| Plan 2 | 4 | Narrative research revisions and concurrency primitive | WORDING/SEMANTIC CLARIFICATION ONLY | Authoritative ResearchRevision; point-in-time semantics | Immutability and exact frozen fields are enforced, but the task should explicitly prevent confidence/evidence-cutoff fields or reinterpretation of `effective_at`/`created_at`. | Add the exact wording in Section 5.2; no behavior change. |
| Plan 2 | 5 | Ownership snapshots | NO CHANGE | Ownership/Smart Capital | Implements only sourced, dated, append-only company-level promoter aggregates and makes no universal actor-model claim. | None |
| Plan 2 | 6 | Governance flags and manually curated disclosures | NO CHANGE | Fact/inference; global compatibility | Separates `factual_evidence` from `interpretation` and uses an extensible disclosure event slug rather than a Reg. 30-only enum. | None |
| Plan 2 | 7 | Market-plan revision stream | NO CHANGE | India-first/global-ready; institutional memory | INR is an explicit M1 value, while immutable revision semantics preserve history. No universal-currency claim is made. | None |
| Plan 2 | 8 | Forecast revisions with administrator-supplied EPS | NO CHANGE | Institutional memory; epistemic separation | Stores immutable administrator-supplied forecasts without treating calculated or model output as fact. INR is scoped to M1. | None |
| Plan 2 | 9 | Method-neutral valuation revisions and reference lines | NO CHANGE | Epistemic separation; institutional memory | Preserves immutable assumptions and conclusions, supports extensible metrics, and performs no valuation calculation or future-engine work. | None |
| Plan 3 | 1 | Entitlement resolution and research access policy | NO CHANGE | Entitlement evolution | Resolves the exact M1 FREE/PREMIUM policy from the database. It neither defines Premium Global nor mixes client mandates into research access. | None |
| Plan 3 | 2 | Explicit response schemas and leakage-safe presenter | NO CHANGE | Research/portfolio/client separation | Presents the common M1 Research View by entitlement and contains no portfolio or client recommendation semantics. | None |
| Plan 3 | 3 | Read-only market price boundary | NO CHANGE | Ticker as M1 price bridge | Treats Ticker as a read-only current-price source and does not elevate it into the permanent research root. | None |
| Plan 3 | 4 | Company list and current-detail query service | NO CHANGE | Company as bounded M1 entity | Queries M1 Company and current revisions without claiming Company is the universal multi-asset root. | None |
| Plan 3 | 5 | Disclosure collections and immutable history queries | NO CHANGE | Point-in-time semantics; India-first disclosures | Uses stored event dates and creation time only for their approved query/tie-break meanings; it does not treat either as publication or evidence cutoff. | None |
| Plan 3 | 6 | Entitlement and projection security matrix | NO CHANGE | Security and entitlement separation | Verifies only the approved M1 tiers and prevents leakage. It creates no broader product taxonomy. | None |
| Plan 4 | 1 | Document, institution, link, metadata, and audit models | NO CHANGE | Documents/provenance; point-in-time semantics | Implements only frozen fields. `document_date`, discovery source metadata, ingestion state, and audit timestamps remain distinct and no missing timestamp is fabricated. | None |
| Plan 4 | 2 | Document request schemas and state validation | NO CHANGE | Provenance and rights | Validates access, acquisition, distribution, and ingestion as separate dimensions without adding publication/discovery/ingestion timestamp columns. | None |
| Plan 4 | 3 | Generic deterministic fingerprint and duplicate decisions | NO CHANGE | Stable identity and portability | Uses `document_date` only as its frozen canonical fingerprint input and supports generic document types; it adds no temporal inference. | None |
| Plan 4 | 4 | Document access and derived-rights policy | NO CHANGE | Research integrity; commercial independence | Keeps product entitlement independent from document rights and prevents commercial tier from determining research evidence access. | None |
| Plan 4 | 5 | Atomic initial document aggregate creation | NO CHANGE | Provenance and institutional memory | Preserves complete source/link metadata atomically and introduces no Event-Causality or future-domain object. | None |
| Plan 4 | 6 | Atomic company-link addition and fingerprint recomputation | NO CHANGE | Stable future relationships | Supports multi-company document relationships through stable Company IDs without adding a graph, Security, Listing, or Theme model. | None |
| Plan 4 | 7 | Audited document metadata, state, rights, and archival changes | NO CHANGE | Auditability and human governance | Records meaningful changes append-only and retains current operational state without rewriting audit history. | None |
| Plan 4 | 8 | Rights-safe document and institutional queries | NO CHANGE | Provenance, rights, and institutional memory | Retains report history and rights-safe projections; it performs no institutional-analysis, Smart Capital, or causality work. | None |
| Plan 5 | 1 | Additive Milestone 1 migration and two-path migration tests | NO CHANGE | No speculative schema; additive evolution | The exact new-table allowlist contains only frozen M1 entities and explicitly excludes all North-Star future systems. | None |
| Plan 5 | 2 | Research error mapping and blueprint registration | NO CHANGE | M1 scope isolation | Registers only frozen M1 boundaries and preserves legacy behavior. | None |
| Plan 5 | 3 | Administrative company, entitlement, fact, and institution APIs | NO CHANGE | Fact/inference; SPA Legacy separation | Exposes only approved common-research facts and entitlement administration; no tenant, mandate, portfolio, or client recommendation appears. | None |
| Plan 5 | 4 | Administrative immutable revision APIs | NO CHANGE | Authoritative revision history | Creates only immutable stored revisions through service transactions; it contains no AI regeneration or mutable historical-view path. | None |
| Plan 5 | 5 | Consumer research, disclosures, and history APIs | NO CHANGE | Authoritative Research View; India-first disclosure | Projects stored M1 revisions and explicitly scoped Reg. 30 queries without adding global adapters or temporal fields. | None |
| Plan 5 | 6 | Administrative and consumer document APIs | NO CHANGE | Provenance and rights | Exposes only frozen document metadata and rights behavior; no file analysis, Event Causality, or new timestamp behavior is introduced. | None |
| Plan 5 | 7 | Idempotent source-backed IKIO seed command | NO CHANGE | India-first operation; fact/inference | The NSE/IKIO seed is an explicit sourced M1 demonstration and refuses unsourced narrative; it makes no global architectural claim. | None |
| Plan 5 | 8 | Full regression, architecture boundary, and release verification | NO CHANGE | All scope-preservation seams | Enforces the frozen table/API boundary, legacy non-interference, no engines, no frontend scope, and no out-of-scope models. | None |

Matrix count: 37 tasks. Every existing task appears once and has exactly one classification.

## 4. Detailed findings

Only the two tasks classified other than `NO CHANGE` appear here.

### 4.1 Plan 2 Task 2 — Business group and company identity

1. **Exact task and plan file:** Task 2 in `docs/superpowers/plans/2026-09-04-investment-operating-system-m1-core-research-domain.md`.
2. **Exact current requirement at issue:** Step 1 requires tests for a “unique normalized uppercase 12-character `Company.isin`” and unique `Company.ticker_id`. Step 3 requires `Company` fields including `ticker_id` and `isin`, plus named unique constraints for both. These requirements are valid but do not state the bounded semantic role of the ISIN.
3. **North-Star invariant involved:** Amendment Sections 3 and 19.A–B: Company is the implemented M1 entity but not the permanent universal research root; Ticker is the M1 price bridge; `Company.isin` identifies the primary listed equity in M1 and is not the universal corporate-issuer identifier.
4. **Smallest proposed remedy:** Add one semantic paragraph to Task 2 Step 3 after the Company field/constraint requirements. Preserve every field, constraint, interface, and validation rule.
5. **Implementation behavior changes:** No. Company creation, update, normalization, uniqueness, and Ticker resolution remain exactly as planned.
6. **Schema/migration behavior changes:** No. `Company.ticker_id` and `Company.isin` remain required and unique. No `ResearchSubject`, `Security`, `Listing`, or other table or field is added.
7. **API behavior changes:** No. Request, response, identity, and lookup behavior remain unchanged.
8. **Tests change:** No. Existing required uniqueness and normalization tests remain sufficient; the edit is semantic guidance.
9. **Effect of deferral on the future seam:** Deferral would not physically close the seam because an additive future migration can preserve `Company.id` and move the security identity. It would leave a documentation ambiguity that could cause later code or documentation to treat ISIN as issuer identity. That is why the classification is wording-only rather than a compatibility or schema change.

### 4.2 Plan 2 Task 4 — Narrative research revisions and concurrency primitive

1. **Exact task and plan file:** Task 4 in `docs/superpowers/plans/2026-09-04-investment-operating-system-m1-core-research-domain.md`.
2. **Exact current requirement at issue:** Step 1 requires immutable revision behavior and absence of update/delete commands. Step 3 lists the exact frozen `ResearchRevision` fields, including `effective_at` and `created_at`, and implements current-base concurrency. It does not explicitly say that confidence and evidence cutoff are absent from M1 or that the two stored timestamps are not an evidence cutoff.
3. **North-Star invariant involved:** Amendment Sections 5, 7, and 19.D–G: stored `ResearchRevision` is the authoritative immutable M1 SPA Research View; M1 adds no confidence or evidence-cutoff field; existing timestamps retain frozen meanings; later analysis must not invent an unrecorded cutoff or rewrite history.
4. **Smallest proposed remedy:** Add one semantic paragraph to Task 4 Step 3 after the exact field list. Keep the existing model, concurrency algorithm, transaction boundary, and immutable children unchanged.
5. **Implementation behavior changes:** No. Creation, supersession, conflict handling, and immutability remain exactly as planned. M1 adds no AI analysis behavior.
6. **Schema/migration behavior changes:** No. No confidence, `evidence_cutoff_at`, publication, discovery, ingestion, or similar field is added. `effective_at` and `created_at` retain their frozen definitions.
7. **API behavior changes:** No. Payloads and projections retain the frozen M1 contract.
8. **Tests change:** No. Existing immutability, exact-field, child atomicity, and stale-base tests remain sufficient. The clarification prohibits inventing extra semantics rather than adding behavior.
9. **Effect of deferral on the future seam:** Deferral would not close a physical persistence seam because immutable revisions and additive migrations already permit future evidence/methodology records. It would leave room to mislabel `effective_at` or `created_at` as an evidence cutoff or to assume confidence is stored when it is not. That semantic risk warrants wording clarification only.

## 5. Proposed plan edits

These are proposed edits for a separate human-approved task. They are not applied by this assessment.

### 5.1 Proposed wording for Plan 2 Task 2 Step 3

Insert after the paragraph defining `Company` fields and constraints:

> M1's required unique `Company.isin` is the bounded identifier of the primary listed equity represented by the M1 `Company`/`Ticker` relationship. It is not SPA's permanent universal identifier for the corporate issuer. The required unique `ticker_id` and `isin` constraints remain unchanged in M1. Do not add `ResearchSubject`, `Security`, `Listing`, or other future-architecture tables. A later approved additive migration may map the security identity to a future Security/Listing model while preserving `Company.id`, historical revisions, and existing relationships.

### 5.2 Proposed wording for Plan 2 Task 4 Step 3

Insert after the paragraph defining `ResearchRevision`, `ResearchPoint`, and the revision transaction:

> The stored `ResearchRevision` is the authoritative immutable M1 SPA Research View. Persist only the fields in the frozen M1 design; do not add confidence, `evidence_cutoff_at`, publication, discovery, ingestion, or similar fields. `effective_at` remains the approved business-effective timestamp and `created_at` remains the creation timestamp; neither is an evidence cutoff. M1 has no AI regeneration path. Any future analysis of an M1 revision must identify the exact stored revision and its actual timestamps/provenance and must not invent an evidence cutoff or rewrite the stored record.

No other plan wording change is proposed.

## 6. M1 scope-preservation check

The proposed reconciliations introduce:

| Potential expansion | Introduced? | Assessment |
|---|---|---|
| New table | NO | No `ResearchSubject`, `Security`, `Listing`, `InvestmentActor`, Theme, Legacy, temporal, or other table is proposed. |
| New field | NO | No timestamp, confidence, evidence-cutoff, actor, jurisdiction, asset, or entitlement field is proposed. |
| New API | NO | All frozen request and response contracts remain unchanged. |
| New engine | NO | No Discovery, Smart Capital, Event-Causality, Theme, Portfolio, Wealth, Learning, Social, or self-modification engine is proposed. |
| New jurisdiction | NO | M1 remains India-first; no United States or global adapter is proposed. |
| New asset class | NO | M1 remains company/equity focused; no ETF, fund, index, REIT, InvIT, bond, or generic security implementation is proposed. |
| New entitlement tier | NO | M1 remains FREE/PREMIUM; Premium Global and SPA Legacy are not proposed. |
| New frontend scope | NO | M1 remains backend-first with no frontend application change. |

The proposed wording does not change implementation behavior, schema or migration behavior, API behavior, or test behavior. It makes the bounded meaning of existing M1 requirements explicit.

## 7. Conflict decision

**NO MATERIAL DESIGN CONFLICT**

The two specifications and all 37 implementation tasks can coexist without redesigning M1. No existing plan document or plan index should be changed until a human reviews and approves this assessment and separately authorizes the exact wording edits.
