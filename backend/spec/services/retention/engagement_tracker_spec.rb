require 'rails_helper'

RSpec.describe Retention::EngagementTracker, type: :service do
  let(:student) { create(:student, created_at: 10.days.ago) }
  let(:tracker) { described_class.new(student: student) }

  describe '#engagement_score' do
    context 'with active student' do
      before do
        create_list(:practice_session, 5, student: student, created_at: 3.days.ago)
        create_list(:conversation, 3, student: student, updated_at: 2.days.ago)
      end

      it 'returns positive score' do
        expect(tracker.engagement_score).to be > 0
      end
    end

    context 'with inactive student' do
      it 'returns low score' do
        expect(tracker.engagement_score).to be < 50
      end
    end
  end

  describe '#needs_nudge?' do
    context 'new student with few sessions' do
      let(:student) { create(:student, created_at: 8.days.ago) }

      it 'returns true when less than 3 sessions' do
        create(:tutoring_session, student: student)

        expect(tracker.needs_nudge?).to be true
      end
    end

    context 'inactive student' do
      let(:student) { create(:student, created_at: 30.days.ago) }

      it 'returns true when no recent activity' do
        expect(tracker.needs_nudge?).to be true
      end
    end
  end

  describe '#recommended_nudge' do
    context 'new student low sessions' do
      let(:student) { create(:student, created_at: 8.days.ago) }

      before { create(:tutoring_session, student: student) }

      it 'recommends session booking' do
        expect(tracker.recommended_nudge).to eq(:new_student_sessions)
      end
    end
  end
end


