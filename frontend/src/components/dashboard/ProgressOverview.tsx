import type { DashboardStats } from '../../types/dashboard';

interface ProgressOverviewProps {
  stats: DashboardStats;
}

export function ProgressOverview({ stats }: ProgressOverviewProps) {
  const statCards = [
    {
      label: 'Tutor Sessions',
      value: stats.total_sessions,
      icon: '👨‍🏫',
      color: 'bg-blue-500'
    },
    {
      label: 'Problems Solved',
      value: stats.total_practice_problems,
      icon: '✏️',
      color: 'bg-green-500'
    },
    {
      label: 'Avg Accuracy',
      value: `${stats.average_accuracy}%`,
      icon: '🎯',
      color: 'bg-purple-500'
    },
    {
      label: 'Day Streak',
      value: stats.current_streak,
      icon: '🔥',
      color: 'bg-orange-500'
    },
    {
      label: 'Goals Completed',
      value: stats.goals_completed,
      icon: '🏆',
      color: 'bg-yellow-500'
    },
    {
      label: 'Active Goals',
      value: stats.active_goals,
      icon: '🎯',
      color: 'bg-indigo-500'
    }
  ];

  return (
    <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
      {statCards.map((stat, index) => (
        <div key={index} className="bg-white rounded-xl p-4 shadow-sm">
          <div className="flex items-center gap-3">
            <div className={`w-10 h-10 ${stat.color} rounded-lg flex items-center justify-center text-xl`}>
              {stat.icon}
            </div>
            <div>
              <div className="text-2xl font-bold text-gray-800">{stat.value}</div>
              <div className="text-xs text-gray-500">{stat.label}</div>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}


