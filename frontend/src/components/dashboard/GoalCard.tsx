import type { LearningGoal } from '../../types/dashboard';
import { CircularProgress } from './CircularProgress';

interface GoalCardProps {
  goal: LearningGoal;
  onUpdate: () => void;
}

export function GoalCard({ goal }: GoalCardProps) {
  const completedMilestones = goal.milestones?.filter(m => m.completed).length || 0;
  const totalMilestones = goal.milestones?.length || 0;

  return (
    <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-100 hover:shadow-md transition-shadow">
      <div className="flex items-start gap-4">
        {/* Progress Circle */}
        <CircularProgress percentage={goal.progress_percentage} size={60} />

        {/* Content */}
        <div className="flex-1">
          <div className="flex items-center gap-2 mb-1">
            <span className="text-xs font-medium text-indigo-600 uppercase tracking-wide">
              {goal.subject}
            </span>
            {goal.target_date && (
              <span className="text-xs text-gray-400">
                Due {new Date(goal.target_date).toLocaleDateString()}
              </span>
            )}
          </div>

          <h3 className="text-lg font-semibold text-gray-800 mb-2">{goal.title}</h3>

          {goal.description && (
            <p className="text-sm text-gray-600 mb-3">{goal.description}</p>
          )}

          {/* Milestones */}
          {totalMilestones > 0 && (
            <div className="mb-3">
              <div className="flex items-center gap-2 mb-2">
                <span className="text-xs text-gray-500">
                  {completedMilestones}/{totalMilestones} milestones
                </span>
              </div>
              <div className="flex gap-1">
                {goal.milestones?.map((milestone, i) => (
                  <div
                    key={i}
                    className={`h-2 flex-1 rounded-full ${
                      milestone.completed ? 'bg-green-500' : 'bg-gray-200'
                    }`}
                    title={milestone.title}
                  />
                ))}
              </div>
            </div>
          )}

          {/* Actions */}
          <div className="flex gap-2">
            <button
              onClick={() => window.location.href = `/practice?subject=${goal.subject}`}
              className="text-sm text-indigo-600 hover:text-indigo-700 font-medium"
            >
              Practice
            </button>
            <button
              onClick={() => window.location.href = `/chat?subject=${goal.subject}`}
              className="text-sm text-gray-600 hover:text-gray-700 font-medium"
            >
              Ask AI
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}


