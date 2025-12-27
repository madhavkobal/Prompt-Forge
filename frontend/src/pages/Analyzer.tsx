import { useState } from 'react';
import { promptService } from '@/services/promptService';
import { PromptAnalysis, PromptEnhancement, LLMType } from '@/types';
import toast from 'react-hot-toast';
import Layout from '@/components/Layout';
import ScoreCard from '@/components/ScoreCard';
import { Sparkles, TrendingUp, ArrowRight } from 'lucide-react';

const LLM_OPTIONS: LLMType[] = ['ChatGPT', 'Claude', 'Gemini', 'Grok', 'DeepSeek'];

export default function Analyzer() {
  const [content, setContent] = useState('');
  const [title, setTitle] = useState('');
  const [targetLLM, setTargetLLM] = useState<LLMType>('ChatGPT');
  const [analysis, setAnalysis] = useState<PromptAnalysis | null>(null);
  const [enhancement, setEnhancement] = useState<PromptEnhancement | null>(null);
  const [loading, setLoading] = useState(false);
  const [promptId, setPromptId] = useState<number | null>(null);

  const handleAnalyze = async () => {
    if (!content.trim()) {
      toast.error('Please enter a prompt to analyze');
      return;
    }

    setLoading(true);
    try {
      // Create prompt first
      const prompt = await promptService.createPrompt({
        title: title || 'Untitled Prompt',
        content,
        target_llm: targetLLM,
      });
      setPromptId(prompt.id);

      // Analyze it
      const analysisResult = await promptService.analyzePrompt(prompt.id);
      setAnalysis(analysisResult);
      toast.success('Analysis complete!');
    } catch (error: any) {
      toast.error(error.response?.data?.detail || 'Analysis failed');
    } finally {
      setLoading(false);
    }
  };

  const handleEnhance = async () => {
    if (!promptId) {
      toast.error('Please analyze the prompt first');
      return;
    }

    setLoading(true);
    try {
      const enhancementResult = await promptService.enhancePrompt(promptId);
      setEnhancement(enhancementResult);
      toast.success('Enhancement complete!');
    } catch (error: any) {
      toast.error(error.response?.data?.detail || 'Enhancement failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Layout>
      <div className="space-y-6">
        <div className="flex justify-between items-center">
          <div>
            <h1 className="text-3xl font-bold text-gray-900">Prompt Analyzer</h1>
            <p className="text-gray-600 mt-1">
              Analyze and enhance your prompts with AI-powered insights
            </p>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Input Section */}
          <div className="space-y-4">
            <div className="card">
              <h2 className="text-xl font-semibold text-gray-900 mb-4">
                Your Prompt
              </h2>
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Title (Optional)
                  </label>
                  <input
                    type="text"
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                    className="input"
                    placeholder="Give your prompt a title"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Target LLM
                  </label>
                  <select
                    value={targetLLM}
                    onChange={(e) => setTargetLLM(e.target.value as LLMType)}
                    className="input"
                  >
                    {LLM_OPTIONS.map((llm) => (
                      <option key={llm} value={llm}>
                        {llm}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Prompt Content
                  </label>
                  <textarea
                    value={content}
                    onChange={(e) => setContent(e.target.value)}
                    className="input h-64 resize-none"
                    placeholder="Enter your prompt here..."
                  />
                </div>
                <div className="flex space-x-2">
                  <button
                    onClick={handleAnalyze}
                    disabled={loading}
                    className="btn btn-primary flex-1 flex items-center justify-center space-x-2"
                  >
                    <Sparkles className="h-4 w-4" />
                    <span>{loading ? 'Analyzing...' : 'Analyze'}</span>
                  </button>
                  {analysis && (
                    <button
                      onClick={handleEnhance}
                      disabled={loading}
                      className="btn btn-secondary flex-1 flex items-center justify-center space-x-2"
                    >
                      <TrendingUp className="h-4 w-4" />
                      <span>{loading ? 'Enhancing...' : 'Enhance'}</span>
                    </button>
                  )}
                </div>
              </div>
            </div>
          </div>

          {/* Results Section */}
          <div className="space-y-4">
            {analysis && (
              <>
                <div className="card">
                  <h2 className="text-xl font-semibold text-gray-900 mb-4">
                    Quality Scores
                  </h2>
                  <div className="grid grid-cols-2 gap-4">
                    <ScoreCard title="Overall Quality" score={analysis.quality_score} />
                    <ScoreCard title="Clarity" score={analysis.clarity_score} />
                    <ScoreCard title="Specificity" score={analysis.specificity_score} />
                    <ScoreCard title="Structure" score={analysis.structure_score} />
                  </div>
                </div>

                <div className="card">
                  <h3 className="text-lg font-semibold text-gray-900 mb-3">
                    Strengths
                  </h3>
                  <ul className="space-y-2">
                    {analysis.strengths.map((strength, idx) => (
                      <li key={idx} className="flex items-start">
                        <span className="text-green-600 mr-2">✓</span>
                        <span className="text-gray-700">{strength}</span>
                      </li>
                    ))}
                  </ul>
                </div>

                <div className="card">
                  <h3 className="text-lg font-semibold text-gray-900 mb-3">
                    Suggestions
                  </h3>
                  <ul className="space-y-2">
                    {analysis.suggestions.map((suggestion, idx) => (
                      <li key={idx} className="flex items-start">
                        <span className="text-primary-600 mr-2">→</span>
                        <span className="text-gray-700">{suggestion}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              </>
            )}

            {enhancement && (
              <div className="card">
                <h3 className="text-lg font-semibold text-gray-900 mb-3 flex items-center">
                  <TrendingUp className="h-5 w-5 mr-2 text-primary-600" />
                  Enhanced Version
                </h3>
                <div className="bg-gray-50 p-4 rounded-lg mb-4">
                  <p className="text-gray-800 whitespace-pre-wrap">
                    {enhancement.enhanced_content}
                  </p>
                </div>
                <div className="mb-3">
                  <span className="badge badge-success">
                    +{Math.round(enhancement.quality_improvement)}% improvement
                  </span>
                </div>
                <div>
                  <h4 className="text-sm font-semibold text-gray-700 mb-2">
                    Improvements Made:
                  </h4>
                  <ul className="space-y-1">
                    {enhancement.improvements.map((improvement, idx) => (
                      <li key={idx} className="flex items-start text-sm">
                        <ArrowRight className="h-4 w-4 text-primary-600 mr-2 mt-0.5" />
                        <span className="text-gray-600">{improvement}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </Layout>
  );
}
