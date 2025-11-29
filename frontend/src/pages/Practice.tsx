import { usePractice } from '../hooks/usePractice';
import { PracticeSetup } from '../components/practice/PracticeSetup';
import { QuizCard } from '../components/practice/QuizCard';
import { FlashCard } from '../components/practice/FlashCard';
import { SessionComplete } from '../components/practice/SessionComplete';
import { ProgressBar } from '../components/practice/ProgressBar';
import type { Problem } from '../types/practice';

export default function PracticePage() {
  const practice = usePractice();
  const { session, sessionResult, currentProblem, currentProblemIndex, isLoading, lastResult } = practice;

  // Compute derived values
  const progress = session ? ((currentProblemIndex + 1) / session.problems.length) * 100 : 0;
  const isLastProblem = session ? currentProblemIndex >= session.problems.length - 1 : false;
  const canProceed = lastResult !== null;

  // Show setup if no session
  if (!session) {
    return <PracticeSetup onStart={practice.startSession} isLoading={isLoading} />;
  }

  // Show results if complete
  if (sessionResult) {
    return <SessionComplete result={sessionResult} onNewSession={() => window.location.reload()} />;
  }

  return (
    <div className="min-h-screen bg-gradient-to-b from-indigo-50 to-white">
      <div className="max-w-3xl mx-auto px-4 py-8">
        {/* Header */}
        <div className="mb-8">
          <div className="flex items-center justify-between mb-4">
            <h1 className="text-2xl font-bold text-gray-800">
              {session.subject} Practice
            </h1>
            <span className="text-sm text-gray-500">
              {currentProblemIndex + 1} of {session.problems.length}
            </span>
          </div>
          <ProgressBar progress={progress} />
        </div>

        {/* Current Problem */}
        {currentProblem && (
          session.session_type === 'flashcards' ? (
            <FlashCard problem={currentProblem as Problem} practice={practice} />
          ) : (
            <QuizCard problem={currentProblem as Problem} practice={practice} />
          )
        )}

        {/* Navigation */}
        <div className="flex justify-between mt-8">
          <button
            disabled={currentProblemIndex === 0}
            className="px-4 py-2 text-gray-600 hover:text-gray-800 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            ← Previous
          </button>

          {isLastProblem && canProceed ? (
            <button
              onClick={practice.completeSession}
              disabled={isLoading}
              className="px-6 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50"
            >
              {isLoading ? 'Finishing...' : 'Complete Session'}
            </button>
          ) : (
            <button
              onClick={practice.nextProblem}
              disabled={!canProceed}
              className="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Next →
            </button>
          )}
        </div>
      </div>
    </div>
  );
}


