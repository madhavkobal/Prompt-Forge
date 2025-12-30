import axios from 'axios';
import { getApiBaseUrl } from '@/config/env';
import { useAuthStore } from '@/store/authStore';

export const api = axios.create({
  baseURL: getApiBaseUrl(),
  headers: {
    'Content-Type': 'application/json',
  },
});

// Add auth token to requests
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Handle auth errors
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // Use auth store to handle session expiry gracefully
      // This triggers a smooth redirect via React Router instead of hard reload
      useAuthStore.getState().handleSessionExpiry();
    }
    return Promise.reject(error);
  }
);
