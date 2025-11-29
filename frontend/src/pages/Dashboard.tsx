import { useState, useEffect } from 'react';
import { api } from '../api/client';
import type { LearningGoal, LearningProfile, DashboardStats } from '../types/dashboard';
import { GoalCard } from '../components/dashboard/GoalCard';
import { ProgressOverview } from '../components/dashboard/ProgressOverview';
import { SubjectProgress } from '../components/dashboard/SubjectProgress';
import { GoalSuggestions } from '../components/dashboard/GoalSuggestions';
import { ActivityFeed } from '../components/dashboard/ActivityFeed';
import { CelebrationModal } from '../components/dashboard/CelebrationModal';

export default function DashboardPage() {
  const [goals, setGoals] = useState<LearningGoal[]>([]);
  const [profiles, setProfiles] = useState<LearningProfile[]>([]);
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [celebration, setCelebration] = useState<LearningGoal | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    loadDashboard();
    checkForCelebrations();
  }, []);

  const loadDashboard = async () => {
    setIsLoading(true);
    try {
      const [goalsRes, profilesRes, statsRes] = await Promise.all([
        api.get('/api/v1/learning_goals'),
        api.get('/api/v1/learning_profiles'),
        api.get('/api/v1/stats')
      ]);
      setGoals(goalsRes.data);
      setProfiles(profilesRes.data);
      setStats(statsRes.data);
    } finally {
      setIsLoading(false);
    }
  };

  const checkForCelebrations = async () => {
    const events = await api.get('/api/v1/student_events?type=goal_completed&acknowledged=false');
    if (events.data.length > 0) {
      const goalId = events.data[0].data.goal_id;
      const goal = goals.find(g => g.id === goalId);
      if (goal) setCelebration(goal);
    }
  };

  const activeGoals = goals.filter(g => g.status === 'active');
  const completedGoals = goals.filter(g => g.status === 'completed');
  const recentlyCompleted = completedGoals.find(g => g.suggested_next_goals?.length > 0);

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="animate-spin w-8 h-8 border-4 border-indigo-600 border-t-transparent rounded-full" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Celebration Modal */}
      {celebration && (
        <CelebrationModal
          goal={celebration}
          onClose={() => setCelebration(null)}
        />
      )}

      <div className="max-w-7xl mx-auto px-4 py-8">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-800">Learning Dashboard</h1>
          <p className="text-gray-600 mt-1">Track your progress across all subjects</p>
        </div>

        {/* Stats Overview */}
        {stats && <ProgressOverview stats={stats} />}

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 mt-8">
          {/* Main Content */}
          <div className="lg:col-span-2 space-y-8">
            {/* Active Goals */}
            <section>
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-xl font-semibold text-gray-800">Active Goals</h2>
                <button
                  onClick={() => window.location.href = '/goals/new'}
                  className="text-sm text-indigo-600 hover:text-indigo-700 font-medium"
                >
                  + Add Goal
                </button>
              </div>

              {activeGoals.length > 0 ? (
                <div className="space-y-4">
                  {activeGoals.map(goal => (
                    <GoalCard key={goal.id} goal={goal} onUpdate={loadDashboard} />
                  ))}
                </div>
              ) : (
                <div className="bg-white rounded-xl p-8 text-center">
                  <p className="text-gray-500">No active goals. Create one to start tracking!</p>
                  <button
                    onClick={() => window.location.href = '/goals/new'}
                    className="mt-4 px-4 py-2 bg-indigo-600 text-white rounded-lg"
                  >
                    Create Your First Goal
                  </button>
                </div>
              )}
            </section>

            {/* Subject Progress */}
            <section>
              <h2 className="text-xl font-semibold text-gray-800 mb-4">Subject Progress</h2>
              <SubjectProgress profiles={profiles} />
            </section>

            {/* Next Steps Suggestions */}
            {recentlyCompleted && (
              <section>
                <h2 className="text-xl font-semibold text-gray-800 mb-4">
                  Recommended Next Steps
                </h2>
                <GoalSuggestions
                  completedGoal={recentlyCompleted}
                  onCreateGoal={loadDashboard}
                />
              </section>
            )}
          </div>

          {/* Sidebar */}
          <div className="space-y-8">
            {/* Completed Goals */}
            <section>
              <h2 className="text-lg font-semibold text-gray-800 mb-4">
                Completed ({completedGoals.length})
              </h2>
              <div className="space-y-2">
                {completedGoals.slice(0, 5).map(goal => (
                  <div
                    key={goal.id}
                    className="bg-white rounded-lg p-3 border border-gray-200"
                  >
                    <div className="flex items-center gap-2">
                      <span className="text-green-500">✓</span>
                      <span className="text-sm font-medium text-gray-800">{goal.title}</span>
                    </div>
                    <span className="text-xs text-gray-500">{goal.subject}</span>
                  </div>
                ))}
              </div>
            </section>

            {/* Activity Feed */}
            <ActivityFeed />
          </div>
        </div>
      </div>
    </div>
  );
}


