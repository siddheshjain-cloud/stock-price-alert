# IKIO Technologies — SPA Research Brain vs. EquiSense Benchmark

**Status:** Comparison analysis only. Does not modify SPA Facts or the EquiSense capture — both source systems remain exactly as frozen.

## Inputs compared

1. **SPA Research Brain (frozen)** — `docs/research_brain/snapshot_a_final_2026-10-07.md` and `snapshot_b_2026-10-07.md` in the `backendtest` repo, backed by the real `instance/trading_app.db`. 8 current `ExtractedFact` rows for IKIO (company_id `c8b839a8-5319-498f-b480-0d6971299094`), each with 1–2 linked `Evidence` rows citing a real `Document`. Boundary: 43 registered IKIO documents, `document_date` 2026-06-27 to 2026-10-06, all 100%-page-extracted into `ExtractionUnit` (including the 292-page FY2026 Annual Report, 815,294 extracted characters).
2. **EquiSense capture (frozen)** — `docs/superpowers/research/equisense-benchmark/2026-10-07-ikio-equisense-capture.md` in this repo, 5 blind queries against `mcp__equisense-research__ask_equisense`.

## Method

For every material EquiSense claim not already matched by an SPA Fact, I went back to SPA's own primary evidence — first the 8 Facts' linked Evidence rows, then, where a claim plausibly came from a document already inside SPA's 43-document corpus, the underlying `ExtractionUnit.content_text` for that document (queried directly from `instance/trading_app.db`), rather than judging plausibility alone. Several EquiSense claims that looked unverifiable turned out to be verbatim-traceable to SPA's own already-extracted Annual Report text — SPA extracted it but never converted it into a Fact. That distinction (extracted-but-not-factified vs. genuinely outside the corpus vs. genuinely wrong) is the spine of this report.

---

## 1. Business Understanding

**Classification: Both, SPA slightly deeper on definitional nuance.**

Both systems independently arrived at the same core picture: pivot from single-client (Signify/Philips) LED lighting ODM toward automotive electronics, wearables/hearables, industrial (Honeywell), and early BESS/BMS; non-lighting mix ~73.5% of Q1 FY27 revenue (SPA: Other Business ₹1,244m / Home Lighting ODM ₹448m of ₹1,693m total, from the Presentation chart = 73.48%/26.46%, matching EquiSense's 73.5%/26.5% to the decimal). Both flag the single Ind AS 108 segment ("Manufacturing of LED Lighting") as a disclosure constraint.

- **SPA-deeper**: SPA treats "Other Business"/"Home Lighting ODM" explicitly as *management-reporting categories*, not a statutory segment, and quantifies the exact gap this creates (see §2). EquiSense describes the same constraint qualitatively ("limits granular statutory disclosure") without quantifying it.
- **EquiSense-deeper**: EquiSense adds export-market color (Forest River/North America RV lighting, Middle East distribution) and named automotive/Honeywell detail (5 Tier-1 aftermarket OEMs, 18–24 month qualification cycles) that is not captured as an SPA Fact, though some is plausibly the same content as SPA's un-factified concall/presentation extraction — not independently verified here since it's outside the 8 Facts.

## 2. Financial Trajectory (Q1 FY2027)

**Classification: Both, with one Conflict EquiSense entirely missed.**

| Metric | SPA (Fact, cited Evidence) | EquiSense | Agreement |
|---|---|---|---|
| Total Revenue | ₹1,693m / ₹169.3 Cr (concall + presentation, both independently corroborating) | ₹169.3 Cr | Match |
| EBITDA | ₹220m / ₹22.0 Cr | ₹22.0 Cr | Match |
| PAT | ₹110m / ₹11.0 Cr | ₹11.0 Cr | Match |

**Conflict EquiSense missed entirely — SPA-only, SPA-deeper:** SPA's `revenue_definition_discrepancy_note` Fact records that the *audited statutory* consolidated "Revenue from operations" for Q1 FY2027 is **₹1,602.89m**, not ₹1,693m — a ~₹90m gap between the number auditors signed off on and the number management presented to the Street. SPA investigated whether a segment note or an "Other income" composition note could bridge it and confirmed it cannot: the statutory filing discloses only the single Ind AS 108 segment, with no sub-line breakdown. Both figures are preserved as genuinely irreconcilable from the available corpus, rather than SPA silently picking one. **EquiSense's response used the ₹169.3 Cr "Total Revenue" figure throughout every one of its five answers and never once surfaced the statutory ₹1,602.89m line or the gap between them.** This is the single most important financial-trajectory miss: EquiSense's entire quarterly growth narrative (41.1% YoY, gross/EBITDA margin calculations) is built on the unreconciled management figure without flagging that an audited number sits ~5.3% lower.

**Internal EquiSense inconsistency, unresolved by SPA (SPA has no Fact covering this):** EquiSense itself states Q1 FY27 EBITDA growth as both "+94.3%" (overview response) and "+94.7%" (concall-summary response) in the same session. SPA's own Evidence independently corroborates ~94% from two sources (concall: "increased 94% year-on-year"; presentation chart 113→220, which computes to +94.69%, i.e. 94.7% is the more defensible rounding) — so where the two EquiSense numbers disagree, SPA's underlying evidence sides with 94.7%, not 94.3%. Classified **Wrong/unsupported** for the 94.3% instance.
EquiSense also stated ROCE as 10.0% (FY26 annual table) in one response and separately "ROCE at 11.8%, ROE at 7.8%" (bear-case response) without reconciling period or basis. **SPA has no ROCE/ROE Fact at all**, so this cannot be adjudicated against SPA evidence — flagged as **Wrong/unsupported, unresolved** (EquiSense-internal, SPA silent).
EquiSense's peer-comparison response gives IKIO "TTM Revenue" as ₹645 Cr, inconsistent with its own FY26 annual-table revenue of ₹595 Cr elsewhere in the same capture. SPA's corpus doesn't contain a TTM figure either (SPA facts are Q1 FY27 and FY2026-point-in-time only) — also **Wrong/unsupported, unresolved**.

## 3. Capacity / Capex

**Classification: EquiSense-only.**

EquiSense gives detailed Block 1/2/3 Noida facility status (Block 1 operational since May 2024; Block 2, 2 lakh sq ft, partially commercialized Q2 FY27, 60% wearables/40% automotive; Block 3/Tower 3 under construction, remaining FY27 capex ₹20–25 Cr) and IPO-proceeds deployment (₹297.3 Cr of ₹326.1 Cr net proceeds deployed).

SPA has **no capacity/capex Fact at all** for IKIO. SPA's only IPO-related Fact (`ipo_net_proceeds_utilization_status`) states total net proceeds of ₹3,261.41m (= ₹326.14 Cr, matching EquiSense's ₹326.1 Cr total) and that CRISIL's Monitoring Agency report found "no deviation from objects" — but SPA's Fact text does not contain a cumulative-deployed-to-date rupee figure. I could not verify EquiSense's specific "₹297.3 Cr deployed" figure against SPA's evidence, because SPA's Evidence quote from `IKIO_REG30_MONITORING_AGENCY_REPORT_13_08_2026` only captures the deviation-check line, not a utilization table that may exist elsewhere in that same document. **This is a plausible EquiSense-deeper data point, but unverified** — it is very likely sourced from a utilization table in the same Monitoring Agency report or the Results filing that SPA read but didn't quote into its Fact.

The Block 1/2/3 facility-status narrative is not traceable to any SPA Fact or Evidence at all; it is **EquiSense-only**, unverified against SPA's corpus in either direction.

## 4. Management Guidance and Commitments

**Classification: EquiSense-only, unverifiable against SPA.**

EquiSense's concall summary (FY27 revenue growth 18–20% maintained despite 41% YoY Q1 print; long-term EBITDA margin target 17–18%; gross margin band 40–42%) is detailed and plausible management-call content, but SPA holds **no Fact of this type** — SPA's three concall-sourced Facts (revenue, EBITDA, PAT) only capture the quarter's actual reported figures, not forward guidance. SPA's Evidence quotes from `IKIO_CONCALL_14_08_2026` are limited to the specific sentences backing those three numeric facts; the guidance language, if present in the same call, was never extracted into a Fact or quoted as Evidence. Cannot be confirmed or refuted from SPA's corpus — a genuine SPA coverage gap, not a contradiction.

## 5. Execution

**Classification: SPA-deeper on IPO/proceeds compliance; EquiSense-deeper on operational narrative.**

SPA's `ipo_net_proceeds_utilization_status` Fact is precise and dual-sourced: company's own Q1 FY27 results filing (₹3,261.41m received) **and** an independent third-party confirmation — CRISIL Ratings' Monitoring Agency Report explicitly stating "Deviation from the objects: Not applicable." This is a clean, corroborated compliance fact with real third-party verification. EquiSense never mentions the Monitoring Agency report or this independent confirmation at all — **SPA-only, SPA-deeper**, and arguably more decision-relevant than EquiSense's capex narrative since it's attested by an independent party, not just management.

EquiSense's automotive/Honeywell qualification-cycle narrative and wearables ODM-mix commentary (not in any SPA Fact) is **EquiSense-only**, unverified.

## 6. Corporate Developments / M&A

**Classification: Both missed a real item; otherwise SPA-only vs. EquiSense-only split.**

- **SPA-only**: the Royalux FZCO (UAE)–Frontline Solutions (Riyadh) MoU for a Saudi Arabia lighting-solutions partnership (`business_development_mou` Fact) — non-binding, no disclosed financial value, 1-year renewable term, 90-day termination notice. **EquiSense never mentions this at all**, despite it being a real, dated (2026-08-10) Reg. 30 disclosure inside what should be EquiSense's own coverage window.
- **Both missed, verified present in SPA's own already-extracted corpus**: page 76 of `IKIO_AR_FY2026` (already 100%-extracted by SPA, never factified) discloses that **IKIO Solutions Private Limited acquired 88% of Gravus Tech Private Limited** (making it a step-down subsidiary) and that **Royalux General Trading LLC was newly incorporated in the UAE** as a further step-down subsidiary. Neither SPA's Facts nor EquiSense's capture mention either event. This is a genuine joint miss on a real corporate-structure/M&A item, and for SPA specifically it is not a sourcing gap — the text was sitting in `extraction_unit` the whole time.

## 7. Governance / Promoter Issues

**Classification: Conflict / SPA-only vs. EquiSense-only, multiple sub-findings — the densest dimension in this benchmark.**

**Both correctly identify** the BGJC & Associates LLP auditor-resignation event in July 2026 as a governance item worth flagging. But the two systems describe **different scopes of the same personnel change**, and each is missing the other's half:

- **SPA's version (Fact `statutory_auditor_governance_event`, SPA-deeper on this specific event)**: BGJC resigned as *Joint Statutory Auditor of three unlisted material subsidiaries only* (Royalux Lighting, IKIO Solutions, Royalux Exports), effective July 24, 2026. SPA's Evidence quotes BGJC's **own** resignation letter stating it was not served proper AGM notice and was not consulted before a joint auditor was appointed alongside it — SPA explicitly classifies this as "a procedural irregularity raised by the auditor itself, not described by the company as an audit-finding dispute," a materially careful distinction. **EquiSense's version conflates/omits this nuance** — it reports the subsidiary resignation but does not characterize whose grievance it was or attribute the procedural complaint to BGJC's own letter.
- **EquiSense's version (EquiSense-only, but verified TRUE against SPA's own unused primary text)**: EquiSense additionally states that Agarwal & Saxena was appointed as the **parent-company** statutory auditor for a 5-year term starting FY27, replacing BGJC & Associates LLP. **I verified this directly against `IKIO_AR_FY2026` (page 43/50/57/61), already inside SPA's extracted corpus**: the 10th AGM notice confirms Agarwal & Saxena's appointment "for a term of five consecutive years... from the conclusion of the 10th AGM until the conclusion of the 15th AGM... in the year 2031," replacing BGJC & Associates LLP at the parent level. **This is a separate, larger governance event (full statutory-rotation-driven auditor change at the parent/holding company, not a subsidiary-level resignation dispute) that SPA completely missed**, despite having the source text already extracted. SPA's `statutory_auditor_governance_event` Fact, read in isolation, materially understates the scope of what actually happened to IKIO's audit arrangements in 2026.

**EquiSense-only, verified TRUE against SPA's unused primary text:**
- "Audit trail (edit log) feature not enabled at the database level" — verified verbatim on pages 215/222/286 of `IKIO_AR_FY2026`. EquiSense's framing ("payroll accounting software") matches the *standalone* note (page 215) precisely; the *consolidated* note (page 222) is broader, naming the Holding Company and all three subsidiaries, not just a payroll module — so EquiSense's claim is accurate but narrower than the full disclosure.
- FY26 employee/worker turnover: permanent employees 49%, permanent workers 43% — verified verbatim (BRSR section, page 92: "Permanent Employees ... Total 49.00%", "Permanent Workers ... Total 43.00%"). **EquiSense under-contextualizes its own correct number**: the same table shows employee turnover was 23.48% in FY2023-24 and 60.47% in FY2024-25 before settling at 49.00% in FY2025-26 — a far more volatile, higher-amplitude trend than a single-year 49% figure conveys, and EquiSense's answer presents no trend at all.
- Inter-corporate loan "₹112.0 Cr... at 8.25% interest" — verified: page 184 of `IKIO_AR_FY2026` shows unsecured loans to subsidiaries of ₹209.50m (Royalux Lighting) + ₹910.50m (IKIO Solutions) = ₹1,120.00m = ₹112.0 Cr exactly, at 8.25% p.a. effective August 1, 2025 (down from 9.5%). EquiSense's figure is correct.
- NSE/BSE "₹10,000 procedural penalties... for delays in RPT filings" — **partially wrong by omission**: verified on pages 76/144 that NSE did fine the company ₹10,000 for a 2-day RPT filing delay, **but the same disclosure states NSE waived the fine on September 22, 2025** (Ref. NSE/LIST/SOP/0995) after the company's waiver application. EquiSense presents this as a live/standing penalty without mentioning the waiver — materially overstates its current governance weight. Classified **Conflict / EquiSense-wrong-by-omission**, traceable directly to SPA's own unused Annual Report text.

**SPA-only**: the promoter-pledge Fact's self-flagged corroboration gap. SPA's `promoter_pledge_status` Fact states the zero-encumbrance declaration itself is **not independently corroborated anywhere else in the corpus** — only the underlying share count (5,60,64,794 shares) is corroborated (Annual Report, postal-ballot scrutinizer report, July 31 results filing). SPA also records that this document had *zero machine-extractable text* (a scanned/signed PDF) and was manually transcribed, with that limitation stated explicitly. EquiSense reports a clean "0.00% pledge" across four quarters with no such caveat and no acknowledgment that this is a single, non-machine-readable source. On this specific point SPA is unambiguously more rigorous.

## 8. Accounting / Disclosure Quality

**Classification: SPA-deeper (quantified), EquiSense-shallower (qualitative only) on the same underlying issue; see §2 for the Conflict.**

Both flag single-segment Ind AS 108 reporting as a disclosure limitation. Only SPA quantifies the consequence (the ₹90m revenue-definition gap) and preserves it as a standing, queryable Fact rather than prose commentary.

## 9. Risks

**Classification: Both, EquiSense broader in count, SPA's items more rigorously sourced.**

EquiSense's risk list (working-capital/cash-conversion weakness, sequential margin compression, semiconductor lead times, conservative guidance vs. Q1 print, subsidiary dependence, valuation vs. return ratios) is broader in breadth than anything in SPA's 8 Facts — **SPA has no working-capital, cash-flow, or valuation Facts for IKIO at all**, so none of this can be cross-checked. This is a straightforward **EquiSense-deeper** dimension, not because SPA is wrong, but because SPA's pilot scope (manual/semi-manual extraction, explicitly no forecasting/valuation per the implementation plan's constraints) never aimed to cover it.

## 10. Material Recent Disclosures

**Classification: SPA-deeper in corpus completeness and recency discipline.**

SPA's boundary explicitly tracks and dates every IKIO filing through 2026-10-06, including routine ones it deliberately did *not* factify (Trading Window closures, the Reg. 74(5) DP compliance certificate) — and separately tracks a "Category-3" held-pending-authorization inventory so that nothing is silently dropped. EquiSense's capture carries no visible awareness of anything after roughly early September 2026 in corporate-action terms (no mention of the Sept 24 Trading Window closure or Oct 6 compliance certificate — though these are routine and immaterial, so this is a minor point, not a thesis-relevant gap).

## 11. Unresolved Questions

**Classification: SPA-only — SPA explicitly tracks unresolved items as first-class citizens; EquiSense does not surface any.**

SPA's frozen snapshot explicitly lists four genuinely unresolved items (the revenue discrepancy; the single-sourced pledge declaration; the single-sourced Saudi MoU; UNO Minda's credit rating being time-boxed to the corpus). EquiSense's output contains no equivalent "here is what we don't know" section anywhere in the five responses — its tone is uniformly declarative even where (per the inconsistencies in §2) its own underlying data is shaky.

---

## Summary Classification Table

| Dimension | Classification |
|---|---|
| Business understanding | Both (SPA slightly deeper on definitional nuance) |
| Financial trajectory | Both + 1 Conflict EquiSense missed (revenue discrepancy) + EquiSense-internal Wrong/unsupported (EBITDA growth %, ROCE/ROE, TTM revenue) |
| Capacity/capex | EquiSense-only, largely unverified |
| Management guidance | EquiSense-only, unverifiable against SPA |
| Execution | SPA-deeper (IPO proceeds, independently verified) / EquiSense-deeper (operational narrative, unverified) |
| Corporate developments/M&A | SPA-only (Saudi MoU) + Both-missed (Gravus Tech acquisition, Royalux UAE incorporation) |
| Governance/promoter issues | Conflict (auditor-change scope: SPA has subsidiary half, EquiSense has parent half, neither has both) + EquiSense-deeper-but-verified (audit trail, turnover, inter-corp loan) + EquiSense-wrong-by-omission (NSE fine waiver) + SPA-deeper (pledge corroboration caveat) |
| Accounting/disclosure quality | SPA-deeper (quantified) |
| Risks | EquiSense-deeper (SPA has no coverage) |
| Material recent disclosures | SPA-deeper (completeness/recency discipline) |
| Unresolved questions | SPA-only |

---

## (1) What SPA Missed

- **The parent-level Agarwal & Saxena auditor appointment** (5-year term, FY27–FY31, replacing BGJC) — a bigger governance story than the subsidiary resignation SPA did capture, sitting unused in SPA's own extracted Annual Report text.
- **FY26 employee/worker turnover (49%/43%)** and its multi-year volatility — fully present in the already-extracted BRSR section, never factified.
- **The audit-trail/edit-log internal-control gap** — present verbatim in the Annual Report's statutory notes, never factified.
- **The ₹112 Cr inter-corporate loan to subsidiaries at 8.25%** — present in the standalone financial notes, never factified.
- **The NSE RPT-filing fine and its subsequent waiver** — present in the Annual Report's secretarial-audit section, never factified (and EquiSense also only got half of this one).
- **The Gravus Tech 88% acquisition and Royalux General Trading LLC (UAE) incorporation** — present in the secretarial audit report, factified by neither system.
- Any forward guidance, capacity/capex detail, or working-capital/cash-flow risk coverage — out of the pilot's declared scope, not an extraction failure, but a real blind spot relative to what a research consumer needs.

## (2) What EquiSense Missed

- **The ₹1,602.89m vs. ₹1,693m statutory-vs-management revenue discrepancy** — the single most consequential miss; EquiSense built its entire financial narrative on the unreconciled, non-statutory figure.
- **The Royalux FZCO–Frontline Solutions Saudi Arabia MoU.**
- **The Gravus Tech acquisition / Royalux UAE incorporation** (missed by both, see above).
- **CRISIL's independent "no deviation from IPO objects" confirmation** as a Monitoring Agency, distinct from and more decision-relevant than a generic capex narrative.
- **The NSE fine waiver** — reported the fine, not its resolution, materially overstating a trivial, closed item.
- **The promoter-pledge declaration's single-source/non-machine-readable nature** — presented a clean 0.00%-pledge figure with no caveat about its evidentiary weakness.
- Any explicit "what remains unresolved" framing.

## (3) Where Either System Was Wrong or Internally Inconsistent

- **EquiSense, internally inconsistent, unresolved by SPA evidence**: Q1 FY27 EBITDA YoY growth stated as both 94.3% and 94.7% (SPA's evidence favors 94.7%); ROCE given as both 10.0% and (separately) implied 11.8%/ROE 7.8% with no period reconciliation; TTM revenue given as both ₹595 Cr and ₹645 Cr.
- **EquiSense, wrong by omission**: reported the NSE RPT-filing fine as a live penalty without disclosing it was waived five weeks after being paid.
- **SPA**: no outright wrong facts found in this benchmark — SPA's one internal self-correction (the EBITDA/Cash-PAT chart column-swap, caught and fixed by visual re-verification before freeze) is documented as resolved, not a residual error. SPA's weaknesses in this benchmark are coverage gaps (facts not derived from already-extracted text), not incorrect facts.

## (4) Which System Was Deeper, By Dimension

- **SPA deeper**: accounting/disclosure-quality precision (quantified revenue discrepancy), IPO-proceeds compliance (independently verified by CRISIL), promoter-pledge evidentiary rigor, material-disclosure completeness/recency tracking, unresolved-questions discipline.
- **EquiSense deeper**: breadth of risk coverage, capacity/capex narrative, forward guidance, peer/competitive positioning, institutional-ownership trend — categories SPA's pilot scope never attempted.
- **Both shallow in the same place**: neither mined the Gravus Tech acquisition or Royalux UAE incorporation out of a document both had access to (SPA literally had it extracted).

## (5) Repeatable Capability Gaps This Reveals in SPA's Research Brain

1. **Extraction-to-Fact conversion is the bottleneck, not extraction itself.** SPA achieved 100% page-level text extraction of all 43 IKIO documents, including the full 292-page Annual Report (815,294 characters) — yet derived zero Facts from the Annual Report. Every governance item EquiSense surfaced and SPA missed (auditor parent-level change, turnover rates, audit-trail gap, inter-corporate loan terms, NSE fine/waiver, the Gravus Tech acquisition) was sitting in SPA's own `ExtractionUnit` rows, unused. The pilot's manual/semi-manual fact-authoring step systematically under-covers dense annual-report-style documents relative to concall/presentation/results documents, which is where all 8 current Facts originated. **This is the single most repeatable, highest-leverage gap**: a document-type-driven coverage bias, not a capability ceiling — the raw material is already there.
2. **No systematic "mine every ingested document for candidate facts" pass exists.** The pilot's fact set appears to have been built by chasing the few most obvious figures (revenue/EBITDA/PAT) and a handful of REG30 attachments that had topically self-evident titles, rather than a document-by-document sweep. The Annual Report, by far the single richest document in the corpus, was read for exactly one narrow purpose (promoter pledge, and only because that document had no machine text to automatically skip past) and not swept for its other ~40 governance/financial-control/related-party disclosures.
3. **No forward-looking fact categories exist yet** (guidance, capacity/utilization targets, capex plans). This isn't a bug in this pilot — it's explicitly out of scope per the implementation plan — but it means SPA's Research View cannot currently answer "what did management say they'll do," which is exactly where an external system like EquiSense is strongest and least verifiable.
4. **No risk/valuation/working-capital fact categories exist yet**, for the same reason. Any benchmark against a general-purpose research tool will structurally show SPA "losing" on breadth in these categories until those fact types are designed — this is a scope gap to plan for, not a quality gap to fix.
5. **SPA's own corroboration discipline is a real, demonstrated strength worth preserving as the system scales**: the promoter-pledge Fact's explicit "not independently corroborated" caveat, and the revenue-discrepancy Fact's explicit "not reconcilable from this corpus" framing, are exactly the behaviors that caught EquiSense in an unqualified, overstated claim (the NSE fine) and an entirely unflagged discrepancy (the revenue gap). As fact-derivation coverage expands to close gap #1, this discipline must scale with it rather than being diluted — the risk of broader coverage is a temptation to assert more facts with less rigor per fact.
6. **A cross-reference/sweep step between `ExtractionUnit` and `ExtractedFact` is the concrete, buildable fix** for gap #1: a pass (semi-manual or tool-assisted) that walks every already-extracted page of every ingested document and flags passages matching known fact-type patterns (governance events, related-party amounts, turnover/attrition disclosures, control-environment qualifications, corporate-structure changes) for human fact-authoring review, rather than relying on the fact-author to already know which document contains what.

**Bottom line**: this benchmark does not show EquiSense "knowing more" about IKIO in any fundamental sense — in every case where EquiSense was ahead, the underlying source material was already sitting inside SPA's own corpus, usually already extracted to the page level. SPA's structural advantages (sourced-at-the-sentence provenance, explicit ambiguity-tracking, independent third-party corroboration) are real and EquiSense lacks them entirely. SPA's gap is coverage depth of its own already-ingested material, not sourcing reach or research rigor.
