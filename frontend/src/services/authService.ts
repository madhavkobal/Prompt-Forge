import { api } from '@/utils/api';
import { User } from '@/types';

export const authService = {
  async register(data: { email: string; username: string; password: string; full_name?: string }) {
    const response = await api.post<User>('/auth/register', data);
    return response.data;
  },

  async login(username: string, password: string) {
    const formData = new FormData();
    formData.append('username', username);
    formData.append('password', password);

    const response = await api.post<{ access_token: string; token_type: string }>(
      '/auth/login',
      formData,
      {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      }
    );
    return response.data;
  },

  async getCurrentUser() {
    const response = await api.get<User>('/auth/me');
    return response.data;
  },
};
