import { useState, useEffect } from 'react';
import { api } from '../../api/client';
import { formatDistanceToNow } from 'date-fns';

interface Activity {
  id: number;
  type: string;
  description: string;
  created_at: string;
}

export function ActivityFeed() {
  const [activities, setActivities] = useState<Activity[]>([]);

  useEffect(() => {
    api.get('/api/v1/activities?limit=10').then(res => setActivities(res.data));
  }, []);

  const getIcon = (type: string) => {
    switch (type) {
      case 'practice_completed': return '✏️';
      case 'conversation': return '💬';
      case 'session_completed': return '👨‍🏫';
      case 'goal_progress': return '📈';
      case 'goal_completed': return '🏆';
      default: return '📌';
    }
  };

  return (
    <section>
      <h2 className="text-lg font-semibold text-gray-800 mb-4">Recent Activity</h2>
      <div className="bg-white rounded-xl shadow-sm overflow-hidden">
        {activities.length > 0 ? (
          <div className="divide-y divide-gray-100">
            {activities.map((activity) => (
              <div key={activity.id} className="p-3 flex items-start gap-3">
                <span className="text-lg">{getIcon(activity.type)}</span>
                <div className="flex-1 min-w-0">
                  <p className="text-sm text-gray-800">{activity.description}</p>
                  <span className="text-xs text-gray-400">
                    {formatDistanceToNow(new Date(activity.created_at), { addSuffix: true })}
                  </span>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="p-6 text-center text-gray-500 text-sm">
            No recent activity
          </div>
        )}
      </div>
    </section>
  );
}


