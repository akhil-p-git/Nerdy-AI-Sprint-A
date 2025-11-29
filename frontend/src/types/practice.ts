export interface Problem {
  id: number;
  type: 'multiple_choice' | 'flashcard' | 'free_response';
  question: string;
  options: string[];
  correct_answer?: string;
  difficulty: number;
  topic: string;
  answered: boolean;
  is_correct: boolean | null;
}

export interface PracticeSession {
  id: number;
  subject: string;
  session_type: string;
  total_problems: number;
  correct_answers: number;
  accuracy: number;
  problems: Problem[];
  struggled_topics: string[];
  completed_at: string | null;
  created_at: string;
}

export interface SubmitResult {
  is_correct: boolean;
  correct_answer: string;
  explanation: string;
  feedback: string;
}

export interface SessionResult {
  accuracy: number;
  correct: number;
  total: number;
  struggled_topics: string[];
  new_proficiency: number;
}


