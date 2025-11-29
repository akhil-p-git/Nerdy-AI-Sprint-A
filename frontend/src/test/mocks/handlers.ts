import { http, HttpResponse } from 'msw';

export const handlers = [
  http.get('/api/v1/conversations', () => {
    return HttpResponse.json([
      { id: 1, subject: 'math', status: 'active', messages: [] },
      { id: 2, subject: 'physics', status: 'active', messages: [] }
    ]);
  }),

  http.post('/api/v1/conversations', () => {
    return HttpResponse.json({
      id: 3,
      subject: 'chemistry',
      status: 'active',
      messages: []
    });
  }),

  http.get('/api/v1/learning_goals', () => {
    return HttpResponse.json([
      { id: 1, title: 'Master algebra', subject: 'math', progress_percentage: 50, status: 'active' }
    ]);
  }),

  http.get('/api/v1/stats', () => {
    return HttpResponse.json({
      total_sessions: 10,
      total_practice_problems: 100,
      average_accuracy: 75,
      current_streak: 5,
      goals_completed: 2,
      active_goals: 3
    });
  }),

  http.post('/api/v1/practice_sessions', () => {
    return HttpResponse.json({
      id: 1,
      subject: 'math',
      session_type: 'quiz',
      total_problems: 5,
      correct_answers: 0,
      problems: [
        { id: 1, question: 'What is 2+2?', options: ['3', '4', '5', '6'], type: 'multiple_choice' }
      ]
    });
  })
];


