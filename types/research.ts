// Types mirroring the backend's explicit, tier-gated company-detail
// projection exactly (app/schemas/research.py, app/schemas/research_consumer.py
// in the backendtest repo). A field only ever appears here if the backend
// schema actually dumps it -- no field is invented or assumed.

export type ResearchTierLabel = 'FREE' | 'PREMIUM' | 'ADMIN';

export interface LockedSection {
  section: string;
  required_tier: string;
}

export interface ResearchAccess {
  tier: ResearchTierLabel;
  locked_sections: LockedSection[];
}

export interface ResearchCompany {
  id: string;
  name: string;
  symbol: string;
  exchange: string;
  isin: string;
  sector: string | null;
  industry: string | null;
}

export interface ResearchBusinessGroup {
  name: string;
}

export interface MarketQuote {
  cmp: number | null;
  as_of: string | null;
}

export interface ResearchPoint {
  id: string;
  kind: string;
  title: string;
  detail: string | null;
  status: string | null;
  target_date: string | null;
  sort_order: number;
}

export interface ResearchNarrative {
  revision: number;
  why_selected: string;
  what_is_changing: string | null;
  business_journey: string | null;
  thesis: string;
  catalysts: ResearchPoint[];
  risks: ResearchPoint[];
  thesis_invalidation: string;
}

export interface ManagementAssessment {
  summary: string | null;
  quality: string;
  rationale: string | null;
  evidence: string | null;
}

export interface GovernanceFlagItem {
  id: string;
  flag_type: string;
  title: string;
  severity: string;
  status: string;
  factual_evidence: string;
  source_title: string | null;
  source_url_or_reference: string;
  interpretation: string;
  observed_on: string | null;
  resolved_on: string | null;
}

export interface Governance {
  // Always present when entitled -- status is null whenever no current
  // research revision exists yet, independent of whether any flags exist.
  status: string | null;
  flags: GovernanceFlagItem[];
}

export interface Ownership {
  as_of_date: string;
  promoter_holding_pct: string | null;
  promoter_pledge_pct: string | null;
  notes: string | null;
  source_reference: string | null;
}

export interface MarketPlan {
  revision: number;
  currency: string;
  accumulation_low: string;
  accumulation_high: string;
  preferred_accumulation_price: string | null;
  supply_low: string | null;
  supply_high: string | null;
  invalidation_level: string;
  rationale: string | null;
  effective_at: string;
}

export interface ForecastLine {
  fiscal_year: number;
  is_estimate: boolean;
  revenue: string | null;
  ebitda: string | null;
  pat: string | null;
  ebitda_margin_pct: string | null;
  eps: string | null;
  currency: string;
  unit: string;
}

export interface Forecast {
  revision: number;
  as_of_date: string;
  assumptions: string | null;
  lines: ForecastLine[];
}

export interface ValuationReferenceLine {
  reference_forecast_revision_id: string | null;
  reference_fiscal_year: number | null;
  reference_metric: string;
  reference_metric_value: string;
  reference_metric_unit: string;
  reference_metric_basis: string;
  sort_order: number;
}

export interface Valuation {
  revision: number;
  valuation_method: string;
  justified_multiple: string | null;
  implied_enterprise_value: string | null;
  net_debt: string | null;
  other_equity_adjustment: string | null;
  implied_future_equity_value: string | null;
  required_return_pct: string | null;
  discount_period_years: string | null;
  present_value: string | null;
  current_market_cap: string | null;
  currency: string | null;
  unit: string | null;
  valuation_notes: string | null;
  as_of_date: string;
  reference_lines: ValuationReferenceLine[];
}

export interface InvestmentCaseGateResult {
  gate: string;
  status: string;
  rationale: string;
  created_at: string;
}

export interface InvestmentCaseKillSwitch {
  condition: string;
  data_source_hint: string | null;
  triggered_at: string | null;
}

export interface ScenarioReturnEntry {
  valuation_revision_id: string | null;
  implied_future_equity_value: string | null;
  current_market_cap: string | null;
  return_pct: string | null;
}

export interface ScenarioReturnSpread {
  scenarios: Record<string, ScenarioReturnEntry | null>;
  upside_pct: string | null;
  downside_pct: string | null;
}

export interface InvestmentCase {
  view: string;
  revision_number: number;
  expected_return_pct: string | null;
  expected_return_basis: string | null;
  as_of_date: string;
  origin: string;
  created_at: string;
  gate_results: InvestmentCaseGateResult[];
  kill_switches: InvestmentCaseKillSwitch[];
  scenario_return_spread: ScenarioReturnSpread | null;
}

// The full company-detail response. Every premium-only field is optional
// AND nullable: absent entirely for FREE tier (the schema never dumps it),
// present-but-null when the section genuinely has no current data for an
// otherwise-entitled viewer. The UI must tell these two states apart --
// never collapse "not entitled" and "no data yet" into the same look.
export interface CompanyDetail {
  company: ResearchCompany;
  business_group: ResearchBusinessGroup | null;
  market_quote: MarketQuote;
  access: ResearchAccess;
  research?: ResearchNarrative | null;
  management?: ManagementAssessment | null;
  governance?: Governance | null;
  ownership?: Ownership | null;
  market_plan?: MarketPlan | null;
  forecast?: Forecast | null;
  valuations?: Valuation[] | null;
  investment_case?: InvestmentCase | null;
}

export interface CompanyListSummary {
  company: ResearchCompany;
  business_group: ResearchBusinessGroup | null;
  market_quote: MarketQuote;
}

export interface CompanyListPage {
  items: CompanyListSummary[];
  page: number;
  per_page: number;
  total_items: number;
  total_pages: number;
}

export interface CompanyListParams {
  q?: string;
  sector?: string;
  industry?: string;
  page?: number;
  per_page?: number;
}
