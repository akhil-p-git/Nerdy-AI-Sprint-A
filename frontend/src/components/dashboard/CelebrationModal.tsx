import { useEffect } from 'react';
import confetti from 'canvas-confetti';
import type { LearningGoal } from '../../types/dashboard';
import { api } from '../../api/client';

interface CelebrationModalProps {
  goal: LearningGoal;
  onClose: () => void;
}

export function CelebrationModal({ goal, onClose }: CelebrationModalProps) {
  useEffect(() => {
    // Trigger confetti
    confetti({
      particleCount: 150,
      spread: 100,
      origin: { y: 0.6 }
    });

    // Acknowledge event
    api.post('/api/v1/student_events/acknowledge', {
      event_type: 'goal_completed',
      goal_id: goal.id
    });
  }, [goal.id]);

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
      <div className="bg-white rounded-2xl p-8 max-w-md mx-4 text-center animate-bounce-in">
        <div className="text-6xl mb-4">🎉</div>
        <h2 className="text-2xl font-bold text-gray-800 mb-2">Goal Achieved!</h2>
        <p className="text-gray-600 mb-6">
          You've completed <span className="font-semibold">{goal.title}</span>
        </p>

        {goal.suggested_next_goals && goal.suggested_next_goals.length > 0 && (
          <div className="mb-6">
            <p className="text-sm text-gray-500 mb-3">Ready for your next challenge?</p>
            <div className="space-y-2">
              {goal.suggested_next_goals.slice(0, 2).map((suggestion, i) => (
                <button
                  key={i}
                  className="w-full p-3 text-left bg-indigo-50 rounded-lg hover:bg-indigo-100 transition-colors"
                >
                  <span className="font-medium text-indigo-700 capitalize">
                    {suggestion.subject.replace('_', ' ')}
                  </span>
                  <span className="text-xs text-indigo-500 block">{suggestion.reason}</span>
                </button>
              ))}
            </div>
          </div>
        )}

        <button
          onClick={onClose}
          className="w-full py-3 bg-indigo-600 text-white rounded-xl font-medium hover:bg-indigo-700 transition-colors"
        >
          Continue Learning
        </button>
      </div>
    </div>
  );
}


