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

---

# Part 2 — World-First Causal Intelligence Refinement (Six Rounds)

The seven-challenge review above stands as originally written. This part consolidates six subsequent rounds of discussion that materially extend it: a missing top-of-chain capability (World Context / Causal Intelligence) was identified, its purpose and architecture were worked out in detail, tested against three concrete real companies, checked for completeness against a five-stage decomposition, extended with a hindsight-preservation requirement, and finally crystallized into a named concept with a seven-node chain. Nothing in Part 1 is superseded; this part adds a capability Part 1 did not include and refines how several of Part 1's phases (Business Pulse, Thesis Tracking, Discovery) interact with it.

## Round 1 — The WORLD-first philosophy

The original SPA philosophy, restated by the owner: SPA should keep its eyes on the WORLD first — macro, policy, geopolitics, regulation, liquidity/capital flows, technological disruption, commodity/supply-demand changes, and major headwinds/tailwinds — and continuously build a point-in-time context of what is changing and why. From that context SPA should move down the chain:

```
WORLD / MACRO / POLICY / DISRUPTION → INDUSTRY / CYCLE / THEME → COMPANY
  → BUSINESS PULSE → FORECAST / VALUATION → THESIS → PORTFOLIO
```

### Correction to an initial framing error

The owner's first mention of this used the phrase "Macro Call / Macro-Regime Intelligence within SPA Legacy." That framing does not match the documentation. Section 16 (SPA Legacy) of the North-Star Architecture Amendment has no macro content at all — it defines a narrow, unrelated scope: UHNI/family wealth-management concerns (client mandates, Wealth Manager roles, tax/entity constraints, private-client isolation, RBAC). Macro instead lives in Section 22, "Architectural North Star," which defines SPA's full conceptual hierarchy:

```
WORLD
  Macro / policy / industry / themes / capital flows
        ↓
DISCOVERY
        ↓
RESEARCH BRAIN
        ↓
INVESTMENT BRAIN
        ↓
MARKET BRAIN
        ↓
WEALTH BRAIN
        ↓
LEARNING BRAIN
        ↓
SELF-STEWARDSHIP
```

With World's responsibility stated explicitly: "Preserve external macro, policy, industry, theme, event, and capital-flow context." Wealth Brain (= SPA Legacy) is a separate, later layer in the same list, not a container for World. **Macro-Regime Intelligence is its own top-level layer, architecturally prior to and independent of SPA Legacy** — the two happen to both be "North-Star, not M1" tier, but they are not nested. This correction matters because it clarifies that World-context tracking is not a wealth-management feature deferred alongside client/mandate concerns; it is the topmost, most foundational layer of the entire hierarchy.

### The gap this revealed

Neither of the two prior roadmap documents (the original proposal, nor Part 1 of this review) placed World/Macro or Industry/Cycle/Theme anywhere except the "broadest North-Star tier" — sequenced essentially last, after Business Pulse, Forecast/Valuation, Thesis, Portfolio, Discovery, and Technical Analysis. That is backwards relative to the stated philosophy: SPA should be watching the world first, continuously, from as close to day one as possible — not bolting macro on as a late-stage enrichment once everything else is mature.

### The reconciliation: build order vs. reasoning order are different things

M1 necessarily built bottom-up — company-level research infrastructure had to exist before anything could reason about how the world affects a specific company. That history does not need revisiting. But the roadmap from M1 forward had conflated "when do we build the deep analytical engine" with "when do we start watching." These should be split, the same way Portfolio Foundation was split into infrastructure vs. intelligence in Part 1, challenge 7:

- **World-context tracking should start immediately, continuously, and in parallel with Research Intelligence Deepening** — not as one item folded into the capture-early cluster, but as its own standing process: an append-only, point-in-time log of macro/policy/geopolitical/regulatory/liquidity/technological-disruption/commodity-supply-demand developments and why they matter, running from the earliest point in the new roadmap.
- **Industry/Cycle/Theme should get the same lightweight treatment early** — not full Theme Intelligence's Driver→Evidence→Catalyst→Counter-thesis structure (spec §13), but a simple classification-and-tracking layer: which themes/cycles exist, which companies sit in them, what is changing. This can start as soon as a handful of companies are researched — it needs breadth across companies more than depth within one.
- **Business Pulse's definition should be extended** — not just company-level stream synthesis as originally scoped in Part 1, but the point where accumulated World and Industry/Theme context *meets* company-specific state. This strengthens Business Pulse's original justification rather than redefining it: "what is this company's state right now" has always implicitly meant "in the context of what is happening around it." Making that explicit means Business Pulse should consume the World/Theme tracking stream as an input from the start, not have it bolted on later.
- **Full Macro-Regime Intelligence and full Theme Intelligence stay in the North-Star tier** — they genuinely need the pattern-detection/correlation depth that only comes with accumulated history — but now explicitly informed by having had raw World/Theme context accumulating since early on, rather than starting from zero when that tier is finally reached.

### Related implication: Discovery's position

The already-documented hierarchy places Discovery between World and Research Brain, not after Portfolio as the original roadmap proposal had it. The same infrastructure/intelligence split applies: a lightweight discovery signal (surfacing candidates from World/Theme shifts alone) becomes possible as soon as the early World/Theme tracking exists, while the full Discovery Engine — which the spec explicitly says combines Smart Capital, Event-Causality, and deep Theme Intelligence (§14) — correctly stays late, since it needs those other capabilities mature first.

### Revised sequencing proposed at the end of this round

1. Research Intelligence Deepening + capture-early cluster + minimal Portfolio Foundation (unchanged from Part 1) — **and now, added as a parallel standing process from this same starting point:** lightweight World/Macro context tracking + lightweight Industry/Cycle/Theme classification.
2. Business Pulse — now explicitly synthesizing company state through the World/Theme context already accumulating, not company-only. Alerts plumbing anchored here, as before.
3. Historical Commitment Backfill; Forecasting Depth → Valuation; Governance/Ownership Intelligence — unchanged.
4. Company Thesis Tracking; Promise-vs-Delivery Forward Scoring — unchanged.
5. Portfolio Decision Journal — unchanged gating.
6. Lightweight Discovery (World/Theme-driven candidate surfacing) — moved up, made possible once step 1's tracking exists.
7. Technical Analysis — unchanged.
8. North-Star tier, reordered: full Macro-Regime Intelligence and full Theme Intelligence sequenced at the front of this tier (they consume the most already-accumulated early-tracking history and directly enable the rest), followed by full Discovery, Smart Capital Intelligence, Event-Causality Intelligence, the Opportunity-Cost Engine, Methodology Evolution Engine, and the multi-actor/multi-asset graph.

This sequencing was itself refined further in Rounds 2–6 below.

## Round 2 — Causal-chain purpose: opportunity discovery, not commentary

### The clarification

The purpose is not generic macro commentary. It is opportunity discovery and causal reasoning: identify a structural change early, map its first-, second-, and third-order economic consequences, identify industries/business models that benefit or suffer, and only then find the companies positioned to capture that change.

### Worked example (AI / generative AI)

If SPA had recognized several years ago that AI would cause a structural explosion in compute demand, it should have mapped the chain from AI models → accelerated computing/GPUs → semiconductor infrastructure → high-speed networking → data centres → power availability → cooling/thermal management → electrical/grid equipment, and then searched for businesses such as Nvidia, Vertiv, and other beneficiaries before their opportunity became obvious.

### This is not a new capability — it is Theme Intelligence's own documented mechanism

The AI/GPU example maps exactly onto the spec's already-documented Theme Intelligence structure (§13):

```
Theme (AI compute demand explosion)
  → Drivers (AI model scaling, training/inference compute needs)
  → Evidence (capex announcements, chip demand data, capacity buildout)
  → Industry / value-chain position (accelerated computing → semiconductor
      infrastructure → high-speed networking → data centres → power
      availability → cooling/thermal management → grid equipment)
  → Company / Security (Nvidia, Vertiv, ...)
  → Exposure → Catalyst → Counter-thesis → Changes through time
```

This is the same shape as the spec's own PVC-oversupply example (§13: "depressed spreads → anti-dumping or capacity rationalisation → possible cycle normalisation → operating leverage → beneficiary companies"), just triggered from a macro/structural-disruption source instead of a narrower industry-cycle source. World is where the trigger is noticed; the causal-chain walk (order-1 → order-2 → order-3 → affected industries/business models → candidate companies) is Theme Intelligence's job, not a separate step before it.

### Why this changes the sequencing, not just the framing

Round 1 placed full Theme Intelligence in the same "needs accumulated history" bucket as Macro-Regime Intelligence and Governance/Ownership pattern-detection — genuinely later-stage work. But causal-chain mapping, as clarified here, is not a statistical pattern-detection problem. It is a structured-reasoning, evidence-cited, revisioned artifact — architecturally the same shape as M1's `ResearchRevision` (analyst/AI-authored, sourced, versioned as understanding evolves), just applied at theme/macro scope instead of company scope. It does not need years of proprietary data to produce its first useful output; it needs a schema for representing chains-of-consequence with evidence at each link, and can be populated by judgment from day one, refined as the thesis proves right or wrong over time. That is a much earlier-buildable thing than Round 1 credited it as.

**Split, the same pattern applied again:**

- **Early — Causal-Chain / Theme structure mechanism.** The trigger-to-candidate-companies chain itself: structural change → order-1/2/3 economic consequences → affected industries/business models → candidate companies, evidence-cited and revisioned. Moves from "late North-Star tier" to right alongside World tracking, close to the start of the post-M1 roadmap. It does not need deep company-level research maturity to function — it only needs to be able to name a company as a candidate (referencing M1's existing stable `Company`/`Ticker` identity), the same way a not-yet-researched company can be named without having a full research file yet.
- **Late — statistical/emergent Theme Intelligence.** Automatically detecting new themes from data patterns (rather than analyst-identified ones), and systematically correlating regime shifts to theme performance. This genuinely needs the accumulated history and stays in the North-Star tier, alongside full Macro-Regime Intelligence.

### This also resolves the Discovery question from Round 1

Round 1 separately proposed a "lightweight Discovery, moved earlier." That is not actually a separate mechanism — it is the direct output of the causal-chain tool: its terminal node ("companies positioned to capture this change, before it's obvious") *is* a Discovery candidate. Building the causal-chain mechanism early delivers early Discovery as a natural byproduct, rather than needing its own separate early build. Full Discovery (§14's combination of Smart Capital, Event-Causality, governance signals, ownership changes, etc.) stays late, exactly as documented — it is a richer synthesis than the causal-chain tool alone produces.

## Round 3 — Grounding in two real companies

### Chemplast Sanmar

PVC oversupply, China supply/export behaviour, crude/feedstock economics, Indian demand, anti-dumping/policy action, and capacity rationalisation can create a cycle-normalisation thesis. This is the spec's own PVC-oversupply example (§13), now grounded in a real company under active tracking, not a hypothetical.

The owner's framing states the dependency more strongly than Round 1 or 2 had it: *"SPA should understand the WORLD/industry-cycle change before interpreting Chemplast's Business Pulse and forecasts."* That is not "Business Pulse benefits from World/Theme context" — it is "Business Pulse interpretation is unreliable without it." This is the correct, firmer claim: without the PVC-cycle/China-dumping/anti-dumping-policy context, a Business Pulse reading of "Chemplast's margins compressed this quarter" looks like company-specific deterioration when it is actually an industry-cycle trough — precisely the kind of misread the causal-chain layer exists to prevent. **This should be treated as a hard sequencing dependency, not a soft enrichment: Business Pulse for a company in an active theme/cycle should not be considered fully interpretable until the relevant World/Theme chain exists.**

### EID Parry

Sugar prices, cane economics, government ethanol policy, diversion economics, monsoon/crop conditions, and regulatory decisions affect industry economics; SPA should connect those upstream variables to company earnings, capital allocation, and thesis change.

This extends the pattern usefully in a different direction from AI (technological) and Chemplast (trade-cyclical): the drivers here are agricultural/climate/policy-driven. Across the three worked examples, at least four distinct trigger types are now evidenced: **technological disruption** (AI), **trade/geopolitical behaviour** (China PVC export/dumping), **regulatory/policy** (anti-dumping duties, ethanol blending mandates), and **climate/natural** (monsoon, crop conditions). The causal-chain schema must stay general-purpose across all of these — it should not be built assuming any one of them as the "normal" case.

### Disambiguation: two different meanings of "capital allocation"

EID Parry's phrasing — "connect upstream variables to company earnings, capital allocation, and thesis change" — uses "capital allocation" to mean the company's own resource-allocation decisions (how much cane goes to sugar vs. ethanol, in response to blending policy), not the investor's portfolio capital allocation, which the roadmap has separately been using the same term for (Portfolio/Capital-Allocation Foundation, the Opportunity-Cost Engine). These are genuinely different things sharing a name. The company's-own-capital-allocation modelling (how management redirects capacity/output in response to upstream drivers) belongs in **Forecast/Valuation** — it is a modelling input, not a portfolio-phase capability. The two uses of "capital allocation" should be kept terminologically distinct going forward.

## Round 4 — Five-stage architecture reassessment

The owner asked whether the proposed Macro Context / Macro-Regime Intelligence, Theme Intelligence, and Research Discovery architecture adequately implements the top-down causal chain, distinguishing five stages: (1) World Context — what is changing globally/domestically; (2) Causal mapping — what industries/cycles/themes are affected and through what mechanism; (3) Opportunity discovery — which companies are exposed positively or negatively; (4) Business Pulse — is the expected effect actually appearing in company evidence; (5) Thesis feedback — is reality confirming or invalidating the original causal thesis.

Assessment: the architecture as described through Round 3 was **incomplete in a specific way** — stages 1, a merged 2+3, and 4 existed, but there was no clean separation between causal mapping and opportunity discovery, and no explicit theme-level feedback loop for stage 5.

### 1. World Context — adequately covered

Maps directly to the World/Macro/Policy/Disruption tracking layer already proposed. No revision needed.

### 2. Causal mapping — adequately covered, but fused with stage 3

This is the Causal-Chain/Theme mechanism: trigger → order-1/2/3 economic consequences → affected industries/business models. Correctly scoped as needing no company-level data at all — one can fully articulate "PVC cycle normalisation" as an industry thesis without yet knowing which companies are best-positioned within it.

### 3. Opportunity discovery — the actual gap

Round 2 had described the causal chain's "terminal node" as directly producing candidate companies, treating stages 2 and 3 as one mechanism. That is the gap. They are genuinely different operations with **different dependencies**:

- Stage 2 needs no company data — pure industry/theme reasoning.
- Stage 3 needs to screen a company universe against the industry thesis — which, or how many, companies in PVC, or in ethanol-blending-exposed sugar producers, are positioned to benefit or suffer, and by how much.

M1's existing foundation (`ResearchRevision` etc.) is deep-but-narrow — thorough research on a small set of companies. Stage 3 needs the opposite shape: **broad-but-shallow** coverage — sector/business-model classification and basic exposure attributes across a much wider company universe than SPA has deeply researched. This is a real infrastructural gap not previously identified: a lightweight company-universe reference layer, distinct from and cheaper to maintain than full deep research, is a genuine prerequisite for stage 3 to function at all. Without it, the causal-chain mechanism can articulate a correct industry thesis and still fail to surface Nvidia/Vertiv-equivalent beneficiaries simply because they are outside the narrow set of already-deeply-researched companies.

### 4. Business Pulse — role needs sharpening, not rebuilding

Round 1 scoped Business Pulse as a general company-state synthesis. The WORLD-first framing makes its role, for a company sitting inside an active theme, more specific and more falsifiable: it is a **hypothesis test** — is the effect the causal thesis predicted actually showing up in this company's evidence (margins, order book, capacity utilisation, management commentary), or not? This requires Business Pulse to carry an explicit reference to which causal-thesis record it is evaluating, and to record a confirm/contradict/inconclusive read against it — not just a freestanding state summary. Same underlying mechanism as originally proposed, sharper contract.

### 5. Thesis feedback — a genuine missing piece, at a different level than existing Thesis Tracking

Part 1 (challenge 3) already established company-level Thesis Tracking ("why do I like this company"). Stage 5 here asks about a **theme-level** loop: is the PVC cycle-normalisation thesis itself — the industry/causal claim, not any single company's position — being confirmed or invalidated by the rolled-up evidence across the companies inside it? That is a different object with a different owner. It needs:

- Its own status field on the Theme/Causal-Chain record (confirmed / invalidated / evolving), separate from any individual company's thesis.
- A rollup mechanism that watches multiple companies' Business Pulse confirm/contradict signals within the same theme and updates the theme's own status.
- An explicit link so that when a theme's status changes, every company thesis built on assuming that theme's chain gets flagged — a cascading-invalidation concern not resolved by company-level Thesis Tracking alone.

The mechanism (the schema, the linking, the rollup rule) can be built early, alongside stage 2 — it does not need to wait. What takes time is the evidence accumulating across enough companies in a theme for the rollup to mean anything, which is a maturity property of any single theme, not a reason to delay building the mechanism itself.

### Revised picture at the end of Round 4

The early tier is not "World tracking + Causal-Chain mechanism" as one clean pair feeding Business Pulse directly — it is five distinct pieces, three of which (World Context, Causal Mapping, the Thesis-Feedback mechanism) can start essentially immediately, one of which (Opportunity Discovery) needs the previously-unidentified broad-shallow company-universe layer to actually function, and one of which (Business Pulse) needs its existing design sharpened to carry an explicit link to the thesis it is testing rather than standing alone.

## Round 5 — Point-in-time hypothesis preservation (hindsight discipline)

### The requirement

How should SPA preserve the original point-in-time world/macro/theme hypothesis so that years later it can evaluate whether it identified the change correctly, chose the right beneficiaries, and acted appropriately — without hindsight rewriting the original reasoning?

Assessment: **the roadmap as developed through Round 4 did not adequately capture this.** Round 2 said the Causal-Chain/Theme mechanism should be "evidence-cited and revisioned, same pattern as `ResearchRevision`," but had not worked out what that needs to mean for this specific purpose, and left stages 3 and 5 described in ways that would quietly allow hindsight to creep in if built as described.

### Where the gap was

**Stage 3 (Opportunity Discovery) — the original beneficiary/loser list was not preserved as such.** Round 2/4 described it as producing "candidate companies," which reads as a current list. If implemented that way, there is no way to later distinguish "we flagged Nvidia and Vertiv when the theme was first identified" from "we added them to the list after they had already re-rated and it became obvious." Without preserving who was flagged as exposed positively or negatively, at what point-in-time revision of the theme, the system can silently inflate its own track record simply by letting the list drift forward as opportunities become obvious.

**Stage 5 (Thesis feedback) — the theme's status was described as a field, not a stream.** "Confirmed / invalidated / evolving" as a single mutable field means only the current belief survives. The actually valuable artifact — "we said uncertain/evolving in year 1, contradicted in year 2, confirmed in year 3" — is exactly the kind of point-in-time belief trajectory that cannot be reconstructed after the fact once the outcome is known. This needs to be a revision stream with its own history, not a field that gets overwritten.

**Stage 2 (the genesis hypothesis itself) — needs an explicit, permanently-anchored first version.** Even with revisioning, if nothing distinguishes "the original articulation" from "the 14th refinement," later edits can subtly reframe what was actually claimed at the start. There needs to be an explicit, permanently-referenced genesis record for each theme/causal-chain — not just "revision 1 of many," but a record type always retrievable as exactly what was first claimed, independent of how the thinking evolved afterward.

### Connection to the Learning Brain layer

The North-Star hierarchy (§22) already names the layer responsible for this: **Learning Brain** — "Evaluate outcomes, reasoning quality, calibration, and methodology versions." This had not been discussed anywhere in the roadmap through Round 4. This is where the actual "did we call this correctly, years later" evaluation belongs, applied to each stage of the chain: did SPA identify the World change correctly; did it map the right causal chain and transmission mechanism; did it identify the correct industries/companies (beneficiaries *and* losers); and did Business Pulse later confirm or invalidate the original hypothesis. It is correctly a late capability, since it needs years of elapsed time and accumulated outcome data to mean anything. That part of the prior sequencing does not need to change.

What does need to change is recognising that **Learning Brain's later usefulness is entirely dependent on capture discipline built into the early mechanism, not something Learning Brain can retrofit.** If the genesis hypothesis, the point-in-time beneficiary list, and the belief-trajectory stream are not preserved immutably from day one, there is nothing honest for a Learning Brain evaluation to score later — it would just be scoring a hindsight-smoothed narrative. This is the same "capture now or lose it forever" principle from Part 1 (challenge 5), applied one level higher: not only must data be captured early, the shape of the claim itself must be structurally protected from later editing.

### A unifying pattern

This is the same structure as Promise-vs-Delivery (Part 1, challenge 4), just one level up: an immutable, dated claim (management's commitment / SPA's theme-call) compared later against what actually happened, producing a calibration score. SPA's architecture has this "immutable point-in-time claim → later comparison against reality → scored calibration" shape recurring at three levels: management commitments (company level), company thesis (Thesis Tracking), and theme/world-causal-calls (this round). The pattern should be kept explicit and consistent across all three rather than solved three separate times.

### Design-requirement corrections from this round

Not a sequencing change — a design-requirement correction applied to the early Causal-Chain/Theme mechanism itself, before it is built, not after:

1. Every theme/causal-chain gets an explicit, permanently-referenced genesis record, distinct from its later revisions.
2. Every revision of "who's exposed" preserves the prior beneficiary/loser list unchanged — new names get added as new revisions, never retroactively inserted into the original.
3. Business Pulse confirm/contradict evidence is genuinely append-only (matching M1's existing discipline, made explicit here).
4. Theme-level status (stage 5) is a revision stream, not a field.
5. A Learning Brain evaluation capability is explicitly added to the North-Star tier — correctly late, but its dependency on 1–4 being right from the start is a hard constraint, not an afterthought.

## Round 6 — World Context / Causal Intelligence: named concept, epistemic grounding, and competing hypotheses

### The concept, formalized

A neutral World Context / Causal Intelligence concept should be added to the roadmap. SPA should observe major global conditions — fiscal deficits, interest rates, dollar/liquidity movements, commodity prices, geopolitics, wars, trade restrictions, sanctions, government policy, defence spending, technological disruption, and capital flows — without assigning unsupported motives. The engine should ask:

1. What changed?
2. Why might it matter?
3. Through which transmission mechanism?
4. Which industries/themes/cycles benefit or suffer?
5. Which companies are exposed?
6. Is Business Pulse later confirming the expected effect?

### Grounding: this is Section 6 (Epistemic Separation), applied to world/macro observation

The "neutral, no unsupported motives" requirement is not a new principle — it is the already-documented system-wide invariant (spec §6):

```
Source → Evidence → Fact → Hypothesis/Inference → Forecast → Valuation → SPA Research View
```

The spec's own worked example is exactly the discipline required here: "The trade preceded the policy announcement by 31 days" may be a fact; "Therefore privileged information was used" is not a valid conclusion without direct evidence. World Context / Causal Intelligence is the same discipline applied one level up — "large fiscal deficits exist, the dollar is moving, geopolitical tension is rising" are observable facts; "this is why, and this administration/actor caused it" is exactly the kind of unsupported-motive assertion the architecture already prohibits. The engine should stop at hypothesis/inference, explicitly hedged ("why might it matter"), never collapse to asserted political cause.

The six-question engine above is the same five-stage decomposition from Round 4, now given a single name, explicit epistemic grounding, and a complete input scope.

### New structural requirement: one world observation can branch into competing hypotheses

Worked example: large U.S. deficits + changing dollar/rate conditions + geopolitical tensions + energy disruptions + rising defence expenditure can create multiple competing causal hypotheses and investment consequences across defence, energy, shipping, chemicals, data centres, infrastructure, and other industries. SPA should preserve the evidence and competing explanations rather than politically blaming any actor.

This reveals something the Chemplast/EID Parry examples (Round 3) did not test: a single world observation does not reduce to a single causal chain. It can spawn several simultaneously — defence spending up, energy/shipping/chemicals affected in scenario-dependent ways, data-centre/infrastructure capital availability shifting with rate conditions — and some of these may be mutually exclusive rather than independent (e.g., "rates stay elevated because of deficit-driven supply pressure" vs. "rates get cut for political reasons" are competing scenarios with different, sometimes opposite, downstream beneficiaries). This means the World Context → Theme/Causal-Chain relationship is **one-to-many**, and where branches are genuinely scenario-dependent rather than merely independent, the architecture needs to represent them as explicitly competing hypotheses — not resolve prematurely to one narrative, and not silently let a later scenario overwrite an earlier one's record (the same immutability discipline from Round 5, now applied to which scenario branch was believed at the time, not just whether the theme was confirmed or not).

This refines, but does not replace, the Round 5 design requirements: each theme/causal-chain record still needs its immutable genesis, its point-in-time beneficiary list, and its revision stream — and now, explicitly, the ability for multiple sibling theme-records to share one World Context parent as competing (not merged) branches.

Re-affirmed with the AI and PVC/sugar-ethanol examples: AI disruption maps AI → compute → semiconductors → networking → data centres → power/cooling/grid infrastructure → exposed companies; industry cycles such as PVC or sugar/ethanol connect macro/policy/supply-demand changes to Chemplast Sanmar or EID Parry specifically — confirming the mechanism generalizes across single-chain themes (PVC, sugar/ethanol) as well as multi-branch, competing-scenario cases (the U.S. deficit example).

### The final, crystallized seven-node chain

The objective is a persistent intelligence chain, with the original point-in-time hypothesis retained so SPA can later measure whether its causal reasoning was correct:

```
WORLD → CAUSAL MAP → INDUSTRY/CYCLE/THEME → COMPANY → BUSINESS PULSE → THESIS → PORTFOLIO
```

Two refinements to note explicitly rather than treat as implicit:

**CAUSAL MAP and INDUSTRY/CYCLE/THEME are two distinct nodes, not one.** Round 4's five-stage breakdown had bundled them ("which industries/themes are affected and through what mechanism"). The seven-node chain splits them cleanly: CAUSAL MAP is the mechanism/reasoning itself (the order-1/2/3 transmission chain), INDUSTRY/CYCLE/THEME is the resulting classification of where that mechanism lands. This is a cleaner separation of "how" from "where" and should be adopted as the structure going forward.

**The point-in-time-hypothesis requirement generalizes across the whole chain, not just the World/Theme layer.** Round 5 scoped the immutability/genesis-record discipline to the Causal-Chain/Theme mechanism specifically. Stating it as a property of the whole WORLD → ... → PORTFOLIO chain makes explicit something that should have been obvious from M1 itself: M1 already applies immutable, append-only revision history uniformly across `ResearchRevision`, `ForecastRevision`, and `ValuationRevision` — that is not a special rule for Theme, it is SPA's standing discipline. Every new node this roadmap adds (World, Causal Map, Industry/Theme, Company/Discovery, Business Pulse, Thesis, Portfolio) should inherit it the same way, not have it bolted on selectively where the conversation happened to surface the need. Business Pulse readings, thesis positions, and portfolio decisions should all retain their point-in-time originals for the same reason the Theme layer needs to — so that years later, SPA can evaluate not just "was the world-causal-thesis right" but "was each link in the chain reasoned correctly, at the time, given what was knowable then."

Note on the THESIS node: the seven-node chain states "THESIS" as a single node for brevity. This should be read as the umbrella covering both distinct levels established earlier — company-level Thesis Tracking (Part 1, challenge 3) and theme-level Thesis Feedback (Round 4, stage 5) — both of which Business Pulse evidence feeds, and both of which gate Portfolio. The two-level distinction from Rounds 4–5 remains in force; the seven-node chain does not collapse it, it summarizes it.

---

# Consolidated Final Sequencing (supersedes the "Recommended Milestone Sequence" list above for the World/Causal-Intelligence capabilities specifically; all other Part 1 milestones are unchanged)

1. **Research Intelligence Deepening** + capture-early cluster (price/volume, forward commitments, disclosure-reaction timing) + minimal, capture-only Portfolio Foundation — **plus, started here as a parallel standing process:** World Context tracking (the neutral, epistemically-disciplined observation log) and the Causal-Chain/Theme structure mechanism (trigger → order-1/2/3 consequences → affected industries/themes, evidence-cited, immutable genesis + revision stream, supporting competing/branching hypotheses from a single World observation).
2. **The broad-shallow company-universe reference layer** (sector/business-model classification across a wide company set, distinct from and cheaper than deep `ResearchRevision`-level research) — identified in Round 4 as a prerequisite for Opportunity Discovery; should be built alongside step 1.
3. **Opportunity Discovery** (screening the company universe against active causal-chain/theme records; point-in-time beneficiary lists preserved immutably per revision, never retroactively edited).
4. **Business Pulse** (company-state synthesis, now explicitly a hypothesis test against any linked causal-chain/theme record for companies inside an active theme — a hard dependency for correct interpretation, not a soft enrichment) + minimal shared Alerts/event plumbing, anchored here.
5. **Theme-level Thesis Feedback** (rollup of Business Pulse confirm/contradict signals into the theme's own status, recorded as a revision stream, cascading flags into dependent company theses) — mechanism built alongside step 1, value accumulating as evidence matures.
6. Historical Commitment Backfill; Forecasting Depth → Valuation (with company-owned capital-allocation-response modelling folded in here, distinct from portfolio-level capital allocation); Governance/Ownership Intelligence — as in Part 1.
7. **Company Thesis Tracking** — independent of portfolio; mandatory point-in-time confidence field from day one; explicitly linkable to the theme(s) it depends on.
8. Promise-vs-Delivery Forward Scoring — as in Part 1.
9. **Portfolio Decision Journal** — gated on Portfolio Foundation and Company Thesis Tracking, as in Part 1.
10. Technical Analysis — as in Part 1.
11. **North-Star tier**, reordered: full statistical Macro-Regime Intelligence and emergent/automatic Theme detection sequenced at the front of this tier (they consume the most already-accumulated early-tracking history), followed by the full Discovery Engine (Smart Capital + Event-Causality + everything above, combined), Smart Capital Intelligence, Event-Causality Intelligence, the Opportunity-Cost Engine, Methodology Evolution Engine, the multi-actor/multi-asset graph, and **the Learning Brain evaluation capability** (scoring SPA's own historical causal calls against outcomes — entirely dependent on the immutable capture discipline in steps 1–5 having been honoured from the start).

Architecture/product reasoning only. No files modified beyond this consolidation, no code changed, no tasks created, no implementation begun.
