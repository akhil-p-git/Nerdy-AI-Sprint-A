import { createContext, useContext, useState, useCallback } from 'react';
import type { ReactNode } from 'react';
import { api } from '../api/client';
import { useWebSocket } from '../hooks/useWebSocket';
import type { Conversation, Message } from '../types/chat';

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


