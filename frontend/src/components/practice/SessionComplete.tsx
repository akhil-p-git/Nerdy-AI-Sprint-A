import { useEffect } from 'react';
import confetti from 'canvas-confetti';
import type { SessionResult } from '../../types/practice';

interface SessionCompleteProps {
  result: SessionResult;
  onNewSession: () => void;
}

export function SessionComplete({ result, onNewSession }: SessionCompleteProps) {
  useEffect(() => {
    if (result.accuracy >= 70) {
      confetti({
        particleCount: 200,
        spread: 100,
        origin: { y: 0.6 }
      });
    }
  }, [result.accuracy]);

  const getMessage = () => {
    if (result.accuracy >= 90) return { emoji: '🏆', text: 'Outstanding!' };
    if (result.accuracy >= 80) return { emoji: '🌟', text: 'Excellent work!' };
    if (result.accuracy >= 70) return { emoji: '👏', text: 'Great job!' };
    if (result.accuracy >= 60) return { emoji: '💪', text: 'Good effort!' };
    return { emoji: '📚', text: 'Keep practicing!' };
  };

  const message = getMessage();

  return (
    <div className="min-h-screen bg-gradient-to-b from-indigo-50 to-white flex items-center justify-center">
      <div className="max-w-md w-full mx-4">
        <div className="bg-white rounded-2xl shadow-lg p-8 text-center">
          <div className="text-6xl mb-4">{message.emoji}</div>
          <h1 className="text-2xl font-bold text-gray-800 mb-2">{message.text}</h1>
          <p className="text-gray-600 mb-8">You've completed this practice session</p>

          {/* Stats */}
          <div className="grid grid-cols-3 gap-4 mb-8">
            <div className="bg-gray-50 rounded-xl p-4">
              <div className="text-3xl font-bold text-indigo-600">{result.accuracy}%</div>
              <div className="text-xs text-gray-500 mt-1">Accuracy</div>
            </div>
            <div className="bg-gray-50 rounded-xl p-4">
              <div className="text-3xl font-bold text-green-600">{result.correct}</div>
              <div className="text-xs text-gray-500 mt-1">Correct</div>
            </div>
            <div className="bg-gray-50 rounded-xl p-4">
              <div className="text-3xl font-bold text-gray-600">{result.total}</div>
              <div className="text-xs text-gray-500 mt-1">Total</div>
            </div>
          </div>

          {/* Proficiency Update */}
          <div className="bg-indigo-50 rounded-xl p-4 mb-6">
            <div className="text-sm text-indigo-600 font-medium mb-2">Proficiency Level</div>
            <div className="flex items-center justify-center gap-1">
              {[...Array(10)].map((_, i) => (
                <div
                  key={i}
                  className={`w-4 h-4 rounded-full ${
                    i < result.new_proficiency ? 'bg-indigo-600' : 'bg-indigo-200'
                  }`}
                />
              ))}
            </div>
            <div className="text-xs text-indigo-500 mt-2">Level {result.new_proficiency}/10</div>
          </div>

          {/* Struggled Topics */}
          {result.struggled_topics.length > 0 && (
            <div className="text-left mb-6">
              <div className="text-sm font-medium text-gray-700 mb-2">Topics to review:</div>
              <div className="flex flex-wrap gap-2">
                {result.struggled_topics.map((topic, i) => (
                  <span key={i} className="px-3 py-1 bg-orange-100 text-orange-700 rounded-full text-sm">
                    {topic}
                  </span>
                ))}
              </div>
            </div>
          )}

          {/* Actions */}
          <div className="flex gap-3">
            <button
              onClick={onNewSession}
              className="flex-1 py-3 bg-indigo-600 text-white rounded-xl font-medium hover:bg-indigo-700 transition-colors"
            >
              Practice Again
            </button>
            <button
              onClick={() => window.location.href = '/dashboard'}
              className="flex-1 py-3 border-2 border-gray-200 text-gray-700 rounded-xl font-medium hover:border-gray-300 transition-colors"
            >
              View Dashboard
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}


