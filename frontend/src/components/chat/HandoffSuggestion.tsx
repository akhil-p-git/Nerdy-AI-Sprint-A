import { useState } from 'react';
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


