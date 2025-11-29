import { useEffect } from 'react';
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


