'use client';

import * as React from 'react';
import Link from 'next/link';

import { Button } from '@/components/ui/button';
import { useAuthContext } from '@/components/providers/AuthProvider';
import { CompanySearch } from '@/components/spars/CompanySearch';
import { Skeleton } from '@/components/ui/skeleton';

export function SparsLanding() {
  const { isAuthenticated, isLoading, user } = useAuthContext();
  const [hasMounted, setHasMounted] = React.useState(false);

  React.useEffect(() => {
    setHasMounted(true);
  }, []);

  const showAuthPlaceholder = !hasMounted || isLoading;

  return (
    <div className="flex min-h-screen flex-col bg-background">
      <header className="flex items-center justify-between gap-4 px-4 py-4 sm:px-8">
        <Link
          href="/"
          className="text-lg font-semibold tracking-[0.28em] text-foreground"
        >
          SPARS
        </Link>
        <nav className="flex items-center gap-1 sm:gap-2">
          <Button variant="ghost" size="sm" className="text-muted-foreground" asChild>
            <Link href="/research/coverage">Research</Link>
          </Button>
          <Button variant="ghost" size="sm" className="text-muted-foreground" asChild>
            <Link href="/research">My Desk</Link>
          </Button>
          {showAuthPlaceholder ? (
            <Skeleton className="h-8 w-16 rounded-md" />
          ) : isAuthenticated ? (
            <Button variant="ghost" size="sm" asChild>
              <Link href="/settings">{user?.name?.split(' ')[0] ?? 'Account'}</Link>
            </Button>
          ) : (
            <Button size="sm" asChild>
              <Link href="/auth/signin">Sign In</Link>
            </Button>
          )}
        </nav>
      </header>

      <main className="flex flex-1 flex-col items-center px-4 pb-24 pt-16 sm:pt-28">
        <h1 className="text-5xl font-semibold tracking-[0.35em] sm:text-7xl">
          SPARS
        </h1>
        <p className="mt-5 max-w-md text-center text-sm text-muted-foreground sm:text-base">
          Search the research universe. Open a company when you are signed in.
        </p>
        <div className="mt-10 w-full max-w-xl">
          <CompanySearch />
        </div>
      </main>
    </div>
  );
}
