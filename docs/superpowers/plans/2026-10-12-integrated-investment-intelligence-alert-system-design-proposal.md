STATUS: PROPOSAL — NOT YET APPROVED FOR IMPLEMENTATION

# Integrated Investment Intelligence Alert System — Design Proposal

**Date:** 2026-10-12

**Scope of this document:** architecture and contracts only, per owner
direction (2026-10-11) naming this the next major development priority
after Phase 3. No migration, model, or service code is created by this
document. It reconciles everything this repository has already said
about alerting against what actually exists in the codebase today
(verified directly, not assumed), proposes entities, ownership
boundaries, an event-source inventory, acceptance gates, and
implementation slices, and lists explicit open questions for owner
review. Implementation does not start until this proposal is approved,
slice by slice, the same way Phase 3 was.

**Requirements evidence this reconciles against:**
- `docs/superpowers/plans/2026-09-25-spa-post-m1-roadmap-proposal.md`
  §"Phase 10 — Alerts (cross-cutting, not a single phase)" — the
  original framing: "Alerts have no independent data model... add the
  relevant alert type incrementally as each phase lands, with a small
  shared notification plumbing layer introduced whenever the first
  alert type is needed."
- `docs/superpowers/plans/2026-09-25-spa-post-m1-roadmap-architecture-review.md`
  §6 "Alerts — anchor point moves earlier, principle unchanged" —
  moved the anchor to Business Pulse's first "material change" signal,
  on the grounds that Alerts "need a coherent 'something changed'
  signal rather than bespoke logic per stream."
- `docs/superpowers/plans/2026-09-25-spa-post-m1-master-roadmap-v2.md`
  §1.3 "Minimal shared Alerts/event plumbing" — the reconciled version
  of the above, dependent on Tier 1.2 Business Pulse.
- `docs/superpowers/specs/2026-09-05-spa-north-star-architecture-amendment-design.md`
  §16 (SPA Legacy's View/Portfolio/Recommendation separation), §22
  (the eight-layer North-Star hierarchy and each layer's stated
  responsibility).
- `docs/superpowers/plans/2026-10-08-phase3-investment-intelligence-foundation-design-proposal.md`
  and `2026-10-08-phase3-development-checkpoint.md` — Phase 3's actual,
  now-complete implementation (Slices A-G: `CycleAssessment`,
  `InvestmentHypothesis`, scenario-aware `ForecastRevision`/
  `ValuationRevision`, and `InvestmentCase`/`InvestmentCaseKillSwitch`/
  `InvestmentCaseGateResult`) — the concrete signal sources this
  proposal's event-source inventory (§4) draws on, superseding the
  2026-09-25 roadmap's "Business Pulse" anchor (§1 below).
- Current `backendtest` code (`live/websocket.py`, `app/models/trade.py`,
  `app/services/telegram_service.py`, `app/models/user.py`,
  `app/models/governance.py`, `app/models/market_plan.py`) as ground
  truth for what alerting already exists in production today —
  verified directly, not assumed. See §2.

---

## 1. Why the prior planning anchor ("Business Pulse") no longer fits

The 2026-09-25 Master Roadmap V2 anchored "Alerts/event plumbing" to
Tier 1.2 Business Pulse's first "material change" signal — an abstract,
not-yet-built company-state-synthesis capability. **Business Pulse was
never built.** Phase 3 took a different, more concrete path: it deepened
Research Brain directly (financial diagnostics/narration, Cycle
Intelligence, the Hypothesis/Forecast/Valuation engines) and then built
the first real slice of Investment Brain (`InvestmentCase`, kill
switches, the nine-gate assessment) — all immutable, revisioned,
provenance-cited rows that are individually far more concrete and
further along than the abstract "company state changed" signal the
2026-09-25 roadmap was anticipating.

**This proposal drops the Business Pulse dependency and anchors
directly on Phase 3's real, already-shipped signal sources instead**
(§4). This is a stronger foundation than the one originally planned,
not a workaround for a missing one. The original principle these three
documents all converge on — *alerts are a cross-cutting layer that
watches other domains for state changes, registered incrementally, not
rebuilt per phase* — is preserved unchanged; only the anchor point
moves from an unbuilt abstraction to Phase 3's real output.

---

## 2. What already exists today (verified against the live code)

There is **no shared alerting mechanism** in this codebase. There is one
single-purpose, hardcoded pipeline, entirely outside the Research
Brain/Investment Brain architecture:

```text
live/websocket.py (TickerManager, live Kite WebSocket feed)
  → Trade.check(candle)            [app/models/trade.py]
      mutates Trade.status in place (ACTIVE → ENTRY/STOPLOSS/TARGET)
  → TickerManager.send_trade_notification(user, trade)
  → TelegramService.send_trade_alert(user, trade)
      hardcoded if/elif on trade.status, inline HTML message string
  → TelegramService.send_message(chat_id, text)   [real network call]
```

Four properties of this pathway matter for this proposal:

1. **No durable record of notification.** `send_message` returns a bare
   `bool`; failure is only logged, never persisted. There is no
   queryable answer to "was this user actually told about this trade's
   target hit," which is exactly the gap a shared plumbing layer should
   close.
2. **`Trade.status` is mutated in place, not revisioned.** This is a
   pre-North-Star, legacy mechanism (the North-Star hierarchy's "Market
   Brain" layer — "observe price... without rewriting fundamental
   truth" — is not yet built; `Trade`/`live/websocket.py` are its
   un-North-Star-ed ancestor). This proposal does not change `Trade`'s
   own mutation model — see §7's safety boundary — it only proposes
   routing the *notification* step through shared, auditable plumbing.
3. **One hardcoded notification type, one hardcoded channel.** Adding a
   second alert-worthy event anywhere in the system today means writing
   a second bespoke `if/elif`-and-Telegram-call block — the exact
   anti-pattern all three prior planning documents (§ above) warned
   against.
4. **`MarketPlanRevision`** (accumulation/supply bounds) **has no live
   trigger at all.** Per its own module docstring, "no technical engine
   creates or updates these rows in Milestone 1" — it is a pure data
   record today, named here only as a future candidate event source
   (§4), not something this proposal wires up.

`User.telegram_chat_id`/`telegram_enabled` (already present) and
`TelegramService.send_message` (already present, already tested without
a real network call in `tests/legacy/test_telegram_contract.py`) are the
only pieces of this pathway this proposal intends to **reuse unchanged**
as the v1 delivery mechanism (§5).

### 2a. Reconciliation findings (2026-10-12, owner-confirmed)

Before any further design work, the owner asked this proposal to
reconcile the pathway above against "our existing WhatsApp-based
subscriber alerts" and identify any separate production implementation.
Three codebases were checked directly: this repo (`backendtest`), this
docs repo, and a third one not previously inspected —
`stock-price-alert`'s actual Next.js frontend
(`C:\Users\Home\Documents\GitHub\stock-price-alert`), which turns out to
be the real product UI for this backend (same design-doc history, same
`User.telegram_*` fields, same `Trade`/`Ticker` types).

**Finding, confirmed by the owner:** there is exactly one production
alert channel today, and it is **Telegram**, via the pathway above end
to end (`TelegramSettings.tsx` → `lib/api/telegram.ts` →
`app/routes/telegram.py` → `TelegramService` → `Trade.check` →
`send_trade_notification` → `send_trade_alert` → `send_message`). The
frontend's own "Alerts" navigation page (`app/alerts/page.tsx`) renders
nothing but `<TradesPage />` — "Alert" and "Trade" are one feature in
this product, not two. "WhatsApp" exists in exactly one place across
all three repos — a stale `<meta description>` string in the frontend's
`app/layout.tsx` — with no WhatsApp settings component, API client,
`User` field, dependency, or database table/column anywhere (two
incidental mentions of the word inside unrelated ingested document text
were the only database hits). **WhatsApp is confirmed by the owner as a
future option, not a parallel pathway that exists today.** No
"subscriber"/"broadcast" concept of any kind was found anywhere.

**Field mapping, confirmed:** entry/stop-loss/target/risk-reward/reason/
tags map cleanly to real `Trade` fields (`entry`, `stoploss`, `target`,
`risk_reward_ratio`/`risk_per_unit`/`reward_per_unit`, `notes`, `tags`).
**Still open:** no stored position-sizing/quantity field was found on
`Trade` (backend) or in the frontend's `Trade` type — flagged to the
owner, not yet resolved; this proposal does not assume such a field
exists until confirmed.

**New requirement from owner review, folded into this proposal:** SPA
and a separate platform, **Sensybull**, "may eventually integrate" —
this proposal must **preserve that interoperability option without
introducing any new dependency or infrastructure now.**

A fork of Sensybull's own API exists locally
(`sensybull-api`, forked 2026-09-21) and was read directly rather than
guessed at. Its actual architecture, verified from the real code:
`services/ingest` publishes an immutable, dataclass-defined
`FilingEvent` envelope (`services/ingest/events.py`) to a Redis channel
(`filing:new`); `services/api` subscribes, persists one row per event
into a `filing_event` table **unique on its own natural identity**
(`edgar_id`, not an internal counter), and fans delivery out over an
authenticated WebSocket namespace to every user whose watchlist
matches. Event-specific structured data is *not* a growing set of
nullable columns — it lives in one flexible `attributes: JSON` column
on a generic `EventType` link row, scoped to the one `FilingEvent` it
classifies. "New signal types publish to the same channel with the same
envelope and are routed identically" (Sensybull's own README) — the
identical cross-cutting-plumbing principle this proposal's §1 already
independently arrived at from SPA's own prior planning docs.

Two concrete design consequences, folded into §5.1/§9 below:
- **Idempotency.** Borrow `FilingEvent.edgar_id`'s discipline directly:
  `AlertEvent` should be unique on its own natural identity
  (`source_table`, `source_id`, `event_type`), not merely insertable
  freely, so a producing call site that retries can never double-record
  the same real-world occurrence.
- **Event-specific data without column sprawl.** Add one optional
  `details: JSON` column to `AlertEvent` (the same `sa.JSON` type
  already used, precedented, in `app/models/document.py` — not a new
  column type for this codebase), mirroring `EventType.attributes`,
  instead of a second nullable column per integrated event type.

**What this does not do:** no Redis, no WebSocket server, no new
Python dependency, and no actual bridge to Sensybull is introduced by
this proposal. The point of the two changes above is only that a later,
separately-approved bridge slice could translate `AlertEvent` rows into
a Sensybull-compatible (or any other) outbound feed **without a schema
change today** — because the row is already a plain, natural-keyed,
JSON-extensible envelope. Nothing is sent anywhere by this proposal's
slices beyond Telegram.

---

## 3. Where this sits in the North-Star hierarchy

**This is not a ninth layer.** Re-reading §22's table: World, Discovery,
Research Brain, Investment Brain, Market Brain, Wealth Brain, Learning
Brain, and Self-Stewardship each *produce or interpret* some kind of
investment truth. An alert produces nothing of that kind — it is a
**cross-cutting notification/delivery mechanism** that observes
immutable rows already written by any layer and tells a human about
them. This is consistent with the original roadmap's own framing
("Alerts... watches every other domain for state changes") and with
this project's existing epistemic-separation discipline (§6 of the
North-Star amendment; §2 of the Phase 3 proposal's own epistemic chain).

**The rule this proposal must not violate, stated explicitly (parallel
to Phase 3's own "no second authoritative research-view table" rule):**
an `AlertEvent` is a notification *about* an already-immutable row
elsewhere in the system. It never asserts a Fact, Hypothesis, Forecast,
Valuation, `InvestmentCase`, or any other node on the epistemic chain,
and no alert-system table is ever cited as provenance *by* one of those
chain objects. Alerts point one way: chain → alert, never the reverse.

---

## 4. Event-source inventory (the actual integration surface)

This is the concrete list of existing write paths this proposal
proposes making alert-worthy. Each is an *addition* of one call at the
end of an already-committed write — no existing service's own
transaction, return value, or error behavior changes.

| Source (layer) | Existing write path | Proposed event | Priority |
|---|---|---|---|
| Investment Brain | `InvestmentCaseService.trigger_kill_switch` | Kill switch triggered | **v1 — highest signal, matches the proposal's own name** |
| Investment Brain | `InvestmentCaseService.record_gate_result` | Gate recorded with status `FAIL` (or a gate flips from `PASS` to a non-`PASS` status on supersession) | **v1** |
| Investment Brain | `InvestmentCaseService.create_investment_case` | New `InvestmentCase`, or a supersession that changes `view` (e.g. `ADD` → `EXIT`) | **v1** |
| Market Brain (legacy) | `Trade.check` → `TickerManager.send_trade_notification` | Trade status changed (Entry/Stop Loss/Target hit) | **v1 — absorb existing behavior, see §7** |
| Research Brain | `GovernanceFlag` command path reaching `severity` `HIGH`/`CRITICAL`, or `status` → `OPEN` | Governance risk flagged | v2 candidate |
| World / Research Brain | `CycleIntelligenceService.create_cycle_assessment` superseding an existing assessment | Cycle view changed | v2 candidate |
| Research Brain | `HypothesisAssumptionService.create_investment_hypothesis` superseding an existing hypothesis | Thesis changed | v2 candidate |
| Market Brain (not yet built) | `MarketPlanRevision` accumulation/supply-bound breach | Price plan breached | **not in this proposal** — no engine creates these rows yet (§2.4); named only so the schema below doesn't need to change when one exists |

The four "v1" rows are the ones this proposal recommends building,
**now sequenced legacy-Trade-first per owner decision (§8, §9)** — the
smallest set that (a) closes the durability gap on the one signal
source already live in production and (b) proves the shared plumbing
against a genuinely new, already-shipped signal source (Investment
Brain) once (a) is proven — without yet committing to the broader
Research Brain surface (Alert-3, §8).

---

## 5. Component design

**Layer:** cross-cutting (§3), not part of the North-Star hierarchy
itself. **Chain position:** observes the chain; never joins it.

### 5.1 `AlertEvent` — one immutable row per alert-worthy occurrence

`(id, event_type, source_table, source_id, company_id, severity,
summary, details, occurred_at, created_at)`.

- **`event_type`**: an open, data-insert-style controlled vocabulary —
  the same convention `ResearchDimension`/`PropositionStageType` already
  use in this codebase for a vocabulary expected to *grow* (unlike the
  nine gates' deliberately *closed* `CHECK` enum in Phase 3 Slice G,
  where the taxonomy is fixed). New event types are data inserts, never
  migrations.
- **`source_table`/`source_id`**: a plain, uncoupled reference to the
  row this event is about, named by convention rather than by foreign
  key — the same deliberate choice `ForecastAssumption.metric_slug`
  already made in Phase 3 Slice D for the identical reason (there,
  naming a `FinancialMetricDefinition` slug without a hard FK; here,
  naming one of a growing, cross-cutting set of source tables without a
  discriminated-union column list that cannot scale past a handful of
  options — see §9 open question (a) for the alternative this proposal
  rejects and why). **Unique together with `event_type`** (a composite
  unique constraint) — the idempotency discipline borrowed directly from
  Sensybull's `FilingEvent.edgar_id` (§2a): the same real-world
  occurrence, re-detected by a retried or re-run producing call, can
  never be recorded twice.
- **`details`**: optional `sa.JSON` (already a precedented column type
  in this codebase — `app/models/document.py`), for event-specific
  structured data (e.g. a gate result's `{gate, status}`, a kill
  switch's `{condition}`) — mirroring Sensybull's `EventType.attributes`
  (§2a) rather than adding a new nullable column per event type.
- **`company_id`** is captured redundantly and directly on the row
  (not resolved by joining through `source_table`) so that "every alert
  for this company" is a single indexed query, never a per-source-type
  join. Nullable, since not every event (e.g. a future macro/World-level
  alert) is company-scoped.
- **`severity`**: a small closed enum (`INFO`/`WATCH`/`CRITICAL`,
  mirroring the existing `GovernanceSeverity` shape), set by the
  producing call site, never inferred.
- Immutable, append-only — the same `before_update`/`before_delete`
  rejection idiom every Phase 3 table already uses.

### 5.2 `AlertDelivery` — one immutable row per (event, recipient, channel) attempt

`(id, alert_event_id, recipient_user_id, channel, delivered_at,
delivery_status, error_detail, created_at)`.

- **`channel`**: a small closed enum; only `TELEGRAM` is implemented in
  this proposal's slices (§8) — `EMAIL`/`PUSH`/`WEBHOOK` are reserved
  names only, not wired to anything, named now so the enum itself does
  not need a migration when one of them is eventually built.
- **`delivery_status`**: `SENT`/`FAILED` (closed enum). This is the
  durability fix for §2 item 1 — whether a given user was actually
  told about a given event becomes a permanent, queryable fact instead
  of a log line.
- Immutable, append-only, same idiom as every other Phase 3 table. A
  failed delivery is never retried by mutating this row — a retry is a
  new row (see §9 open question (c) on whether retries are even built
  in v1).

### 5.3 `AlertService` — owns writes to `AlertEvent`/`AlertDelivery` only

Mirrors Phase 3's P3-A service-ownership-boundary rule exactly: every
other service that produces an alert-worthy write calls
`AlertService.record_event(...)` as one additional step *after* its own
commit; `AlertService` never reaches into any other table, and no other
service writes to `AlertEvent`/`AlertDelivery` directly.

- `record_event(event_type, source_table, source_id, summary, *,
  company_id=None, severity=...)` — creates the `AlertEvent`, then
  resolves recipients (§9 open question (b); this proposal's v1
  recommendation is "every `User` with `is_admin=True`", reusing the
  exact admin-broadcast pattern `live/websocket.py` already uses for
  Kite-login alerts) and attempts delivery per recipient per enabled
  channel, recording one `AlertDelivery` row per attempt regardless of
  outcome.
- `deliver_via_telegram(...)` — a thin wrapper around the existing,
  unchanged `TelegramService.send_message`; failure is caught and
  recorded as `delivery_status=FAILED`, never raised past this layer
  (an alert-delivery failure must never roll back or interrupt the
  business write that triggered it — the producing call site's own
  transaction has already committed by the time `record_event` runs).
- Read query: `list_events_for_company(company_id)` /
  `list_undelivered_or_failed(...)` — read-only, computed live, no new
  stored rollup, matching every Phase 3 engine's "read contracts are
  computed live" discipline.

---

## 6. Schema changes requiring owner approval

Two new tables, zero changes to any existing table — the cleanest
possible classification under §21 of the North-Star amendment ("bounded
changes preserving an approved seam"):

| # | Change | Table(s) | Why |
|---|---|---|---|
| 1 | New table `AlertEvent` | — | One immutable row per alert-worthy occurrence (§5.1) |
| 2 | New table `AlertDelivery` | — | One immutable row per delivery attempt (§5.2) |

No column is added to `InvestmentCase`, `Trade`, `GovernanceFlag`,
`User`, or any other existing table. The integration surface (§4) is
entirely additional calls from existing services into the new
`AlertService` — not schema changes to the tables those services already
own.

---

## 7. Safety boundaries (carried over explicitly, not relaxed)

This repository's own `AGENTS.md` names Telegram and live
websockets/trading systems as boundaries requiring explicit task
authorization before interaction. This proposal is designed so that
**approving it does not, by itself, authorize touching either live
system**:

- No slice of this proposal modifies `live/websocket.py`,
  `TickerManager`, or any Kite/candle-processing logic. `Trade.check`'s
  own triggering mechanism is untouched; only the notification *call
  site* at the end of `send_trade_notification` gains an additional,
  non-blocking `AlertService.record_event(...)` call.
- Every test added under this proposal follows
  `tests/legacy/test_telegram_contract.py`'s existing convention: no
  real network call, no real Telegram bot token used, delivery stubbed
  or mocked exactly like that file already does for verification/welcome
  messages.
- No slice touches the live database (`instance/trading_app.db`);
  migration testing happens only against isolated SQLite copies in the
  session scratchpad, per this engagement's standing constraint.
- No slice wires a live trigger onto `MarketPlanRevision` (§2 item 4,
  §4's last row) — that would be new live-market logic requiring its
  own separate authorization, out of scope here.

---

## 8. Proposed implementation slices and acceptance gates

**Resequenced 2026-10-12 per owner decision on §9 open question (e):**
legacy Trade alert integration is approved as the **first** real
integration slice, not the last — reversing this proposal's original
order, which had Investment Brain integration first. Two hard
requirements attach to that approval and are now load-bearing gates on
Slice 1, not just prose:

- **Regression-first.** Before any new code, write characterization
  tests that pin today's exact `Trade.check` → `send_trade_notification`
  → `send_trade_alert` → `send_message` behavior (message content per
  status, which user, which chat ID) as it actually is right now — a
  safety net, not a redesign.
- **Fail-safe, non-negotiable.** If `AlertService.record_event`/
  `AlertDelivery` recording fails for any reason, the existing direct
  Telegram send must still fire exactly as it does today, unmodified.
  The new plumbing is additive insurance, never a dependency the
  legacy alert path can be broken by.

| Slice | Delivers | Depends on | Acceptance gate |
|---|---|---|---|
| **Alert-1** | (a) Characterization tests of today's `Trade`→Telegram pathway, written first, against the *current* code, no production change. (b) `AlertEvent`/`AlertDelivery` schema + `AlertService.record_event`/`deliver_via_telegram`/`list_events_for_company`. (c) `TickerManager.send_trade_notification`'s call site additionally calls `record_event`, wrapped so a failure there can never block or alter the existing direct Telegram send. | Nothing beyond current code | (1) Alert-1(a)'s characterization tests, run against the *unmodified* code, pass and are committed before Alert-1(b)/(c) are written. (2) After Alert-1(b)/(c): those same tests still pass unchanged — proving no regression in message content, timing, or recipient. (3) A durable, correctly-typed `AlertEvent`/`AlertDelivery` pair is now also recorded for the same Entry/Stop Loss/Target occurrence. (4) A fixture in which `record_event` is made to raise proves the original Telegram send still succeeds. (5) No real network call in any test (§7). |
| **Alert-2** | Investment Brain integration: `InvestmentCaseService` calls `record_event` on kill-switch trigger, gate-`FAIL` result, and view-changing supersession | Alert-1, Phase 3 Slice G | A fixture kill-switch trigger and a fixture gate-`FAIL` result each produce exactly one correctly-typed, correctly-company-scoped `AlertEvent`, delivered through the same Alert-1 plumbing |
| **Alert-3** (lower priority, broader coverage) | `GovernanceFlag`/`CycleAssessment`/`InvestmentHypothesis` event sources (§4's v2-candidate rows) | Alert-2 | Same event-creation proof as Alert-2, one fixture per source type |

**Explicitly not in this proposal:** the Research Orchestrator (§9 open
question (d)); any `MarketPlanRevision` live-trigger engine; per-user
alert subscriptions/preferences (§9 open question (b)); any non-Telegram
delivery channel actually sending anything (including any actual
Sensybull bridge, §2a); any retry/backoff delivery worker (§9 open
question (c)); any Redis/WebSocket infrastructure.

---

## 9. Open questions for owner decision

**Resolved (2026-10-12):**
- *v1 event-source scope / sequencing* — legacy Trade alert integration
  is approved as the **first** implementation slice (Alert-1, §8),
  reversing this proposal's original order, subject to the
  regression-first and fail-safe gates now written into Alert-1's
  acceptance criteria. Investment Brain integration (kill switch, gate
  `FAIL`, view-changing supersession) follows as Alert-2.
- *WhatsApp* — confirmed by the owner as a future option, not a parallel
  pathway that exists today (§2a). Telegram is SPA's one confirmed live
  alert channel.
- *Sensybull interoperability* — confirmed as a real future integration
  target (a fork of its API exists locally, read directly — §2a), to be
  preserved as an option without any new dependency or infrastructure
  today. Folded into `AlertEvent`'s shape (idempotency key, `details`
  JSON column) and into the channel-scope recommendation below.

**Still open:**

1. **`AlertEvent` provenance shape.** This proposal recommends a plain
   `source_table`/`source_id` string pair, unique together with
   `event_type`, plus an optional `details: JSON` column (§5.1) — the
   same named-by-convention choice already made for
   `ForecastAssumption.metric_slug`, now additionally grounded in
   Sensybull's own real `FilingEvent.edgar_id` (natural-key uniqueness)
   and `EventType.attributes` (JSON, not column sprawl) precedent (§2a).
   The alternative — a growing discriminated-union of nullable foreign
   keys, the idiom used everywhere else in Phase 3 for a *closed*, small
   provenance set (3-5 options) — does not scale to an open-ended,
   incrementally-registered set of event sources without an
   ever-growing column list on one table. A third alternative, one
   small link table per integrated source type (mirroring
   `InvestmentCaseForecast`/`InvestmentCaseValuation`), is more
   type-safe than either but means a new migration every time a new
   source is integrated — arguably against this mechanism's whole
   "register incrementally" purpose. **Recommendation: the string-pair
   + JSON-details approach.**
2. **Recipient targeting for v1.** This proposal recommends "every
   `User` with `is_admin=True`" (§5.3), the smallest viable scope and an
   existing pattern (`send_kite_login_alert`). A per-user subscription
   table (by company, by event type, by severity) is a natural future
   enhancement, not built now — deferred the same way Phase 3 deferred
   `CapitalAllocationSnapshot` until real volume justified it.
3. **Delivery timing.** This proposal recommends fully synchronous,
   inline delivery attempts (§5.3) — simplest, a direct durability
   upgrade over today's fire-and-forget call, and the only option
   consistent with "no new infrastructure today" (§2a) — a queue/worker
   is itself new infrastructure. A deferred/queued delivery mechanism
   with retry/backoff is a plausible future enhancement once real
   delivery-failure volume exists to justify it, and once a Redis-backed
   bridge (if a real Sensybull integration is ever separately approved)
   would need one anyway.
4. **Relationship to the Research Orchestrator (§6 of the Phase 3
   proposal).** The Orchestrator's signal shape
   (`source_event`/`candidate_targets`/`reason`) is structurally
   similar to this proposal's `AlertEvent`, but its *purpose* is
   different: internal "this may now be stale, please re-review"
   surfacing for existing research objects, never human-facing
   notification. **This proposal recommends treating the Alert System
   as structurally separate from, and smaller than, the Orchestrator**
   — reusing only the naming convention, not the Orchestrator's
   revalidation semantics — so that approving this proposal does not
   implicitly authorize or require building the Orchestrator, which
   remains "not implemented under any circumstance without separate
   approval" per the Phase 3 checkpoint. Flagged explicitly in case the
   owner intended the two to be the same mechanism.
5. **Channel scope.** Telegram-only for v1 (the only channel with a
   live, working implementation today) vs. also defining (but not
   wiring) additional channel names now. This proposal recommends
   Telegram-only, with the `channel` enum's reserved-but-unimplemented
   names (§5.2) — now explicitly including `WHATSAPP` (owner-confirmed
   future option) and `WEBHOOK` (the shape a future Sensybull-style
   bridge would most plausibly take, §2a) — as the seam for later, the
   same technique Phase 3's `origin` column used to reserve room for a
   future Orchestrator without building it.

**Still unresolved, carried from the owner's own review, not yet
answered:**
- Where "position sizing" actually lives (§2a) — no stored field was
  found on `Trade` or in the frontend's `Trade` type. This proposal
  does not assume such a field exists until the owner confirms where it
  is, or confirms it should be dropped from Alert-1's scope.

---

## 10. What this document does not do

No migration, model, or service code is written. No existing table is
altered. `live/websocket.py`, `TickerManager`, and all Kite/candle
logic are untouched. `MarketPlanRevision` gains no live trigger. The
Research Orchestrator is not built, and this proposal does not treat
itself as authorizing it (§9, open question 4). No actual Sensybull
bridge, Redis, or WebSocket infrastructure is introduced (§2a). No
non-Telegram channel is wired to anything. No per-user subscription/
preference mechanism is built. Implementation does not start — this
remains a proposal for owner review.
