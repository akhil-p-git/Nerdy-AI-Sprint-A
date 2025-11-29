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
