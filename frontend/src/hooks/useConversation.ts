import { useState, useCallback, useRef, useEffect } from 'react';
import { api } from '../api/client';

interface Message {
  id: number;
  role: 'user' | 'assistant';
  content: string;
  created_at: string;
}

interface Conversation {
  id: number;
  subject: string | null;
  messages: Message[];
}

export function useConversation(conversationId?: number) {
  const [conversation, setConversation] = useState<Conversation | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [isStreaming, setIsStreaming] = useState(false);
  const [streamingContent, setStreamingContent] = useState('');
  const wsRef = useRef<WebSocket | null>(null);

  // Load existing conversation
  useEffect(() => {
    if (conversationId) {
      loadConversation(conversationId);
    }
  }, [conversationId]);

  const loadConversation = async (id: number) => {
    const response = await api.get(`/api/v1/conversations/${id}`);
    setConversation(response.data);
    setMessages(response.data.messages || []);
  };

  const createConversation = async (initialMessage?: string, subject?: string) => {
    const response = await api.post('/api/v1/conversations', {
      initial_message: initialMessage,
      subject
    });
    setConversation(response.data);
    if (response.data.messages) {
      setMessages(response.data.messages);
    }
    return response.data;
  };

  const sendMessage = useCallback(async (content: string, useStreaming = true) => {
    if (!conversation) return;

    // Add user message immediately
    const userMessage: Message = {
      id: Date.now(),
      role: 'user',
      content,
      created_at: new Date().toISOString()
    };
    setMessages(prev => [...prev, userMessage]);

    if (useStreaming) {
      // Use WebSocket for streaming
      connectAndStream(content);
    } else {
      // Use REST API
      setIsLoading(true);
      try {
        const response = await api.post(`/api/v1/conversations/${conversation.id}/messages`, {
          content
        });
        setMessages(prev => [...prev, response.data]);
      } finally {
        setIsLoading(false);
      }
    }
  }, [conversation]);

  const connectAndStream = (content: string) => {
    const token = localStorage.getItem('token');
    const wsUrl = `${import.meta.env.VITE_WS_URL || 'ws://localhost:3000'}/cable?token=${token}`;

    const ws = new WebSocket(wsUrl);
    wsRef.current = ws;

    ws.onopen = () => {
      // Subscribe to conversation channel
      ws.send(JSON.stringify({
        command: 'subscribe',
        identifier: JSON.stringify({
          channel: 'ConversationChannel',
          conversation_id: conversation?.id
        })
      }));

      // Send message after subscription
      setTimeout(() => {
        ws.send(JSON.stringify({
          command: 'message',
          identifier: JSON.stringify({
            channel: 'ConversationChannel',
            conversation_id: conversation?.id
          }),
          data: JSON.stringify({ action: 'send_message', content })
        }));
        setIsStreaming(true);
        setStreamingContent('');
      }, 100);
    };

    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);

      if (data.type === 'ping') return;

      if (data.message) {
        if (data.message.type === 'chunk') {
          setStreamingContent(prev => prev + data.message.content);
        } else if (data.message.type === 'complete') {
          // Add complete message
          setMessages(prev => [...prev, {
            id: Date.now(),
            role: 'assistant',
            content: streamingContent,
            created_at: new Date().toISOString()
          }]);
          setIsStreaming(false);
          setStreamingContent('');
          ws.close();
        }
      }
    };

    ws.onerror = () => {
      setIsStreaming(false);
      ws.close();
    };
  };

  return {
    conversation,
    messages,
    isLoading,
    isStreaming,
    streamingContent,
    createConversation,
    sendMessage,
    loadConversation
  };
}
