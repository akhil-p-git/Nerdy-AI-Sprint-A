import { renderHook, act, waitFor } from '@testing-library/react';
import { describe, it, expect } from 'vitest';
import { usePractice } from '../usePractice';

describe('usePractice', () => {
  it('initializes with null session', () => {
    const { result } = renderHook(() => usePractice());

    expect(result.current.session).toBeNull();
    expect(result.current.currentProblem).toBeNull();
    expect(result.current.isLoading).toBe(false);
  });

  it('starts a practice session', async () => {
    const { result } = renderHook(() => usePractice());

    await act(async () => {
      await result.current.startSession('math', 'quiz', 5);
    });

    await waitFor(() => {
      expect(result.current.session).not.toBeNull();
      expect(result.current.session?.subject).toBe('math');
    });
  });

  it('tracks current problem index', async () => {
    const { result } = renderHook(() => usePractice());

    await act(async () => {
      await result.current.startSession('math', 'quiz', 5);
    });

    expect(result.current.currentIndex).toBe(0);

    // Simulate answering
    await act(async () => {
      // Mock answer submission would set lastResult
    });
  });

  it('calculates progress correctly', async () => {
    const { result } = renderHook(() => usePractice());

    await act(async () => {
      await result.current.startSession('math', 'quiz', 5);
    });

    // First problem of 5 = 20% progress
    expect(result.current.progress).toBe(20);
  });
});


