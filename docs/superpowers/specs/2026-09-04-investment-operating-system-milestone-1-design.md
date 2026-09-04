# Investment Operating System — Milestone 1 Design Specification

**Status:** Approved architecture, including the frozen institutional-research refinement

**Date:** 2026-09-04

**Implementation order:** Backend first

**Repositories:** `backendtest` (backend), `stock-price-alert` (frontend)

## 1. Purpose

Stock Price Alert is evolving from an alerts and trade-tracking product into an Investment Operating System for long-term investors. Milestone 1 establishes the backend foundation for structured, auditable company research while preserving every existing authentication, trade, alert, Telegram, Kite, websocket, and database behavior.

This milestone provides:

- a company-centered research domain linked to the existing live-market ticker;
- immutable revisions for thesis, forecasts, valuation inputs, and market plans;
- structured ownership, management, governance, disclosure, and document metadata;
- a common Document Library that supports institutional and brokerage reports;
- backend-enforced free and premium entitlements;
- provenance, rights, distribution, and audit rules that prevent source or derived-content leakage;
- stable API contracts for later frontend work; and
- an idempotent, sourced IKIO Technologies demonstration record.

Milestone 1 does not implement forecasting, valuation, automated discovery, file ingestion, PDF analysis, technical confirmation, or a research frontend.

## 2. Approved architectural decisions

The system will use a hybrid relational and immutable-versioned architecture:

1. Stable identities and searchable facts use normalized relational tables.
2. Narrative research is stored as immutable `ResearchRevision` snapshots.
3. Forecasts, valuations, and market plans use independent immutable revision series.
4. Ownership is stored as dated snapshots.
5. Documents use one common Document Library; institutional research does not use separate storage.
6. The existing `Ticker` remains the source of current market price and websocket updates.
7. The backend resolves entitlements and emits explicit free or premium response projections.
8. Document rights are independent from product entitlement.
9. Institutional analysis and all derived artifacts inherit their source document's distribution restrictions by default.
10. Material document-state changes produce append-only `DocumentAuditEvent` rows. The audit log is not an event-sourcing mechanism.

The design assumes that company research is a shared, administrator-curated catalogue. Users consume the same current research revision, subject to entitlement and document-rights policies. Milestone 1 has no draft or publication workflow. Personal research workspaces are outside Milestone 1.

## 3. Existing-system context and boundaries

### 3.1 Backend

The backend is a Flask application factory using Flask-SQLAlchemy, Flask-Migrate, Flask-JWT-Extended, Marshmallow, and optional Elasticsearch. Models use string UUID primary keys and UTC creation timestamps through the existing `BaseModel`.

Existing models are:

- `User` for identity, administrator status, and Telegram settings;
- `Ticker` for symbol, exchange, Kite instrument token, name, latest price, and price timestamp;
- `Trade` for user-owned alerts and trading setups linked to `Ticker`;
- `Tag` for user-owned trade classification; and
- `TelegramVerification` for Telegram connection workflows.

Existing routes perform validation, querying, serialization, and transaction management directly. New research routes will preserve existing route behavior while moving research-specific business rules into dedicated services.

The database uses `DATABASE_URL` when supplied and otherwise falls back to SQLite. Flask-Migrate is initialized, but no migration history is currently committed.

The Kite websocket writes only operational market state to `Ticker` and evaluates existing trades. Research services must never write ticker prices, subscribe to Kite, or participate in trade evaluation.

### 3.2 Frontend

The frontend is a Next.js App Router application using TypeScript, Axios, Zustand, Zod, and JWT cookies. API calls are split into domain modules. Future research integration will follow that pattern, but Milestone 1 makes no frontend application changes.

### 3.3 Non-interference requirements

Milestone 1 must not alter:

- existing authentication flows or JWT identity semantics;
- existing user, ticker, trade, tag, Telegram, or verification columns;
- current trade and ticker API response shapes;
- Kite credentials, websocket behavior, ticker price updates, or alert evaluation;
- Telegram notification behavior;
- existing database records; or
- existing frontend routes, state, and components.

Research is linked to `Ticker` through a new foreign key on `Company`; no research field is added to `Ticker`.

## 4. Domain model

All new primary keys are string UUIDs. All timestamps are timezone-aware UTC. Mutable metadata tables include `updated_at`; append-only revisions do not update their substantive contents.

### 4.1 Company identity

#### `Company`

Represents the stable research identity for one listed company.

| Field | Rules |
|---|---|
| `id` | UUID primary key |
| `ticker_id` | Required unique FK to existing `ticker.id` |
| `legal_name` | Required |
| `display_name` | Optional; falls back to legal name |
| `isin` | Required, normalized uppercase, unique |
| `sector` | Optional indexed string |
| `industry` | Optional indexed string |
| `business_group_id` | Optional FK |
| `business_group_basis` | Required when a group is assigned |
| `business_group_source_reference` | Required when a group is assigned |
| `created_at`, `updated_at` | UTC timestamps |

The API projects `symbol` and `exchange` from the linked `Ticker`. Milestone 1 supports one primary ticker per company. Multiple listings and securities require a later security/listing model.

#### `BusinessGroup`

Stores a curated business family or promoter group.

| Field | Rules |
|---|---|
| `id` | UUID primary key |
| `name` | Required canonical name, unique |
| `notes` | Optional factual context |
| `source_reference` | Optional supporting reference |
| `created_at`, `updated_at` | UTC timestamps |

A group is assigned only from factual evidence. Surname similarity is never sufficient. If no reliable association exists, `business_group_id` remains null and the API omits the group.

### 4.2 Entitlements

#### `UserEntitlement`

| Field | Rules |
|---|---|
| `id` | UUID primary key |
| `user_id` | Required FK to existing `user.id` |
| `product_code` | Required; Milestone 1 uses `INVESTMENT_RESEARCH` |
| `tier` | `FREE` or `PREMIUM` |
| `status` | `ACTIVE`, `INACTIVE`, or `REVOKED` |
| `valid_from`, `valid_until` | Optional UTC validity bounds |
| `created_at`, `updated_at` | UTC timestamps |

There is exactly zero or one row for each `(user_id, product_code)` pair, enforced by a database unique constraint. Entitlement changes update that row's tier, status, and validity fields; Milestone 1 does not create historical entitlement rows. Missing, inactive, expired, or invalid entitlement data resolves to `FREE`. Historical billing or subscription events may be introduced later if a billing subsystem requires them. Administrators receive full research access but remain subject to document-rights rules when content would be redistributed outside administrative use.

The current tier is resolved from the database on each protected research request. JWT claims are not the authority for the tier because they can become stale.

### 4.3 Narrative research and management

#### `ResearchRevision`

An immutable snapshot of the company's current narrative research.

| Field | Rules |
|---|---|
| `id` | UUID primary key |
| `company_id` | Required FK |
| `revision_number` | Positive integer, unique per company |
| `supersedes_revision_id` | Null for the first revision; otherwise required FK to the previously current revision |
| `why_selected` | Required research narrative |
| `what_is_changing` | Optional narrative |
| `business_journey` | Optional narrative |
| `thesis` | Required narrative |
| `thesis_invalidation` | Required fundamental or investment-thesis invalidation narrative |
| `management_summary` | Optional narrative |
| `management_quality` | `UNASSESSED`, `WEAK`, `WATCH`, `ACCEPTABLE`, or `STRONG` |
| `management_rationale` | Required when quality is not `UNASSESSED` |
| `management_evidence` | Optional factual evidence/reference text |
| `governance_status` | `UNREVIEWED`, `CLEAR`, `WATCH`, or `HIGH_RISK` |
| `change_reason` | Required after the first revision |
| `effective_at` | Required business-effective timestamp |
| `created_by_user_id` | Required administrator FK |
| `created_at` | UTC creation timestamp |

The current revision is the row with the highest revision number. The backend creates the revision and all child points in one transaction. Existing revisions cannot be edited or deleted.

#### `ResearchPoint`

Stores ordered catalysts and risks for one research revision.

| Field | Rules |
|---|---|
| `id` | UUID primary key |
| `research_revision_id` | Required FK |
| `kind` | `CATALYST` or `RISK` |
| `title` | Required |
| `detail` | Optional |
| `status` | Optional stable machine value |
| `target_date` | Optional date |
| `sort_order` | Non-negative integer |

Points belong to a specific immutable revision, ensuring that old thesis context remains reproducible.

### 4.4 Ownership

#### `OwnershipSnapshot`

| Field | Rules |
|---|---|
| `id` | UUID primary key |
| `company_id` | Required FK |
| `as_of_date` | Required; unique per company |
| `promoter_holding_pct` | Optional decimal from 0 through 100 |
| `promoter_pledge_pct` | Optional decimal from 0 through 100 |
| `notes` | Optional ownership/change narrative |
| `source_reference` | Required when either percentage is present |
| `created_by_user_id` | Required administrator FK |
| `created_at` | UTC timestamp |

Ownership history is naturally append-only. Changes are derived by comparing snapshots; old snapshots are retained.

### 4.5 Governance

#### `GovernanceFlag`

| Field | Rules |
|---|---|
| `id` | UUID primary key |
| `company_id` | Required FK |
| `flag_type` | Required stable classification |
| `title` | Required |
| `severity` | `INFO`, `LOW`, `MEDIUM`, `HIGH`, or `CRITICAL` |
| `status` | `OPEN`, `MONITORING`, `RESOLVED`, or `DISMISSED` |
| `factual_evidence` | Required |
| `source_title` | Optional |
| `source_url_or_reference` | Required |
| `interpretation` | Required and explicitly distinguished from factual evidence |
| `observed_on`, `resolved_on` | Dates with cross-field validation |
| `created_by_user_id` | Required administrator FK |
| `created_at`, `updated_at`, `archived_at` | UTC timestamps |

Governance flags are never inferred solely from unsourced narrative. Archival preserves the record.

### 4.6 Company disclosures

#### `CompanyDisclosure`

| Field | Rules |
|---|---|
| `id` | UUID primary key |
| `company_id` | Required FK |
| `event_type` | `REG30` or another stable disclosure type |
| `event_date` | Required |
| `title` | Required |
| `original_source_url_or_reference` | Required |
| `exchange_reference` | Optional |
| `significance_note` | Optional analytical note |
| `is_key` | Required boolean, default false; manually curated |
| `document_id` | Optional FK to the common Document Library |
| `created_by_user_id` | Required administrator FK |
| `created_at`, `updated_at`, `archived_at` | UTC timestamps |

The disclosure represents the event; an attached filing is represented once in the Document Library. `is_key` is a manual designation only. Milestone 1 does not calculate an importance score or classify important disclosures automatically.

### 4.7 Market context

Current market price is read from the linked `Ticker.last_price` and `Ticker.last_updated`. It is not copied into research tables.

#### `MarketPlanRevision`

| Field | Rules |
|---|---|
| `id` | UUID primary key |
| `company_id` | Required FK |
| `revision_number` | Positive integer, unique per company |
| `supersedes_revision_id` | Previous current market-plan revision |
| `currency` | `INR` in Milestone 1 |
| `accumulation_low`, `accumulation_high` | Required positive decimals |
| `preferred_accumulation_price` | Optional decimal inside the accumulation range |
| `supply_low`, `supply_high` | Both null or both present in ascending order |
| `invalidation_level` | Required positive decimal |
| `rationale` | Optional narrative |
| `effective_at` | Required |
| `change_reason` | Required after the first revision |
| `created_by_user_id`, `created_at` | Audit identity and time |

Market plans are manually entered research data. No technical engine creates or updates them in Milestone 1.

### 4.8 Forecast placeholders

#### `ForecastRevision`

| Field | Rules |
|---|---|
| `id` | UUID primary key |
| `company_id` | Required FK |
| `revision_number` | Positive integer, unique per company |
| `supersedes_revision_id` | Previous current forecast revision |
| `as_of_date` | Required |
| `assumptions` | Optional narrative |
| `change_reason` | Required after the first revision |
| `created_by_user_id`, `created_at` | Audit identity and time |

#### `ForecastLine`

| Field | Rules |
|---|---|
| `id` | UUID primary key |
| `forecast_revision_id` | Required FK |
| `fiscal_year` | Four-digit year, such as `2027` |
| `is_estimate` | Boolean; true produces an `FY27E` presentation label |
| `revenue`, `ebitda`, `pat` | Optional fixed-precision decimals |
| `ebitda_margin_pct` | Optional fixed-precision decimal |
| `eps` | Optional fixed-precision decimal; administrator-supplied |
| `currency` | `INR` in Milestone 1 |
| `unit` | `ABSOLUTE`, `THOUSAND`, `LAKH`, `CRORE`, or `MILLION` |

There is one line per fiscal year in a revision. FY27E, FY28E, and FY29E are seed/API conventions, not dedicated columns. The backend stores supplied values and does not calculate or forecast them. In particular, Milestone 1 does not derive EPS from PAT or share count and does not introduce share-count data or EPS calculation logic.

### 4.9 Method-neutral valuation placeholders

#### `ValuationRevision`

| Field | Rules |
|---|---|
| `id` | UUID primary key |
| `company_id` | Required FK |
| `valuation_method` | `PE`, `EV_EBITDA`, `PB`, `NAV`, `SOTP`, `ASSET_VALUE`, `UNIT_BASED`, or `OTHER` |
| `revision_number` | Positive integer, unique per `(company_id, valuation_method)` |
| `supersedes_revision_id` | Previous current valuation revision for the same company and method; null for the first method revision |
| `justified_multiple` | Optional fixed-precision decimal |
| `implied_enterprise_value` | Optional fixed-precision decimal administrator-supplied snapshot |
| `net_debt` | Optional signed fixed-precision decimal administrator-supplied snapshot; positive means debt exceeds cash and negative means net cash |
| `other_equity_adjustment` | Optional signed fixed-precision decimal administrator-supplied snapshot |
| `implied_future_equity_value` | Optional fixed-precision decimal |
| `required_return_pct` | Optional fixed-precision decimal |
| `discount_period_years` | Optional positive fixed-precision decimal |
| `present_value` | Optional fixed-precision decimal |
| `current_market_cap` | Optional fixed-precision decimal captured as of the revision |
| `currency`, `unit` | Required when monetary values are present |
| `valuation_notes` | Optional narrative |
| `as_of_date` | Required |
| `change_reason` | Required after the first revision |
| `created_by_user_id`, `created_at` | Audit identity and time |

#### `ValuationReferenceLine`

| Field | Rules |
|---|---|
| `id` | UUID primary key |
| `valuation_revision_id` | Required FK to exactly one immutable `ValuationRevision` |
| `reference_forecast_revision_id` | Optional FK to an immutable internal forecast for the same company as the valuation |
| `reference_fiscal_year` | Optional fiscal year associated with the reference metric; required when a forecast revision is referenced |
| `reference_metric` | Required extensible uppercase slug, such as `PAT`, `EPS`, `EBITDA`, `NET_DEBT`, `LAND_VALUE`, `COST_PER_TON`, or `CAPACITY` |
| `reference_metric_value` | Required fixed-precision decimal snapshot |
| `reference_metric_unit` | Required extensible uppercase slug, such as `INR_CRORE`, `INR_PER_SHARE`, `INR_PER_TON`, or `TONNES_PER_YEAR` |
| `reference_metric_basis` | Required narrative explaining normalization, period, source, and meaning |
| `sort_order` | Required non-negative integer, unique within the valuation revision |

Each reference line belongs immutably to one valuation revision. A valuation revision may have zero, one, or many reference lines according to its method and recorded reasoning. References are line-scoped so one valuation may mix forecast-derived inputs with administrator-supplied operating, balance-sheet, asset, or market assumptions.

`valuation_method` is a controlled classification. `ValuationReferenceLine.reference_metric` and `ValuationReferenceLine.reference_metric_unit` are deliberately not rigid database enums: they are validated, length-limited uppercase slugs so company- and industry-specific metrics can be introduced without a schema migration. Known metric and unit names may be catalogued in application code for consistency without rejecting a well-formed new slug.

Current valuations are the highest revision in each `(company_id, valuation_method)` stream. Creating or revising one method does not supersede another method. The same internal `ForecastRevision` may support several independent valuation methods without changing the forecast.

For enterprise-value methods, the stored bridge convention is:

```text
implied_enterprise_value
- net_debt
+ other_equity_adjustment
= implied_future_equity_value
```

`net_debt > 0` means debt exceeds cash; `net_debt < 0` means net cash. Milestone 1 neither calculates nor enforces this bridge: every bridge value is an administrator-supplied snapshot of the recorded reasoning. `PE`, `PB`, `NAV`, `ASSET_VALUE`, and other equity-value methods may leave `implied_enterprise_value`, `net_debt`, and `other_equity_adjustment` null when irrelevant.

A unit-based valuation can preserve several simultaneous inputs:

```json
{
  "valuation_method": "UNIT_BASED",
  "reference_lines": [
    {
      "reference_metric": "CAPACITY",
      "reference_metric_value": "500000",
      "reference_metric_unit": "TONNES_PER_YEAR",
      "reference_metric_basis": "installed post-expansion capacity",
      "sort_order": 0
    },
    {
      "reference_metric": "EV_PER_TON",
      "reference_metric_value": "20000",
      "reference_metric_unit": "INR_PER_TON",
      "reference_metric_basis": "selected enterprise-value benchmark",
      "sort_order": 1
    },
    {
      "reference_metric": "EBITDA_PER_TON",
      "reference_metric_value": "8200",
      "reference_metric_unit": "INR_PER_TON",
      "reference_metric_basis": "steady-state expected EBITDA",
      "sort_order": 2
    },
    {
      "reference_metric": "COST_PER_TON",
      "reference_metric_value": "41500",
      "reference_metric_unit": "INR_PER_TON",
      "reference_metric_basis": "normalized FY27 production cost",
      "sort_order": 3
    }
  ]
}
```

Other valid extensible metrics include `REVENUE_PER_TON`, `EV_PER_TON`, `CAPACITY_TONNES_PER_YEAR`, `VALUE_PER_MW`, `CAPACITY_MW`, `VALUE_PER_BED`, `VALUE_PER_ROOM`, `VALUE_PER_STORE`, and `VALUE_PER_SUBSCRIBER`. These examples do not form an exhaustive database enum.

Cost-per-unit, capacity, net-debt context, and similar values are reference inputs that a valuation may preserve. `ValuationRevision` and its reference lines store an administrator's valuation assumptions and conclusions; they do not calculate operating metrics, forecasts, market CMP, enterprise-to-equity bridges, or institutional brokerage valuations. Milestone 1 does not calculate multiples, future value, discounting, present value, market capitalization, net debt, NAV, replacement value, cost per unit, EBITDA per unit, capacity, or SOTP components.

## 5. Common Document Library

Institutional research, annual reports, investor presentations, concalls, Screener references, Reg. 30 attachments, and other research material share one library.

### 5.1 `Document`

| Field | Rules |
|---|---|
| `id` | UUID primary key |
| `document_type` | `ANNUAL_REPORT`, `QUARTERLY_RESULTS`, `INVESTOR_PRESENTATION`, `CONCALL`, `SCREENER`, `REG30_ATTACHMENT`, `CREDIT_RATING_REPORT`, `INDUSTRY_REPORT`, `INSTITUTIONAL_RESEARCH`, or `OTHER` |
| `title` | Required |
| `document_date` | Required when known; nullable only for undated references |
| `reporting_period` | Optional stable label |
| `publisher_name` | Optional publisher display name for non-institutional documents; normalized only when building the fingerprint |
| `publisher_reference` | Optional publisher URL or identifier |
| `original_source_url` | Optional HTTP/HTTPS URL |
| `discovery_source_type` | `OFFICIAL_SITE`, `EXCHANGE`, `TELEGRAM`, `EMAIL`, `SEARCH`, `USER`, or `OTHER` |
| `discovery_source_reference` | Optional URL or opaque reference |
| `source_access` | `PUBLIC`, `RESTRICTED`, or `UNKNOWN` |
| `acquisition_method` | `PUBLIC_DOWNLOAD`, `USER_UPLOAD`, `MANUAL_REFERENCE`, or `NOT_ACQUIRED` |
| `distribution_status` | `UNKNOWN`, `LINK_ONLY`, `PRIVATE_LIBRARY`, or `APP_DISTRIBUTABLE` |
| `ingestion_status` | `DISCOVERED`, `AWAITING_UPLOAD`, `STORED`, or `ANALYSED` |
| `storage_provider`, `storage_key` | Nullable opaque storage reference |
| `content_hash_sha256` | Nullable lowercase SHA-256 hex digest |
| `metadata_fingerprint` | Required stable digest generated from normalized metadata |
| `mime_type`, `file_size_bytes` | Nullable stored-file metadata |
| `provided_by_user_id` | Required only for `USER_UPLOAD` |
| `distribution_basis` | Required for `APP_DISTRIBUTABLE`; optional otherwise |
| `rights_verified_by_user_id`, `rights_verified_at` | Required for `APP_DISTRIBUTABLE` |
| `created_by_user_id` | Required administrator FK for Milestone 1 metadata entry |
| `created_at`, `updated_at`, `archived_at` | UTC timestamps |

`storage_key` is never a client-facing URL. Future file delivery must authorize the request and return a short-lived URL or stream.

### 5.2 `DocumentCompanyLink`

| Field | Rules |
|---|---|
| `document_id`, `company_id` | Composite unique relationship |
| `is_primary` | Boolean; zero or one linked company may be primary for a document |
| `created_at` | UTC timestamp |

Normal single-company documents ordinarily mark their sole company as primary. A genuine sector, industry, or multi-company report may have no natural primary company and must not be assigned one artificially. At most one link per document may have `is_primary=true`, enforced transactionally and, where supported portably by the target database, with a filtered unique index. Link order has no semantic meaning. The link table avoids duplicating a multi-company report.

### 5.3 `Institution`

| Field | Rules |
|---|---|
| `id` | UUID primary key |
| `name` | Required canonical display name |
| `normalized_name` | Required unique normalized name |
| `website` | Optional URL |
| `created_at`, `updated_at` | UTC timestamps |

### 5.4 `InstitutionalReportMetadata`

One-to-one extension for a document whose type is `INSTITUTIONAL_RESEARCH`.

| Field | Rules |
|---|---|
| `document_id` | Primary key and FK |
| `institution_id` | Required FK |
| `analyst_name` | Optional; supporting duplicate evidence only |
| `report_type` | Required stable classification |
| `created_at`, `updated_at` | UTC timestamps |

Several reports from the same institution are valid. Older reports are retained. The frontend may later feature the latest report per institution while keeping the complete history.

### 5.5 Source, acquisition, distribution, and ingestion

These classifications are independent:

- `source_access` describes accessibility at the original source.
- `acquisition_method` records how the library reference or stored copy was obtained. `MANUAL_REFERENCE` means an administrator recorded metadata from a lawful reference without storing a file; `NOT_ACQUIRED` means the report is known to exist but no library copy or accepted reference has been acquired.
- `distribution_status` records what the application may distribute.
- `ingestion_status` records processing progress.

Public accessibility does not imply redistribution rights. Conservative defaults are mandatory:

- A publicly accessible report defaults to `LINK_ONLY` unless broader rights are verified.
- A restricted institutional report obtained by user upload defaults to `PRIVATE_LIBRARY`.
- `UNKNOWN` does not permit stored-file delivery.
- `APP_DISTRIBUTABLE` requires a documented, independently valid distribution basis and rights verification.
- A premium product entitlement never changes document rights.

Telegram channels and feeds may be recorded as discovery sources. Telegram is not treated as the authoritative original source. If an official public publisher URL is found, it becomes `original_source_url` while the Telegram reference remains the discovery source. Restricted or unclear material is not automatically downloaded or redistributed.

Valid ingestion combinations are:

| Ingestion status | Valid acquisition method | Required storage state |
|---|---|---|
| `DISCOVERED` | `NOT_ACQUIRED` or `MANUAL_REFERENCE` | No stored file required |
| `AWAITING_UPLOAD` | `NOT_ACQUIRED` or `MANUAL_REFERENCE` | Storage fields absent |
| `STORED` | `PUBLIC_DOWNLOAD` or `USER_UPLOAD` | Storage reference, MIME metadata where known, and SHA-256 required |
| `ANALYSED` | `PUBLIC_DOWNLOAD` or `USER_UPLOAD` | Same requirements as `STORED` |

Forward transitions are `DISCOVERED` to `AWAITING_UPLOAD` or `STORED`, `AWAITING_UPLOAD` to `STORED`, and `STORED` to `ANALYSED`. Administrative corrections require a reason and an audit event. `USER_UPLOAD` requires `provided_by_user_id`. Automated acquisition cannot use `PUBLIC_DOWNLOAD` when `source_access` is `RESTRICTED` or `UNKNOWN`.

Milestone 1 persists the complete ingestion enum for contract stability but provides no analysis operation. Its own endpoints therefore do not perform the `STORED` to `ANALYSED` transition; that transition belongs to the future analysis subsystem.

### 5.6 Deduplication

Every Document type uses one stable, deterministic metadata-fingerprint algorithm. The canonical fingerprint payload contains:

1. `document_type`;
2. all linked canonical company IDs sorted lexicographically, or an explicit empty-list sentinel when no company is linked;
3. `document_date` in ISO format, or an explicit null sentinel;
4. normalized document title;
5. canonical publisher or institution identity when applicable, otherwise an explicit null sentinel;
6. normalized `reporting_period` when applicable, otherwise an explicit null sentinel; and
7. normalized institutional `report_type` when applicable, otherwise an explicit null sentinel.

For institutional research, canonical institution ID is the publisher/institution component. For other document types, the component uses the normalized generic publisher identity when supplied. Multi-company fingerprints use the complete sorted company-ID list, so link insertion order and the optional primary designation cannot change the result.

Analyst name is always excluded so later enrichment does not change the fingerprint. It may be used only as supporting duplicate evidence.

Canonicalization is deterministic and versioned in application code. It covers case, Unicode normalization, surrounding and repeated whitespace, punctuation conventions, canonical publisher/institution identity, canonical company IDs, ISO date representation, reporting-period normalization, null sentinels, and stable serialization before hashing.

The fingerprint is recomputed only when a canonical input changes, including a change to the set of company links. Changes to link order, primary designation, analyst name, discovery metadata, access state, storage state, or rights state do not change it.

Deduplication rules:

- A matching SHA-256 digest is the definitive same-binary signal.
- A matching metadata fingerprint without a hash match is a likely duplicate requiring review.
- The same SHA-256 with discrepant metadata reuses the stored binary but flags the metadata conflict for review.
- A document may acquire additional company or provenance links without duplicating the stored binary.
- Institution and date alone are never unique.
- Documents of every first-class type use the same canonical fingerprint pipeline; type-specific optional inputs use explicit null sentinels.
- Duplicate handling must preserve the most restrictive applicable rights and must not broaden distribution automatically.

### 5.7 `DocumentAuditEvent`

A focused append-only audit record for meaningful document-state changes.

| Field | Rules |
|---|---|
| `id` | UUID primary key |
| `document_id` | Required FK |
| `event_type` | Required stable enum |
| `field_changed` | Optional field name for single-field changes |
| `old_value` | Nullable portable JSON value |
| `new_value` | Nullable portable JSON value |
| `actor_user_id` | Required FK |
| `reason` | Required for rights, access, correction, and archival changes |
| `created_at` | UTC timestamp |

Required event types include:

- `SOURCE_ACCESS_CHANGED`
- `ACQUISITION_METHOD_CHANGED`
- `DISTRIBUTION_STATUS_CHANGED`
- `INGESTION_STATUS_CHANGED`
- `RIGHTS_VERIFIED`
- `RIGHTS_VERIFICATION_REVOKED`
- `STORAGE_ATTACHED`
- `COMPANY_LINKS_CHANGED`
- `ARCHIVED`
- `RESTORED`

Audit events are created in the same transaction as the corresponding document change. They cannot be changed or deleted through the API. The current `Document` row remains the source of operational truth; audit events neither reconstruct state nor drive command handling. This is deliberately not generic event sourcing.

For `COMPANY_LINKS_CHANGED`, `field_changed` is `company_links`; `old_value` and `new_value` contain the sorted canonical company IDs, optional primary company ID, and the corresponding metadata fingerprint. The event contains identifiers and fingerprint metadata only, not document content.

## 6. Institutional research extension and rights inheritance

The retained model separation is:

```text
Document
└── InstitutionalReportMetadata
    └── InstitutionalAnalysisRevision (future)
        └── InstitutionalEstimateLine (future)
```

Milestone 1 creates `Document` and `InstitutionalReportMetadata`. It reserves the interfaces below but does not create institutional-analysis or estimate tables, ingest files, or generate analysis.

### 6.1 Future `InstitutionalAnalysisRevision`

An immutable analysis revision will reference exactly one institutional document and may contain:

- recommendation and target price;
- valuation methodology and justified multiple;
- important assumptions;
- catalysts and risks;
- extracted key insights;
- information potentially missing from internal research;
- comparison with a specific internal thesis revision;
- forecast-review-required and thesis-review-required flags;
- analysis method/version and creation provenance; and
- a rights mode of `INHERITED` by default or `INDEPENDENT` only with an independently valid rights basis.

### 6.2 Future `InstitutionalEstimateLine`

Estimate lines will reference an immutable institutional analysis revision and use the same dimensions as internal forecasts:

- fiscal year and estimate flag;
- Revenue;
- EBITDA;
- EBITDA margin;
- PAT;
- EPS;
- currency and unit.

Using the same fiscal-period and unit conventions permits comparison without mixing internal and institutional forecasts in one table.

### 6.3 Derived-content rights

Institutional analysis, extracted estimates, summaries, comparisons, and future consensus contributions inherit the underlying document's distribution restriction by default.

Rules:

1. A `PRIVATE_LIBRARY`, `LINK_ONLY`, `UNKNOWN`, or otherwise restricted source cannot produce derived content exposed to unrelated premium users.
2. The provider of a private user upload and administrators may access permitted derived content within the private library context.
3. Broader distribution requires an independently valid rights basis or analysis built from independently sourced public information.
4. An independent basis must record its provenance, distribution status, verification actor, verification time, and explanatory basis.
5. Merely rewriting, summarizing, aggregating, or extracting numbers does not remove inherited restrictions.
6. Product entitlement never overrides inherited or independently assigned rights.
7. A comparison involving multiple institutional sources receives the most restrictive effective distribution status across all contributing sources unless every restricted contribution is replaced by independently sourced, verified information.
8. A future consensus calculation must filter eligible sources for the requesting user before aggregation; it must not leak restricted estimates through averages, ranges, counts, or differences.

Institutional research remains evidence, not authoritative truth. It can raise review flags but never directly overwrites an internal `ResearchRevision`, `ForecastRevision`, or `ValuationRevision`.

## 7. Entitlement and response-projection policy

### 7.1 Initial product split

The initial policy is:

**Free:**

- company identity;
- business-group label where factually assigned;
- current market price and timestamp;
- public/link-safe document title, type, date, and official source metadata; and
- public/link-safe disclosure title, date, and original reference.

**Premium:**

- ownership details and notes;
- management assessment, rationale, and evidence;
- full thesis, catalysts, risks, and thesis invalidation;
- governance detail and interpretation;
- disclosure significance notes;
- market plans and zones;
- forecast revisions;
- valuation revisions; and
- research revision history.

**Admin:**

- all research management functions and complete research data;
- document administration subject to audit; and
- no authority to redistribute documents contrary to rights policy.

### 7.2 Enforcement

Each request follows this sequence:

1. JWT authentication resolves the user.
2. `EntitlementService` resolves the effective research tier from `UserEntitlement`.
3. `ResearchAccessPolicy` determines allowed research sections.
4. For document or derived content, `DocumentAccessPolicy` separately evaluates source access, acquisition, distribution, ownership, archival state, and derived-rights inheritance.
5. `ResearchQueryService` loads only the relations needed for the authorized projection where practical.
6. `ResearchPresenter` uses explicit free, premium, or administrative Marshmallow schemas.
7. The response may identify locked section names but never include locked values.

Client-side hiding is presentation only and is never considered an access control.

### 7.3 Null and omission semantics

- A present field with `null` means the caller is entitled to that field but no value is known.
- An absent field or section means it was not included in the caller's projection.
- Locked-section metadata may name a section and required tier but cannot contain protected values, snippets, counts that reveal protected information, or derived aggregates.

## 8. Service boundaries

New research code uses these boundaries without refactoring existing application domains:

- `EntitlementService`: resolves free or premium product access.
- `ResearchAccessPolicy`: maps research sections to product tiers.
- `DocumentAccessPolicy`: enforces source, distribution, ownership, and derived-content rights.
- `ResearchQueryService`: company list, detail, collection, and history queries.
- `ResearchCommandService`: transactional creation of companies and immutable research revisions.
- `MarketPriceService`: read-only projection of `Ticker.last_price` and `last_updated`.
- `DocumentLibraryService`: document metadata, state transitions, company links, institutions, and audit events.
- `DocumentDeduplicationService`: metadata fingerprints, SHA-256 matches, and duplicate candidates.
- `ResearchPresenter`: explicit entitlement-safe response schemas.

Routes authenticate, authorize, validate request data, call one service operation, and serialize the result. Services own transactions and domain invariants. Existing trade, Telegram, Kite, ticker, and authentication routes retain their current patterns.

`DocumentLibraryService.create_document()` accepts and validates the complete creation aggregate: Document metadata, the initial company-link set, optional primary designation, and conditional institutional metadata. It computes the final fingerprint, begins one database transaction, performs the final duplicate/conflict check inside that transaction, and inserts the Document row, company links, and institutional metadata before committing. Appropriate locking or a supporting database constraint closes the concurrent-creation race. No incomplete institutional document or document with a provisional fingerprint becomes visible.

`DocumentLibraryService.add_company_link()` prepares the complete resulting link set before mutation, validates the zero-or-one-primary rule, recomputes the fingerprint from the final sorted company set, reruns duplicate/conflict detection, preserves the existing rights fields, inserts the link, updates the fingerprint, and writes a `COMPANY_LINKS_CHANGED` audit event in one transaction. Any validation or duplicate conflict rolls back the complete operation.

## 9. API contracts

All Milestone 1 research endpoints require JWT authentication. Consumer responses are rights- and entitlement-filtered on the backend.

### 9.1 Consumer endpoints

| Method and path | Purpose |
|---|---|
| `GET /api/research/companies` | Paginated entitlement-safe company summaries; filters: `q`, `sector`, `industry`, `page`, `per_page` |
| `GET /api/research/companies/<company_id>` | Current company research aggregate |
| `GET /api/research/companies/<company_id>/documents` | Paginated rights-safe documents; filters include type, institution, report type, and date range |
| `GET /api/research/companies/<company_id>/disclosures` | Paginated disclosures; filters include `event_type`, `is_key`, date range, and newest/oldest ordering |
| `GET /api/research/companies/<company_id>/institutional-reports` | Rights-safe institutional metadata; optional `latest_per_institution=true` |
| `GET /api/research/documents/<document_id>` | Rights-safe document metadata |
| `GET /api/research/companies/<company_id>/history` | Premium/admin history; `section` is one of `research`, `market`, `forecast`, or `valuation`; valuation history may filter by `valuation_method` |

No Milestone 1 endpoint returns a stored file, extracted document content, or institutional analysis.

The latest five manually curated important Reg. 30 disclosures are retrieved without a special scoring API:

```text
GET /api/research/companies/<company_id>/disclosures?event_type=REG30&is_key=true&sort=-event_date&per_page=5
```

The query filters `event_type=REG30` and `is_key=true`, orders newest first with a deterministic `created_at`/`id` tie-breaker, and limits the page to five. There is no numeric importance score or automated importance classification.

### 9.2 Administrative endpoints

All administrative endpoints use the existing administrator authorization mechanism.

| Method and path | Purpose |
|---|---|
| `POST /api/admin/research/companies` | Create company research identity linked to an existing ticker |
| `PATCH /api/admin/research/companies/<company_id>` | Correct stable company metadata |
| `PUT /api/admin/users/<user_id>/entitlements/investment-research` | Create, replace, deactivate, or revoke the user's research entitlement |
| `POST /api/admin/research/companies/<company_id>/research-revisions` | Create immutable narrative revision |
| `POST /api/admin/research/companies/<company_id>/ownership-snapshots` | Add dated ownership snapshot |
| `POST /api/admin/research/companies/<company_id>/governance-flags` | Add governance flag |
| `PATCH /api/admin/research/governance-flags/<flag_id>` | Resolve, archive, or correct flag metadata |
| `POST /api/admin/research/companies/<company_id>/disclosures` | Add disclosure |
| `PATCH /api/admin/research/disclosures/<disclosure_id>` | Correct or archive disclosure |
| `POST /api/admin/research/companies/<company_id>/market-plan-revisions` | Create immutable market-plan revision |
| `POST /api/admin/research/companies/<company_id>/forecast-revisions` | Create immutable forecast and lines |
| `POST /api/admin/research/companies/<company_id>/valuation-revisions` | Atomically create an immutable method-specific valuation revision and its zero or more reference lines; forecast links are optional |
| `POST /api/admin/research/documents` | Atomically create Document metadata, initial company links, optional primary designation, and conditional institutional metadata |
| `PATCH /api/admin/research/documents/<document_id>` | Apply validated metadata/state/rights change and audit it |
| `POST /api/admin/research/documents/<document_id>/company-links` | Add company relationship without duplicating document |
| `POST /api/admin/research/institutions` | Create canonical institution |
| `PATCH /api/admin/research/institutions/<institution_id>` | Correct institution metadata |

File upload, download, extraction, and analysis endpoints are intentionally absent.

The document-creation request is one aggregate payload:

```json
{
  "document": {
    "document_type": "INSTITUTIONAL_RESEARCH",
    "title": "Example report",
    "document_date": "2026-08-31",
    "reporting_period": "FY27E",
    "original_source_url": "https://institution.example/research/report",
    "source_access": "PUBLIC",
    "acquisition_method": "MANUAL_REFERENCE",
    "distribution_status": "LINK_ONLY",
    "ingestion_status": "DISCOVERED"
  },
  "company_links": [
    {
      "company_id": "company-uuid",
      "is_primary": true
    }
  ],
  "institutional_report": {
    "institution_id": "institution-uuid",
    "analyst_name": null,
    "report_type": "INITIATING_COVERAGE"
  }
}
```

`company_links` is part of initial creation rather than a follow-up repair step. For `INSTITUTIONAL_RESEARCH`, it must contain at least one valid company and `institutional_report` is required. For other document types, `institutional_report` must be absent. The service validates the aggregate, builds the final canonical fingerprint from the complete linked-company set, and performs the final duplicate check and all inserts inside one transaction.

The subsequent company-link endpoint remains available. Its success response contains the final rights-safe Document projection. A fingerprint conflict returns `409 Conflict`; no link, fingerprint, rights field, or audit event is changed.

A method-specific valuation request may reference, but does not require, an internal forecast:

```json
{
  "valuation_method": "EV_EBITDA",
  "base_revision_id": null,
  "reference_lines": [
    {
      "reference_forecast_revision_id": "forecast-revision-uuid",
      "reference_fiscal_year": 2027,
      "reference_metric": "EBITDA",
      "reference_metric_value": "125.00",
      "reference_metric_unit": "INR_CRORE",
      "reference_metric_basis": "internal FY27 estimate",
      "sort_order": 0
    },
    {
      "reference_forecast_revision_id": null,
      "reference_fiscal_year": null,
      "reference_metric": "NET_DEBT",
      "reference_metric_value": "75.00",
      "reference_metric_unit": "INR_CRORE",
      "reference_metric_basis": "administrator snapshot at valuation date",
      "sort_order": 1
    }
  ],
  "justified_multiple": "12.0",
  "implied_enterprise_value": "1500.00",
  "net_debt": "75.00",
  "other_equity_adjustment": "0.00",
  "implied_future_equity_value": "1425.00",
  "required_return_pct": "15.0",
  "discount_period_years": "2.0",
  "present_value": "1077.50",
  "current_market_cap": "900.00",
  "currency": "INR",
  "unit": "CRORE",
  "valuation_notes": "Internal EV/EBITDA valuation conclusion",
  "as_of_date": "2026-09-04",
  "change_reason": null
}
```

For a first revision within a method stream, `base_revision_id` and `change_reason` are null. A later revision supplies the current revision ID and a reason. A `NAV`, `ASSET_VALUE`, `SOTP`, or other appropriate method may omit forecast-linked reference lines entirely. The example's bridge values are supplied snapshots, not server-calculated outputs.

### 9.3 Revision concurrency

Revision-creation requests include `base_revision_id` after the first revision. The service verifies that it is still current. A stale base returns `409 Conflict`; the server does not silently overwrite intervening work.

Revision header and children are created atomically. Document aggregates follow the equivalent atomicity rule for their initial metadata, links, institutional extension, fingerprint, and duplicate decision. No partial revision or document aggregate is visible after a failed transaction.

### 9.4 Company detail response

A premium response has this structural contract:

```json
{
  "company": {
    "id": "uuid",
    "name": "IKIO Lighting Limited",
    "symbol": "IKIO",
    "exchange": "NSE",
    "isin": "normalized-isin",
    "sector": null,
    "industry": null
  },
  "market_quote": {
    "cmp": 123.45,
    "as_of": "2026-09-04T09:30:00Z"
  },
  "research": {
    "revision": 1,
    "why_selected": "sourced narrative",
    "what_is_changing": null,
    "business_journey": null,
    "thesis": "sourced narrative",
    "catalysts": [],
    "risks": [],
    "thesis_invalidation": "explicit fundamental thesis invalidation condition"
  },
  "management": {
    "summary": null,
    "quality": "UNASSESSED",
    "rationale": null,
    "evidence": null
  },
  "governance": {
    "status": "UNREVIEWED",
    "flags": []
  },
  "ownership": null,
  "market_plan": null,
  "forecast": null,
  "valuations": [],
  "access": {
    "tier": "PREMIUM",
    "locked_sections": []
  }
}
```

Free responses omit premium sections entirely. Document collections receive an additional rights projection; they never expose `storage_key`, private content, hashes usable as content identifiers, or rights-restricted derived data to an unauthorized caller.

### 9.5 Serialization conventions

- UUIDs are JSON strings.
- Dates are ISO `YYYY-MM-DD`.
- Timestamps are ISO-8601 UTC.
- Fixed-precision financial amounts and percentages are serialized as decimal strings.
- Existing ticker CMP remains a JSON number for compatibility.
- Enum values use the uppercase machine values defined by this specification.
- Collection endpoints use a consistent `items`, `page`, `per_page`, `total_items`, and `total_pages` shape.

## 10. Validation and domain invariants

### 10.1 General

- Reject unknown write fields.
- Trim strings and normalize identifiers before uniqueness checks.
- Validate URLs as HTTP or HTTPS.
- Apply explicit maximum lengths to names, titles, references, and narrative fields.
- Do not accept client-supplied IDs, actor IDs, revision numbers, audit timestamps, or entitlement decisions where the server can derive them.

### 10.2 Company and group

- ISIN must be exactly 12 uppercase characters matching the ISIN structural pattern.
- ISIN and ticker relationship must be unique.
- `ticker_id` must reference an existing ticker.
- Business-group assignment requires both evidence basis and source reference.
- `(user_id, product_code)` must be unique in `UserEntitlement`; entitlement changes update the existing row rather than append history.

### 10.3 Percentages, prices, and forecasts

- Ownership percentages and margins are from 0 through 100.
- Monetary and multiple values use fixed-precision numeric columns, never binary floating point.
- Accumulation bounds must be positive and ordered.
- Preferred accumulation price must lie within the accumulation bounds.
- Supply bounds must be supplied together and ordered.
- Forecast fiscal years are unique inside a revision.
- `ForecastLine.eps` is an optional fixed-precision administrator snapshot. It is validated as a supplied numeric value independently of PAT, and no share count or PAT-to-EPS calculation is required or performed.
- `ValuationRevision.revision_number` is unique within `(company_id, valuation_method)`, and a superseded valuation must belong to the same company and method.
- `ValuationReferenceLine.sort_order` is non-negative and unique within its valuation revision; line IDs, ownership, values, and order are immutable after insertion.
- Every reference line requires one metric, value, unit, and basis. Metric and unit must be length-limited uppercase slugs rather than closed database enums.
- A supplied line-level `reference_forecast_revision_id` must belong to the same company and requires `reference_fiscal_year`; the referenced fiscal-year line and metric must exist. A valuation may otherwise contain non-forecast reference lines or no reference lines when its method permits.
- `PE` may contain an `EPS` or `PAT` reference line, may link a line to a forecast revision/year only when that metric is stored in the referenced forecast line, and may use `justified_multiple`; those optional references are validated when supplied rather than universally required.
- `EV_EBITDA` may contain an `EBITDA` forecast reference line plus `NET_DEBT` or other relevant context lines, and may use `justified_multiple`.
- `PB` may contain `BOOK_VALUE` or `BOOK_VALUE_PER_SHARE` reference lines and may use `justified_multiple`.
- `NAV` may contain only a `NAV` reference line and does not require an earnings forecast or justified multiple.
- `ASSET_VALUE` may contain several replacement-value, land-value, plant-value, capacity, or other extensible asset reference lines and does not require PAT.
- `UNIT_BASED` requires at least one reference line and may simultaneously contain capacity, value-per-unit, EBITDA-per-unit, cost-per-unit, or other relevant lines.
- `SOTP` does not require an earnings forecast; `valuation_notes` must explain the aggregate basis because detailed component modelling is outside Milestone 1.
- `OTHER` requires `valuation_notes` sufficient to explain the methodology.
- `implied_enterprise_value`, `net_debt`, and `other_equity_adjustment` are optional. Equity-value methods may leave them null. When supplied, each is a fixed-precision administrator snapshot; `net_debt` may be positive, zero, or negative under the documented sign convention.
- The server does not calculate, backfill, reconcile, or require equality for `implied_enterprise_value - net_debt + other_equity_adjustment = implied_future_equity_value` in Milestone 1.
- Every valuation revision must contain a meaningful conclusion through at least one of `implied_enterprise_value`, `implied_future_equity_value`, `present_value`, or `valuation_notes`.
- No forecast, operating-metric, net-debt, enterprise-to-equity, or valuation engine-derived values are accepted as implied server output in Milestone 1.

### 10.4 Revisions

- The first revision has number 1 and no superseded revision.
- Subsequent revisions require the current base revision and a non-empty reason.
- Valuation first/current/superseded semantics apply independently within each valuation-method stream.
- Revision records and their children are append-only.
- Hard delete is prohibited for revisions, forecasts, valuations, ownership snapshots, and document audit events.
- `ResearchRevision.thesis_invalidation` and `MarketPlanRevision.invalidation_level` are distinct required concepts; one cannot substitute for the other.

### 10.5 Documents

- Institutional metadata is permitted only for an institutional document type.
- Institutional documents require an institution, report type, date when known, and at least one company link.
- Initial document creation validates metadata, the complete company-link set, optional primary designation, and conditional institutional metadata before insertion.
- The final fingerprint and duplicate decision are computed from the complete initial link set before the Document becomes visible.
- The final duplicate check and aggregate inserts share one transaction, with a database constraint or locking strategy preventing concurrent duplicate creation.
- Adding a company link recomputes the fingerprint, reruns duplicate detection, preserves rights, and records `COMPANY_LINKS_CHANGED` atomically; any failure rolls back every part of the change.
- Quarterly results, credit-rating reports, and industry reports use their first-class document types and must not be stored as `OTHER`.
- A document has zero or one primary company. Multi-company and industry reports may legitimately have none.
- `source_access=PUBLIC` and `distribution_status=LINK_ONLY` each require an original HTTP/HTTPS source URL.
- `STORED` and `ANALYSED` require storage metadata and SHA-256.
- `USER_UPLOAD` requires a providing user.
- `APP_DISTRIBUTABLE` requires a distribution basis and rights verification.
- `PRIVATE_LIBRARY` and restricted rights are not widened by entitlement, deduplication, state transition, or analysis.
- Analyst enrichment never changes the stable metadata fingerprint.
- Archival and restoration produce audit events.
- Rights-sensitive changes require an actor and reason.

## 11. Error handling

New endpoints preserve the existing top-level error style while using stable error codes:

```json
{
  "error": "validation_error",
  "message": "Request validation failed",
  "details": {
    "field": ["reason"]
  }
}
```

Status rules:

- `400 Bad Request`: malformed JSON or semantic validation failure.
- `401 Unauthorized`: missing, expired, or invalid JWT.
- `403 Forbidden`: insufficient product entitlement, administrator permission, ownership, or document rights.
- `404 Not Found`: unknown or inaccessible resource. Rights-sensitive lookups may use 404 to avoid confirming private-resource existence.
- `409 Conflict`: duplicate stable identity, duplicate current version, stale base revision, or unresolved duplicate document candidate.
- `500 Internal Server Error`: unexpected failure after rollback, with a generic response and server-side logging.

No endpoint returns raw exception text, storage credentials, private references, or restricted snippets in error messages.

## 12. Migration and baseline strategy

Flask-Migrate is configured but the repository has no committed Alembic history. Implementation must establish a verified baseline before creating the additive Milestone 1 migration.

### 12.1 Pre-migration inventory

Before generating or applying migrations:

1. Identify every active deployment database and dialect.
2. Back up each database using its normal operational process.
3. Inspect whether an `alembic_version` table or external migration history exists.
4. Compare the live schema with current SQLAlchemy models, including indexes, constraints, enum representation, and nullability.
5. Record any drift and resolve it explicitly; do not let autogeneration silently normalize existing tables.

### 12.2 Baseline

Create an initial baseline revision representing the existing schema exactly. For an existing verified database, stamp that baseline only after schema comparison confirms equivalence. For a new empty database, apply the baseline normally.

Stamping is an explicit deployment operation, not application-startup behavior. The application must not use `db.create_all()` as a migration substitute.

### 12.3 Milestone 1 migration

After the baseline, create a separate additive revision that creates only new Investment Operating System tables, foreign keys, indexes, and constraints. It must not alter or rebuild existing user, ticker, trade, tag, Telegram, or verification tables.

The new entitlement table references `user`; the new company table references `ticker`. ORM relationships may be added to model definitions without adding columns to the existing tables.

The entitlement table migration includes a unique constraint on `(user_id, product_code)` and does not create an entitlement-history table.

The `forecast_line` table includes nullable fixed-precision `eps`. The migration adds no share-count column, generated column, trigger, or other EPS calculation mechanism.

Valuation storage uses a controlled `valuation_method` classification. `ValuationRevision` has nullable fixed-precision columns for `implied_enterprise_value`, signed `net_debt`, and signed `other_equity_adjustment`; no generated column, trigger, or formula constraint calculates or reconciles the enterprise-to-equity bridge. The valuation revision uniqueness constraint is `(company_id, valuation_method, revision_number)`.

Create `valuation_reference_line` with a required FK to `valuation_revision`, an optional FK to `forecast_revision`, optional fiscal year, required fixed-precision value and basis, portable string columns for extensible `reference_metric` and `reference_metric_unit`, and a non-negative `sort_order`. Add uniqueness on `(valuation_revision_id, sort_order)` plus indexes for parent retrieval and forecast-reference lookup. The migration must not create database enums or industry-specific tables for operating metric names or units. Reference lines are inserted with their parent revision and are never updated or reassigned.

`Document.metadata_fingerprint` is non-null at insertion. The schema and migration do not provide a provisional fingerprint state for creating a Document before its initial links or institutional metadata.

Test both upgrade paths:

- empty database → baseline → Milestone 1; and
- verified existing-schema copy → stamp baseline → Milestone 1.

Downgrade testing may remove only the new Milestone 1 tables and must be marked destructive. No downgrade runs automatically in a shared or production environment.

## 13. IKIO seed strategy

The seed is data-driven and backend-owned:

- Store the payload in `seed_data/ikio_research.json`.
- Provide an explicit `scripts/seed_research.py` command.
- Resolve the existing `IKIO` ticker rather than creating or modifying market data.
- Use ticker/ISIN identity for idempotent company creation.
- Give each seeded revision a stable seed version so reruns do not create duplicates.
- Pass seed input through the same validation and command services as administrative writes.
- Never seed CMP; project it from `Ticker.last_price`.
- Include only verified facts with source references.
- Leave unknown management, governance, ownership, forecast, valuation, and document values null or absent rather than inventing content.
- Put document metadata into the common Document Library and link it to IKIO through `DocumentCompanyLink`.
- Do not download or bundle external PDFs as seed assets.

## 14. Testing strategy

The backend currently has no automated test suite. Milestone 1 introduces an isolated test configuration and database without changing production behavior.

### 14.1 Model and validation tests

- Company, ticker, ISIN, and business-group constraints.
- One-row-per-user/product entitlement uniqueness and in-place entitlement updates.
- Ownership ranges and snapshot uniqueness.
- Research, forecast, valuation, and market-plan version invariants.
- Separation of `thesis_invalidation` from price-based `invalidation_level`.
- Optional administrator-supplied forecast EPS persists exactly, may remain null, and is never derived from PAT or share count.
- A `PE` valuation reference line can link to supplied EPS in the same-company forecast fiscal-year line.
- Forecast fiscal-year uniqueness and optional line-level valuation references to same-company forecasts.
- Independent valuation revision streams per company and method.
- `PE`, `EV_EBITDA`, `PB`, `NAV`, `SOTP`, `ASSET_VALUE`, `UNIT_BASED`, and `OTHER` method-specific validation.
- Valuations that legitimately omit PAT, an earnings forecast, or any forecast reference.
- Zero-, one-, and many-line valuation references where permitted by the method, including a unit-based revision that atomically preserves capacity, EV-per-ton, EBITDA-per-ton, and cost-per-ton lines in stable sort order.
- Required metric/value/unit/basis per reference line and acceptance of well-formed new metric and unit slugs without schema changes.
- Reference-line ownership and immutability, unique sort order, mixed forecast and non-forecast lines, and same-company validation for each forecast-linked line.
- Optional enterprise-to-equity bridge fields, signed positive-debt/negative-cash `net_debt`, null bridge fields for equity-value methods, and preservation of administrator-supplied values without formula calculation or automatic net-debt derivation.
- The same forecast revision referenced by several valuation methods without mutation.
- Document state combinations and transition rules.
- Required distribution basis and verification for `APP_DISTRIBUTABLE`.
- Append-only behavior for revisions and document audit events.

### 14.2 Entitlement tests

- Missing, inactive, expired, and revoked entitlement resolves to free.
- Active premium entitlement resolves to premium.
- Administrator research access works without weakening document rights.
- Free responses recursively contain no premium keys, values, snippets, counts, or aggregates.
- Null versus omitted-field behavior is stable.
- Entitlement changes take effect without issuing a new JWT.

### 14.3 Document-rights tests

- `PUBLIC` never implies `APP_DISTRIBUTABLE`.
- `LINK_ONLY` returns no stored file reference.
- Restricted user upload defaults to `PRIVATE_LIBRARY`.
- Private documents and derived data are unavailable to unrelated premium users.
- User-provided private content is available only to its provider and administrators.
- Derived analysis defaults to inherited rights.
- Independently distributable derived analysis requires complete independent rights provenance.
- Multi-source comparisons and consensus use the most restrictive effective rights and reveal no restricted aggregates.
- Rights-sensitive missing resources do not leak their existence through errors.

### 14.4 Deduplication and history tests

- Metadata normalization produces a stable fingerprint.
- Every first-class document type uses the generic fingerprint pipeline and is distinguished by `document_type`.
- Multi-company fingerprints are identical regardless of link order.
- Adding or changing the optional primary company designation does not change the fingerprint.
- Zero-primary multi-company and industry documents are valid; two primary links are rejected.
- Applicable publisher/institution, reporting-period, and institutional report-type components affect the fingerprint deterministically.
- Analyst changes do not change the fingerprint.
- SHA-256 exact duplicate handling.
- Metadata-only duplicate candidates require review.
- Multiple reports from one institution are retained.
- Latest-per-institution query does not delete or hide historical pagination.
- Deduplication never broadens distribution rights.
- Meaningful document changes write the correct old/new audit values in the same transaction.
- Adding a company link recomputes the fingerprint using the complete sorted link set and records `COMPANY_LINKS_CHANGED`.
- A duplicate conflict during company-link addition rolls back the link, fingerprint, and audit event while preserving rights.
- Failed document changes write neither current-state changes nor audit rows.

### 14.5 API and regression tests

- JWT and admin authorization for every endpoint.
- Company list/detail pagination and filtering.
- CMP projection, including unavailable or stale ticker data.
- Disclosure and document collection filtering.
- Important Reg. 30 retrieval returns only `is_key=true` Reg. 30 records, newest first, limited to five with deterministic ties.
- `is_key` defaults to false and has no automated or numeric scoring path.
- Initial Document creation accepts metadata, all initial company links, optional primary designation, and conditional institutional metadata in one request.
- Invalid company links or missing institutional metadata create no partial Document.
- Duplicate detection runs against the final aggregate fingerprint before insertion.
- Document, initial links, institutional metadata, and the final fingerprint commit or roll back together.
- Stale revision conflict behavior.
- Valuation revision headers and all nested reference lines commit or roll back together; invalid ownership, forecast linkage, ordering, metric, unit, value, or basis creates no partial revision.
- Transaction rollback for other invalid nested revisions.
- Seed idempotency and sourced-data validation.
- Existing auth, user, ticker, trade, tag, Telegram, and alert endpoints preserve their status codes and response contracts.
- Websocket and trade evaluation do not import or call research command services.

### 14.6 Migration tests

- Fresh database baseline and upgrade.
- Verified existing-schema stamp and additive upgrade.
- SQLite coverage plus the actual deployment dialect before release.
- Confirmation that no existing table is altered by the Milestone 1 revision.

## 15. Expected implementation file boundaries

This section defines expected implementation shape but does not authorize implementation in this design phase.

### 15.1 Existing backend files likely modified later

- `app/__init__.py`: register consumer and administrative research/document blueprints.
- `app/models/__init__.py`: import new models for SQLAlchemy and Alembic discovery.
- `app/models/user.py`: add ORM relationships only; no existing user column changes.
- `app/utils/error_handlers.py`: add conflict handling while preserving current endpoints.

### 15.2 New backend modules likely created later

- `app/models/company.py`
- `app/models/entitlement.py`
- `app/models/research.py`
- `app/models/ownership.py`
- `app/models/governance.py`
- `app/models/disclosure.py`
- `app/models/market_plan.py`
- `app/models/forecast.py`
- `app/models/valuation.py`
- `app/models/document.py`
- `app/models/institution.py`
- `app/models/institutional_report.py`
- `app/schemas/research.py`
- `app/schemas/admin_research.py`
- `app/schemas/document.py`
- `app/routes/research.py`
- `app/routes/admin_research.py`
- `app/routes/documents.py`
- `app/routes/admin_documents.py`
- `app/services/entitlement_service.py`
- `app/services/research_query_service.py`
- `app/services/research_command_service.py`
- `app/services/market_price_service.py`
- `app/services/document_library_service.py`
- `app/services/document_deduplication_service.py`
- `app/policies/research_access.py`
- `app/policies/document_access.py`
- `scripts/seed_research.py`
- `seed_data/ikio_research.json`
- focused tests under `tests/research/`
- Alembic baseline and additive revision files after database inventory

No frontend application file is part of backend-first Milestone 1. Later frontend integration can add research types, API modules, stores, routes, and navigation after the backend contract is implemented and tested.

## 16. Explicitly out of scope

Milestone 1 excludes:

- forecasting calculations or model generation;
- valuation calculations, discounting, or market-cap calculation;
- multiple valuation engines or method-specific calculation engines;
- automatic enterprise-to-equity bridge calculation, reconciliation, or net-debt derivation;
- detailed SOTP component tables or calculations;
- operating-metric engines or automatic cost-per-unit, EBITDA-per-unit, capacity, NAV, asset-value, or replacement-value calculations;
- quarterly thesis-review workflows;
- Business Pulse;
- 5-minute, 15-minute, or 60-minute technical confirmation;
- indicator computation or automated accumulation-zone generation;
- portfolio holdings, transactions, allocation, or broker synchronization;
- automated Reg. 30 discovery, classification, or significance scoring;
- numeric Reg. 30 importance scoring or automated assignment of `is_key`;
- Telegram channel/feed scanning;
- automated institutional-report discovery;
- automated downloads from public, restricted, Telegram, or other sources;
- file upload, binary storage, download, preview, or sharing endpoints;
- PDF parsing, OCR, extraction, or indexing;
- report summarization or AI-generated research;
- institutional recommendation or estimate extraction;
- institutional/internal thesis comparison;
- automated forecast-review or thesis-review flags;
- institutional consensus and range calculations;
- distribution of restricted or user-provided reports;
- anonymous/public API access;
- multiple listings or securities per company;
- Elasticsearch research indexing;
- a full editorial draft, approval, or publication workflow;
- a generic event store or event-sourced document model;
- physical deletion of revision or audit history;
- frontend research pages or components;
- billing or payment processing;
- entitlement, subscription, or billing-event history;
- cookie/authentication redesign;
- unrelated refactoring; and
- any modification to existing Kite, websocket, trade, alert, Telegram, authentication, or frontend behavior.

## 17. Security and leakage invariants

The following are release-blocking requirements:

1. Premium research values are never sent to a free client.
2. Restricted document metadata never exposes storage locations or private source references.
3. Premium entitlement never grants document distribution rights.
4. Derived institutional content inherits source restrictions unless independent rights are documented and verified.
5. Aggregation, comparison, and consensus cannot be used to infer restricted values.
6. Deduplication cannot merge access scopes in a way that broadens visibility.
7. Audit records contain no file contents, credentials, JWTs, or unnecessary sensitive data.
8. Research code reads CMP through a read-only boundary and does not mutate ticker or trade state.
9. Research failures cannot interrupt the live websocket, trade evaluation, or Telegram notification path.
10. New migrations are additive after a verified baseline and do not rewrite existing tables.

## 18. Acceptance criteria

Milestone 1 implementation is acceptable when:

- the new schema represents every Milestone 1 entity and relationship defined here;
- `QUARTERLY_RESULTS`, `CREDIT_RATING_REPORT`, and `INDUSTRY_REPORT` are first-class document types;
- disclosures support the manually curated `is_key` flag and deterministic latest-five Reg. 30 query;
- fundamental `thesis_invalidation` remains distinct from market-plan `invalidation_level`;
- generic document fingerprints are deterministic across single-company, multi-company, and non-institutional documents while excluding analyst name;
- each user/product pair has at most one mutable entitlement row and a missing row resolves to free;
- initial Document creation validates, fingerprints, deduplicates, and persists metadata, initial company links, and conditional institutional metadata as one atomic aggregate;
- subsequent company-link changes recompute and deduplicate atomically, preserve rights, and produce a focused audit event;
- forecast lines can store optional administrator-supplied EPS, which PE valuation references may use, without share-count storage or automatic EPS calculation;
- valuation revisions support all defined methods without requiring PAT or an internal forecast;
- valuation revisions can store zero, one, or many immutable reference lines as permitted by the method, including multiple simultaneous unit, asset, or balance-sheet inputs;
- valuation reference metrics and units are extensible slugs rather than an exhaustive industry schema;
- optional administrator-supplied enterprise-to-equity bridge snapshots use the documented net-debt sign convention and are never calculated by Milestone 1;
- each valuation method has an independent immutable revision stream, and one forecast can support several methods;
- immutable revision and audit guarantees are enforced;
- all consumer responses are filtered by product entitlement and document rights;
- document provenance, acquisition, distribution, and ingestion remain distinct;
- IKIO can be seeded idempotently without hard-coded frontend content or fabricated research;
- the migration strategy works for both fresh and verified existing databases;
- automated tests prove premium-data and document-rights isolation;
- existing backend API contracts and live-market integrations continue to work; and
- no out-of-scope engine, ingestion workflow, or frontend feature is introduced.
