STATUS: ARCHITECTURE REVIEW — INPUT TO ROADMAP — DOES NOT AUTHORIZE IMPLEMENTATION

## Revised Analysis — All 7 Challenges

### 1. Business Pulse / company-state layer — genuinely missing, and it matters

M1's streams (`ResearchRevision`, `ForecastRevision`, `ValuationRevision`, `GovernanceFlag`, `OwnershipSnapshot`, `MarketPlanRevision`) are each independently revisioned. Nothing synthesizes them into "what is the current state of this business, right now." That gap matters because three later capabilities implicitly assume it exists: Thesis Tracking needs something to diff against; Alerts need a coherent "something changed" signal rather than bespoke logic per stream; Discovery needs a comparable state summary to rank candidates against each other.

**Resolution:** add an explicit Business Pulse phase. It only needs Research Intelligence's output plus the *raw* M1-level `GovernanceFlag`/`OwnershipSnapshot` records (not the pattern-detection intelligence over them) — so it does not wait on Governance/Ownership Intelligence. It should sit right after Research Intelligence, informing Forecasting before Forecasting begins, and becomes the object Thesis Tracking and Alerts key off of later.

### 2. Forecast vs Valuation — separate, with a defined overlap

Given the forecasting layer's actual scope (economic drivers, capacity modelling, acquisition contribution, margins, PAT/FCF, revision history), bundling it with valuation methodology is too much surface for one phase, and valuation has a hard data dependency on forecast *outputs* (DCF needs FCF projections; multiples need PAT projections) — not just on forecasting "existing" but on it being *sufficiently rich*.

**Resolution:** split into Forecasting Depth (leads) and Valuation Methodology (follows), not fully sequential — allow overlap: valuation work can begin once core outputs (PAT/FCF) are reliable, while capacity-modelling and acquisition-contribution refinements continue in parallel.

### 3. Thesis vs Portfolio Decision Journal — correctly separable, different dependencies

Right insight: a thesis is a property of the *company*, not of ownership. My original single "Thesis Tracking (Decision Journal)" phase conflated two things with different dependency sets:

- **Company Thesis Tracking** — depends only on Research Intelligence + Business Pulse + Forecast/Valuation. No portfolio dependency at all. Can move considerably earlier than I originally had it.
- **Portfolio Decision Journal** — depends on Company Thesis Tracking *and* Portfolio Foundation (it references "what did I believe" against "what did I do about it"). Must stay later, gated on both.

### 4. Historical commitment backfill — Promise-vs-Delivery doesn't have to wait for maturation

Correct: forward-only capture means Promise-vs-Delivery produces nothing useful until newly-captured commitments come due, potentially a year or more. But past commitments are often extractable *retroactively* from documents the Document Library can already ingest (concall transcripts, investor presentations, annual reports), and can be matched against actuals that have *already been disclosed* — both halves of the comparison already exist in the past.

**Resolution:** split Promise-vs-Delivery into a **backfill track** (extract historical commitments + match against already-disclosed actuals — usable almost immediately once Research Intelligence's document-extraction capability exists) and a **forward track** (the original capture-then-score path, which keeps enriching the same feature as newly-captured commitments mature over real time). The backfill track pulls "useful Promise-vs-Delivery" much earlier than the original single-phase framing implied.

### 5. Capture-early invariant — generalized

The price/volume and management-commitment cases share a common shape, but they're not the only instances. Going through each future capability for point-in-time data that can't be faithfully reconstructed later:

- **Price/volume** — refined: raw daily OHLC is often backfillable from external vendors; what's genuinely irrecoverable is SPA's own *contemporaneous read* of price action relative to a research event (did the market react to this disclosure, and when).
- **Forward management commitments** — nuance/tone/qualifiers from a live commitment are best captured close to the event, even though the backfill track (point 4) covers the historical gap.
- **Thesis confidence/conviction at the time it was held** — cannot be reconstructed later at all (hindsight bias makes retroactive confidence assessment worthless). Cheap to capture (one field). Must be mandatory from Company Thesis Tracking's very first version.
- **Rejection rationale for considered-and-rejected candidates** (Discovery) — "why didn't we buy this" is lost forever if not recorded at the time. Mandatory from Discovery's first version.
- **Sizing/allocation rationale at the moment of a transaction** (Portfolio) — same shape as thesis confidence. Mandatory from Portfolio Foundation's first version.
- **Disclosure-to-reaction timing** — true reaction timing can be finer-grained than daily OHLC preserves; worth a lightweight timestamp marker captured at ingestion time.

**Generalized invariant:** any field recording a *contemporaneous belief, confidence, or rationale* — as opposed to an externally verifiable fact — must be captured the moment the capability that produces it first exists, as a mandatory field in that capability's first version, regardless of when that capability is otherwise sequenced. Externally-sourced facts (prices, disclosures) are often backfillable; internally-generated judgment never is.

### 6. Alerts — anchor point moves earlier, principle unchanged

The cross-cutting, incrementally-registered approach still holds. But the *first* genuinely alert-worthy signal is now earlier than I originally placed it: Business Pulse detecting a material state change (not Governance/Ownership Intelligence, which now runs later and in parallel).

**Resolution:** introduce the minimal shared notification/event plumbing alongside Business Pulse, reusing the existing legacy Telegram delivery pattern where appropriate but kept properly separated per the North-Star research/live boundary. Every later phase (Governance/Ownership Intelligence, Thesis Tracking, Promise-vs-Delivery backfill hits, Discovery candidates, Technical Analysis signals) registers new event types onto this same plumbing rather than building its own.

### 7. Portfolio foundation — split infrastructure from intelligence

With Thesis correctly decoupled (point 3), Portfolio Foundation's *feature* dependents shrink to a later-clustered set: Portfolio Decision Journal, sizing analytics, the Opportunity-Cost Engine, and Add/Hold/Reduce/Exit outcome tracking. None of Research Intelligence, Business Pulse, Forecasting, Valuation, Governance/Ownership Intelligence, Thesis Tracking, Promise-vs-Delivery, Discovery, or Technical Analysis need it.

But the capture-early invariant (point 5) still applies to Portfolio Foundation *itself*: real transactions and their rationale are happening regardless of what SPA has built, and that rationale is lost if not captured contemporaneously.

**Resolution — split infrastructure from intelligence:** stand up a **minimal, capture-only** Portfolio Foundation early (bare holdings/transactions/rationale-at-decision-time, alongside the Phase 2 capture-early cluster) — purely to stop losing data — while the *intelligence* built on top of it (Decision Journal, Opportunity-Cost Engine, sizing analytics) stays correctly sequenced later, gated on Company Thesis Tracking existing. Boundary discipline: this must be a genuinely separate data domain (its own `Holding`/`Transaction`/actor tables), referencing `company_id` only as a loose identifier — never a foreign-key relationship into the research schema — mirroring exactly how `CompanyDisclosure` references `document.id` and how the M1 websocket/research import boundary was kept clean.

---

## Revised Dependency Graph

```
M1 (frozen)
 │
 ├──> Research Intelligence Deepening
 │      │  (also starts: price/volume capture, forward commitment capture,
 │      │   disclosure-reaction timing markers — capture-early cluster)
 │      │
 │      ├──> Business Pulse (company-state synthesis)
 │      │      + raw M1 GovernanceFlag/OwnershipSnapshot data (no wait on
 │      │        Governance/Ownership Intelligence)
 │      │      │
 │      │      ├──> minimal shared Alerts/event plumbing (anchored here)
 │      │      │
 │      │      ├──> Forecasting Depth (economic drivers, capacity,
 │      │      │      acquisition contribution, margins, PAT/FCF, revisions)
 │      │      │      │
 │      │      │      └──> Valuation Methodology (overlaps once core
 │      │      │             PAT/FCF outputs are reliable)
 │      │      │             │
 │      │      │             └──> Company Thesis Tracking
 │      │      │                    (captures point-in-time confidence
 │      │      │                     from its first version)
 │      │      │                    │
 │      │      │                    └──> Portfolio Decision Journal ──┐
 │      │      │                                                       │
 │      │      └──> Governance/Ownership Intelligence                  │
 │      │             (pattern detection; runs parallel to Forecasting/│
 │      │              Valuation, gated on accumulated snapshot depth) │
 │      │                                                              │
 │      └──> Historical Commitment Backfill (Promise-vs-Delivery,      │
 │             usable ~immediately after document extraction exists)  │
 │             │                                                       │
 │             └──> Promise-vs-Delivery Forward Scoring                │
 │                    (enriches the same feature as forward-captured   │
 │                     commitments mature over real time)              │
 │                                                                      │
 ├──> Research Discovery                                               │
 │      (captures rejection-rationale from its first version;          │
 │       needs a broad researched-company base, not deep forecast/     │
 │       valuation/thesis maturity)                                    │
 │                                                                      │
 ├──> Technical Analysis                                               │
 │      (only hard dependency: the price/volume capture already        │
 │       running since Research Intelligence)                          │
 │                                                                      │
 └──> minimal Portfolio Foundation (capture-only: holdings/transactions/
        rationale-at-decision-time; own data domain, company_id as a
        loose identifier only, no FK into research schema)
        │
        └────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
              Broader North-Star tier (Smart Capital Intelligence,
              Event-Causality Intelligence, Theme Intelligence,
              Opportunity-Cost Engine, Methodology Evolution Engine,
              multi-actor/multi-asset graph) — gated on accumulated
              depth across nearly everything above, including
              Portfolio Decision Journal
```

## Recommended Milestone Sequence

1. **Research Intelligence Deepening** — plus the capture-early cluster (price/volume, forward commitments, disclosure-reaction timing) and a minimal, capture-only Portfolio Foundation, both started here purely to stop losing data, independent of when the intelligence layers that consume them ship.
2. **Business Pulse** (company-state synthesis) — plus the minimal shared Alerts/event plumbing, anchored to its first "material change" signal.
3. **Historical Commitment Backfill** (Promise-vs-Delivery, backfill track) — usable almost immediately; runs in parallel with everything below.
4. **Forecasting Depth**, then **Valuation Methodology** (overlapping tail, not fully sequential).
5. **Governance/Ownership Intelligence** — parallel to 3–4, gated on accumulated snapshot depth rather than a hard phase order.
6. **Company Thesis Tracking** — independent of portfolio; mandatory point-in-time confidence field from day one.
7. **Promise-vs-Delivery Forward Scoring** — enriches milestone 3's backfill as forward-captured commitments mature.
8. **Portfolio Decision Journal** — gated on both milestone 1's Portfolio Foundation and milestone 6's Thesis Tracking.
9. **Research Discovery** — rejection-rationale mandatory from day one.
10. **Technical Analysis** — gated only on milestone 1's price/volume capture; no urgency relative to the others.
11. **Broader North-Star tier** — Smart Capital Intelligence, Event-Causality Intelligence, Theme Intelligence, Opportunity-Cost Engine, Methodology Evolution Engine, multi-actor/multi-asset graph — gated on accumulated depth across all of the above.

No files modified, no code changed, no tasks created.
