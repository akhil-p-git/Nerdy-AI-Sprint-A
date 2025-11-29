import { useState, useEffect } from 'react';
import { api } from '../api/client';

interface StudentSummary {
  id: number;
  name: string;
  summary: {
    total_sessions_this_month: number;
    practice_problems_this_week: number;
    average_accuracy: number;
    active_goals: number;
    current_streak: number;
    engagement_score: number;
  };
  recent_activity: Array<{
    type: string;
    description: string;
    timestamp: string;
  }>;
  goals: Array<{
    id: number;
    title: string;
    subject: string;
    progress: number;
  }>;
  recommendations: Array<{
    type: string;
    priority: string;
    message: string;
    action: string;
  }>;
}

export default function ParentDashboard() {
  const [students, setStudents] = useState<StudentSummary[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    loadDashboard();
  }, []);

  const loadDashboard = async () => {
    // Note: In a real app, this would be authenticated as a parent
    // For now, we'll mock or assume parent auth context is set
    try {
      const response = await api.get('/api/v1/parent/dashboard');
      setStudents(response.data.students);
    } catch (error) {
      console.error('Failed to load parent dashboard', error);
    } finally {
      setIsLoading(false);
    }
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="animate-spin w-8 h-8 border-4 border-indigo-600 border-t-transparent rounded-full" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 py-8">
        <h1 className="text-3xl font-bold text-gray-800 mb-8">Parent Dashboard</h1>

        {students.length === 0 ? (
          <div className="text-center text-gray-500">No students found.</div>
        ) : (
          students.map((student) => (
            <div key={student.id} className="mb-8">
              <div className="bg-white rounded-xl shadow-sm p-6">
                <h2 className="text-xl font-semibold text-gray-800 mb-4">{student.name}</h2>

                {/* Stats Grid */}
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
                  <StatCard
                    label="Sessions This Month"
                    value={student.summary.total_sessions_this_month}
                    icon="👨‍🏫"
                  />
                  <StatCard
                    label="Practice Problems"
                    value={student.summary.practice_problems_this_week}
                    icon="✏️"
                  />
                  <StatCard
                    label="Accuracy"
                    value={`${student.summary.average_accuracy}%`}
                    icon="🎯"
                  />
                  <StatCard
                    label="Day Streak"
                    value={student.summary.current_streak}
                    icon="🔥"
                  />
                </div>

                {/* Engagement Score */}
                <div className="mb-6">
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-sm font-medium text-gray-600">Engagement Score</span>
                    <span className="text-sm font-bold text-indigo-600">{student.summary.engagement_score}/100</span>
                  </div>
                  <div className="w-full h-3 bg-gray-200 rounded-full">
                    <div
                      className={`h-full rounded-full ${
                        student.summary.engagement_score >= 70 ? 'bg-green-500' :
                        student.summary.engagement_score >= 40 ? 'bg-yellow-500' : 'bg-red-500'
                      }`}
                      style={{ width: `${student.summary.engagement_score}%` }}
                    />
                  </div>
                </div>

                {/* Recommendations */}
                {student.recommendations.length > 0 && (
                  <div className="mb-6">
                    <h3 className="text-lg font-medium text-gray-800 mb-3">Recommendations</h3>
                    <div className="space-y-2">
                      {student.recommendations.map((rec, i) => (
                        <div
                          key={i}
                          className={`p-3 rounded-lg ${
                            rec.priority === 'high' ? 'bg-red-50 border-l-4 border-red-500' :
                            rec.priority === 'medium' ? 'bg-yellow-50 border-l-4 border-yellow-500' :
                            'bg-blue-50 border-l-4 border-blue-500'
                          }`}
                        >
                          <p className="text-sm text-gray-700">{rec.message}</p>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* Active Goals */}
                <div className="mb-6">
                  <h3 className="text-lg font-medium text-gray-800 mb-3">Active Goals</h3>
                  <div className="space-y-3">
                    {student.goals.map((goal) => (
                      <div key={goal.id} className="flex items-center gap-4">
                        <div className="flex-1">
                          <div className="flex justify-between mb-1">
                            <span className="text-sm font-medium text-gray-700">{goal.title}</span>
                            <span className="text-sm text-gray-500">{goal.progress}%</span>
                          </div>
                          <div className="w-full h-2 bg-gray-200 rounded-full">
                            <div
                              className="h-full bg-indigo-600 rounded-full"
                              style={{ width: `${goal.progress}%` }}
                            />
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Recent Activity */}
                <div>
                  <h3 className="text-lg font-medium text-gray-800 mb-3">Recent Activity</h3>
                  <div className="space-y-2">
                    {student.recent_activity.map((activity, i) => (
                      <div key={i} className="flex items-center gap-3 text-sm">
                        <span>{activity.type === 'practice' ? '✏️' : '👨‍🏫'}</span>
                        <span className="text-gray-600">{activity.description}</span>
                        <span className="text-gray-400 ml-auto">
                          {new Date(activity.timestamp).toLocaleDateString()}
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

function StatCard({ label, value, icon }: { label: string; value: string | number; icon: string }) {
  return (
    <div className="bg-gray-50 rounded-lg p-4">
      <div className="flex items-center gap-2">
        <span className="text-xl">{icon}</span>
        <div>
          <div className="text-xl font-bold text-gray-800">{value}</div>
          <div className="text-xs text-gray-500">{label}</div>
        </div>
      </div>
    </div>
  );
}


