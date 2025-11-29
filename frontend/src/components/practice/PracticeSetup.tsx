import { useState } from 'react';

interface PracticeSetupProps {
  onStart: (subject: string, type: 'quiz' | 'flashcards', numProblems: number) => Promise<any>;
  isLoading: boolean;
}

const SUBJECTS = [
  { id: 'mathematics', name: 'Mathematics', icon: '📐', color: 'bg-blue-500' },
  { id: 'physics', name: 'Physics', icon: '⚡', color: 'bg-purple-500' },
  { id: 'chemistry', name: 'Chemistry', icon: '🧪', color: 'bg-green-500' },
  { id: 'biology', name: 'Biology', icon: '🧬', color: 'bg-pink-500' },
  { id: 'english', name: 'English', icon: '📚', color: 'bg-yellow-500' },
  { id: 'history', name: 'History', icon: '🏛️', color: 'bg-orange-500' },
  { id: 'sat_prep', name: 'SAT Prep', icon: '📝', color: 'bg-red-500' }
];

export function PracticeSetup({ onStart, isLoading }: PracticeSetupProps) {
  const [subject, setSubject] = useState<string | null>(null);
  const [type, setType] = useState<'quiz' | 'flashcards'>('quiz');
  const [numProblems, setNumProblems] = useState(10);

  const handleStart = () => {
    if (subject) {
      onStart(subject, type, numProblems);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-b from-indigo-50 to-white">
      <div className="max-w-2xl mx-auto px-4 py-12">
        <div className="text-center mb-10">
          <h1 className="text-3xl font-bold text-gray-800 mb-2">Practice Mode</h1>
          <p className="text-gray-600">Choose a subject and start practicing!</p>
        </div>

        {/* Subject Selection */}
        <div className="mb-8">
          <h2 className="text-lg font-semibold text-gray-700 mb-4">Select Subject</h2>
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
            {SUBJECTS.map((s) => (
              <button
                key={s.id}
                onClick={() => setSubject(s.id)}
                className={`p-4 rounded-xl border-2 transition-all ${
                  subject === s.id
                    ? 'border-indigo-500 bg-indigo-50 shadow-md'
                    : 'border-gray-200 hover:border-gray-300 bg-white'
                }`}
              >
                <span className="text-2xl mb-2 block">{s.icon}</span>
                <span className="font-medium text-gray-800">{s.name}</span>
              </button>
            ))}
          </div>
        </div>

        {/* Practice Type */}
        <div className="mb-8">
          <h2 className="text-lg font-semibold text-gray-700 mb-4">Practice Type</h2>
          <div className="flex gap-4">
            <button
              onClick={() => setType('quiz')}
              className={`flex-1 p-4 rounded-xl border-2 transition-all ${
                type === 'quiz'
                  ? 'border-indigo-500 bg-indigo-50'
                  : 'border-gray-200 hover:border-gray-300 bg-white'
              }`}
            >
              <span className="text-2xl mb-2 block">📋</span>
              <span className="font-medium">Quiz</span>
              <p className="text-xs text-gray-500 mt-1">Multiple choice questions</p>
            </button>
            <button
              onClick={() => setType('flashcards')}
              className={`flex-1 p-4 rounded-xl border-2 transition-all ${
                type === 'flashcards'
                  ? 'border-indigo-500 bg-indigo-50'
                  : 'border-gray-200 hover:border-gray-300 bg-white'
              }`}
            >
              <span className="text-2xl mb-2 block">🃏</span>
              <span className="font-medium">Flashcards</span>
              <p className="text-xs text-gray-500 mt-1">Study and self-assess</p>
            </button>
          </div>
        </div>

        {/* Number of Problems */}
        <div className="mb-10">
          <h2 className="text-lg font-semibold text-gray-700 mb-4">Number of Questions</h2>
          <div className="flex gap-3">
            {[5, 10, 15, 20].map((num) => (
              <button
                key={num}
                onClick={() => setNumProblems(num)}
                className={`flex-1 py-3 rounded-lg border-2 font-medium transition-all ${
                  numProblems === num
                    ? 'border-indigo-500 bg-indigo-50 text-indigo-700'
                    : 'border-gray-200 hover:border-gray-300 text-gray-700'
                }`}
              >
                {num}
              </button>
            ))}
          </div>
        </div>

        {/* Start Button */}
        <button
          onClick={handleStart}
          disabled={!subject || isLoading}
          className="w-full py-4 bg-indigo-600 text-white rounded-xl font-semibold text-lg hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors shadow-lg"
        >
          {isLoading ? (
            <span className="flex items-center justify-center gap-2">
              <svg className="animate-spin w-5 h-5" viewBox="0 0 24 24">
                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" />
                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
              </svg>
              Generating Questions...
            </span>
          ) : (
            'Start Practice'
          )}
        </button>
      </div>
    </div>
  );
}


