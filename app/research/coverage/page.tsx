'use client';

import { AppSidebar } from '@/components/layout/app-sidebar';
import { SiteHeader } from '@/components/layout/site-header';
import { SidebarInset, SidebarProvider } from '@/components/ui/sidebar';
import { AuthGuard } from '@/components/auth/AuthGuard';
import { CoverageGrid } from '@/components/research/CoverageGrid';

export default function CoveragePage() {
  return (
    <AuthGuard requireAuth={true}>
      <SidebarProvider
        style={
          {
            '--sidebar-width': 'calc(var(--spacing) * 72)',
            '--header-height': 'calc(var(--spacing) * 12)',
          } as React.CSSProperties
        }
      >
        <AppSidebar variant="inset" />
        <SidebarInset className="overflow-hidden">
          <SiteHeader />
          <div className="flex flex-1 flex-col">
            <div className="px-4 lg:px-6 space-y-8 py-4 md:py-6">
              <div>
                <h1 className="text-xl font-semibold">Investment Coverage</h1>
                <p className="text-sm text-muted-foreground">
                  Every company currently in SPA&apos;s research universe.
                </p>
              </div>
              <CoverageGrid />
            </div>
          </div>
        </SidebarInset>
      </SidebarProvider>
    </AuthGuard>
  );
}
