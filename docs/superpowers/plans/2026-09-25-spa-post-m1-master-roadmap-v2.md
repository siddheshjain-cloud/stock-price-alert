STATUS: PROPOSAL — NOT YET APPROVED — DOES NOT AUTHORIZE IMPLEMENTATION

# SPA Post-M1 Master Roadmap V2

**Date:** 2026-09-25

**Provenance:** This document reconciles two prior documents into one coherent sequence. It does not replace or edit either of them — both remain as-written:

- `2026-09-25-spa-post-m1-roadmap-proposal.md` — the original 11-phase proposal.
- `2026-09-25-spa-post-m1-roadmap-architecture-review.md` — Part 1 (seven challenges against the original proposal) and Part 2 (six rounds establishing the World Context / Causal Intelligence chain).

Like both source documents, this is a proposal only. No frozen M2 roadmap exists or is created by this document. It authorizes no implementation, creates no tasks, and does not amend the frozen M1 design, the North-Star Architecture Amendment, or the M1 Impact Assessment.

## Reconciliation principle

The single biggest correction the architecture review made to the original proposal is this: **build order and capture order are not the same thing, and conflating them was the recurring error the review kept finding and fixing** — for Portfolio Foundation, for macro data, for management commitments, and most significantly for World/Causal Intelligence itself, which the original proposal placed at the very end ("broader North-Star capabilities") when it should start at the very beginning.

This roadmap is organized around that distinction directly, as **tiers**, not a flat numbered list:

- **Tier 0 — Capture & Context Foundations:** cheap, additive, infrastructure-only work. Nothing here requires deep intelligence to already exist; several items exist purely to stop losing data or context that cannot be reconstructed later. All of Tier 0 can start immediately post-M1, and most of it runs in parallel, not sequentially.
- **Tiers 1–4 — Core Intelligence:** the capabilities that give the captured data meaning — screening, state-reading, forecasting, valuing, thesis-tracking, portfolio-tracking. Each tier's entry depends on specific Tier 0 (or earlier-tier) outputs, stated explicitly below, not on "M1 plus time."
- **Tier 5 — Low-urgency, independently-gated work:** capabilities whose only dependency is a single Tier 0 item, with nothing else waiting on them.
- **Tier 6 — North-Star / Advanced Intelligence:** capabilities that are genuinely gated on accumulated history and maturity across nearly everything above, correctly sequenced last.

Where the review established that two things can run in parallel rather than strictly one-after-another, this roadmap preserves that — it does not force a false linear order onto work that was explicitly found to be parallelizable.

---

## Tier 0 — Capture & Context Foundations (start together, immediately post-M1)

All of the following can begin at the same time. None depends on any other item in this tier being finished first; several are independent, standing processes rather than one-time builds.

### 0.1 Research Intelligence Deepening
Direct continuation of M1's Company Research Brain: richer document ingestion for M1's existing document types, structured extraction where currently manual. **Depends on:** M1 (satisfied).

### 0.2 Capture-early cluster
Two independent, cheap, append-only capture mechanisms, started here specifically because delaying them destroys history that can never be recovered later. Historical OHLCV price/volume itself is generally backfillable from external vendors later and does not need early capture; what must be preserved early is **SPA's own contemporaneous market interpretation** — disclosure-to-reaction timing, and other point-in-time judgment/context tied to a specific research event — which cannot be honestly reconstructed after the fact once the outcome is already known:
- SPA's point-in-time market-interpretation capture: disclosure-to-reaction timing markers and other contemporaneous readings of price action relative to a research event, distinct from the legacy live `Ticker.last_price`, which the research/websocket import boundary deliberately keeps out of reach.
- Forward management-commitment capture (what was said, when, sourced to a document) — the forward half of Promise-vs-Delivery; the historical half is Tier 1.

**Depends on:** nothing beyond 0.1's document-ingestion capability existing.

### 0.3 Minimal Portfolio Foundation (capture only)
Bare holdings/transactions/rationale-at-decision-time. Portfolio remains a genuinely separate bounded domain from Research — its own `Holding`/`Transaction`/actor tables, not merged into or made structurally dependent on the research schema. The exact cross-domain identity/reference mechanism (for example, whether `company_id` is carried as a loose identifier, a formal foreign key, or some other linkage) is **not fixed by this roadmap** and is deferred to the Portfolio Foundation specification, which should weigh precedents such as how `CompanyDisclosure` references `document.id` and how the M1 websocket/research import boundary was kept clean, without this document pre-deciding the outcome. Started here, not with the Portfolio *intelligence* that consumes it later, because real transactions and their rationale are happening regardless of what SPA has built, and that rationale cannot be reconstructed retroactively. **Depends on:** nothing.

### 0.4 World Context tracking
A neutral, epistemically-disciplined, append-only observation log of macro, policy, geopolitical, regulatory, liquidity/capital-flow, technological-disruption, and commodity/supply-demand developments. Grounded in the North-Star spec's Section 6 (Epistemic Separation): records fact/evidence and hedged hypothesis, never asserts unsupported motive (fiscal deficits, dollar movement, and geopolitical tension are observable; "this administration caused it" is not a valid conclusion without direct evidence). This is the "World" node of the seven-node chain and the first two questions of the six-question engine (what changed; why might it matter). **Depends on:** nothing. Architecturally the topmost layer in the documented North-Star hierarchy (§22: `WORLD → DISCOVERY → RESEARCH BRAIN → ...`), not a subset of SPA Legacy/Wealth Brain.

### 0.5 Causal-Chain / Theme structure mechanism
The mechanism that answers the six-question engine's remaining questions (through what transmission mechanism; which industries/themes/cycles benefit or suffer): trigger → order-1/2/3 economic consequences → affected industries/business models. Architecturally a structured-reasoning, evidence-cited, revisioned artifact — the same shape as M1's `ResearchRevision`, applied at theme/macro scope — not a statistical pattern-detection engine, so it does not need years of proprietary data to produce a first useful output. Must support, from its first version:
- An explicit, permanently-referenced **genesis record** per theme/causal-chain, distinct from later revisions, so the original articulation is always retrievable unchanged.
- **Multiple sibling hypotheses/scenarios from one World observation**, preserved as distinct, competing branches (not merged or resolved prematurely) — one macro condition (e.g., large fiscal deficits + shifting rate/dollar conditions + geopolitical tension) can produce several mutually-exclusive downstream scenarios across different industries, and all must be preserved as they were reasoned at the time.

**Depends on:** 0.4 (needs a World observation to originate from). Does not need company-level research maturity — it only needs to be able to *name* a company as a candidate later, referencing M1's existing stable `Company`/`Ticker` identity.

### 0.6 Broad-shallow company-universe reference layer
Sector/business-model classification and basic exposure attributes across a much wider set of companies than SPA has deeply researched — distinct from and cheaper to maintain than M1's deep `ResearchRevision`-style research. Identified in the architecture review as a previously-missing prerequisite: without it, Opportunity Discovery (Tier 1) can articulate a correct industry thesis and still fail to surface the actual beneficiaries, simply because they sit outside the narrow set of already-deeply-researched companies. **Depends on:** nothing beyond M1's `Company`/`Ticker` identity model.

---

## Tier 1 — First Intelligence Outputs (depends only on Tier 0)

### 1.1 Opportunity Discovery
Screens the Tier 0.6 company universe against active Tier 0.5 causal-chain/theme records to identify which companies are exposed, positively or negatively. This is the "Company" node of the seven-node chain. Every revision's beneficiary/loser list preserves the prior list unchanged — new names are added as new revisions, never retroactively inserted into the original, so the system cannot silently inflate its own track record by letting the list drift forward as opportunities become obvious. **Depends on:** 0.5 and 0.6.

### 1.2 Business Pulse
Company-state synthesis — but, for a company sitting inside an active theme, specifically a **hypothesis test**: is the effect the causal thesis predicted actually appearing in this company's evidence (margins, order book, capacity utilisation, management commentary)? Carries an explicit reference to which causal-thesis record it is evaluating; its confirm/contradict/inconclusive evidence is genuinely append-only, matching M1's existing revision discipline. Consumes Research Intelligence's output (0.1), raw M1-level `GovernanceFlag`/`OwnershipSnapshot` records directly (not the pattern-detection intelligence over them — no wait on Tier 2's Governance/Ownership Intelligence), and, for themed companies, the Tier 0.5 causal-chain record and Tier 1.1 exposure flag. **This is a hard dependency for correct interpretation, not a soft enrichment** — a Business Pulse reading for a company in an active industry cycle (e.g., Chemplast Sanmar inside a PVC cycle) is unreliable without the World/Theme context, since margin compression that looks company-specific may actually be an industry-cycle trough. **Depends on:** 0.1, 0.4/0.5 (for themed companies), M1's `GovernanceFlag`/`OwnershipSnapshot`.

### 1.3 Minimal shared Alerts/event plumbing
Anchored to Business Pulse's first "material change" signal — the earliest genuinely alert-worthy event in the roadmap. Not a single milestone; every later phase registers new event types onto this same plumbing incrementally rather than building its own. **Depends on:** 1.2.

### 1.4 Historical Commitment Backfill (Promise-vs-Delivery, backfill track)
Extracts historical management commitments from documents the Document Library can already ingest (concall transcripts, investor presentations, annual reports) and matches them against actuals that have already been disclosed — both halves of the comparison already exist in the past, so this produces useful output almost immediately, without waiting on the 0.2 forward-capture mechanism to mature over real time. **Depends on:** 0.1's document-extraction capability.

### 1.5 Theme-level Thesis Feedback
A rollup mechanism, distinct from company-level Thesis Tracking (Tier 3), that watches multiple companies' Tier 1.2 Business Pulse confirm/contradict signals within the same theme and updates the theme's own status — recorded as its own revision stream (confirmed / invalidated / evolving over time), never a single mutable field that only shows the current belief. When a theme's status changes, every company thesis built on assuming that theme's chain should be flaggable via an explicit link. The mechanism (schema, linking, rollup rule) is built here, alongside Business Pulse; the *value* of any single theme's rollup accumulates only as evidence arrives across enough companies within it — a maturity property of the theme, not a reason to delay building the mechanism. **Depends on:** 0.5, 1.2.

---

## Tier 2 — Forecast, Valuation, and Governance/Ownership Maturity (depends on Tier 1)

### 2.1 Forecasting Depth
Economic drivers, capacity modelling, acquisition contribution, margins, PAT/FCF projection, and revision-history mechanics — plus company-owned capital-allocation-response modelling (how management redirects capacity/output in response to upstream drivers, e.g. EID Parry's cane-to-ethanol diversion mix in response to blending policy). This is distinct from and should not be confused with *portfolio*-level capital allocation (Tier 4) — the two share a name but are different concepts at different levels. **Depends on:** 1.2 (Business Pulse gives forecasting a reliable "current state" to project forward from).

### 2.2 Valuation Methodology
Consumes 2.1's forecast outputs (DCF needs FCF projections; multiples need PAT projections) — not just needing forecasting to "exist" but to be *sufficiently rich*. Not fully sequential after 2.1: valuation work can begin once core outputs (PAT/FCF) are reliable, while capacity-modelling and acquisition-contribution refinements continue in parallel. **Depends on:** 2.1's core outputs (overlapping, not blocking).

### 2.3 Governance/Ownership Intelligence
Pattern detection over `GovernanceFlag`/`OwnershipSnapshot` (unusual promoter selling, recurring related-party patterns, disclosure-timing anomalies). Structurally buildable anytime after M1 — the code has no hard dependency on Tiers 0–1 — but practically gated on accumulated snapshot history, since a single snapshot shows no pattern. Runs in parallel with 2.1/2.2, not after them. **Depends on:** M1's models (structurally); accumulated snapshot depth (practically, a time-based gate).

---

## Tier 3 — Thesis Tracking and Forward Scoring (depends on Tier 2)

### 3.1 Company Thesis Tracking
"Why do I like this company" — a property of the company, independent of ownership. Depends only on Research Intelligence + Business Pulse + Forecast/Valuation; no portfolio dependency at all. Mandatory point-in-time confidence/conviction field from its first version — this cannot be reconstructed later at all (hindsight bias makes retroactive confidence assessment worthless), unlike externally-sourced facts, which are often backfillable. Explicitly linkable to the Tier 0.5/1.5 theme(s) it depends on, so a theme-level status change can flag dependent company theses. **Depends on:** 0.1, 1.2, 2.1, 2.2.

### 3.2 Promise-vs-Delivery Forward Scoring
Enriches Tier 1.4's backfill as the 0.2 forward-captured commitments mature over real elapsed time. This dependency is time-based, not build-order-based — it does not need Tier 2 or 3.1 to exist; it is placed here sequentially only because it is a natural low-priority companion to Thesis Tracking, not because anything blocks it earlier. **Depends on:** 0.2 (elapsed time), 1.4 (shares infrastructure).

---

## Tier 4 — Portfolio Decision Journal (depends on Tier 0.3 and Tier 3)

### 4.1 Portfolio Decision Journal
Sizing decisions, opportunity-cost comparisons, and the "did I actually act on this thesis" half of the Decision Journal. The only capability in this roadmap with a genuine dependency on portfolio/holdings data — none of Tiers 0–3 needed it. Mandatory sizing/allocation-rationale-at-the-moment-of-transaction field, for the same irreconcilable-after-the-fact reason as 3.1's confidence field; already captured from Tier 0.3's first version. **Depends on:** 0.3 (Portfolio Foundation), 3.1 (Company Thesis Tracking).

---

## Tier 5 — Independently-Gated, Low-Urgency Work

### 5.1 Research Discovery (broad candidate surfacing beyond the theme-driven route)
"Find exceptional business/change early" more generally than Tier 1.1's theme-triggered exposure screening. Needs a reasonably broad base of researched companies to compare candidates against, but not deep forecast/valuation/thesis maturity. Rejection rationale for considered-and-rejected candidates is mandatory from its first version, for the same point-in-time-belief reason as 3.1 and 4.1's rationale fields. **Depends on:** 0.6.

### 5.2 Technical Analysis
Raw OHLCV price/volume history is generally backfillable from external vendors and imposes no hard early-capture requirement of its own. Where Technical Analysis draws on SPA's own contemporaneous market-interpretation readings (disclosure-to-reaction timing and similar point-in-time context), that depends on 0.2 having captured it at the time. Either way, there is no urgency to sequence Technical Analysis earlier, since nothing else in this roadmap waits on it. **Depends on:** 0.2 (for SPA's own interpretive context only; not for raw price history).

---

## Tier 6 — North-Star / Advanced Intelligence (gated on accumulated depth across nearly everything above)

- **Full statistical Macro-Regime Intelligence** and **emergent/automatic Theme detection** — systematic regime classification and regime-to-theme-performance correlation, and automatic detection of *new* themes from data patterns (as opposed to the analyst-identified themes Tier 0.5 already supports). Sequenced at the *front* of this tier, not undifferentiated at the back, because they consume the most already-accumulated Tier 0 World/Theme tracking history directly.
- **Full Discovery Engine** — combining Smart Capital, Event-Causality, deep Theme Intelligence, governance signals, ownership changes, and everything above, per the spec's own §14 description. A richer synthesis than Tier 1.1/5.1 alone produce.
- **Smart Capital Intelligence** — observable-actor behaviour (promoters, insiders, HNIs, FIIs, etc.); needs accumulated actor-behaviour history to be meaningful.
- **Event-Causality Intelligence** — needs accumulated event-outcome history.
- **Opportunity-Cost Engine** — needs mature Portfolio Decision Journal (Tier 4) data to compare alternatives against.
- **Methodology Evolution Engine.**
- **Multi-actor/multi-asset graph.**
- **Learning Brain evaluation** — scoring SPA's own historical causal calls against outcomes: did SPA identify the World change correctly; did it map the right causal chain and transmission mechanism; did it identify the correct industries/companies (beneficiaries *and* losers); did Business Pulse later confirm or invalidate the original hypothesis. Entirely dependent on Tier 0.5/1.1/1.5's immutable genesis records, point-in-time beneficiary/loser lists, and revision streams having been honoured from the start — there is nothing honest for this evaluation to score otherwise. Correctly the last capability in the roadmap, since it needs years of elapsed time and accumulated outcome data to mean anything.

---

## Dependency Graph

```
M1 (frozen)
 │
 ├─ TIER 0 (parallel, starts immediately) ───────────────────────────────┐
 │   0.1 Research Intelligence Deepening                                 │
 │   0.2 Capture-early cluster (SPA's contemporaneous market-           │
 │        interpretation/disclosure-reaction timing -- not raw OHLCV,   │
 │        which is backfillable; forward commitments)                   │
 │   0.3 Minimal Portfolio Foundation (capture only)                     │
 │   0.4 World Context tracking                                          │
 │   0.5 Causal-Chain/Theme structure mechanism  ◄── depends on 0.4      │
 │        (genesis records; competing/sibling hypotheses preserved)      │
 │   0.6 Broad-shallow company-universe reference layer                  │
 │                                                                        │
 ├─ TIER 1 (depends on Tier 0) ──────────────────────────────────────────┤
 │   1.1 Opportunity Discovery         ◄── 0.5, 0.6                      │
 │   1.2 Business Pulse                ◄── 0.1, 0.4/0.5 (themed          │
 │        (hypothesis-test role)            companies), M1 governance/   │
 │                                           ownership data              │
 │   1.3 Alerts/event plumbing         ◄── 1.2                          │
 │   1.4 Historical Commitment Backfill ◄── 0.1                         │
 │   1.5 Theme-level Thesis Feedback   ◄── 0.5, 1.2                     │
 │                                                                        │
 ├─ TIER 2 (depends on Tier 1) ──────────────────────────────────────────┤
 │   2.1 Forecasting Depth             ◄── 1.2                          │
 │        │ (overlap)                                                    │
 │        └─► 2.2 Valuation Methodology                                  │
 │   2.3 Governance/Ownership Intelligence  ◄── M1 (structural);        │
 │        (parallel to 2.1/2.2)              accumulated snapshots (time)│
 │                                                                        │
 ├─ TIER 3 (depends on Tier 2) ──────────────────────────────────────────┤
 │   3.1 Company Thesis Tracking       ◄── 0.1, 1.2, 2.1, 2.2           │
 │   3.2 Promise-vs-Delivery Forward   ◄── 0.2 (time), 1.4 (infra)      │
 │        Scoring                                                        │
 │                                                                        │
 ├─ TIER 4 ───────────────────────────────────────────────────────────────┤
 │   4.1 Portfolio Decision Journal    ◄── 0.3, 3.1                      │
 │                                                                        │
 ├─ TIER 5 (independently gated, parallel to 1-4) ───────────────────────┤
 │   5.1 Research Discovery (broad)    ◄── 0.6                          │
 │   5.2 Technical Analysis            ◄── 0.2                          │
 │                                                                        │
 └─ TIER 6 (gated on accumulated depth across all above) ────────────────┘
     Full Macro-Regime Intelligence + emergent Theme detection
     Full Discovery Engine (Smart Capital + Event-Causality + Theme + ...)
     Smart Capital Intelligence
     Event-Causality Intelligence
     Opportunity-Cost Engine            ◄── 4.1
     Methodology Evolution Engine
     Multi-actor/multi-asset graph
     Learning Brain evaluation          ◄── 0.5, 1.1, 1.5 (immutability
                                              discipline honoured from Tier 0)
```

---

## Cross-cutting principles (apply across multiple tiers, not owned by any single one)

**Capture-early invariant.** Any field recording a contemporaneous belief, confidence, or rationale — as opposed to an externally verifiable fact — must be captured the moment the capability that produces it first exists, as a mandatory field in that capability's first version, regardless of when that capability is otherwise sequenced. Externally-sourced facts (prices, disclosures) are often backfillable; internally-generated judgment never is. Applies to: 0.2's capture cluster, 0.3's transaction rationale, 3.1's thesis confidence, 4.1's sizing rationale, 5.1's rejection rationale.

**Infrastructure-vs-intelligence split.** Every capability with a genuine later-stage intelligence layer has its cheap capture/infrastructure half pulled as early as possible, while the layer that requires accumulated history or sophistication stays correctly late. Applies to: Portfolio (0.3 vs. 4.1/Tier 6's Opportunity-Cost Engine), Promise-vs-Delivery (1.4's backfill vs. 3.2's forward scoring), World/Theme (0.4/0.5's structured-reasoning capture vs. Tier 6's statistical/emergent intelligence).

**Immutability / hindsight-preservation discipline.** M1 already applies immutable, append-only revision history uniformly across `ResearchRevision`, `ForecastRevision`, and `ValuationRevision`. Every new record type this roadmap adds inherits the same discipline: explicit genesis records distinct from later revisions (0.5), point-in-time beneficiary/loser lists preserved per revision rather than drifting forward (1.1), status as a revision stream rather than a mutable field (1.5), and point-in-time belief/rationale fields that are never retroactively editable (3.1, 4.1, 5.1). This is what makes Tier 6's Learning Brain evaluation honest rather than a hindsight-smoothed narrative.

**Epistemic separation.** Grounded in the North-Star spec's Section 6 invariant (`Source → Evidence → Fact → Hypothesis/Inference → Forecast → Valuation → SPA Research View`). World Context (0.4) and the Causal-Chain mechanism (0.5) must record fact/evidence and hedged hypothesis only, never asserted motive — competing explanations are preserved neutrally and updated as evidence arrives, not collapsed into a single narrative or political attribution.

**World/Macro context linkage.** Where a Forecast (2.1), Valuation (2.2), or Thesis (1.5, 3.1) revision is created for a company inside an active theme, it must reference the applicable immutable/versioned World Context (0.4) and Causal-Chain/Theme (0.5) revision it relied on — a pointer to that specific revision, not a copy of it. Macro/theme state is never duplicated into the referencing record: the World/Theme revision remains the single source of truth, and the reference lets a later reader (including Tier 6's Learning Brain evaluation) reconstruct exactly which point-in-time World/Macro understanding a given Forecast, Valuation, or Thesis was reasoned under, without every downstream record re-stating that state itself. This applies only where an applicable World/Macro theme exists for the company in question — it does not require every Forecast/Valuation/Thesis revision to carry a macro reference regardless of relevance.

---

## What this document does not do

No detailed implementation tasks are created. No code or M1 state is modified. Neither source document (`...-roadmap-proposal.md`, `...-roadmap-architecture-review.md`) is edited — both remain exactly as previously saved. This is a planning artifact only.
