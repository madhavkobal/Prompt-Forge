/**
 * Test utilities and helpers
 * Common functions, mock data, and custom renderers for tests
 */

import React, { ReactElement } from 'react';
import { render, RenderOptions } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

// Create a custom render function that includes providers
const AllTheProviders = ({ children }: { children: React.ReactNode }) => {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
      },
    },
  });

  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>{children}</BrowserRouter>
    </QueryClientProvider>
  );
};

const customRender = (
  ui: ReactElement,
  options?: Omit<RenderOptions, 'wrapper'>
) => render(ui, { wrapper: AllTheProviders, ...options });

// Re-export everything
export * from '@testing-library/react';
export { customRender as render };

// =============================================================================
// Mock Data Factories
// =============================================================================

export const createMockUser = (overrides = {}) => ({
  id: 1,
  email: 'test@example.com',
  username: 'testuser',
  full_name: 'Test User',
  is_active: true,
  created_at: '2024-01-15T10:00:00',
  ...overrides,
});

export const createMockPrompt = (overrides = {}) => ({
  id: 1,
  title: 'Test Prompt',
  content: 'Write a comprehensive article about AI testing.',
  target_llm: 'ChatGPT' as const,
  category: 'testing',
  tags: ['ai', 'testing'],
  owner_id: 1,
  quality_score: null,
  clarity_score: null,
  specificity_score: null,
  structure_score: null,
  suggestions: null,
  best_practices: null,
  enhanced_content: null,
  created_at: '2024-01-15T10:00:00',
  updated_at: '2024-01-15T10:00:00',
  ...overrides,
});

export const createMockAnalysis = (overrides = {}) => ({
  quality_score: 85.0,
  clarity_score: 88.0,
  specificity_score: 82.0,
  structure_score: 87.0,
  strengths: [
    'Clear objective stated',
    'Specific topic defined',
  ],
  weaknesses: [
    'Could add more context',
    'Output format not specified',
  ],
  suggestions: [
    'Add expected article length',
    'Specify tone and style',
  ],
  best_practices: {
    has_clear_instruction: 'excellent',
    has_context: 'good',
    has_constraints: 'fair',
  },
  ...overrides,
});

export const createMockEnhancement = (overrides = {}) => ({
  original_content: 'Write a comprehensive article about AI testing.',
  enhanced_content: 'Write a comprehensive, well-structured article about AI testing best practices. Target audience: software developers. Tone: technical yet accessible. Include: 1) Testing strategies, 2) Tools and frameworks, 3) Real-world examples. Format: 1500-2000 words.',
  quality_improvement: 15.5,
  improvements: [
    'Added clear target audience',
    'Defined tone and style',
    'Structured content requirements',
    'Specified word count',
  ],
  ...overrides,
});

export const createMockTemplate = (overrides = {}) => ({
  id: 1,
  name: 'Blog Post Template',
  description: 'Template for creating blog posts',
  content: 'Write a blog post about {topic}. Target audience: {audience}.',
  category: 'content',
  tags: ['blog', 'content'],
  is_public: true,
  owner_id: 1,
  use_count: 0,
  created_at: '2024-01-15T10:00:00',
  updated_at: '2024-01-15T10:00:00',
  ...overrides,
});

export const createMockAuthResponse = (overrides = {}) => ({
  access_token: 'mock-jwt-token-12345',
  token_type: 'bearer',
  ...overrides,
});

// =============================================================================
// Mock API Responses
// =============================================================================

export const mockApiResponses = {
  // Auth
  login: createMockAuthResponse(),
  register: createMockUser(),
  me: createMockUser(),

  // Prompts
  prompts: [createMockPrompt()],
  prompt: createMockPrompt(),
  createPrompt: createMockPrompt(),
  updatePrompt: createMockPrompt({ title: 'Updated Prompt' }),
  analyzePrompt: createMockAnalysis(),
  enhancePrompt: createMockEnhancement(),

  // Templates
  templates: [createMockTemplate()],
  template: createMockTemplate(),
  createTemplate: createMockTemplate(),
};

// =============================================================================
// Mock Functions
// =============================================================================

export const createMockAxios = () => ({
  get: vi.fn(),
  post: vi.fn(),
  put: vi.fn(),
  delete: vi.fn(),
  patch: vi.fn(),
  request: vi.fn(),
  interceptors: {
    request: {
      use: vi.fn(),
      eject: vi.fn(),
    },
    response: {
      use: vi.fn(),
      eject: vi.fn(),
    },
  },
});

// =============================================================================
// Test Helpers
// =============================================================================

/**
 * Wait for async operations to complete
 */
export const waitForLoadingToFinish = () =>
  new Promise((resolve) => setTimeout(resolve, 0));

/**
 * Create a mock file for file upload tests
 */
export const createMockFile = (
  name = 'test.txt',
  content = 'test content',
  type = 'text/plain'
) => {
  const blob = new Blob([content], { type });
  return new File([blob], name, { type });
};

/**
 * Mock clipboard API
 */
export const mockClipboard = () => {
  Object.assign(navigator, {
    clipboard: {
      writeText: vi.fn().mockResolvedValue(undefined),
      readText: vi.fn().mockResolvedValue(''),
    },
  });
};

/**
 * Suppress console errors/warnings in specific tests
 */
export const suppressConsole = () => {
  const originalError = console.error;
  const originalWarn = console.warn;

  beforeAll(() => {
    console.error = vi.fn();
    console.warn = vi.fn();
  });

  afterAll(() => {
    console.error = originalError;
    console.warn = originalWarn;
  });
};

/**
 * Mock localStorage for specific tests
 */
export const mockLocalStorage = () => {
  const store: Record<string, string> = {};

  return {
    getItem: vi.fn((key: string) => store[key] || null),
    setItem: vi.fn((key: string, value: string) => {
      store[key] = value;
    }),
    removeItem: vi.fn((key: string) => {
      delete store[key];
    }),
    clear: vi.fn(() => {
      Object.keys(store).forEach((key) => delete store[key]);
    }),
  };
};

/**
 * Create a mock router
 */
export const createMockRouter = () => ({
  navigate: vi.fn(),
  location: {
    pathname: '/',
    search: '',
    hash: '',
    state: null,
  },
  params: {},
});
