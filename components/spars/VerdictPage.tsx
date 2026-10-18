'use client';

import * as React from 'react';
import { useResearchStore } from '@/store/researchStore';
import { Badge } from '@/components/ui/badge';
import { Separator } from '@/components/ui/separator';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { Skeleton } from '@/components/ui/skeleton';
import { EmptyState } from '@/components/research/EmptyState';
import { fmtPct, fmtNum, fmtDate } from '@/lib/research-format';
import { CompanyDetail, LockedSection } from '@/types/research';

// Statically inlined by Next.js at build time -- a real production build
// can never evaluate to true, so this can't leak into the production/
// public research experience regardless of which API it's pointed at.
const IS_REVIEW_ENVIRONMENT = process.env.NODE_ENV !== 'production';

function lockedFor(locked: LockedSection[], section: string) {
  return locked.find((item) => item.section === section) ?? null;
}

const GATE_STATUS_VARIANT: Record<
  string,
  'default' | 'destructive' | 'secondary' | 'outline'
> = {
  PASS: 'default',
  FAIL: 'destructive',
  PENDING: 'secondary',
  NOT_APPLICABLE: 'outline',
  WATCH: 'secondary',
};

/**
 * The public-facing company page: one scroll, a sticky price/identity
 * strip, and plain-language sections instead of a tab bar. Unlike
 * CompanyWorkspace (the signed-in Wealth Desk view, left untouched), a
 * PUBLIC-tier viewer never sees a locked/upgrade state here -- only real
 * content, or an honest "not yet available" message. A signed-in FREE/
 * PREMIUM/ADMIN viewer who lands here keeps the exact tiered lock
 * behavior they'd see on the Wealth Desk.
 */
export function VerdictPage({ companyId }: { companyId: string }) {
  const { companyDetails, isLoadingDetail, fetchCompanyDetail } =
    useResearchStore();
  const detail = companyDetails[companyId];

  React.useEffect(() => {
    // Silent: an anonymous visitor hitting an unpublished company is the
    // routine, expected case right now (nothing is published yet) -- not
    // an error worth a toast, just the honest empty state rendered below.
    fetchCompanyDetail(companyId, { silent: true });
  }, [companyId, fetchCompanyDetail]);

  if (isLoadingDetail && !detail) {
    return (
      <div className="mx-auto max-w-3xl space-y-4 px-4 py-10 sm:px-6">
        <Skeleton className="h-14 w-full" />
        <Skeleton className="h-80 w-full" />
      </div>
    );
  }

  if (!detail) {
    // Deliberately a fixed, calm message rather than the raw backend error
    // text -- the backend returns a plain "not found" for an unpublished
    // company (by design, to avoid confirming anything to an anonymous
    // caller), which reads as a technical error rather than the honest,
    // understated "not yet available" this page is meant to show.
    return (
      <div className="mx-auto max-w-3xl px-4 py-16 sm:px-6">
        <EmptyState title="This company's research isn't public yet." />
      </div>
    );
  }

  return <VerdictPageContent detail={detail} />;
}

function VerdictPageContent({ detail }: { detail: CompanyDetail }) {
  const { company, business_group, market_quote, access } = detail;
  const isPublicViewer = access.tier === 'PUBLIC';
  const locked = access.locked_sections;

  const stewardshipHasData =
    !!detail.ownership ||
    !!detail.management ||
    (!!detail.governance &&
      (detail.governance.status !== null || detail.governance.flags.length > 0));

  const marketPlanSectionNeeded =
    !!detail.market_plan || !!lockedFor(locked, 'market_plan');

  return (
    <div className="flex flex-col">
      <div className="sticky top-0 z-10 border-b bg-background/95 py-3 backdrop-blur">
        <div className="mx-auto flex max-w-3xl flex-wrap items-baseline justify-between gap-3 px-4 sm:px-6">
          <div className="flex min-w-0 flex-wrap items-baseline gap-x-3 gap-y-0.5">
            <span className="truncate font-semibold">{company.name}</span>
            <span className="whitespace-nowrap text-xs text-muted-foreground">
              {company.symbol} · {company.exchange}
            </span>
            {IS_REVIEW_ENVIRONMENT && (
              <Badge variant="destructive" className="whitespace-nowrap">
                TEST DATA
              </Badge>
            )}
          </div>
          <div className="text-right">
            <div className="text-sm font-semibold">
              {market_quote.cmp !== null ? fmtNum(String(market_quote.cmp)) : '—'}
            </div>
            <div className="whitespace-nowrap text-[11px] text-muted-foreground">
              {market_quote.as_of ? `as of ${fmtDate(market_quote.as_of)}` : 'No live quote'}
            </div>
          </div>
        </div>
      </div>

      <div className="mx-auto w-full max-w-3xl space-y-8 px-4 py-6 sm:px-6">
        <div className="flex flex-wrap gap-x-6 gap-y-1 text-sm text-muted-foreground">
          {company.sector && (
            <span>
              <span className="font-medium text-foreground">Sector</span> {company.sector}
            </span>
          )}
          {company.industry && (
            <span>
              <span className="font-medium text-foreground">Industry</span> {company.industry}
            </span>
          )}
          {business_group && (
            <span>
              <span className="font-medium text-foreground">Group</span> {business_group.name}
            </span>
          )}
        </div>

        <Separator />

        <Section
          title="The Case"
          isPublicViewer={isPublicViewer}
          lock={lockedFor(locked, 'research')}
          hasData={!!detail.research}
        >
          {detail.research && (
            <TheCase research={detail.research} investmentCase={detail.investment_case} />
          )}
        </Section>

        <Section
          title="Why we believe this"
          isPublicViewer={isPublicViewer}
          lock={lockedFor(locked, 'investment_case')}
          hasData={!!detail.investment_case && detail.investment_case.gate_results.length > 0}
        >
          {detail.investment_case && (
            <WhyWeBelieve
              investmentCase={detail.investment_case}
              thesisInvalidation={detail.research?.thesis_invalidation}
            />
          )}
        </Section>

        <Section
          title="The Numbers"
          isPublicViewer={isPublicViewer}
          lock={lockedFor(locked, 'forecast') ?? lockedFor(locked, 'valuation')}
          hasData={!!detail.forecast || !!(detail.valuations && detail.valuations.length > 0)}
        >
          <TheNumbers forecast={detail.forecast} valuations={detail.valuations} />
        </Section>

        <Section
          title="Stewardship"
          isPublicViewer={isPublicViewer}
          lock={
            lockedFor(locked, 'governance') ??
            lockedFor(locked, 'ownership') ??
            lockedFor(locked, 'management')
          }
          hasData={stewardshipHasData}
        >
          <Stewardship
            governance={detail.governance}
            ownership={detail.ownership}
            management={detail.management}
          />
        </Section>

        {marketPlanSectionNeeded && (
          <Section
            title="Entry zone"
            isPublicViewer={isPublicViewer}
            lock={lockedFor(locked, 'market_plan')}
            hasData={!!detail.market_plan}
          >
            {detail.market_plan && <EntryZone plan={detail.market_plan} />}
          </Section>
        )}
      </div>
    </div>
  );
}

function Section({
  title,
  isPublicViewer,
  lock,
  hasData,
  children,
}: {
  title: string;
  isPublicViewer: boolean;
  lock: LockedSection | null;
  hasData: boolean;
  children?: React.ReactNode;
}) {
  // A PUBLIC (anonymous) viewer never sees a locked/upgrade state here --
  // only real content, or the same honest "not yet available" message
  // used everywhere else. A signed-in viewer's tiered lock is unchanged.
  if (!isPublicViewer && lock) {
    return (
      <section>
        <h2 className="mb-3 text-base font-semibold">{title}</h2>
        <EmptyState title={title} locked requiredTier={lock.required_tier} />
      </section>
    );
  }

  if (!hasData) {
    return (
      <section>
        <h2 className="mb-3 text-base font-semibold">{title}</h2>
        <EmptyState title={title} />
      </section>
    );
  }

  return (
    <section>
      <h2 className="mb-3 text-base font-semibold">{title}</h2>
      {children}
    </section>
  );
}

function TheCase({
  research,
  investmentCase,
}: {
  research: NonNullable<CompanyDetail['research']>;
  investmentCase: CompanyDetail['investment_case'];
}) {
  return (
    <div className="space-y-4">
      <p className="font-serif text-lg italic leading-relaxed text-foreground">
        {research.thesis}
      </p>

      {investmentCase?.expected_return_pct && (
        <div className="flex gap-6">
          <div>
            <div className="text-xs text-muted-foreground">Expected return</div>
            <div className="text-xl font-semibold">
              {fmtPct(investmentCase.expected_return_pct)}
            </div>
          </div>
          {investmentCase.scenario_return_spread && (
            <>
              <div>
                <div className="text-xs text-muted-foreground">Upside</div>
                <div className="text-xl font-semibold text-green-600">
                  {fmtPct(investmentCase.scenario_return_spread.upside_pct)}
                </div>
              </div>
              <div>
                <div className="text-xs text-muted-foreground">Downside</div>
                <div className="text-xl font-semibold text-red-600">
                  {fmtPct(investmentCase.scenario_return_spread.downside_pct)}
                </div>
              </div>
            </>
          )}
        </div>
      )}

      {research.what_is_changing && (
        <div>
          <h4 className="mb-1 text-sm font-semibold">What is changing</h4>
          <p className="whitespace-pre-wrap text-sm text-muted-foreground">
            {research.what_is_changing}
          </p>
        </div>
      )}

      <div className="grid gap-4 sm:grid-cols-2">
        <div>
          <h4 className="mb-2 text-sm font-semibold">Catalysts</h4>
          {research.catalysts.length === 0 ? (
            <p className="text-xs text-muted-foreground">None recorded.</p>
          ) : (
            <ul className="space-y-2">
              {research.catalysts.map((point) => (
                <li key={point.id} className="text-sm">
                  <span className="font-medium">{point.title}</span>
                  {point.detail && (
                    <p className="text-xs text-muted-foreground">{point.detail}</p>
                  )}
                </li>
              ))}
            </ul>
          )}
        </div>
        <div>
          <h4 className="mb-2 text-sm font-semibold">Risks</h4>
          {research.risks.length === 0 ? (
            <p className="text-xs text-muted-foreground">None recorded.</p>
          ) : (
            <ul className="space-y-2">
              {research.risks.map((point) => (
                <li key={point.id} className="text-sm">
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
    </div>
  );
}

function WhyWeBelieve({
  investmentCase,
  thesisInvalidation,
}: {
  investmentCase: NonNullable<CompanyDetail['investment_case']>;
  thesisInvalidation?: string | null;
}) {
  const hasInvalidation = thesisInvalidation || investmentCase.kill_switches.length > 0;

  return (
    <div className="space-y-4">
      {investmentCase.gate_results.length === 0 ? (
        <p className="text-sm text-muted-foreground">No assessment recorded yet.</p>
      ) : (
        <div className="overflow-x-auto">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Check</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Rationale</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {investmentCase.gate_results.map((gate) => (
                <TableRow key={gate.gate}>
                  <TableCell className="font-medium">
                    {gate.gate.replace(/_/g, ' ')}
                  </TableCell>
                  <TableCell>
                    <Badge variant={GATE_STATUS_VARIANT[gate.status] ?? 'outline'}>
                      {gate.status}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-sm text-muted-foreground">
                    {gate.rationale}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      )}

      {hasInvalidation && (
        <div>
          <h4 className="mb-2 text-sm font-semibold">What would change our mind</h4>
          {thesisInvalidation && (
            <p className="mb-2 whitespace-pre-wrap text-sm text-muted-foreground">
              {thesisInvalidation}
            </p>
          )}
          {investmentCase.kill_switches.length > 0 && (
            <ul className="space-y-2">
              {investmentCase.kill_switches.map((ks, idx) => (
                <li key={idx} className="rounded-lg border p-3">
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-sm font-medium">{ks.condition}</span>
                    {ks.triggered_at ? (
                      <Badge variant="destructive">Triggered {fmtDate(ks.triggered_at)}</Badge>
                    ) : (
                      <Badge variant="outline">Watching</Badge>
                    )}
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
    </div>
  );
}

function TheNumbers({
  forecast,
  valuations,
}: {
  forecast: CompanyDetail['forecast'];
  valuations: CompanyDetail['valuations'];
}) {
  return (
    <div className="space-y-4">
      {forecast && (
        <div>
          <h4 className="mb-2 text-sm font-semibold">Forecast</h4>
          {forecast.assumptions && (
            <p className="mb-3 text-sm text-muted-foreground">{forecast.assumptions}</p>
          )}
          <div className="overflow-x-auto">
            <Table>
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
                {forecast.lines.map((line) => (
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
                    <TableCell>{fmtNum(line.ebitda, line.unit)}</TableCell>
                    <TableCell>{fmtNum(line.pat, line.unit)}</TableCell>
                    <TableCell>{fmtNum(line.eps)}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        </div>
      )}

      {valuations && valuations.length > 0 && (
        <div>
          <h4 className="mb-2 text-sm font-semibold">Valuation</h4>
          <div className="space-y-3">
            {valuations.map((val) => (
              <div key={val.valuation_method} className="rounded-lg border p-3">
                <div className="flex items-center justify-between">
                  <span className="font-medium">{val.valuation_method}</span>
                  <span className="text-xs text-muted-foreground">
                    as of {fmtDate(val.as_of_date)}
                  </span>
                </div>
                <div className="mt-2 grid gap-2 text-sm sm:grid-cols-3">
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
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

function Stewardship({
  governance,
  ownership,
  management,
}: {
  governance: CompanyDetail['governance'];
  ownership: CompanyDetail['ownership'];
  management: CompanyDetail['management'];
}) {
  return (
    <div className="space-y-4">
      {management && (
        <div>
          <div className="mb-1 flex items-center justify-between">
            <h4 className="text-sm font-semibold">Management quality</h4>
            <Badge variant="outline">{management.quality}</Badge>
          </div>
          {management.summary && <p className="text-sm">{management.summary}</p>}
        </div>
      )}

      {ownership && (
        <div className="grid gap-4 sm:grid-cols-2">
          <div>
            <div className="text-xs text-muted-foreground">Promoter holding</div>
            <div className="text-lg font-semibold">
              {fmtPct(ownership.promoter_holding_pct)}
            </div>
          </div>
          <div>
            <div className="text-xs text-muted-foreground">Promoter pledge</div>
            <div className="text-lg font-semibold">
              {fmtPct(ownership.promoter_pledge_pct)}
            </div>
          </div>
        </div>
      )}

      {governance && governance.flags.length > 0 && (
        <div>
          <h4 className="mb-2 text-sm font-semibold">Governance</h4>
          <ul className="space-y-2">
            {governance.flags.map((flag) => (
              <li key={flag.id} className="rounded-lg border p-3">
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
                <p className="mt-1 text-xs text-muted-foreground">{flag.factual_evidence}</p>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}

function EntryZone({ plan }: { plan: NonNullable<CompanyDetail['market_plan']> }) {
  return (
    <div className="space-y-3">
      <div className="grid gap-4 sm:grid-cols-3">
        <div>
          <div className="text-xs text-muted-foreground">Accumulation range</div>
          <div className="text-sm font-semibold">
            {fmtNum(plan.accumulation_low, plan.currency)} –{' '}
            {fmtNum(plan.accumulation_high, plan.currency)}
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
      {plan.rationale && <p className="text-sm text-muted-foreground">{plan.rationale}</p>}
    </div>
  );
}
