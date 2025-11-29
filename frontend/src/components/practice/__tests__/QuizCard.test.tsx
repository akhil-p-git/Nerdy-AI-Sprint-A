import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, it, expect, vi } from 'vitest';
import { QuizCard } from '../QuizCard';

const mockPractice = {
  lastResult: null,
  isLoading: false,
  submitAnswer: vi.fn(),
  showExplanation: false
};

const mockProblem = {
  id: 1,
  type: 'multiple_choice',
  question: 'What is 2+2?',
  options: ['3', '4', '5', '6'],
  difficulty: 5,
  topic: 'arithmetic',
  answered: false,
  is_correct: null
};

describe('QuizCard', () => {
  it('renders question and options', () => {
    render(<QuizCard problem={mockProblem} practice={mockPractice as any} />);

    expect(screen.getByText('What is 2+2?')).toBeInTheDocument();
    expect(screen.getByText('A.')).toBeInTheDocument();
    expect(screen.getByText('3')).toBeInTheDocument();
    expect(screen.getByText('4')).toBeInTheDocument();
  });

  it('allows selecting an answer', async () => {
    const user = userEvent.setup();
    render(<QuizCard problem={mockProblem} practice={mockPractice as any} />);

    await user.click(screen.getByText('4'));

    // Check option is selected (has indigo border)
    const option = screen.getByText('4').closest('button');
    expect(option).toHaveClass('border-indigo-500');
  });

  it('submits answer on button click', async () => {
    const user = userEvent.setup();
    render(<QuizCard problem={mockProblem} practice={mockPractice as any} />);

    await user.click(screen.getByText('4'));
    await user.click(screen.getByText('Submit Answer'));

    expect(mockPractice.submitAnswer).toHaveBeenCalledWith('4');
  });

  it('shows result after submission', () => {
    const practiceWithResult = {
      ...mockPractice,
      lastResult: {
        is_correct: true,
        correct_answer: '4',
        explanation: '2+2 equals 4',
        feedback: 'Great job!'
      },
      showExplanation: true
    };

    render(<QuizCard problem={mockProblem} practice={practiceWithResult as any} />);

    expect(screen.getByText('Correct!')).toBeInTheDocument();
  });
});


