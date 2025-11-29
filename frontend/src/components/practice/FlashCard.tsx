import { useState } from 'react';
import type { Problem } from '../../types/practice';
import { usePractice } from '../../hooks/usePractice';

interface FlashCardProps {
  problem: Problem;
  practice: ReturnType<typeof usePractice>;
}

export function FlashCard({ problem, practice }: FlashCardProps) {
  const [isFlipped, setIsFlipped] = useState(false);
  const { submitAnswer, lastResult, isLoading } = practice;

  const handleFlip = () => {
    setIsFlipped(!isFlipped);
  };

  const handleSelfAssess = async (correct: boolean) => {
    await submitAnswer(correct ? (problem.correct_answer || 'correct') : 'incorrect');
  };

  return (
    <div className="perspective-1000">
      <div
        onClick={!isFlipped && !lastResult ? handleFlip : undefined}
        className={`relative w-full h-80 cursor-pointer transition-transform duration-500 transform-style-preserve-3d ${
          isFlipped ? 'rotate-y-180' : ''
        }`}
        style={{
          transformStyle: 'preserve-3d',
          transform: isFlipped ? 'rotateY(180deg)' : 'rotateY(0)'
        }}
      >
        {/* Front */}
        <div
          className="absolute inset-0 bg-white rounded-2xl shadow-lg p-6 flex flex-col items-center justify-center backface-hidden"
          style={{ backfaceVisibility: 'hidden' }}
        >
          <span className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-4">
            {problem.topic}
          </span>
          <h2 className="text-xl font-semibold text-gray-800 text-center">
            {problem.question}
          </h2>
          <p className="text-sm text-gray-400 mt-6">Click to reveal answer</p>
        </div>

        {/* Back */}
        <div
          className="absolute inset-0 bg-indigo-600 rounded-2xl shadow-lg p-6 flex flex-col items-center justify-center text-white rotate-y-180"
          style={{ backfaceVisibility: 'hidden', transform: 'rotateY(180deg)' }}
        >
          <span className="text-xs font-medium text-indigo-200 uppercase tracking-wide mb-4">
            Answer
          </span>
          <h2 className="text-xl font-semibold text-center mb-6">
            {problem.correct_answer}
          </h2>

          {!lastResult && (
            <div className="mt-4">
              <p className="text-sm text-indigo-200 mb-3 text-center">Did you get it right?</p>
              <div className="flex gap-3">
                <button
                  onClick={() => handleSelfAssess(false)}
                  disabled={isLoading}
                  className="px-6 py-2 bg-red-500 rounded-lg hover:bg-red-600 transition-colors disabled:opacity-50"
                >
                  ✗ No
                </button>
                <button
                  onClick={() => handleSelfAssess(true)}
                  disabled={isLoading}
                  className="px-6 py-2 bg-green-500 rounded-lg hover:bg-green-600 transition-colors disabled:opacity-50"
                >
                  ✓ Yes
                </button>
              </div>
            </div>
          )}

          {lastResult && (
            <div className={`mt-4 px-4 py-2 rounded-lg ${
              lastResult.is_correct ? 'bg-green-500' : 'bg-red-500'
            }`}>
              {lastResult.is_correct ? '🎉 Great job!' : '💪 Keep practicing!'}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}


