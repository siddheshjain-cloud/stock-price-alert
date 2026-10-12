'use client';

import * as React from 'react';
import Link from 'next/link';
import { Search } from 'lucide-react';
import { useResearchStore } from '@/store/researchStore';
import { Input } from '@/components/ui/input';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { EmptyState } from '@/components/research/EmptyState';

export function CoverageGrid() {
  const { companyList, isLoadingList, fetchCompanies } = useResearchStore();
  const [query, setQuery] = React.useState('');

  // Simple debounce -- no new dependency needed for a single search box.
  React.useEffect(() => {
    const handle = setTimeout(() => {
      fetchCompanies({ q: query || undefined, per_page: 50 });
    }, 300);
    return () => clearTimeout(handle);
  }, [query, fetchCompanies]);

  return (
    <div className="space-y-4">
      <div className="relative max-w-sm">
        <Search className="absolute left-2.5 top-2.5 size-4 text-muted-foreground" />
        <Input
          placeholder="Search companies, sector, industry..."
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          className="pl-8"
        />
      </div>

      {isLoadingList && !companyList ? (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: 6 }).map((_, i) => (
            <Skeleton key={i} className="h-32 w-full" />
          ))}
        </div>
      ) : !companyList || companyList.items.length === 0 ? (
        <EmptyState title="No companies match this search." />
      ) : (
        <>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {companyList.items.map((item) => (
              <Link key={item.company.id} href={`/research/${item.company.id}`}>
                <Card className="h-full transition-colors hover:border-primary">
                  <CardHeader>
                    <CardTitle className="text-base">{item.company.name}</CardTitle>
                  </CardHeader>
                  <CardContent className="space-y-1">
                    <div className="text-sm text-muted-foreground">
                      {item.company.symbol} · {item.company.exchange}
                    </div>
                    {item.business_group && (
                      <div className="text-xs text-muted-foreground">
                        {item.business_group.name}
                      </div>
                    )}
                    <div className="flex items-baseline justify-between pt-2">
                      <span className="text-xs text-muted-foreground">
                        {item.company.sector ?? 'Sector unclassified'}
                      </span>
                      <span className="text-sm font-semibold">
                        {item.market_quote.cmp !== null
                          ? item.market_quote.cmp.toLocaleString('en-IN')
                          : '—'}
                      </span>
                    </div>
                  </CardContent>
                </Card>
              </Link>
            ))}
          </div>
          <p className="text-xs text-muted-foreground">
            {companyList.total_items} companies in the research universe.
          </p>
        </>
      )}
    </div>
  );
}
