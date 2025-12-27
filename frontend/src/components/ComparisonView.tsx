import { ArrowRight, TrendingUp } from 'lucide-react';
import PromptEditor from './PromptEditor';

interface ComparisonViewProps {
  original: string;
  enhanced: string;
  qualityImprovement?: number;
}

export default function ComparisonView({
  original,
  enhanced,
  qualityImprovement,
}: ComparisonViewProps) {
  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="card bg-gradient-to-r from-primary-50 to-primary-100">
        <div className="flex items-center justify-between">
          <h3 className="text-xl font-semibold text-gray-900">
            Side-by-Side Comparison
          </h3>
          {qualityImprovement !== undefined && (
            <div className="flex items-center space-x-2">
              <TrendingUp className="h-5 w-5 text-green-600" />
              <span className="text-lg font-bold text-green-600">
                +{Math.round(qualityImprovement)}% Improvement
              </span>
            </div>
          )}
        </div>
      </div>

      {/* Side-by-Side Editors */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {/* Original */}
        <div className="space-y-2">
          <div className="flex items-center space-x-2">
            <div className="h-2 w-2 rounded-full bg-gray-400"></div>
            <h4 className="text-md font-semibold text-gray-700">
              Original Prompt
            </h4>
          </div>
          <div className="relative">
            <PromptEditor
              value={original}
              onChange={() => {}}
              height="500px"
              readOnly
            />
            <div className="absolute top-2 right-2 bg-gray-600 text-white px-2 py-1 rounded text-xs">
              BEFORE
            </div>
          </div>
        </div>

        {/* Arrow Indicator (Hidden on mobile) */}
        <div className="hidden lg:flex items-center justify-center absolute left-1/2 top-1/2 transform -translate-x-1/2 -translate-y-1/2 z-10">
          <div className="bg-white rounded-full p-3 shadow-lg border-2 border-primary-200">
            <ArrowRight className="h-8 w-8 text-primary-600" />
          </div>
        </div>

        {/* Enhanced */}
        <div className="space-y-2">
          <div className="flex items-center space-x-2">
            <div className="h-2 w-2 rounded-full bg-green-500"></div>
            <h4 className="text-md font-semibold text-gray-700">
              Enhanced Prompt
            </h4>
          </div>
          <div className="relative">
            <PromptEditor
              value={enhanced}
              onChange={() => {}}
              height="500px"
              readOnly
            />
            <div className="absolute top-2 right-2 bg-green-600 text-white px-2 py-1 rounded text-xs">
              AFTER
            </div>
          </div>
        </div>
      </div>

      {/* Mobile Arrow */}
      <div className="lg:hidden flex justify-center">
        <div className="bg-primary-100 rounded-full p-2">
          <ArrowRight className="h-6 w-6 text-primary-600 transform rotate-90" />
        </div>
      </div>

      {/* Difference Summary */}
      <div className="card bg-blue-50">
        <h4 className="text-md font-semibold text-gray-900 mb-2">
          Key Differences
        </h4>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="text-center">
            <div className="text-2xl font-bold text-gray-700">
              {original.length}
            </div>
            <div className="text-sm text-gray-600">Original Length</div>
          </div>
          <div className="text-center">
            <div className="text-2xl font-bold text-gray-700">
              →
            </div>
            <div className="text-sm text-gray-600">Transform</div>
          </div>
          <div className="text-center">
            <div className="text-2xl font-bold text-green-600">
              {enhanced.length}
            </div>
            <div className="text-sm text-gray-600">Enhanced Length</div>
          </div>
        </div>
        <div className="mt-4 text-center">
          <span className="text-sm text-gray-600">
            Character difference:{' '}
            <span className="font-semibold text-primary-600">
              {enhanced.length > original.length ? '+' : ''}
              {enhanced.length - original.length}
            </span>
          </span>
        </div>
      </div>
    </div>
  );
}
