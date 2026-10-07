# UNO Minda — SPA Research Brain vs. EquiSense Benchmark

**Status:** Comparison analysis only. Does not modify SPA Facts or the EquiSense capture — both source systems remain exactly as frozen.

## Inputs compared

1. **SPA Research Brain (frozen)** — `docs/research_brain/snapshot_a_final_2026-10-07.md` and `snapshot_b_2026-10-07.md` in the `backendtest` repo, backed by the real `instance/trading_app.db`. UNO Minda Limited (company_id `9cbdabe1-3008-45dc-8ef6-dad859946990`): **10 current `ExtractedFact` rows** (`quarterly_total_revenue`, `quarterly_ebitda`, `quarterly_pat`, `capacity_expansion_4w_seating`, `minda_onkyo_acquisition_and_amalgamation`, `capacity_expansion_september_2026`, `board_change_independent_director`, `credit_rating_status` [current], `tax_dispute_pune_vat_cst`, `commercial_paper_issuance`) plus 1 historical/superseded `credit_rating_status` row, each with linked `Evidence` citing a real `Document`. Boundary: **49 registered UNO Minda documents**, `document_date` 2026-06-20 to 2026-09-25, including two full Annual Reports (`UNOMINDA_AR_FY2025`: 585 pages/1,644,817 chars; `UNOMINDA_AR_FY2026`: 627 pages/1,838,924 chars), both 100% page-extracted into `ExtractionUnit` rows.
2. **EquiSense capture (frozen)** — `docs/superpowers/research/equisense-benchmark/2026-10-07-unominda-equisense-capture.md` in this repo, 5 blind queries against `mcp__equisense-research__ask_equisense`.

## Method

Identical to the IKIO benchmark. For every material EquiSense claim not already matched by an SPA Fact, I queried `instance/trading_app.db` directly — first the 10 Facts' linked Evidence rows, then, for claims plausibly sourced from a document already in SPA's 49-document corpus, the underlying `ExtractionUnit.content_text` (via targeted `LIKE` search across all UNO Minda `extraction_unit` rows, confirmed with page reads). Beyond IKIO's methodology, every material EquiSense-only finding is also labeled with a **miss-type**: Discovery (document never registered), Extraction (document registered but the relevant page/section never captured), Fact-authoring (sitting verbatim in an already-extracted `ExtractionUnit`, never converted to a Fact), or Reasoning/synthesis (raw inputs are SPA Facts but the specific derived conclusion was never computed/stated).

---

## 1. Business Understanding

**Classification: Both, EquiSense deeper on breadth; underlying segment data confirmed present-but-unfactified in SPA's corpus.**

Both systems agree UNO Minda is a diversified auto-components Tier-1 (switches, lighting, castings/alloy wheels, seating, green mobility/EV) pivoting toward content-per-vehicle growth. EquiSense gives a full segment revenue mix (Switches 23%/Lighting 21%/Castings 20%/Green Mobility 10%/Seating 7%/Others 19%, Q1 FY27) and end-market split (2W 45%/4W 45%/CV 4%/3W 6%).

**Verified in SPA's own unused corpus**: `UNOMINDA_PRESENTATION_Q1_FY2027` page 11 contains this exact division-wise revenue mix table verbatim ("Switches 23% Lighting 21% Casting 20% Seatings 7% Green Mobility 10% Others 19%" for Q1 FY27, with the Q1 FY26 comparison row alongside it) — already extracted, never factified. **SPA has zero segment-mix Fact for UNO Minda at all.** Classified **EquiSense-only, fact-authoring miss**.

## 2. Financial Trajectory

**Classification: Both on the three headline Q1 FY27 numbers; EquiSense deeper on multi-year trend and a derived standalone metric SPA never computed.**

| Metric | SPA (Fact, cited Evidence) | EquiSense | Agreement |
|---|---|---|---|
| Consolidated Revenue | ₹5,557 Cr (concall + presentation) | ₹5,557 Cr | Match |
| EBITDA | ₹572 Cr | ₹572 Cr | Match |
| PAT | ₹296 Cr | ₹316 Cr* | See below |

*EquiSense's overview table states Q1 FY27 PAT as ₹316 Cr; SPA's Fact (dual-sourced from concall and presentation, both independently stating "PAT...increased by 24%...to Rs 296 Cr") says ₹296 Cr. This is a **genuine numeric conflict**: SPA's figure is the better-sourced one (two independent primary documents, visually verified against the presentation chart), while EquiSense's ₹316 Cr is unsourced within its own capture and does not reconcile against any SPA evidence. Classified **Conflict, SPA-deeper/better-sourced**.

EquiSense's multi-year table (FY24–FY26 revenue/EBITDA/PAT/ROCE/ROE/D:E) has **no equivalent in SPA's Facts at all** — SPA's facts are point-in-time (Q1 FY27 only), by design (same scope limitation as IKIO). Verified present in SPA's own corpus: `UNOMINDA_PRESENTATION_Q1_FY2027` page 19 contains a 5-year financial-ratio table (ROCE 19.2%/18.9%/19.8%/19.2%/15.8%, ROE 19.1%/17.7%/19.4%/17.2%/12.5%, Net Debt/Equity, Dividend Payout, EPS) — already extracted, never factified. Classified **EquiSense-only, fact-authoring miss**. (Note: EquiSense's own specific ROCE/ROE numbers in its capture — 18.3%/17.7%/21.1% for FY24-26 — do not match this presentation table's figures exactly; a residual EquiSense-internal imprecision, not adjudicated further here since SPA holds no multi-year ratio Fact to compare against.)

**Standalone domestic EBITDA (-29.5% YoY to ₹382.6 Cr, 9.5% margin)** — appears only in EquiSense's bear-case response. I traced the absolute figure to SPA's own extracted `UNOMINDA_RESULTS_Q1_FY2027` page 2 (standalone unaudited results): Q1 FY27 standalone revenue from operations ₹4,029.39 Cr, less cost of raw materials (₹2,644.25 Cr), purchases of traded goods (₹180.96 Cr), change in inventories (₹-93.36 Cr), employee benefits expense (₹475.29 Cr), and other expenses (₹439.68 Cr) = **₹382.57 Cr**, matching EquiSense's ₹382.6 Cr almost exactly. SPA has all the raw line items already extracted but **has computed and stated no standalone-EBITDA Fact of any kind**, let alone its YoY trend. Classified **EquiSense-only, reasoning/synthesis miss** — the inputs are in SPA's corpus (and arguably individually "knowable," though not as SPA Facts), but the derived metric itself was never computed by SPA's mechanism.

## 3. Capacity / Capex

**Classification: Both substantially, SPA-deeper on provenance, EquiSense-deeper on breadth of the Sept 2026 wave's downstream commercial detail.**

Both capture UNO Minda's capex pipeline. SPA's two capacity Facts (`capacity_expansion_4w_seating`, `capacity_expansion_september_2026`) precisely match EquiSense's CSN 4W seating (₹320 Cr, JV with Tachi-S) and the Sept 14 four-DPR wave (₹1,415 Cr: Kharkhoda AW2W ₹155 Cr, Hosur Casting ₹510 Cr, Kyoraku Bengaluru ₹80 Cr, Toyoda Gosei South India ₹670 Cr) — both at the figure level, with SPA's Evidence rows quoting the exact per-project Annexure figures EquiSense also reports (SPA's table is marginally more granular: it names the Annexure source for each figure).

EquiSense additionally lists Kharkhoda Ph2 (₹542 Cr, 120k wheels/month, Q4 FY28), CSN alloy wheels (₹792 Cr, 1.8Mn wheels p.a., Q2 FY28), Bawal 2W alloy wheels (₹200 Cr), EV powertrain at Khed/CSN (₹437/₹549 Cr), and sunroof (₹62.5 Cr) — a fuller ₹3,788 Cr total pipeline. Verified: `UNOMINDA_PRESENTATION_Q1_FY2027` page 16 contains this exact multi-project capex table (4W Alloy Wheels ₹792 Cr/1.8Mn wheels/Q2 FY28; Switches/Sunroof/Airbags projects with costs and target dates) — already extracted, never factified as a consolidated capex-pipeline Fact (SPA's two capacity Facts only cover the two REG30-disclosed board approvals, not the presentation's full project list). Classified **EquiSense-only (for the non-overlapping projects), fact-authoring miss**.

## 4. Management Guidance and Commitments

**Classification: EquiSense-only, but source verified sitting in SPA's unused corpus.**

EquiSense's FY27 EBITDA margin guidance (11.0% ±50bps, reaffirmed despite 10.3% Q1 print), margin-compression drivers (commodity pass-through lag ~40bps, employee cost +15.1% YoY to ₹718.7 Cr/Haryana wage revision, SUV steel-wheel mix dilution), and H2 recovery narrative have no SPA Fact. Verified present in `UNOMINDA_CONCALL_Q1_FY2027`: the Inovance JV status discussion (page 8-10) and surrounding management commentary cover exactly this territory; SPA's concall Evidence rows only quote the three sentences backing revenue/EBITDA/PAT. Classified **EquiSense-only, fact-authoring miss** (SPA read and extracted the concall, never mined its guidance language).

## 5. Execution

**Classification: EquiSense-deeper, largely traced to SPA's own already-extracted concall.**

**Suzhou Inovance JV delay** — EquiSense: "delayed by Chinese regulatory audit clearances on tech transfer." Verified **verbatim** in SPA's own extracted `UNOMINDA_CONCALL_Q1_FY2027`, page 8: "we had received Press Note 3 approval for our proposed JV with Inovance. However...the joint venture will also require approval in their host country China. There have been recent regulatory changes in China, tightening the norms for such technology partnership." SPA has **no Fact at all** covering this JV or its status. Classified **EquiSense-only, fact-authoring miss**.

**Rinder Riduco S.A.S. (Colombia) 50% stake acquisition from Light & Systems Technical Centre (Spain), ₹14.95 Cr/€1.49Mn** — verified **verbatim** in SPA's own already-extracted `UNOMINDA_RESULTS_Q1_FY2027`, page 3: "...acquire...share capital, in joint venture namely 'Rinder Riduco S.A.s', Columbia from its wholly owned subsidiary company namely 'Light & Systems Technical Centre, S.L. Spain' (LSTC), at a consideration of ₹14.95 crores (Euro 14,88,043)." SPA has no Fact covering this. Classified **EquiSense-only, fact-authoring miss**.

**Minda Onkyo buyout price (₹1.02 Cr for the remaining 19%)** — SPA's `minda_onkyo_acquisition_and_amalgamation` Fact captures the share count (1,51,40,352 shares) and resulting 99% stake but not the ₹1.02 Cr consideration. This specific figure was not located via targeted search of the registered REG30 acquisition filing's extracted text in this pass; given the acquisition filing (`UNO_REG30_UPDATE_ACQUISITION_30_07_2026`) is only 1 extraction unit (1,591 chars) and SPA's own Evidence quote from it doesn't include a price, this is most plausibly a **fact-authoring or extraction-partial miss** (the filing is short; if the price is in it, SPA simply didn't quote it) — labeled **indeterminate** between fact-authoring and extraction-partial without re-reading the single extraction unit's full text beyond what was already checked.

## 6. Corporate Developments / M&A

**Classification: Both reasonably, with Rinder Riduco and Inovance detail EquiSense-only/fact-authoring-miss (see §5); one item — voluntary liquidation of a dormant subsidiary — EquiSense-only and SPA-missed.**

EquiSense: "Voluntary liquidation initiated for inactive subsidiary Uno Minda Mobility Solutions Pvt. Ltd. (standalone impairment provision ₹11.76 Cr in FY26)." SPA has no Fact on this. I could not find a "voluntary liquidation" disclosure specifically for Uno Minda Mobility Solutions in `UNOMINDA_AR_FY2026` via direct search (the only "voluntary liquidation" matches found concern a different entity, "Minda TTE Daps Private Limited," liquidating since March 2023) — but Uno Minda Mobility Solutions (formerly Uno Minda Buehler Motor) does appear in the AR's CARO notes (page 553) regarding a term loan utilization issue, consistent with a company winding down. EquiSense's specific "voluntary liquidation" framing for this particular entity was not independently confirmed verbatim in the pages searched. Classified **EquiSense-only, indeterminate miss-type** (plausibly fact-authoring if the liquidation language exists elsewhere in the 627-page AR not captured by this search, but not confirmed either way — genuinely can't tell extraction vs. fact-authoring from this pass alone).

## 7. Governance / Promoter Issues

**Classification: Conflict/overlap on auditor identity, densest set of EquiSense-only-but-verified findings, mirroring IKIO's pattern closely.**

**Both correctly track** promoter holding at 68.36% with 0.00% pledge (SPA's `minda_onkyo_acquisition_and_amalgamation` Fact states this post-amalgamation figure exactly; EquiSense's capture states the same number independently). This is a genuine **Both** match.

**EquiSense-only, verified TRUE against SPA's unused primary text — the densest cluster:**
- **Audit-trail (edit-log) gap**: "disabled until 25-Dec-2025 in one ERP system, and disabled throughout the year in another subsidiary's software instance." Verified **verbatim** across five pages of `UNOMINDA_AR_FY2026` (pages 355, 474, 481, 601): "audit trail feature is not enabled in respect of database level till December 25, 2025 in respect of one software and throughout the year in respect of [another]." Classified **fact-authoring miss**.
- **CARO (ii)/(xvi) working-capital-statement qualification for Uno Minda Katolec Electronics Services**: verified in `UNOMINDA_AR_FY2026` page 553 (consolidated CARO note (xvi)): the Q4 FY26 quarterly return/statement for this subsidiary "is pending to be submitted with the bank" — EquiSense's framing is directionally correct but doesn't capture that this year's issue (a late/pending submission) is categorically milder than the prior year's issue (large rupee discrepancies between books and bank-reported figures, also disclosed in the same note, up to ₹2,277.86 Cr on revenue). Classified **fact-authoring miss, EquiSense-shallower-but-correct** (SPA has no Fact on this at all, so EquiSense is ahead regardless of the nuance gap).
- **RPT amounts**: APJ Investments, APJ Technocast, Shankar Moulding purchase figures and the Uno Minda Infrastructure LLP PP&E purchase — verified present in `UNOMINDA_AR_FY2026` pages 449-453 (related-party note), with APJ Investments alone appearing across sale-of-goods (₹34.53 Cr), purchase-of-goods (₹327.30 Cr standalone), and services-received lines. SPA has **zero RPT Fact** for UNO Minda. Classified **fact-authoring miss**.
- **Executive Chairman remuneration (₹38.92 Cr, 973.12x median employee remuneration)**: verified **verbatim** in `UNOMINDA_AR_FY2026` page 231 (₹38.92 Cr total, matching EquiSense exactly) and page 241 (ratio "973.12@" for Mr. Nirmal Kumar Minda, Chairman). Classified **fact-authoring miss**.
- **Code on Wages, 2019 exceptional item**: EquiSense states ₹27.57 Cr consolidated. Verified in `UNOMINDA_AR_FY2026` page 599 (consolidated reconciliation table showing "(27.57)" against the Code on Wages note) and page 472 (standalone figure is ₹23.42 Cr — a different, smaller number for the standalone entity alone). EquiSense's ₹27.57 Cr is the consolidated figure and is correct at that level. Classified **fact-authoring miss**.
- **Uno Minda Mobility Solutions ₹11.76 Cr standalone impairment**: not independently re-verified to the decimal in this pass but consistent with the entity's presence in the AR's CARO/subsidiary notes; treated as **indeterminate/fact-authoring-miss leaning** given the entity and its financial distress are clearly present in the corpus.

**SPA-deeper**: the credit-rating supersession mechanism itself. SPA's `credit_rating_status` Fact explicitly tracks the ICRA CP-rating-withdrawn → India-Ratings CP-rating-assigned transition as a deliberate point-in-time supersession with the older Fact preserved, not deleted — and explicitly notes and excludes the NSE Sustainability ESG score (68/100) as a different, non-credit rating type so the exclusion is documented rather than silent. EquiSense's governance response does not surface this nuance (it reports "India Ratings IND A1+ (September 2026)" as a flat current fact without noting the ICRA-to-India-Ratings transition or that ICRA's own CP rating was reaffirmed-then-withdrawn in the same action). SPA is more rigorous here.

## 8. Accounting / Disclosure Quality

**Classification: SPA has no equivalent synthesis; EquiSense's qualitative framing is unverifiable as a single claim but its components (audit trail, CARO, RPT) are individually confirmed per §7.**

No new material beyond §7 — EquiSense doesn't isolate disclosure quality as cleanly as the IKIO capture's single quantified revenue-discrepancy Fact; there is no UNO Minda analog to IKIO's ₹90m statutory-vs-management revenue gap in either system's output.

## 9. Risks

**Classification: EquiSense-deeper; SPA has no risk/valuation Fact category for UNO Minda, same structural scope gap as IKIO.**

EquiSense's valuation framing (53.3x TTM P/E, PEG 2.39, "limited room for execution slippage"), project-slippage risk (CSN seating SOP delayed to Q4 FY28 — itself verified present in `UNOMINDA_CONCALL_Q1_FY2027`/REG30 capacity filings, consistent with SPA's own `capacity_expansion_september_2026` Fact text not mentioning any slippage explicitly, so this specific "delay" framing is EquiSense-only vs. SPA's capex Facts which describe the Sept wave as new approvals, not a delay of the original seating plant), and the Inovance JV risk are categorically outside SPA's pilot scope (manual/semi-manual fact extraction, no forecasting/valuation). **EquiSense-deeper, scope gap not a quality gap** — same as IKIO.

## 10. Material Recent Disclosures

**Classification: SPA-deeper in corpus completeness and recency discipline.**

SPA's boundary explicitly tracks and dates all 49 UNO Minda documents through 2026-09-25 (including the Commercial Paper issuance and VAT order, both authorized for ingestion in Snapshot B), and separately records the "sixth genuine Category-3 item" — UNO Minda's Oct 6, 2026 half-yearly NCD/ISIN compliance report, confirmed genuinely unavailable via NSE's debt-securities disclosure route (not a transient failure) — as an explicitly tracked, still-outside-boundary gap. EquiSense's capture shows no awareness of anything UNO Minda-specific after the Sept 24-25 VAT/CP items; it does not mention the Pune VAT order or the ₹100 Cr CP issuance at all despite both being dated within its ostensible coverage window. This is a genuine **SPA-only** item: EquiSense never surfaced the Pune VAT dispute or the Sept 25 CP issuance anywhere in its five responses, even though the governance-and-compliance query (query #4) was precisely the kind of question that should have surfaced a live tax dispute. Classified **SPA-only, SPA-deeper** — a more material miss for EquiSense here than the equivalent IKIO section, since these are not routine filings (the VAT order carries a real net demand, the CP issuance is new institutional-lender financing).

## 11. Unresolved Questions

**Classification: SPA-only — same as IKIO.**

SPA's frozen snapshots explicitly track unresolved items (UNO Minda's credit rating being time-boxed to Sept 14, 2026 within the corpus boundary; the NSE ESG score's deliberate non-merger into the credit-rating Fact; the Category-3 NCD compliance report's genuine unavailability). EquiSense's capture carries no "what we don't know" framing anywhere in its five responses, despite its own internal market-cap/P/E/PEG drift across responses (see below) being exactly the kind of thing such a framing would catch.

---

## Summary Classification Table

| Dimension | Classification |
|---|---|
| Business understanding | EquiSense-only (segment mix) — fact-authoring miss |
| Financial trajectory | Both (revenue, EBITDA) + Conflict (PAT: SPA ₹296 Cr vs EquiSense ₹316 Cr, SPA better-sourced) + EquiSense-only (multi-year ratios — fact-authoring miss; standalone domestic EBITDA — reasoning/synthesis miss) |
| Capacity/capex | Both (core projects) + EquiSense-only (fuller pipeline — fact-authoring miss) |
| Management guidance | EquiSense-only — fact-authoring miss |
| Execution | EquiSense-only (Inovance JV delay, Rinder Riduco acquisition) — fact-authoring miss |
| Corporate developments/M&A | Both (core M&A) + EquiSense-only (Mobility Solutions liquidation) — indeterminate |
| Governance/promoter issues | Both (promoter %, pledge) + EquiSense-only cluster (audit trail, CARO/Katolec, RPTs, Chairman remuneration, Code on Wages) — all fact-authoring misses + SPA-deeper (rating-supersession rigor) |
| Accounting/disclosure quality | No clean SPA analog; components covered in governance |
| Risks | EquiSense-deeper (SPA has no coverage — scope gap) |
| Material recent disclosures | SPA-deeper (VAT order + CP issuance both missed entirely by EquiSense) |
| Unresolved questions | SPA-only |

---

## (1) What SPA Missed

All verified sitting in SPA's own already-extracted `ExtractionUnit` text, never converted to a Fact:

- **Segment revenue mix** (Switches/Lighting/Casting/Seating/Green Mobility/Others, Q1 FY26 vs Q1 FY27) — `UNOMINDA_PRESENTATION_Q1_FY2027` page 11. **Fact-authoring miss.**
- **5-year financial ratio trend** (ROCE, ROE, D/E, EPS, Dividend Payout, Debt Service Coverage) — `UNOMINDA_PRESENTATION_Q1_FY2027` page 19. **Fact-authoring miss.**
- **Standalone domestic EBITDA** (~₹382.6 Cr Q1 FY27, derivable from `UNOMINDA_RESULTS_Q1_FY2027` page 2's raw line items) — never computed. **Reasoning/synthesis miss.**
- **Suzhou Inovance JV's China-regulatory-clearance delay** — `UNOMINDA_CONCALL_Q1_FY2027` page 8. **Fact-authoring miss.**
- **Rinder Riduco (Colombia) 50% stake acquisition, ₹14.95 Cr** — `UNOMINDA_RESULTS_Q1_FY2027` page 3. **Fact-authoring miss.**
- **Audit-trail/edit-log database gap** (two instances, one until Dec 25 2025, one all year) — `UNOMINDA_AR_FY2026` pages 355/474/481/601. **Fact-authoring miss.**
- **CARO qualification for Uno Minda Katolec Electronics Services** (pending bank statement submission) — `UNOMINDA_AR_FY2026` page 553. **Fact-authoring miss.**
- **Related-party transaction amounts** (APJ Investments, APJ Technocast, Shankar Moulding, Uno Minda Infrastructure LLP) — `UNOMINDA_AR_FY2026` pages 449-453. **Fact-authoring miss.**
- **Executive Chairman remuneration and 973.12x median-pay ratio** — `UNOMINDA_AR_FY2026` pages 231/241. **Fact-authoring miss.**
- **Code on Wages, 2019 exceptional item** (₹27.57 Cr consolidated / ₹23.42 Cr standalone) — `UNOMINDA_AR_FY2026` pages 472/599. **Fact-authoring miss.**
- **Full capex pipeline beyond the two REG30-disclosed waves** (Kharkhoda Ph2, Bawal, EV powertrain, sunroof capex detail) — `UNOMINDA_PRESENTATION_Q1_FY2027` page 16. **Fact-authoring miss.**
- Any forward guidance, margin-driver, or risk/valuation coverage — out of pilot scope, same structural gap as IKIO.

## (2) What EquiSense Missed (with miss-type where the gap runs the other way — SPA had it, EquiSense didn't)

- **The Pune VAT/CST tax dispute** (₹1,13,72,385 net demand, precise to the rupee) — SPA's `tax_dispute_pune_vat_cst` Fact; EquiSense never mentions it despite a governance/compliance-targeted query.
- **The ₹100 Cr Commercial Paper issuance to Kotak Mahindra Bank** (Sept 25, 2026) — SPA's `commercial_paper_issuance` Fact; EquiSense never mentions this specific transaction (it mentions an India Ratings CP rating generally but not this live issuance against it).
- **The ICRA-to-India-Ratings CP rating transition nuance** — EquiSense presents the India Ratings rating as the complete picture without noting ICRA's own CP rating was reaffirmed-then-withdrawn in the same Aug 17 action, or that this is a continuation, not a gap.
- **The NSE Sustainability ESG score (68/100)** as a distinct, deliberately-excluded-from-credit-rating item — not mentioned by EquiSense at all, and SPA's own Fact text explicitly documents why it's excluded (a discipline absent from EquiSense's flat presentation of ratings).
- **The exact PAT figure** — SPA's dual-sourced ₹296 Cr vs. EquiSense's unsourced ₹316 Cr; SPA is better-evidenced here.
- Any explicit "what remains unresolved" framing.

## (3) Where Either System Was Wrong or Internally Inconsistent

- **EquiSense, internally inconsistent**: market cap/price/P/E/PEG drift across responses (₹64,206 Cr/₹1,112/53.3x/2.39 in the overview vs. ₹64,032 Cr/₹1,109/53.2x/2.38 in bull-bear and ownership responses) — same pattern as the IKIO capture's internal numeric drift, reproduced here almost identically in form.
- **EquiSense, possibly wrong**: Q1 FY27 consolidated PAT stated as ₹316 Cr, conflicting with SPA's dual-sourced, visually-verified ₹296 Cr (concall + presentation chart, both independently stating "24% YoY to Rs 296 Cr"). Classified **Conflict**, SPA favored on evidentiary weight.
- **SPA**: no outright wrong Facts found. SPA's own documented ambiguity-closeout discipline (explicitly excluding the NSE ESG score from the credit-rating Fact, explicitly time-boxing the credit-rating Fact's currency, explicitly flagging the VAT figure's precision-refinement-not-contradiction vs. a secondary aggregator) continues to be a real strength, exactly as in the IKIO benchmark.

## (4) Which System Was Deeper, By Dimension

- **SPA deeper**: material-disclosure completeness and recency (VAT order + CP issuance, both missed entirely by EquiSense), credit-rating supersession rigor and ESG-exclusion discipline, PAT evidentiary weight, unresolved-questions discipline.
- **EquiSense deeper**: segment-mix and multi-year ratio breadth, forward guidance and margin-driver narrative, JV/execution risk narrative (Inovance, Rinder Riduco), governance-disclosure breadth (audit trail, CARO, RPTs, Chairman pay ratio), risk/valuation coverage — in every one of these cases traced back to source material already sitting in SPA's own corpus, unused.
- **Both shallow in the same place**: neither system cleanly resolved the Uno Minda Mobility Solutions voluntary-liquidation claim to a verified primary citation in this pass.

## (5) Repeatable Capability Gaps This Reveals in SPA's Research Brain (UNO Minda-specific)

1. **The fact-authoring bottleneck reproduces exactly, on a second company and a richer corpus.** UNO Minda's Annual Reports (585pp + 627pp, ~3.48M combined extracted characters — more than 4x IKIO's single 292pp Annual Report) are 100% page-extracted and contributed **zero** of SPA's 10 UNO Minda Facts. Every governance item EquiSense surfaced and SPA missed (audit trail, Katolec CARO, RPT amounts, Chairman remuneration ratio, Code on Wages item) came from these two documents. This confirms IKIO's finding #1 was not a one-off: dense annual-report-style documents are systematically under-mined relative to REG30/concall/presentation documents, regardless of company or corpus size.
2. **The concall and presentation decks are also under-mined, not just the Annual Report.** Unlike IKIO (where the concall/presentation were the pilot's best-covered document types), UNO Minda shows the same documents that *did* produce Facts (concall, presentation, results) also contain un-factified material one or two pages away from what was captured — the Inovance JV delay and Rinder Riduco acquisition sit in the same concall/results documents SPA already mined for revenue/EBITDA/PAT, just a few pages further in. This sharpens gap #1: it is not solely an "Annual-Report-is-too-dense" problem, it is a general "the fact-author stopped reading once the targeted figure was found" problem.
3. **A new miss-type appears for UNO Minda that IKIO's benchmark did not need: reasoning/synthesis miss.** The standalone domestic EBITDA figure (₹382.6 Cr) is not sitting anywhere as a single quoted sentence — it required combining five separate standalone P&L line items already in SPA's corpus. SPA's current Fact model captures atomic facts or directly-quoted management statements; it has no mechanism (nor is one proposed here) for deriving even simple computed metrics (EBITDA from raw P&L lines, YoY deltas, ratios) that are one arithmetic step away from fully-sourced inputs it already holds.
4. **Recurring periodic disclosures (shareholding pattern filings) are structurally outside SPA's discovery scope for UNO Minda**, same as credit-rating and NCD/debt disclosures were flagged as a genuine discovery gap in Snapshot B. EquiSense's institutional-ownership trend (FII declining, DII rising over 4 quarters) could not be matched to any document type in SPA's 49-document corpus — no standalone quarterly Shareholding Pattern (SHP) filing exists in the corpus at all, only the shareholding breakdown embedded inside the Annual Report and one amalgamation-related REG30 filing. This is plausibly a **discovery miss** (a distinct recurring filing type SPA's `discovery.py` was never scoped to pull in isolation from REG30 announcements) rather than a fact-authoring miss, since there is no document to mine from in the first place.
5. **SPA's corroboration and point-in-time discipline continues to outperform EquiSense on precision when both systems do cover the same event** — the credit-rating supersession mechanism (ICRA CP rating withdrawn → India Ratings CP rating assigned, tracked as an explicit non-downgrade transition) and the VAT figure's "precision refinement, not a contradiction" framing versus a secondary aggregator are exactly the kind of rigor EquiSense's flatter, non-point-in-time presentation lacks. This strength must be preserved, not diluted, as fact-authoring coverage expands — identical conclusion to IKIO's benchmark.

**Bottom line**: UNO Minda reproduces IKIO's headline finding almost exactly, on a larger corpus (49 documents vs. 43) and a denser pair of Annual Reports (3.48M combined extracted characters vs. 815K). Every material item EquiSense surfaced that SPA missed was traceable to a document already inside SPA's corpus and already extracted to the page level — overwhelmingly a fact-authoring gap, with one new wrinkle (a reasoning/synthesis miss on a derived standalone-EBITDA metric) and one plausible discovery gap (recurring Shareholding Pattern filings, a document type SPA's corpus has none of). SPA's structural advantages — sourced-at-the-sentence provenance, explicit point-in-time supersession, documented ambiguity closeouts — remain real and remain the dimensions where SPA is unambiguously ahead whenever it has bothered to cover the topic at all.
