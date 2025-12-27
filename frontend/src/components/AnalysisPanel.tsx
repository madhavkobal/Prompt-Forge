import { PromptAnalysis } from '@/types';
import {
  RadarChart,
  PolarGrid,
  PolarAngleAxis,
  PolarRadiusAxis,
  Radar,
  ResponsiveContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Cell,
} from 'recharts';
import { CheckCircle, XCircle, AlertCircle } from 'lucide-react';

interface AnalysisPanelProps {
  analysis: PromptAnalysis;
}

export default function AnalysisPanel({ analysis }: AnalysisPanelProps) {
  // Prepare data for radar chart
  const radarData = [
    { metric: 'Quality', score: analysis.quality_score },
    { metric: 'Clarity', score: analysis.clarity_score },
    { metric: 'Specificity', score: analysis.specificity_score },
    { metric: 'Structure', score: analysis.structure_score },
  ];

  // Prepare data for bar chart
  const barData = [
    { name: 'Quality', score: analysis.quality_score, fill: '#0ea5e9' },
    { name: 'Clarity', score: analysis.clarity_score, fill: '#10b981' },
    { name: 'Specificity', score: analysis.specificity_score, fill: '#f59e0b' },
    { name: 'Structure', score: analysis.structure_score, fill: '#8b5cf6' },
  ];

  const getScoreColor = (score: number) => {
    if (score >= 80) return 'text-green-600';
    if (score >= 60) return 'text-yellow-600';
    return 'text-red-600';
  };

  return (
    <div className="space-y-6">
      {/* Overall Score */}
      <div className="card">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">
          Overall Quality Score
        </h3>
        <div className="flex items-center justify-center">
          <div className="relative">
            <div
              className={`text-6xl font-bold ${getScoreColor(
                analysis.quality_score
              )}`}
            >
              {Math.round(analysis.quality_score)}
            </div>
            <div className="text-center text-gray-500 text-sm mt-2">/ 100</div>
          </div>
        </div>
      </div>

      {/* Score Breakdown - Bar Chart */}
      <div className="card">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">
          Score Breakdown
        </h3>
        <ResponsiveContainer width="100%" height={250}>
          <BarChart data={barData}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="name" />
            <YAxis domain={[0, 100]} />
            <Tooltip />
            <Bar dataKey="score" radius={[8, 8, 0, 0]}>
              {barData.map((entry, index) => (
                <Cell key={`cell-${index}`} fill={entry.fill} />
              ))}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>

      {/* Radar Chart */}
      <div className="card">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">
          Quality Radar
        </h3>
        <ResponsiveContainer width="100%" height={300}>
          <RadarChart data={radarData}>
            <PolarGrid />
            <PolarAngleAxis dataKey="metric" />
            <PolarRadiusAxis domain={[0, 100]} />
            <Radar
              name="Scores"
              dataKey="score"
              stroke="#0ea5e9"
              fill="#0ea5e9"
              fillOpacity={0.6}
            />
          </RadarChart>
        </ResponsiveContainer>
      </div>

      {/* Strengths */}
      {analysis.strengths && analysis.strengths.length > 0 && (
        <div className="card">
          <h3 className="text-lg font-semibold text-gray-900 mb-3 flex items-center">
            <CheckCircle className="h-5 w-5 text-green-600 mr-2" />
            Strengths
          </h3>
          <ul className="space-y-2">
            {analysis.strengths.map((strength, idx) => (
              <li key={idx} className="flex items-start">
                <span className="text-green-600 mr-2 mt-1">✓</span>
                <span className="text-gray-700">{strength}</span>
              </li>
            ))}
          </ul>
        </div>
      )}

      {/* Weaknesses */}
      {analysis.weaknesses && analysis.weaknesses.length > 0 && (
        <div className="card">
          <h3 className="text-lg font-semibold text-gray-900 mb-3 flex items-center">
            <XCircle className="h-5 w-5 text-red-600 mr-2" />
            Areas for Improvement
          </h3>
          <ul className="space-y-2">
            {analysis.weaknesses.map((weakness, idx) => (
              <li key={idx} className="flex items-start">
                <span className="text-red-600 mr-2 mt-1">✗</span>
                <span className="text-gray-700">{weakness}</span>
              </li>
            ))}
          </ul>
        </div>
      )}

      {/* Suggestions */}
      {analysis.suggestions && analysis.suggestions.length > 0 && (
        <div className="card">
          <h3 className="text-lg font-semibold text-gray-900 mb-3 flex items-center">
            <AlertCircle className="h-5 w-5 text-primary-600 mr-2" />
            Suggestions
          </h3>
          <ul className="space-y-2">
            {analysis.suggestions.map((suggestion, idx) => (
              <li key={idx} className="flex items-start">
                <span className="text-primary-600 mr-2 mt-1">→</span>
                <span className="text-gray-700">{suggestion}</span>
              </li>
            ))}
          </ul>
        </div>
      )}

      {/* Best Practices Compliance */}
      {analysis.best_practices && Object.keys(analysis.best_practices).length > 0 && (
        <div className="card">
          <h3 className="text-lg font-semibold text-gray-900 mb-3">
            Best Practices Compliance
          </h3>
          <div className="space-y-3">
            {Object.entries(analysis.best_practices).map(([key, value]) => {
              if (key === 'ambiguities' && Array.isArray(value)) {
                return (
                  <div key={key}>
                    <h4 className="text-sm font-medium text-gray-700 capitalize mb-2">
                      {key.replace(/_/g, ' ')}
                    </h4>
                    {value.length > 0 ? (
                      <ul className="space-y-1 ml-4">
                        {value.map((item, idx) => (
                          <li key={idx} className="text-sm text-orange-600">
                            ⚠ {item}
                          </li>
                        ))}
                      </ul>
                    ) : (
                      <p className="text-sm text-gray-500 ml-4">
                        No ambiguities detected
                      </p>
                    )}
                  </div>
                );
              }
              return (
                <div key={key} className="flex justify-between items-center">
                  <span className="text-sm font-medium text-gray-700 capitalize">
                    {key.replace(/_/g, ' ')}:
                  </span>
                  <span
                    className={`text-sm font-semibold ${
                      value === 'good' || value === 'excellent'
                        ? 'text-green-600'
                        : value === 'fair'
                        ? 'text-yellow-600'
                        : 'text-red-600'
                    }`}
                  >
                    {typeof value === 'string' ? value : JSON.stringify(value)}
                  </span>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}
