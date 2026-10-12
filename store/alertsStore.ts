import { create } from 'zustand';
import { alertsApi } from '@/lib/api/alerts';
import { AlertEvent } from '@/types/alerts';

interface AlertsState {
  recentEvents: AlertEvent[] | null;
  isLoading: boolean;
  error: string | null;

  fetchRecentEvents: (limit?: number) => Promise<void>;
}

export const useAlertsStore = create<AlertsState>((set) => ({
  recentEvents: null,
  isLoading: false,
  error: null,

  fetchRecentEvents: async (limit) => {
    try {
      set({ isLoading: true, error: null });
      const page = await alertsApi.listRecent(limit);
      set({ recentEvents: page.items, isLoading: false });
    } catch (error: any) {
      // Deliberately no toast here -- a 403 for a non-admin viewer is an
      // expected, routine outcome, not an error worth interrupting them
      // over. The component decides what to show.
      const message =
        error?.response?.status === 403
          ? 'admin_only'
          : error?.response?.data?.error || 'Failed to load the alert feed';
      set({ isLoading: false, error: message });
    }
  },
}));
