import type { AxiosRequestConfig } from 'axios';
import axiosInstance from '@/lib/axios';
import { CompanyDetail, CompanyListPage, CompanyListParams } from '@/types/research';

export const researchApi = {
  /**
   * List companies in the research universe, with optional search/filter.
   * Entitlement-aware on the backend: FREE and PREMIUM/ADMIN users see the
   * same list shape, since the premium gate applies to detail sections,
   * not list membership.
   */
  listCompanies: async (params: CompanyListParams = {}): Promise<CompanyListPage> => {
    const response = await axiosInstance.get<CompanyListPage>('/research/companies', {
      params,
    });
    return response.data;
  },

  /**
   * One company's full detail projection. The backend returns exactly one
   * explicit schema (FREE/PREMIUM/ADMIN) chosen server-side from the
   * caller's own entitlement -- never a flag the client can influence.
   */
  getCompanyDetail: async (
    companyId: string,
    config?: AxiosRequestConfig
  ): Promise<CompanyDetail> => {
    const response = await axiosInstance.get<CompanyDetail>(
      `/research/companies/${companyId}`,
      config
    );
    return response.data;
  },
};
