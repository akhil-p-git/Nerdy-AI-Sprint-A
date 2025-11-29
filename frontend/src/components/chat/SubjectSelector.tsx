import { useState } from 'react';
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


