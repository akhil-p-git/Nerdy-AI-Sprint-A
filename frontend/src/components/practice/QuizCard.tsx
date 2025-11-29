import { useState } from 'react';
import type { Problem } from '../../types/practice';
import { usePractice } from '../../hooks/usePractice';
import confetti from 'canvas-confetti';

interface QuizCardProps {
  problem: Problem;
  practice: ReturnType<typeof usePractice>;
}

export function QuizCard({ problem, practice }: QuizCardProps) {
  const [selectedAnswer, setSelectedAnswer] = useState<string | null>(null);
  const { lastResult, isLoading, submitAnswer } = practice;
  const showExplanation = true; // Always show explanation when available

  const handleSubmit = async () => {
    if (!selectedAnswer) return;

    const result = await submitAnswer(selectedAnswer);

    if (result?.is_correct) {
      confetti({
        particleCount: 100,
        spread: 70,
        origin: { y: 0.6 }
      });
    }
  };

  const getOptionStyle = (option: string) => {
    if (!lastResult) {
      return selectedAnswer === option
        ? 'border-indigo-500 bg-indigo-50'
        : 'border-gray-200 hover:border-gray-300';
    }

    if (option === lastResult.correct_answer) {
      return 'border-green-500 bg-green-50';
    }

    if (selectedAnswer === option && !lastResult.is_correct) {
      return 'border-red-500 bg-red-50';
    }

    return 'border-gray-200 opacity-50';
  };

  return (
    <div className="bg-white rounded-2xl shadow-lg p-6">
      {/* Difficulty Badge */}
      <div className="flex items-center justify-between mb-4">
        <span className="text-xs font-medium text-gray-500 uppercase tracking-wide">
          {problem.topic}
        </span>
        <div className="flex items-center gap-1">
          {[...Array(10)].map((_, i) => (
            <div
              key={i}
              className={`w-2 h-2 rounded-full ${
                i < problem.difficulty ? 'bg-indigo-500' : 'bg-gray-200'
              }`}
            />
          ))}
        </div>
      </div>

      {/* Question */}
      <h2 className="text-xl font-semibold text-gray-800 mb-6">
        {problem.question}
      </h2>

      {/* Options */}
      <div className="space-y-3 mb-6">
        {problem.options.map((option, index) => (
          <button
            key={index}
            onClick={() => !lastResult && setSelectedAnswer(option)}
            disabled={!!lastResult}
            className={`w-full p-4 text-left rounded-xl border-2 transition-all ${getOptionStyle(option)}`}
          >
            <span className="font-medium text-gray-500 mr-3">
              {String.fromCharCode(65 + index)}.
            </span>
            <span className="text-gray-800">{option}</span>

            {lastResult && option === lastResult.correct_answer && (
              <span className="float-right text-green-600">✓</span>
            )}
            {lastResult && selectedAnswer === option && !lastResult.is_correct && (
              <span className="float-right text-red-600">✗</span>
            )}
          </button>
        ))}
      </div>

      {/* Submit or Result */}
      {!lastResult ? (
        <button
          onClick={handleSubmit}
          disabled={!selectedAnswer || isLoading}
          className="w-full py-3 bg-indigo-600 text-white rounded-xl font-medium hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        >
          {isLoading ? 'Checking...' : 'Submit Answer'}
        </button>
      ) : (
        <div className={`p-4 rounded-xl ${lastResult.is_correct ? 'bg-green-50' : 'bg-red-50'}`}>
          <div className="flex items-center gap-2 mb-2">
            {lastResult.is_correct ? (
              <>
                <span className="text-2xl">🎉</span>
                <span className="font-semibold text-green-700">Correct!</span>
              </>
            ) : (
              <>
                <span className="text-2xl">💪</span>
                <span className="font-semibold text-red-700">Not quite</span>
              </>
            )}
          </div>

          {showExplanation && (
            <div className="mt-3 pt-3 border-t border-gray-200">
              <p className="text-sm text-gray-600 mb-2">{lastResult.feedback}</p>
              <p className="text-sm text-gray-700">
                <span className="font-medium">Explanation:</span> {lastResult.explanation}
              </p>
            </div>
          )}
        </div>
      )}
    </div>
  );
}


