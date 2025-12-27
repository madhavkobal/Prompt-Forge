export interface User {
  id: number;
  email: string;
  username: string;
  full_name?: string;
  is_active: boolean;
  is_superuser: boolean;
  created_at: string;
}

export interface Prompt {
  id: number;
  title?: string;
  content: string;
  enhanced_content?: string;
  quality_score?: number;
  clarity_score?: number;
  specificity_score?: number;
  structure_score?: number;
  analysis_result?: any;
  suggestions?: string[];
  best_practices?: any;
  target_llm?: string;
  category?: string;
  tags?: string[];
  owner_id: number;
  created_at: string;
  updated_at?: string;
}

export interface PromptCreate {
  title?: string;
  content: string;
  target_llm?: string;
  category?: string;
  tags?: string[];
}

export interface PromptAnalysis {
  quality_score: number;
  clarity_score: number;
  specificity_score: number;
  structure_score: number;
  strengths: string[];
  weaknesses: string[];
  suggestions: string[];
  best_practices: any;
}

export interface PromptEnhancement {
  original_content: string;
  enhanced_content: string;
  improvements: string[];
  quality_improvement: number;
}

export interface PromptVersion {
  id: number;
  prompt_id: number;
  version_number: number;
  content: string;
  quality_score?: number;
  change_summary?: string;
  created_at: string;
}

export interface Template {
  id: number;
  name: string;
  description?: string;
  content: string;
  category?: string;
  tags?: string[];
  is_public: boolean;
  use_count: number;
  owner_id: number;
  created_at: string;
  updated_at?: string;
}

export interface TemplateCreate {
  name: string;
  description?: string;
  content: string;
  category?: string;
  tags?: string[];
  is_public?: boolean;
}

export type LLMType = 'ChatGPT' | 'Claude' | 'Gemini' | 'Grok' | 'DeepSeek';
