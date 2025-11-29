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


