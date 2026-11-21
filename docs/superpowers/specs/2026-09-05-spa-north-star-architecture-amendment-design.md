# SPA North-Star Architecture Amendment
## Global, Multi-Asset, Smart-Capital and Institutional-Memory Compatibility

**Status:** Controlled amendment to the approved Milestone 1 architecture

**Date:** 2026-09-05

**Applies to:** SPA Investment Operating System architecture

**M1 implementation scope:** Unchanged

## 1. Purpose

SPA is being built first as the family's permanent investment-intelligence and wealth-management operating system. It may later become a research product and subscription business. Commercialization is a possible use of the system; it does not define the truth, evidence, or investment-methodology layers.

SPA supports this investment workflow:

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

The approved M1 design creates a company-centered research foundation. This amendment records the broader architectural constraints needed to keep that foundation compatible with the long-term SPA system. It does not expand M1 into the future subsystems described here.

The controlling principle is:

> M1 builds the first durable Company Research Brain. Future capability must not require destroying or rewriting M1's institutional history.

### 1.1 Amendment control and precedence

The approved M1 design at `docs/superpowers/specs/2026-09-04-investment-operating-system-milestone-1-design.md` remains immutable historical design. The five current implementation plans and their 37 tasks also remain unchanged by this amendment.

This document is an additive architectural control. It governs the interpretation of current M1 choices and the design of later phases. It does not retroactively replace M1 entities, fields, APIs, migrations, acceptance criteria, or task ordering. If a later impact assessment finds a material conflict, work stops at that conflict until a human approves a specific resolution.

## 2. M1 scope boundary

M1 remains company- and equity-focused. It implements the first durable Company Research Brain using the relational architecture already approved.

M1 does not implement:

- ETF research;
- mutual-fund or other fund research;
- index research;
- US or other global research adapters;
- a `Security` or `Listing` abstraction;
- an `InvestmentActor` or Smart Capital transaction engine;
- Theme Intelligence;
- Event-Causality Intelligence;
- Global Research Discovery;
- a Portfolio or Capital Allocation Brain;
- an Opportunity-Cost Engine;
- a Decision Journal;
- a Methodology Evolution Engine;
- SPA Social;
- SPA Legacy UHNI, client, or wealth-manager functionality;
- client mandates;
- private family portfolios;
- tax or entity intelligence; or
- autonomous architecture changes.

These are North-Star capabilities or later phases. Their description in this amendment does not authorize their implementation, add work to the 37-task M1 plan, or justify speculative M1 tables. M1 tables exist only when required by approved M1 behavior.

## 3. Investment-universe invariant

SPA is an investment-intelligence system whose long-term research universe is broader than equities. Researchable or investable entities may eventually include:

- companies and equities;
- ETFs;
- mutual funds and other funds;
- indices;
- REITs and InvITs; and
- bonds or other securities where future requirements justify them.

The approved M1 interpretation is:

- `Company` remains the implemented research entity.
- Existing `Ticker` remains the current market-price bridge.
- M1 does not create generic `ResearchSubject`, `Security`, or `Listing` tables.
- M1's one-primary-ticker-per-company constraint is a bounded M1 operating rule, not a permanent assertion that one company always equals one tradable instrument.
- Company identity, research history, and document relationships must not be defined solely by a mutable symbol or exchange code.

The frozen M1 schema's required unique `Company.isin` remains unchanged. In M1, it is a bounded identifier for the primary listed equity represented by the `Company`/`Ticker` relationship. It is not evidence that an ISIN is SPA's permanent universal identifier for the corporate issuer. A future approved `Security`/`Listing` architecture may map or migrate that security identity to the appropriate `Security` while preserving `Company.id`, historical research revisions, and existing relationships. This clarification introduces no `Security`, `Listing`, or other table in M1.

The possible future abstraction is conceptual only:

```text
Research Subject
        ↓
Domain object: Company / ETF / Fund / Index / other approved type
        ↓
Security
        ↓
Listing
```

No M1 API, table, migration, or service is required to expose this abstraction. A later approved migration may introduce it while preserving existing Company identifiers and immutable revision history.

## 4. Global-compatibility invariant

M1 is operationally India-first and structurally global-ready. India-first behavior is valid within M1; it must not be documented or encoded as the universal meaning of the generic research domain.

Generic research semantics must not permanently assume:

- NSE or BSE are the only exchanges;
- INR is the only currency;
- Regulation 30 is the universal disclosure format;
- promoter is the universal ownership concept; or
- Indian corporate and governance terminology applies unchanged in every jurisdiction.

M1 may use `NSE`, `INR`, `REG30`, promoter holding, and promoter pledge where the frozen design explicitly requires them. Those are M1 values and India-specific semantics. Extensible classifications, provenance, stable identities, and later migrations provide the seam for other jurisdictions.

Future jurisdiction adapters may map local sources and legal concepts into common evidence and research semantics. Examples include:

| Jurisdiction | Market-specific sources and concepts |
|---|---|
| India | NSE/BSE, Regulation 30, shareholding pattern, promoter/promoter-group, pledge/encumbrance |
| United States | SEC/EDGAR, 10-K, 10-Q, 8-K, Form 4, 13D/13G, institutional filings, insider activity |

The United States adapter and all other global adapters are outside M1.

## 5. Point-in-time evidence

SPA must distinguish what is known now from what was publicly knowable at an earlier date. Historical reconstruction asks:

> What publicly available evidence could reasonably have existed at that time?

Where a reliable source supplies them, SPA must preserve distinct meanings for:

- event or document date;
- public publication or availability time;
- SPA discovery time;
- SPA ingestion time; and
- research revision timestamp.

This is a North-Star conceptual model, not an M1 persistence requirement. M1 persists only the date and timestamp fields already approved in the frozen design. This amendment does not add `published_at`, `discovered_at`, `ingested_at`, `evidence_cutoff_at`, or any similar column.

Existing `document_date`, `event_date`, `effective_at`, `created_at`, and `updated_at` fields retain their frozen meanings. They are not interchangeable and must not be overloaded to impersonate another temporal fact. Where M1 has no explicit field for a distinct publication, availability, discovery, ingestion, or evidence-cutoff time, that fact remains unrecorded and unknown in structured M1 storage rather than being fabricated or inferred from another timestamp.

Later information must never silently contaminate an earlier historical thesis. If an investor transaction occurs on June 15 and a policy announcement occurs on July 10, the July announcement is not evidence available to the June 15 research state. A later analysis may compare the two events, but it must preserve the dates, the evidence available at each cutoff, and the fact that chronology alone does not establish causality.

M1 does not build a temporal evidence graph or add temporal columns through this amendment. It preserves immutable revisions, provenance, stable document and disclosure identities, and the frozen meanings of existing dates so a future approved temporal or evidence model can add the missing distinctions without rewriting prior research.

## 6. Epistemic separation

The following sequence is a system-wide semantic invariant:

```text
Source
  → Evidence
  → Fact
  → Hypothesis / Inference
  → Forecast
  → Valuation
  → SPA Research View
  → future Portfolio View
  → future Client Recommendation
```

Each transition changes the epistemic status of information. Implementations, prompts, schemas, presentations, and human workflows must not silently collapse these concepts.

Examples:

- "Promoter purchased ₹20 crore" may be a fact when a reliable source directly supports the actor, transaction, amount, and date.
- "Promoter expects a recovery" is an inference unless a reliable source explicitly records that statement.
- "The trade preceded the policy announcement by 31 days" may be a factual temporal relationship when both dates are supported.
- "Therefore privileged information was used" is not a valid factual conclusion without direct evidence.

SPA may investigate correlation, timing, policy relationships, and competing explanations. The broader future system should retain source provenance, state uncertainty, preserve alternatives, and record confidence where an approved model supports it; this does not add an M1 confidence field. SPA must never turn suspicion, sequence, or model-generated narrative into an asserted fact.

M1's existing distinctions among document source metadata, governance factual evidence and interpretation, forecasts, valuation snapshots, and research conclusions remain valid. This amendment requires disciplined use of those meanings; it does not introduce new M1 tables.

## 7. Authoritative SPA Research View

`ResearchRevision` remains the authoritative immutable M1 point-in-time representation of what SPA believed at that moment. M1 must not introduce a second `InvestmentViewRevision` table.

The broader SPA Research View conceptually includes separation among:

- factual inputs;
- thesis and inference;
- catalysts;
- risks;
- falsifiers and invalidation conditions;
- confidence;
- what changed; and
- evidence cutoff and point-in-time context.

M1 persists only the `ResearchRevision` fields already approved in the frozen design. Confidence and explicit evidence cutoff are not new M1 persisted fields. In particular, `effective_at` and `created_at` retain their frozen meanings and must not be reinterpreted as an evidence cutoff. This conceptual separation governs how the broader SPA architecture evolves; it does not authorize field or schema expansion in M1. A future approved evidence or methodology model may add explicit confidence and evidence-cutoff semantics additively while preserving existing revisions.

AI-generated output is not itself the historical record. The stored revision is the record. A later model may analyze, critique, summarize, or explain a prior M1 revision, but it must identify the exact revision and use its actual stored timestamps and provenance. It must not invent an evidence cutoff that M1 never recorded or silently change the stored view.

Creating a later ResearchRevision is the approved way to update SPA's belief. The earlier revision remains immutable and independently interpretable.

## 8. Institutional memory

Research history is permanent institutional memory. Old research revisions, forecasts, valuation assumptions, reference lines, market plans, and conclusions must not be silently overwritten.

Future SPA should be capable of evaluating:

- what SPA believed;
- what evidence supported the belief;
- what assumptions were made;
- what subsequently happened;
- whether the conclusion was correct;
- whether the reasoning was correct even when the outcome was not; and
- whether the methodology itself needs improvement.

Outcome quality and reasoning quality are separate assessments. A sound process can produce an adverse outcome; a poor process can benefit from luck. Evaluation must preserve that distinction.

Future methodology versions must be identifiable and historically reproducible. Reprocessing with a newer model or method may create a new analysis, but it must not replace the method, inputs, or result associated with an earlier authoritative record.

M1 does not build Methodology Evolution or Decision Journal infrastructure. Its immutable revision streams, provenance rules, explicit supersession, and append-only history are the durable foundation for those later capabilities.

## 9. Smart Capital Intelligence — North Star

Smart Capital Intelligence is a future first-class subsystem for observing and analyzing identifiable sophisticated-capital behavior where lawful, reliable data exists.

Potential observable actors include:

- promoters;
- founders;
- directors;
- executives and insiders;
- HNIs;
- family offices;
- PMS managers;
- AIFs;
- mutual funds;
- FIIs and FPIs;
- specialist sector investors;
- global asset managers;
- hedge funds;
- activists;
- other identifiable sophisticated capital; and
- public officials or politicians only where lawful public financial disclosures exist.

The long-term subsystem should be able to represent and investigate:

```text
WHO
  → bought or sold WHAT
  → WHEN
  → HOW MUCH
  → through which transaction or ownership type
  → at what valuation and business condition
  → against what public evidence available at the time
  → followed by what subsequent outcome
  → in the context of that actor's comparable historical behavior
```

Smart Capital is a research trigger, not proof of investment correctness. SPA's investigative question is:

> What publicly observable information may this investor have interpreted better than the market?

SPA must not substitute the question, "What secret information did this investor know?" or assert non-public knowledge without direct evidence.

No Smart Capital model, adapter, ingestion path, transaction engine, signal, table, or API is part of M1.

## 10. Historical actor behavior

Future SPA may construct evidence-based actor histories to test patterns such as:

- how often an investor accumulates during drawdowns;
- whether observable entries precede earnings inflections;
- sectors in which observable decisions have historically been strongest;
- whether buying was token or economically meaningful;
- whether an insider tends to buy before capacity ramp-up;
- whether promoter selling coincides with deteriorating governance or financial signals; and
- whether multiple sophisticated actors independently converge on the same thesis.

Every pattern requires a defined observation universe, point-in-time evidence, comparable denominators, and explicit uncertainty. Selection bias, reporting thresholds, incomplete identities, delayed disclosures, corporate actions, and survivorship bias must remain visible limitations.

Historical actor behavior is one evidence input into discovery and research. It does not authorize naive copy trading or mechanically produce an Add, Hold, Reduce, or Exit conclusion.

M1 `OwnershipSnapshot` remains a dated company-level aggregate for promoter holding and pledge context. It is not the complete actor engine. M1 does not introduce `InvestmentActor` or transaction-history tables. Stable company identity, source references, snapshot dates, and append-only history preserve a future migration seam.

## 11. Promoter and insider forensics

Future Smart Capital Intelligence may include:

- open-market buying and selling;
- preferential allotments and conversions;
- promoter holding changes;
- pledge or encumbrance changes;
- insider transactions;
- block and bulk activity;
- director or KMP transactions;
- management remuneration;
- related-party trends;
- capital allocation; and
- governance events.

Every observation must be contextualized by economic size, actor identity, transaction type, ownership structure, business conditions, price, valuation, prior behavior, disclosure rules, and evidence available at the time.

Potentially meaningful convergence may look like:

```text
Price down
+ earnings down
+ promoter buying
+ pledge reduction
+ capex nearing commissioning
```

Potentially adverse convergence may look like:

```text
Management guidance up
+ promoter selling
+ CFO resignation
+ receivables rising
+ OCF/PAT deteriorating
```

Neither pattern is a conclusion. No single transaction is automatically bullish or bearish, and no timing relationship alone establishes motive, correctness, causality, or illegality.

## 12. Event-Causality Intelligence — North Star

Event-Causality Intelligence is a future subsystem for investigating temporal and economic relationships such as:

```text
Capital movement
  → subsequent policy, regulatory, or corporate event
  → earnings or industry consequence
  → market consequence
```

It may also investigate the reverse discovery path:

```text
Public policy breadcrumbs
  → sophisticated capital movement
  → formal policy outcome
  → possible undiscovered beneficiaries
```

The subsystem must:

- distinguish chronology from causality;
- retain primary-source evidence;
- determine what information was already public before a transaction;
- test competing explanations;
- measure whether exposure was specific to the security or part of a broad sector move;
- distinguish an investor, spouse, trust, fund, or reportable account when the source supports that distinction;
- expose missing or delayed evidence; and
- never infer illegality merely from timing.

Findings must identify evidence, time windows, tested alternatives, confidence, and unresolved uncertainty. Event-Causality Intelligence does not exist in M1, and this amendment does not authorize its engine, graph, models, ingestion, or API.

## 13. Theme Intelligence — North Star

Theme is a future first-class research object rather than a text tag. Its conceptual structure is:

```text
Theme
  → Drivers
  → Evidence
  → Industry
  → Value-chain position
  → Company / Security
  → Exposure
  → Catalyst
  → Counter-thesis
  → Changes through time
```

Examples include:

```text
AI compute
  → data-centre buildout
  → power, cooling, and transmission constraints
  → direct and second-order beneficiaries
```

```text
PVC oversupply
  → depressed spreads
  → anti-dumping or capacity rationalisation
  → possible cycle normalisation
  → operating leverage
  → beneficiary companies
```

Theme Intelligence should eventually allow SPA to ask:

> If the thesis strengthens, which beneficiaries have not yet rerated?

Themes must retain evidence, counter-theses, exposure strength, time, and versioned changes. M1 does not introduce Theme tables, Theme APIs, or theme-driven discovery behavior.

## 14. Discovery Engine relationship

Long-term Discovery may combine:

- company transformation;
- capacity addition;
- order-book inflection;
- management change;
- industry cycle;
- policy change;
- valuation anomaly;
- Smart Capital;
- promoter or insider behavior;
- Theme Intelligence;
- Event Causality;
- ownership changes;
- governance improvement or deterioration;
- technology and intellectual property;
- hidden assets; and
- margin or operating-leverage possibilities.

The objective is not to mechanically find "10X stocks." The objective is to identify conditions from which asymmetric outcomes could emerge before conventional reported numbers make them obvious.

Discovery produces research candidates and questions. It does not produce an authoritative SPA Research View, portfolio allocation, or client recommendation by itself. Smart Capital feeds Discovery as one evidence source; it never becomes a standalone buy or sell signal.

Discovery automation is outside M1.

## 15. Multi-actor and multi-asset graph — future concept

The long-term conceptual relationship graph is:

```text
Research Subjects
        ↕
Securities / Listings
        ↕
ETFs / Funds
        ↕
Institutions / Investors
        ↕
Ownership / Transactions
        ↕
Themes
        ↕
Events
        ↕
Evidence
        ↕
Time
```

This describes relationships the future system may need to traverse. It is not a physical database design.

M1 remains relational. It does not implement a graph database, redesign Company Research as a graph, or create generic speculative entity tables. Stable identifiers, explicit foreign keys, provenance, immutable history, and additive migrations are sufficient M1 compatibility mechanisms.

## 16. SPA Legacy

SPA Legacy remains North-Star-only for M1. It may eventually serve the user's family first and potentially a limited number of UHNI families, each guided by a dedicated Wealth Manager.

The conceptual separation is permanent:

1. **SPA Research View** — what SPA believes about an investment.
2. **SPA Portfolio View** — the potential role of the investment in a portfolio.
3. **Client Recommendation** — what an authorized Wealth Manager recommends for a specific client and mandate.

These concepts must never become the same field, object, or authorization decision. The same SPA Research View may lead to different portfolio conclusions or client recommendations because mandates, taxes, liquidity, concentration, time horizon, and constraints differ.

Future SPA Legacy requirements may include:

- strong tenant isolation;
- family and client mandates;
- Wealth Manager roles;
- role-based access control;
- portfolio holdings;
- tax and entity constraints;
- liquidity constraints;
- concentration limits;
- ethical exclusions;
- geography and currency constraints;
- immutable recommendation and approval history; and
- private client-data isolation.

No SPA Legacy table, API, mandate, private portfolio, tax model, or client authorization path is part of M1. M1's shared Research Brain must not contain private client records or client-specific recommendations. M1 must preserve enough separation that a later private Wealth Brain can reference research without merging its data or permissions into the common Research Brain.

## 17. Future Social

SPA Social is future-only. A later approved system may include:

- Company Rooms;
- Theme Rooms;
- Research Discussions;
- evidence-oriented tags such as `Bull Case`, `Bear Case`, `New Evidence`, `Governance`, `Valuation`, and `Question`;
- discussions attached to stable research objects; and
- community evidence that triggers review.

Community content must never overwrite the authoritative SPA Research View. "Community says" and "SPA says" remain distinct in storage, presentation, provenance, permissions, and audit history. Any future Social system requires moderation, audit, conflict-disclosure, abuse, and entitlement controls before release.

M1 has no Social schema or behavior. Stable Company identity and immutable research history provide sufficient future attachment points.

## 18. Architecture stewardship

Future SPA may observe signals that its architecture or investment methodology has become inadequate. The governing principle is:

> Self-observing, not recklessly self-modifying.

A future controlled process may be:

```text
Observe
  → Diagnose
  → Propose Architecture Change Thesis
  → Human approval
  → Execute
  → Validate or roll back when required
```

Consequential changes to database semantics, research logic, entitlements, immutable history, investment methodology, or private-client boundaries remain auditable and human-governed. An AI system may identify evidence, diagnose limitations, and propose changes. It may not autonomously redefine those boundaries or rewrite historical records.

M1 has no autonomous architecture engine.

## 19. Hard M1 compatibility requirements

The following must remain true throughout M1:

### A. Implemented research identity

`Company` is the implemented M1 research entity. It is not declared the permanent universal research root for every asset class.

### B. Current market-price bridge

Existing `Ticker` may serve M1 market-price needs, including the approved unique primary link from Company, without creating a permanent one-company/one-security/one-listing promise.

### C. Jurisdiction-neutral semantics

Generic research concepts remain jurisdiction-neutral where practical. India-specific values retain explicit M1 or adapter context.

### D. Authoritative ResearchRevision

`ResearchRevision` remains immutable and is the authoritative point-in-time SPA Research View. No parallel M1 investment-view revision is introduced.

### E. Immutable forecast and valuation history

`ForecastRevision` and `ValuationRevision`, including their approved immutable child records, remain point-in-time objects and are never silently overwritten.

### F. Provenance and temporal reconstruction

Documents and disclosures preserve their approved provenance and date meanings. Current fields must not be overloaded, and unavailable dates must not be invented. The result must remain compatible with later point-in-time reconstruction.

### G. Epistemic boundaries

Sources, evidence, facts, inference, forecasts, valuation, and SPA conclusions remain conceptually distinguishable even where M1 stores narrative snapshots rather than a complete evidence graph.

### H. Ownership migration seam

`OwnershipSnapshot` remains the approved M1 company-level ownership record. Its aggregate promoter fields must not be presented as a universal actor model or used to make future identifiable-investor and event migration impossible.

### I. Entitlement evolution

M1 implements the approved `FREE` and `PREMIUM` research tiers. The entitlement boundary must remain capable of later approved evolution toward Basic, Premium, and Premium Global without implementing Global access, global content, billing history, or new tiers in M1.

### J. Private-client separation

SPA Legacy client, mandate, portfolio, tax, entity, and recommendation data must not be mixed into the common Research Brain.

### K. Stable future relationships

Stable research identity and immutable history must permit future Theme, Social, Smart Capital, security, listing, event, and evidence relationships through approved additive evolution.

### L. No speculative schema

No future table, generic abstraction, API, engine, or adapter is introduced unless current approved M1 behavior requires it.

## 20. Explicit non-goals

This amendment:

- does not authorize implementation of any future system;
- does not automatically expand or revise the 37-task M1 plan;
- does not modify the database;
- does not modify frontend scope;
- does not add United States or global ingestion;
- does not add ETF, fund, index, REIT, InvIT, bond, Security, or Listing support;
- does not add Smart Capital Intelligence;
- does not add InvestmentActor or transaction history;
- does not add Theme Intelligence;
- does not add Event-Causality Intelligence;
- does not add a Portfolio, Wealth, Opportunity-Cost, Learning, Decision Journal, or Methodology Evolution engine;
- does not add SPA Legacy;
- does not add SPA Social;
- does not add autonomous architecture changes; and
- does not change existing authentication, trading, Kite, websocket, alert, Telegram, database, or frontend behavior.

## 21. Impact-assessment rule

After this specification is approved, the existing implementation plan may be reviewed against it in a separate, explicitly authorized task. Each existing M1 task must receive one classification:

| Classification | Meaning |
|---|---|
| `NO CHANGE` | The task already satisfies this amendment and requires no edit. |
| `WORDING/SEMANTIC CLARIFICATION ONLY` | The implementation remains the same; wording must prevent a temporary M1 choice from becoming a permanent architectural claim. |
| `SMALL COMPATIBILITY CHANGE` | A bounded change is needed to preserve an approved seam without adding a future subsystem. |
| `MATERIAL DESIGN CONFLICT` | The task cannot satisfy both the frozen M1 design and this amendment without a consequential design decision. Human approval is required before changing the plan or implementation. |

The default classification is `NO CHANGE`. The existence of a North-Star capability is never sufficient reason to expand M1. Any claimed compatibility change must identify the exact M1 requirement at risk, the smallest proposed remedy, its migration and history implications, and why deferral would close a real future seam.

This document does not perform that task-by-task assessment and does not revise an implementation plan.

## 22. Architectural North Star

SPA's conceptual hierarchy is:

```text
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

The hierarchy is surrounded by these invariants:

- immutable history;
- provenance;
- point-in-time truth;
- security;
- permissions;
- human governance;
- portability; and
- versioned methodology.

The layers have distinct responsibilities:

| Layer | North-Star responsibility |
|---|---|
| World | Preserve external macro, policy, industry, theme, event, and capital-flow context. |
| Discovery | Identify research candidates and questions from evidence and change. |
| Research Brain | Maintain sourced facts, analysis, forecasts, valuation, falsifiers, and the authoritative SPA Research View. |
| Investment Brain | Translate research into investment cases, opportunity comparisons, sizing inputs, and decision options. |
| Market Brain | Observe price, liquidity, positioning, accumulation, and market behavior without rewriting fundamental truth. |
| Wealth Brain | Apply portfolio, mandate, client, tax, liquidity, and concentration context under separate permissions. |
| Learning Brain | Evaluate outcomes, reasoning quality, calibration, and methodology versions. |
| Self-Stewardship | Observe system limitations and propose auditable, human-approved architectural change. |

M1 implements only the first durable foundation beneath this North Star. It does not implement the complete hierarchy.

## 23. Constitutional principles

1. SPA is an investment-intelligence system, not an equity-only database.
2. Evidence and facts are different from inference.
3. Correlation is not automatically causation.
4. Smart Capital behavior is a research trigger, not a buy or sell instruction.
5. SPA investigates what sophisticated investors may have understood from public evidence rather than inventing claims about secret knowledge.
6. Historical research is permanent institutional memory.
7. Later evidence must never silently rewrite an earlier point-in-time SPA view.
8. AI-generated analysis is replaceable; authoritative historical research records are not.
9. Research View, Portfolio View, and Client Recommendation are separate concepts.
10. Commercial subscription logic must never dictate research conclusions.
11. Future architecture may evolve, but consequential changes remain auditable and human-governed.
12. Build seams now only where necessary; build future subsystems when their requirements are real.
