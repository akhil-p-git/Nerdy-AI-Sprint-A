import type { LearningProfile } from '../../types/dashboard';

interface SubjectProgressProps {
  profiles: LearningProfile[];
}

const SUBJECT_ICONS: Record<string, string> = {
  mathematics: '📐',
  physics: '⚡',
  chemistry: '🧪',
  biology: '🧬',
  english: '📚',
  history: '🏛️',
  sat_prep: '📝',
  general: '💡'
};

export function SubjectProgress({ profiles }: SubjectProgressProps) {
  if (profiles.length === 0) {
    return (
      <div className="bg-white rounded-xl p-6 text-center text-gray-500">
        No subjects tracked yet. Start a conversation or practice to begin!
      </div>
    );
  }

  return (
    <div className="bg-white rounded-xl p-6 shadow-sm">
      <div className="space-y-4">
        {profiles.map((profile) => (
          <div key={profile.subject} className="border-b border-gray-100 pb-4 last:border-0 last:pb-0">
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center gap-2">
                <span className="text-xl">
                  {SUBJECT_ICONS[profile.subject] || '📚'}
                </span>
                <span className="font-medium text-gray-800 capitalize">
                  {profile.subject.replace('_', ' ')}
                </span>
              </div>
              <span className="text-sm font-medium text-indigo-600">
                Level {profile.proficiency_level}/10
              </span>
            </div>

            {/* Proficiency Bar */}
            <div className="w-full h-2 bg-gray-100 rounded-full mb-3">
              <div
                className="h-full bg-indigo-600 rounded-full transition-all duration-500"
                style={{ width: `${profile.proficiency_level * 10}%` }}
              />
            </div>

            {/* Strengths & Weaknesses */}
            <div className="flex gap-4 text-xs">
              {profile.strengths?.length > 0 && (
                <div>
                  <span className="text-gray-500">Strengths: </span>
                  <span className="text-green-600">{profile.strengths.slice(0, 2).join(', ')}</span>
                </div>
              )}
              {profile.weaknesses?.length > 0 && (
                <div>
                  <span className="text-gray-500">To improve: </span>
                  <span className="text-orange-600">{profile.weaknesses.slice(0, 2).join(', ')}</span>
                </div>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}


