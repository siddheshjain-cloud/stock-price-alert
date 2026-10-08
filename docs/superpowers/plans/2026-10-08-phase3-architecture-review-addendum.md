STATUS: ADDENDUM — SUPERSEDED BY INTEGRATION, PRESERVED AS REVIEW RECORD — DOES NOT AUTHORIZE IMPLEMENTATION

**RESOLUTION (2026-10-08):** the owner reviewed this addendum and accepted its approach in principle, with final refinements. Those refinements are integrated directly into `2026-10-08-phase3-investment-intelligence-foundation-design-proposal.md` (the base proposal, now at its integrated revision). This document is preserved unchanged below as the review record of how that integration was reasoned through — it is no longer the place to look for the current design. Where this document and the integrated base proposal differ (notably: the nine gates are now named and their statuses expanded to five; MID_CYCLE is now explicitly excluded from probability-weighted expected return; the automation boundary now permits future `SYSTEM_DRAFT` rows rather than prohibiting system authorship outright; `CapitalAllocationSnapshot` is explicitly deferred rather than built in Slice B), **the base proposal governs.**

---

# Phase 3 Architecture Review Addendum

**Date:** 2026-10-08
**Amends:** `2026-10-08-phase3-investment-intelligence-foundation-design-proposal.md` (the base proposal — unedited by this document; see §6 for the specific, small edits recommended to it).
**Scope:** architecture reconciliation only, per owner instruction. No migration, model, or service code is created. No field proposed here is applied — every schema item is flagged for the same slice-by-slice owner approval the base proposal already established in its §5.

---

## 1. Two corrections applied

**EFP = Event Forensics Pipeline**, not Evidence→Fact→Proposition. The base proposal's preface (line 18) explicitly flagged its own guess as provisional and asked to be corrected if wrong — it was. EFP covers: event reconstruction, promoter/ownership networks, governance, financial forensics, capital allocation, and transformation monitoring. §2 below reconciles each piece.

**CC+T is two distinct, correctly-named things that must not share an abbreviation:**
- **Causal-Chain + Theme** — this repo's existing World-layer mechanism (Master Roadmap V2 §0.5, not yet built; Theme Intelligence's node chain, North-Star §13). The base proposal's own preface already identified this correctly and it is **preserved unchanged** — Phase 3 does not touch it.
- **Commodity Cycle + Transformation** — your company-research framework: an external commodity/industry cycle component plus a company-internal transformation component. This is **new input**, not a repo concept, and the base proposal's P3-C section did not use "CC+T" at all — it reconciled Cycle Intelligence against Theme Intelligence's node chain instead. That reconciliation target was wrong in one specific way: Theme Intelligence's chain (`Theme → Drivers → Evidence → Industry → Value-chain position → Company/Security → Exposure → Catalyst → Counter-thesis → Changes through time`) has no Transformation node at all. §3 below re-reconciles P3-C against the correct framework.

**Naming-governance recommendation:** reserve the literal string "CC+T" for Causal-Chain+Theme everywhere in this repo (as it already is used in Master Roadmap V2). Spell out "Commodity-Cycle & Transformation" in full in all Phase 3 documents, or use a visually distinct short form if one is needed later. This is a documentation convention, not an architecture change.

---

## 2. EFP reconciliation — six capabilities, zero new models

| EFP capability | Existing/proposed structure | Verdict |
|---|---|---|
| Promoter/ownership networks | `OwnershipSnapshot` (existing, unchanged — `promoter_holding_pct`, `promoter_pledge_pct`, append-only, dated) | **Reuse unchanged** |
| Governance | `GovernanceFlag` (existing, unchanged — `flag_type`, `severity`, company-scoped) | **Reuse unchanged** |
| Financial forensics | `ExtractedFact`/`FactDerivation` under P3-B's `fin.raw.*`/`fin.norm.*` namespace (proposed, extended per §4 Q1 below) | **Reuse, extend** |
| Capital allocation | `CapitalAllocationSnapshot` (already proposed, additive, in base §4 P3-B) | **Reuse as proposed** |
| Event reconstruction | `ResearchProposition`/`PropositionLink` with a forensics-flavored `PropositionStageType` set (e.g. `ALLEGATION_RAISED → REGULATOR_NOTICE → COMPANY_RESPONSE → INVESTIGATION_OUTCOME → REMEDIATION`) — new stage-type *rows*, not a new table, per the existing "new dimensions never need a migration" convention | **Reuse, extend with data, not schema** |
| Transformation monitoring | Same `ResearchProposition` stage-taxonomy mechanism already proven on UNO Minda's Tachi-S JV capacity ramp | **Reuse unchanged — and converges with §3's Transformation dimension below** |

**Finding:** EFP needs no new model. It is a cross-cutting *label* for six capabilities this codebase (via Slices 1–4) and the base proposal (via P3-B) already cover, mostly with existing tables. Recommend P3-B's section header in the base proposal be expanded to read "P3-B — EFP: Event Forensics Pipeline (Financial Normalisation & Forensic Engine)" so this mapping is visible in the document itself rather than implied.

**Convergent finding carried into §3:** EFP's "transformation monitoring" and Commodity-Cycle+Transformation's "Transformation" are the same real-world concept — a company's own internal multi-stage change process (capacity ramp, cost restructuring, product-mix shift). They must be **one mechanism** (`ResearchProposition`), cited from both P3-B and P3-C, not two parallel transformation-tracking structures.

---

## 3. Cycle Intelligence re-reconciled: Commodity Cycle vs. Transformation must be separately citable

**The gap this exposes:** the base proposal's `CompanyExposure` (`exposure_direction: BENEFICIARY|LOSER|MIXED`, free-text `rationale`) lets a thesis blend "the external cycle is turning" and "the company is transforming itself" into one undifferentiated row. §8's own Chemplast trace already does this — "PVC normalization **+ capacity ramp**" is two separable claims bundled into one `InvestmentHypothesis`. Left blended, a later reviewer cannot tell whether a disappointing outcome falsified the cycle call, the transformation call, or both — which weakens the falsifier/kill-switch discipline the base proposal otherwise insists on.

**Recommendation — a contract clarification, not a schema change:** require that wherever an `InvestmentHypothesis` or `ForecastAssumption` cites both a cycle component and a transformation component, it cites them as **two separate provenance entries**, not one blended rationale:
- Cycle-side: `cycle_exposure_id` (external — `CompanyExposure` → `CycleAssessment` → `CycleObservation`, unchanged from base proposal).
- Transformation-side: a `ResearchProposition` id tracking the company's own internal change (reusing the proven stage taxonomy — same mechanism as EFP's transformation monitoring, §2).

This is **zero new tables, zero new columns** — it is a citation-discipline rule for `HypothesisAssumptionService`, enforceable at the acceptance-gate level (a hypothesis citing both a cycle and a company-transformation claim must name both separately) rather than at the schema level. It also directly answers the "industry vs. earnings vs. equity cycle" part of the question:
- **Industry/commodity cycle** = `CycleObservation`/`CycleAssessment`, unchanged.
- **Earnings cycle** (how the company's own reported earnings move through the external cycle) = the Forecast layer's job — already covered by `ForecastAssumption`'s scenario-forking and the `MID_CYCLE` value (§5 below), not a new entity.
- **Equity cycle** (market re-rating) = the Valuation layer's job — already covered by `ValuationRevision`'s scenario tagging, not a new entity.

No new entity is needed for any of the three cycle types. The one real fix is the citation-separation rule above.

---

## 4. Typed financial-observation contract (Q1) — two columns, not a new model

Verified against the live model (`app/models/research_brain.py`): `ExtractedFact.period` is a free-text `String(50)`; there is no first-class `basis` (standalone/consolidated) field — the base proposal's own §3.2 item 2 had conceded basis would live "in the value" as prose; and `supersedes_fact_id` treats "the company restated this number" and "we corrected our own extraction" as the same kind of event.

**Ten-year histories, quarterly/TTM, dilution-adjustment:** all already representable with **zero new fields** — `ExtractedFact` is already one row per `(company_id, fact_type, period)`, and TTM/dilution-adjusted metrics are just another `fin.norm.*` `FactDerivation` (sum-of-four-quarters, bonus/split-adjusted EPS) over existing raw rows, exactly the mechanism already proven on UNO Minda's EBITDA derivation. **Rejecting a new "typed financial-observation" model as unnecessary complexity** — the existing Fact/FactDerivation mechanism already generalizes to this.

**The one genuine gap:** `basis` as a first-class, queryable field, and a `supersede_reason` discriminator. Recommend, for Slice B owner approval (same `SMALL COMPATIBILITY CHANGE` classification as the base proposal's §5 `scenario` column):
- `ExtractedFact.basis: VARCHAR, nullable` (`STANDALONE`|`CONSOLIDATED`), populated only for `fin.*` fact types, `NULL` elsewhere — zero impact on any non-financial Fact.
- `ExtractedFact.supersede_reason: VARCHAR, nullable` (`RESTATEMENT`|`CORRECTION`) on the existing `supersedes_fact_id` link — because "the company restated FY22 revenue down 8%" is itself research-worthy (an EFP-relevant signal), while "we fixed our own extraction" is bookkeeping hygiene; today's single mechanism can't tell a reader which happened.

Both are additive, nullable, narrowly-scoped columns — no backfill risk (consistent with the base proposal's existing zero-rows verification approach), no change to any current reader.

---

## 5. Scenario coherence without `ScenarioSet` (Q4), and `MID_CYCLE` (Q5)

**`ScenarioSet`: rejected.** Point-in-time reconstruction is already sound: `ForecastRevisionAssumption` (base proposal, P3-E) names the exact immutable `ForecastAssumption` row ids behind a given scenario forecast; nothing is mutated after the fact. The only real risk is a *coherence* one — a Bull scenario built today citing fresh cycle data could drift out of sync with a Bear scenario built last week on stale data. That is fixed by a **service-level invariant**, not a new table: `ForecastEngineService.create_scenario_forecast` must stamp every scenario in one coherent family with the same `as_of_date` and require they cite `ForecastAssumption` rows sharing the same `investment_hypothesis_id` revision. A `ScenarioSet` wrapper would only freeze what this rule already makes derivable live by querying `(company_id, as_of_date, investment_hypothesis_id)` — the same "don't freeze what a live query already reconstructs" reasoning the base proposal itself used to justify *not* adding redundant tables elsewhere, and the mirror image of why `CapitalAllocationSnapshot` *was* justified (a rollup that genuinely can't be reconstructed later). Recommend adding this one sentence to P3-A's service-ownership contract; no schema change.

**`MID_CYCLE`: stays a scenario value, not a separate object.** It answers "what does this company earn at an average point in its own cycle" — structurally identical to Bull/Base/Bear (a `ForecastRevision` built from its own `ForecastAssumption` set), differing only in assumption philosophy (through-cycle averaging vs. a discrete scenario). A separate object would duplicate the entire Forecast/Valuation/Assumption chain for no structural gain. This closes the base proposal's open question 4.

---

## 6. `InvestmentCase` reasoning completeness (Q6) and the nine-gate representation (Q2)

**Kill switches and valuation linkage are already adequate** (`InvestmentCaseKillSwitch`, append-only, `triggered_at` set-once; `InvestmentCaseValuation` already links all three scenario valuations). **The gap is "priced-in upside/downside" as a first-class, readable number** — today it would end up buried in free-text `change_reason`, the same anti-pattern P3-D already flagged for `ForecastRevision.assumptions`. Recommend a **read-only query contract**, not a new column, per P3-A's own established pattern: `InvestmentCaseService.get_scenario_return_spread(investment_case_id)`, computed live from the already-linked Bull/Base/MID_CYCLE/Bear `InvestmentCaseValuation` rows against the price as of `as_of_date`. Zero schema change.

**Nine-gate investment assessment:** the specific nine gates are **not defined anywhere in either repo** — this is new input, and I am not inventing nine gate names to fill the silence (the same discipline the base proposal applied to the EFP guess, which is exactly what needed correcting). What *is* answerable without knowing the gate names is the representation pattern: a small new additive link table, `InvestmentCaseGateResult` (`id, investment_case_id, gate_slug, status: PASS|FAIL|WAIVED, rationale, provenance: discriminated-union citation [same idiom as PropositionLink], created_by_user_id, created_at`), with `gate_slug` a controlled vocabulary populated by **data insert, not migration** — the same convention already established for `ResearchDimension`/`PropositionStageType`. This lets Slice G ship the mechanism now and have the owner supply the actual nine gates later as rows, with no further schema change. **Open item for the owner:** name the nine gates before Slice G's acceptance gate is finalized.

---

## 7. Automated refresh vs. human judgment (Q7) — already correctly drawn, make it explicit

The boundary already exists in the schema and in the base proposal's §6 Research Orchestrator contract: Fact-layer writes (`record_fact`, `promote_candidate_finding`, `record_fact_derivation`) are mechanical, append-only, and don't assert interpretation — safe to pipeline. Everything from `InvestmentHypothesis` onward requires `created_by_user_id` and is explicitly never auto-revised by the Orchestrator signal ("never one that silently revises... every actual revision remains a deliberate, reviewer-initiated act"). **No architecture change needed.** Recommend stating this boundary as one explicit sentence in P3-A rather than leaving it implicit: *"Automation ends at Fact/FactDerivation. Every object from InvestmentHypothesis onward is always human-attributed and is never system-authored."*

---

## 8. Three-company acceptance frame

| Company | SPA footprint today | What it exercises |
|---|---|---|
| **Chemplast Sanmar** (`fbc97e85-b038-4b1a-9634-9946a5c706a0`) | Company row exists; `sector`/`industry` null; zero `ResearchRevision`/`ForecastRevision`/`ValuationRevision` rows (verified) | First-time build of the full P3-B→G chain on a shell company — the base proposal's original §8 trace |
| **UNO Minda** (`9cbdabe1-3008-45dc-8ef6-dad859946990`) | Deepest existing research baseline — Slices 1–4's proven EBITDA `FactDerivation` and Tachi-S JV `ResearchProposition` transformation trace already live | Exercises EFP financial-forensics and transformation-monitoring reuse against **real existing data**, and a second, differently-shaped cycle (auto-ancillaries, not PVC) — the second company the base proposal's open question 5 asked for |
| **Jasch Industries** (NSE: JASCHIND) | **Zero footprint** — no `Company`/`Ticker` row, no documents. Confirmed in `scripts/spa_bridge/CANARY_CHECKPOINT.md`: identified as a real, trackable company explicitly flagged "not in the current archive snapshot... needs a one-off check," with document migration deliberately paused pending go-ahead | Tests the **cold-start onboarding seam** (Company/Ticker creation → document ingestion → Fact promotion) that neither other company exercises, using the existing SPA bridge/Research Brain pipeline — no new architecture required, but onboarding itself is a prerequisite action outside this addendum's scope |

---

## 9. Revised acceptance gates

| Slice | Delivers | Acceptance gate (revised) |
|---|---|---|
| **A** | P3-A contracts; `scenario` column; `FinancialMetricDefinition`; **+ the §4 `basis`/`supersede_reason` columns**; **+ the §5 scenario-coherence service rule** | Existing tests pass unchanged with all new columns `NULL`; a disposable fixture proves two scenario rows and two `basis` values coexist without collision |
| **B — EFP (Financial Normalisation & Forensic Engine)** | `fin.raw.*`/`fin.norm.*`; `CapitalAllocationSnapshot`; forensics-flavored `PropositionStageType` rows | **Chemplast:** standalone/consolidated revenue, EBITDA, PAT reconciled with `basis` set. **UNO Minda:** re-express the existing EBITDA derivation and Tachi-S JV trace under the `basis`/forensics stage-type vocabulary with no data loss — proves the extension is backward-compatible with Slices 1–4's output |
| **C — Cycle Intelligence (Commodity-Cycle & Transformation)** | `CycleObservation`, `CycleAssessment`, `CompanyExposure`; **§3's cycle-side/transformation-side separate-citation rule** | **Chemplast:** real PVC `CycleAssessment` with Bull/Base/Bear siblings. **UNO Minda:** a hypothesis citing *both* an auto-ancillary cycle assessment AND the existing Tachi-S transformation `ResearchProposition` as two separate citations — proves the separation rule is enforceable, not just specified |
| **D — Hypothesis & Assumption** | `InvestmentHypothesis`, `ForecastAssumption` | Chemplast hypothesis citing Slice B/C output with 3 scenario-forked assumption sets |
| **E — Forecast Engine** | `ForecastRevisionAssumption`; scenario-forking logic; the §5 coherence invariant enforced in code | 3 coherent scenario-tagged `ForecastRevision`s for Chemplast, all sharing one `as_of_date`/hypothesis revision |
| **F — Valuation Engine** | Scenario-aware valuation (no new table) | 3 scenario-tagged `ValuationRevision`s, each citing its matching `ForecastRevision` |
| **G — Investment View** | `InvestmentCase`, `InvestmentCaseKillSwitch`, link tables; **+ `InvestmentCaseGateResult`**; **+ `get_scenario_return_spread` query contract** | Full Chemplast trace end to end, with upside/downside spread queryable and **the owner-supplied nine gates** recorded with at least one PASS and one FAIL/WAIVED example |
| **Jasch onboarding (prerequisite, not a Phase 3 slice)** | `Company`/`Ticker` row, initial document ingestion, via the existing SPA bridge pipeline | Explicit owner go-ahead to lift the pause noted in `CANARY_CHECKPOINT.md` — not authorized by this addendum |
| **Orchestrator** | Contract only, §6 of base proposal + §7's explicit automation boundary | Not implemented under any circumstances unless separately approved |

---

## 10. Minimal recommended edits to the base proposal (described, not applied)

1. Preface (line 18): replace the provisional EFP/CC+T footnote with the corrected definitions from §1 above, and a pointer to this addendum.
2. P3-B section header: rename to "P3-B — EFP: Event Forensics Pipeline (Financial Normalisation & Forensic Engine)" and add the §2 capability table.
3. P3-C section: re-reconcile against "Commodity-Cycle & Transformation" (new, user-supplied) instead of Theme Intelligence §13; add the §3 cycle-side/transformation-side citation rule.
4. P3-A contracts: add the §5 scenario-coherence sentence and the §7 automation-boundary sentence.
5. §10 open questions: mark Q1 (EFP reading) and Q4 (MID_CYCLE) resolved per this addendum; leave Q2 (scenario column), Q3 (CapitalAllocationSnapshot timing), and Q5 (second acceptance company) as owner decisions, now informed by §8–9 above.
6. §9 acceptance-gate table: replace with §9 of this addendum.

None of these edits are applied to the base proposal file by this addendum. They are listed here for the owner to approve, individually or together, the same way the base proposal's own §5 schema change was isolated for individual sign-off.

---

## 11. Open items requiring owner input (not resolved by this document)

1. Approve or reject the two new columns in §4 (`ExtractedFact.basis`, `ExtractedFact.supersede_reason`).
2. Approve or reject the new `InvestmentCaseGateResult` table in §6, and — separately — **name the actual nine gates** before Slice G's acceptance gate is finalized.
3. Approve, defer, or reject lifting the Jasch Industries onboarding pause noted in `CANARY_CHECKPOINT.md` (a prerequisite for using it as a third acceptance company at all).
4. Confirm the §10-of-base-proposal items not resolved here: `CapitalAllocationSnapshot` timing (Slice B vs. later), and whether UNO Minda + Jasch together now satisfy the "second company" requirement or a further company is still wanted.
5. Approve the five described edits to the base proposal in §10 above, or direct that it remain frozen as originally written with this addendum standing alongside it instead.

---

## 12. What this addendum does not do

No migration, model, or service code is written. No existing table is altered. The base proposal is not edited by this document. No Jasch Industries onboarding, document ingestion, or any other data action is performed. Phase 3 execution does not start.
