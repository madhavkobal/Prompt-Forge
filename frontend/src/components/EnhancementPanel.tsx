import { PromptEnhancement } from '@/types';
import { TrendingUp, Copy, Check } from 'lucide-react';
import { useState } from 'react';
import toast from 'react-hot-toast';

interface EnhancementPanelProps {
  enhancement: PromptEnhancement;
  onUse?: (enhancedContent: string) => void;
}

export default function EnhancementPanel({
  enhancement,
  onUse,
}: EnhancementPanelProps) {
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(enhancement.enhanced_content);
      setCopied(true);
      toast.success('Enhanced prompt copied to clipboard!');
      setTimeout(() => setCopied(false), 2000);
    } catch (error) {
      toast.error('Failed to copy to clipboard');
    }
  };

  const handleUse = () => {
    if (onUse) {
      onUse(enhancement.enhanced_content);
      toast.success('Enhanced prompt loaded into editor');
    }
  };

  return (
    <div className="space-y-4">
      {/* Header with improvement percentage */}
      <div className="card bg-gradient-to-r from-primary-50 to-primary-100">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-2">
            <TrendingUp className="h-6 w-6 text-primary-600" />
            <h3 className="text-lg font-semibold text-gray-900">
              Enhanced Version
            </h3>
          </div>
          <div className="badge badge-success text-lg font-bold">
            +{Math.round(enhancement.quality_improvement)}%
          </div>
        </div>
        <p className="text-sm text-gray-600 mt-2">
          Quality improvement estimated
        </p>
      </div>

      {/* Enhanced Content */}
      <div className="card">
        <div className="flex justify-between items-start mb-3">
          <h4 className="text-md font-semibold text-gray-900">
            Enhanced Prompt
          </h4>
          <div className="flex space-x-2">
            <button
              onClick={handleCopy}
              className="btn btn-secondary p-2"
              title="Copy to clipboard"
            >
              {copied ? (
                <Check className="h-4 w-4 text-green-600" />
              ) : (
                <Copy className="h-4 w-4" />
              )}
            </button>
            {onUse && (
              <button
                onClick={handleUse}
                className="btn btn-primary text-sm"
              >
                Use This Version
              </button>
            )}
          </div>
        </div>
        <div className="bg-gray-50 p-4 rounded-lg border border-gray-200">
          <pre className="whitespace-pre-wrap font-sans text-gray-800 leading-relaxed">
            {enhancement.enhanced_content}
          </pre>
        </div>
      </div>

      {/* Improvements Made */}
      {enhancement.improvements && enhancement.improvements.length > 0 && (
        <div className="card">
          <h4 className="text-md font-semibold text-gray-900 mb-3">
            Improvements Made
          </h4>
          <ul className="space-y-2">
            {enhancement.improvements.map((improvement, idx) => (
              <li key={idx} className="flex items-start">
                <span className="inline-block w-6 h-6 rounded-full bg-primary-100 text-primary-600 text-xs flex items-center justify-center mr-2 mt-0.5 flex-shrink-0">
                  {idx + 1}
                </span>
                <span className="text-gray-700">{improvement}</span>
              </li>
            ))}
          </ul>
        </div>
      )}

      {/* Original for Reference */}
      <div className="card bg-gray-50">
        <h4 className="text-md font-semibold text-gray-900 mb-3">
          Original Prompt
        </h4>
        <div className="bg-white p-4 rounded-lg border border-gray-200">
          <pre className="whitespace-pre-wrap font-sans text-gray-600 text-sm">
            {enhancement.original_content}
          </pre>
        </div>
      </div>
    </div>
  );
}
