'use client';

import { useParams } from 'next/navigation';
import { AppSidebar } from '@/components/layout/app-sidebar';
import { SiteHeader } from '@/components/layout/site-header';
import { SidebarInset, SidebarProvider } from '@/components/ui/sidebar';
import { AuthGuard } from '@/components/auth/AuthGuard';
import { CompanyWorkspace } from '@/components/research/CompanyWorkspace';

export default function CompanyWorkspacePage() {
  const params = useParams<{ companyId: string }>();

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
              <CompanyWorkspace companyId={params.companyId} />
            </div>
          </div>
        </SidebarInset>
      </SidebarProvider>
    </AuthGuard>
  );
}
