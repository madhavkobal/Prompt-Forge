import { api } from '@/utils/api';
import {
  Prompt,
  PromptCreate,
  PromptAnalysis,
  PromptEnhancement,
  PromptVersion,
} from '@/types';

export const promptService = {
  async getPrompts() {
    const response = await api.get<Prompt[]>('/prompts/');
    return response.data;
  },

  async getPrompt(id: number) {
    const response = await api.get<Prompt>(`/prompts/${id}`);
    return response.data;
  },

  async createPrompt(data: PromptCreate) {
    const response = await api.post<Prompt>('/prompts/', data);
    return response.data;
  },

  async updatePrompt(id: number, data: Partial<PromptCreate>) {
    const response = await api.put<Prompt>(`/prompts/${id}`, data);
    return response.data;
  },

  async deletePrompt(id: number) {
    await api.delete(`/prompts/${id}`);
  },

  async analyzePrompt(id: number) {
    const response = await api.post<PromptAnalysis>(`/prompts/${id}/analyze`);
    return response.data;
  },

  async enhancePrompt(id: number) {
    const response = await api.post<PromptEnhancement>(`/prompts/${id}/enhance`);
    return response.data;
  },

  async getPromptVersions(id: number) {
    const response = await api.get<PromptVersion[]>(`/prompts/${id}/versions`);
    return response.data;
  },
};
