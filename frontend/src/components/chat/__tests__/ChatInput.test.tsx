import { render, screen, fireEvent } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, it, expect, vi } from 'vitest';
import { ChatInput } from '../ChatInput';
import { ChatProvider } from '../../../contexts/ChatContext';

const mockSendMessage = vi.fn();

vi.mock('../../../contexts/ChatContext', async () => {
  const actual = await vi.importActual('../../../contexts/ChatContext');
  return {
    ...actual,
    useChat: () => ({
      sendMessage: mockSendMessage,
      isStreaming: false
    })
  };
});

describe('ChatInput', () => {
  beforeEach(() => {
    mockSendMessage.mockClear();
  });

  it('renders input field', () => {
    render(<ChatInput />);
    expect(screen.getByPlaceholderText(/ask me anything/i)).toBeInTheDocument();
  });

  it('sends message on submit', async () => {
    const user = userEvent.setup();
    render(<ChatInput />);

    const input = screen.getByPlaceholderText(/ask me anything/i);
    await user.type(input, 'Hello AI');
    await user.click(screen.getByRole('button'));

    expect(mockSendMessage).toHaveBeenCalledWith('Hello AI');
  });

  it('sends message on Enter key', async () => {
    const user = userEvent.setup();
    render(<ChatInput />);

    const input = screen.getByPlaceholderText(/ask me anything/i);
    await user.type(input, 'Hello AI{Enter}');

    expect(mockSendMessage).toHaveBeenCalledWith('Hello AI');
  });

  it('does not send empty message', async () => {
    const user = userEvent.setup();
    render(<ChatInput />);

    await user.click(screen.getByRole('button'));

    expect(mockSendMessage).not.toHaveBeenCalled();
  });

  it('clears input after sending', async () => {
    const user = userEvent.setup();
    render(<ChatInput />);

    const input = screen.getByPlaceholderText(/ask me anything/i);
    await user.type(input, 'Hello AI{Enter}');

    expect(input).toHaveValue('');
  });
});


