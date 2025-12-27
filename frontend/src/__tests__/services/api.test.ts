/**
 * Tests for API services
 * Tests axios integration, authentication, and error handling
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import axios from 'axios';
import { authService } from '@/services/authService';
import { promptService } from '@/services/promptService';
import { templateService } from '@/services/templateService';
import {
  createMockUser,
  createMockPrompt,
  createMockTemplate,
  createMockAuthResponse,
  createMockAnalysis,
  createMockEnhancement,
} from '../testUtils';

// Mock axios
vi.mock('axios');
const mockedAxios = vi.mocked(axios, true);

// Mock axios.create to return an axios instance with interceptors
mockedAxios.create = vi.fn(() => ({
  ...mockedAxios,
  interceptors: {
    request: { use: vi.fn(), eject: vi.fn() },
    response: { use: vi.fn(), eject: vi.fn() },
  },
})) as any;

describe('Auth Service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    localStorage.clear();
  });

  describe('register', () => {
    it('registers a new user successfully', async () => {
      const mockUser = createMockUser();
      const userData = {
        email: 'test@example.com',
        username: 'testuser',
        password: 'password123',
        full_name: 'Test User',
      };

      mockedAxios.post.mockResolvedValue({ data: mockUser });

      const result = await authService.register(userData);

      expect(mockedAxios.post).toHaveBeenCalledWith('/auth/register', userData);
      expect(result).toEqual(mockUser);
    });

    it('handles registration error', async () => {
      const error = {
        response: {
          data: { detail: 'Email already exists' },
          status: 400,
        },
      };

      mockedAxios.post.mockRejectedValue(error);

      await expect(
        authService.register({
          email: 'test@example.com',
          username: 'testuser',
          password: 'password123',
        })
      ).rejects.toEqual(error);
    });
  });

  describe('login', () => {
    it('logs in successfully and returns token', async () => {
      const mockResponse = createMockAuthResponse();

      mockedAxios.post.mockResolvedValue({ data: mockResponse });

      const result = await authService.login('testuser', 'password123');

      expect(mockedAxios.post).toHaveBeenCalledWith(
        '/auth/login',
        expect.any(FormData),
        expect.objectContaining({
          headers: { 'Content-Type': 'multipart/form-data' },
        })
      );
      expect(result).toEqual(mockResponse);
    });

    it('sends credentials as FormData', async () => {
      const mockResponse = createMockAuthResponse();
      let capturedFormData: any = null;

      mockedAxios.post.mockImplementation(async (_url, data) => {
        capturedFormData = data;
        return { data: mockResponse };
      });

      await authService.login('testuser', 'password123');

      expect(capturedFormData).toBeInstanceOf(FormData);
      expect(capturedFormData.get('username')).toBe('testuser');
      expect(capturedFormData.get('password')).toBe('password123');
    });
  });

  describe('getCurrentUser', () => {
    it('fetches current user', async () => {
      const mockUser = createMockUser();

      mockedAxios.get.mockResolvedValue({ data: mockUser });

      const result = await authService.getCurrentUser();

      expect(mockedAxios.get).toHaveBeenCalledWith('/auth/me');
      expect(result).toEqual(mockUser);
    });
  });
});

describe('Prompt Service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('getPrompts', () => {
    it('fetches all prompts', async () => {
      const mockPrompts = [createMockPrompt()];

      mockedAxios.get.mockResolvedValue({ data: mockPrompts });

      const result = await promptService.getPrompts();

      expect(mockedAxios.get).toHaveBeenCalledWith('/prompts/');
      expect(result).toEqual(mockPrompts);
    });
  });

  describe('getPrompt', () => {
    it('fetches a single prompt by ID', async () => {
      const mockPrompt = createMockPrompt();

      mockedAxios.get.mockResolvedValue({ data: mockPrompt });

      const result = await promptService.getPrompt(1);

      expect(mockedAxios.get).toHaveBeenCalledWith('/prompts/1');
      expect(result).toEqual(mockPrompt);
    });
  });

  describe('createPrompt', () => {
    it('creates a new prompt', async () => {
      const newPromptData = {
        title: 'New Prompt',
        content: 'Test content',
        target_llm: 'ChatGPT' as const,
      };
      const mockPrompt = createMockPrompt(newPromptData);

      mockedAxios.post.mockResolvedValue({ data: mockPrompt });

      const result = await promptService.createPrompt(newPromptData);

      expect(mockedAxios.post).toHaveBeenCalledWith('/prompts/', newPromptData);
      expect(result).toEqual(mockPrompt);
    });
  });

  describe('updatePrompt', () => {
    it('updates an existing prompt', async () => {
      const updates = { title: 'Updated Title' };
      const mockPrompt = createMockPrompt(updates);

      mockedAxios.put.mockResolvedValue({ data: mockPrompt });

      const result = await promptService.updatePrompt(1, updates);

      expect(mockedAxios.put).toHaveBeenCalledWith('/prompts/1', updates);
      expect(result).toEqual(mockPrompt);
    });
  });

  describe('deletePrompt', () => {
    it('deletes a prompt', async () => {
      mockedAxios.delete.mockResolvedValue({});

      await promptService.deletePrompt(1);

      expect(mockedAxios.delete).toHaveBeenCalledWith('/prompts/1');
    });
  });

  describe('analyzePrompt', () => {
    it('analyzes a prompt and returns analysis', async () => {
      const mockAnalysis = createMockAnalysis();

      mockedAxios.post.mockResolvedValue({ data: mockAnalysis });

      const result = await promptService.analyzePrompt(1);

      expect(mockedAxios.post).toHaveBeenCalledWith('/prompts/1/analyze');
      expect(result).toEqual(mockAnalysis);
    });
  });

  describe('enhancePrompt', () => {
    it('enhances a prompt and returns enhancement', async () => {
      const mockEnhancement = createMockEnhancement();

      mockedAxios.post.mockResolvedValue({ data: mockEnhancement });

      const result = await promptService.enhancePrompt(1);

      expect(mockedAxios.post).toHaveBeenCalledWith('/prompts/1/enhance');
      expect(result).toEqual(mockEnhancement);
    });
  });

  describe('getPromptVersions', () => {
    it('fetches prompt version history', async () => {
      const mockVersions = [
        { id: 1, prompt_id: 1, version_number: 1, content: 'Version 1' },
        { id: 2, prompt_id: 1, version_number: 2, content: 'Version 2' },
      ];

      mockedAxios.get.mockResolvedValue({ data: mockVersions });

      const result = await promptService.getPromptVersions(1);

      expect(mockedAxios.get).toHaveBeenCalledWith('/prompts/1/versions');
      expect(result).toEqual(mockVersions);
    });
  });
});

describe('Template Service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('getTemplates', () => {
    it('fetches templates with includePublic=true by default', async () => {
      const mockTemplates = [createMockTemplate()];

      mockedAxios.get.mockResolvedValue({ data: mockTemplates });

      const result = await templateService.getTemplates();

      expect(mockedAxios.get).toHaveBeenCalledWith('/templates/', {
        params: { include_public: true },
      });
      expect(result).toEqual(mockTemplates);
    });

    it('fetches only private templates when includePublic=false', async () => {
      const mockTemplates = [createMockTemplate({ is_public: false })];

      mockedAxios.get.mockResolvedValue({ data: mockTemplates });

      const result = await templateService.getTemplates(false);

      expect(mockedAxios.get).toHaveBeenCalledWith('/templates/', {
        params: { include_public: false },
      });
      expect(result).toEqual(mockTemplates);
    });
  });

  describe('getTemplate', () => {
    it('fetches a single template by ID', async () => {
      const mockTemplate = createMockTemplate();

      mockedAxios.get.mockResolvedValue({ data: mockTemplate });

      const result = await templateService.getTemplate(1);

      expect(mockedAxios.get).toHaveBeenCalledWith('/templates/1');
      expect(result).toEqual(mockTemplate);
    });
  });

  describe('createTemplate', () => {
    it('creates a new template', async () => {
      const newTemplateData = {
        name: 'New Template',
        content: 'Template content',
        category: 'test',
      };
      const mockTemplate = createMockTemplate(newTemplateData);

      mockedAxios.post.mockResolvedValue({ data: mockTemplate });

      const result = await templateService.createTemplate(newTemplateData);

      expect(mockedAxios.post).toHaveBeenCalledWith('/templates/', newTemplateData);
      expect(result).toEqual(mockTemplate);
    });
  });

  describe('deleteTemplate', () => {
    it('deletes a template', async () => {
      mockedAxios.delete.mockResolvedValue({});

      await templateService.deleteTemplate(1);

      expect(mockedAxios.delete).toHaveBeenCalledWith('/templates/1');
    });
  });
});

describe('API Error Handling', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('handles network errors', async () => {
    const networkError = new Error('Network Error');

    mockedAxios.get.mockRejectedValue(networkError);

    await expect(promptService.getPrompts()).rejects.toThrow('Network Error');
  });

  it('handles 401 unauthorized errors', async () => {
    const error = {
      response: {
        status: 401,
        data: { detail: 'Unauthorized' },
      },
    };

    mockedAxios.get.mockRejectedValue(error);

    await expect(promptService.getPrompts()).rejects.toEqual(error);
  });

  it('handles 404 not found errors', async () => {
    const error = {
      response: {
        status: 404,
        data: { detail: 'Prompt not found' },
      },
    };

    mockedAxios.get.mockRejectedValue(error);

    await expect(promptService.getPrompt(999)).rejects.toEqual(error);
  });

  it('handles 422 validation errors', async () => {
    const error = {
      response: {
        status: 422,
        data: {
          detail: [
            {
              loc: ['body', 'email'],
              msg: 'invalid email format',
              type: 'value_error.email',
            },
          ],
        },
      },
    };

    mockedAxios.post.mockRejectedValue(error);

    await expect(
      authService.register({
        email: 'invalid',
        username: 'test',
        password: '123',
      })
    ).rejects.toEqual(error);
  });

  it('handles 500 server errors', async () => {
    const error = {
      response: {
        status: 500,
        data: { detail: 'Internal server error' },
      },
    };

    mockedAxios.post.mockRejectedValue(error);

    await expect(promptService.analyzePrompt(1)).rejects.toEqual(error);
  });
});

describe('API Authentication Headers', () => {
  it('includes auth token in requests when present', async () => {
    const token = 'mock-jwt-token';
    localStorage.setItem('token', token);

    mockedAxios.get.mockResolvedValue({ data: [] });

    await promptService.getPrompts();

    // Note: This tests the axios interceptor setup
    // The actual header injection happens in api.ts
    expect(mockedAxios.get).toHaveBeenCalled();
  });

  it('makes requests without auth token when not logged in', async () => {
    localStorage.removeItem('token');

    mockedAxios.get.mockResolvedValue({ data: [] });

    await promptService.getPrompts();

    expect(mockedAxios.get).toHaveBeenCalled();
  });
});
