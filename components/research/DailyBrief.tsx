'use client';

import * as React from 'react';
import Link from 'next/link';
import { Radio } from 'lucide-react';
import { useResearchStore } from '@/store/researchStore';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';

/**
 * Provisional Daily Brief. The agreed design is alert-first (new filings,
 * material research changes surfaced here first) -- but no HTTP route
 * exists yet for I3AS's AlertEvent feed (confirmed by reading the backend
 * routes directly; see the Codebase Registry's "known gaps"). Building a
 * live feed here would mean inventing data. Instead this honestly says so,
 * and surfaces the one thing that is genuinely real and already available:
 * the current size of the research universe, with a path into it.
 */
export function DailyBrief() {
  const { companyList, isLoadingList, fetchCompanies } = useResearchStore();

  React.useEffect(() => {
    fetchCompanies({ per_page: 5 });
  }, [fetchCompanies]);

  return (
    <div className="space-y-6">
      <Card className="border-dashed">
        <CardHeader>
          <div className="flex items-center gap-2">
            <Radio className="size-4 text-muted-foreground" />
            <CardTitle className="text-base">Live alert feed not yet connected</CardTitle>
          </div>
          <CardDescription>
            This Daily Brief is designed to lead with new filings and material research
            changes as they happen. That live feed is not wired up yet -- it needs a small
            backend read endpoint that does not exist today. Until then, this page shows the
            research universe as it currently stands rather than inventing activity that
            did not happen.
          </CardDescription>
        </CardHeader>
      </Card>

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
