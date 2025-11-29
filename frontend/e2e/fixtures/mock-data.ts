// Mock data for E2E tests - aligned with actual TypeScript types

export const mockStudent = {
  id: 1,
  firstName: 'Test',
  lastName: 'Student',
  email: 'test@example.com',
};

export const mockAuthResponse = {
  token: 'mock-jwt-token-12345',
  refresh_token: 'mock-refresh-token-67890',
  student: mockStudent,
};

// Matches LearningProfile type from types/dashboard.ts
export const mockLearningProfiles = [
  {
    subject: 'mathematics',
    proficiency_level: 6,
    strengths: ['algebra', 'geometry'],
    weaknesses: ['calculus'],
  },
  {
    subject: 'science',
    proficiency_level: 4,
    strengths: ['biology basics'],
    weaknesses: ['physics'],
  },
];

// Matches LearningGoal type from types/dashboard.ts
export const mockLearningGoals = [
  {
    id: 1,
    title: 'Master Quadratic Equations',
    description: 'Learn to solve all types of quadratic equations',
    subject: 'mathematics',
    target_date: '2025-12-31',
    status: 'active',
    progress_percentage: 45,
    milestones: [
      { id: '1', title: 'Understand basics', completed: true },
      { id: '2', title: 'Solve simple equations', completed: true },
      { id: '3', title: 'Complex equations', completed: false },
    ],
    suggested_next_goals: [],
    created_at: new Date().toISOString(),
    completed_at: null,
  },
  {
    id: 2,
    title: 'Learn Photosynthesis',
    description: 'Understand the complete process of photosynthesis',
    subject: 'science',
    target_date: '2025-12-15',
    status: 'active',
    progress_percentage: 20,
    milestones: [
      { id: '4', title: 'Basic concepts', completed: true },
      { id: '5', title: 'Chemical reactions', completed: false },
    ],
    suggested_next_goals: [],
    created_at: new Date().toISOString(),
    completed_at: null,
  },
  {
    id: 3,
    title: 'Complete Algebra Unit',
    description: 'Finished all algebra topics',
    subject: 'mathematics',
    target_date: null,
    status: 'completed',
    progress_percentage: 100,
    milestones: [],
    suggested_next_goals: [
      { subject: 'mathematics', reason: 'Start Trigonometry', priority: 1 },
      { subject: 'mathematics', reason: 'Advanced Algebra', priority: 2 },
    ],
    created_at: new Date(Date.now() - 86400000 * 7).toISOString(),
    completed_at: new Date(Date.now() - 86400000).toISOString(),
  },
];

// Matches DashboardStats type from types/dashboard.ts
export const mockStats = {
  total_sessions: 25,
  total_practice_problems: 150,
  average_accuracy: 78,
  current_streak: 5,
  goals_completed: 2,
  active_goals: 2,
};

// Matches Conversation type from types/chat.ts
export const mockConversations = [
  {
    id: 1,
    subject: 'mathematics',
    status: 'active',
    messages: [],
    message_count: 5,
    last_message: {
      role: 'assistant',
      preview: 'The solutions are x = -2 and x = -3.',
      created_at: new Date().toISOString(),
    },
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  },
  {
    id: 2,
    subject: 'science',
    status: 'active',
    messages: [],
    message_count: 3,
    last_message: {
      role: 'user',
      preview: 'How does photosynthesis work?',
      created_at: new Date(Date.now() - 86400000).toISOString(),
    },
    created_at: new Date(Date.now() - 86400000).toISOString(),
    updated_at: new Date(Date.now() - 86400000).toISOString(),
  },
];

// Matches Message type from types/chat.ts
export const mockMessages = [
  {
    id: 1,
    role: 'user',
    content: 'Can you help me understand how to solve x^2 + 5x + 6 = 0?',
    created_at: new Date(Date.now() - 60000).toISOString(),
  },
  {
    id: 2,
    role: 'assistant',
    content: 'Of course! This is a quadratic equation. We can solve it by factoring.\n\nLooking at x^2 + 5x + 6 = 0, we need two numbers that:\n- Multiply to give 6\n- Add to give 5\n\nThose numbers are 2 and 3!\n\nSo we can factor: (x + 2)(x + 3) = 0\n\nSetting each factor to zero:\n- x + 2 = 0 → x = -2\n- x + 3 = 0 → x = -3\n\nThe solutions are x = -2 and x = -3.',
    created_at: new Date().toISOString(),
  },
];

// Matches PracticeSession structure
export const mockPracticeSession = {
  id: 1,
  subject: 'mathematics',
  session_type: 'quiz',
  total_problems: 3,
  correct_answers: 0,
  accuracy: 0,
  problems: [
    {
      id: 1,
      type: 'multiple_choice',
      question: 'Solve for x: 2x + 5 = 15',
      options: ['x = 5', 'x = 10', 'x = 7.5', 'x = 3'],
      difficulty: 3,
      topic: 'algebra',
      answered: false,
      is_correct: null,
    },
    {
      id: 2,
      type: 'multiple_choice',
      question: 'What is the slope of the line y = 3x + 2?',
      options: ['2', '3', '5', '1'],
      difficulty: 2,
      topic: 'linear equations',
      answered: false,
      is_correct: null,
    },
    {
      id: 3,
      type: 'multiple_choice',
      question: 'Factor: x^2 - 9',
      options: ['(x+3)(x-3)', '(x+9)(x-1)', '(x-3)(x-3)', '(x+3)(x+3)'],
      difficulty: 4,
      topic: 'factoring',
      answered: false,
      is_correct: null,
    },
  ],
  struggled_topics: [],
  completed_at: null,
  created_at: new Date().toISOString(),
};

export const mockActivities = [
  {
    id: 1,
    type: 'practice_completed',
    description: 'Completed 10 practice problems in Math',
    created_at: new Date().toISOString(),
  },
  {
    id: 2,
    type: 'goal_progress',
    description: 'Made progress on "Master Quadratic Equations"',
    created_at: new Date(Date.now() - 3600000).toISOString(),
  },
  {
    id: 3,
    type: 'conversation',
    description: 'Asked about photosynthesis in Science',
    created_at: new Date(Date.now() - 86400000).toISOString(),
  },
];

export const mockStudentEvents = [];
