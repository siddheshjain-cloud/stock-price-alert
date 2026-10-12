import { create } from 'zustand';
import { toast } from 'sonner';
import { researchApi } from '@/lib/api/research';
import { CompanyDetail, CompanyListPage, CompanyListParams } from '@/types/research';

interface ResearchState {
  companyList: CompanyListPage | null;
  isLoadingList: boolean;
  listError: string | null;

  companyDetails: Record<string, CompanyDetail>;
  isLoadingDetail: boolean;
  detailError: string | null;

  fetchCompanies: (params?: CompanyListParams) => Promise<void>;
  fetchCompanyDetail: (companyId: string) => Promise<void>;
}

export const useResearchStore = create<ResearchState>((set, get) => ({
  companyList: null,
  isLoadingList: false,
  listError: null,

  companyDetails: {},
  isLoadingDetail: false,
  detailError: null,

  fetchCompanies: async (params) => {
    try {
      set({ isLoadingList: true, listError: null });
      const page = await researchApi.listCompanies(params);
      set({ companyList: page, isLoadingList: false });
    } catch (error: any) {
      const message =
        error?.response?.data?.error || 'Failed to load the coverage list';
      set({ isLoadingList: false, listError: message });
      toast.error(message);
    }
  },

  fetchCompanyDetail: async (companyId: string) => {
    try {
      set({ isLoadingDetail: true, detailError: null });
      const detail = await researchApi.getCompanyDetail(companyId);
      set((state) => ({
        companyDetails: { ...state.companyDetails, [companyId]: detail },
        isLoadingDetail: false,
      }));
    } catch (error: any) {
      const message =
        error?.response?.data?.error || 'Failed to load company research';
      set({ isLoadingDetail: false, detailError: message });
      toast.error(message);
    }
  },
}));
