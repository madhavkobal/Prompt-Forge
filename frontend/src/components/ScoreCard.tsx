import { getScoreBadge } from '@/utils/helpers';

interface ScoreCardProps {
  title: string;
  score: number;
  description?: string;
}

export default function ScoreCard({ title, score, description }: ScoreCardProps) {
  const percentage = Math.round(score);

  return (
    <div className="card">
      <div className="flex justify-between items-start mb-2">
        <h3 className="text-sm font-medium text-gray-700">{title}</h3>
        <span className={`badge ${getScoreBadge(percentage)}`}>{percentage}%</span>
      </div>
      <div className="w-full bg-gray-200 rounded-full h-2 mb-2">
        <div
          className={`h-2 rounded-full transition-all duration-500 ${
            percentage >= 80
              ? 'bg-green-600'
              : percentage >= 60
              ? 'bg-yellow-600'
              : 'bg-red-600'
          }`}
          style={{ width: `${percentage}%` }}
        />
      </div>
      {description && <p className="text-xs text-gray-500">{description}</p>}
    </div>
  );
}
