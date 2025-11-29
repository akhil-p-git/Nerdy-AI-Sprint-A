export interface LearningGoal {
  id: number;
  subject: string;
  title: string;
  description: string;
  status: 'pending' | 'active' | 'completed' | 'paused';
  progress_percentage: number;
  target_date: string | null;
  milestones: Milestone[];
  suggested_next_goals: GoalSuggestion[];
  created_at: string;
  completed_at: string | null;
}

export interface Milestone {
  id: string;
  title: string;
  completed: boolean;
}

export interface GoalSuggestion {
  subject: string;
  reason: string;
  priority: number;
}

export interface LearningProfile {
  subject: string;
  proficiency_level: number;
  strengths: string[];
  weaknesses: string[];
}

export interface DashboardStats {
  total_sessions: number;
  total_practice_problems: number;
  average_accuracy: number;
  current_streak: number;
  goals_completed: number;
  active_goals: number;
}


