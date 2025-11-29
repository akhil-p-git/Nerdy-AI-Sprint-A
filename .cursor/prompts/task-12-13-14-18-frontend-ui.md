# One-Shot Prompt: Frontend UI Components (Tasks 12, 13, 14, 18)

## Context
Building the React frontend for the Nerdy AI Study Companion. These are the core user-facing interfaces for chat, practice, and progress tracking. Assumes backend APIs from Tasks 1-11 are complete.

## Your Mission
Implement the complete frontend UI in a single pass:
- **Task 12:** Chat Interface UI Component
- **Task 13:** Practice Module UI
- **Task 14:** Multi-Goal Progress Dashboard
- **Task 18:** WebSocket Real-time Communication

---

## Task 18: WebSocket Real-time Communication (Foundation)

Set up WebSocket infrastructure first as chat depends on it.

### WebSocket Manager
Create `frontend/src/lib/websocket.ts`:
```typescript
type MessageHandler = (data: any) => void;
type ConnectionHandler = () => void;

interface Subscription {
  channel: string;
  params: Record<string, any>;
  handlers: {
    onMessage: MessageHandler;
    onConnect?: ConnectionHandler;
    onDisconnect?: ConnectionHandler;
  };
}

class WebSocketManager {
  private ws: WebSocket | null = null;
  private url: string;
  private subscriptions: Map<string, Subscription> = new Map();
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  private reconnectDelay = 1000;
  private heartbeatInterval: NodeJS.Timeout | null = null;
  private isConnecting = false;

  constructor() {
    const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const baseUrl = import.meta.env.VITE_WS_URL || `${wsProtocol}//${window.location.host}`;
    this.url = `${baseUrl}/cable`;
  }

  connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      if (this.ws?.readyState === WebSocket.OPEN) {
        resolve();
        return;
      }

      if (this.isConnecting) {
        // Wait for existing connection attempt
        const checkConnection = setInterval(() => {
          if (this.ws?.readyState === WebSocket.OPEN) {
            clearInterval(checkConnection);
            resolve();
          }
        }, 100);
        return;
      }

      this.isConnecting = true;
      const token = localStorage.getItem('token');

      this.ws = new WebSocket(`${this.url}?token=${token}`);

      this.ws.onopen = () => {
        console.log('WebSocket connected');
        this.isConnecting = false;
        this.reconnectAttempts = 0;
        this.startHeartbeat();

        // Resubscribe to all channels
        this.subscriptions.forEach((sub, identifier) => {
          this.sendSubscribe(sub.channel, sub.params);
          sub.handlers.onConnect?.();
        });

        resolve();
      };

      this.ws.onmessage = (event) => {
        const data = JSON.parse(event.data);

        if (data.type === 'ping') {
          this.send({ type: 'pong' });
          return;
        }

        if (data.type === 'confirm_subscription') {
          console.log('Subscription confirmed:', data.identifier);
          return;
        }

        if (data.identifier && data.message) {
          const subscription = this.subscriptions.get(data.identifier);
          subscription?.handlers.onMessage(data.message);
        }
      };

      this.ws.onclose = () => {
        console.log('WebSocket disconnected');
        this.isConnecting = false;
        this.stopHeartbeat();

        this.subscriptions.forEach(sub => {
          sub.handlers.onDisconnect?.();
        });

        this.attemptReconnect();
      };

      this.ws.onerror = (error) => {
        console.error('WebSocket error:', error);
        this.isConnecting = false;
        reject(error);
      };
    });
  }

  private attemptReconnect() {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('Max reconnection attempts reached');
      return;
    }

    this.reconnectAttempts++;
    const delay = this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1);

    console.log(`Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts})`);

    setTimeout(() => {
      this.connect();
    }, delay);
  }

  private startHeartbeat() {
    this.heartbeatInterval = setInterval(() => {
      if (this.ws?.readyState === WebSocket.OPEN) {
        this.send({ type: 'ping' });
      }
    }, 30000);
  }

  private stopHeartbeat() {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
      this.heartbeatInterval = null;
    }
  }

  private send(data: any) {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(data));
    }
  }

  private sendSubscribe(channel: string, params: Record<string, any>) {
    const identifier = JSON.stringify({ channel, ...params });
    this.send({
      command: 'subscribe',
      identifier
    });
  }

  subscribe(
    channel: string,
    params: Record<string, any>,
    handlers: Subscription['handlers']
  ): () => void {
    const identifier = JSON.stringify({ channel, ...params });

    this.subscriptions.set(identifier, { channel, params, handlers });

    if (this.ws?.readyState === WebSocket.OPEN) {
      this.sendSubscribe(channel, params);
    } else {
      this.connect();
    }

    // Return unsubscribe function
    return () => {
      this.subscriptions.delete(identifier);
      if (this.ws?.readyState === WebSocket.OPEN) {
        this.send({
          command: 'unsubscribe',
          identifier
        });
      }
    };
  }

  perform(channel: string, params: Record<string, any>, action: string, data: any) {
    const identifier = JSON.stringify({ channel, ...params });

    this.send({
      command: 'message',
      identifier,
      data: JSON.stringify({ action, ...data })
    });
  }

  disconnect() {
    this.stopHeartbeat();
    this.subscriptions.clear();
    this.ws?.close();
    this.ws = null;
  }
}

export const wsManager = new WebSocketManager();
```

### WebSocket Hook
Create `frontend/src/hooks/useWebSocket.ts`:
```typescript
import { useEffect, useRef, useCallback } from 'react';
import { wsManager } from '../lib/websocket';

interface UseWebSocketOptions {
  channel: string;
  params: Record<string, any>;
  onMessage: (data: any) => void;
  onConnect?: () => void;
  onDisconnect?: () => void;
  enabled?: boolean;
}

export function useWebSocket({
  channel,
  params,
  onMessage,
  onConnect,
  onDisconnect,
  enabled = true
}: UseWebSocketOptions) {
  const unsubscribeRef = useRef<(() => void) | null>(null);

  useEffect(() => {
    if (!enabled) return;

    unsubscribeRef.current = wsManager.subscribe(channel, params, {
      onMessage,
      onConnect,
      onDisconnect
    });

    return () => {
      unsubscribeRef.current?.();
    };
  }, [channel, JSON.stringify(params), enabled]);

  const perform = useCallback((action: string, data: any) => {
    wsManager.perform(channel, params, action, data);
  }, [channel, JSON.stringify(params)]);

  return { perform };
}
```

---

## Task 12: Chat Interface UI Component

Build the main AI companion chat interface.

### Types
Create `frontend/src/types/chat.ts`:
```typescript
export interface Message {
  id: number | string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  created_at: string;
  metadata?: {
    type?: 'handoff_suggestion' | 'celebration';
    context?: any;
  };
}

export interface Conversation {
  id: number;
  subject: string | null;
  status: 'active' | 'archived';
  messages: Message[];
  message_count: number;
  last_message?: {
    role: string;
    preview: string;
    created_at: string;
  };
  created_at: string;
  updated_at: string;
}
```

### Chat Context
Create `frontend/src/contexts/ChatContext.tsx`:
```typescript
import React, { createContext, useContext, useState, useCallback, ReactNode } from 'react';
import { api } from '../api/client';
import { useWebSocket } from '../hooks/useWebSocket';
import { Conversation, Message } from '../types/chat';

interface ChatContextType {
  conversations: Conversation[];
  currentConversation: Conversation | null;
  messages: Message[];
  isLoading: boolean;
  isStreaming: boolean;
  streamingContent: string;
  loadConversations: () => Promise<void>;
  createConversation: (subject?: string, initialMessage?: string) => Promise<Conversation>;
  selectConversation: (id: number) => Promise<void>;
  sendMessage: (content: string) => void;
}

const ChatContext = createContext<ChatContextType | undefined>(undefined);

export function ChatProvider({ children }: { children: ReactNode }) {
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [currentConversation, setCurrentConversation] = useState<Conversation | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [isStreaming, setIsStreaming] = useState(false);
  const [streamingContent, setStreamingContent] = useState('');

  // WebSocket for streaming
  const { perform } = useWebSocket({
    channel: 'ConversationChannel',
    params: { conversation_id: currentConversation?.id },
    enabled: !!currentConversation,
    onMessage: (data) => {
      if (data.type === 'chunk') {
        setStreamingContent(prev => prev + data.content);
      } else if (data.type === 'complete') {
        // Add complete message
        setMessages(prev => [...prev, {
          id: Date.now(),
          role: 'assistant',
          content: streamingContent,
          created_at: new Date().toISOString()
        }]);
        setIsStreaming(false);
        setStreamingContent('');
      }
    },
    onConnect: () => console.log('Chat connected'),
    onDisconnect: () => console.log('Chat disconnected')
  });

  const loadConversations = useCallback(async () => {
    const response = await api.get('/api/v1/conversations');
    setConversations(response.data);
  }, []);

  const createConversation = useCallback(async (subject?: string, initialMessage?: string) => {
    setIsLoading(true);
    try {
      const response = await api.post('/api/v1/conversations', {
        subject,
        initial_message: initialMessage
      });
      const newConversation = response.data;
      setConversations(prev => [newConversation, ...prev]);
      setCurrentConversation(newConversation);
      setMessages(newConversation.messages || []);
      return newConversation;
    } finally {
      setIsLoading(false);
    }
  }, []);

  const selectConversation = useCallback(async (id: number) => {
    setIsLoading(true);
    try {
      const response = await api.get(`/api/v1/conversations/${id}`);
      setCurrentConversation(response.data);
      setMessages(response.data.messages || []);
    } finally {
      setIsLoading(false);
    }
  }, []);

  const sendMessage = useCallback((content: string) => {
    if (!currentConversation) return;

    // Add user message immediately
    const userMessage: Message = {
      id: Date.now(),
      role: 'user',
      content,
      created_at: new Date().toISOString()
    };
    setMessages(prev => [...prev, userMessage]);
    setIsStreaming(true);
    setStreamingContent('');

    // Send via WebSocket
    perform('send_message', { content, subject: currentConversation.subject });
  }, [currentConversation, perform]);

  return (
    <ChatContext.Provider value={{
      conversations,
      currentConversation,
      messages,
      isLoading,
      isStreaming,
      streamingContent,
      loadConversations,
      createConversation,
      selectConversation,
      sendMessage
    }}>
      {children}
    </ChatContext.Provider>
  );
}

export const useChat = () => {
  const context = useContext(ChatContext);
  if (!context) throw new Error('useChat must be used within ChatProvider');
  return context;
};
```

### Chat Page
Create `frontend/src/pages/Chat.tsx`:
```typescript
import React, { useEffect } from 'react';
import { ChatProvider, useChat } from '../contexts/ChatContext';
import { ConversationList } from '../components/chat/ConversationList';
import { ChatWindow } from '../components/chat/ChatWindow';
import { SubjectSelector } from '../components/chat/SubjectSelector';

function ChatContent() {
  const { currentConversation, loadConversations } = useChat();

  useEffect(() => {
    loadConversations();
  }, [loadConversations]);

  return (
    <div className="flex h-screen bg-gray-50">
      {/* Sidebar */}
      <div className="w-80 bg-white border-r border-gray-200 flex flex-col">
        <div className="p-4 border-b border-gray-200">
          <h1 className="text-xl font-semibold text-gray-800">AI Companion</h1>
          <p className="text-sm text-gray-500">Your personal study assistant</p>
        </div>
        <SubjectSelector />
        <ConversationList />
      </div>

      {/* Main Chat Area */}
      <div className="flex-1 flex flex-col">
        {currentConversation ? (
          <ChatWindow />
        ) : (
          <EmptyState />
        )}
      </div>
    </div>
  );
}

function EmptyState() {
  const { createConversation } = useChat();

  const quickStarts = [
    { subject: 'Math', prompt: 'Help me understand quadratic equations' },
    { subject: 'Science', prompt: 'Explain photosynthesis' },
    { subject: 'English', prompt: 'How do I write a thesis statement?' },
    { subject: 'SAT', prompt: 'Give me SAT math practice tips' }
  ];

  return (
    <div className="flex-1 flex items-center justify-center">
      <div className="text-center max-w-md">
        <div className="w-16 h-16 bg-indigo-100 rounded-full flex items-center justify-center mx-auto mb-4">
          <svg className="w-8 h-8 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z" />
          </svg>
        </div>
        <h2 className="text-xl font-semibold text-gray-800 mb-2">Start a Conversation</h2>
        <p className="text-gray-500 mb-6">Ask me anything about your studies. I'm here to help!</p>

        <div className="grid grid-cols-2 gap-3">
          {quickStarts.map((qs) => (
            <button
              key={qs.subject}
              onClick={() => createConversation(qs.subject, qs.prompt)}
              className="p-3 text-left bg-white border border-gray-200 rounded-lg hover:border-indigo-300 hover:bg-indigo-50 transition-colors"
            >
              <span className="font-medium text-gray-800">{qs.subject}</span>
              <p className="text-xs text-gray-500 mt-1 line-clamp-2">{qs.prompt}</p>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

export default function ChatPage() {
  return (
    <ChatProvider>
      <ChatContent />
    </ChatProvider>
  );
}
```

### Conversation List Component
Create `frontend/src/components/chat/ConversationList.tsx`:
```typescript
import React from 'react';
import { useChat } from '../../contexts/ChatContext';
import { formatDistanceToNow } from 'date-fns';

export function ConversationList() {
  const { conversations, currentConversation, selectConversation, isLoading } = useChat();

  if (isLoading && conversations.length === 0) {
    return (
      <div className="flex-1 flex items-center justify-center">
        <div className="animate-spin w-6 h-6 border-2 border-indigo-600 border-t-transparent rounded-full" />
      </div>
    );
  }

  return (
    <div className="flex-1 overflow-y-auto">
      {conversations.map((conv) => (
        <button
          key={conv.id}
          onClick={() => selectConversation(conv.id)}
          className={`w-full p-4 text-left border-b border-gray-100 hover:bg-gray-50 transition-colors ${
            currentConversation?.id === conv.id ? 'bg-indigo-50 border-l-2 border-l-indigo-600' : ''
          }`}
        >
          <div className="flex items-center justify-between mb-1">
            <span className="font-medium text-gray-800 text-sm">
              {conv.subject || 'General'}
            </span>
            <span className="text-xs text-gray-400">
              {formatDistanceToNow(new Date(conv.updated_at), { addSuffix: true })}
            </span>
          </div>
          {conv.last_message && (
            <p className="text-xs text-gray-500 line-clamp-2">
              {conv.last_message.preview}
            </p>
          )}
        </button>
      ))}

      {conversations.length === 0 && (
        <div className="p-4 text-center text-gray-500 text-sm">
          No conversations yet. Start one!
        </div>
      )}
    </div>
  );
}
```

### Chat Window Component
Create `frontend/src/components/chat/ChatWindow.tsx`:
```typescript
import React, { useRef, useEffect } from 'react';
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
```

### Message Bubble Component
Create `frontend/src/components/chat/MessageBubble.tsx`:
```typescript
import React from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { oneDark } from 'react-syntax-highlighter/dist/esm/styles/prism';
import { Message } from '../../types/chat';
import { HandoffSuggestion } from './HandoffSuggestion';

interface MessageBubbleProps {
  message: Message;
  isStreaming?: boolean;
}

export function MessageBubble({ message, isStreaming }: MessageBubbleProps) {
  const isUser = message.role === 'user';
  const isHandoff = message.metadata?.type === 'handoff_suggestion';

  return (
    <div className={`flex ${isUser ? 'justify-end' : 'justify-start'}`}>
      <div
        className={`max-w-[80%] rounded-2xl px-4 py-3 ${
          isUser
            ? 'bg-indigo-600 text-white'
            : 'bg-white border border-gray-200 text-gray-800'
        } ${isStreaming ? 'animate-pulse' : ''}`}
      >
        {isHandoff ? (
          <HandoffSuggestion context={message.metadata?.context} />
        ) : (
          <div className={`prose prose-sm max-w-none ${isUser ? 'prose-invert' : ''}`}>
            <ReactMarkdown
              remarkPlugins={[remarkGfm, remarkMath]}
              rehypePlugins={[rehypeKatex]}
              components={{
                code({ node, inline, className, children, ...props }) {
                  const match = /language-(\w+)/.exec(className || '');
                  return !inline && match ? (
                    <SyntaxHighlighter
                      style={oneDark}
                      language={match[1]}
                      PreTag="div"
                      className="rounded-lg text-sm"
                      {...props}
                    >
                      {String(children).replace(/\n$/, '')}
                    </SyntaxHighlighter>
                  ) : (
                    <code
                      className={`${
                        isUser ? 'bg-indigo-500' : 'bg-gray-100'
                      } px-1 py-0.5 rounded text-sm`}
                      {...props}
                    >
                      {children}
                    </code>
                  );
                },
                p({ children }) {
                  return <p className="mb-2 last:mb-0">{children}</p>;
                },
                ul({ children }) {
                  return <ul className="list-disc pl-4 mb-2">{children}</ul>;
                },
                ol({ children }) {
                  return <ol className="list-decimal pl-4 mb-2">{children}</ol>;
                }
              }}
            >
              {message.content}
            </ReactMarkdown>
          </div>
        )}

        {/* Timestamp */}
        <div
          className={`text-xs mt-2 ${
            isUser ? 'text-indigo-200' : 'text-gray-400'
          }`}
        >
          {new Date(message.created_at).toLocaleTimeString([], {
            hour: '2-digit',
            minute: '2-digit'
          })}
        </div>
      </div>
    </div>
  );
}
```

### Chat Input Component
Create `frontend/src/components/chat/ChatInput.tsx`:
```typescript
import React, { useState, useRef, useEffect } from 'react';
import { useChat } from '../../contexts/ChatContext';

export function ChatInput() {
  const [input, setInput] = useState('');
  const { sendMessage, isStreaming } = useChat();
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  // Auto-resize textarea
  useEffect(() => {
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto';
      textareaRef.current.style.height = `${textareaRef.current.scrollHeight}px`;
    }
  }, [input]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!input.trim() || isStreaming) return;

    sendMessage(input.trim());
    setInput('');
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSubmit(e);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="px-6 py-4 bg-white border-t border-gray-200">
      <div className="flex items-end gap-3">
        <div className="flex-1 relative">
          <textarea
            ref={textareaRef}
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="Ask me anything..."
            rows={1}
            className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl resize-none focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent max-h-32"
            disabled={isStreaming}
          />
        </div>
        <button
          type="submit"
          disabled={!input.trim() || isStreaming}
          className="p-3 bg-indigo-600 text-white rounded-xl hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        >
          <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
          </svg>
        </button>
      </div>
      <p className="text-xs text-gray-400 mt-2">
        Press Enter to send, Shift+Enter for new line
      </p>
    </form>
  );
}
```

### Typing Indicator Component
Create `frontend/src/components/chat/TypingIndicator.tsx`:
```typescript
import React from 'react';

export function TypingIndicator() {
  return (
    <div className="flex justify-start">
      <div className="bg-white border border-gray-200 rounded-2xl px-4 py-3">
        <div className="flex items-center gap-1">
          <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: '0ms' }} />
          <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: '150ms' }} />
          <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: '300ms' }} />
        </div>
      </div>
    </div>
  );
}
```

### Subject Selector Component
Create `frontend/src/components/chat/SubjectSelector.tsx`:
```typescript
import React, { useState } from 'react';
import { useChat } from '../../contexts/ChatContext';

const SUBJECTS = [
  { id: 'math', name: 'Mathematics', icon: '📐' },
  { id: 'science', name: 'Science', icon: '🔬' },
  { id: 'english', name: 'English', icon: '📚' },
  { id: 'history', name: 'History', icon: '🏛️' },
  { id: 'sat_prep', name: 'SAT Prep', icon: '📝' },
  { id: 'general', name: 'General', icon: '💡' }
];

export function SubjectSelector() {
  const [isOpen, setIsOpen] = useState(false);
  const { createConversation } = useChat();

  const handleSelect = async (subject: string) => {
    await createConversation(subject);
    setIsOpen(false);
  };

  return (
    <div className="p-4 border-b border-gray-200">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="w-full py-2 px-4 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition-colors flex items-center justify-center gap-2"
      >
        <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
        </svg>
        New Conversation
      </button>

      {isOpen && (
        <div className="mt-3 grid grid-cols-2 gap-2">
          {SUBJECTS.map((subject) => (
            <button
              key={subject.id}
              onClick={() => handleSelect(subject.id)}
              className="p-2 text-left bg-gray-50 rounded-lg hover:bg-indigo-50 transition-colors"
            >
              <span className="mr-2">{subject.icon}</span>
              <span className="text-sm text-gray-700">{subject.name}</span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
```

### Handoff Suggestion Component
Create `frontend/src/components/chat/HandoffSuggestion.tsx`:
```typescript
import React, { useState } from 'react';
import { api } from '../../api/client';

interface HandoffSuggestionProps {
  context: {
    subject: string;
    focus_areas: string[];
    available_slots: Array<{
      tutor_id: string;
      tutor_name: string;
      datetime: string;
    }>;
  };
}

export function HandoffSuggestion({ context }: HandoffSuggestionProps) {
  const [selectedSlot, setSelectedSlot] = useState<number | null>(null);
  const [isBooking, setIsBooking] = useState(false);
  const [booked, setBooked] = useState(false);

  const handleBook = async () => {
    if (selectedSlot === null) return;

    const slot = context.available_slots[selectedSlot];
    setIsBooking(true);

    try {
      await api.post('/api/v1/handoffs', {
        tutor_id: slot.tutor_id,
        datetime: slot.datetime,
        subject: context.subject
      });
      setBooked(true);
    } catch (error) {
      console.error('Booking failed:', error);
    } finally {
      setIsBooking(false);
    }
  };

  if (booked) {
    return (
      <div className="bg-green-50 border border-green-200 rounded-lg p-4">
        <div className="flex items-center gap-2 text-green-700">
          <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
          </svg>
          <span className="font-medium">Session booked!</span>
        </div>
        <p className="text-sm text-green-600 mt-1">
          You'll receive a confirmation email shortly.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      <p className="text-gray-700">
        I think a tutor session could really help here. Here are some available times:
      </p>

      <div className="space-y-2">
        {context.available_slots?.slice(0, 3).map((slot, index) => (
          <button
            key={index}
            onClick={() => setSelectedSlot(index)}
            className={`w-full p-3 text-left rounded-lg border transition-colors ${
              selectedSlot === index
                ? 'border-indigo-500 bg-indigo-50'
                : 'border-gray-200 hover:border-gray-300'
            }`}
          >
            <div className="font-medium text-gray-800">{slot.tutor_name}</div>
            <div className="text-sm text-gray-500">
              {new Date(slot.datetime).toLocaleString([], {
                weekday: 'short',
                month: 'short',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
              })}
            </div>
          </button>
        ))}
      </div>

      {context.focus_areas?.length > 0 && (
        <div className="text-sm text-gray-600">
          <span className="font-medium">Focus areas:</span>{' '}
          {context.focus_areas.join(', ')}
        </div>
      )}

      <button
        onClick={handleBook}
        disabled={selectedSlot === null || isBooking}
        className="w-full py-2 px-4 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
      >
        {isBooking ? 'Booking...' : 'Book This Session'}
      </button>
    </div>
  );
}
```

---

## Task 13: Practice Module UI

Build the practice exercise interface.

### Types
Create `frontend/src/types/practice.ts`:
```typescript
export interface Problem {
  id: number;
  type: 'multiple_choice' | 'flashcard' | 'free_response';
  question: string;
  options: string[];
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
```

### Practice Hook
Create `frontend/src/hooks/usePractice.ts`:
```typescript
import { useState, useCallback } from 'react';
import { api } from '../api/client';
import { PracticeSession, Problem, SubmitResult, SessionResult } from '../types/practice';

export function usePractice() {
  const [session, setSession] = useState<PracticeSession | null>(null);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [isLoading, setIsLoading] = useState(false);
  const [lastResult, setLastResult] = useState<SubmitResult | null>(null);
  const [sessionResult, setSessionResult] = useState<SessionResult | null>(null);
  const [showExplanation, setShowExplanation] = useState(false);

  const startSession = useCallback(async (
    subject: string,
    sessionType: 'quiz' | 'flashcards' = 'quiz',
    numProblems = 10
  ) => {
    setIsLoading(true);
    setLastResult(null);
    setSessionResult(null);
    setCurrentIndex(0);
    setShowExplanation(false);

    try {
      const response = await api.post('/api/v1/practice_sessions', {
        subject,
        session_type: sessionType,
        num_problems: numProblems
      });
      setSession(response.data);
      return response.data;
    } finally {
      setIsLoading(false);
    }
  }, []);

  const submitAnswer = useCallback(async (answer: string) => {
    if (!session) return;

    const problem = session.problems[currentIndex];
    setIsLoading(true);

    try {
      const response = await api.post(`/api/v1/practice_sessions/${session.id}/submit`, {
        problem_id: problem.id,
        answer
      });

      setLastResult(response.data);
      setShowExplanation(true);

      // Update local session state
      setSession(prev => {
        if (!prev) return prev;
        const updatedProblems = [...prev.problems];
        updatedProblems[currentIndex] = {
          ...updatedProblems[currentIndex],
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
  }, [session, currentIndex]);

  const nextProblem = useCallback(() => {
    if (session && currentIndex < session.problems.length - 1) {
      setCurrentIndex(prev => prev + 1);
      setLastResult(null);
      setShowExplanation(false);
    }
  }, [session, currentIndex]);

  const previousProblem = useCallback(() => {
    if (currentIndex > 0) {
      setCurrentIndex(prev => prev - 1);
      setLastResult(null);
      setShowExplanation(false);
    }
  }, [currentIndex]);

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

  const currentProblem = session?.problems[currentIndex] || null;
  const progress = session ? ((currentIndex + 1) / session.problems.length) * 100 : 0;
  const isLastProblem = session ? currentIndex >= session.problems.length - 1 : false;
  const canProceed = lastResult !== null;

  return {
    session,
    currentProblem,
    currentIndex,
    progress,
    isLoading,
    lastResult,
    sessionResult,
    showExplanation,
    isLastProblem,
    canProceed,
    startSession,
    submitAnswer,
    nextProblem,
    previousProblem,
    completeSession,
    setShowExplanation
  };
}
```

### Practice Page
Create `frontend/src/pages/Practice.tsx`:
```typescript
import React, { useState } from 'react';
import { usePractice } from '../hooks/usePractice';
import { PracticeSetup } from '../components/practice/PracticeSetup';
import { QuizCard } from '../components/practice/QuizCard';
import { FlashCard } from '../components/practice/FlashCard';
import { SessionComplete } from '../components/practice/SessionComplete';
import { ProgressBar } from '../components/practice/ProgressBar';

export default function PracticePage() {
  const practice = usePractice();
  const { session, sessionResult, currentProblem, progress, isLoading } = practice;

  // Show setup if no session
  if (!session) {
    return <PracticeSetup onStart={practice.startSession} isLoading={isLoading} />;
  }

  // Show results if complete
  if (sessionResult) {
    return <SessionComplete result={sessionResult} onNewSession={() => window.location.reload()} />;
  }

  return (
    <div className="min-h-screen bg-gradient-to-b from-indigo-50 to-white">
      <div className="max-w-3xl mx-auto px-4 py-8">
        {/* Header */}
        <div className="mb-8">
          <div className="flex items-center justify-between mb-4">
            <h1 className="text-2xl font-bold text-gray-800">
              {session.subject} Practice
            </h1>
            <span className="text-sm text-gray-500">
              {practice.currentIndex + 1} of {session.problems.length}
            </span>
          </div>
          <ProgressBar progress={progress} />
        </div>

        {/* Current Problem */}
        {currentProblem && (
          session.session_type === 'flashcards' ? (
            <FlashCard problem={currentProblem} practice={practice} />
          ) : (
            <QuizCard problem={currentProblem} practice={practice} />
          )
        )}

        {/* Navigation */}
        <div className="flex justify-between mt-8">
          <button
            onClick={practice.previousProblem}
            disabled={practice.currentIndex === 0}
            className="px-4 py-2 text-gray-600 hover:text-gray-800 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            ← Previous
          </button>

          {practice.isLastProblem && practice.canProceed ? (
            <button
              onClick={practice.completeSession}
              disabled={isLoading}
              className="px-6 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50"
            >
              {isLoading ? 'Finishing...' : 'Complete Session'}
            </button>
          ) : (
            <button
              onClick={practice.nextProblem}
              disabled={!practice.canProceed}
              className="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Next →
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
```

### Practice Setup Component
Create `frontend/src/components/practice/PracticeSetup.tsx`:
```typescript
import React, { useState } from 'react';

interface PracticeSetupProps {
  onStart: (subject: string, type: 'quiz' | 'flashcards', numProblems: number) => Promise<any>;
  isLoading: boolean;
}

const SUBJECTS = [
  { id: 'mathematics', name: 'Mathematics', icon: '📐', color: 'bg-blue-500' },
  { id: 'physics', name: 'Physics', icon: '⚡', color: 'bg-purple-500' },
  { id: 'chemistry', name: 'Chemistry', icon: '🧪', color: 'bg-green-500' },
  { id: 'biology', name: 'Biology', icon: '🧬', color: 'bg-pink-500' },
  { id: 'english', name: 'English', icon: '📚', color: 'bg-yellow-500' },
  { id: 'history', name: 'History', icon: '🏛️', color: 'bg-orange-500' },
  { id: 'sat_prep', name: 'SAT Prep', icon: '📝', color: 'bg-red-500' }
];

export function PracticeSetup({ onStart, isLoading }: PracticeSetupProps) {
  const [subject, setSubject] = useState<string | null>(null);
  const [type, setType] = useState<'quiz' | 'flashcards'>('quiz');
  const [numProblems, setNumProblems] = useState(10);

  const handleStart = () => {
    if (subject) {
      onStart(subject, type, numProblems);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-b from-indigo-50 to-white">
      <div className="max-w-2xl mx-auto px-4 py-12">
        <div className="text-center mb-10">
          <h1 className="text-3xl font-bold text-gray-800 mb-2">Practice Mode</h1>
          <p className="text-gray-600">Choose a subject and start practicing!</p>
        </div>

        {/* Subject Selection */}
        <div className="mb-8">
          <h2 className="text-lg font-semibold text-gray-700 mb-4">Select Subject</h2>
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
            {SUBJECTS.map((s) => (
              <button
                key={s.id}
                onClick={() => setSubject(s.id)}
                className={`p-4 rounded-xl border-2 transition-all ${
                  subject === s.id
                    ? 'border-indigo-500 bg-indigo-50 shadow-md'
                    : 'border-gray-200 hover:border-gray-300 bg-white'
                }`}
              >
                <span className="text-2xl mb-2 block">{s.icon}</span>
                <span className="font-medium text-gray-800">{s.name}</span>
              </button>
            ))}
          </div>
        </div>

        {/* Practice Type */}
        <div className="mb-8">
          <h2 className="text-lg font-semibold text-gray-700 mb-4">Practice Type</h2>
          <div className="flex gap-4">
            <button
              onClick={() => setType('quiz')}
              className={`flex-1 p-4 rounded-xl border-2 transition-all ${
                type === 'quiz'
                  ? 'border-indigo-500 bg-indigo-50'
                  : 'border-gray-200 hover:border-gray-300 bg-white'
              }`}
            >
              <span className="text-2xl mb-2 block">📋</span>
              <span className="font-medium">Quiz</span>
              <p className="text-xs text-gray-500 mt-1">Multiple choice questions</p>
            </button>
            <button
              onClick={() => setType('flashcards')}
              className={`flex-1 p-4 rounded-xl border-2 transition-all ${
                type === 'flashcards'
                  ? 'border-indigo-500 bg-indigo-50'
                  : 'border-gray-200 hover:border-gray-300 bg-white'
              }`}
            >
              <span className="text-2xl mb-2 block">🃏</span>
              <span className="font-medium">Flashcards</span>
              <p className="text-xs text-gray-500 mt-1">Study and self-assess</p>
            </button>
          </div>
        </div>

        {/* Number of Problems */}
        <div className="mb-10">
          <h2 className="text-lg font-semibold text-gray-700 mb-4">Number of Questions</h2>
          <div className="flex gap-3">
            {[5, 10, 15, 20].map((num) => (
              <button
                key={num}
                onClick={() => setNumProblems(num)}
                className={`flex-1 py-3 rounded-lg border-2 font-medium transition-all ${
                  numProblems === num
                    ? 'border-indigo-500 bg-indigo-50 text-indigo-700'
                    : 'border-gray-200 hover:border-gray-300 text-gray-700'
                }`}
              >
                {num}
              </button>
            ))}
          </div>
        </div>

        {/* Start Button */}
        <button
          onClick={handleStart}
          disabled={!subject || isLoading}
          className="w-full py-4 bg-indigo-600 text-white rounded-xl font-semibold text-lg hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors shadow-lg"
        >
          {isLoading ? (
            <span className="flex items-center justify-center gap-2">
              <svg className="animate-spin w-5 h-5" viewBox="0 0 24 24">
                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" />
                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
              </svg>
              Generating Questions...
            </span>
          ) : (
            'Start Practice'
          )}
        </button>
      </div>
    </div>
  );
}
```

### Quiz Card Component
Create `frontend/src/components/practice/QuizCard.tsx`:
```typescript
import React, { useState } from 'react';
import { Problem } from '../../types/practice';
import { usePractice } from '../../hooks/usePractice';
import confetti from 'canvas-confetti';

interface QuizCardProps {
  problem: Problem;
  practice: ReturnType<typeof usePractice>;
}

export function QuizCard({ problem, practice }: QuizCardProps) {
  const [selectedAnswer, setSelectedAnswer] = useState<string | null>(null);
  const { lastResult, isLoading, submitAnswer, showExplanation } = practice;

  const handleSubmit = async () => {
    if (!selectedAnswer) return;

    const result = await submitAnswer(selectedAnswer);

    if (result?.is_correct) {
      confetti({
        particleCount: 100,
        spread: 70,
        origin: { y: 0.6 }
      });
    }
  };

  const getOptionStyle = (option: string) => {
    if (!lastResult) {
      return selectedAnswer === option
        ? 'border-indigo-500 bg-indigo-50'
        : 'border-gray-200 hover:border-gray-300';
    }

    if (option === lastResult.correct_answer) {
      return 'border-green-500 bg-green-50';
    }

    if (selectedAnswer === option && !lastResult.is_correct) {
      return 'border-red-500 bg-red-50';
    }

    return 'border-gray-200 opacity-50';
  };

  return (
    <div className="bg-white rounded-2xl shadow-lg p-6">
      {/* Difficulty Badge */}
      <div className="flex items-center justify-between mb-4">
        <span className="text-xs font-medium text-gray-500 uppercase tracking-wide">
          {problem.topic}
        </span>
        <div className="flex items-center gap-1">
          {[...Array(10)].map((_, i) => (
            <div
              key={i}
              className={`w-2 h-2 rounded-full ${
                i < problem.difficulty ? 'bg-indigo-500' : 'bg-gray-200'
              }`}
            />
          ))}
        </div>
      </div>

      {/* Question */}
      <h2 className="text-xl font-semibold text-gray-800 mb-6">
        {problem.question}
      </h2>

      {/* Options */}
      <div className="space-y-3 mb-6">
        {problem.options.map((option, index) => (
          <button
            key={index}
            onClick={() => !lastResult && setSelectedAnswer(option)}
            disabled={!!lastResult}
            className={`w-full p-4 text-left rounded-xl border-2 transition-all ${getOptionStyle(option)}`}
          >
            <span className="font-medium text-gray-500 mr-3">
              {String.fromCharCode(65 + index)}.
            </span>
            <span className="text-gray-800">{option}</span>

            {lastResult && option === lastResult.correct_answer && (
              <span className="float-right text-green-600">✓</span>
            )}
            {lastResult && selectedAnswer === option && !lastResult.is_correct && (
              <span className="float-right text-red-600">✗</span>
            )}
          </button>
        ))}
      </div>

      {/* Submit or Result */}
      {!lastResult ? (
        <button
          onClick={handleSubmit}
          disabled={!selectedAnswer || isLoading}
          className="w-full py-3 bg-indigo-600 text-white rounded-xl font-medium hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        >
          {isLoading ? 'Checking...' : 'Submit Answer'}
        </button>
      ) : (
        <div className={`p-4 rounded-xl ${lastResult.is_correct ? 'bg-green-50' : 'bg-red-50'}`}>
          <div className="flex items-center gap-2 mb-2">
            {lastResult.is_correct ? (
              <>
                <span className="text-2xl">🎉</span>
                <span className="font-semibold text-green-700">Correct!</span>
              </>
            ) : (
              <>
                <span className="text-2xl">💪</span>
                <span className="font-semibold text-red-700">Not quite</span>
              </>
            )}
          </div>

          {showExplanation && (
            <div className="mt-3 pt-3 border-t border-gray-200">
              <p className="text-sm text-gray-600 mb-2">{lastResult.feedback}</p>
              <p className="text-sm text-gray-700">
                <span className="font-medium">Explanation:</span> {lastResult.explanation}
              </p>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
```

### Flash Card Component
Create `frontend/src/components/practice/FlashCard.tsx`:
```typescript
import React, { useState } from 'react';
import { Problem } from '../../types/practice';
import { usePractice } from '../../hooks/usePractice';

interface FlashCardProps {
  problem: Problem;
  practice: ReturnType<typeof usePractice>;
}

export function FlashCard({ problem, practice }: FlashCardProps) {
  const [isFlipped, setIsFlipped] = useState(false);
  const [selfAssessment, setSelfAssessment] = useState<'correct' | 'incorrect' | null>(null);
  const { submitAnswer, lastResult, isLoading } = practice;

  const handleFlip = () => {
    setIsFlipped(!isFlipped);
  };

  const handleSelfAssess = async (correct: boolean) => {
    setSelfAssessment(correct ? 'correct' : 'incorrect');
    await submitAnswer(correct ? problem.correct_answer : 'incorrect');
  };

  return (
    <div className="perspective-1000">
      <div
        onClick={!isFlipped && !lastResult ? handleFlip : undefined}
        className={`relative w-full h-80 cursor-pointer transition-transform duration-500 transform-style-preserve-3d ${
          isFlipped ? 'rotate-y-180' : ''
        }`}
        style={{
          transformStyle: 'preserve-3d',
          transform: isFlipped ? 'rotateY(180deg)' : 'rotateY(0)'
        }}
      >
        {/* Front */}
        <div
          className="absolute inset-0 bg-white rounded-2xl shadow-lg p-6 flex flex-col items-center justify-center backface-hidden"
          style={{ backfaceVisibility: 'hidden' }}
        >
          <span className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-4">
            {problem.topic}
          </span>
          <h2 className="text-xl font-semibold text-gray-800 text-center">
            {problem.question}
          </h2>
          <p className="text-sm text-gray-400 mt-6">Click to reveal answer</p>
        </div>

        {/* Back */}
        <div
          className="absolute inset-0 bg-indigo-600 rounded-2xl shadow-lg p-6 flex flex-col items-center justify-center text-white rotate-y-180"
          style={{ backfaceVisibility: 'hidden', transform: 'rotateY(180deg)' }}
        >
          <span className="text-xs font-medium text-indigo-200 uppercase tracking-wide mb-4">
            Answer
          </span>
          <h2 className="text-xl font-semibold text-center mb-6">
            {problem.correct_answer}
          </h2>

          {!lastResult && (
            <div className="mt-4">
              <p className="text-sm text-indigo-200 mb-3 text-center">Did you get it right?</p>
              <div className="flex gap-3">
                <button
                  onClick={() => handleSelfAssess(false)}
                  disabled={isLoading}
                  className="px-6 py-2 bg-red-500 rounded-lg hover:bg-red-600 transition-colors disabled:opacity-50"
                >
                  ✗ No
                </button>
                <button
                  onClick={() => handleSelfAssess(true)}
                  disabled={isLoading}
                  className="px-6 py-2 bg-green-500 rounded-lg hover:bg-green-600 transition-colors disabled:opacity-50"
                >
                  ✓ Yes
                </button>
              </div>
            </div>
          )}

          {lastResult && (
            <div className={`mt-4 px-4 py-2 rounded-lg ${
              lastResult.is_correct ? 'bg-green-500' : 'bg-red-500'
            }`}>
              {lastResult.is_correct ? '🎉 Great job!' : '💪 Keep practicing!'}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
```

### Progress Bar Component
Create `frontend/src/components/practice/ProgressBar.tsx`:
```typescript
import React from 'react';

interface ProgressBarProps {
  progress: number;
}

export function ProgressBar({ progress }: ProgressBarProps) {
  return (
    <div className="w-full h-2 bg-gray-200 rounded-full overflow-hidden">
      <div
        className="h-full bg-indigo-600 rounded-full transition-all duration-300 ease-out"
        style={{ width: `${progress}%` }}
      />
    </div>
  );
}
```

### Session Complete Component
Create `frontend/src/components/practice/SessionComplete.tsx`:
```typescript
import React, { useEffect } from 'react';
import confetti from 'canvas-confetti';
import { SessionResult } from '../../types/practice';

interface SessionCompleteProps {
  result: SessionResult;
  onNewSession: () => void;
}

export function SessionComplete({ result, onNewSession }: SessionCompleteProps) {
  useEffect(() => {
    if (result.accuracy >= 70) {
      confetti({
        particleCount: 200,
        spread: 100,
        origin: { y: 0.6 }
      });
    }
  }, [result.accuracy]);

  const getMessage = () => {
    if (result.accuracy >= 90) return { emoji: '🏆', text: 'Outstanding!' };
    if (result.accuracy >= 80) return { emoji: '🌟', text: 'Excellent work!' };
    if (result.accuracy >= 70) return { emoji: '👏', text: 'Great job!' };
    if (result.accuracy >= 60) return { emoji: '💪', text: 'Good effort!' };
    return { emoji: '📚', text: 'Keep practicing!' };
  };

  const message = getMessage();

  return (
    <div className="min-h-screen bg-gradient-to-b from-indigo-50 to-white flex items-center justify-center">
      <div className="max-w-md w-full mx-4">
        <div className="bg-white rounded-2xl shadow-lg p-8 text-center">
          <div className="text-6xl mb-4">{message.emoji}</div>
          <h1 className="text-2xl font-bold text-gray-800 mb-2">{message.text}</h1>
          <p className="text-gray-600 mb-8">You've completed this practice session</p>

          {/* Stats */}
          <div className="grid grid-cols-3 gap-4 mb-8">
            <div className="bg-gray-50 rounded-xl p-4">
              <div className="text-3xl font-bold text-indigo-600">{result.accuracy}%</div>
              <div className="text-xs text-gray-500 mt-1">Accuracy</div>
            </div>
            <div className="bg-gray-50 rounded-xl p-4">
              <div className="text-3xl font-bold text-green-600">{result.correct}</div>
              <div className="text-xs text-gray-500 mt-1">Correct</div>
            </div>
            <div className="bg-gray-50 rounded-xl p-4">
              <div className="text-3xl font-bold text-gray-600">{result.total}</div>
              <div className="text-xs text-gray-500 mt-1">Total</div>
            </div>
          </div>

          {/* Proficiency Update */}
          <div className="bg-indigo-50 rounded-xl p-4 mb-6">
            <div className="text-sm text-indigo-600 font-medium mb-2">Proficiency Level</div>
            <div className="flex items-center justify-center gap-1">
              {[...Array(10)].map((_, i) => (
                <div
                  key={i}
                  className={`w-4 h-4 rounded-full ${
                    i < result.new_proficiency ? 'bg-indigo-600' : 'bg-indigo-200'
                  }`}
                />
              ))}
            </div>
            <div className="text-xs text-indigo-500 mt-2">Level {result.new_proficiency}/10</div>
          </div>

          {/* Struggled Topics */}
          {result.struggled_topics.length > 0 && (
            <div className="text-left mb-6">
              <div className="text-sm font-medium text-gray-700 mb-2">Topics to review:</div>
              <div className="flex flex-wrap gap-2">
                {result.struggled_topics.map((topic, i) => (
                  <span key={i} className="px-3 py-1 bg-orange-100 text-orange-700 rounded-full text-sm">
                    {topic}
                  </span>
                ))}
              </div>
            </div>
          )}

          {/* Actions */}
          <div className="flex gap-3">
            <button
              onClick={onNewSession}
              className="flex-1 py-3 bg-indigo-600 text-white rounded-xl font-medium hover:bg-indigo-700 transition-colors"
            >
              Practice Again
            </button>
            <button
              onClick={() => window.location.href = '/dashboard'}
              className="flex-1 py-3 border-2 border-gray-200 text-gray-700 rounded-xl font-medium hover:border-gray-300 transition-colors"
            >
              View Dashboard
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
```

---

## Task 14: Multi-Goal Progress Dashboard

Build the progress tracking dashboard.

### Types
Create `frontend/src/types/dashboard.ts`:
```typescript
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
```

### Dashboard Page
Create `frontend/src/pages/Dashboard.tsx`:
```typescript
import React, { useState, useEffect } from 'react';
import { api } from '../api/client';
import { LearningGoal, LearningProfile, DashboardStats } from '../types/dashboard';
import { GoalCard } from '../components/dashboard/GoalCard';
import { ProgressOverview } from '../components/dashboard/ProgressOverview';
import { SubjectProgress } from '../components/dashboard/SubjectProgress';
import { GoalSuggestions } from '../components/dashboard/GoalSuggestions';
import { ActivityFeed } from '../components/dashboard/ActivityFeed';
import { CelebrationModal } from '../components/dashboard/CelebrationModal';

export default function DashboardPage() {
  const [goals, setGoals] = useState<LearningGoal[]>([]);
  const [profiles, setProfiles] = useState<LearningProfile[]>([]);
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [celebration, setCelebration] = useState<LearningGoal | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    loadDashboard();
    checkForCelebrations();
  }, []);

  const loadDashboard = async () => {
    setIsLoading(true);
    try {
      const [goalsRes, profilesRes, statsRes] = await Promise.all([
        api.get('/api/v1/learning_goals'),
        api.get('/api/v1/learning_profiles'),
        api.get('/api/v1/stats')
      ]);
      setGoals(goalsRes.data);
      setProfiles(profilesRes.data);
      setStats(statsRes.data);
    } finally {
      setIsLoading(false);
    }
  };

  const checkForCelebrations = async () => {
    const events = await api.get('/api/v1/student_events?type=goal_completed&acknowledged=false');
    if (events.data.length > 0) {
      const goalId = events.data[0].data.goal_id;
      const goal = goals.find(g => g.id === goalId);
      if (goal) setCelebration(goal);
    }
  };

  const activeGoals = goals.filter(g => g.status === 'active');
  const completedGoals = goals.filter(g => g.status === 'completed');
  const recentlyCompleted = completedGoals.find(g => g.suggested_next_goals?.length > 0);

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="animate-spin w-8 h-8 border-4 border-indigo-600 border-t-transparent rounded-full" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Celebration Modal */}
      {celebration && (
        <CelebrationModal
          goal={celebration}
          onClose={() => setCelebration(null)}
        />
      )}

      <div className="max-w-7xl mx-auto px-4 py-8">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-800">Learning Dashboard</h1>
          <p className="text-gray-600 mt-1">Track your progress across all subjects</p>
        </div>

        {/* Stats Overview */}
        {stats && <ProgressOverview stats={stats} />}

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 mt-8">
          {/* Main Content */}
          <div className="lg:col-span-2 space-y-8">
            {/* Active Goals */}
            <section>
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-xl font-semibold text-gray-800">Active Goals</h2>
                <button
                  onClick={() => window.location.href = '/goals/new'}
                  className="text-sm text-indigo-600 hover:text-indigo-700 font-medium"
                >
                  + Add Goal
                </button>
              </div>

              {activeGoals.length > 0 ? (
                <div className="space-y-4">
                  {activeGoals.map(goal => (
                    <GoalCard key={goal.id} goal={goal} onUpdate={loadDashboard} />
                  ))}
                </div>
              ) : (
                <div className="bg-white rounded-xl p-8 text-center">
                  <p className="text-gray-500">No active goals. Create one to start tracking!</p>
                  <button
                    onClick={() => window.location.href = '/goals/new'}
                    className="mt-4 px-4 py-2 bg-indigo-600 text-white rounded-lg"
                  >
                    Create Your First Goal
                  </button>
                </div>
              )}
            </section>

            {/* Subject Progress */}
            <section>
              <h2 className="text-xl font-semibold text-gray-800 mb-4">Subject Progress</h2>
              <SubjectProgress profiles={profiles} />
            </section>

            {/* Next Steps Suggestions */}
            {recentlyCompleted && (
              <section>
                <h2 className="text-xl font-semibold text-gray-800 mb-4">
                  Recommended Next Steps
                </h2>
                <GoalSuggestions
                  completedGoal={recentlyCompleted}
                  onCreateGoal={loadDashboard}
                />
              </section>
            )}
          </div>

          {/* Sidebar */}
          <div className="space-y-8">
            {/* Completed Goals */}
            <section>
              <h2 className="text-lg font-semibold text-gray-800 mb-4">
                Completed ({completedGoals.length})
              </h2>
              <div className="space-y-2">
                {completedGoals.slice(0, 5).map(goal => (
                  <div
                    key={goal.id}
                    className="bg-white rounded-lg p-3 border border-gray-200"
                  >
                    <div className="flex items-center gap-2">
                      <span className="text-green-500">✓</span>
                      <span className="text-sm font-medium text-gray-800">{goal.title}</span>
                    </div>
                    <span className="text-xs text-gray-500">{goal.subject}</span>
                  </div>
                ))}
              </div>
            </section>

            {/* Activity Feed */}
            <ActivityFeed />
          </div>
        </div>
      </div>
    </div>
  );
}
```

### Progress Overview Component
Create `frontend/src/components/dashboard/ProgressOverview.tsx`:
```typescript
import React from 'react';
import { DashboardStats } from '../../types/dashboard';

interface ProgressOverviewProps {
  stats: DashboardStats;
}

export function ProgressOverview({ stats }: ProgressOverviewProps) {
  const statCards = [
    {
      label: 'Tutor Sessions',
      value: stats.total_sessions,
      icon: '👨‍🏫',
      color: 'bg-blue-500'
    },
    {
      label: 'Problems Solved',
      value: stats.total_practice_problems,
      icon: '✏️',
      color: 'bg-green-500'
    },
    {
      label: 'Avg Accuracy',
      value: `${stats.average_accuracy}%`,
      icon: '🎯',
      color: 'bg-purple-500'
    },
    {
      label: 'Day Streak',
      value: stats.current_streak,
      icon: '🔥',
      color: 'bg-orange-500'
    },
    {
      label: 'Goals Completed',
      value: stats.goals_completed,
      icon: '🏆',
      color: 'bg-yellow-500'
    },
    {
      label: 'Active Goals',
      value: stats.active_goals,
      icon: '🎯',
      color: 'bg-indigo-500'
    }
  ];

  return (
    <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
      {statCards.map((stat, index) => (
        <div key={index} className="bg-white rounded-xl p-4 shadow-sm">
          <div className="flex items-center gap-3">
            <div className={`w-10 h-10 ${stat.color} rounded-lg flex items-center justify-center text-xl`}>
              {stat.icon}
            </div>
            <div>
              <div className="text-2xl font-bold text-gray-800">{stat.value}</div>
              <div className="text-xs text-gray-500">{stat.label}</div>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}
```

### Goal Card Component
Create `frontend/src/components/dashboard/GoalCard.tsx`:
```typescript
import React from 'react';
import { LearningGoal } from '../../types/dashboard';
import { CircularProgress } from './CircularProgress';

interface GoalCardProps {
  goal: LearningGoal;
  onUpdate: () => void;
}

export function GoalCard({ goal, onUpdate }: GoalCardProps) {
  const completedMilestones = goal.milestones?.filter(m => m.completed).length || 0;
  const totalMilestones = goal.milestones?.length || 0;

  return (
    <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-100 hover:shadow-md transition-shadow">
      <div className="flex items-start gap-4">
        {/* Progress Circle */}
        <CircularProgress percentage={goal.progress_percentage} size={60} />

        {/* Content */}
        <div className="flex-1">
          <div className="flex items-center gap-2 mb-1">
            <span className="text-xs font-medium text-indigo-600 uppercase tracking-wide">
              {goal.subject}
            </span>
            {goal.target_date && (
              <span className="text-xs text-gray-400">
                Due {new Date(goal.target_date).toLocaleDateString()}
              </span>
            )}
          </div>

          <h3 className="text-lg font-semibold text-gray-800 mb-2">{goal.title}</h3>

          {goal.description && (
            <p className="text-sm text-gray-600 mb-3">{goal.description}</p>
          )}

          {/* Milestones */}
          {totalMilestones > 0 && (
            <div className="mb-3">
              <div className="flex items-center gap-2 mb-2">
                <span className="text-xs text-gray-500">
                  {completedMilestones}/{totalMilestones} milestones
                </span>
              </div>
              <div className="flex gap-1">
                {goal.milestones?.map((milestone, i) => (
                  <div
                    key={i}
                    className={`h-2 flex-1 rounded-full ${
                      milestone.completed ? 'bg-green-500' : 'bg-gray-200'
                    }`}
                    title={milestone.title}
                  />
                ))}
              </div>
            </div>
          )}

          {/* Actions */}
          <div className="flex gap-2">
            <button
              onClick={() => window.location.href = `/practice?subject=${goal.subject}`}
              className="text-sm text-indigo-600 hover:text-indigo-700 font-medium"
            >
              Practice
            </button>
            <button
              onClick={() => window.location.href = `/chat?subject=${goal.subject}`}
              className="text-sm text-gray-600 hover:text-gray-700 font-medium"
            >
              Ask AI
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
```

### Circular Progress Component
Create `frontend/src/components/dashboard/CircularProgress.tsx`:
```typescript
import React from 'react';

interface CircularProgressProps {
  percentage: number;
  size?: number;
  strokeWidth?: number;
}

export function CircularProgress({
  percentage,
  size = 60,
  strokeWidth = 6
}: CircularProgressProps) {
  const radius = (size - strokeWidth) / 2;
  const circumference = radius * 2 * Math.PI;
  const offset = circumference - (percentage / 100) * circumference;

  const getColor = () => {
    if (percentage >= 80) return '#10B981'; // green
    if (percentage >= 50) return '#6366F1'; // indigo
    if (percentage >= 25) return '#F59E0B'; // yellow
    return '#EF4444'; // red
  };

  return (
    <div className="relative" style={{ width: size, height: size }}>
      <svg className="transform -rotate-90" width={size} height={size}>
        {/* Background circle */}
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke="#E5E7EB"
          strokeWidth={strokeWidth}
        />
        {/* Progress circle */}
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke={getColor()}
          strokeWidth={strokeWidth}
          strokeDasharray={circumference}
          strokeDashoffset={offset}
          strokeLinecap="round"
          className="transition-all duration-500 ease-out"
        />
      </svg>
      <div className="absolute inset-0 flex items-center justify-center">
        <span className="text-sm font-bold text-gray-800">{percentage}%</span>
      </div>
    </div>
  );
}
```

### Subject Progress Component
Create `frontend/src/components/dashboard/SubjectProgress.tsx`:
```typescript
import React from 'react';
import { LearningProfile } from '../../types/dashboard';

interface SubjectProgressProps {
  profiles: LearningProfile[];
}

const SUBJECT_ICONS: Record<string, string> = {
  mathematics: '📐',
  physics: '⚡',
  chemistry: '🧪',
  biology: '🧬',
  english: '📚',
  history: '🏛️',
  sat_prep: '📝',
  general: '💡'
};

export function SubjectProgress({ profiles }: SubjectProgressProps) {
  if (profiles.length === 0) {
    return (
      <div className="bg-white rounded-xl p-6 text-center text-gray-500">
        No subjects tracked yet. Start a conversation or practice to begin!
      </div>
    );
  }

  return (
    <div className="bg-white rounded-xl p-6 shadow-sm">
      <div className="space-y-4">
        {profiles.map((profile) => (
          <div key={profile.subject} className="border-b border-gray-100 pb-4 last:border-0 last:pb-0">
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center gap-2">
                <span className="text-xl">
                  {SUBJECT_ICONS[profile.subject] || '📚'}
                </span>
                <span className="font-medium text-gray-800 capitalize">
                  {profile.subject.replace('_', ' ')}
                </span>
              </div>
              <span className="text-sm font-medium text-indigo-600">
                Level {profile.proficiency_level}/10
              </span>
            </div>

            {/* Proficiency Bar */}
            <div className="w-full h-2 bg-gray-100 rounded-full mb-3">
              <div
                className="h-full bg-indigo-600 rounded-full transition-all duration-500"
                style={{ width: `${profile.proficiency_level * 10}%` }}
              />
            </div>

            {/* Strengths & Weaknesses */}
            <div className="flex gap-4 text-xs">
              {profile.strengths?.length > 0 && (
                <div>
                  <span className="text-gray-500">Strengths: </span>
                  <span className="text-green-600">{profile.strengths.slice(0, 2).join(', ')}</span>
                </div>
              )}
              {profile.weaknesses?.length > 0 && (
                <div>
                  <span className="text-gray-500">To improve: </span>
                  <span className="text-orange-600">{profile.weaknesses.slice(0, 2).join(', ')}</span>
                </div>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
```

### Goal Suggestions Component
Create `frontend/src/components/dashboard/GoalSuggestions.tsx`:
```typescript
import React from 'react';
import { api } from '../../api/client';
import { LearningGoal } from '../../types/dashboard';

interface GoalSuggestionsProps {
  completedGoal: LearningGoal;
  onCreateGoal: () => void;
}

export function GoalSuggestions({ completedGoal, onCreateGoal }: GoalSuggestionsProps) {
  const handleCreateGoal = async (suggestion: any) => {
    await api.post('/api/v1/learning_goals', {
      subject: suggestion.subject,
      title: `Master ${suggestion.subject.replace('_', ' ')}`,
      description: suggestion.reason
    });
    onCreateGoal();
  };

  return (
    <div className="bg-gradient-to-r from-indigo-50 to-purple-50 rounded-xl p-6">
      <div className="flex items-center gap-2 mb-4">
        <span className="text-2xl">🎉</span>
        <div>
          <h3 className="font-semibold text-gray-800">
            Congratulations on completing "{completedGoal.title}"!
          </h3>
          <p className="text-sm text-gray-600">Here's what we suggest next:</p>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
        {completedGoal.suggested_next_goals?.map((suggestion, index) => (
          <div
            key={index}
            className="bg-white rounded-lg p-4 border border-gray-200 hover:border-indigo-300 transition-colors"
          >
            <h4 className="font-medium text-gray-800 capitalize mb-1">
              {suggestion.subject.replace('_', ' ')}
            </h4>
            <p className="text-sm text-gray-600 mb-3">{suggestion.reason}</p>
            <button
              onClick={() => handleCreateGoal(suggestion)}
              className="text-sm text-indigo-600 hover:text-indigo-700 font-medium"
            >
              Start this goal →
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}
```

### Celebration Modal Component
Create `frontend/src/components/dashboard/CelebrationModal.tsx`:
```typescript
import React, { useEffect } from 'react';
import confetti from 'canvas-confetti';
import { LearningGoal } from '../../types/dashboard';
import { api } from '../../api/client';

interface CelebrationModalProps {
  goal: LearningGoal;
  onClose: () => void;
}

export function CelebrationModal({ goal, onClose }: CelebrationModalProps) {
  useEffect(() => {
    // Trigger confetti
    confetti({
      particleCount: 150,
      spread: 100,
      origin: { y: 0.6 }
    });

    // Acknowledge event
    api.post('/api/v1/student_events/acknowledge', {
      event_type: 'goal_completed',
      goal_id: goal.id
    });
  }, [goal.id]);

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
      <div className="bg-white rounded-2xl p-8 max-w-md mx-4 text-center animate-bounce-in">
        <div className="text-6xl mb-4">🎉</div>
        <h2 className="text-2xl font-bold text-gray-800 mb-2">Goal Achieved!</h2>
        <p className="text-gray-600 mb-6">
          You've completed <span className="font-semibold">{goal.title}</span>
        </p>

        {goal.suggested_next_goals && goal.suggested_next_goals.length > 0 && (
          <div className="mb-6">
            <p className="text-sm text-gray-500 mb-3">Ready for your next challenge?</p>
            <div className="space-y-2">
              {goal.suggested_next_goals.slice(0, 2).map((suggestion, i) => (
                <button
                  key={i}
                  className="w-full p-3 text-left bg-indigo-50 rounded-lg hover:bg-indigo-100 transition-colors"
                >
                  <span className="font-medium text-indigo-700 capitalize">
                    {suggestion.subject.replace('_', ' ')}
                  </span>
                  <span className="text-xs text-indigo-500 block">{suggestion.reason}</span>
                </button>
              ))}
            </div>
          </div>
        )}

        <button
          onClick={onClose}
          className="w-full py-3 bg-indigo-600 text-white rounded-xl font-medium hover:bg-indigo-700 transition-colors"
        >
          Continue Learning
        </button>
      </div>
    </div>
  );
}
```

### Activity Feed Component
Create `frontend/src/components/dashboard/ActivityFeed.tsx`:
```typescript
import React, { useState, useEffect } from 'react';
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
```

---

## Dependencies to Install

```bash
cd frontend

# Core UI
npm install react-router-dom @tanstack/react-query axios

# Markdown & Syntax
npm install react-markdown remark-gfm remark-math rehype-katex
npm install react-syntax-highlighter
npm install @types/react-syntax-highlighter -D

# Date formatting
npm install date-fns

# Animations
npm install canvas-confetti
npm install @types/canvas-confetti -D

# Math rendering (for KaTeX)
npm install katex
```

---

## App Router Setup

Update `frontend/src/App.tsx`:
```typescript
import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { AuthProvider, useAuth } from './contexts/AuthContext';

// Pages
import ChatPage from './pages/Chat';
import PracticePage from './pages/Practice';
import DashboardPage from './pages/Dashboard';
import LoginPage from './pages/Login';

const queryClient = new QueryClient();

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, isLoading } = useAuth();

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin w-8 h-8 border-4 border-indigo-600 border-t-transparent rounded-full" />
      </div>
    );
  }

  return isAuthenticated ? <>{children}</> : <Navigate to="/login" />;
}

function AppRoutes() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        path="/chat"
        element={
          <ProtectedRoute>
            <ChatPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/practice"
        element={
          <ProtectedRoute>
            <PracticePage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/dashboard"
        element={
          <ProtectedRoute>
            <DashboardPage />
          </ProtectedRoute>
        }
      />
      <Route path="/" element={<Navigate to="/dashboard" />} />
    </Routes>
  );
}

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <BrowserRouter>
          <AppRoutes />
        </BrowserRouter>
      </AuthProvider>
    </QueryClientProvider>
  );
}
```

---

## Tailwind Config Addition

Add animation to `tailwind.config.js`:
```javascript
module.exports = {
  // ...
  theme: {
    extend: {
      animation: {
        'bounce-in': 'bounceIn 0.5s ease-out',
      },
      keyframes: {
        bounceIn: {
          '0%': { transform: 'scale(0.9)', opacity: '0' },
          '50%': { transform: 'scale(1.02)' },
          '100%': { transform: 'scale(1)', opacity: '1' },
        },
      },
    },
  },
  // ...
};
```

---

## Validation Checklist

- [ ] WebSocket connects and maintains heartbeat
- [ ] Chat messages stream in real-time
- [ ] Markdown and code blocks render correctly
- [ ] Practice quiz shows questions and tracks answers
- [ ] Flashcards flip and allow self-assessment
- [ ] Session completion shows confetti and results
- [ ] Dashboard loads goals, profiles, and stats
- [ ] Progress circles animate correctly
- [ ] Goal suggestions appear after completion
- [ ] Celebration modal triggers for completed goals
- [ ] All routes are protected and redirect to login

Execute this entire frontend implementation.
