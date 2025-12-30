import axios from 'axios';
import { getApiBaseUrl } from '@/config/env';
import { useAuthStore } from '@/store/authStore';
import toast from 'react-hot-toast';

export const api = axios.create({
  baseURL: getApiBaseUrl(),
  headers: {
    'Content-Type': 'application/json',
  },
  withCredentials: true,  // Enable httpOnly cookie support (XSS protection)
});

// Add auth token to requests (fallback for backward compatibility)
api.interceptors.request.use((config) => {
  // httpOnly cookies are sent automatically, but keep localStorage fallback
  // for mobile apps or clients that don't support cookies
  const token = localStorage.getItem('token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Track if we're currently refreshing to prevent multiple simultaneous refresh calls
let isRefreshing = false;
let failedQueue: Array<{
  resolve: (value?: unknown) => void;
  reject: (reason?: unknown) => void;
}> = [];

const processQueue = (error: Error | null = null) => {
  failedQueue.forEach((prom) => {
    if (error) {
      prom.reject(error);
    } else {
      prom.resolve();
    }
  });
  failedQueue = [];
};

// Handle auth errors and rate limiting
api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;

    if (error.response?.status === 401 && !originalRequest._retry) {
      // Access token expired - try to refresh it
      if (isRefreshing) {
        // Already refreshing - queue this request
        return new Promise((resolve, reject) => {
          failedQueue.push({ resolve, reject });
        })
          .then(() => {
            return api(originalRequest);
          })
          .catch((err) => {
            return Promise.reject(err);
          });
      }

      originalRequest._retry = true;
      isRefreshing = true;

      try {
        // Attempt to refresh the access token
        // The refresh token is sent automatically via httpOnly cookie
        await api.post('/api/v1/auth/refresh');

        // Refresh successful - process queued requests
        processQueue();
        isRefreshing = false;

        // Retry the original request
        return api(originalRequest);
      } catch (refreshError) {
        // Refresh failed - session truly expired
        processQueue(new Error('Session expired'));
        isRefreshing = false;

        // Clear auth state and redirect to login
        useAuthStore.getState().handleSessionExpiry();
        return Promise.reject(refreshError);
      }
    } else if (error.response?.status === 429) {
      // Rate limit exceeded - show helpful message with retry time
      const retryAfter = error.response.data?.retry_after || error.response.headers?.['retry-after'] || 60;
      const retryMessage = retryAfter > 1
        ? `Too many requests. Please try again in ${retryAfter} seconds.`
        : 'Too many requests. Please try again in a moment.';

      toast.error(retryMessage, {
        duration: Math.min(retryAfter * 1000, 5000), // Show for retry duration or max 5s
        icon: '⏱️',
      });
    }
    return Promise.reject(error);
  }
);
