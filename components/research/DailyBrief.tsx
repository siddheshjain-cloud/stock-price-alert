'use client';

import * as React from 'react';
import Link from 'next/link';
import { Radio } from 'lucide-react';
import { useResearchStore } from '@/store/researchStore';
import { useAlertsStore } from '@/store/alertsStore';
import { useAuthStore } from '@/store/authStore';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';

const SEVERITY_VARIANT: Record<string, 'default' | 'destructive' | 'secondary' | 'outline'> = {
  INFO: 'outline',
  WATCH: 'secondary',
  CRITICAL: 'destructive',
};

function fmtWhen(value: string) {
  try {
    return new Date(value).toLocaleString('en-IN', {
      month: 'short',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
    });
  } catch {
    return value;
  }
}

/**
 * Daily Brief: alert-first, per the agreed design. The feed below reads
 * from GET /admin/alerts -- a small, additive, read-only backend endpoint
 * added specifically for this page (reuses AlertService exactly as every
 * other I3AS alert producer does; no new write path, no interpretation).
 * It is admin-only on the backend, so a non-admin viewer is told that
 * honestly rather than shown a confusing 403.
 */
export function DailyBrief() {
  const { companyList, isLoadingList, fetchCompanies } = useResearchStore();
  const { recentEvents, isLoading: isLoadingAlerts, fetchRecentEvents } = useAlertsStore();
  const { user } = useAuthStore();
  const isAdmin = !!user?.is_admin;

  React.useEffect(() => {
    fetchCompanies({ per_page: 5 });
  }, [fetchCompanies]);

  React.useEffect(() => {
    if (isAdmin) {
      fetchRecentEvents(20);
    }
  }, [isAdmin, fetchRecentEvents]);

  return (
    <div className="space-y-6">
      {!isAdmin ? (
        <Card className="border-dashed">
          <CardHeader>
            <div className="flex items-center gap-2">
              <Radio className="size-4 text-muted-foreground" />
              <CardTitle className="text-base">Alert feed is admin-only</CardTitle>
            </div>
            <CardDescription>
              The live alert feed (new filings, kill switches, governance flags, and more) is
              currently only shown to admin accounts. This page instead shows the research
              universe as it stands.
            </CardDescription>
          </CardHeader>
        </Card>
      ) : (
        <Card>
          <CardHeader>
            <div className="flex items-center gap-2">
              <Radio className="size-4" />
              <CardTitle className="text-base">Recent alerts</CardTitle>
            </div>
            <CardDescription>
              Every alert-worthy occurrence SPA has recorded recently, newest first.
            </CardDescription>
          </CardHeader>
          <CardContent>
            {isLoadingAlerts && !recentEvents ? (
              <div className="space-y-2">
                <Skeleton className="h-10 w-full" />
                <Skeleton className="h-10 w-full" />
              </div>
            ) : !recentEvents || recentEvents.length === 0 ? (
              <p className="text-sm text-muted-foreground">
                No alerts have been recorded yet.
              </p>
            ) : (
              <ul className="divide-y">
                {recentEvents.map((event) => {
                  const row = (
                    <div className="flex items-start justify-between gap-4 py-3">
                      <div>
                        <div className="flex items-center gap-2">
                          <Badge variant={SEVERITY_VARIANT[event.severity] ?? 'outline'}>
                            {event.severity}
                          </Badge>
                          <span className="text-sm font-medium">
                            {event.event_type.replace(/_/g, ' ')}
                          </span>
                        </div>
                        <p className="text-sm text-muted-foreground mt-1">{event.summary}</p>
                      </div>
                      <span className="text-xs text-muted-foreground whitespace-nowrap">
                        {fmtWhen(event.occurred_at)}
                      </span>
                    </div>
                  );
                  return (
                    <li key={event.id}>
                      {event.company_id ? (
                        <Link
                          href={`/research/${event.company_id}`}
                          className="block hover:bg-muted/50 rounded-md px-2 -mx-2"
                        >
                          {row}
                        </Link>
                      ) : (
                        row
                      )}
                    </li>
                  );
                })}
              </ul>
            )}
          </CardContent>
        </Card>
      )}

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Research universe</CardTitle>
        </CardHeader>
        <CardContent>
          {isLoadingList && !companyList ? (
            <Skeleton className="h-6 w-48" />
          ) : (
            <div className="flex items-center justify-between">
              <div>
                <div className="text-2xl font-semibold">
                  {companyList?.total_items ?? 0}
                </div>
                <div className="text-sm text-muted-foreground">companies currently covered</div>
              </div>
              <Button asChild>
                <Link href="/research/coverage">Open Investment Coverage</Link>
              </Button>
            </div>
          )}
        </CardContent>
      </Card>

      {companyList && companyList.items.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Recently in coverage</CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="divide-y">
              {companyList.items.map((item) => (
                <li key={item.company.id} className="py-2">
                  <Link
                    href={`/research/${item.company.id}`}
                    className="flex items-center justify-between hover:underline"
                  >
                    <span className="text-sm font-medium">{item.company.name}</span>
                    <span className="text-xs text-muted-foreground">
                      {item.company.symbol}
                    </span>
                  </Link>
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
