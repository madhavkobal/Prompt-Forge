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

// Handle auth errors and rate limiting
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // Use auth store to handle session expiry gracefully
      // This triggers a smooth redirect via React Router instead of hard reload
      useAuthStore.getState().handleSessionExpiry();
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
