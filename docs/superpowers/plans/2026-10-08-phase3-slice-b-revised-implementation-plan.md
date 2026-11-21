STATUS: PROPOSAL — NOT YET APPROVED — DOES NOT AUTHORIZE IMPLEMENTATION

# Phase 3 Slice B — Revised Implementation Plan
## Deterministic Financial Diagnostics & Narration

**Date:** 2026-10-08 (v2 — corrected per owner review; v1's architecture, five diagnostic groups, stateless narration service, scoped `ADJUSTED` namespace, Chemplast demonstration, and explicit deferrals are approved in principle and unchanged below except where this revision tightens them).
**Revises:** Slice B as originally scoped in `2026-10-08-phase3-investment-intelligence-foundation-design-proposal.md` (§4 P3-B). Slice A (`backendtest` commit `30bb2a6`) is unchanged and fully reused.

## Why this revision

v1 established the right shape (deterministic diagnostics + stateless narration, AI-free, EFP's broader scope deferred). This pass adds the integrity detail needed before coding: verifying the exact existing relationships `ADJUSTED` Fact provenance must use, specifying adjustment reconciliation/direction/justification/double-counting protection, defining exact calculation and missing-data conventions for all five diagnostic groups, and extending the acceptance tests to cover all of it. No architectural change from v1 — this is the same plan, made precise.

---

## 1. Verification: `ADJUSTED` provenance needs zero new relationships

Read directly from `app/models/research_coverage.py` before writing anything else in this plan:

- `FactDerivationInput` already has exactly two typed input slots, discriminated by a `CHECK` constraint: `(input_fact_id IS NOT NULL) != (input_evidence_id IS NOT NULL)`. One of them is always an `ExtractedFact` (an arithmetic input); the other is always a raw `Evidence` row.
- `Evidence` already carries `document_id` (required FK), `text_snippet` (up to 4000 chars — enough for a quoted management exceptional-item explanation), and `locator` (page/section). Citing `input_evidence_id` therefore already names the document and the exact passage — there is no separate `input_document_id` to invent, and none is needed.
- `role_label` (free text, nullable, already used today for e.g. `"Finance costs"`, `"PBEIT"`, `"D&A"` — naming what each input represents) is already the mechanism for distinguishing one input's purpose from another's within one derivation.

**Conclusion: an `ADJUSTED` Fact's provenance is fully representable today, with no new foreign key, no new table, and no abuse of an existing one:**
- The number(s) being adjusted → `input_fact_id` rows, `role_label` = the line item (e.g. `"Reported EBITDA (pre-adjustment)"`).
- The adjustment amount, if separately disclosed as its own figure → a further `input_fact_id` or `input_evidence_id` row, `role_label` naming it (e.g. `"One-off redundancy cost (add-back)"`).
- The justification for making the adjustment at all → an `input_evidence_id` row whose `role_label` **must** begin with the literal prefix `"Adjustment justification: "` followed by a short description — a plain string convention, not a schema change, and machine-checkable by an acceptance test (`role_label.startswith("Adjustment justification: ")`).

`record_fact_derivation`'s existing validation (`app/services/research_coverage_service.py`) already requires at least one input and exactly one discriminator per input — unchanged, reused as-is.

---

## 2. The one schema change (unchanged from v1, now the only one)

Widen `financial_metric_definition.namespace`'s `CHECK` constraint from two values (`RAW`, `NORMALIZED`) to three, adding `ADJUSTED`. Additive, zero rows affected (verified: `financial_metric_definition` has zero rows as of Slice A). No other table, column, or constraint changes anywhere in this plan — §1 above confirms nothing else is needed.

**No unresolved schema blockers were found.** This is the only schema item in Slice B, and it was already identified and approved in principle in the prior review round.

---

## 3. Adjustment integrity contract (new — reconciliation, direction, justification, double-counting)

Every `ADJUSTED` Fact must satisfy all four, checked at the acceptance gate (§6), not left to convention alone:

1. **Reconciliation.** `FactDerivation.formula_description` states the explicit arithmetic in full (e.g. *"Adjusted EBITDA = Reported EBITDA (fin.raw.ebitda, ₹118.4 Cr) + one-off redundancy cost add-back (₹6.2 Cr, per Evidence citing the Q2 FY25 earnings-call transcript) = ₹124.6 Cr"*). The acceptance test independently recomputes this from the cited `input_fact_id` values and asserts it equals the stored `ADJUSTED` Fact's value exactly — the formula description is not just prose, it is checked.
2. **Direction.** The formula must name whether the adjustment is an **add-back** (excluding a one-off *expense* — increases adjusted earnings) or a **deduction** (excluding a one-off *gain* — decreases adjusted earnings), and the sign applied must match the disclosed item's actual nature. The acceptance test asserts the sign is consistent with which case applies — a sign error here is exactly the kind of mistake this check exists to catch.
3. **Justification.** Per §1 — an `input_evidence_id` row with a `role_label` carrying the `"Adjustment justification: "` prefix, citing a `Document` of type `CONCALL`, `QUARTERLY_RESULTS`, or `ANNUAL_REPORT`, or a specific exceptional-items note. No adjustment without this row is accepted.
4. **Double-counting protection.** Two checks, both mechanical and both testable without any new schema:
   - *Within one derivation:* no `input_fact_id` appears twice in the same `FactDerivation`'s input set (the base figure and the adjustment delta must be two distinct cited numbers, never the same Fact counted under two role labels).
   - *Across the base figure and the adjustment:* the base (`"...pre-adjustment"`) input's own value must **not** already have the adjustment baked in — i.e. the raw Fact cited as the base figure is independently verified (by the same reconciliation check in point 1) to be the *reported*, unadjusted number, so the add-back/deduction is never applied twice to an already-adjusted base.

---

## 4. Deliverables

**D1 — Period-correct raw ingestion.** Unchanged from v1: existing `CandidateFinding` → `promote_candidate_finding` path; `period` via Slice A's `FiscalPeriod` grammar; `basis`/`accounting_standard` per the existing typed contract.

**D2 — Calculated diagnostics (`NORMALIZED`).** Exact conventions, all five groups:

| Group | Metric | Formula | Missing-data rule |
|---|---|---|---|
| Margins | Gross margin % | (Revenue − COGS) / Revenue × 100 | Not computed if COGS is not separately disclosed (common for non-manufacturers) |
| | EBITDA margin % | EBITDA / Revenue × 100 | Not computed if either input absent for that exact period |
| | PAT margin % | PAT / Revenue × 100 | Same |
| Cash conversion | CFO/EBITDA % | CFO / EBITDA × 100 | Computed **only** for periods where CFO is actually disclosed — most Indian filers disclose cash flow statements annually, not quarterly; never estimated for an undisclosed quarter |
| | FCF conversion % | (CFO − Capex) / PAT × 100 | Same cadence rule |
| Working capital | Inventory / receivable / payable days | `line item / (Revenue or COGS) × period_days` | `period_days` comes from `FiscalPeriod.resolve()`'s actual date span, never a hardcoded 365 — a half-year balance sheet must not be scaled as if annual. Computed only for periods where the Balance Sheet is actually filed (often annual/half-yearly, not every quarter) |
| | Cash conversion cycle | Inventory days + Receivable days − Payable days | Not computed unless all three component days are available for the same period |
| Growth & trend | YoY / QoQ revenue, EBITDA growth | (Current − comparator) / \|comparator\| × 100, comparator resolved via `FiscalPeriod`'s matching same-period-prior-year or immediately-prior-period logic | Not computed if the comparator period has no raw Fact (e.g. the company's first reported period), or if the comparator value is ≤ 0 (percentage growth is degenerate in that case — no metric, not a fabricated or sign-flipped one) |
| Earnings quality | Accruals ratio | (PAT − CFO) / Total Assets × 100 | Same CFO-disclosure-cadence rule as cash conversion; flags divergence magnitude only — **never** paired with an inferred explanation (that requires a D3 `ADJUSTED` Fact with its own citation) |

**One rule governs every row of this table: a diagnostic Fact is computed from complete, actually-disclosed inputs for that exact period, or it is not created at all.** No partial, estimated, interpolated, or zero-substituted computation exists anywhere in Slice B.

**D3 — Analytical adjustments (`ADJUSTED`), governed by §3.** Narrowly scoped: one genuine, fully traceable Chemplast exceptional-item case satisfies this deliverable (owner-confirmed threshold). The specific disclosure is identified during implementation against Chemplast's real filed corpus, not invented during planning.

**D4 — `FinancialNarrationService`.** Unchanged from v1: new, stateless, read-only, template-rendering only, no persisted model, no AI/LLM dependency. Descriptive clauses from any Fact; causal clauses only with a specific disclosure citation for that exact claim.

**D5 — Chemplast Sanmar end-to-end pass.** Unchanged from v1.

---

## 5. Acceptance tests

Extends v1's seven with the integrity conditions from §3–4:

1. Namespace migration — as v1.
2. Diagnostic correctness — as v1, now covering every formula in §4's table, not just a representative sample.
3. Period correctness — as v1.
4. **Missing-data absence check (new):** for a period where a required input is genuinely undisclosed (e.g. a quarter with no filed cash flow statement), assert the corresponding diagnostic Fact does **not** exist — not that it exists with a null/zero value.
5. **Disclosure-cadence check (new):** assert no CFO-dependent diagnostic (cash conversion, FCF conversion, accruals ratio) is ever computed for a period where Chemplast did not actually file a cash flow statement.
6. Adjustment citation gate — as v1, now explicitly checking the `"Adjustment justification: "` `role_label` prefix (§1), not just "a citation exists somewhere."
7. **Adjustment reconciliation check (new):** recompute the `ADJUSTED` Fact's value from its cited inputs and assert exact equality with the stored value (§3.1).
8. **Adjustment direction check (new):** assert the applied sign matches the disclosed item's nature — expense exclusion adds back, gain exclusion deducts (§3.2).
9. **Double-counting check (new):** assert no `input_fact_id` is repeated within one `FactDerivation`'s inputs, and that the base figure's own reconciliation (point 7) shows it as the unadjusted reported number (§3.4).
10. Narration citation completeness — as v1.
11. No uncited causation — as v1.
12. No AI dependency — as v1.

---

## 6. Safe deferrals (unchanged from v1)

`CapitalAllocationSnapshot`; EFP's remaining scope (promoter/ownership-network forensics, governance-flag forensics, event reconstruction, transformation monitoring); ten-year backfill volume and corporate-action adjustments beyond what the Chemplast pass requires; P3-C through P3-G; the Research Orchestrator; US ingestion; Jasch Industries onboarding. All untouched, per every prior approval.

---

## 7. Open questions for owner approval

Only one remains from v1 — the rest (namespace addition, five diagnostic groups, stateless narration shape, D3 threshold) are now confirmed per this review round:

1. Confirm the §4 missing-data/disclosure-cadence conventions (compute only when actually disclosed, never estimated) as stated, or direct a different rule for any specific metric.

---

## 8. What this plan does not do

No code, migration, or service is written. No schema change is applied. No new table, service, abstraction, or dependency is introduced anywhere in this revision — §1's verification confirms the existing `FactDerivationInput`/`Evidence`/`role_label` structures are sufficient for every integrity requirement in §3. No AI/LLM dependency is introduced or implied. The live database is untouched. This plan does not itself authorize Slice B.
