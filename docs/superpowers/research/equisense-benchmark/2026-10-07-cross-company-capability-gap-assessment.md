# Cross-Company Capability Gap Assessment — SPA Research Brain vs. EquiSense

**Status:** Synthesis of two independent benchmarks (IKIO Technologies, UNO Minda Limited). Does not modify either company's SPA Facts, either EquiSense capture, or either benchmark report. This document names and prioritizes capability gaps only — it does not design, propose, or specify any fix, tool, sweep process, or schema change for any of them.

## Inputs

1. `2026-10-07-ikio-spa-vs-equisense-benchmark.md` — IKIO Technologies, 8 current SPA Facts over a 43-document corpus (292pp Annual Report, 815,294 extracted characters).
2. `2026-10-07-unominda-spa-vs-equisense-benchmark.md` — UNO Minda Limited, 10 current SPA Facts over a 49-document corpus (two Annual Reports, 585pp + 627pp, 1,644,817 + 1,838,924 = 3,483,741 extracted characters combined).

---

## (a) Side-by-side comparison of findings

| | IKIO | UNO Minda |
|---|---|---|
| SPA Facts (current) | 8 | 10 (+1 historical/superseded) |
| Corpus size | 43 documents | 49 documents |
| Richest document(s) | 1 Annual Report, 292pp / 815K chars | 2 Annual Reports, 585pp+627pp / 3.48M chars combined |
| Facts derived from the Annual Report | 0 | 0 |
| Dominant EquiSense-ahead pattern | Governance/related-party items sitting unused in the AR | Governance/related-party items sitting unused in the AR, plus execution items unused in the *already-mined* concall/results |
| Material Conflict found | Statutory vs. management revenue (₹1,602.89m vs ₹1,693m) — EquiSense missed it entirely | PAT ₹296 Cr (SPA, dual-sourced) vs ₹316 Cr (EquiSense, unsourced) |
| EquiSense internal inconsistency | EBITDA growth % (94.3% vs 94.7%), ROCE/ROE conflicting, TTM revenue conflicting | Market cap/price/P/E/PEG drift across responses (same shape as IKIO) |
| Corporate items both systems missed | Gravus Tech 88% acquisition, Royalux UAE incorporation (both in AR, neither factified nor EquiSense-surfaced) | Uno Minda Mobility Solutions voluntary liquidation (indeterminate — not confirmed verbatim in either system's source) |
| Where SPA beat EquiSense on live/recent items | Saudi MoU (EquiSense never mentioned); CRISIL Monitoring Agency independent confirmation | Pune VAT dispute and ₹100 Cr CP issuance (EquiSense mentioned neither, despite a governance-targeted query) |
| New miss-type needed beyond "fact-authoring" | Not needed — all misses were fact-authoring or genuinely out-of-scope | Reasoning/synthesis miss (standalone EBITDA, a derived metric from already-extracted raw lines) and a plausible discovery miss (no Shareholding Pattern filing type in corpus) |

## (b) Repeatable/systemic gaps vs. company-specific/one-off gaps

**Repeatable across both companies (systemic):**

1. **Dense annual-report-style documents are 100% extracted and 0% factified.** True for IKIO's single AR and both of UNO Minda's ARs. This is the single most consistent finding across both benchmarks and is not attributable to corpus size, industry, or document count — it reproduced at nearly 4x the extracted-text volume for UNO Minda.
2. **Governance/related-party/control-environment disclosures are the specific content type most reliably missed** inside those dense documents: audit-trail (edit-log) gaps, CARO qualifications, related-party transaction tables, KMP/Chairman remuneration ratios. This exact cluster of disclosure types repeated near-identically in both companies' Annual Reports and in both cases was the dominant content of EquiSense's governance-query advantage.
3. **EquiSense's own internal numeric inconsistency is a repeatable pattern, not a one-off.** Both captures show unreconciled drift in valuation metrics (market cap/price/P/E/PEG) across different queries in the same session, and both show at least one instance of EquiSense stating two different values for the same metric without flagging the discrepancy itself (IKIO: EBITDA growth %, ROCE/ROE, TTM revenue; UNO Minda: the valuation cluster). SPA, in both benchmarks, produced no outright wrong Facts — its errors were coverage gaps, not incorrect assertions.
4. **SPA's corroboration and point-in-time discipline is a repeatable strength, not a one-off.** Both benchmarks show SPA Facts explicitly documenting what is NOT corroborated (IKIO's promoter-pledge single-sourcing; UNO Minda's VAT-figure precision-refinement note) and explicitly managing supersession without deletion (IKIO's none; UNO Minda's credit-rating ICRA→India-Ratings transition, documented as continuation not a gap). EquiSense exhibits no equivalent behavior in either capture.
5. **No forward-guidance, risk, or valuation fact categories exist in either company's Research View.** This was flagged as explicitly out-of-scope in the IKIO benchmark and reproduced identically for UNO Minda — a scope gap known in advance, not a quality defect, but one that will make SPA structurally "lose" on breadth against any general-purpose research tool until addressed.
6. **SPA fully extracts documents it does mine for Facts, then reads them narrowly.** Both companies show this: the fact-author finds the figure it's looking for (revenue/EBITDA/PAT in a concall or results filing) and does not continue reading the same already-open document for adjacent material. IKIO's Royalux/Gravus item and UNO Minda's Inovance-JV-delay and Rinder-Riduco items are both cases where the missed information was pages away from content that *did* get factified, inside the same document.

**Company-specific / one-off (not yet shown to be systemic):**

1. **The statutory-vs-management revenue Conflict (IKIO only).** UNO Minda's revenue figures matched cleanly across concall, presentation, and (implicitly) results; no equivalent discrepancy surfaced. This appears tied to IKIO's specific segment-reporting structure (single Ind AS 108 segment with a management-reporting overlay), not a general pattern — one data point, not yet evidence of a repeatable issue.
2. **The reasoning/synthesis miss-type (UNO Minda only, so far).** IKIO's benchmark did not surface any case requiring this classification — every IKIO gap was either fact-authoring or genuinely out-of-scope. UNO Minda's standalone-EBITDA case is the only instance of this miss-type across both benchmarks. One occurrence is not enough to call this systemic yet, though it is a plausible candidate given how many financial metrics are computed from already-extracted raw lines in principle.
3. **The discovery-gap candidate for recurring Shareholding Pattern filings (UNO Minda only).** IKIO's benchmark did not surface an equivalent "this filing type doesn't exist in the corpus at all" finding — IKIO's EquiSense-only risk/capex items were all judged plausible-but-unverified rather than confirmed-absent-document-type. This may be specific to how UNO Minda's corpus was assembled, or it may generalize; one company's evidence is insufficient to say which.
4. **Live/recent-disclosure misses by EquiSense (company-specific in content, but the same shape in form).** IKIO's Saudi MoU miss and UNO Minda's VAT-order/CP-issuance misses are different filings entirely, but both show EquiSense's blind-query approach failing to surface a company's most recent REG30-style disclosures even when directly asked about governance/compliance. This is tentatively repeatable in form (EquiSense under-covers the newest disclosures regardless of company) but the underlying items themselves are one-off by nature.

## (c) Aggregate miss-type breakdown

Counting every material EquiSense-only finding across both benchmarks that was actually checked against SPA's corpus (excluding genuinely out-of-scope categories like forward guidance/valuation/risk, which are scope gaps rather than misses):

| Miss-type | IKIO occurrences | UNO Minda occurrences | Total | Share |
|---|---|---|---|---|
| **Fact-authoring miss** | 6 (parent auditor appointment, turnover rates, audit-trail gap, inter-corp loan, NSE fine/waiver, Gravus Tech/Royalux UAE) | 9 (segment mix, 5-yr ratios, Inovance JV delay, Rinder Riduco, audit trail, Katolec CARO, RPTs, Chairman remuneration, Code on Wages) | **15** | **~71%** |
| **Reasoning/synthesis miss** | 0 | 1 (standalone domestic EBITDA) | **1** | **~5%** |
| **Discovery miss** | 0 confirmed (capacity/capex items were "plausible but unverified," not confirmed-absent) | 1 candidate (Shareholding Pattern filing type absent from corpus) | **1** | **~5%** |
| **Extraction miss** | 0 | 0 | **0** | **0%** |
| **Indeterminate** | 0 | 2 (Minda Onkyo buyout price; Mobility Solutions liquidation) | **2** | **~9%** |

**Fact-authoring miss dominates overwhelmingly — roughly 71% of all classified findings across both companies, and the only miss-type that recurred multiple times in both benchmarks independently.** Extraction miss did not occur even once across either company: in every case checked, if a document was in the corpus, it was fully page-extracted (both companies show 100% extraction coverage of every registered document, with the sole exception of IKIO's one genuinely-scanned, zero-text-layer promoter-pledge filing — which SPA itself flagged and manually transcribed rather than silently dropping). This means the bottleneck is almost never "we have the document but didn't read the right page" — it is "we read the right page and didn't write a Fact from it."

## (d) How the two companies' corpora differ, and whether that explains the gap pattern

- **Corpus size**: UNO Minda's corpus (49 docs) is modestly larger than IKIO's (43), but the real difference is **document density**, not count: UNO Minda's two Annual Reports together carry 4.3x the extracted text of IKIO's single Annual Report. Despite this much larger volume of unmined material, the dominant miss-type (fact-authoring) did not change — if anything it intensified (9 vs. 6 confirmed instances), suggesting the gap scales with document density rather than being an artifact of IKIO's specific corpus.
- **Governance/related-party complexity**: UNO Minda is a far larger, more subsidiary- and JV-dense group (Katolec, Riduco, Inovance, Minda Onkyo, Toyoda Gosei joint ventures, multiple promoter-entity RPTs) than IKIO (three material subsidiaries). This larger web of related entities produced a correspondingly larger related-party/governance miss cluster for UNO Minda — the gap pattern is the same shape, just with more raw material to miss.
- **Document-type coverage**: IKIO's corpus included essentially every REG30/concall/presentation/results/AR document type UNO Minda's did, plus one scanned promoter-declaration PDF. UNO Minda's corpus, despite being larger, appears to lack one document *type* entirely — recurring, dedicated Shareholding Pattern filings — that IKIO's benchmark did not surface a gap on. This is the one structural corpus difference that plausibly produced a genuinely different miss-type (a candidate discovery gap) rather than just a bigger version of the same fact-authoring gap.
- **Financial-statement granularity**: UNO Minda publishes both standalone and consolidated results with full line-item detail (raw material cost, employee cost, D&A, finance cost all broken out) in its quarterly results filing; IKIO's results filing was read "only for context," not quoted as Evidence, in the original IKIO benchmark. This difference in how much structured line-item detail is available is plausibly why the reasoning/synthesis miss-type surfaced only for UNO Minda — the derivable-metric opportunity exists more concretely there.

Net: the two corpora differ mainly in scale and relationship complexity, not in kind — and the dominant gap (fact-authoring) held constant across that difference, which is evidence the gap is a property of SPA's own fact-derivation process rather than a property of either company's specific filings.

## (e) Prioritized list of systemic capability gaps (naming only — no fix design)

1. **Fact-authoring coverage of dense, already-extracted documents is the dominant, highest-leverage gap, confirmed across two independent companies and roughly 71% of all classified misses.** This is not a sourcing problem, an extraction problem, or a reach problem — the material is already inside SPA's own database in both cases. This is the single gap to prioritize above all others.
2. **A specific, recurring sub-pattern within gap #1: governance and related-party disclosure types (audit-trail/control gaps, CARO qualifications, related-party transaction tables, KMP remuneration ratios) are the most consistently-missed content category inside those dense documents, in both companies.** Worth naming separately from gap #1 because its recurrence in the *same disclosure types* (not just "annual reports in general") suggests the miss is patterned, not random.
3. **Narrow-task tunnel vision: once a fact-author opens a document to extract one targeted figure, nothing else in that same document reliably gets mined, even a few pages away.** Distinct from gap #1 because it reproduced inside documents that were NOT dense annual reports (concalls, results filings) — it is a behavior of the fact-authoring process itself, not a property of document length.
4. **No fact category exists yet for forward guidance, capacity/utilization targets, capex-pipeline totals, or risk/valuation metrics, in either company.** This is a scope gap rather than a quality gap, but it is systemic (confirmed in both benchmarks) and will structurally disadvantage SPA against any general-purpose comparison until addressed at a design level.
5. **No mechanism exists for deriving computed/synthesized metrics from already-extracted raw inputs (a reasoning/synthesis capability).** Only one confirmed instance so far (UNO Minda's standalone EBITDA), so lower-confidence as "systemic" than gaps 1-4, but worth tracking given how many of SPA's own raw financial-statement extractions could plausibly feed metrics never computed.
6. **Possible discovery-layer gap for certain recurring, dedicated filing types (e.g., periodic Shareholding Pattern filings) that fall outside the current discovery mechanism's scope.** Lowest-confidence item on this list — only one company's corpus showed evidence of this, and it was not conclusively distinguished from the possibility that such filings simply weren't prioritized for registration. Needs a second data point before being treated as systemic.
7. **SPA's corroboration/point-in-time/supersession discipline is a strength to actively preserve, not a gap — but it is explicitly at risk as a side effect of closing gap #1.** Both benchmarks show this discipline holding steady at low fact volume (8 and 10 Facts respectively). Scaling fact-authoring coverage by an order of magnitude without a corresponding scaling of this same rigor would convert today's quality advantage into tomorrow's quantity-over-rigor liability. Named here as a gap to guard against, not a gap to fix.

**No implementation, tool, sweep process, or schema change is proposed for any of the above** — this assessment stops at naming and prioritizing the gaps themselves, per the scope of this exercise.
