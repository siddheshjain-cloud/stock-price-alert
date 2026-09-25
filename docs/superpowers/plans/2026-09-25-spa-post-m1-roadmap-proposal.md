STATUS: PROPOSAL — NOT YET APPROVED — DOES NOT AUTHORIZE IMPLEMENTATION

# SPA Post-M1 Roadmap Proposal

**Date:** 2026-09-25

**Nature of this document:** No frozen M2–M10 roadmap exists anywhere in this repository (confirmed by exhaustive search of `docs/superpowers/specs/`, `docs/superpowers/plans/`, every other markdown file in both repositories, and the full commit history). This document is a **new proposal**, not a recovery of prior scope. It does not amend the frozen M1 design, the North-Star Architecture Amendment, or the M1 Impact Assessment. It authorizes no implementation, creates no tasks, and does not begin any phase.

## Grounding

This roadmap is grounded in two things already on record, rather than an ordering invented from scratch:

1. The investment workflow the North-Star spec itself documents (`docs/superpowers/specs/2026-09-05-spa-north-star-architecture-amendment-design.md`, §1):

   ```text
   Find exceptional business/change early
           ↓
   Establish why it could become substantially larger
           ↓
   Determine valuation/downside
           ↓
   Monitor management delivery
           ↓
   Identify accumulation
           ↓
   Size
           ↓
   Update thesis
           ↓
   Add / Hold / Do-not-add / Reduce / Exit
   ```

2. M1's actual built foundation: `Company`, `ResearchRevision`, `ForecastRevision`, `ValuationRevision`, `GovernanceFlag`, `OwnershipSnapshot`, the common Document Library, and the entitlement model.

## The one structural call-out before the phases

Two things should start much earlier than their place in the workflow would suggest, because they are data-accumulation dependencies, not just feature dependencies.

1. **Minimal point-in-time price/volume capture on the research side.** Technical analysis, event-causality correlation, and "monitor management delivery vs. market reaction" all eventually need historical price/volume data attributable to research evidence, not the legacy live `Ticker.last_price`, which the North-Star boundary (and the M1-closure websocket/research import-boundary fix) deliberately keeps out of research's reach. If this capture doesn't start until the phase that "needs" it, all the history between now and then is permanently unrecoverable. Recommendation: start a lightweight, append-only, research-side price/volume snapshot in Phase 2 — years before full technical-analysis intelligence is built on top of it — purely so the data exists when it's needed.
2. **Structured management-commitment recording (promise, not yet promise-vs-delivery).** "Monitor management delivery" requires knowing what was promised at the time it was promised. If commitment-recording only starts when the full promise-vs-delivery intelligence feature is built, every guidance/target given before that point is lost. Recommendation: add a simple, append-only "management commitment" record (what was said, when, sourced to a document) early, well before the comparison/scoring logic that reads it.

Both are cheap, additive, and match M1's own point-in-time evidence principle — they are capture infrastructure, not intelligence, so building them early adds negligible scope.

## Phase 2 — Research Intelligence Deepening

Direct continuation of M1's Company Research Brain: better use of the existing `ResearchRevision`/`Document`/`ForecastRevision`/`ValuationRevision` foundation before building anything new on top of it. Includes: the two capture mechanisms above; richer document ingestion for M1's already-existing document types; structured extraction where currently manual (e.g., turning concall/filing text into queryable revision points).

**Depends on:** M1 (satisfied). Nothing later can safely build "intelligence" over research data until the research data itself is dependable and reasonably automated — this is why it leads.

## Phase 3 — Forecast & Valuation Maturity

Forecast-accuracy tracking (declared vs. actual, now that Phase 2 is recording actuals) and valuation-methodology breadth, both sitting on the existing `ForecastRevision`↔`ValuationRevision` link M1 already built.

**Depends on:** Phase 2 (needs real research cadence and, for accuracy tracking, at least one full reporting cycle of recorded actuals). Valuation specifically depends on forecasts existing first — M1's own schema already encodes this (valuation references forecast revisions), so this ordering isn't new, just continued.

## Phase 4 — Governance/Ownership Intelligence

Pattern detection over `GovernanceFlag`/`OwnershipSnapshot` (unusual promoter selling, recurring related-party patterns, disclosure-timing anomalies).

**Depends on:** M1's models (satisfied structurally) but is practically gated on accumulated history — a single snapshot can't show a pattern. This is a case where the code could be built anytime, but its value is gated by time-in-production, so there's no harm sequencing it here while Phases 2–3 run and ownership/governance data keeps accumulating in the background.

## Phase 5 — Thesis Tracking (Decision Journal)

The explicit "Update thesis" step. Structurally, this is a diffing/tracking layer over everything above it — it needs a stable research thesis to track against, forecast/valuation revisions to diff, and governance signals to flag against the thesis.

**Depends on:** Phases 2–4. Building this earlier would mean tracking a thesis against a foundation that's still actively changing shape, producing noisy, low-value diffs.

## Phase 6 — Promise-vs-Delivery Scoring

The comparison logic over the commitment records captured back in Phase 2, now that enough delivery cycles exist to score against.

**Depends on:** Phase 2's capture mechanism (satisfied by construction) and enough elapsed time for commitments to have come due.

## Phase 7 — Portfolio / Capital-Allocation Foundation

The second capability flagged for moving earlier than its "natural" workflow position (which is last — "Size", "Add/Hold/Reduce/Exit"). The North-Star doc explicitly names this a missing foundational concept (`InvestmentActor`/Smart Capital transaction engine, excluded from M1). Sizing decisions, opportunity-cost comparisons, and the "did I actually act on this thesis" half of the Decision Journal all need a position/holdings model that doesn't exist anywhere yet — not in M1's research schema, and not reusable from the legacy `Trade` model, which the North-Star boundary keeps separate from research for good reason (it's for live trading/alerting, not portfolio bookkeeping).

**Recommendation:** stand up the minimal position/transaction data model here, in the middle of the roadmap rather than the end, specifically because Phase 5 (thesis tracking) and everything in Phase 8+ structurally depend on knowing what's actually held.

## Phase 8 — Research Discovery

"Find exceptional business/change early" — proactive candidate identification, explicitly kept epistemically separate from the "Authoritative SPA Research View" per the North-Star doc (§6–7, §14).

**Depends on:** a reasonably broad base of researched companies to compare candidates against (so it isn't first), but does not need deep forecast/valuation/thesis maturity — it could in principle move earlier than Phase 5–7 if there's appetite to start surfacing candidates sooner. Placed after the core intelligence phases because its output (new candidates) is most useful once the pipeline that processes a candidate into a full thesis (Phases 2–6) already exists.

## Phase 9 — Technical Analysis

Deliberately last among the "core" phases, not because it's unimportant, but because its only hard dependency — the price/volume history — was captured back in Phase 2. Everything from here is analysis over already-accumulated data, so there is no urgency to sequence it earlier; doing so would not unlock anything for other phases the way Phase 2's capture step does.

## Phase 10 — Alerts (cross-cutting, not a single phase)

Alerts have no independent data model — they are a notification layer that watches every other domain for state changes (new governance flag, thesis threshold crossed, forecast miss, technical signal, promise coming due).

**Recommendation:** do not build this as one big milestone; add the relevant alert type incrementally as each phase above lands, with a small shared notification plumbing layer introduced whenever the first alert type is needed (likely alongside Phase 4 or 5, whichever ships first).

## Phase 11+ — Broader North-Star Capabilities

Smart Capital Intelligence, Event-Causality Intelligence, Theme Intelligence, and the multi-actor/multi-asset graph are explicitly the most advanced concepts in the North-Star document itself (§9, §12, §13, §15). Each draws correlations across the outputs of nearly everything above — ownership intelligence, portfolio data, price history, thesis history, and discovery all need to already be rich and historically deep before these produce meaningful signal rather than noise.

These belong last, gated on the accumulated depth of Phases 2–9, not on any single remaining architectural blocker.

## Summary of the two "move earlier" recommendations

Point-in-time research-side price/volume capture and structured management-commitment recording should both start in Phase 2 — far earlier than the features that consume them (technical analysis in Phase 9, promise-vs-delivery in Phase 6) — because delaying capture destroys history that can never be recovered later, while the capture mechanisms themselves are cheap and additive to build now.
