import { useState, useEffect } from 'react';
import { promptService } from '@/services/promptService';
import { Prompt } from '@/types';
import { formatDate, getScoreBadge } from '@/utils/helpers';
import toast from 'react-hot-toast';
import Layout from '@/components/Layout';
import { Trash2, Eye } from 'lucide-react';

export default function Prompts() {
  const [prompts, setPrompts] = useState<Prompt[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedPrompt, setSelectedPrompt] = useState<Prompt | null>(null);

  useEffect(() => {
    loadPrompts();
  }, []);

  const loadPrompts = async () => {
    try {
      const data = await promptService.getPrompts();
      setPrompts(data);
    } catch (error: any) {
      toast.error('Failed to load prompts');
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (id: number) => {
    if (!confirm('Are you sure you want to delete this prompt?')) return;

    try {
      await promptService.deletePrompt(id);
      setPrompts(prompts.filter((p) => p.id !== id));
      toast.success('Prompt deleted');
    } catch (error: any) {
      toast.error('Failed to delete prompt');
    }
  };

  return (
    <Layout>
      <div className="space-y-6">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">My Prompts</h1>
          <p className="text-gray-600 mt-1">Manage your analyzed prompts</p>
        </div>

        {loading ? (
          <div className="text-center py-12">
            <div className="text-gray-500">Loading...</div>
          </div>
        ) : prompts.length === 0 ? (
          <div className="card text-center py-12">
            <p className="text-gray-500">No prompts yet. Start analyzing!</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 gap-4">
            {prompts.map((prompt) => (
              <div key={prompt.id} className="card hover:shadow-lg transition-shadow">
                <div className="flex justify-between items-start">
                  <div className="flex-1">
                    <h3 className="text-lg font-semibold text-gray-900">
                      {prompt.title || 'Untitled'}
                    </h3>
                    <p className="text-gray-600 text-sm mt-1 line-clamp-2">
                      {prompt.content}
                    </p>
                    <div className="flex items-center space-x-4 mt-3">
                      {prompt.quality_score && (
                        <span className={`badge ${getScoreBadge(prompt.quality_score)}`}>
                          Score: {Math.round(prompt.quality_score)}%
                        </span>
                      )}
                      {prompt.target_llm && (
                        <span className="badge badge-info">{prompt.target_llm}</span>
                      )}
                      <span className="text-xs text-gray-500">
                        {formatDate(prompt.created_at)}
                      </span>
                    </div>
                  </div>
                  <div className="flex space-x-2 ml-4">
                    <button
                      onClick={() => setSelectedPrompt(prompt)}
                      className="btn btn-secondary p-2"
                    >
                      <Eye className="h-4 w-4" />
                    </button>
                    <button
                      onClick={() => handleDelete(prompt.id)}
                      className="btn btn-danger p-2"
                    >
                      <Trash2 className="h-4 w-4" />
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}

        {/* Prompt Detail Modal */}
        {selectedPrompt && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
            <div className="bg-white rounded-lg max-w-2xl w-full max-h-[90vh] overflow-y-auto p-6">
              <h2 className="text-2xl font-bold text-gray-900 mb-4">
                {selectedPrompt.title || 'Untitled'}
              </h2>
              <div className="space-y-4">
                <div>
                  <h3 className="font-semibold text-gray-700 mb-2">Original Content</h3>
                  <div className="bg-gray-50 p-4 rounded-lg">
                    <p className="text-gray-800 whitespace-pre-wrap">
                      {selectedPrompt.content}
                    </p>
                  </div>
                </div>
                {selectedPrompt.enhanced_content && (
                  <div>
                    <h3 className="font-semibold text-gray-700 mb-2">
                      Enhanced Content
                    </h3>
                    <div className="bg-primary-50 p-4 rounded-lg">
                      <p className="text-gray-800 whitespace-pre-wrap">
                        {selectedPrompt.enhanced_content}
                      </p>
                    </div>
                  </div>
                )}
                <button
                  onClick={() => setSelectedPrompt(null)}
                  className="btn btn-secondary w-full"
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </Layout>
  );
}
