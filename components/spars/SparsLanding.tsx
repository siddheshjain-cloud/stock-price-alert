'use client';

import { CompanySearch } from '@/components/spars/CompanySearch';
import { SparsHeader } from '@/components/spars/SparsHeader';

export function SparsLanding() {
  return (
    <div className="flex min-h-screen flex-col bg-background">
      <SparsHeader showLogo={false} />

      <main className="flex flex-1 flex-col items-center px-4 pb-24 pt-16 sm:pt-28">
        <h1 className="text-5xl font-bold tracking-[0.08em] text-foreground sm:text-7xl">
          SPARS
        </h1>
        <p className="mt-5 max-w-md text-center text-sm text-muted-foreground sm:text-base">
          Research Deeply. Invest Intelligently.
        </p>
        <div className="mt-10 w-full max-w-xl">
          <CompanySearch />
        </div>
      </main>
    </div>
  );
}
