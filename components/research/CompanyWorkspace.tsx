'use client';

import * as React from 'react';
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
import { Skeleton } from '@/components/ui/skeleton';
import { EmptyState } from '@/components/research/EmptyState';
import { CompanyDetail, LockedSection } from '@/types/research';

function lockedFor(locked: LockedSection[], section: string) {
  return locked.find((item) => item.section === section) ?? null;
}

function fmtPct(value: string | null | undefined) {
  if (value === null || value === undefined) return '—';
  return `${Number(value).toFixed(2)}%`;
}

function fmtNum(value: string | null | undefined, unit?: string | null) {
  if (value === null || value === undefined) return '—';
  const num = Number(value);
  const formatted = Number.isFinite(num) ? num.toLocaleString('en-IN') : value;
  return unit ? `${formatted} ${unit}` : formatted;
}

function fmtDate(value: string | null | undefined) {
  if (!value) return '—';
  try {
    return new Date(value).toLocaleDateString('en-IN', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  } catch {
    return value;
  }
}

const GATE_STATUS_VARIANT: Record<string, 'default' | 'destructive' | 'secondary' | 'outline'> = {
  PASS: 'default',
  FAIL: 'destructive',
  PENDING: 'secondary',
  NOT_APPLICABLE: 'outline',
  WATCH: 'secondary',
};

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
        <Skeleton className="h-24 w-full" />
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

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div>
              <CardTitle className="text-2xl">{company.name}</CardTitle>
              <CardDescription>
                {company.symbol} · {company.exchange}
                {business_group ? ` · ${business_group.name}` : ''}
                {company.sector ? ` · ${company.sector}` : ''}
              </CardDescription>
            </div>
            <div className="text-right">
              <div className="text-2xl font-semibold">
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
      </Card>

      <Tabs defaultValue="overview" className="w-full">
        <TabsList className="flex-wrap h-auto">
          <TabsTrigger value="overview">Overview</TabsTrigger>
          <TabsTrigger value="investment-case">Investment Case</TabsTrigger>
          <TabsTrigger value="financials">Financials</TabsTrigger>
          <TabsTrigger value="governance">Governance &amp; Ownership</TabsTrigger>
          <TabsTrigger value="management">Management</TabsTrigger>
          <TabsTrigger value="market-plan">Market Plan</TabsTrigger>
        </TabsList>

        <TabsContent value="overview" className="pt-4">
          <OverviewTab detail={detail} locked={locked} />
        </TabsContent>
        <TabsContent value="investment-case" className="pt-4">
          <InvestmentCaseTab detail={detail} locked={locked} />
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

function OverviewTab({
  detail,
  locked,
}: {
  detail: CompanyDetail;
  locked: LockedSection[];
}) {
  const lock = lockedFor(locked, 'research');
  if (lock) {
    return <EmptyState title="Research thesis" locked requiredTier={lock.required_tier} />;
  }
  const research = detail.research;
  if (!research) {
    return <EmptyState title="Research thesis" />;
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Why this company (revision {research.revision})</CardTitle>
        <CardDescription>{research.why_selected}</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div>
          <h4 className="text-sm font-semibold mb-1">Thesis</h4>
          <p className="text-sm text-muted-foreground whitespace-pre-wrap">
            {research.thesis}
          </p>
        </div>
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
          <div>
            <h4 className="text-sm font-semibold mb-2">Catalysts</h4>
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
            <h4 className="text-sm font-semibold mb-2">Risks</h4>
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
        <Separator />
        <div>
          <h4 className="text-sm font-semibold mb-1">Thesis invalidation</h4>
          <p className="text-sm text-muted-foreground whitespace-pre-wrap">
            {research.thesis_invalidation}
          </p>
        </div>
      </CardContent>
    </Card>
  );
}

function InvestmentCaseTab({
  detail,
  locked,
}: {
  detail: CompanyDetail;
  locked: LockedSection[];
}) {
  const lock = lockedFor(locked, 'investment_case');
  if (lock) {
    return <EmptyState title="Investment case" locked requiredTier={lock.required_tier} />;
  }
  const ic = detail.investment_case;
  if (!ic) {
    return <EmptyState title="Investment case" />;
  }

  return (
    <div className="space-y-4">
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>
              {ic.view} · revision {ic.revision_number}
            </CardTitle>
            <Badge variant="outline">{ic.origin}</Badge>
          </div>
          <CardDescription>As of {fmtDate(ic.as_of_date)}</CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          <div className="flex gap-6">
            <div>
              <div className="text-xs text-muted-foreground">Expected return</div>
              <div className="text-xl font-semibold">{fmtPct(ic.expected_return_pct)}</div>
              {ic.expected_return_basis && (
                <div className="text-xs text-muted-foreground">{ic.expected_return_basis}</div>
              )}
            </div>
            {ic.scenario_return_spread && (
              <>
                <div>
                  <div className="text-xs text-muted-foreground">Upside</div>
                  <div className="text-xl font-semibold text-green-600">
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
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Gate</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Rationale</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {ic.gate_results.map((gate) => (
                  <TableRow key={gate.gate}>
                    <TableCell className="font-medium">{gate.gate.replace(/_/g, ' ')}</TableCell>
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
    </div>
  );
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

  return (
    <div className="space-y-4">
      <Card>
        <CardHeader>
          <CardTitle className="text-base">Forecast</CardTitle>
        </CardHeader>
        <CardContent>
          {forecastLock ? (
            <EmptyState title="Forecast" locked requiredTier={forecastLock.required_tier} />
          ) : !detail.forecast ? (
            <EmptyState title="Forecast" />
          ) : (
            <>
              {detail.forecast.assumptions && (
                <p className="text-sm text-muted-foreground mb-3">
                  {detail.forecast.assumptions}
                </p>
              )}
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
                      <TableCell>{fmtNum(line.ebitda, line.unit)}</TableCell>
                      <TableCell>{fmtNum(line.pat, line.unit)}</TableCell>
                      <TableCell>{fmtNum(line.eps)}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Valuation</CardTitle>
        </CardHeader>
        <CardContent>
          {valuationLock ? (
            <EmptyState title="Valuation" locked requiredTier={valuationLock.required_tier} />
          ) : !detail.valuations || detail.valuations.length === 0 ? (
            <EmptyState title="Valuation" />
          ) : (
            <div className="space-y-3">
              {detail.valuations.map((val) => (
                <div key={val.valuation_method} className="rounded-lg border p-3">
                  <div className="flex items-center justify-between">
                    <span className="font-medium">{val.valuation_method}</span>
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
                  {val.valuation_notes && (
                    <p className="text-xs text-muted-foreground mt-2">{val.valuation_notes}</p>
                  )}
                </div>
              ))}
            </div>
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
                <Badge variant="outline" className="mb-3">
                  {detail.governance.status}
                </Badge>
              )}
              {detail.governance.flags.length === 0 ? (
                <p className="text-sm text-muted-foreground">No active governance flags.</p>
              ) : (
                <ul className="space-y-2">
                  {detail.governance.flags.map((flag) => (
                    <li key={flag.id} className="rounded-lg border p-3">
                      <div className="flex items-center justify-between gap-2">
                        <span className="text-sm font-medium">{flag.title}</span>
                        <Badge
                          variant={flag.severity === 'HIGH' || flag.severity === 'CRITICAL' ? 'destructive' : 'secondary'}
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
  if (!detail.management) {
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
