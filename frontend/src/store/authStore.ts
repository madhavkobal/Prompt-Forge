import { create } from 'zustand';
import { User } from '@/types';

interface AuthState {
  user: User | null;
  token: string | null;
  sessionExpired: boolean;
  setUser: (user: User | null) => void;
  setToken: (token: string | null) => void;
  logout: () => void;
  handleSessionExpiry: () => void;
  clearSessionExpired: () => void;
  isAuthenticated: () => boolean;
}

export const useAuthStore = create<AuthState>((set, get) => ({
  user: null,
  token: localStorage.getItem('token'),
  sessionExpired: false,
  setUser: (user) => set({ user }),
  setToken: (token) => {
    if (token) {
      localStorage.setItem('token', token);
    } else {
      localStorage.removeItem('token');
    }
    set({ token });
  },
  logout: () => {
    localStorage.removeItem('token');
    set({ user: null, token: null, sessionExpired: false });
  },
  handleSessionExpiry: () => {
    localStorage.removeItem('token');
    set({ user: null, token: null, sessionExpired: true });
  },
  clearSessionExpired: () => set({ sessionExpired: false }),
  isAuthenticated: () => !!get().token,
}));
