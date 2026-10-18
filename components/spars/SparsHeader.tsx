'use client';

import * as React from 'react';
import Link from 'next/link';
import { Briefcase, ChevronDown, LogOut, Settings } from 'lucide-react';

import { Button } from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { useAuthContext } from '@/components/providers/AuthProvider';
import { Skeleton } from '@/components/ui/skeleton';
import { cn } from '@/lib/utils';

export function SparsHeader({ showLogo = true }: { showLogo?: boolean }) {
  const { isAuthenticated, isLoading, user, logout } = useAuthContext();
  const [hasMounted, setHasMounted] = React.useState(false);

  React.useEffect(() => {
    setHasMounted(true);
  }, []);

  // True only once mounted on the client AND the auth check has actually
  // finished -- My Desk is gated on this, never on isAuthenticated alone,
  // so it can't flash into view before we genuinely know the viewer is
  // signed in.
  const authResolved = hasMounted && !isLoading;

  return (
    <header className="flex items-center justify-between gap-4 px-4 py-4 sm:px-8">
      <Link
        href="/"
        aria-hidden={!showLogo || undefined}
        className={cn(
          'text-lg font-bold tracking-[0.06em] text-foreground',
          !showLogo && 'invisible'
        )}
      >
        SPARS
      </Link>
      <nav className="flex items-center gap-2 sm:gap-5">
        {/* Visible from the tablet breakpoint up, for every viewer --
            mobile drops it regardless of auth state, per spec. */}
        <Link
          href="/research/coverage"
          className="hidden rounded-sm text-sm font-medium tracking-tight text-muted-foreground outline-none transition-colors hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 md:inline-flex"
        >
          Explore Research
        </Link>

        {authResolved && isAuthenticated && (
          <Button variant="outline" size="lg" className="px-3 sm:px-6" asChild>
            <Link href="/research">
              <Briefcase className="size-4" aria-hidden />
              My Desk
            </Link>
          </Button>
        )}

        {!authResolved ? (
          <Skeleton className="h-10 w-20 rounded-md" />
        ) : isAuthenticated ? (
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="outline" size="lg" className="px-3 sm:px-6">
                {user?.name?.split(' ')[0] ?? 'Account'}
                <ChevronDown className="size-3.5 opacity-60" aria-hidden />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem asChild>
                <Link href="/settings">
                  <Settings className="size-4" />
                  Settings
                </Link>
              </DropdownMenuItem>
              <DropdownMenuSeparator />
              <DropdownMenuItem onClick={logout} className="text-destructive">
                <LogOut className="size-4" />
                Sign Out
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        ) : (
          <Button size="lg" className="px-3 sm:px-6" asChild>
            <Link href="/auth/signin">Sign In</Link>
          </Button>
        )}
      </nav>
    </header>
  );
}
