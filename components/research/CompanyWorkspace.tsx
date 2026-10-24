'use client';

import * as React from 'react';
import {
  Bar,
  BarChart,
  CartesianGrid,
  ReferenceLine,
  XAxis,
  YAxis,
} from 'recharts';
import { Info, TrendingDown, TrendingUp } from 'lucide-react';

import { useResearchStore } from '@/store/researchStore';
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Separator } from '@/components/ui/separator';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import {
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
  type ChartConfig,
} from '@/components/ui/chart';
import { Skeleton } from '@/components/ui/skeleton';
import { EmptyState } from '@/components/research/EmptyState';
import { CompanyDetail, ForecastLine, LockedSection, Valuation } from '@/types/research';
import { cn } from '@/lib/utils';
import { fmtPct, fmtNum, fmtDate } from '@/lib/research-format';

function lockedFor(locked: LockedSection[], section: string) {
  return locked.find((item) => item.section === section) ?? null;
}

function toNum(value: string | null | undefined): number | null {
  if (value === null || value === undefined) return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

// -----------------------------------------------------------------------
// Shared status-color system -- one place all PASS/WATCH/FAIL-shaped
// signals (gates, governance, view) draw from, so a color always means
// the same thing anywhere on the page.
// -----------------------------------------------------------------------
const STATUS_TONE = {
  good: 'border-emerald-600/30 bg-emerald-50 text-emerald-700 dark:border-emerald-400/30 dark:bg-emerald-950/30 dark:text-emerald-400',
  watch:
    'border-amber-600/30 bg-amber-50 text-amber-700 dark:border-amber-400/30 dark:bg-amber-950/30 dark:text-amber-400',
  bad: 'border-red-600/30 bg-red-50 text-red-700 dark:border-red-400/30 dark:bg-red-950/30 dark:text-red-400',
  neutral:
    'border-blue-600/30 bg-blue-50 text-blue-700 dark:border-blue-400/30 dark:bg-blue-950/30 dark:text-blue-400',
  muted: 'border-border bg-muted text-muted-foreground',
} as const;

const STATUS_DOT = {
  good: 'bg-emerald-500',
  watch: 'bg-amber-500',
  bad: 'bg-red-500',
  neutral: 'bg-blue-500',
  muted: 'bg-muted-foreground/40',
} as const;

type Tone = keyof typeof STATUS_TONE;

const GATE_TONE: Record<string, Tone> = {
  PASS: 'good',
  FAIL: 'bad',
  WATCH: 'watch',
  PENDING: 'watch',
  NOT_APPLICABLE: 'muted',
};

const VIEW_TONE: Record<string, Tone> = {
  ADD: 'good',
  HOLD: 'neutral',
  DO_NOT_ADD: 'watch',
  REDUCE: 'bad',
  EXIT: 'bad',
};

const GOVERNANCE_TONE: Record<string, Tone> = {
  CLEAR: 'good',
  WATCH: 'watch',
  HIGH_RISK: 'bad',
  UNREVIEWED: 'muted',
};

function StatusBadge({ label, tone }: { label: string; tone: Tone }) {
  return (
    <Badge variant="outline" className={cn('whitespace-nowrap', STATUS_TONE[tone])}>
      {label.replace(/_/g, ' ')}
    </Badge>
  );
}

function StatusDot({ tone }: { tone: Tone }) {
  return <span className={cn('inline-block size-2 shrink-0 rounded-full', STATUS_DOT[tone])} />;
}

// A visually distinct callout for judgment/assumption text, so a reader
// never mistakes a modeled number or a methodology caveat for a
// disclosed fact -- both render identically otherwise.
function AssumptionNote({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex gap-2 rounded-lg border border-amber-600/30 bg-amber-50/70 px-3 py-2 dark:border-amber-400/20 dark:bg-amber-950/20">
      <Info className="mt-0.5 size-3.5 shrink-0 text-amber-700 dark:text-amber-400" />
      <p className="text-xs leading-relaxed text-amber-900 dark:text-amber-300">{children}</p>
    </div>
  );
}

function ScoreTile({
  label,
  value,
  tone,
}: {
  label: string;
  value: React.ReactNode;
  tone?: Tone;
}) {
  return (
    <div className="flex min-w-[7rem] flex-1 flex-col gap-1 rounded-lg border bg-card/50 px-3 py-2.5">
      <span className="text-[11px] font-medium uppercase tracking-wide text-muted-foreground">
        {label}
      </span>
      <div className={cn('text-sm font-semibold', tone && STATUS_TONE[tone].split(' ').find((c) => c.startsWith('text-')))}>
        {value}
      </div>
    </div>
  );
}

export function CompanyWorkspace({ companyId }: { companyId: string }) {
  const { companyDetails, isLoadingDetail, detailError, fetchCompanyDetail } =
    useResearchStore();
  const detail = companyDetails[companyId];

  React.useEffect(() => {
    fetchCompanyDetail(companyId);
  }, [companyId, fetchCompanyDetail]);

  if (isLoadingDetail && !detail) {
    return (
      <div className="space-y-4">
        <Skeleton className="h-28 w-full" />
        <Skeleton className="h-96 w-full" />
      </div>
    );
  }

  if (!detail) {
    return (
      <EmptyState
        title={detailError ?? 'Unable to load this company right now.'}
      />
    );
  }

  return <CompanyWorkspaceContent detail={detail} />;
}

function CompanyWorkspaceContent({ detail }: { detail: CompanyDetail }) {
  const { company, business_group, market_quote, access } = detail;
  const locked = access.locked_sections;
  const ic = lockedFor(locked, 'investment_case') ? null : detail.investment_case;
  const governance = lockedFor(locked, 'governance') ? null : detail.governance;

  const gateCounts = React.useMemo(() => {
    const counts = new Map<string, number>();
    for (const g of ic?.gate_results ?? []) {
      counts.set(g.status, (counts.get(g.status) ?? 0) + 1);
    }
    return Array.from(counts.entries());
  }, [ic]);

  const hasScorecard = !!ic || !!governance?.status;

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader className="pb-4">
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div>
              <div className="flex flex-wrap items-center gap-2">
                <CardTitle className="text-2xl">{company.name}</CardTitle>
                {company.is_demo_data && (
                  <Badge variant="destructive" className="whitespace-nowrap">
                    TEST DATA
                  </Badge>
                )}
              </div>
              <CardDescription>
                {company.symbol} · {company.exchange}
                {business_group ? ` · ${business_group.name}` : ''}
                {company.sector ? ` · ${company.sector}` : ''}
              </CardDescription>
            </div>
            <div className="text-right">
              <div className="text-xl font-semibold">
                {market_quote.cmp !== null ? fmtNum(String(market_quote.cmp)) : '—'}
              </div>
              <div className="text-xs text-muted-foreground">
                {market_quote.as_of
                  ? `as of ${fmtDate(market_quote.as_of)}`
                  : 'No live quote available'}
              </div>
              <Badge variant="outline" className="mt-2">
                {access.tier} access
              </Badge>
            </div>
          </div>
        </CardHeader>

        {hasScorecard && (
          <CardContent className="pt-0">
            <div className="flex flex-wrap gap-2">
              {ic && (
                <ScoreTile
                  label="View"
                  value={<StatusBadge label={ic.view} tone={VIEW_TONE[ic.view] ?? 'muted'} />}
                />
              )}
              {ic && (
                <ScoreTile
                  label="Expected return"
                  value={
                    ic.expected_return_pct ? (
                      <span className="flex items-center gap-1">
                        {Number(ic.expected_return_pct) >= 0 ? (
                          <TrendingUp className="size-3.5 text-emerald-600" />
                        ) : (
                          <TrendingDown className="size-3.5 text-red-600" />
                        )}
                        {fmtPct(ic.expected_return_pct)}
                      </span>
                    ) : (
                      <span className="font-normal text-muted-foreground">Not computed</span>
                    )
                  }
                />
              )}
              {ic && gateCounts.length > 0 && (
                <ScoreTile
                  label="Gate assessment"
                  value={
                    <span className="flex flex-wrap items-center gap-x-2.5 gap-y-1">
                      {gateCounts.map(([status, count]) => (
                        <span key={status} className="flex items-center gap-1">
                          <StatusDot tone={GATE_TONE[status] ?? 'muted'} />
                          {count} {status}
                        </span>
                      ))}
                    </span>
                  }
                />
              )}
              {governance?.status && (
                <ScoreTile
                  label="Governance"
                  value={
                    <StatusBadge
                      label={governance.status}
                      tone={GOVERNANCE_TONE[governance.status] ?? 'muted'}
                    />
                  }
                />
              )}
            </div>
          </CardContent>
        )}
      </Card>

      <Tabs defaultValue="overview" className="w-full">
        <TabsList className="flex-wrap h-auto">
          <TabsTrigger value="overview">Overview</TabsTrigger>
          <TabsTrigger value="financials">Financials</TabsTrigger>
          <TabsTrigger value="governance">Governance &amp; Ownership</TabsTrigger>
          <TabsTrigger value="management">Management</TabsTrigger>
          <TabsTrigger value="market-plan">Market Plan</TabsTrigger>
        </TabsList>

        <TabsContent value="overview" className="pt-4">
          <OverviewTab detail={detail} locked={locked} />
        </TabsContent>
        <TabsContent value="financials" className="pt-4">
          <FinancialsTab detail={detail} locked={locked} />
        </TabsContent>
        <TabsContent value="governance" className="pt-4">
          <GovernanceTab detail={detail} locked={locked} />
        </TabsContent>
        <TabsContent value="management" className="pt-4">
          <ManagementTab detail={detail} locked={locked} />
        </TabsContent>
        <TabsContent value="market-plan" className="pt-4">
          <MarketPlanTab detail={detail} locked={locked} />
        </TabsContent>
      </Tabs>
    </div>
  );
}

// ---------------------------------------------------------------------
// Overview -- thesis, catalysts/risks, and the investment case (gates,
// scenarios, kill switches) in one scroll. These two used to be
// separate tabs; a single buy/hold/sell read shouldn't require a click
// partway through it.
// ---------------------------------------------------------------------
function OverviewTab({
  detail,
  locked,
}: {
  detail: CompanyDetail;
  locked: LockedSection[];
}) {
  const researchLock = lockedFor(locked, 'research');
  const icLock = lockedFor(locked, 'investment_case');
  const research = detail.research;
  const ic = detail.investment_case;

  return (
    <div className="space-y-4">
      {researchLock ? (
        <EmptyState title="Research thesis" locked requiredTier={researchLock.required_tier} />
      ) : !research ? (
        <EmptyState title="Research thesis" />
      ) : (
        <Card>
          <CardHeader>
            <CardTitle className="text-base font-medium text-muted-foreground">
              Why this company (revision {research.revision})
            </CardTitle>
            <CardDescription>{research.why_selected}</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <p className="font-serif text-lg italic leading-relaxed text-foreground">
              {research.thesis}
            </p>
            {research.business_journey && (
              <div>
                <h4 className="text-sm font-semibold mb-1">Business journey</h4>
                <p className="text-sm text-muted-foreground whitespace-pre-wrap">
                  {research.business_journey}
                </p>
              </div>
            )}
            {research.what_is_changing && (
              <div>
                <h4 className="text-sm font-semibold mb-1">What is changing</h4>
                <p className="text-sm text-muted-foreground whitespace-pre-wrap">
                  {research.what_is_changing}
                </p>
              </div>
            )}
            <Separator />
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <h4 className="text-sm font-semibold">Catalysts</h4>
                {research.catalysts.length === 0 ? (
                  <p className="text-xs text-muted-foreground">None recorded.</p>
                ) : (
                  <ul className="space-y-2">
                    {research.catalysts.map((point) => (
                      <li
                        key={point.id}
                        className="rounded-md border-l-2 border-l-emerald-500/60 bg-emerald-500/[0.04] py-1 pl-3 text-sm"
                      >
                        <span className="font-medium">{point.title}</span>
                        {point.detail && (
                          <p className="text-xs text-muted-foreground">{point.detail}</p>
                        )}
                      </li>
                    ))}
                  </ul>
                )}
              </div>
              <div className="space-y-2">
                <h4 className="text-sm font-semibold">Risks</h4>
                {research.risks.length === 0 ? (
                  <p className="text-xs text-muted-foreground">None recorded.</p>
                ) : (
                  <ul className="space-y-2">
                    {research.risks.map((point) => (
                      <li
                        key={point.id}
                        className="rounded-md border-l-2 border-l-amber-500/60 bg-amber-500/[0.04] py-1 pl-3 text-sm"
                      >
                        <span className="font-medium">{point.title}</span>
                        {point.detail && (
                          <p className="text-xs text-muted-foreground">{point.detail}</p>
                        )}
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            </div>
            <Separator />
            <div>
              <h4 className="text-sm font-semibold mb-1">Thesis invalidation</h4>
              <p className="text-sm text-muted-foreground whitespace-pre-wrap">
                {research.thesis_invalidation}
              </p>
            </div>
          </CardContent>
        </Card>
      )}

      {icLock ? (
        <EmptyState title="Investment case" locked requiredTier={icLock.required_tier} />
      ) : !ic ? (
        <EmptyState title="Investment case" />
      ) : (
        <>
          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <CardTitle className="flex items-center gap-2 text-base">
                  <StatusBadge label={ic.view} tone={VIEW_TONE[ic.view] ?? 'muted'} />
                  <span className="font-normal text-muted-foreground">
                    revision {ic.revision_number}
                  </span>
                </CardTitle>
                <Badge variant="outline">{ic.origin}</Badge>
              </div>
              <CardDescription>As of {fmtDate(ic.as_of_date)}</CardDescription>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                Near-term (nearest forward fiscal year)
              </div>
              <div className="flex flex-wrap gap-6">
                <div>
                  <div className="text-xs text-muted-foreground">Expected return</div>
                  <div className="text-xl font-semibold">{fmtPct(ic.expected_return_pct)}</div>
                </div>
                {ic.scenario_return_spread && (
                  <>
                    <div>
                      <div className="text-xs text-muted-foreground">Upside</div>
                      <div className="text-xl font-semibold text-emerald-600">
                        {fmtPct(ic.scenario_return_spread.upside_pct)}
                      </div>
                    </div>
                    <div>
                      <div className="text-xs text-muted-foreground">Downside</div>
                      <div className="text-xl font-semibold text-red-600">
                        {fmtPct(ic.scenario_return_spread.downside_pct)}
                      </div>
                    </div>
                  </>
                )}
              </div>
              {ic.expected_return_basis && (
                <AssumptionNote>{ic.expected_return_basis}</AssumptionNote>
              )}
              {ic.scenario_return_spread && (
                <div className="grid gap-2 sm:grid-cols-3 pt-2">
                  {Object.entries(ic.scenario_return_spread.scenarios).map(([scenario, entry]) => (
                    <div key={scenario} className="rounded-lg border p-3">
                      <div className="text-xs font-medium text-muted-foreground">{scenario}</div>
                      <div className="text-sm font-semibold">
                        {entry ? fmtPct(entry.return_pct) : 'Not computable yet'}
                      </div>
                    </div>
                  ))}
                </div>
              )}

              {ic.long_term_scenario_spread && (
                <>
                  <Separator />
                  <div className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                    Long-term (FY2030E, annualized)
                  </div>
                  <AssumptionNote>
                    Each scenario&apos;s justified multiple is held CONSTANT from the near-term
                    valuation out to FY2030E -- not a prediction that market multiples stay static
                    that far out, but a disclosed simplification isolating the return contribution
                    of earnings growth alone. Annualized (CAGR) over the real elapsed time to
                    FY2030&apos;s fiscal year-end -- unlike the near-term figure above, which is
                    well under a year out and deliberately left un-annualized.
                  </AssumptionNote>
                  <div className="grid gap-2 sm:grid-cols-3 pt-1">
                    {Object.entries(ic.long_term_scenario_spread.scenarios).map(([scenario, entry]) => (
                      <div key={scenario} className="rounded-lg border p-3">
                        <div className="text-xs font-medium text-muted-foreground">
                          {scenario} CAGR
                        </div>
                        <div
                          className={cn(
                            'text-sm font-semibold',
                            entry && entry.cagr_pct && Number(entry.cagr_pct) >= 0
                              ? 'text-emerald-600'
                              : entry && entry.cagr_pct
                                ? 'text-red-600'
                                : undefined
                          )}
                        >
                          {entry ? fmtPct(entry.cagr_pct) : 'Not computable yet'}
                        </div>
                        {entry && (
                          <div className="text-[11px] text-muted-foreground">
                            {entry.horizon_years} yrs to FY{entry.fiscal_year}E
                          </div>
                        )}
                      </div>
                    ))}
                  </div>
                </>
              )}
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="text-base">Nine-gate assessment</CardTitle>
            </CardHeader>
            <CardContent>
              {ic.gate_results.length === 0 ? (
                <p className="text-sm text-muted-foreground">No gate assessments recorded yet.</p>
              ) : (
                <div className="grid gap-2 sm:grid-cols-3">
                  {ic.gate_results.map((gate) => {
                    const tone = GATE_TONE[gate.status] ?? 'muted';
                    return (
                      <div
                        key={gate.gate}
                        className={cn(
                          'rounded-lg border border-l-4 bg-card/50 p-3',
                          STATUS_DOT[tone].replace('bg-', 'border-l-')
                        )}
                      >
                        <div className="flex items-center justify-between gap-2">
                          <span className="text-sm font-medium">
                            {gate.gate.replace(/_/g, ' ')}
                          </span>
                          <StatusBadge label={gate.status} tone={tone} />
                        </div>
                        <p className="mt-1.5 text-xs leading-relaxed text-muted-foreground">
                          {gate.rationale}
                        </p>
                      </div>
                    );
                  })}
                </div>
              )}
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="text-base">Kill switches</CardTitle>
            </CardHeader>
            <CardContent>
              {ic.kill_switches.length === 0 ? (
                <p className="text-sm text-muted-foreground">No kill switches recorded yet.</p>
              ) : (
                <ul className="space-y-2">
                  {ic.kill_switches.map((ks, idx) => (
                    <li key={idx} className="rounded-lg border p-3">
                      <div className="flex items-center justify-between gap-2">
                        <span className="text-sm font-medium">{ks.condition}</span>
                        {ks.triggered_at ? (
                          <Badge variant="destructive">Triggered {fmtDate(ks.triggered_at)}</Badge>
                        ) : (
                          <Badge variant="outline">Watching</Badge>
                        )}
                      </div>
                      {ks.data_source_hint && (
                        <p className="text-xs text-muted-foreground mt-1">{ks.data_source_hint}</p>
                      )}
                    </li>
                  ))}
                </ul>
              )}
            </CardContent>
          </Card>
        </>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------
// Financials -- a forecast bar chart (revenue / EBITDA / PAT per fiscal
// year) over the exact-figures table, and a valuation bar chart
// (implied equity value per method, with current market cap as a
// reference line when one exists) over its own detail table.
// ---------------------------------------------------------------------
const FORECAST_CHART_CONFIG = {
  revenue: { label: 'Revenue', color: 'var(--chart-1)' },
  ebitda: { label: 'EBITDA', color: 'var(--chart-2)' },
  pat: { label: 'PAT', color: 'var(--chart-3)' },
} satisfies ChartConfig;

function buildForecastChartData(lines: ForecastLine[]) {
  return lines
    .slice()
    .sort((a, b) => a.fiscal_year - b.fiscal_year)
    .map((line) => {
      const revenue = toNum(line.revenue);
      const ebitda =
        toNum(line.ebitda) ??
        (revenue !== null && line.ebitda_margin_pct
          ? Math.round(revenue * (toNum(line.ebitda_margin_pct)! / 100))
          : null);
      return {
        fy: `FY${line.fiscal_year}${line.is_estimate ? 'E' : ''}`,
        revenue,
        ebitda,
        pat: toNum(line.pat),
      };
    });
}

const VALUATION_CHART_CONFIG = {
  implied: { label: 'Implied equity value', color: 'var(--chart-1)' },
} satisfies ChartConfig;

// -----------------------------------------------------------------------
// Valuation chart outlier rule (documented, deterministic; chart-scale
// only -- never a data-quality judgment):
//
// A method's implied equity value is flagged an OUTLIER when its
// magnitude is at least OUTLIER_MEDIAN_MULTIPLE times the median
// magnitude of every method's implied value in the set. The median (not
// the mean) is used so that one extreme value can't drag its own
// threshold up and hide itself. Fewer than two non-null values can't
// have a group median, so nothing is ever flagged in that case. Sign is
// ignored (magnitude only) so a large negative value is judged the same
// way as a large positive one, and a zero or negative value is never
// flagged purely for being zero or negative -- only genuine scale
// extremity trips the rule.
//
// This is a statistical scale flag, not a claim the figure is wrong: a
// flagged value is still shown in full, unrounded, next to every other
// method -- it is only left out of the bar chart's own axis domain so
// one outlier can't flatten every other bar into invisibility.
const OUTLIER_MEDIAN_MULTIPLE = 5;

function median(values: number[]): number {
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid];
}

function flagOutliers(impliedValues: (number | null)[]): boolean[] {
  const magnitudes = impliedValues.filter((v): v is number => v !== null).map(Math.abs);
  if (magnitudes.length < 2) return impliedValues.map(() => false);
  const med = median(magnitudes);
  if (med === 0) return impliedValues.map(() => false);
  return impliedValues.map((v) => v !== null && Math.abs(v) / med >= OUTLIER_MEDIAN_MULTIPLE);
}

function buildValuationChartData(valuations: Valuation[]) {
  const implied = valuations.map((v) => toNum(v.implied_future_equity_value));
  const outlierFlags = flagOutliers(implied);
  return valuations.map((v, i) => ({
    method: v.valuation_method,
    implied: implied[i],
    marketCap: toNum(v.current_market_cap),
    isOutlier: outlierFlags[i],
  }));
}

function FinancialsTab({
  detail,
  locked,
}: {
  detail: CompanyDetail;
  locked: LockedSection[];
}) {
  const forecastLock = lockedFor(locked, 'forecast');
  const valuationLock = lockedFor(locked, 'valuation');

  const forecastChartData = detail.forecast ? buildForecastChartData(detail.forecast.lines) : [];
  const valuationChartData =
    detail.valuations && detail.valuations.length > 0
      ? buildValuationChartData(detail.valuations)
      : [];
  const marketCapKnown = valuationChartData.some((d) => d.marketCap !== null);
  const chartableValuations = valuationChartData.filter((d) => !d.isOutlier && d.implied !== null);
  const outlierValuations = valuationChartData.filter((d) => d.isOutlier);

  return (
    <div className="space-y-4">
      <Card>
        <CardHeader>
          <CardTitle className="text-base">Forecast</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          {forecastLock ? (
            <EmptyState title="Forecast" locked requiredTier={forecastLock.required_tier} />
          ) : !detail.forecast ? (
            <EmptyState title="Forecast" />
          ) : (
            <>
              {detail.forecast.assumptions && (
                <AssumptionNote>{detail.forecast.assumptions}</AssumptionNote>
              )}
              {forecastChartData.some((d) => d.revenue !== null) && (
                <ChartContainer config={FORECAST_CHART_CONFIG} className="h-56 w-full">
                  <BarChart data={forecastChartData} barGap={4}>
                    <CartesianGrid vertical={false} />
                    <XAxis dataKey="fy" tickLine={false} axisLine={false} />
                    <YAxis tickLine={false} axisLine={false} width={48} />
                    <ChartTooltip content={<ChartTooltipContent />} />
                    <Bar dataKey="revenue" fill="var(--color-revenue)" radius={3} isAnimationActive={false} />
                    <Bar dataKey="ebitda" fill="var(--color-ebitda)" radius={3} isAnimationActive={false} />
                    <Bar dataKey="pat" fill="var(--color-pat)" radius={3} isAnimationActive={false} />
                  </BarChart>
                </ChartContainer>
              )}
              {/* min-w forces the table to its natural content width so the
                  Table primitive's own overflow-x-auto wrapper actually
                  scrolls on narrow viewports, instead of silently
                  compressing/clipping column text (observed: "EPS" header
                  and decimal values truncated at 390px). */}
              <div className="overflow-x-auto">
                <Table className="min-w-[640px]">
                  <TableHeader>
                    <TableRow>
                      <TableHead>FY</TableHead>
                      <TableHead>Revenue</TableHead>
                      <TableHead>EBITDA</TableHead>
                      <TableHead>PAT</TableHead>
                      <TableHead>EPS</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {detail.forecast.lines.map((line) => (
                      <TableRow key={line.fiscal_year}>
                        <TableCell className="font-medium">
                          FY{line.fiscal_year}
                          {line.is_estimate && (
                            <Badge variant="secondary" className="ml-2">
                              Est.
                            </Badge>
                          )}
                        </TableCell>
                        <TableCell>{fmtNum(line.revenue, line.unit)}</TableCell>
                        <TableCell>
                          {line.ebitda
                            ? fmtNum(line.ebitda, line.unit)
                            : line.ebitda_margin_pct
                              ? `${fmtPct(line.ebitda_margin_pct)} margin`
                              : '—'}
                        </TableCell>
                        <TableCell>{fmtNum(line.pat, line.unit)}</TableCell>
                        <TableCell>{fmtNum(line.eps)}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>
            </>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Valuation</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          {valuationLock ? (
            <EmptyState title="Valuation" locked requiredTier={valuationLock.required_tier} />
          ) : !detail.valuations || detail.valuations.length === 0 ? (
            <EmptyState title="Valuation" />
          ) : (
            <>
              {chartableValuations.length > 0 && (
                <div className="space-y-1.5">
                  <ChartContainer config={VALUATION_CHART_CONFIG} className="h-48 w-full">
                    <BarChart data={chartableValuations} layout="vertical" barSize={28}>
                      <CartesianGrid horizontal={false} />
                      <XAxis type="number" tickLine={false} axisLine={false} />
                      <YAxis
                        type="category"
                        dataKey="method"
                        tickLine={false}
                        axisLine={false}
                        width={90}
                      />
                      <ChartTooltip content={<ChartTooltipContent />} />
                      <Bar dataKey="implied" fill="var(--color-implied)" radius={3} isAnimationActive={false} />
                      {marketCapKnown &&
                        valuationChartData.map((d) =>
                          d.marketCap !== null ? (
                            <ReferenceLine
                              key={d.method}
                              x={d.marketCap}
                              stroke="var(--muted-foreground)"
                              strokeDasharray="4 4"
                            />
                          ) : null
                        )}
                    </BarChart>
                  </ChartContainer>
                  {marketCapKnown && (
                    <p className="text-xs text-muted-foreground">
                      Dashed line marks the current market capitalization.
                    </p>
                  )}
                  {outlierValuations.length > 0 && (
                    <p className="text-xs text-muted-foreground">
                      {outlierValuations.length} method
                      {outlierValuations.length > 1 ? 's' : ''} excluded from this chart&apos;s
                      scale -- see below.
                    </p>
                  )}
                </div>
              )}
              <div className="space-y-3">
                {detail.valuations.map((val) => {
                  const chartRow = valuationChartData.find((d) => d.method === val.valuation_method);
                  const isOutlier = chartRow?.isOutlier ?? false;
                  return (
                    <div
                      key={val.valuation_method}
                      className={cn(
                        'rounded-lg border p-3',
                        isOutlier && 'border-amber-600/30 dark:border-amber-400/30'
                      )}
                    >
                      <div className="flex flex-wrap items-center justify-between gap-2">
                        <span className="flex items-center gap-2 font-medium">
                          {val.valuation_method}
                          {isOutlier && (
                            <Badge
                              variant="outline"
                              className={cn('whitespace-nowrap', STATUS_TONE.watch)}
                            >
                              OUTLIER -- EXCLUDED FROM CHART SCALE
                            </Badge>
                          )}
                        </span>
                        <span className="text-xs text-muted-foreground">
                          as of {fmtDate(val.as_of_date)}
                        </span>
                      </div>
                      <div className="grid gap-2 sm:grid-cols-3 mt-2 text-sm">
                        <div>
                          <div className="text-xs text-muted-foreground">Implied equity value</div>
                          <div>{fmtNum(val.implied_future_equity_value, val.unit)}</div>
                        </div>
                        <div>
                          <div className="text-xs text-muted-foreground">Current market cap</div>
                          <div>{fmtNum(val.current_market_cap, val.unit)}</div>
                        </div>
                        <div>
                          <div className="text-xs text-muted-foreground">Required return</div>
                          <div>{fmtPct(val.required_return_pct)}</div>
                        </div>
                      </div>
                      {isOutlier && (
                        <p className="mt-2 text-xs leading-relaxed text-amber-900 dark:text-amber-300">
                          This value&apos;s magnitude is at least {OUTLIER_MEDIAN_MULTIPLE}&times;
                          the group&apos;s median, so it is flagged a statistical outlier and left
                          out of the chart above to keep the other methods&apos; bars readable.
                          This is a scale flag only, not a claim that the figure is incorrect --
                          the value is shown here exactly as recorded.
                        </p>
                      )}
                      {val.valuation_notes && (
                        <div className="mt-2">
                          <AssumptionNote>{val.valuation_notes}</AssumptionNote>
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            </>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

function GovernanceTab({
  detail,
  locked,
}: {
  detail: CompanyDetail;
  locked: LockedSection[];
}) {
  const govLock = lockedFor(locked, 'governance');
  const ownLock = lockedFor(locked, 'ownership');

  return (
    <div className="space-y-4">
      <Card>
        <CardHeader>
          <CardTitle className="text-base">Governance</CardTitle>
        </CardHeader>
        <CardContent>
          {govLock ? (
            <EmptyState title="Governance" locked requiredTier={govLock.required_tier} />
          ) : !detail.governance ||
            (detail.governance.status === null && detail.governance.flags.length === 0) ? (
            <EmptyState title="Governance" />
          ) : (
            <>
              {detail.governance.status && (
                <StatusBadge
                  label={detail.governance.status}
                  tone={GOVERNANCE_TONE[detail.governance.status] ?? 'muted'}
                />
              )}
              {detail.governance.flags.length === 0 ? (
                <p className="mt-3 text-sm text-muted-foreground">No active governance flags.</p>
              ) : (
                <ul className="mt-3 space-y-2">
                  {detail.governance.flags.map((flag) => (
                    <li
                      key={flag.id}
                      className={cn(
                        'rounded-lg border border-l-4 p-3',
                        flag.severity === 'HIGH' || flag.severity === 'CRITICAL'
                          ? 'border-l-red-500'
                          : 'border-l-amber-500'
                      )}
                    >
                      <div className="flex items-center justify-between gap-2">
                        <span className="text-sm font-medium">{flag.title}</span>
                        <Badge
                          variant={
                            flag.severity === 'HIGH' || flag.severity === 'CRITICAL'
                              ? 'destructive'
                              : 'secondary'
                          }
                        >
                          {flag.severity}
                        </Badge>
                      </div>
                      <p className="text-xs text-muted-foreground mt-1">
                        {flag.factual_evidence}
                      </p>
                    </li>
                  ))}
                </ul>
              )}
            </>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Ownership</CardTitle>
        </CardHeader>
        <CardContent>
          {ownLock ? (
            <EmptyState title="Ownership" locked requiredTier={ownLock.required_tier} />
          ) : !detail.ownership ? (
            <EmptyState title="Ownership" />
          ) : (
            <div className="grid gap-4 sm:grid-cols-2">
              <div>
                <div className="text-xs text-muted-foreground">Promoter holding</div>
                <div className="text-lg font-semibold">
                  {fmtPct(detail.ownership.promoter_holding_pct)}
                </div>
              </div>
              <div>
                <div className="text-xs text-muted-foreground">Promoter pledge</div>
                <div className="text-lg font-semibold">
                  {fmtPct(detail.ownership.promoter_pledge_pct)}
                </div>
              </div>
              <div className="col-span-2 text-xs text-muted-foreground">
                As of {fmtDate(detail.ownership.as_of_date)}
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

function ManagementTab({
  detail,
  locked,
}: {
  detail: CompanyDetail;
  locked: LockedSection[];
}) {
  const lock = lockedFor(locked, 'management');
  if (lock) {
    return <EmptyState title="Management" locked requiredTier={lock.required_tier} />;
  }
  // Same "present but nothing actually recorded" treatment GovernanceTab
  // already gives its own status/flags pair -- an UNASSESSED quality with
  // no summary/rationale/evidence is functionally no record, not content,
  // and previously rendered as a near-blank card instead of this EmptyState.
  if (
    !detail.management ||
    (detail.management.quality === 'UNASSESSED' &&
      !detail.management.summary &&
      !detail.management.rationale &&
      !detail.management.evidence)
  ) {
    return <EmptyState title="Management" />;
  }
  const m = detail.management;
  return (
    <Card>
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle className="text-base">Management quality</CardTitle>
          <Badge variant="outline">{m.quality}</Badge>
        </div>
      </CardHeader>
      <CardContent className="space-y-3">
        {m.summary && <p className="text-sm">{m.summary}</p>}
        {m.rationale && (
          <div>
            <h4 className="text-sm font-semibold mb-1">Rationale</h4>
            <p className="text-sm text-muted-foreground">{m.rationale}</p>
          </div>
        )}
        {m.evidence && (
          <div>
            <h4 className="text-sm font-semibold mb-1">Evidence</h4>
            <p className="text-sm text-muted-foreground">{m.evidence}</p>
          </div>
        )}
      </CardContent>
    </Card>
  );
}

function MarketPlanTab({
  detail,
  locked,
}: {
  detail: CompanyDetail;
  locked: LockedSection[];
}) {
  const lock = lockedFor(locked, 'market_plan');
  if (lock) {
    return <EmptyState title="Market plan" locked requiredTier={lock.required_tier} />;
  }
  if (!detail.market_plan) {
    return <EmptyState title="Market plan" />;
  }
  const plan = detail.market_plan;
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Accumulation plan (revision {plan.revision})</CardTitle>
        <CardDescription>Effective {fmtDate(plan.effective_at)}</CardDescription>
      </CardHeader>
      <CardContent className="space-y-3">
        <div className="grid gap-4 sm:grid-cols-3">
          <div>
            <div className="text-xs text-muted-foreground">Accumulation range</div>
            <div className="text-sm font-semibold">
              {fmtNum(plan.accumulation_low, plan.currency)} – {fmtNum(plan.accumulation_high, plan.currency)}
            </div>
          </div>
          <div>
            <div className="text-xs text-muted-foreground">Preferred price</div>
            <div className="text-sm font-semibold">
              {fmtNum(plan.preferred_accumulation_price, plan.currency)}
            </div>
          </div>
          <div>
            <div className="text-xs text-muted-foreground">Invalidation level</div>
            <div className="text-sm font-semibold">
              {fmtNum(plan.invalidation_level, plan.currency)}
            </div>
          </div>
        </div>
        {plan.rationale && (
          <div>
            <h4 className="text-sm font-semibold mb-1">Rationale</h4>
            <p className="text-sm text-muted-foreground">{plan.rationale}</p>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
