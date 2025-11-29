import { useRef, useEffect } from 'react';
import { useChat } from '../../contexts/ChatContext';
import { MessageBubble } from './MessageBubble';
import { ChatInput } from './ChatInput';
import { TypingIndicator } from './TypingIndicator';

export function ChatWindow() {
  const { currentConversation, messages, isStreaming, streamingContent } = useChat();
  const messagesEndRef = useRef<HTMLDivElement>(null);

  // Auto-scroll to bottom
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, streamingContent]);

  return (
    <div className="flex-1 flex flex-col">
      {/* Header */}
      <div className="px-6 py-4 bg-white border-b border-gray-200">
        <h2 className="font-semibold text-gray-800">
          {currentConversation?.subject || 'General Chat'}
        </h2>
        <p className="text-sm text-gray-500">
          {messages.length} messages
        </p>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto px-6 py-4 space-y-4">
        {messages.map((message) => (
          <MessageBubble key={message.id} message={message} />
        ))}

        {/* Streaming response */}
        {isStreaming && streamingContent && (
          <MessageBubble
            message={{
              id: 'streaming',
              role: 'assistant',
              content: streamingContent,
              created_at: new Date().toISOString()
            }}
            isStreaming
          />
        )}

        {/* Typing indicator */}
        {isStreaming && !streamingContent && (
          <TypingIndicator />
        )}

        <div ref={messagesEndRef} />
      </div>

      {/* Input */}
      <ChatInput />
    </div>
  );
}


