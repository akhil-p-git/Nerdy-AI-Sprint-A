import { api } from '../../api/client';
import type { LearningGoal } from '../../types/dashboard';

interface GoalSuggestionsProps {
  completedGoal: LearningGoal;
  onCreateGoal: () => void;
}

export function GoalSuggestions({ completedGoal, onCreateGoal }: GoalSuggestionsProps) {
  const handleCreateGoal = async (suggestion: any) => {
    await api.post('/api/v1/learning_goals', {
      subject: suggestion.subject,
      title: `Master ${suggestion.subject.replace('_', ' ')}`,
      description: suggestion.reason
    });
    onCreateGoal();
  };

  return (
    <div className="bg-gradient-to-r from-indigo-50 to-purple-50 rounded-xl p-6">
      <div className="flex items-center gap-2 mb-4">
        <span className="text-2xl">🎉</span>
        <div>
          <h3 className="font-semibold text-gray-800">
            Congratulations on completing "{completedGoal.title}"!
          </h3>
          <p className="text-sm text-gray-600">Here's what we suggest next:</p>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
        {completedGoal.suggested_next_goals?.map((suggestion, index) => (
          <div
            key={index}
            className="bg-white rounded-lg p-4 border border-gray-200 hover:border-indigo-300 transition-colors"
          >
            <h4 className="font-medium text-gray-800 capitalize mb-1">
              {suggestion.subject.replace('_', ' ')}
            </h4>
            <p className="text-sm text-gray-600 mb-3">{suggestion.reason}</p>
            <button
              onClick={() => handleCreateGoal(suggestion)}
              className="text-sm text-indigo-600 hover:text-indigo-700 font-medium"
            >
              Start this goal →
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}


