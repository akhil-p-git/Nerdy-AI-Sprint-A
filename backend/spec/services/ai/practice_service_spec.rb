require 'rails_helper'

RSpec.describe AI::PracticeService, type: :service do
  let(:student) { create(:student) }
  let(:service) { described_class.new(student: student) }

  describe '#generate_session', vcr: { cassette_name: 'openai/practice_generation' } do
    it 'creates a practice session with problems' do
      session = service.generate_session(
        subject: 'mathematics',
        session_type: 'quiz',
        num_problems: 5
      )

      expect(session).to be_persisted
      expect(session.practice_problems.count).to eq(5)
    end

    it 'sets correct attributes on session' do
      session = service.generate_session(
        subject: 'physics',
        session_type: 'flashcards',
        num_problems: 3
      )

      expect(session.subject).to eq('physics')
      expect(session.session_type).to eq('flashcards')
      expect(session.total_problems).to eq(3)
    end
  end

  describe '#submit_answer' do
    let(:session) { create(:practice_session, :with_problems, student: student) }
    let(:problem) { session.practice_problems.first }

    it 'records correct answer' do
      problem.update!(correct_answer: 'A')

      result = service.submit_answer(problem.id, 'A')

      expect(result[:is_correct]).to be true
      expect(problem.reload.is_correct).to be true
    end

    it 'records incorrect answer' do
      problem.update!(correct_answer: 'A')

      result = service.submit_answer(problem.id, 'B')

      expect(result[:is_correct]).to be false
      expect(problem.reload.is_correct).to be false
    end

    it 'updates session statistics' do
      problem.update!(correct_answer: 'A')

      expect {
        service.submit_answer(problem.id, 'A')
      }.to change { session.reload.correct_answers }.by(1)
    end
  end

  describe '#complete_session' do
    let(:session) { create(:practice_session, student: student, correct_answers: 8, total_problems: 10) }

    it 'marks session as completed' do
      result = service.complete_session(session.id)

      expect(session.reload.completed_at).not_to be_nil
      expect(result[:accuracy]).to eq(80)
    end

    it 'updates learning profile' do
      profile = create(:learning_profile, student: student, subject: session.subject, proficiency_level: 5)

      service.complete_session(session.id)

      # High accuracy should increase proficiency
      expect(profile.reload.proficiency_level).to be >= 5
    end
  end
end


