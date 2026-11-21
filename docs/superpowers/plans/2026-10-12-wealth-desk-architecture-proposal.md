STATUS: PROPOSAL — UI/UX IMPLEMENTATION RESERVED FOR OWNER APPROVAL

# SPA Private Wealth Desk — Architecture & UI Proposal

**Date:** 2026-10-12 (overnight session)

**Scope of this document:** architecture, navigation, UX, screen
hierarchy, and implementation sequence only. No frontend code is
written by this document or this session. Backend read-API work
proceeds in parallel under separate authorization (safe, read-only,
reuses existing entitlement/auth patterns) and is reported separately;
it does not depend on this proposal being approved first, since any of
the three UI approaches below would consume the same read API.

---

## 1. What already exists (verified directly, not assumed)

**Frontend** (`stock-price-alert` Next.js app,
`C:\Users\Home\Documents\GitHub\stock-price-alert`):
- A full shadcn/ui (Radix-based) component library is already
  installed and unused beyond the Trade feature: `card`, `table`,
  `tabs`, `dialog`, `drawer`, `sheet`, `chart` (recharts), `badge`,
  `command`, `dropdown-menu`, `breadcrumb`, `select`, `tooltip`,
  `skeleton`, `sonner` (toasts). **No new UI dependency is needed for
  any of the three approaches below.**
- The sidebar (`components/layout/app-sidebar.tsx`) already has
  placeholder nav entries pointing nowhere (`url: "#"`): "Dashboard",
  "Analytics", "Notifications", "Friends" — alongside the two real,
  working entries, "Trade Alerts" (`/alerts`) and "Settings". This
  reads as a generic dashboard template that was scaffolded once and
  only the Trade/Telegram slice was ever wired up.
- `lib/api/` has exactly four files: `auth.ts`, `telegram.ts`,
  `tickers.ts`, `trades.ts`. **There is no frontend API client for
  anything else** — not just Phase 3/I3AS (expected, since those were
  built backend-only), but also the *existing* `research_bp` consumer
  API (companies/disclosures/history, entitlement-tiered, built in an
  earlier engagement phase). The Wealth Desk is the first real
  consumer of `research_bp` **and** the first-ever consumer of
  Investment Brain/I3AS data — not an incremental extension of
  something partially built.

**Backend**: `research_bp` (`/api/research/*`) already implements the
exact entitlement-tiering pattern any new section should extend rather
than reinvent: `EntitlementService.resolve(user)` →
`ResearchAccessContext(user_id, is_admin, tier)` →
`ResearchAccessPolicy.allowed_sections()`/`locked_sections()` → one of
three explicit marshmallow schemas (`CompanyAdminSchema`/
`CompanyPremiumSchema`/`CompanyFreeSchema`) chosen by tier, never a
single schema with conditionally-hidden fields. `FREE_SECTIONS` /
`PREMIUM_SECTIONS` are named, explicit constants (`app/policies/
research_access.py`) — Investment Brain sections belong in
`PREMIUM_SECTIONS` as additional named entries, the same way
`forecast`/`valuation`/`governance` already do, not as a new
access-control mechanism.

Phase 3 + I3AS (`InvestmentCase`, `InvestmentCaseGateResult`,
`InvestmentCaseKillSwitch`, `CycleAssessment`, `InvestmentHypothesis`,
`AlertEvent`/`AlertDelivery`) have **zero HTTP routes today** — every
one of them is service-layer only. This is the actual backend gap
behind any Wealth Desk screen; see the companion backend-work report
for what was safely built against it overnight.

## 2. Design principle this proposal holds itself to

**Lead with research conclusions and material changes, not price.**
The user's own framing — "daily investment decisions, material
changes, evidence, company research, portfolio monitoring and
alerts — not conventional trading-dashboard clutter" — is treated as
a hard constraint, not a preference: no candlestick charts, no
real-time ticker tape, no "watchlist by % change today" as the primary
surface. Price/`Trade` stays exactly where it already lives
(`/alerts`, unchanged) — the Wealth Desk is additive, not a
replacement screen fighting it for the same nav slot.

---

## 3. Three navigation/IA approaches

### Approach A — Company Workspace (research-first, no new concepts)

```text
┌─ Sidebar ──────┐  ┌─ Companies ─────────────────────────────────┐
│ Daily Brief     │  │ [search]  [sector ▾] [tier badge]           │
│ Companies    ◄──┼──┤ Chemplast Sanmar      ADD   ●WATCH          │
│ Trade Alerts    │  │ UNO Minda             HOLD  ●PASS           │
│ Settings        │  │ ...                                         │
└─────────────────┘  └──────────────────────┬──────────────────────┘
                                             │ click
┌─ Company Workspace: Chemplast Sanmar ─────▼──────────────────────┐
│ [Overview] [Thesis] [Forecast & Valuation] [Governance] [Alerts] │
│                                                                    │
│  Overview tab:                                                    │
│  ┌ Research View summary ┐ ┌ Current Investment Case ┐           │
│  │ why_selected, thesis   │ │ view: ADD                │           │
│  │ management/governance  │ │ nine gates: 7 PASS 1 WATCH│          │
│  └────────────────────────┘ └───────────────────────────┘        │
│  ┌ Bull/Base/Bear return spread (recharts bar) ──────────────┐   │
│  └──────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────┘
```

One page per company, tabbed by epistemic-chain stage (mirrors the
chain itself: thesis → forecast/valuation → governance). Home is just
the Companies list. Closest to how an analyst already thinks ("let me
pull up Company X"), and maps almost 1:1 onto
`ResearchQueryService.get_company_detail`'s existing aggregate shape.

**Weakness:** no single screen answers "what changed across everything
I follow today" without opening each company in turn.

### Approach B — Daily Brief (alert-first, I3AS as the hero feature)

```text
┌─ Sidebar ──────┐  ┌─ Daily Brief ─────────────────────────────────┐
│ Daily Brief ◄──┼──┤ 🔴 CRITICAL  Kill switch triggered             │
│ Companies       │  │    Chemplast Sanmar · PVC spread re-widened   │
│ Trade Alerts    │  │    [View Investment Case →]                   │
│ Settings        │  │ 🟡 WATCH     Execution gate FAILED             │
└─────────────────┘  │    UNO Minda · capacity ramp behind schedule  │
                      │    [View Investment Case →]                   │
                      │ 🟡 WATCH     Thesis superseded                │
                      │    UNO Minda · additional JV equity approved  │
                      │ ℹ️ INFO      New investment case: Chemplast   │
                      └────────────────────────────────────────────────┘
```

Home = the `AlertEvent` feed itself, newest first, severity-colored,
each row deep-linking into that company's Workspace (Approach A still
exists one level down — these aren't mutually exclusive). Makes the
alert infrastructure built this session the literal front door.

**Weakness:** today's alerts are admin-only and low-volume in real use
(no real governance HIGH/CRITICAL event exists yet, per the Alert-3
real-company validation); an empty or near-empty home screen on a
quiet day reads as broken rather than quiet. Needs a secondary "state
of the world" panel (Approach C) to not feel empty.

### Approach C — Status Grid (portfolio-shaped, honest about what it isn't)

```text
┌─ Sidebar ──────┐  ┌─ Watchlist ────────────────────────────────────┐
│ Watchlist   ◄──┼──┤ Company          View   Gates      KillSwitch  │
│ Trade Alerts    │  │ Chemplast Sanmar ADD    7/9 PASS   🔴 fired    │
│ Settings        │  │ UNO Minda        HOLD   8/9 PASS   ○ armed    │
└─────────────────┘  └────────────────────────────────────────────────┘
```

A dense, scannable grid — one row per researched company, status
chips for view/gates/kill-switch/last-alert. Click a row → Company
Workspace. Closest to a classic buy-side watchlist-with-intelligence
overlay (the AlphaSense/Koyfin-style comparison framing already named
in the Phase 3 design proposal).

**Important honesty note, not a nitpick:** this is a *watchlist of
researched companies*, not a true portfolio view — no `Holding`/
`Transaction` model exists yet (Master Roadmap V2 Tier 0.3, never
built). Calling this screen "Portfolio" in the UI would overstate what
the data actually represents. It should be labeled "Watchlist" or
"Coverage" until real holdings data exists.

---

## 4. Recommendation: B, with C folded in as the home screen's second panel

Neither B nor C alone is sufficient on its own (B goes empty-looking on
a quiet day; C alone misses "what changed"). The recommended Wealth
Desk home screen is **B's alert feed as the primary panel, with C's
status grid as a persistent secondary panel below or beside it** — one
screen answers both "what needs my attention right now" and "where do
things stand across everything I follow," with Approach A's Company
Workspace one click away from either. This is not a fourth approach
invented after the fact — it is B and C's own stated weaknesses
resolving each other directly, which is why both are worth presenting
rather than picking one outright.

```text
┌─ Sidebar ────────┐  ┌─ Home ("Daily Brief") ─────────────────────────┐
│ Daily Brief   ◄──┼──┤ ┌ Alert feed (primary, ~60%) ─────────────────┐ │
│ Companies         │  │ │ 🔴 CRITICAL  Kill switch — Chemplast...    │ │
│ Trade Alerts       │  │ │ 🟡 WATCH     Gate FAILED — UNO Minda...   │ │
│ Settings           │  │ └─────────────────────────────────────────────┘ │
└───────────────────┘  │ ┌ Watchlist grid (secondary, ~40%) ──────────┐ │
                        │ │ Chemplast Sanmar  ADD  7/9 PASS  🔴 fired  │ │
                        │ │ UNO Minda         HOLD 8/9 PASS  ○ armed  │ │
                        │ └─────────────────────────────────────────────┘ │
                        └───────────────────────────────────────────────┘
```

---

## 5. Implementation milestones and critical path

Targeting 2026-10-25 without compromising quality means being explicit
about what is genuinely achievable versus what would need to be cut or
descoped — not silently thinning quality to hit the date.

| Milestone | Delivers | Depends on |
|---|---|---|
| M0 | Backend read API: Investment Brain + Alert feed endpoints, entitlement-gated, reusing existing patterns exactly | Nothing further -- in progress tonight, reported separately |
| M1 | Frontend shell: `lib/api/investment-case.ts`/`alerts.ts` clients; replace the sidebar's dead "Analytics"/"Notifications" placeholders with real routes; auth-gated routing | M0 |
| M2 | Daily Brief home screen (alert feed + watchlist grid, §4) | M1 |
| M3 | Company Workspace (Overview/Thesis/Forecast & Valuation/Governance tabs) | M1; Overview tab can ship before the deeper tabs |
| M4 | Premium-tier gating UI (locked-section states, matching `locked_sections()`'s existing payload shape) and empty/loading states | M2, M3 |
| M5 | Real-company QA pass using Chemplast/UNO Minda's actual research content (not synthetic fixtures) across every screen | M2-M4 |

**Honest risk to the 2026-10-25 date:** M0 is backend-only and is
proceeding now; M1-M3 are net-new frontend screens with zero prior
frontend work to build on (§1) — this is not a thin UI layer over an
already-wired API, it is the first UI for three backend capabilities
at once. A credible, quality-preserving critical path ships M0-M2
(Daily Brief home screen) as the Beta, with M3's full Company Workspace
depth and M4/M5 polish following immediately after if the date is
firm — rather than shipping all of M0-M5 thin and rushed by the 25th.
This trade-off is named here for owner decision, not decided
unilaterally.

---

## 6. What this document does not do

No frontend code is written. No UI dependency is added. No navigation
change is made to the live `stock-price-alert` frontend repo. The
backend read-API work referenced in §1/§5 (M0) is reported and
committed separately, under its own safe/read-only/existing-
architecture authorization, and does not require this proposal's
approval to proceed — but no frontend screen in §3/§4 is built until
the owner picks an approach (or approves the recommendation in §4) and
explicitly authorizes UI implementation.
