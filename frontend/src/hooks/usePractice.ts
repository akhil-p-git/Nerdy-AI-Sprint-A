import { useState, useCallback } from 'react';
import { api } from '../api/client';

interface Problem {
  id: number;
  type: string;
  question: string;
  options: string[];
  difficulty: number;
  topic: string;
  answered: boolean;
  is_correct: boolean | null;
}

interface PracticeSession {
  id: number;
  subject: string;
  session_type: string;
  total_problems: number;
  correct_answers: number;
  problems: Problem[];
}

interface SubmitResult {
  is_correct: boolean;
  correct_answer: string;
  explanation: string;
  feedback: string;
}

interface SessionResult {
  accuracy: number;
  correct: number;
  total: number;
  struggled_topics: string[];
  new_proficiency: number;
}

export function usePractice() {
  const [session, setSession] = useState<PracticeSession | null>(null);
  const [currentProblemIndex, setCurrentProblemIndex] = useState(0);
  const [isLoading, setIsLoading] = useState(false);
  const [lastResult, setLastResult] = useState<SubmitResult | null>(null);
  const [sessionResult, setSessionResult] = useState<SessionResult | null>(null);

  const startSession = useCallback(async (
    subject: string,
    sessionType: 'quiz' | 'flashcards' = 'quiz',
    numProblems = 10
  ) => {
    setIsLoading(true);
    try {
      const response = await api.post('/api/v1/practice_sessions', {
        subject,
        session_type: sessionType,
        num_problems: numProblems
      });
      setSession(response.data);
      setCurrentProblemIndex(0);
      setLastResult(null);
      setSessionResult(null);
      return response.data;
    } finally {
      setIsLoading(false);
    }
  }, []);

  const submitAnswer = useCallback(async (answer: string) => {
    if (!session) return;

    const problem = session.problems[currentProblemIndex];
    setIsLoading(true);

    try {
      const response = await api.post(`/api/v1/practice_sessions/${session.id}/submit`, {
        problem_id: problem.id,
        answer
      });

      setLastResult(response.data);

      // Update local state
      setSession(prev => {
        if (!prev) return prev;
        const updatedProblems = [...prev.problems];
        updatedProblems[currentProblemIndex] = {
          ...updatedProblems[currentProblemIndex],
          answered: true,
          is_correct: response.data.is_correct
        };
        return {
          ...prev,
          problems: updatedProblems,
          correct_answers: prev.correct_answers + (response.data.is_correct ? 1 : 0)
        };
      });

      return response.data;
    } finally {
      setIsLoading(false);
    }
  }, [session, currentProblemIndex]);

  const nextProblem = useCallback(() => {
    if (session && currentProblemIndex < session.problems.length - 1) {
      setCurrentProblemIndex(prev => prev + 1);
      setLastResult(null);
    }
  }, [session, currentProblemIndex]);

  const completeSession = useCallback(async () => {
    if (!session) return;

    setIsLoading(true);
    try {
      const response = await api.post(`/api/v1/practice_sessions/${session.id}/complete`);
      setSessionResult(response.data);
      return response.data;
    } finally {
      setIsLoading(false);
    }
  }, [session]);

  const currentProblem = session?.problems[currentProblemIndex] || null;
  const isComplete = session ? currentProblemIndex >= session.problems.length - 1 && lastResult !== null : false;

  return {
    session,
    currentProblem,
    currentProblemIndex,
    isLoading,
    lastResult,
    sessionResult,
    isComplete,
    startSession,
    submitAnswer,
    nextProblem,
    completeSession
  };
}
