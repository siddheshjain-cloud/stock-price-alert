import axios, { AxiosError, AxiosResponse, InternalAxiosRequestConfig } from 'axios';
import Cookies from 'js-cookie';
import { toast } from 'sonner';

declare module 'axios' {
  export interface AxiosRequestConfig {
    /** Skip this instance's generic status-code error toast for one request -- the caller is handling that error state itself (e.g. an expected 404). */
    suppressErrorToast?: boolean;
  }
}

// Create axios instance
const axiosInstance = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor to add auth token
axiosInstance.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    const token = Cookies.get('access_token');
    
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    
    return config;
  },
  (error: AxiosError) => {
    return Promise.reject(error);
  }
);

// Response interceptor to handle token refresh and errors
axiosInstance.interceptors.response.use(
  (response: AxiosResponse) => {
    return response;
  },
  async (error: AxiosError) => {
    const originalRequest = error.config as InternalAxiosRequestConfig & { _retry?: boolean };

    // Handle 401 errors (unauthorized)
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;

      try {
        const refreshToken = Cookies.get('refresh_token');
        
        if (refreshToken) {
          // Try to refresh the token
          const response = await axios.post(`${process.env.NEXT_PUBLIC_API_URL}/auth/refresh`, {}, {
            headers: {
              Authorization: `Bearer ${refreshToken}`,
            },
          });

          if (response.data.access_token) {
            // Update the access token in cookies
            Cookies.set('access_token', response.data.access_token, { 
              expires: 1,
              secure: process.env.NODE_ENV === 'production',
              sameSite: 'strict'
            });

            // Retry the original request with new token
            originalRequest.headers.Authorization = `Bearer ${response.data.access_token}`;
            return axiosInstance(originalRequest);
          }
        }
      } catch (refreshError) {
        // Refresh failed, redirect to login
        Cookies.remove('access_token');
        Cookies.remove('refresh_token');
        
        // Only show error if not already on auth pages
        if (typeof window !== 'undefined' && 
            !window.location.pathname.includes('/auth/')) {
          toast.error('Session expired. Please login again.');
          window.location.href = '/auth/signin';
        }
        
        return Promise.reject(refreshError);
      }
    }

    // Handle other error status codes
    if (!originalRequest?.suppressErrorToast && error.response?.status) {
      const status = error.response.status;
      const message = (error.response.data as { error?: string })?.error || error.message;

      switch (status) {
        case 400:
          toast.error(`Bad Request: ${message}`);
          break;
        case 403:
          toast.error('Access denied. You do not have permission to perform this action.');
          break;
        case 404:
          toast.error('Resource not found.');
          break;
        case 409:
          toast.error(message || 'Conflict occurred.');
          break;
        case 422:
          // Validation errors - let the component handle these
          break;
        case 500:
          toast.error('Server error. Please try again later.');
          break;
        default:
          if (status >= 500) {
            toast.error('Server error. Please try again later.');
          }
      }
    } else if (error.code === 'ECONNABORTED') {
      toast.error('Request timed out. Please try again.');
    } else if (error.message === 'Network Error') {
      toast.error('Network error. Please check your connection.');
    }

    return Promise.reject(error);
  }
);

export default axiosInstance;