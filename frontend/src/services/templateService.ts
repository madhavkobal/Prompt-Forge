import { api } from '@/utils/api';
import { Template, TemplateCreate } from '@/types';

export const templateService = {
  async getTemplates(includePublic: boolean = true) {
    const response = await api.get<Template[]>('/templates/', {
      params: { include_public: includePublic },
    });
    return response.data;
  },

  async getTemplate(id: number) {
    const response = await api.get<Template>(`/templates/${id}`);
    return response.data;
  },

  async createTemplate(data: TemplateCreate) {
    const response = await api.post<Template>('/templates/', data);
    return response.data;
  },

  async deleteTemplate(id: number) {
    await api.delete(`/templates/${id}`);
  },
};
