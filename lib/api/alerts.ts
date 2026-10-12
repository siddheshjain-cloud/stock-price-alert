import axiosInstance from '@/lib/axios';
import { AlertEventList } from '@/types/alerts';

export const alertsApi = {
  /**
   * The admin-only recent alert feed. 403s for a non-admin caller --
   * callers should check the current user's `is_admin` before fetching,
   * rather than relying on this throwing.
   */
  listRecent: async (limit = 20): Promise<AlertEventList> => {
    const response = await axiosInstance.get<AlertEventList>('/admin/alerts', {
      params: { limit },
    });
    return response.data;
  },
};
