STATUS: PROPOSAL — ARCHITECTURE INTEGRATED PER ADDENDUM + OWNER REFINEMENTS (2026-10-08) — NOT YET APPROVED FOR IMPLEMENTATION

# Phase 3 — Investment Intelligence Foundation: Design Proposal

**Date:** 2026-10-08 (v1); integrated 2026-10-08 with `2026-10-08-phase3-architecture-review-addendum.md`'s accepted recommendations and the owner's final refinements of the same date; implementation-readiness pass (FiscalPeriod resolution, ForecastAssumption atomicity, SQLite NULL-uniqueness fix, §12 Slice A checklist) added the same date, pending Slice A authorization.

**Scope of this document:** architecture and contracts only. No migration, model, or service code is created by this document. It defines proposed entities/contracts, ownership boundaries, data flow, revision/supersession semantics, provenance rules, implementation slices, and acceptance gates for owner review. Phase 3 execution does not start until this proposal is explicitly approved, slice by slice, the same way the Research Coverage & Fact Intelligence capability was.

**Requirements evidence this reconciles against:**
- `docs/superpowers/specs/2026-09-04-investment-operating-system-milestone-1-design.md` (the frozen M1 design — §4.3 `ResearchRevision`, §4.4 `OwnershipSnapshot`, §4.5 `GovernanceFlag`, §4.6 `CompanyDisclosure`, §4.8 "Forecast placeholders" (`ForecastRevision`/`ForecastLine`), §4.9 "Method-neutral valuation placeholders" (`ValuationRevision`/`ValuationReferenceLine`), §16 "Explicitly out of scope").
- `docs/superpowers/specs/2026-09-05-spa-north-star-architecture-amendment-design.md` (the controlling amendment — §6 Epistemic separation, §7 Authoritative SPA Research View, §13 Theme Intelligence, §14 Discovery Engine, §16 SPA Legacy's View/Portfolio/Recommendation separation, §19 Hard M1 compatibility requirements, §21 Impact-assessment classification, §22 Architectural North Star hierarchy).
- `docs/superpowers/plans/2026-09-25-spa-post-m1-master-roadmap-v2.md` (Tier 0.1 Research Intelligence Deepening — now closed; Tier 0.4/0.5 World Context + Causal-Chain/Theme — not yet built; Tier 1.2 Business Pulse's Chemplast Sanmar/PVC-cycle example; Tier 2.1 Forecasting Depth; cross-cutting principles: capture-early, infrastructure-vs-intelligence split, immutability, epistemic separation, World/Macro context linkage).
- `docs/superpowers/plans/2026-09-25-spa-post-m1-roadmap-architecture-review.md` (Round 2's "Industry/Cycle/Theme should get the same lightweight treatment early" finding; Round 3's Chemplast Sanmar PVC-cycle grounding; Round 5/6's Causal-Chain/Theme genesis-record and sibling-hypothesis requirements).
- `docs/superpowers/plans/2026-10-07-research-coverage-fact-intelligence-design-proposal.md` (the closed Research Intelligence Deepening capability — `ResearchDimension`, `CoverageProfile`/`CoverageProfileDimension`, `CoverageReviewPass`/`CoverageRecord`, `CandidateFinding`/`CandidateFindingDecision`, `FactDerivation`/`FactDerivationInput`, `ResearchProposition`/`PropositionStageType`/`PropositionLink`, plus the real IKIO/UNO Minda acceptance corpus).
- `docs/superpowers/plans/2026-10-08-phase3-architecture-review-addendum.md` (the architecture-review addendum this revision integrates — preserved unchanged as the review record; see it for the full reasoning behind each decision below).
- Current `backendtest` code (`app/models/*.py`, `app/services/*.py`) as ground truth where it is more current than the specs above — verified directly, not assumed.
- The two frozen EquiSense benchmarks and the external-platform capability set observed across AlphaSense/Canalyst, Quartr, Screener/Koyfin and general institutional buy-side workflow (owner-supplied context; no new external benchmark document exists in this repo).

**Acronyms, resolved by the owner (2026-10-08):**
- **EFP = Event Forensics Pipeline** — event reconstruction, promoter/ownership networks, governance, financial forensics, capital allocation, and transformation monitoring. This proposal's **P3-B defines where EFP's findings are stored once produced. It does not implement EFP's investigative execution** — detection logic, cross-entity pattern-matching, or any analytical process that produces a forensic finding in the first place remains analyst-driven (manual) or future work, explicitly out of scope here. See P3-B below.
- **CC+T is two distinct things, kept separate:** "Causal-Chain + Theme" remains this repo's own World-layer mechanism (Master Roadmap V2 §0.5, not yet built) — **preserved unchanged**, not touched by Phase 3. "Commodity Cycle + Transformation" is the owner's company-research framework — an external commodity/industry-cycle component plus a company-internal transformation component — and is **not a subset of Theme Intelligence** (§13's node chain has no Transformation node). P3-C below is reconciled against this framework directly, not against Theme Intelligence. The literal string "CC+T" is reserved for Causal-Chain+Theme in all future documents; "Commodity-Cycle & Transformation" is spelled out in full.

**Cross-market scope (owner requirement, 2026-10-08):** Phase 3's Research Brain, Financial Normalisation/EFP, Cycle Intelligence, Scenario, and Valuation engines must be market-agnostic at the core — able to research Indian and US-listed companies without duplication. Jurisdiction-specific differences (accounting standard, currency, ownership/governance vocabulary, fiscal calendar, corporate-action conventions) belong in source adapters and mapping conventions, never hardcoded into core logic. **No US ingestion or SEC-specific workflow is built in Phase 3** — this revision only ensures the contracts stay compatible with one, and names where India-specific assumptions already exist. See §3.5, the P3-A Market/Jurisdiction Adapter boundary in §4, and §10 items 5–6.

---

## 1. Where Phase 3 sits in the existing architecture

The North-Star amendment's own hierarchy (§22) is:

```text
WORLD → DISCOVERY → RESEARCH BRAIN → INVESTMENT BRAIN → MARKET BRAIN → WEALTH BRAIN → LEARNING BRAIN → SELF-STEWARDSHIP
```

with layer responsibilities stated explicitly in its table: **Research Brain** "maintain[s] sourced facts, analysis, forecasts, valuation, falsifiers, and the authoritative SPA Research View"; **Investment Brain** "translate[s] research into investment cases, opportunity comparisons, sizing inputs, and decision options."

This matters because **"Phase 3 — Investment Intelligence Foundation" spans two North-Star layers, not one**:

| Component | North-Star layer | What it actually is |
|---|---|---|
| P3-B EFP storage layer (Financial Normalisation & Forensic Engine) | **Research Brain** (deepens Fact/Evidence) | Finishing work M1 explicitly deferred (§16) at the Fact layer, plus a storage home for EFP findings — not EFP's investigative execution |
| P3-C Cycle Intelligence (Commodity-Cycle & Transformation) | **World** (a narrow, early slice) | The owner's own cycle+transformation framework — distinct from, and not a subset of, Theme Intelligence (§13) |
| P3-D Investment Hypothesis & Assumption Engine | **Research Brain** (the Hypothesis/Inference step of §6's chain) | New — this exact structured step does not exist in M1 today |
| P3-E Scenario/Forecast Engine | **Research Brain** (the Forecast step) | Turning the existing `ForecastRevision`/`ForecastLine` **placeholders** (§4.8) into a real, scenario-aware engine |
| P3-F Valuation Engine | **Research Brain** (the Valuation step) | Turning the existing `ValuationRevision`/`ValuationReferenceLine` **placeholders** (§4.9) into a real engine |
| P3-A Investment Brain contracts | **Investment Brain** | The ownership/interface boundary itself |
| P3-G Investment View / ResearchRevision | **Investment Brain** | The actual translation of Research Brain output into an investment case, now including the nine-gate assessment |

**Reconciliation decision carried through the rest of this document:** P3-B/D/E/F are **Research Brain deepening** — they complete work the frozen M1 design named and explicitly deferred, not new architecture. P3-A/G are the **first real slice of Investment Brain**. P3-C is a **deliberately narrow first slice of the World layer**, scoped to the owner's Commodity-Cycle & Transformation framework, not a reimplementation of Theme Intelligence.

---

## 2. The epistemic chain every new object must slot into exactly once

§6 of the amendment fixes this sequence as a system-wide invariant:

```text
Source → Evidence → Fact → Hypothesis/Inference → Forecast → Valuation → SPA Research View → (future) Portfolio View → (future) Client Recommendation
```

Mapping Phase 3's new objects onto it, one object per step, with no step skipped or collapsed:

```text
Source           Document (existing)
  ↓
Evidence         Evidence (existing) — also CycleObservation's own source citations
  ↓
Fact             ExtractedFact (existing) — raw financial line items AND normalized
                 primitives both live here (§3.1); CompanyExposure (new, P3-C)
  ↓
Hypothesis/      InvestmentHypothesis (new, P3-D) — cites Fact/Proposition/
Inference        CompanyExposure (cycle-side) AND a ResearchProposition
                 (transformation-side) as SEPARATE citations when both apply (§4
                 P3-C); ForecastAssumption (new, P3-D/P3-C) — cites
                 InvestmentHypothesis + exactly one evidence source
  ↓
Forecast         ForecastRevision/ForecastLine (existing placeholder, now a
                 real scenario-aware engine — P3-E)
  ↓
Valuation        ValuationRevision/ValuationReferenceLine (existing placeholder,
                 now a real engine — P3-F)
  ↓
SPA Research     ResearchRevision (existing, unchanged, still the ONE
View             authoritative narrative) + InvestmentCase (new, P3-G) — the
                 Investment Brain's translation of the above into a decision,
                 gated by the nine-gate assessment (§4 P3-G)
```

This placement is the single most load-bearing design decision in this proposal and is repeated at the start of every component section below so each one's exact position is unambiguous.

---

## 3. Reuse ledger — what is reused unchanged, what is reused and extended, what is genuinely new

### 3.1 Reused unchanged (no schema touch at all)

| Existing structure | Reused for |
|---|---|
| `Document`, `ExtractionRun`, `ExtractionUnit` (`research_brain.py`) | Source for every new evidence-citing object below |
| `Evidence`, `ExtractedFact`, `FactEvidence`, `ResearchBrainService.record_evidence`/`record_fact` | Raw financial observations are `ExtractedFact` rows (§3.2 for the typed-contract refinement) |
| `FactDerivation`, `FactDerivationInput` | Normalized financial primitives, TTM aggregates, **and corporate-action-adjusted metrics** (bonus/split/rights-adjusted EPS, etc.) are all `ExtractedFact` + `FactDerivation` rows, each naming the specific adjustment in `formula_description` — no new field, no new table |
| `ResearchProposition`, `PropositionStageType`, `PropositionLink`, `ResearchCoverageService.create_proposition`/`link_proposition_stage`/`get_proposition_timeline` | Management promise-vs-delivery, **EFP's "event reconstruction"** (new forensics-flavored `PropositionStageType` rows, e.g. `ALLEGATION_RAISED → REGULATOR_NOTICE → COMPANY_RESPONSE → INVESTIGATION_OUTCOME → REMEDIATION`), and **"transformation monitoring"** — the same mechanism as the Commodity-Cycle & Transformation framework's Transformation dimension (§4 P3-C). One mechanism serves both EFP and Cycle Intelligence; no duplicate transformation-tracking structure. New stage types are data inserts, never migrations. |
| `CandidateFinding`/`CandidateFindingDecision`, `CoverageReviewPass`/`CoverageRecord`, `ResearchDimension`/`CoverageProfile` | Unchanged; Phase 3 adds a `FIN_FORENSIC` or similar `ResearchDimension` row (a data insert) rather than a parallel sweep mechanism |
| `ResearchRevision`/`ResearchPoint`, `ResearchCommandService.create_research_revision` | Unchanged. Remains the one authoritative narrative view (§7, §19.D). `InvestmentCase` (P3-G) references it; never duplicates or supersedes it. |
| `Company`/`Ticker`, `OwnershipSnapshot`, `GovernanceFlag`, `CompanyDisclosure` | Unchanged identity/context backbone. `OwnershipSnapshot` (promoter/ownership networks) and `GovernanceFlag` (governance) are themselves two of EFP's six capabilities, already fully covered with no change. `Company.sector`/`Company.industry`/`Company.business_group_id` are the attachment point for `CompanyExposure` (P3-C). |
| `ValuationReferenceLine.reference_forecast_revision_id` | Already the valuation→forecast citation mechanism. Reused as-is by P3-F. |
| `InvestmentCaseForecast`/`InvestmentCaseValuation` (new in this proposal, see P3-G) | The authoritative, exact record of which immutable scenario-family revisions a given `InvestmentCase` was built from — this is what guarantees point-in-time scenario-family reconstruction; see §4 P3-G and the addendum's §5 for why a separate `ScenarioSet` table is not needed on top of it. |

### 3.2 The typed financial-observation contract (smallest adequate version)

Per owner refinement: the generic Fact/FactDerivation mechanism is retained unchanged in shape, but reporting periods, units, standalone/consolidated basis, restatements, and corporate-action adjustments must be **reliably** supported, not just representable in principle. The smallest contract that achieves this:

1. **Typed, validated reporting periods, resolvable to real calendar dates — application-layer contract, no schema change before Slice B.** `ExtractedFact.period` remains the existing `String(50)` column, but every `fin.*` write path (`promote_candidate_finding`, `record_fact`, and the new `FinancialNormalizationService`) must construct it through one shared `FiscalPeriod` value object with two responsibilities: (a) enforcing a single grammar (`FY<year>`, `FY<year>Q<1-4>`, `FY<year>H<1-2>`, `FY<year>TTM`) and rejecting anything else at write time; (b) **resolving** a label to an actual `(period_start_date, period_end_date)` pair via `FiscalPeriod.resolve(fiscal_year_end_month: int = 3)` — the parameter the TTM/YoY arithmetic actually needs, not just the label. **Recommendation: do not add `Company.fiscal_year_end_month` before Slice B.** Every company in the system today uses India's April–March year implicitly, so the default parameter value (`3`) is correct for 100% of current and Slice-B-acceptance companies (Chemplast Sanmar, UNO Minda) and the resolver needs no per-company lookup yet. Building the resolver as a function of an explicit (currently always-defaulted) parameter, rather than a bare unparameterized date-math helper, is what makes this backward-compatible: when a company with a different fiscal year end is eventually onboarded, exactly one change is needed — add the nullable `fiscal_year_end_month` column to `Company` (zero backfill risk; existing rows default to `3`) and change the resolver's call sites to pass `company.fiscal_year_end_month or 3` instead of the literal default. No change to the grammar, to `ExtractedFact`, or to any Slice B service logic. This is the smallest approach that is correct today and doesn't need to be revisited structurally later — only extended with one column, on its own future schedule.
2. **Validated units — application-layer contract, no schema change.** Every `fin.*` Fact's `unit` must match its `FinancialMetricDefinition.standard_unit` (or an explicitly documented alternate-unit allowlist on that same row), checked at write time by `FinancialNormalizationService`. `FinancialMetricDefinition` already exists in this proposal (§4 P3-B) as the controlled vocabulary; this is one more validation rule against it, not a new table.
3. **Standalone/consolidated basis — one new column (flagged, §5).** `ExtractedFact.basis: VARCHAR, nullable` (`STANDALONE`|`CONSOLIDATED`), populated only for `fin.*` fact types, `NULL` for every other Fact in the system. Promotes what the original draft of this proposal had left as prose-in-`value` to a first-class, queryable field.
4. **Restatement vs. correction — one new column (flagged, §5).** `ExtractedFact.supersede_reason: VARCHAR, nullable` (`RESTATEMENT`|`CORRECTION`) on the existing `supersedes_fact_id` link. "The company restated FY22 revenue down 8%" is itself a research-worthy signal (an EFP-relevant event); "we corrected our own extraction" is bookkeeping hygiene. Today's single supersession mechanism cannot tell a reader which happened; this field does, with no change to the supersession mechanism itself.
5. **Corporate-action adjustments (bonus/split/rights-adjusted metrics) — reuse `FactDerivation`, no new field.** A dilution-adjusted metric is a `fin.norm.*` `ExtractedFact` with a `FactDerivation` whose `formula_description` names the specific corporate action and adjustment factor (e.g. "EPS restated for 1:2 bonus effective 2024-06-01"), and `FactDerivationInput` rows citing the pre-adjustment raw Fact(s) — identical to the mechanism already proven on UNO Minda's EBITDA derivation, now with a documented convention that corporate-action adjustments are always expressed this way, never silently baked into a raw Fact's value.

Ten-year histories need no change at all — `ExtractedFact` is already one row per `(company_id, fact_type, period)`, a timeseries shape by construction.

**Rejected as unnecessary complexity:** a new "typed financial observation" model or value-object table. Two narrowly-scoped nullable columns plus three write-path validation/convention rules are adequate; a parallel model would duplicate Fact/FactDerivation for no structural gain.

### 3.3 Genuinely new (additive tables)

`FinancialMetricDefinition` (P3-B), `CycleObservation`/`CycleAssessment`/`CompanyExposure` (P3-C), `InvestmentHypothesis` (P3-D), `ForecastAssumption` (P3-D, shared with P3-C), `ForecastRevisionAssumption` (P3-E link table), `InvestmentCase`/`InvestmentCaseKillSwitch`/`InvestmentCaseGateResult` (P3-G).

`CapitalAllocationSnapshot` (P3-B) is **specified but its implementation is deferred** — see §4 P3-B and §10.

### 3.4 Genuinely new (additive columns on existing frozen tables — each requires explicit sign-off)

All schema-touching items in this proposal, consolidated (see §5 for the full table): the `scenario` column on `ForecastRevision`/`ValuationRevision`; `basis`, `supersede_reason`, and `accounting_standard` on `ExtractedFact`; and the `origin`/`promoted_by_user_id`/`promoted_at` columns on `InvestmentHypothesis`, `ForecastRevision`, `ValuationRevision`, and `InvestmentCase` (§4 P3-A, automation boundary).

### 3.5 Market-agnostic core — jurisdiction differences stay in adapters, not in the engines

Verified against the live, frozen M1 models before writing this section (not assumed): `ForecastLine.currency`/`ValuationRevision.currency` already exist as ISO-4217 `String(3)` columns — the core already treats currency as a first-class, per-row field, just defaulted to `"INR"` at the database level. Three real India-specific assumptions exist today; each is handled differently depending on whether it sits in code this proposal controls or in already-frozen M1 code:

1. **`CapitalAllocationSnapshot`'s field names (this proposal's own draft, not yet built — fixed here, no cost).** The §4 P3-B shape previously named `total_committed_inr_crore`/`total_deployed_inr_crore` — currency and scale baked into the column name. Corrected to `total_committed_amount: Decimal`, `total_deployed_amount: Decimal`, `currency: VARCHAR(3)` (ISO-4217, no default), with crore/lakh/million purely a display-formatting concern applied at read time, never stored. Since this table is still unbuilt (§4 P3-B, deferred), this costs nothing to fix now.
2. **`FinancialMetricDefinition.slug` naming convention (this proposal's own new table — a documentation rule, no schema change).** Slugs must name canonical, standard-neutral economic concepts (e.g. `operating_revenue`, not a Schedule-III-specific Ind AS line-item name) — the standard-specific line-item-to-canonical-concept mapping is a source-adapter's job (below), not the slug's. `ExtractedFact.accounting_standard: VARCHAR, nullable` (`IND_AS`\|`US_GAAP`\|`IFRS`), parallel to `basis`, records which standard actually produced a given raw Fact's value, since the same canonical slug can be filed under different standards by different companies (flagged in §5 item 3b). `basis` (`STANDALONE`\|`CONSOLIDATED`) already degrades cleanly for a US filer that only reports consolidated statements — it is simply always `CONSOLIDATED` or left `NULL`, never a blocker.
3. **Two assumptions already exist in frozen M1 code and are *not* fixed by this proposal (identified, not actioned):**
   - `OwnershipSnapshot.promoter_holding_pct`/`promoter_pledge_pct` encode India's specific regulatory "promoter" category (with its own pledge-disclosure requirement) — there is no exact US equivalent (US uses Schedule 13D/G beneficial ownership and Section 16 insider filings, a different concept). This table is frozen M1 code; Phase 3 does not touch it. **Before real US coverage, this will need either a jurisdiction-neutral ownership model extended by a jurisdiction-specific interpretation, or a parallel US-specific ownership structure** — an M1-touching decision outside this proposal's authority.
   - `Company` carries no fiscal-year-end field — `ForecastLine.fiscal_year`/`ExtractedFact`'s `FiscalPeriod` grammar (§3.2) are bare year/quarter labels with no stored calendar anchor, so "FY2024" is unambiguous only because every company in the system today uses India's April–March convention implicitly. **Before a US company (typically a December fiscal year end) can be onboarded correctly, `Company` will need an additive, nullable `fiscal_year_end_month` column** (zero backfill risk — it would default existing rows to March) — again an M1-touching change this proposal flags but does not make.

**The Market/Jurisdiction Adapter boundary (specified, not implemented — see §4 P3-A).** The pattern that keeps the core engines market-agnostic: a per-jurisdiction adapter owns (a) GAAP-line-item → canonical `FinancialMetricDefinition` slug mapping, (b) `basis`/`accounting_standard`/currency population conventions, (c) ownership/governance vocabulary translation, (d) fiscal-calendar and corporate-action-term translation (e.g. a US stock split and an Indian bonus issue are the same economic event under different vocabulary). India's current conventions are the one adapter instance this system already runs, implicitly. **No second adapter is built in Phase 3.**

---

## 4. Component designs

### P3-A — Investment Brain contracts

**Layer:** Investment Brain (the boundary itself). **Chain position:** governs how every other node above talks to Research Brain; produces nothing on the chain itself.

Defines, without implementing:
- **Shared vocabulary.** A `Scenario` slug (`BULL`, `BASE`, `BEAR`, `MID_CYCLE`). A shared "exactly one provenance source" value shape — `{fact_id | candidate_finding_id | evidence_id | cycle_observation_id | cycle_assessment_id | research_proposition_id}`, the discriminated-union idiom `PropositionLink`/`FactDerivationInput` already established, reused by every new citing field.
- **The system-draft / governed-promotion boundary (automation, refined per owner instruction).** `InvestmentHypothesis`, `ForecastRevision`, `ValuationRevision`, and `InvestmentCase` each carry `origin: SYSTEM_DRAFT|HUMAN_AUTHORED` (default `HUMAN_AUTHORED`) plus `promoted_by_user_id`/`promoted_at` (nullable; both required before a `SYSTEM_DRAFT` row counts as authoritative — every "current" query excludes any `SYSTEM_DRAFT` row with `promoted_by_user_id IS NULL`). This is **not** a prohibition on future automated analytical proposals — it is the seam that lets one exist later without a schema change, while every row remains `created_by_user_id`-attributed and no `SYSTEM_DRAFT` row is ever treated as authoritative until a human explicitly promotes it. The Research Orchestrator (§6) is not built now; this field only reserves the room for it. Columns flagged in §5.
- **Scenario-family coherence (creation-time rule, no new table).** `ForecastEngineService.create_scenario_forecast` must stamp every scenario in one coherent family with the same `as_of_date` and require they cite `ForecastAssumption` rows sharing the same `investment_hypothesis_id` revision. Reconstruction of the *exact* family actually used by a given decision is guaranteed at the `InvestmentCase` level by `InvestmentCaseForecast`/`InvestmentCaseValuation` (§4 P3-G) — those link tables name the exact immutable revision ids, which is stronger than inferring coherence from shared `as_of_date` alone. A separate `ScenarioSet` wrapper table is rejected: it would freeze what this rule plus the link tables already make exact and queryable.
- **Service ownership boundary — one service owns each write path, none reaches into another's tables directly:**

| New service (P3 component) | Owns writes to |
|---|---|
| `FinancialNormalizationService` (P3-B) | `fin.norm.*` Facts via existing `record_fact`/`record_fact_derivation`; `FinancialMetricDefinition`; enforces the §3.2 period/unit/basis contract |
| `CycleIntelligenceService` (P3-C) | `CycleObservation`, `CycleAssessment`, `CompanyExposure` |
| `HypothesisAssumptionService` (P3-D) | `InvestmentHypothesis`, `ForecastAssumption` |
| `ForecastEngineService` (P3-E) | `ForecastRevision`/`ForecastLine` (via the existing `ResearchCommandService.create_forecast_revision` path, extended), `ForecastRevisionAssumption` |
| `ValuationEngineService` (P3-F) | `ValuationRevision`/`ValuationReferenceLine` (via the existing `ResearchCommandService.create_valuation_revision` path, extended) |
| `InvestmentCaseService` (P3-G) | `InvestmentCase`, `InvestmentCaseKillSwitch`, `InvestmentCaseGateResult` |

Every service above is additive and sits alongside `ResearchBrainService`/`ResearchCoverageService`/`ResearchCommandService`, never replacing them.
- **Read-only query contracts** each engine must expose to every other, including `ForecastEngineService.get_current_scenario_set(company_id)` and `InvestmentCaseService.get_scenario_return_spread(investment_case_id)` (§4 P3-G) — computed live, not stored.
- **The Research Orchestrator's trigger-contract shape**, specified fully in §6 — not implemented now.
- **The automation boundary, stated explicitly:** mechanical automation is permitted through Fact/FactDerivation (append-only, evidence-cited, no interpretation asserted) and through `SYSTEM_DRAFT` rows above Fact level. It never extends to an *authoritative* Hypothesis, Forecast, Valuation, or InvestmentCase — promotion to authoritative is always a deliberate, human, attributed act.
- **The Market/Jurisdiction Adapter boundary (specified, not implemented; §3.5).** Every P3-B–G service reads `basis`/`accounting_standard`/`currency` off the Fact/Forecast/Valuation rows it is given and must never branch on a hardcoded jurisdiction. A per-market adapter (India's current conventions are the one instance that exists today, implicitly) owns GAAP-mapping, ownership/governance vocabulary, fiscal-calendar, and corporate-action-term translation. No second adapter is built in Phase 3; this is a contract boundary only, verified by the §9 Slice A market-agnostic compatibility test.

No table is created by P3-A itself; it defines four new columns across four existing-in-this-proposal tables (§5).

---

### P3-B — EFP storage layer (Financial Normalisation & Forensic Engine)

**Layer:** Research Brain (Fact step, deepened). **Chain position:** `Source → Evidence → Fact`, with the forensic half reaching into `Fact → Hypothesis` only insofar as a delivered/undelivered commitment or a forensic finding is itself evidence a later `InvestmentHypothesis` cites.

**What this component is, and is not.** EFP (Event Forensics Pipeline) names six capabilities: event reconstruction, promoter/ownership networks, governance, financial forensics, capital allocation, and transformation monitoring. **This component defines where a forensic finding is stored once it exists. It does not implement EFP's investigative execution** — no detection algorithm, cross-entity pattern-matcher, or automated red-flag scanner is specified or built here. Producing a forensic finding remains an analyst's (or, later, a separately-approved automated process's) job; this section only ensures that once produced, it has a correct, queryable, provenance-cited home that doesn't duplicate an existing structure.

| EFP capability | Storage | Status |
|---|---|---|
| Promoter/ownership networks | `OwnershipSnapshot` | Already covers this, unchanged |
| Governance | `GovernanceFlag` | Already covers this, unchanged |
| Financial forensics | `ExtractedFact`/`FactDerivation` under `fin.raw.*`/`fin.norm.*`, extended per §3.2 | Covered by this proposal |
| Capital allocation | `CapitalAllocationSnapshot` | Contract specified below; **implementation deferred** (§10) |
| Event reconstruction | `ResearchProposition`/`PropositionLink` with forensics-flavored `PropositionStageType` rows (data insert) | Covered by this proposal |
| Transformation monitoring | Same `ResearchProposition` mechanism — converges with Cycle Intelligence's Transformation dimension (§4 P3-C) | Covered by this proposal |

**Storage (reusing existing Fact/FactDerivation — no new table for raw or normalized values themselves):**

1. **`FinancialMetricDefinition`** (new, additive, seed/lookup table): `(id, slug, label, statement_section, namespace: RAW|NORMALIZED, standard_unit, description, created_at)`. `slug` names a canonical, standard-neutral economic concept (§3.5) — new metrics are a data insert, never a migration.
2. **Raw observations** = `ExtractedFact(fact_type="fin.raw.<slug>")`, via the unchanged `CandidateFinding` → `promote_candidate_finding` path, with `basis` and `accounting_standard` set (§3.2, §3.5) and `period` constructed via the `FiscalPeriod` grammar.
3. **Normalized primitives / TTM / corporate-action-adjusted metrics** = `ExtractedFact(fact_type="fin.norm.<slug>")` + `FactDerivation` + `FactDerivationInput` rows, per §3.2.5.
4. **`CapitalAllocationSnapshot`** (new, additive, append-only, point-in-time — **contract only, not built in Slice B**): `(id, company_id, as_of_date, total_committed_amount, total_deployed_amount, currency [ISO-4217, no default — §3.5], provenance: list of ResearchProposition/PropositionLink ids rolled up, created_by_user_id, change_reason, supersedes_snapshot_id)`. Currency-and-scale-generic by design (§3.5) — crore/lakh/million is a display concern, never stored. Deferred because, until real promise-vs-delivery `ResearchProposition` volume exists on a researched company, a live rollup query over `ResearchProposition`/`PropositionLink` is adequate and a frozen snapshot adds cost without yet solving a real reconstruction problem. Revisit once Slice C/D have run on both Chemplast Sanmar and UNO Minda for long enough that the live rollup stops being trivially reconstructable.

**Scope discipline (unchanged):** `FinancialNormalizationService` operates only against companies with an active `CoverageProfile`/research presence, never run universe-wide. Screener and other external structured data are ingested only as `Document`s or as raw citations inside a normalization's `FactDerivation.formula_description`.

---

### P3-C — Cycle Intelligence (Commodity-Cycle & Transformation)

**Layer:** World (a deliberately narrow first slice). **Chain position:** feeds `Fact`/`Hypothesis` from outside the company-specific chain.

**Reconciled against the owner's Commodity-Cycle & Transformation framework, not against Theme Intelligence (§13).** Theme Intelligence's node chain (`Theme → Drivers → Evidence → Industry → Value-chain position → Company/Security → Exposure → Catalyst → Counter-thesis → Changes through time`) has no Transformation node and remains a separate, not-yet-built World-layer mechanism under its own name, Causal-Chain + Theme (preserved unchanged). Commodity-Cycle & Transformation is this proposal's own, narrower, two-part framework:

```text
Commodity Cycle    CycleObservation (external, industry-wide, dated, cited)
                     → CycleAssessment (SPA's synthesized, versioned, sibling-
                       scenario-preserving read of where a named cycle stands)
Transformation     A company's own internal multi-stage change (capacity ramp,
                     cost restructuring, product-mix shift) — tracked as a
                     ResearchProposition using the proven stage-taxonomy
                     mechanism (same as EFP's transformation monitoring,
                     §4 P3-B) — not a new entity.
```

**The gap this corrects (from the architecture-review addendum):** a thesis that blends "the external cycle turned" and "the company transformed itself" into one undifferentiated `CompanyExposure.rationale` cannot later be falsified precisely — a disappointing outcome can't be attributed to the cycle call, the transformation call, or both. **Fix — a citation-discipline rule, not a schema change:** wherever an `InvestmentHypothesis` or `ForecastAssumption` depends on both a cycle component and a transformation component, it must cite them as two separate provenance entries:
- Cycle-side: `cycle_exposure_id` (external — `CompanyExposure` → `CycleAssessment` → `CycleObservation`).
- Transformation-side: a `ResearchProposition` id (company-internal, reusing the proven stage taxonomy).

This also resolves the three cycle-type question cleanly: **industry/commodity cycle** = `CycleObservation`/`CycleAssessment` (this section); **earnings cycle** (how the company's own reported earnings move through the external cycle) = the Forecast layer's job via scenario-forked `ForecastAssumption`/`ForecastRevision`, not a new entity; **equity cycle** (market re-rating) = the Valuation layer's job via scenario-tagged `ValuationRevision`, not a new entity.

**Entities (new, additive):**
- **`CycleObservation`**: `(id, cycle_tag, observed_on, description, source: evidence_id|document_id|external_reference, created_by_user_id, created_at)`. Append-only, company-independent.
- **`CycleAssessment`**: `(id, cycle_tag, scenario [BULL|BASE|BEAR for the cycle's own trajectory], revision_number, supersedes_revision_id, narrative, confidence, cites: list of CycleObservation ids, created_by_user_id, created_at, change_reason)`. Revisioned per `(cycle_tag, scenario)`; sibling scenarios coexist. First assessment per `(cycle_tag, scenario)` is an explicit genesis record.
- **`CompanyExposure`**: `(id, company_id, cycle_assessment_id, exposure_direction: BENEFICIARY|LOSER|MIXED, rationale, created_by_user_id, created_at)`. Append-only.
- **`ForecastAssumption`**: shared with P3-D — see there. Its link to Cycle Intelligence is one of its "exactly one provenance source" options: `cycle_exposure_id`. Its link to Transformation is `research_proposition_id` (the same discriminated union, now with that option included — see P3-A).

**World-context linkage, explicitly not built here:** unchanged from the prior draft — a `CycleAssessment` references a future World Context record by id, never copies it; Theme Intelligence's `Value-chain position`/`Catalyst` nodes, macro-regime detection, and any cross-industry theme graph remain out of scope for this slice.

---

### P3-D — Investment Hypothesis & Assumption Engine

**Layer:** Research Brain (the Hypothesis/Inference step — new). **Chain position:** `Fact → Hypothesis/Inference → (feeds) Forecast`.

- **`InvestmentHypothesis`**: `(id, company_id, title, thesis_narrative, consensus_view, variant_view, why_market_is_wrong, falsifiers, confidence [mandatory from v1], cites: list of Fact/ResearchProposition/CompanyExposure ids — cycle-side and transformation-side cited separately per P3-C when both apply, revision_number, supersedes_revision_id, origin: SYSTEM_DRAFT|HUMAN_AUTHORED, promoted_by_user_id, promoted_at, created_by_user_id, created_at, change_reason)`.
- **`ForecastAssumption`**: `(id, investment_hypothesis_id [required], scenario [BULL|BASE|BEAR|MID_CYCLE], assumption_statement, metric_slug [optional, references FinancialMetricDefinition], assumed_value, assumed_unit, provenance: exactly one of {cycle_exposure_id, research_proposition_id, fact_id, candidate_finding_id, evidence_id}, created_by_user_id, created_at)`. One hypothesis typically produces three scenario-forked assumption sets (Bull/Base/Bear) plus, where relevant, one `MID_CYCLE` set (§4 P3-E) — each row atomic and independently citable.

  **Atomicity rule (explicit, owner-confirmed):** one `ForecastAssumption` row = one driver = one provenance source. The existing discriminated-union `provenance` shape already enforces "exactly one source" at the constraint level; this rule additionally requires that **one row never carries two drivers' reasoning in its `assumption_statement`**. When one scenario's forecast depends on both a commodity-cycle driver and a company-transformation driver (Chemplast's "PVC normalization" + "capacity ramp" is the canonical case), it is represented as **two separate `ForecastAssumption` rows for that scenario** — one with `provenance.cycle_exposure_id` set, one with `provenance.research_proposition_id` set — both linked to the same `ForecastRevision` via `ForecastRevisionAssumption` (§4 P3-E). This is a direct, mechanical extension of §4 P3-C's citation-separation rule down to the assumption layer, not a new mechanism.

  **Acceptance test (Slice D):** a fixture builds Chemplast Sanmar's BULL-scenario assumption set as exactly two `ForecastAssumption` rows — one citing `cycle_exposure_id` (the PVC `CompanyExposure`), one citing `research_proposition_id` (the capacity-ramp `ResearchProposition`) — and asserts: (a) each row's `provenance` has exactly one non-null field; (b) the two rows' populated provenance field differs; (c) `ForecastEngineService` can query "this forecast's cycle-driver assumptions" and "this forecast's transformation-driver assumptions" as two disjoint sets rather than needing to parse free text to tell them apart.

---

### P3-E — Scenario / Forecast Engine

**Layer:** Research Brain (the Forecast step). **Chain position:** `Hypothesis/Inference → Forecast → (feeds) Valuation`.

Reuses `ForecastRevision`/`ForecastLine`, unchanged in every field except `scenario` (§5) and `origin`/`promoted_by_user_id`/`promoted_at` (§4 P3-A). Adds:
- **`ForecastRevisionAssumption`**: `(forecast_revision_id, forecast_assumption_id)`.
- `ForecastEngineService.create_scenario_forecast(company_id, scenario, assumption_ids, as_of_date, ...)` — resolves cited assumptions, computes `ForecastLine` values (arithmetic deliberately not specified here), calls the existing `create_forecast_revision` path unchanged, now scenario-tagged, and enforces the §4 P3-A coherence rule.
- **`MID_CYCLE` is a normalized-earnings reference, not a probability-weighted scenario (owner refinement).** It answers "what would this company earn at a representative point in its own cycle," used for valuation anchoring and sanity-checking. It is a valid `scenario` column value — same mechanics as Bull/Base/Bear — but `InvestmentCaseService`'s expected-return weighting (§4 P3-G) must explicitly exclude it from any probability-weighted calculation. This is a query-logic rule, not a schema difference.

No forecasting calculation logic is specified or implemented by this proposal.

---

### P3-F — Valuation Engine

**Layer:** Research Brain (the Valuation step). **Chain position:** `Forecast → Valuation → (feeds) SPA Research View / Investment Case`.

Requires zero new tables beyond `scenario` and the `origin`/promotion columns (§5). `ValuationReferenceLine.reference_forecast_revision_id` already lets a valuation cite a specific scenario's `ForecastRevision`. `ValuationEngineService` is a thin wrapper around `create_valuation_revision`, now producing one `ValuationRevision` per scenario (including `MID_CYCLE` as a valuation anchor, excluded from expected-return weighting per P3-E) under the same `valuation_method`, distinguished by `scenario`.

Expected return, risk framing, and kill switches are **not** added to `ValuationRevision` — they belong to P3-G.

---

### P3-G — Investment View / ResearchRevision

**Layer:** Investment Brain (genuinely new). **Chain position:** `SPA Research View` and beyond, strictly additive to it.

**The one rule this component cannot violate (§7, §19.D): no second authoritative research-view table.**

- **`InvestmentCase`**: `(id, company_id, research_revision_id [required FK], investment_hypothesis_id [required FK], cycle_assessment_id [nullable FK], view: ADD|HOLD|DO_NOT_ADD|REDUCE|EXIT, expected_return_pct, expected_return_basis, as_of_date, revision_number, supersedes_case_id, origin: SYSTEM_DRAFT|HUMAN_AUTHORED, promoted_by_user_id, promoted_at, created_by_user_id, created_at, change_reason)`.
- **`InvestmentCaseForecast`/`InvestmentCaseValuation`** (link tables): `(investment_case_id, forecast_revision_id)` / `(investment_case_id, valuation_revision_id)` — the exact, authoritative record of which immutable scenario-family revisions this case was built from. This is what guarantees point-in-time scenario-family reconstruction (§4 P3-A); no `ScenarioSet` table is needed.
- **`InvestmentCaseKillSwitch`**: `(id, investment_case_id, condition, data_source_hint, triggered_at [nullable, set once, never cleared])`.
- **`InvestmentCaseService.get_scenario_return_spread(investment_case_id)`** — a read-only query contract computed live from the linked Bull/Base/Bear valuations against price as of `as_of_date`, surfacing upside/downside/priced-in-return reasoning without a new stored field. `MID_CYCLE` is excluded from this weighting (§4 P3-E).

**The nine-gate investment assessment (owner-adopted taxonomy).** New, additive link table:

**`InvestmentCaseGateResult`**: `(id, investment_case_id, gate: VARCHAR CHECK IN ('GOVERNANCE','TRANSFORMATION','EXECUTION','INSTITUTIONAL_ADVANTAGE','FINANCIAL_VALIDATION','MARKET_CAP_OPPORTUNITY','OPTIONALITY','VARIANT_PERCEPTION','KILL_SWITCHES'), status: VARCHAR CHECK IN ('PASS','FAIL','WATCH','NOT_ASSESSED','WAIVED'), rationale, provenance: exactly one of {fact_id, evidence_id, candidate_finding_id, research_proposition_id, cycle_assessment_id}, supersedes_gate_result_id [nullable, self-FK — same append-only supersession idiom as ExtractedFact/ResearchRevision, giving historical assessment context for free], created_by_user_id, created_at)`.

The nine gates (Governance, Transformation, Execution, Institutional Advantage, Financial Validation, Market Cap Opportunity, Optionality, Variant Perception, Kill Switches) are expressed as a closed `CHECK` constraint rather than an open lookup table — a deliberate deviation from this codebase's usual "new values are data inserts" convention (`ResearchDimension`, `PropositionStageType`), because this is a curated, owner-fixed taxonomy, not an open sweep vocabulary expected to grow. **Flagged in §5 for explicit sign-off, including this choice of representation.**

`ResearchRevision` itself is **not modified** — no new column, no reverse reference added to it.

---

## 5. Schema changes requiring owner approval

All additive, all nullable where applicable, all classified `SMALL COMPATIBILITY CHANGE` per §21 of the North-Star amendment (bounded changes preserving an approved seam, not adding a future subsystem) unless noted otherwise.

| # | Change | Table(s) | Why | Slice |
|---|---|---|---|---|
| 1 | `scenario: VARCHAR, nullable`, enforced via **two partial unique indexes, not one composite UNIQUE constraint** (corrected during implementation-readiness review — see below) | `ForecastRevision`, `ValuationRevision` | Lets Bull/Base/Bear/Mid-Cycle coexist without misrepresenting one as superseding another. Zero rows system-wide today (verified) — no backfill risk. | A |
| 2 | `basis: VARCHAR, nullable` (`STANDALONE`\|`CONSOLIDATED`) | `ExtractedFact` | Promotes standalone/consolidated basis from free-text prose to a queryable field, scoped to `fin.*` fact types only | B |
| 3 | `supersede_reason: VARCHAR, nullable` (`RESTATEMENT`\|`CORRECTION`) | `ExtractedFact` | Distinguishes "the company restated this number" (a research signal) from "we fixed our own extraction" (hygiene) | B |
| 3b | `accounting_standard: VARCHAR, nullable` (`IND_AS`\|`US_GAAP`\|`IFRS`) | `ExtractedFact` | Records which standard produced a `fin.*` Fact's value, since the same canonical `FinancialMetricDefinition` slug may be filed under different standards by different companies (§3.5, cross-market requirement) | B |
| 4 | `origin: VARCHAR, default 'HUMAN_AUTHORED'` (`SYSTEM_DRAFT`\|`HUMAN_AUTHORED`); `promoted_by_user_id: nullable FK(user.id)`; `promoted_at: nullable timestamp` | `InvestmentHypothesis`, `ForecastRevision`, `ValuationRevision`, `InvestmentCase` | Reserves the automation seam without authorizing automated authorship of anything authoritative; every "current" query must exclude unpromoted `SYSTEM_DRAFT` rows | D, E, F, G respectively |
| 5 | New table `InvestmentCaseGateResult`, with `gate` and `status` as closed `CHECK`-constrained enums (not open lookup tables) | — | The nine-gate assessment representation; **the closed-enum choice is itself flagged for sign-off** as a deviation from the codebase's usual open-vocabulary convention | G |

**Item 1, corrected: why a composite UNIQUE constraint is not sufficient.** SQL NULL is never equal to another NULL for uniqueness purposes. A plain `UniqueConstraint(company_id, scenario, revision_number)` with `scenario` nullable does **not** block two rows at `(company_id, NULL, revision_number)` from coexisting — verified empirically against SQLite 3.49.1 (this project's engine): a composite UNIQUE with a nullable column silently admitted a duplicate `(C1, NULL, 1)` row, while correctly rejecting a duplicate named-scenario row. This would have silently broken the "exactly one current forecast per company per revision, when `scenario IS NULL`" invariant that is the entire reason item 1 exists — the legacy single-stream guarantee Phase 3 must not weaken.

**The fix — two partial unique indexes, following an idiom this codebase already uses** (`app/models/document.py`'s `uq_document_metadata_fingerprint_ordinary`/`_successor` pair, lines 306–319, already shipped and tested):

```python
__table_args__ = (
    sa.Index(
        "uq_forecast_revision_company_number_legacy",
        "company_id", "revision_number",
        unique=True,
        sqlite_where=sa.text("scenario IS NULL"),
        postgresql_where=sa.text("scenario IS NULL"),
    ),
    sa.Index(
        "uq_forecast_revision_company_scenario_number",
        "company_id", "scenario", "revision_number",
        unique=True,
        sqlite_where=sa.text("scenario IS NOT NULL"),
        postgresql_where=sa.text("scenario IS NOT NULL"),
    ),
    # existing CheckConstraint("revision_number > 0", ...) unchanged
)
```

replacing the single `uq_forecast_revision_company_number` constraint. `ValuationRevision` gets the same pair, with `valuation_method` carried in both index column lists. Verified empirically (same SQLite engine): with this pair, a duplicate `(C1, NULL, 1)` row is correctly rejected, a duplicate `(C1, 'BULL', 1)` row is correctly rejected, and `(C1, NULL, 1)` / `(C1, 'BULL', 1)` / `(C1, 'BEAR', 1)` correctly coexist. `sqlite_where`/`postgresql_where` are both specified because the live app targets SQLite in development and Postgres via `DATABASE_URL` in other environments (`config.py`) — matching the existing dual-dialect idiom exactly, not introducing a new one.

**Rollback precaution:** both tables have zero rows system-wide today (verified), so applying this migration carries no data risk at all right now. If rolled back after real rows exist (post-Slices B–G), reverting to a single composite constraint only *loosens* the constraint — it cannot fail against data that already satisfied the stricter partial-index pair — so the rollback itself is safe without a pre-check; the risk this fix prevents is forward (silently admitting invalid duplicates), not backward.

Item 1 carries forward from the base proposal's original §5 in intent (unchanged purpose), corrected in mechanism per this integration. Items 2–5 are new, per the prior integration.

---

## 6. Research Orchestrator contract (specified, not implemented)

Unchanged from the original draft in mechanism. Per owner instruction, explicitly reaffirmed: **the Orchestrator is not implemented now**, and nothing in this revision changes that. The `origin`/`promoted_by_user_id`/`promoted_at` columns (§5 item 4) are not part of the Orchestrator — they exist independently so that a future automated analytical proposal (whether or not it is ever wired to an Orchestrator-style trigger) has a place to land without a further schema change. Building the consumer, the queue, or any automatic wiring still requires separate, explicit approval.

**Trigger sources** — every P3 write path that should eventually emit a revalidation signal: `promote_candidate_finding`, `link_proposition_stage`, `record_fact_derivation` (existing); `CycleIntelligenceService` writes; `HypothesisAssumptionService` writes (new).

**Signal shape:**
```text
ResearchOrchestratorSignal(
  source_event: {kind, id, company_id, occurred_at},
  candidate_targets: {
    investment_hypothesis_ids: [...],
    forecast_revision_ids: [...],
    valuation_revision_ids: [...],
    investment_case_ids: [...],
  },
  reason: str,
)
```

**Trigger consumers (future, not built):** a revalidation worker surfacing a "may be stale" review item — never one that silently revises or supersedes anything automatically.

---

## 7. BUY/INTEGRATE/BUILD benchmark reconciliation

Unchanged from the original draft:

| Capability | External platform(s) | Disposition |
|---|---|---|
| Generic screening, ratio dashboards, peer comparison | Screener, Koyfin | **INTEGRATE** as a Document Library source |
| Generic transcript/filing search and broad-corpus KPI extraction | AlphaSense, Canalyst | **INTEGRATE** as a document source feeding the existing pipeline, researched/watchlist companies only |
| Company briefing packs, consensus/estimate aggregation | Quartr | **INTEGRATE** as a document/evidence source |
| Provenance-cited, scenario-forked, point-in-time-reconstructable chain from raw financials through cycle-aware assumptions to a dated, nine-gated Add/Hold/Exit judgment with kill switches | None of the above | **BUILD** — P3-B through P3-G |

---

## 8. Acceptance companies

**Chemplast Sanmar Limited — primary.** `Company.id = fbc97e85-b038-4b1a-9634-9946a5c706a0` exists; `sector`/`industry` null; no `ResearchRevision`/`ForecastRevision`/`ValuationRevision` rows for it or any company system-wide (verified). The full P3-B→G chain, first built, runs here:

```text
historical financials (fin.raw.* Facts, standalone + consolidated)
  + company facts/propositions (capex/capacity ResearchProposition)
  + PVC-cycle intelligence (CycleObservation → CycleAssessment → CompanyExposure = BENEFICIARY)
      ↓
  InvestmentHypothesis ("PVC normalization" cited via cycle_exposure_id +
    "capacity ramp" cited via a SEPARATE research_proposition_id — per P3-C's
    citation-discipline rule, not one blended rationale)
      ↓
  ForecastAssumption × Bull/Base/Bear + a MID_CYCLE normalized-earnings set
      ↓
  ForecastRevision × 4 (scenario-tagged, MID_CYCLE excluded from weighting)
      ↓
  ValuationRevision × 4 (scenario-tagged, each citing its matching ForecastRevision)
      ↓
  InvestmentCase: expected return/risk (Bull/Base/Bear spread via
    get_scenario_return_spread), nine InvestmentCaseGateResult rows (at least
    one PASS, one FAIL/WATCH/WAIVED example), kill switches, view = ADD/HOLD/...,
    fully traceable back through every link to the original filed raw Facts.
```

**UNO Minda Limited — secondary.** `Company.id = 9cbdabe1-3008-45dc-8ef6-dad859946990`; Slices 1–4's EBITDA `FactDerivation` and Tachi-S JV `ResearchProposition` transformation trace already live. Used to prove the §3.2 typed-contract extension and the forensics-flavored `PropositionStageType` rows are backward-compatible with existing Slice 1–4 output (no data loss, no re-derivation), and to exercise a second, differently-shaped cycle (auto-ancillaries) alongside a transformation example that already exists rather than being newly fabricated.

**Jasch Industries — onboarding remains paused.** No `Company`/`Ticker` row exists; `scripts/spa_bridge/CANARY_CHECKPOINT.md` already flags it (NSE: JASCHIND) as a known candidate with document migration deliberately paused pending a separate go-ahead. Not used in any Phase 3 acceptance gate in this proposal.

---

## 9. Implementation slices and acceptance gates

| Slice | Delivers | Depends on | Acceptance gate |
|---|---|---|---|
| **A** | P3-A contracts (incl. the `origin`/promotion vocabulary, coherence rule, and Market/Jurisdiction Adapter boundary); `scenario` column via the §5 item 1 partial-index pair; `FinancialMetricDefinition`; the `FiscalPeriod` resolver (parameterized, `Company.fiscal_year_end_month` not added) | Nothing beyond current code | Existing forecast/valuation tests pass unchanged with `scenario IS NULL`; **the SQLite NULL-uniqueness test** — two inserts at `(company_id, NULL, revision_number)` must collide, two inserts at `(company_id, 'BULL', revision_number)` must collide, and `NULL`/`'BULL'`/`'BEAR'` rows at the same `(company_id, revision_number)` must coexist; a `FiscalPeriod.resolve()` fixture proves label→calendar-date resolution for FY/Q/H/TTM labels under the default `fiscal_year_end_month=3`; **a market-agnostic compatibility test** — a fixture-only pass with `accounting_standard=US_GAAP`, `currency=USD`, `basis=CONSOLIDATED` substituted for every India-shaped value, proving no P3-B–G service or constraint branches on a hardcoded jurisdiction (no real US ingestion or company involved) |
| **B — EFP storage layer** | `fin.raw.*`/`fin.norm.*` incl. `basis`/`supersede_reason`; forensics-flavored `PropositionStageType` rows; `CapitalAllocationSnapshot` contract (not implemented) | Slice A | **Chemplast:** standalone/consolidated revenue, EBITDA, PAT reconciled with `basis` set. **UNO Minda:** re-express the existing EBITDA derivation and Tachi-S JV trace under the new vocabulary with zero data loss |
| **C — Cycle Intelligence** | `CycleObservation`, `CycleAssessment`, `CompanyExposure`; cycle-side/transformation-side separate-citation rule | Slice A | **Chemplast:** real PVC `CycleAssessment` with Bull/Base/Bear siblings. **UNO Minda:** a hypothesis citing an auto-ancillary cycle assessment AND the existing Tachi-S transformation `ResearchProposition` as two separate citations |
| **D — Hypothesis & Assumption** | `InvestmentHypothesis`, `ForecastAssumption`, `origin`/promotion columns | Slices B, C | A real Chemplast hypothesis, `HUMAN_AUTHORED`, citing Slice B/C output with 3 scenario-forked assumption sets; **the atomicity test (§4 P3-D)** — BULL's assumption set built as two separate rows (cycle-side, transformation-side), each with exactly one provenance field populated, independently queryable |
| **E — Forecast Engine** | `ForecastRevisionAssumption`; scenario-forking logic incl. `MID_CYCLE`; coherence rule enforced in code | Slice D | 4 coherent scenario-tagged `ForecastRevision`s for Chemplast (Bull/Base/Bear/Mid-Cycle), all sharing one `as_of_date`/hypothesis revision |
| **F — Valuation Engine** | Scenario-aware valuation (no new table) | Slice E | 4 scenario-tagged `ValuationRevision`s, each citing its matching `ForecastRevision` |
| **G — Investment View** | `InvestmentCase`, `InvestmentCaseKillSwitch`, link tables, `InvestmentCaseGateResult` (nine gates), `get_scenario_return_spread` | Slices B–F | Full Chemplast trace end to end: upside/downside spread queryable (Mid-Cycle excluded), all nine gates recorded with at least one PASS and one non-PASS example, at least one kill switch |
| **Orchestrator** | Contract only (§6) | — | **Not implemented in Phase 3 under any circumstances unless separately approved** |

---

## 10. Open questions — status after owner review (2026-10-08)

Resolved by the owner:

1. **Nine gates / five statuses:** owner confirmed "a controlled vocabulary." Read literally and carried forward as the closed `CHECK`-constrained enum this proposal recommended (§4 P3-G, §5 item 5) — a bounded, named set is itself a controlled vocabulary, and the gates are a curated, fixed taxonomy rather than one expected to grow the way `ResearchDimension` does. **Flagged explicitly in case the owner intended the open-lookup-table style instead** — correctable before Slice G with no cost, since `InvestmentCaseGateResult` is not built yet.
2. **`origin`/promotion scope:** owner confirmed all four tables — `InvestmentHypothesis`, `ForecastRevision`, `ValuationRevision`, `InvestmentCase` — consistently. Resolved; §5 item 4 and §9 unchanged.
3. **`CapitalAllocationSnapshot`:** owner confirmed deferral until real reconstruction requirements justify it, as recommended. Resolved.
4. **Market/Jurisdiction Adapter boundary:** approved as specified (§3.5, §4 P3-A). Resolved.
5. **Jasch Industries / `OwnershipSnapshot` US-equivalent:** owner confirmed both stay paused/deferred. Resolved.
6. **Human-governed promotion:** owner reaffirmed — `SYSTEM_DRAFT` rows are never authoritative until a human promotion sets `promoted_by_user_id`/`promoted_at`. No design change; already the mechanism in §4 P3-A.

Resolved by this implementation-readiness pass (§3.2, §4 P3-D, §5 item 1):

7. `Company.fiscal_year_end_month` is **not** added before Slice B — the `FiscalPeriod` resolver takes it as a defaulted parameter instead, deferring the M1 schema touch until a non-March company actually needs onboarding.
8. `ForecastAssumption`'s one-driver-one-provenance atomicity rule is now explicit, with a named Slice D acceptance test.
9. §5 item 1's `scenario` uniqueness is implemented as two partial unique indexes, not one composite `UNIQUE` constraint — a composite constraint would have silently failed to enforce the legacy single-stream invariant (verified empirically against this project's SQLite engine).

No remaining open architectural questions beyond what §12's checklist calls out as pending at authorization time.

---

## 11. What this document does not do

No migration, model, or service code is written. No existing table is altered. No North-Star non-goal (§20) is authorized. The Research Orchestrator is specified, not built. EFP's investigative execution is not built — only its storage layer is designed. Jasch Industries onboarding is not performed. **No US ingestion, SEC-specific workflow, or second market adapter is built or implied as built** — only the contract boundary that would let one exist later without reworking the core engines. Phase 3 execution does not start — this remains a proposal for owner review, now integrated with the architecture-review addendum's accepted recommendations and the owner's final refinements of 2026-10-08. §12 below is Slice A's implementation-readiness checklist, for authorization — it does not itself authorize anything.

---

## 12. Slice A implementation-readiness checklist

**Schema changes (Slice A only):**
- [ ] `ForecastRevision.scenario: VARCHAR, nullable`; drop `uq_forecast_revision_company_number`; add the two partial unique indexes (§5 item 1) with both `sqlite_where`/`postgresql_where` clauses.
- [ ] `ValuationRevision.scenario: VARCHAR, nullable`; same partial-index replacement, `valuation_method` included in both index column lists.
- [ ] `FinancialMetricDefinition` (new table): `id, slug, label, statement_section, namespace, standard_unit, description, created_at` — `slug` documented as standard-neutral (§3.5).
- [ ] `origin`/`promoted_by_user_id`/`promoted_at` columns added to `InvestmentHypothesis`, `ForecastRevision`, `ValuationRevision`, `InvestmentCase` **only as those tables are themselves created in their own slices (D/E/F/G)** — not all four exist yet; Slice A adds the columns to the two that already exist (`ForecastRevision`, `ValuationRevision`) and documents the convention for D/G to follow when those tables are created.
- [ ] No column added to `Company`, `OwnershipSnapshot`, or any other frozen M1 table (§3.5, §10 items 5/7).

**Compatibility tests (must pass before Slice A is considered done):**
- [ ] All existing `ForecastRevision`/`ValuationRevision` tests pass unchanged with `scenario IS NULL`.
- [ ] SQLite NULL-uniqueness test (§9): duplicate `(company_id, NULL, revision_number)` rejected; duplicate `(company_id, 'BULL', revision_number)` rejected; `NULL`/`'BULL'`/`'BEAR'` coexist at the same `(company_id, revision_number)`.
- [ ] Same three cases re-run against Postgres (or confirmed by code review of the `postgresql_where` clause against Postgres's documented NULL/partial-index semantics, if a Postgres instance isn't available in CI) — this proposal's dual-dialect claim is otherwise unverified on one of the two dialects it names.
- [ ] `FiscalPeriod.resolve()` fixture: FY/Q/H/TTM labels resolve to correct calendar start/end dates under `fiscal_year_end_month=3`; malformed labels are rejected at write time.
- [ ] Market-agnostic compatibility test (§9): a fixture-only pass substituting `accounting_standard=US_GAAP`/`currency=USD`/`basis=CONSOLIDATED` touches no hardcoded jurisdiction branch in any Slice A service.

**Acceptance evidence (Chemplast Sanmar primary; no new company onboarded in Slice A):**
- [ ] A disposable fixture on Chemplast's existing company row proves two named-scenario `ForecastRevision`s and one legacy (`NULL`-scenario) row coexist without any of the three colliding incorrectly.
- [ ] `FinancialMetricDefinition` seeded with at least the metrics Slice B will need first (revenue, EBITDA, PAT), each slug reviewed against the §3.5 standard-neutral naming rule before it is inserted.

**Rollback precautions:**
- [ ] Both `ForecastRevision`/`ValuationRevision` have zero rows system-wide as of this writing (verified) — Slice A's migration carries no data-migration risk today. Re-verify row counts are still zero immediately before running it, in case another branch has inserted rows in the interim.
- [ ] Rollback = drop the two new partial indexes and `scenario` columns, restore the original single composite `UniqueConstraint`. Safe unconditionally if run before any other slice inserts scenario-tagged rows; safe after, too, per §5's rollback note (loosening a constraint cannot fail against data that already satisfied the stricter one).
- [ ] `FinancialMetricDefinition` rollback = drop the table; it has no inbound FK from any other Slice A object, so this is a plain drop with no dependency ordering to worry about.

**Explicitly not in Slice A:** `CycleObservation`/`CycleAssessment`/`CompanyExposure` (Slice C), `InvestmentHypothesis`/`ForecastAssumption` (Slice D), `InvestmentCaseGateResult` (Slice G), `CapitalAllocationSnapshot` (deferred indefinitely), any US ingestion, any Jasch Industries onboarding, any change to `OwnershipSnapshot` or `Company`.
