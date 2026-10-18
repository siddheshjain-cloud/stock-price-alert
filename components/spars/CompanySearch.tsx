'use client';

import * as React from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { Search } from 'lucide-react';
import { AxiosError } from 'axios';

import { researchApi } from '@/lib/api/research';
import { useAuthContext } from '@/components/providers/AuthProvider';
import { cn } from '@/lib/utils';
import type { CompanyListSummary } from '@/types/research';

const MIN_QUERY_LENGTH = 2;
const SEARCH_DEBOUNCE_MS = 300;

export function CompanySearch() {
  const router = useRouter();
  const { isAuthenticated, isLoading: isAuthLoading } = useAuthContext();
  const [query, setQuery] = React.useState('');
  const [results, setResults] = React.useState<CompanyListSummary[]>([]);
  const [isSearching, setIsSearching] = React.useState(false);
  const [searchError, setSearchError] = React.useState<string | null>(null);
  const [isOpen, setIsOpen] = React.useState(false);
  const [activeIndex, setActiveIndex] = React.useState(-1);
  const containerRef = React.useRef<HTMLDivElement>(null);

  const trimmedQuery = query.trim();
  const showPanel = isOpen && trimmedQuery.length > 0;

  React.useEffect(() => {
    function handlePointerDown(event: MouseEvent) {
      if (!containerRef.current?.contains(event.target as Node)) {
        setIsOpen(false);
        setActiveIndex(-1);
      }
    }

    document.addEventListener('mousedown', handlePointerDown);
    return () => document.removeEventListener('mousedown', handlePointerDown);
  }, []);

  React.useEffect(() => {
    if (!isAuthenticated || trimmedQuery.length < MIN_QUERY_LENGTH) {
      setResults([]);
      setIsSearching(false);
      setSearchError(null);
      setActiveIndex(-1);
      return;
    }

    const controller = new AbortController();
    const handle = window.setTimeout(async () => {
      setIsSearching(true);
      setSearchError(null);
      try {
        const page = await researchApi.listCompanies({
          q: trimmedQuery,
          per_page: 8,
        });
        if (!controller.signal.aborted) {
          setResults(page.items);
          setActiveIndex(page.items.length > 0 ? 0 : -1);
        }
      } catch (error) {
        if (controller.signal.aborted) return;
        const axiosError = error as AxiosError<{ error?: string }>;
        setResults([]);
        setSearchError(
          axiosError.response?.data?.error || 'Unable to search companies right now.'
        );
      } finally {
        if (!controller.signal.aborted) {
          setIsSearching(false);
        }
      }
    }, SEARCH_DEBOUNCE_MS);

    return () => {
      controller.abort();
      window.clearTimeout(handle);
    };
  }, [isAuthenticated, trimmedQuery]);

  const openCompany = React.useCallback(
    (companyId: string) => {
      setIsOpen(false);
      router.push(`/research/${companyId}`);
    },
    [router]
  );

  const handleKeyDown = (event: React.KeyboardEvent<HTMLInputElement>) => {
    if (!showPanel) return;

    if (event.key === 'Escape') {
      event.preventDefault();
      setIsOpen(false);
      setActiveIndex(-1);
      return;
    }

    if (!isAuthenticated || results.length === 0) return;

    if (event.key === 'ArrowDown') {
      event.preventDefault();
      setActiveIndex((current) =>
        current < results.length - 1 ? current + 1 : 0
      );
    } else if (event.key === 'ArrowUp') {
      event.preventDefault();
      setActiveIndex((current) =>
        current > 0 ? current - 1 : results.length - 1
      );
    } else if (event.key === 'Enter' && activeIndex >= 0) {
      event.preventDefault();
      openCompany(results[activeIndex].company.id);
    }
  };

  return (
    <div ref={containerRef} className="relative w-full">
      <label htmlFor="spars-company-search" className="sr-only">
        Search companies
      </label>
      <div
        className={cn(
          'flex h-14 items-center gap-3 rounded-full border bg-card px-5 shadow-lg shadow-black/5',
          'transition-[box-shadow,border-color]',
          'focus-within:border-ring focus-within:ring-ring/40 focus-within:ring-[3px]'
        )}
      >
        <Search className="size-5 shrink-0 text-muted-foreground" aria-hidden />
        <input
          id="spars-company-search"
          type="search"
          autoComplete="off"
          spellCheck={false}
          value={query}
          onChange={(event) => {
            setQuery(event.target.value);
            setIsOpen(true);
          }}
          onFocus={() => setIsOpen(true)}
          onKeyDown={handleKeyDown}
          placeholder="Search companies by name or symbol"
          className="h-full w-full bg-transparent text-base outline-none placeholder:text-muted-foreground"
          role="combobox"
          aria-expanded={showPanel}
          aria-controls="spars-company-search-list"
          aria-autocomplete="list"
        />
      </div>

      {showPanel && (
        <div
          id="spars-company-search-list"
          role="listbox"
          className="absolute z-20 mt-2 w-full overflow-hidden rounded-2xl border bg-popover text-popover-foreground shadow-xl"
        >
          {isAuthLoading ? (
            <p className="px-4 py-6 text-center text-sm text-muted-foreground">
              Checking your session…
            </p>
          ) : !isAuthenticated ? (
            <div className="space-y-3 px-4 py-5 text-center">
              <p className="text-sm text-muted-foreground">
                Sign in to search the SPARS research universe.
              </p>
              <Link
                href="/auth/signin"
                className="inline-flex h-9 items-center justify-center rounded-md bg-primary px-4 text-sm font-medium text-primary-foreground hover:bg-primary/90"
                onClick={() => {
                  sessionStorage.setItem('redirectAfterLogin', '/');
                }}
              >
                Sign In
              </Link>
            </div>
          ) : trimmedQuery.length < MIN_QUERY_LENGTH ? (
            <p className="px-4 py-6 text-center text-sm text-muted-foreground">
              Type at least {MIN_QUERY_LENGTH} characters to search.
            </p>
          ) : isSearching ? (
            <p className="px-4 py-6 text-center text-sm text-muted-foreground">
              Searching…
            </p>
          ) : searchError ? (
            <p className="px-4 py-6 text-center text-sm text-muted-foreground">
              {searchError}
            </p>
          ) : results.length === 0 ? (
            <p className="px-4 py-6 text-center text-sm text-muted-foreground">
              No companies match this search.
            </p>
          ) : (
            <ul className="max-h-80 overflow-y-auto py-1">
              {results.map((item, index) => (
                <li key={item.company.id}>
                  <button
                    type="button"
                    role="option"
                    aria-selected={index === activeIndex}
                    className={cn(
                      'flex w-full items-center justify-between gap-3 px-4 py-3 text-left',
                      index === activeIndex
                        ? 'bg-accent text-accent-foreground'
                        : 'hover:bg-accent/60'
                    )}
                    onMouseEnter={() => setActiveIndex(index)}
                    onClick={() => openCompany(item.company.id)}
                  >
                    <span className="min-w-0">
                      <span className="block truncate text-sm font-medium">
                        {item.company.name}
                      </span>
                      <span className="block truncate text-xs text-muted-foreground">
                        {item.company.symbol} · {item.company.exchange}
                        {item.company.sector ? ` · ${item.company.sector}` : ''}
                      </span>
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
    </div>
  );
}
