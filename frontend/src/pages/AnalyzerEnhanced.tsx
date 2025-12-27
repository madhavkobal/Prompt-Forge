import { useState, useEffect } from 'react';
import { promptService } from '@/services/promptService';
import { PromptAnalysis, PromptEnhancement, LLMType } from '@/types';
import toast from 'react-hot-toast';
import Layout from '@/components/Layout';
import PromptEditor from '@/components/PromptEditor';
import AnalysisPanel from '@/components/AnalysisPanel';
import EnhancementPanel from '@/components/EnhancementPanel';
import ComparisonView from '@/components/ComparisonView';
import { useDebounce } from '@/hooks/useDebounce';
import { Sparkles, TrendingUp, ArrowLeftRight, Loader, Save } from 'lucide-react';

const LLM_OPTIONS: LLMType[] = ['ChatGPT', 'Claude', 'Gemini', 'Grok', 'DeepSeek'];

export default function AnalyzerEnhanced() {
  // State
  const [content, setContent] = useState('');
  const [title, setTitle] = useState('');
  const [targetLLM, setTargetLLM] = useState<LLMType>('ChatGPT');
  const [analysis, setAnalysis] = useState<PromptAnalysis | null>(null);
  const [enhancement, setEnhancement] = useState<PromptEnhancement | null>(null);
  const [loading, setLoading] = useState(false);
  const [analyzing, setAnalyzing] = useState(false);
  const [promptId, setPromptId] = useState<number | null>(null);
  const [activeView, setActiveView] = useState<'editor' | 'analysis' | 'enhancement' | 'comparison'>('editor');
  const [autoAnalyze, setAutoAnalyze] = useState(false);

  // Debounced content for real-time analysis
  const debouncedContent = useDebounce(content, 500);

  // Real-time analysis effect
  useEffect(() => {
    if (autoAnalyze && debouncedContent && debouncedContent.length > 20) {
      handleAnalyze(true);
    }
  }, [debouncedContent, autoAnalyze]);

  const handleAnalyze = async (isAutoAnalysis = false) => {
    if (!content.trim()) {
      toast.error('Please enter a prompt to analyze');
      return;
    }

    if (!isAutoAnalysis) {
      setLoading(true);
    } else {
      setAnalyzing(true);
    }

    try {
      // Create or update prompt
      let pid = promptId;
      if (!promptId) {
        const prompt = await promptService.createPrompt({
          title: title || 'Untitled Prompt',
          content,
          target_llm: targetLLM,
        });
        pid = prompt.id;
        setPromptId(pid);
      }

      // Analyze it
      if (pid) {
        const analysisResult = await promptService.analyzePrompt(pid);
        setAnalysis(analysisResult);

        if (!isAutoAnalysis) {
          setActiveView('analysis');
          toast.success('Analysis complete!');
        }
      }
    } catch (error: any) {
      if (!isAutoAnalysis) {
        toast.error(error.response?.data?.detail || 'Analysis failed');
      }
    } finally {
      setLoading(false);
      setAnalyzing(false);
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
      setActiveView('enhancement');
      toast.success('Enhancement complete!');
    } catch (error: any) {
      toast.error(error.response?.data?.detail || 'Enhancement failed');
    } finally {
      setLoading(false);
    }
  };

  const handleUseEnhanced = (enhancedContent: string) => {
    setContent(enhancedContent);
    setPromptId(null); // Reset to create new prompt
    setActiveView('editor');
  };

  const handleSave = async () => {
    if (!content.trim()) {
      toast.error('Cannot save empty prompt');
      return;
    }

    try {
      if (promptId) {
        await promptService.updatePrompt(promptId, { content, title });
        toast.success('Prompt updated!');
      } else {
        const prompt = await promptService.createPrompt({
          title: title || 'Untitled Prompt',
          content,
          target_llm: targetLLM,
        });
        setPromptId(prompt.id);
        toast.success('Prompt saved!');
      }
    } catch (error: any) {
      toast.error('Failed to save prompt');
    }
  };

  return (
    <Layout>
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
          <div>
            <h1 className="text-3xl font-bold text-gray-900">
              Prompt Analyzer
            </h1>
            <p className="text-gray-600 mt-1">
              Analyze and enhance your prompts with AI-powered insights
            </p>
          </div>

          {/* Auto-analyze toggle */}
          <div className="flex items-center space-x-2">
            <label className="flex items-center space-x-2 cursor-pointer">
              <input
                type="checkbox"
                checked={autoAnalyze}
                onChange={(e) => setAutoAnalyze(e.target.checked)}
                className="w-4 h-4 text-primary-600 focus:ring-primary-500 rounded"
              />
              <span className="text-sm text-gray-700">Real-time analysis</span>
            </label>
            {analyzing && (
              <Loader className="h-4 w-4 animate-spin text-primary-600" />
            )}
          </div>
        </div>

        {/* View Tabs */}
        <div className="card p-0">
          <div className="flex border-b border-gray-200 overflow-x-auto">
            <button
              onClick={() => setActiveView('editor')}
              className={`px-6 py-3 font-medium text-sm whitespace-nowrap ${
                activeView === 'editor'
                  ? 'border-b-2 border-primary-600 text-primary-600'
                  : 'text-gray-600 hover:text-gray-900'
              }`}
            >
              Editor
            </button>
            <button
              onClick={() => setActiveView('analysis')}
              disabled={!analysis}
              className={`px-6 py-3 font-medium text-sm whitespace-nowrap ${
                activeView === 'analysis'
                  ? 'border-b-2 border-primary-600 text-primary-600'
                  : 'text-gray-600 hover:text-gray-900 disabled:text-gray-400 disabled:cursor-not-allowed'
              }`}
            >
              Analysis
              {analysis && (
                <span className="ml-2 inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-primary-100 text-primary-800">
                  {Math.round(analysis.quality_score)}
                </span>
              )}
            </button>
            <button
              onClick={() => setActiveView('enhancement')}
              disabled={!enhancement}
              className={`px-6 py-3 font-medium text-sm whitespace-nowrap ${
                activeView === 'enhancement'
                  ? 'border-b-2 border-primary-600 text-primary-600'
                  : 'text-gray-600 hover:text-gray-900 disabled:text-gray-400 disabled:cursor-not-allowed'
              }`}
            >
              Enhancement
              {enhancement && (
                <span className="ml-2 inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800">
                  +{Math.round(enhancement.quality_improvement)}%
                </span>
              )}
            </button>
            <button
              onClick={() => setActiveView('comparison')}
              disabled={!enhancement}
              className={`px-6 py-3 font-medium text-sm whitespace-nowrap ${
                activeView === 'comparison'
                  ? 'border-b-2 border-primary-600 text-primary-600'
                  : 'text-gray-600 hover:text-gray-900 disabled:text-gray-400 disabled:cursor-not-allowed'
              }`}
            >
              Comparison
            </button>
          </div>
        </div>

        {/* Editor View */}
        {activeView === 'editor' && (
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <div className="lg:col-span-2 space-y-4">
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
                    <PromptEditor
                      value={content}
                      onChange={setContent}
                      placeholder="Enter your prompt here..."
                      height="400px"
                    />
                  </div>
                  <div className="flex flex-wrap gap-2">
                    <button
                      onClick={() => handleAnalyze(false)}
                      disabled={loading || !content.trim()}
                      className="btn btn-primary flex items-center space-x-2"
                    >
                      <Sparkles className="h-4 w-4" />
                      <span>{loading ? 'Analyzing...' : 'Analyze'}</span>
                    </button>
                    {analysis && (
                      <button
                        onClick={handleEnhance}
                        disabled={loading}
                        className="btn btn-secondary flex items-center space-x-2"
                      >
                        <TrendingUp className="h-4 w-4" />
                        <span>{loading ? 'Enhancing...' : 'Enhance'}</span>
                      </button>
                    )}
                    <button
                      onClick={handleSave}
                      disabled={!content.trim()}
                      className="btn btn-secondary flex items-center space-x-2"
                    >
                      <Save className="h-4 w-4" />
                      <span>Save</span>
                    </button>
                  </div>
                </div>
              </div>
            </div>

            {/* Quick Stats Sidebar */}
            <div className="space-y-4">
              <div className="card">
                <h3 className="text-lg font-semibold text-gray-900 mb-3">
                  Quick Stats
                </h3>
                <div className="space-y-3">
                  <div>
                    <div className="text-sm text-gray-600">Characters</div>
                    <div className="text-2xl font-bold text-gray-900">
                      {content.length}
                    </div>
                  </div>
                  <div>
                    <div className="text-sm text-gray-600">Words</div>
                    <div className="text-2xl font-bold text-gray-900">
                      {content.split(/\s+/).filter(Boolean).length}
                    </div>
                  </div>
                  <div>
                    <div className="text-sm text-gray-600">Lines</div>
                    <div className="text-2xl font-bold text-gray-900">
                      {content.split('\n').length}
                    </div>
                  </div>
                </div>
              </div>

              {analysis && (
                <div className="card bg-gradient-to-br from-primary-50 to-primary-100">
                  <h3 className="text-lg font-semibold text-gray-900 mb-2">
                    Last Analysis
                  </h3>
                  <div className="text-4xl font-bold text-primary-600">
                    {Math.round(analysis.quality_score)}
                  </div>
                  <div className="text-sm text-gray-600">Quality Score</div>
                  <button
                    onClick={() => setActiveView('analysis')}
                    className="btn btn-primary w-full mt-3 text-sm"
                  >
                    View Details
                  </button>
                </div>
              )}
            </div>
          </div>
        )}

        {/* Analysis View */}
        {activeView === 'analysis' && analysis && (
          <AnalysisPanel analysis={analysis} />
        )}

        {/* Enhancement View */}
        {activeView === 'enhancement' && enhancement && (
          <EnhancementPanel
            enhancement={enhancement}
            onUse={handleUseEnhanced}
          />
        )}

        {/* Comparison View */}
        {activeView === 'comparison' && enhancement && (
          <ComparisonView
            original={enhancement.original_content}
            enhanced={enhancement.enhanced_content}
            qualityImprovement={enhancement.quality_improvement}
          />
        )}
      </div>
    </Layout>
  );
}
