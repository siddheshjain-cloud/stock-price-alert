'use client';

import { useParams } from 'next/navigation';
import { SparsHeader } from '@/components/spars/SparsHeader';
import { VerdictPage } from '@/components/spars/VerdictPage';

/**
 * The public, no-sign-in-required company page -- what Smart Search opens.
 * Deliberately separate from /research/[companyId] (the signed-in Wealth
 * Desk workspace, untouched): this route carries no AuthGuard, so an
 * anonymous visitor reaches it directly, and the backend's own PUBLIC tier
 * (not this page) decides what they're shown.
 */
export default function PublicCompanyPage() {
  const params = useParams<{ companyId: string }>();

  return (
    <div className="flex min-h-screen flex-col bg-background">
      <SparsHeader />
      <VerdictPage companyId={params.companyId} />
    </div>
  );
}
